"""Bounded, review-only discovery of medical-method literature (v2 gates).

This module stores metadata and short permitted evidence snippets.  It never
persists an article body and never promotes a candidate to the curated seed.

v2: a verified journal whitelist is the gate, a per-module Methods-section
signal decides relevance, and only ``screened`` candidates count toward the
daily quota.  Pending literature requests are served first in every cycle.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

import discovery
from backup import backup_data_dir

ALLOWED_HOSTS = frozenset({"www.ebi.ac.uk", "europepmc.org", "www.ebi.ac.uk", "eutils.ncbi.nlm.nih.gov", "pmc.ncbi.nlm.nih.gov"})
MAX_BODY_BYTES = 2_000_000
REQUEST_TIMEOUT_SECONDS = 10
MAX_RUNTIME_SECONDS = 210
TZ_SHANGHAI = dt.timezone(dt.timedelta(hours=8), name="Asia/Shanghai")
METHOD_WORDS = re.compile(r"\b(method|methodology|statistical|analysis|analyses|model|regression|imputation|hazard|spline|propensity|agreement)\b", re.I)
NUMERIC = re.compile(r"\b\d+(?:\.\d+)?(?:%|\s*(?:CI|mg|year|month|day|patient|participants?))?\b", re.I)
EXTRACTION_VERSION = "method-sections-v2"
SCREENING_VERSION = "whitelist-signal-v2"
METHOD_HEADING = re.compile(r"method|statistic|analysis|analyses|analytical", re.I)
from registry import METHOD_MAP_SCHEMA  # noqa: E402  (omicstat fork: one registry)
DAILY_QUOTA = 10
PAGE_SIZE = 25
MAX_FULLTEXT_PER_MODULE = 3
MAX_FULLTEXT_PER_REQUEST = 4
REQUEST_DAILY_SLOTS = 4
REQUEST_MAX_ATTEMPTS = 3
LEGACY_FLAG = "legacy_v1_unscreened"
MIGRATION_V2 = "v2-001-screening-gates"
ACTIVE_REQUEST_STATES = ("queued", "searching")
TERMINAL_REQUEST_STATES = ("fulfilled", "partially_fulfilled", "unavailable", "cancelled", "expired")
REQUEST_PHASE_MAX_REQUESTS = 24
REQUEST_PHASE_MAX_ATTEMPTS = 6
DOMAIN_CURSOR_KEY = "v2:domain-rotation"
GATES = ("off_whitelist", "duplicate", "excluded_by_regex", "year_out_of_range", "retracted",
         "pubtype_excluded", "invalid_metadata", "no_pmcid", "off_topic", "no_method_section",
         "rights_unconfirmed", "rights_restricted", "headers_only_fulltext", "fulltext_error", "identity_rejected",
         "excluded_by_request", "screened")
# Profile-level verdicts are remembered per module; paper-level verdicts for every module ('*').
PROFILE_LEVEL_OUTCOMES = frozenset({"off_topic", "excluded_by_regex", "pubtype_excluded"})
PAPER_LEVEL_OUTCOMES = frozenset({"retracted", "year_out_of_range", "identity_rejected", "invalid_metadata"})


class HarvestError(RuntimeError):
    """Structured operational error with a stable code."""
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code, self.message = code, message

    def as_dict(self) -> dict[str, str]:
        return {"error": self.code, "message": self.message}


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def _day(now: dt.datetime | None = None) -> str:
    now = now or dt.datetime.now(dt.timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=dt.timezone.utc)
    return now.astimezone(TZ_SHANGHAI).date().isoformat()


def _norm_identifier(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    value = value.strip().lower()
    if not value:
        return None
    value = re.sub(r"^https?://(?:dx\.)?doi\.org/", "", value)
    value = re.sub(r"^doi:\s*", "", value)
    value = value.rstrip(". ")
    if value.startswith("pmcid:"):
        value = value[6:]
    if value.startswith("pmid:"):
        value = value[5:]
    if value.startswith("pmc") and value[3:].isdigit():
        return "pmcid:" + value.upper()
    if value.isdigit():
        return "pmid:" + value
    if "/" in value and not value.startswith("http"):
        return "doi:" + value
    return value


def _identifiers(record: Mapping[str, Any]) -> set[str]:
    found: set[str] = set()
    for key in ("doi", "pmid", "pmcid", "id"):
        normalized = _norm_identifier(record.get(key))
        if normalized:
            found.add(normalized)
    return found


def _seed_identifiers(seed_catalog: str | Path | Mapping[str, Any] | Iterable[str] | None) -> set[str]:
    if seed_catalog is None:
        return set()
    if isinstance(seed_catalog, (str, Path)):
        try:
            data: Any = json.loads(Path(seed_catalog).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise HarvestError("invalid_seed_catalog", "Seed catalog must be readable UTF-8 JSON") from exc
    else:
        data = seed_catalog
    result: set[str] = set()
    if isinstance(data, Mapping):
        stack: list[Any] = [data]
        while stack:
            node = stack.pop()
            if isinstance(node, Mapping):
                result.update(_identifiers(node))
                stack.extend(node.values())
            elif isinstance(node, list):
                stack.extend(node)
    else:
        for value in data:  # type: ignore[union-attr]
            normalized = _norm_identifier(value)
            if normalized:
                result.add(normalized)
    return result


def _load_method_map(path: str | Path | None = None) -> dict[str, Any]:
    """Load the authoritative router order (omicstat fork: delegated to registry.load_method_map)."""
    import registry
    try:
        return registry.load_method_map(path)
    except registry.RegistryError as exc:
        raise HarvestError(exc.code, str(exc)) from exc


class HarvestStore:
    """Separate SQLite store for unreviewed acquisition candidates."""
    def __init__(self, db_path: str | Path):
        self.db_path = str(db_path)
        self._initialize()

    def _connection(self) -> sqlite3.Connection:
        con = sqlite3.connect(self.db_path, timeout=10, isolation_level=None)
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA busy_timeout=10000")
        con.execute("PRAGMA foreign_keys=ON")
        return con

    def _initialize(self) -> None:
        con = self._connection()
        try:
            con.executescript("""
              CREATE TABLE IF NOT EXISTS candidates (
                candidate_id TEXT PRIMARY KEY, title TEXT NOT NULL, module TEXT NOT NULL,
                status TEXT NOT NULL, flags_json TEXT NOT NULL, provenance_json TEXT NOT NULL,
                record_json TEXT NOT NULL, created_at TEXT NOT NULL
              );
              CREATE TABLE IF NOT EXISTS identity_aliases (
                alias TEXT PRIMARY KEY, candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id)
              );
              CREATE TABLE IF NOT EXISTS daily_ledger (
                day TEXT NOT NULL, candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id),
                counted_at TEXT NOT NULL, PRIMARY KEY(day, candidate_id)
              );
              CREATE TABLE IF NOT EXISTS daily_runs (
                day TEXT PRIMARY KEY, state TEXT NOT NULL, detail_json TEXT NOT NULL, updated_at TEXT NOT NULL
              );
              CREATE TABLE IF NOT EXISTS leases (
                name TEXT PRIMARY KEY, owner TEXT NOT NULL, expires_at REAL NOT NULL
              );
              CREATE TABLE IF NOT EXISTS query_cursors (
                module TEXT PRIMARY KEY, cursor TEXT NOT NULL, updated_at TEXT NOT NULL
              );
              CREATE TABLE IF NOT EXISTS route_probes (
                day TEXT NOT NULL, route TEXT NOT NULL, available INTEGER NOT NULL,
                checked_at TEXT NOT NULL, PRIMARY KEY(day, route)
              );
              CREATE TABLE IF NOT EXISTS method_map_state (
                singleton INTEGER PRIMARY KEY CHECK(singleton=1), map_hash TEXT NOT NULL,
                source_sha256 TEXT, order_json TEXT NOT NULL, next_module TEXT NOT NULL,
                state TEXT NOT NULL, updated_at TEXT NOT NULL
              );
              CREATE TABLE IF NOT EXISTS module_events (
                day TEXT NOT NULL, module TEXT NOT NULL, map_hash TEXT NOT NULL,
                outcome TEXT NOT NULL, detail TEXT, recorded_at TEXT NOT NULL,
                PRIMARY KEY(day, module, outcome, detail)
              );
            """)
        finally:
            con.close()
        self._migrate_v2()

    # ------------------------------------------------------------ v2 migration
    V2_TABLES = """
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY, applied_at TEXT NOT NULL, detail_json TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS screened_out (
        alias TEXT NOT NULL, outcome TEXT NOT NULL, module TEXT NOT NULL,
        day TEXT NOT NULL, recorded_at TEXT NOT NULL, PRIMARY KEY(alias, module)
      );
      CREATE TABLE IF NOT EXISTS daily_gate_counts (
        day TEXT NOT NULL, gate TEXT NOT NULL, n INTEGER NOT NULL, PRIMARY KEY(day, gate)
      );
      CREATE TABLE IF NOT EXISTS literature_requests (
        request_id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, module TEXT NOT NULL,
        payload_json TEXT NOT NULL, keywords_json TEXT NOT NULL, status TEXT NOT NULL,
        max_papers INTEGER NOT NULL, requester TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, expires_at TEXT NOT NULL,
        gap_report_json TEXT, history_json TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS request_attempts (
        request_id TEXT NOT NULL REFERENCES literature_requests(request_id), day TEXT NOT NULL,
        started_at TEXT NOT NULL, finished_at TEXT, detail_json TEXT NOT NULL,
        PRIMARY KEY(request_id, day)
      );
      CREATE TABLE IF NOT EXISTS request_links (
        request_id TEXT NOT NULL REFERENCES literature_requests(request_id),
        candidate_id TEXT NOT NULL REFERENCES candidates(candidate_id), day TEXT NOT NULL,
        counted INTEGER NOT NULL, linked_at TEXT NOT NULL, PRIMARY KEY(request_id, candidate_id)
      );
      CREATE TABLE IF NOT EXISTS accepted_profiles (
        profile_key TEXT PRIMARY KEY, profile_json TEXT NOT NULL, source_proposal_id TEXT NOT NULL,
        accepted_by TEXT NOT NULL, accepted_at TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1
      );
      CREATE UNIQUE INDEX IF NOT EXISTS ux_literature_requests_active_fp
        ON literature_requests(fingerprint) WHERE status IN ('queued','searching');
    """

    def _migrate_v2(self) -> None:
        """Additive only: new tables/columns; legacy rows are *marked*, never rewritten or deleted."""
        con = self._connection()
        try:
            self._guard_pre_r2_schema(con)
            con.executescript(self.V2_TABLES)
            if con.execute("SELECT 1 FROM schema_migrations WHERE version=?", (MIGRATION_V2,)).fetchone():
                return
            legacy_rows = int(con.execute("SELECT count(*) FROM candidates").fetchone()[0])
        finally:
            con.close()
        backup_path = None
        if legacy_rows:
            # Upgrade of an existing v1 store: take a timestamped /data tar first.
            backup_path = str(backup_data_dir(Path(self.db_path).resolve().parent, "pre-v2-migration"))
        con = self._connection()
        try:
            con.execute("BEGIN IMMEDIATE")
            if con.execute("SELECT 1 FROM schema_migrations WHERE version=?", (MIGRATION_V2,)).fetchone():
                con.execute("ROLLBACK")
                return
            columns = {row["name"] for row in con.execute("PRAGMA table_info(candidates)")}
            if "legacy_flag" not in columns:
                con.execute("ALTER TABLE candidates ADD COLUMN legacy_flag TEXT")
            if "pipeline" not in columns:
                con.execute("ALTER TABLE candidates ADD COLUMN pipeline TEXT")
            marked = con.execute("UPDATE candidates SET legacy_flag=? WHERE legacy_flag IS NULL AND pipeline IS NULL", (LEGACY_FLAG,)).rowcount
            con.execute("INSERT INTO schema_migrations(version,applied_at,detail_json) VALUES(?,?,?)", (
                MIGRATION_V2, _utc_now(), json.dumps({"legacy_marked": marked, "backup": backup_path}, ensure_ascii=False)))
            con.execute("COMMIT")
        except Exception:
            if con.in_transaction:
                con.execute("ROLLBACK")
            raise
        finally:
            con.close()

    @staticmethod
    def _guard_pre_r2_schema(con: sqlite3.Connection) -> None:
        """Refuse a development store built with the pre-R2 v2 table definitions (never mix silently)."""
        names = {r[0] for r in con.execute("SELECT name FROM sqlite_master")}
        stale = False
        if "literature_requests" in names:
            # The TEXT primary key owns sqlite_autoindex_literature_requests_1 in both definitions, so
            # detect the old column-level UNIQUE by origin 'u' on the fingerprint column instead.
            for index in con.execute("PRAGMA index_list(literature_requests)"):
                if index["origin"] == "u":
                    columns = [c["name"] for c in con.execute('PRAGMA index_info("%s")' % index["name"].replace('"', ""))]
                    stale = stale or columns == ["fingerprint"]
        if "screened_out" in names:
            pk_columns = [r["name"] for r in con.execute("PRAGMA table_info(screened_out)") if r["pk"]]
            stale = stale or pk_columns == ["alias"]
        if stale:
            raise HarvestError("schema_predates_r2", "harvest.sqlite was created by a pre-R2 v2 build (global fingerprint UNIQUE or alias-only screened_out); recreate it from the v1 store instead of mixing definitions")

    def migration_status(self) -> list[dict[str, Any]]:
        con = self._connection()
        try:
            return [{"version": r["version"], "applied_at": r["applied_at"], "detail": json.loads(r["detail_json"])}
                    for r in con.execute("SELECT * FROM schema_migrations ORDER BY applied_at")]
        finally:
            con.close()

    def _count(self, con: sqlite3.Connection, day: str) -> int:
        """Quota basis: only v2 ``screened`` candidates; legacy ledger rows stay but never count."""
        return int(con.execute(
            "SELECT count(*) FROM daily_ledger l JOIN candidates c ON c.candidate_id=l.candidate_id "
            "WHERE l.day=? AND c.status='screened' AND c.legacy_flag IS NULL", (day,)).fetchone()[0])

    def add_gate_counts(self, day: str, counts: Mapping[str, int]) -> None:
        items = [(day, gate, int(n)) for gate, n in counts.items() if n]
        if not items:
            return
        con = self._connection()
        try:
            con.executemany("INSERT INTO daily_gate_counts(day,gate,n) VALUES(?,?,?) ON CONFLICT(day,gate) DO UPDATE SET n=n+excluded.n", items)
        finally:
            con.close()

    def gate_counts(self, day: str) -> dict[str, int]:
        con = self._connection()
        try:
            return {r["gate"]: int(r["n"]) for r in con.execute("SELECT gate,n FROM daily_gate_counts WHERE day=? ORDER BY gate", (day,))}
        finally:
            con.close()

    def remember_identity(self, aliases: Iterable[str], outcome: str, module: str, day: str) -> None:
        """Identifier-only memory for off_topic/rejected results: no title, text or snippet.

        Profile-level outcomes are keyed to the module; paper-level outcomes to '*'.
        Anything else (e.g. a request's private exclusion) is never remembered.
        """
        values = sorted(set(aliases))
        if not values:
            return
        if outcome in PAPER_LEVEL_OUTCOMES:
            module = "*"
        elif outcome not in PROFILE_LEVEL_OUTCOMES:
            return
        con = self._connection()
        try:
            con.executemany("INSERT OR IGNORE INTO screened_out(alias,outcome,module,day,recorded_at) VALUES(?,?,?,?,?)",
                            [(a, outcome[:40], module[:80], day, _utc_now()) for a in values])
        finally:
            con.close()

    def screened_candidate_for(self, aliases: Iterable[str], module: str) -> str | None:
        values = tuple(sorted(set(aliases)))
        if not values:
            return None
        con = self._connection()
        try:
            row = con.execute("SELECT c.candidate_id FROM identity_aliases a JOIN candidates c ON c.candidate_id=a.candidate_id "
                              "WHERE a.alias IN (%s) AND c.status='screened' AND c.legacy_flag IS NULL AND c.module=? LIMIT 1" % ",".join("?" * len(values)),
                              (*values, module)).fetchone()
            return None if row is None else row["candidate_id"]
        finally:
            con.close()

    def acquire_lease(self, name: str, owner: str, *, seconds: int = 240) -> bool:
        now = time.time()
        con = self._connection()
        try:
            con.execute("BEGIN IMMEDIATE")
            row = con.execute("SELECT owner, expires_at FROM leases WHERE name=?", (name,)).fetchone()
            if row and row["expires_at"] > now and row["owner"] != owner:
                con.execute("ROLLBACK")
                return False
            con.execute("INSERT INTO leases(name,owner,expires_at) VALUES(?,?,?) ON CONFLICT(name) DO UPDATE SET owner=excluded.owner,expires_at=excluded.expires_at", (name, owner, now + seconds))
            con.execute("COMMIT")
            return True
        except Exception:
            if con.in_transaction:
                con.execute("ROLLBACK")
            raise
        finally:
            con.close()

    def release_lease(self, name: str, owner: str) -> None:
        con = self._connection()
        try:
            con.execute("DELETE FROM leases WHERE name=? AND owner=?", (name, owner))
        finally:
            con.close()

    def configure_method_map(self, method_map: Mapping[str, Any]) -> dict[str, Any]:
        """Durably initialize the authoritative order or block an unsafe remap."""
        order, map_hash = list(method_map["order"]), str(method_map["hash"])
        con = self._connection()
        try:
            con.execute("BEGIN IMMEDIATE")
            current = con.execute("SELECT * FROM method_map_state WHERE singleton=1").fetchone()
            if current is None:
                con.execute("INSERT INTO method_map_state VALUES(1,?,?,?,?,?,?)", (
                    map_hash, method_map.get("source_sha256"), json.dumps(order, ensure_ascii=False),
                    order[0], "active", _utc_now()))
                con.execute("COMMIT")
                return {"state": "initialized", "next_module": order[0], "hash": map_hash, "order": order}
            old_order = json.loads(current["order_json"])
            if current["map_hash"] != map_hash:
                # A cursor means the predecessor relationship is meaningful.  Do not guess
                # how to translate it after a router order change.
                con.execute("UPDATE method_map_state SET state=?,updated_at=? WHERE singleton=1", (
                    "map_change_blocked", _utc_now()))
                con.execute("COMMIT")
                raise HarvestError("method_map_changed", "Stored method-map cursor requires explicit reconciliation")
            if current["next_module"] not in order or old_order != order:
                con.execute("UPDATE method_map_state SET state=?,updated_at=? WHERE singleton=1", (
                    "map_change_blocked", _utc_now()))
                con.execute("COMMIT")
                raise HarvestError("method_map_changed", "Stored method-map order is inconsistent")
            con.execute("UPDATE method_map_state SET state=?,updated_at=? WHERE singleton=1", ("active", _utc_now()))
            con.execute("COMMIT")
            return {"state": "active", "next_module": current["next_module"], "hash": map_hash, "order": order}
        except Exception:
            if con.in_transaction:
                con.execute("ROLLBACK")
            raise
        finally:
            con.close()

    def map_status(self) -> dict[str, Any] | None:
        con = self._connection()
        try:
            row = con.execute("SELECT map_hash,source_sha256,order_json,next_module,state,updated_at FROM method_map_state WHERE singleton=1").fetchone()
            return None if row is None else {"hash": row["map_hash"], "source_sha256": row["source_sha256"],
                "order": json.loads(row["order_json"]), "next_module": row["next_module"],
                "state": row["state"], "updated_at": row["updated_at"]}
        finally:
            con.close()

    def record_module_event(self, day: str, module: str, map_hash: str, outcome: str, detail: str = "") -> None:
        if outcome not in {"deferred", "missing", "accepted"}:
            raise HarvestError("invalid_module_event", "Module event outcome is not supported")
        con = self._connection()
        try:
            con.execute("INSERT OR IGNORE INTO module_events VALUES(?,?,?,?,?,?)", (
                day, module, map_hash, outcome, detail[:160], _utc_now()))
        finally:
            con.close()

    def add_candidate(self, record: Mapping[str, Any], *, day: str, quota: int,
                      map_hash: str | None = None, next_module: str | None = None,
                      request_id: str | None = None) -> tuple[bool, str | None]:
        """Atomically insert a fresh candidate; only ``screened`` is counted.  Returns (stored, reason)."""
        aliases = _identifiers(record)
        if not aliases:
            return False, "missing_identifier"
        con = self._connection()
        try:
            con.execute("BEGIN IMMEDIATE")
            duplicate = con.execute("SELECT candidate_id FROM identity_aliases WHERE alias IN (%s) LIMIT 1" % ",".join("?" * len(aliases)), tuple(sorted(aliases))).fetchone()
            if duplicate:
                con.execute("ROLLBACK")
                return False, "duplicate_identity"
            status = str(record.get("status", "metadata_only"))
            counts_toward_quota = status == "screened"
            if counts_toward_quota and self._count(con, day) >= quota:
                con.execute("ROLLBACK")
                return False, "daily_quota_reached"
            if counts_toward_quota and request_id is not None and self._request_slots_used(con, day) >= REQUEST_DAILY_SLOTS:
                con.execute("ROLLBACK")
                return False, "request_slots_exhausted"
            candidate_id = "H-" + uuid.uuid4().hex[:16]
            con.execute("INSERT INTO candidates(candidate_id,title,module,status,flags_json,provenance_json,record_json,created_at,legacy_flag,pipeline) VALUES(?,?,?,?,?,?,?,?,NULL,?)", (candidate_id, str(record.get("title") or "Untitled"), str(record.get("module") or "unassigned"), status, json.dumps(record.get("flags", []), ensure_ascii=False), json.dumps(record.get("provenance", {}), ensure_ascii=False), json.dumps(dict(record), ensure_ascii=False), _utc_now(), "v2"))
            con.executemany("INSERT INTO identity_aliases(alias,candidate_id) VALUES(?,?)", [(a, candidate_id) for a in aliases])
            if request_id is not None:
                con.execute("INSERT INTO request_links(request_id,candidate_id,day,counted,linked_at) VALUES(?,?,?,?,?)", (
                    request_id, candidate_id, day, int(counts_toward_quota), _utc_now()))
            if counts_toward_quota:
                con.execute("INSERT INTO daily_ledger(day,candidate_id,counted_at) VALUES(?,?,?)", (day, candidate_id, _utc_now()))
                if map_hash is not None:
                    state = con.execute("SELECT map_hash,state FROM method_map_state WHERE singleton=1").fetchone()
                    if state is None or state["map_hash"] != map_hash or state["state"] != "active" or not next_module:
                        raise HarvestError("method_map_changed", "Method-map state changed before quota checkpoint")
                    con.execute("UPDATE method_map_state SET next_module=?,updated_at=? WHERE singleton=1", (next_module, _utc_now()))
            con.execute("COMMIT")
            return True, candidate_id
        except Exception:
            if con.in_transaction:
                con.execute("ROLLBACK")
            raise
        finally:
            con.close()

    def record_run(self, day: str, state: str, detail: Mapping[str, Any]) -> None:
        con = self._connection()
        try:
            con.execute("INSERT INTO daily_runs(day,state,detail_json,updated_at) VALUES(?,?,?,?) ON CONFLICT(day) DO UPDATE SET state=excluded.state,detail_json=excluded.detail_json,updated_at=excluded.updated_at", (day, state, json.dumps(dict(detail), ensure_ascii=False), _utc_now()))
        finally:
            con.close()

    def status(self) -> dict[str, Any]:
        day = _day()
        con = self._connection()
        try:
            count = self._count(con, day)
            last = con.execute("SELECT day,state,detail_json,updated_at FROM daily_runs ORDER BY day DESC LIMIT 1").fetchone()
            map_row = con.execute("SELECT map_hash,source_sha256,order_json,next_module,state,updated_at FROM method_map_state WHERE singleton=1").fetchone()
            map_status = None if map_row is None else {"hash": map_row["map_hash"], "source_sha256": map_row["source_sha256"],
                "order": json.loads(map_row["order_json"]), "next_module": map_row["next_module"],
                "state": map_row["state"], "updated_at": map_row["updated_at"]}
            by_status = {r["status"]: int(r["n"]) for r in con.execute("SELECT status, count(*) n FROM candidates WHERE legacy_flag IS NULL GROUP BY status")}
            legacy = int(con.execute("SELECT count(*) FROM candidates WHERE legacy_flag IS NOT NULL").fetchone()[0])
            requests = {r["status"]: int(r["n"]) for r in con.execute("SELECT status, count(*) n FROM literature_requests GROUP BY status")}
            recent = [{"day": r["day"], "state": r["state"], "shortfall": json.loads(r["detail_json"]).get("shortfall")}
                      for r in con.execute("SELECT day,state,detail_json FROM daily_runs ORDER BY day DESC LIMIT 7")]
            gates = {r["gate"]: int(r["n"]) for r in con.execute("SELECT gate,n FROM daily_gate_counts WHERE day=?", (day,))}
            return {"day": day, "quota": DAILY_QUOTA, "quota_basis": "screened_only", "actual_count": count,
                    "remaining": max(0, DAILY_QUOTA - count), "shortfall_today": max(0, DAILY_QUOTA - count),
                    "gate_counts_today": gates, "recent_days": recent,
                    "last_outcome": None if not last else {"day": last["day"], "state": last["state"], "detail": json.loads(last["detail_json"]), "updated_at": last["updated_at"]},
                    "backlog": int(sum(by_status.values())), "candidates_by_status": by_status,
                    "legacy_v1_unscreened": legacy, "literature_requests": requests,
                    "request_daily_slots": REQUEST_DAILY_SLOTS, "method_map": map_status}
        finally:
            con.close()

    def day_count(self, day: str) -> int:
        """Count candidates already credited to an explicit Shanghai day."""
        con = self._connection()
        try:
            return self._count(con, day)
        finally:
            con.close()

    def cursor(self, module: str) -> str | None:
        con = self._connection()
        try:
            row = con.execute("SELECT cursor FROM query_cursors WHERE module=?", (module,)).fetchone()
            return None if not row else row["cursor"]
        finally:
            con.close()

    def set_cursor(self, module: str, cursor: str) -> None:
        if not cursor or len(cursor) > 512:
            return
        con = self._connection()
        try:
            con.execute("INSERT INTO query_cursors(module,cursor,updated_at) VALUES(?,?,?) ON CONFLICT(module) DO UPDATE SET cursor=excluded.cursor,updated_at=excluded.updated_at", (module, cursor, _utc_now()))
        finally:
            con.close()

    def gt103_unavailable(self, day: str) -> bool:
        con = self._connection()
        try:
            row = con.execute("SELECT available FROM route_probes WHERE day=? AND route='gt103'", (day,)).fetchone()
            return bool(row is not None and not row["available"])
        finally:
            con.close()

    def record_gt103_probe(self, day: str, available: bool) -> None:
        con = self._connection()
        try:
            con.execute("INSERT INTO route_probes(day,route,available,checked_at) VALUES(?,?,?,?) ON CONFLICT(day,route) DO UPDATE SET available=excluded.available,checked_at=excluded.checked_at", (day, "gt103", int(available), _utc_now()))
        finally:
            con.close()

    def list_candidates(self, module: str | None = None, limit: int = 10, offset: int = 0,
                        include_legacy: bool = False) -> dict[str, Any]:
        limit, offset = max(1, min(int(limit), 100)), max(0, int(offset))
        con = self._connection()
        try:
            clauses, args = [], []
            if module is not None:
                clauses.append("module=?")
                args.append(module)
            if not include_legacy:
                clauses.append("legacy_flag IS NULL")
            where = (" WHERE " + " AND ".join(clauses)) if clauses else ""
            total = int(con.execute("SELECT count(*) FROM candidates" + where, args).fetchone()[0])
            rows = con.execute("SELECT candidate_id,title,module,status,flags_json,provenance_json,legacy_flag FROM candidates" + where + " ORDER BY created_at,candidate_id LIMIT ? OFFSET ?", [*args, limit, offset]).fetchall()
            items = [{"candidate_id": r["candidate_id"], "title": r["title"], "module": r["module"], "status": r["status"],
                      "flags": json.loads(r["flags_json"]) + ([r["legacy_flag"]] if r["legacy_flag"] else []),
                      "legacy_flag": r["legacy_flag"], "provenance": json.loads(r["provenance_json"]),
                      "review_state": "unreviewed_machine_screened" if r["status"] == "screened" else "unreviewed"} for r in rows]
            return {"items": items, "total": total, "include_legacy": bool(include_legacy),
                    "legacy_note": "legacy_v1_unscreened candidates are hidden unless include_legacy=true; they never passed the v2 whitelist/method-signal gates.",
                    "next_offset": offset+len(items) if offset+len(items) < total else None}
        finally:
            con.close()

    def search_screened(self, term_groups: list[tuple[str, ...]], module: str | None, limit: int, offset: int) -> dict[str, Any]:
        """Discovery column: v2 ``screened`` candidates only (legacy/metadata_only never appear)."""
        con = self._connection()
        try:
            args: list[Any] = []
            where = "status='screened' AND legacy_flag IS NULL"
            if module:
                where += " AND module=?"
                args.append(module)
            rows = con.execute("SELECT candidate_id,record_json,created_at FROM candidates WHERE " + where + " ORDER BY created_at DESC, candidate_id", args).fetchall()
        finally:
            con.close()
        hits = []
        for row in rows:
            record = json.loads(row["record_json"])
            signal = record.get("signal") or {}
            text = " ".join(str(x) for x in (record.get("title"), record.get("journal"), record.get("module"), signal.get("snippet"), signal.get("matched"))).casefold()
            if term_groups and not all(any(term in text for term in group) for group in term_groups):
                continue
            hits.append({"column": "discovery", "label": "unreviewed_machine_screened", "candidate_id": row["candidate_id"],
                         "title": str(record.get("title"))[:360], "journal": record.get("journal"), "journal_tier": record.get("journal_tier"),
                         "year": record.get("year"), "module": record.get("module"), "doi": record.get("doi"), "pmid": record.get("pmid"),
                         "pmcid": record.get("pmcid"), "signal_snippet": signal.get("snippet"),
                         "locator": {"section_id": signal.get("section_id"), "section_path": signal.get("section_path")},
                         "screened_at": row["created_at"]})
        page = hits[offset:offset + limit]
        return {"label": "unreviewed_machine_screened", "total": len(hits), "offset": offset,
                "next_offset": offset + limit if offset + limit < len(hits) else None, "results": page}

    def get_candidate(self, candidate_id: str) -> dict[str, Any]:
        con = self._connection()
        try:
            row = con.execute("SELECT record_json,status,legacy_flag FROM candidates WHERE candidate_id=?", (candidate_id,)).fetchone()
            if not row:
                return {"error": "not_found", "candidate_id": candidate_id}
            record = json.loads(row["record_json"])
            record["candidate_id"] = candidate_id
            record["status"] = row["status"]
            if row["legacy_flag"]:
                record["legacy_flag"] = row["legacy_flag"]
                record["flags"] = list(record.get("flags", [])) + [row["legacy_flag"]]
            record["review_state"] = "unreviewed_machine_screened" if row["status"] == "screened" and not row["legacy_flag"] else "unreviewed"
            return record
        finally:
            con.close()

    def has_identity(self, aliases: Iterable[str], module: str | None = None) -> bool:
        """Known candidate (any module), or remembered rejection for this module or for every module ('*')."""
        values = tuple(sorted(set(aliases)))
        if not values:
            return False
        marks = ",".join("?" * len(values))
        con = self._connection()
        try:
            return (con.execute("SELECT 1 FROM identity_aliases WHERE alias IN (%s) LIMIT 1" % marks, values).fetchone() is not None
                    or con.execute("SELECT 1 FROM screened_out WHERE alias IN (%s) AND module IN (?, '*') LIMIT 1" % marks,
                                   (*values, module if module is not None else "*")).fetchone() is not None)
        finally:
            con.close()

    # --------------------------------------------------- literature requests
    def _request_slots_used(self, con: sqlite3.Connection, day: str) -> int:
        return int(con.execute("SELECT count(*) FROM request_links WHERE day=? AND counted=1", (day,)).fetchone()[0])

    def request_slots_used(self, day: str) -> int:
        con = self._connection()
        try:
            return self._request_slots_used(con, day)
        finally:
            con.close()

    def link_existing(self, request_id: str, candidate_id: str, day: str) -> bool:
        con = self._connection()
        try:
            return con.execute("INSERT OR IGNORE INTO request_links(request_id,candidate_id,day,counted,linked_at) VALUES(?,?,?,0,?)",
                               (request_id, candidate_id, day, _utc_now())).rowcount == 1
        finally:
            con.close()

    def accepted_profiles(self) -> list[dict[str, Any]]:
        con = self._connection()
        try:
            return [{"profile_key": r["profile_key"], "profile": json.loads(r["profile_json"]), "source_proposal_id": r["source_proposal_id"]}
                    for r in con.execute("SELECT * FROM accepted_profiles WHERE active=1 ORDER BY accepted_at, profile_key")]
        finally:
            con.close()

    def profile_key_taken(self, profile_key: str) -> bool:
        con = self._connection()
        try:
            return con.execute("SELECT 1 FROM accepted_profiles WHERE profile_key=?", (profile_key,)).fetchone() is not None
        finally:
            con.close()

    def deactivate_profile(self, profile_key: str) -> None:
        con = self._connection()
        try:
            con.execute("UPDATE accepted_profiles SET active=0 WHERE profile_key=?", (profile_key,))
        finally:
            con.close()

    def add_accepted_profile(self, profile_key: str, profile: Mapping[str, Any], proposal_id: str, curator: str) -> None:
        con = self._connection()
        try:
            con.execute("INSERT INTO accepted_profiles(profile_key,profile_json,source_proposal_id,accepted_by,accepted_at,active) VALUES(?,?,?,?,?,1)",
                        (profile_key, json.dumps(dict(profile), ensure_ascii=False, sort_keys=True), proposal_id, curator, _utc_now()))
        finally:
            con.close()


class _NoUnsafeRedirect(HTTPRedirectHandler):
    def __init__(self) -> None:
        super().__init__()
        self.redirects = 0

    def redirect_request(self, req: Request, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> Request | None:
        self.redirects += 1
        if self.redirects > 3:
            raise HarvestError("too_many_redirects", "Official request exceeded three redirects")
        if urlparse(newurl).scheme != "https" or urlparse(newurl).hostname not in ALLOWED_HOSTS:
            raise HarvestError("unsafe_redirect", "Redirect target is not an approved official HTTPS host")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _validate_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS:
        raise HarvestError("unsafe_url", "Only approved official HTTPS endpoints may be requested")


def _direct_fetch(url: str, *, timeout: int = REQUEST_TIMEOUT_SECONDS) -> bytes:
    _validate_url(url)
    request = Request(url, headers={"User-Agent": "omicstat-reference-harvester/1.0 (review-only)"})
    try:
        with build_opener(_NoUnsafeRedirect()).open(request, timeout=timeout) as response:
            body = response.read(MAX_BODY_BYTES + 1)
    except (HTTPError, URLError, TimeoutError) as exc:
        raise HarvestError("network_failure", str(exc)) from exc
    if len(body) > MAX_BODY_BYTES:
        raise HarvestError("body_too_large", "Official response exceeded bounded body limit")
    return body


def _gt103_fetch(url: str, *, timeout: int = REQUEST_TIMEOUT_SECONDS) -> bytes:
    """Read-only fixed-host adapter. It receives only a locally allowlisted URL."""
    _validate_url(url)
    remote = ("import sys,urllib.request,urllib.parse,urllib.error\n"
              "u=" + repr(url) + "\nallowed={'www.ebi.ac.uk','europepmc.org','eutils.ncbi.nlm.nih.gov','pmc.ncbi.nlm.nih.gov'}\n"
              "class H(urllib.request.HTTPRedirectHandler):\n"
              " count=0\n"
              " def redirect_request(self,req,fp,code,msg,h,new):\n"
              "  self.count+=1\n"
              "  if self.count>3: raise ValueError('redirect limit')\n"
              "  p=urllib.parse.urlparse(new)\n"
              "  if p.scheme!='https' or p.hostname not in allowed: raise ValueError('unsafe redirect')\n"
              "  return super().redirect_request(req,fp,code,msg,h,new)\n"
              "try:\n"
              " r=urllib.request.build_opener(H()).open(urllib.request.Request(u,headers={'User-Agent':'omicstat-reference-harvester/1.0'}),timeout=" + str(timeout) + ")\n"
              " sys.stdout.buffer.write(r.read(" + str(MAX_BODY_BYTES + 1) + "))\n"
              "except urllib.error.HTTPError as e:\n sys.stderr.write('MREF_HTTP:'+str(e.code)); sys.exit(42)\n"
              "except (urllib.error.URLError,TimeoutError,OSError):\n sys.stderr.write('MREF_NETWORK'); sys.exit(43)\n"
              "except ValueError:\n sys.stderr.write('MREF_REDIRECT'); sys.exit(44)\n")
    cmd = [r"C:\Windows\System32\OpenSSH\ssh.exe", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=8", "-o", "ConnectionAttempts=1", "-o", "IdentitiesOnly=yes", "-i", r"C:\Users\<user>\.ssh\id_ed25519", "<user>@<analysis-host>", "python3 -"]
    try:
        result = subprocess.run(cmd, input=remote.encode("utf-8"), capture_output=True, timeout=timeout + 12, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise HarvestError("gt103_unavailable", "Fixed GT103 read-only adapter unavailable") from exc
    if result.returncode in {42, 43}:
        # SSH succeeded: a missing/fulltext endpoint is not a dead GT103 host.
        raise HarvestError("network_failure", "Official endpoint failed via reachable GT103")
    if result.returncode == 44:
        raise HarvestError("unsafe_redirect", "Official endpoint redirect was rejected on GT103")
    if result.returncode:
        raise HarvestError("gt103_unavailable", "Fixed GT103 read-only adapter unavailable")
    if len(result.stdout) > MAX_BODY_BYTES:
        raise HarvestError("body_too_large", "Official response exceeded bounded body limit")
    return result.stdout


def _fetch_with_retry(fetch: Callable[[str], bytes], url: str) -> bytes:
    try:
        return fetch(url)
    except HarvestError as exc:
        if exc.code not in {"network_failure"}:
            raise
        return fetch(url)  # one selective transient retry


def _clean_text(element: ET.Element | None) -> str:
    if element is None:
        return ""
    return re.sub(r"\s+", " ", "".join(element.itertext())).strip()


def _parse_jats(raw: bytes, expected: Mapping[str, Any]) -> dict[str, Any]:
    """v1 excerpt extractor (kept for compatibility); v2 screening uses discovery.screen_article."""
    article, seen, source_sha256 = _load_jats_article(raw, expected)
    return _v1_excerpts(article, seen, source_sha256)


def _load_jats_article(raw: bytes, expected: Mapping[str, Any]) -> tuple[ET.Element, dict[str, str], str]:
    """Securely parse JATS and verify identifiers against discovery metadata."""
    source_sha256 = hashlib.sha256(raw).hexdigest()
    # PMC efetch commonly includes the well-known JATS public declaration.
    # It is never fetched or resolved: we remove precisely that declaration
    # before stdlib parsing. Any entity declaration or other DOCTYPE is unsafe.
    if re.search(br"<!ENTITY", raw[:8192], re.I):
        raise HarvestError("unsafe_xml", "XML entity declarations are rejected")
    doctype = re.search(br"<!DOCTYPE\s+article\s+[^>]*>", raw[:8192], re.I)
    if doctype:
        declared = doctype.group(0).lower()
        if b"-//nlm//dtd jats" not in declared or b"public" not in declared or b"[" in declared:
            raise HarvestError("unsafe_xml", "Only a standard JATS public declaration may be ignored")
        raw = raw[:doctype.start()] + raw[doctype.end():]
    elif re.search(br"<!DOCTYPE", raw[:8192], re.I):
        raise HarvestError("unsafe_xml", "Unexpected DOCTYPE is rejected")
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as exc:
        raise HarvestError("invalid_jats", "Full-text response was not valid JATS XML") from exc
    article = root if root.tag.rsplit("}", 1)[-1] == "article" else root.find(".//article")
    if article is None:
        raise HarvestError("invalid_jats", "No JATS article element")
    seen: dict[str, str] = {}
    for e in article.findall("./front/article-meta/article-id"):
        value, kind = _clean_text(e), e.get("pub-id-type", "").lower()
        if value:
            seen[kind] = value
    expected_values = {k: _norm_identifier(expected.get(k)) for k in ("doi", "pmid", "pmcid")}
    actual_values = {"doi": _norm_identifier(seen.get("doi")), "pmid": _norm_identifier(seen.get("pmid")), "pmcid": _norm_identifier(seen.get("pmc") or seen.get("pmcid"))}
    expected_ids = {v for v in expected_values.values() if v}
    actual_ids = {v for v in actual_values.values() if v}
    if expected_ids and not actual_ids:
        raise HarvestError("missing_jats_identifier", "JATS has no identifier for metadata verification")
    if any(expected_values[key] and actual_values[key] and expected_values[key] != actual_values[key] for key in expected_values):
        raise HarvestError("identifier_mismatch", "A same-kind JATS identifier conflicts with discovery metadata")
    if expected_ids and not (expected_ids & actual_ids):
        raise HarvestError("identifier_mismatch", "JATS identifiers do not match discovery metadata")
    return article, seen, source_sha256


def _v1_excerpts(article: ET.Element, seen: dict[str, str], source_sha256: str) -> dict[str, Any]:
    body = article.find("./body")
    if body is None or not _clean_text(body):
        raise HarvestError("headers_only_fulltext", "JATS front matter/abstract alone is not full text")
    permission_node = article.find("./front/article-meta/permissions")
    permissions = _clean_text(permission_node)
    links = [] if permission_node is None else [v for e in permission_node.iter() for k, v in e.attrib.items() if k.rsplit("}", 1)[-1].endswith("href")]
    rights_ok = "creative commons" in permissions.lower() or any("creativecommons.org/licenses/" in link.lower() for link in links) or "text mining" in permissions.lower()
    excerpts: list[dict[str, Any]] = []
    captions: list[dict[str, Any]] = []
    remaining = 25
    sections = sorted(body.findall(".//sec"), key=lambda sec: (
        0 if re.search(r"statistic|analysis|analyses", _clean_text(sec.find("./title")), re.I)
        else 1 if METHOD_HEADING.search(_clean_text(sec.find("./title"))) else 2))
    for sec in sections:
        heading = _clean_text(sec.find("./title"))
        # Mentioning a prior analysis in the Introduction is not methods evidence.
        if not METHOD_HEADING.search(heading):
            continue
        paragraphs = [_clean_text(p) for p in sec.findall("./p")]
        relevant = [p for p in paragraphs if METHOD_WORDS.search(p)]
        text = " ".join(relevant or paragraphs)
        if not text:
            continue
        if remaining <= 0:
            break
        words = text.split()[:remaining]
        quote = " ".join(words)
        if quote:
            excerpts.append({"section_id": sec.get("id"), "section_title": heading, "quote": quote, "word_count": len(words), "method_signals": sorted(set(x.lower() for x in METHOD_WORDS.findall(text)))[:8], "numeric_tokens": NUMERIC.findall(text)[:8]})
            remaining -= len(words)
    for cap in body.findall(".//fig/caption") + body.findall(".//table-wrap/caption"):
        text = _clean_text(cap)
        if text and METHOD_WORDS.search(text):
            captions.append({"locator": cap.get("id"), "method_signals": sorted(set(x.lower() for x in METHOD_WORDS.findall(text)))[:8], "numeric_tokens": NUMERIC.findall(text)[:8]})
    return {"jats_identifiers": seen, "license_links": links[:8], "rights_confirmed": rights_ok,
            "extraction_version": EXTRACTION_VERSION,
            "method_excerpts": excerpts if rights_ok else [],
            "caption_candidates": captions[:3] if rights_ok else [],
            "fulltext_sha256": source_sha256}


def _record_from_result(result: Mapping[str, Any], module: str, route: str, retrieval_time: str,
                        meta: Mapping[str, Any]) -> dict[str, Any] | None:
    """Identifier/metadata record for a whitelisted result; never contains article text."""
    source = str(result.get("source") or result.get("src") or "")
    if source != "MED":
        return None
    record = {"title": str(result.get("title") or "").strip()[:600], "doi": result.get("doi"),
              "pmid": result.get("pmid") or (result.get("id") if source == "MED" else None), "pmcid": result.get("pmcid"),
              "journal": meta.get("journal_name"), "journal_tier": meta.get("journal_tier"),
              "journal_secondary_tier": meta.get("journal_secondary_tier"), "issns": list(meta.get("issns", [])),
              "year": str(result.get("pubYear") or ""), "module": module}
    if (record["pmcid"] and not re.fullmatch(r"PMC\d+", str(record["pmcid"]), re.I)) or (record["pmid"] and not str(record["pmid"]).isdigit()) or not _identifiers(record):
        return None
    record.update({"status": "metadata_only", "flags": ["unreviewed", "metadata_only"], "screening_version": SCREENING_VERSION,
                   "provenance": {"discovery_source": "Europe PMC REST", "source": source, "route": route, "retrieved_at": retrieval_time},
                   "metadata_sha256": hashlib.sha256(json.dumps(dict(result), sort_keys=True).encode()).hexdigest(),
                   "retrieval_time": retrieval_time, "rights": "unknown"})
    return record


class _Run:
    """Per-invocation budget, counters and fetch routing."""
    def __init__(self, store: HarvestStore, day: str, *, transport: str, max_requests: int,
                 fetcher: Callable[[str], bytes] | None):
        self.store, self.day, self.transport, self.max_requests, self.fetcher = store, day, transport, max_requests, fetcher
        self.started = time.monotonic()
        self.request_count = 0
        self.route = transport
        self.gt_failed = store.gt103_unavailable(day) if transport == "gt103" else False
        self.gates: dict[str, int] = {}
        self.errors: list[str] = []

    def budget_left(self) -> bool:
        return self.request_count < self.max_requests and time.monotonic() - self.started < MAX_RUNTIME_SECONDS

    def count(self, gate: str, n: int = 1) -> None:
        self.gates[gate] = self.gates.get(gate, 0) + n

    def fetch(self, url: str) -> bytes:
        _validate_url(url)
        if not self.budget_left():
            raise HarvestError("budget_exhausted", "Request or elapsed-runtime bound reached")
        self.request_count += 1
        if self.fetcher is not None:
            body = self.fetcher(url)
        elif self.transport == "gt103" and not self.gt_failed:
            try:
                self.route = "gt103"
                body = _gt103_fetch(url)
            except HarvestError as exc:
                if exc.code != "gt103_unavailable":
                    raise
                self.gt_failed, self.route = True, "direct"
                self.store.record_gt103_probe(self.day, False)
                if not self.budget_left():
                    raise HarvestError("budget_exhausted", "No budget remains for GT103 direct fallback")
                self.request_count += 1
                body = _direct_fetch(url)
        else:
            self.route = "direct"
            body = _direct_fetch(url)
        if len(body) > MAX_BODY_BYTES:
            raise HarvestError("body_too_large", "Response exceeded bounded body limit")
        return body


def _search(run: _Run, query: str, cursor: str | None) -> dict[str, Any]:
    # EPMC returns a version-only payload for unsupported sort values; the
    # live-supported search syntax is sort_date:y within the query.
    args: dict[str, Any] = {"query": query + " sort_date:y", "format": "json", "pageSize": PAGE_SIZE, "resultType": "core",
                            "cursorMark": cursor or "*"}
    url = "https://www.ebi.ac.uk/europepmc/webservices/rest/search?" + urlencode(args)
    payload = json.loads(_fetch_with_retry(run.fetch, url).decode("utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("resultList"), dict) or not isinstance(payload["resultList"].get("result"), list):
        raise HarvestError("invalid_search_response", "Official search did not return a result list; do not interpret this as zero papers")
    return payload


def _fetch_fulltext(run: _Run, pmcid: str) -> tuple[bytes, str]:
    url = "https://www.ebi.ac.uk/europepmc/webservices/rest/" + pmcid.upper() + "/fullTextXML"
    try:
        return _fetch_with_retry(run.fetch, url), "Europe PMC fullTextXML"
    except HarvestError as primary_error:
        # NCBI PMC efetch is an official fallback for a transient Europe PMC
        # retrieval failure, never a route taken from paper text.
        if primary_error.code != "network_failure":
            raise
        fallback = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?" + urlencode({"db": "pmc", "id": pmcid.upper().replace("PMC", ""), "rettype": "xml"})
        return _fetch_with_retry(run.fetch, fallback), "NCBI PMC efetch"


def _tier_key(item: Any, journals: Mapping[str, Any]) -> int:
    if not isinstance(item, Mapping):
        return 9
    for issn in discovery.result_issns(item):
        if issn in journals["by_issn"]:
            return discovery.TIER_RANK[journals["by_issn"][issn]["tier"]]
    return 9


def _screen_one(run: _Run, item: Any, profile: Mapping[str, Any], journals: Mapping[str, Any], seed_ids: set[str],
                today: dt.date, *, exclusions: list[str] | None = None) -> tuple[str, dict[str, Any] | None, set[str]]:
    """Metadata gate -> (optional) full-text Methods gate.  Returns (outcome, record, identities).

    Outcomes: 'skip:<gate>' (nothing stored), 'forget:<gate>' (identifier-only memory),
    'metadata_only' (stored, not counted), 'screened' (stored, counted), 'retry' (transient).
    """
    if not isinstance(item, Mapping):
        return "skip:invalid_metadata", None, set()
    identities = _identifiers({"doi": item.get("doi"), "pmid": item.get("pmid") or item.get("id"), "pmcid": item.get("pmcid")})
    if not identities:
        return "skip:invalid_metadata", None, identities
    if identities & seed_ids or run.store.has_identity(identities, profile["module"]):
        return "skip:duplicate", None, identities
    verdict, meta = discovery.screen_metadata(item, profile, journals, today=today)
    if verdict == "off_whitelist":
        return "skip:off_whitelist", None, identities
    if verdict != "pass":
        return "forget:" + verdict, None, identities
    if exclusions:
        text = (str(item.get("title") or "") + " " + str(item.get("abstractText") or "")).casefold()
        if any(phrase in text for phrase in exclusions):
            # A request's private exclusion is never remembered (F-03): count only.
            return "skip:excluded_by_request", None, identities
    record = _record_from_result(item, profile["module"], run.route, _utc_now(), meta)
    if record is None:
        return "skip:invalid_metadata", None, identities
    pmcid = record.get("pmcid")
    if not pmcid:
        record["flags"].append("no_open_fulltext_identifier")
        return "metadata_only:no_pmcid", record, identities
    try:
        raw, source = _fetch_fulltext(run, str(pmcid))
        article, seen, sha = _load_jats_article(raw, record)
    except HarvestError as exc:
        if exc.code in {"identifier_mismatch", "unsafe_xml"}:
            return "forget:identity_rejected", None, identities
        if exc.code in {"budget_exhausted"}:
            raise
        if exc.code in {"network_failure", "gt103_unavailable", "body_too_large"}:
            run.errors.append(exc.code)
            return "retry:fulltext_error", None, identities
        record["flags"].append(exc.code)
        return "metadata_only:fulltext_error", record, identities
    record["provenance"].update({"fulltext_source": source, "route": run.route})
    record.update({"fulltext_sha256": sha, "jats_identifiers": seen})
    gate, detail = discovery.screen_article(article, profile)
    if gate == "screened":
        record.update({"status": "screened", "rights": "confirmed_for_limited_extraction", "licence": detail["licence"],
                       "signal": detail["signal"], "license_links": detail.get("license_links", []),
                       "flags": ["unreviewed_machine_screened", "snippet_limited_to_25_words", "human_applicability_review_required"]})
        return "screened", record, identities
    if gate == "off_topic":
        return "forget:off_topic", None, identities
    record["flags"].append(gate)
    if "licence" in detail:
        record["licence"] = detail["licence"]
    if gate == "rights_unconfirmed":
        record["rights"] = "unconfirmed"
    elif gate == "rights_restricted":
        record["rights"] = "tdm_restricted"
    return "metadata_only:" + gate, record, identities


def _consume_results(run: _Run, results: list[Any], profile: Mapping[str, Any], journals: Mapping[str, Any],
                     seed_ids: set[str], today: dt.date, *, quota: int, max_fulltext: int,
                     map_hash: str | None, next_module: str | None, request: Mapping[str, Any] | None = None,
                     request_want: int = 0) -> dict[str, Any]:
    """Walk one result page.  Stops after one screened item (rotation) or request_want items (request)."""
    fulltext_attempts, screened_ids, linked_existing, exhausted = 0, [], [], True
    exclusions = (request or {}).get("keywords", {}).get("exclusions") if request else None
    for item in sorted(results, key=lambda x: _tier_key(x, journals)):
        if run.store.day_count(run.day) >= quota or not run.budget_left():
            exhausted = False
            break
        if request is not None and len(screened_ids) + len(linked_existing) >= request_want:
            exhausted = False
            break
        if request is not None and isinstance(item, Mapping):
            ids = _identifiers({"doi": item.get("doi"), "pmid": item.get("pmid") or item.get("id"), "pmcid": item.get("pmcid")})
            existing = run.store.screened_candidate_for(ids, profile["module"])
            if existing:
                if run.store.link_existing(request["request_id"], existing, run.day):
                    linked_existing.append(existing)
                    run.count("linked_existing")
                continue
        if fulltext_attempts >= max_fulltext:
            exhausted = False
            break
        before = run.request_count
        try:
            outcome, record, identities = _screen_one(run, item, profile, journals, seed_ids, today, exclusions=exclusions)
        except HarvestError as exc:
            if exc.code == "budget_exhausted":
                run.errors.append("budget_exhausted")
                exhausted = False
                break
            raise
        if run.request_count > before:
            fulltext_attempts += 1
        kind, _, gate = outcome.partition(":")
        if kind == "skip":
            run.count(gate)
            continue
        if kind == "retry":
            run.count(gate)
            exhausted = False
            continue
        if kind == "forget":
            run.count(gate)
            run.store.remember_identity(identities, gate, profile["module"], run.day)
            continue
        if kind == "metadata_only":
            run.count(gate if gate in {"no_pmcid", "no_method_section", "rights_unconfirmed", "rights_restricted", "headers_only_fulltext"} else "fulltext_error")
            run.store.add_candidate(record, day=run.day, quota=quota, request_id=None)
            continue
        stored, reason = run.store.add_candidate(record, day=run.day, quota=quota, map_hash=map_hash, next_module=next_module,
                                                 request_id=None if request is None else request["request_id"])
        if stored:
            run.count("screened")
            screened_ids.append(reason)
            if request is None:
                exhausted = False
                break
        elif reason in {"daily_quota_reached", "request_slots_exhausted"}:
            exhausted = False
            break
        else:
            run.count("duplicate")
    return {"screened": screened_ids, "linked_existing": linked_existing, "page_exhausted": exhausted,
            "fulltext_attempts": fulltext_attempts}


def _serve_requests(run: _Run, journals: Mapping[str, Any], config: Mapping[str, Any], seed_ids: set[str],
                    today: dt.date, quota: int, now: dt.datetime | None) -> list[dict[str, Any]]:
    """Queue first: at most REQUEST_DAILY_SLOTS screened per day; unused slots return to rotation."""
    import literature_requests as lr
    served: list[dict[str, Any]] = []
    started_attempts = 0
    for req in lr.due_requests(run.store, run.day, now=now):
        slots = min(REQUEST_DAILY_SLOTS - run.store.request_slots_used(run.day), quota - run.store.day_count(run.day))
        if slots <= 0 or not run.budget_left():
            break
        # F-07: bound the request phase's network spend before an attempt is reserved, so
        # requests that are not started keep their attempt budget.  An attempt is started only
        # if its nominal worst case (1 search + MAX_FULLTEXT_PER_REQUEST fetches) still fits.
        if (started_attempts >= REQUEST_PHASE_MAX_ATTEMPTS
                or run.request_count + 1 + MAX_FULLTEXT_PER_REQUEST > REQUEST_PHASE_MAX_REQUESTS):
            break
        profile = config["profiles"].get(req["module"])
        if profile is None:
            continue
        if not lr.start_attempt(run.store, req["request_id"], run.day):
            continue
        started_attempts += 1
        before_gates = dict(run.gates)
        want = max(0, req["max_papers"] - lr.linked_count(run.store, req["request_id"]))
        detail: dict[str, Any] = {"query_terms": {"required": req["keywords"]["required"], "any_of": req["keywords"]["any_of"]},
                                  "hit_count": None, "examined": 0}
        try:
            query = discovery.build_query(profile, config, journals, today=today,
                                          keyword_mode=(req["keywords"]["required"], req["keywords"]["any_of"]))
            payload = _search(run, query, None)
            results = payload["resultList"]["result"]
            detail["hit_count"] = payload.get("hitCount")
            detail["examined"] = len(results)
            outcome = _consume_results(run, results, profile, journals, seed_ids, today, quota=quota,
                                       max_fulltext=MAX_FULLTEXT_PER_REQUEST, map_hash=None, next_module=None,
                                       request={**req}, request_want=want)
            detail.update({"screened_new": outcome["screened"], "linked_existing": outcome["linked_existing"]})
        except (HarvestError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            detail["error"] = getattr(exc, "code", "invalid_search_response")
            run.errors.append(detail["error"])
        detail["gate_counts"] = {k: run.gates.get(k, 0) - before_gates.get(k, 0) for k in run.gates if run.gates.get(k, 0) - before_gates.get(k, 0)}
        new_status = lr.finish_attempt(run.store, req["request_id"], run.day, detail)
        served.append({"request_id": req["request_id"], "module": req["module"], "status": new_status,
                       "screened_new": len(detail.get("screened_new", [])), "linked_existing": len(detail.get("linked_existing", [])),
                       "error": detail.get("error")})
    return served


def harvest_daily(store: HarvestStore, *, target: int = 10, transport: str = "gt103", seed_catalog: str | Path | Mapping[str, Any] | Iterable[str] | None = None, max_requests: int = 60, fetcher: Callable[[str], bytes] | None = None, now: dt.datetime | None = None, method_map_path: str | Path | None = None, profiles_path: str | Path | None = None, journals_path: str | Path | None = None) -> dict[str, Any]:
    """Serve literature requests, then rotate module profiles, until the day's screened quota.

    `fetcher` is a deterministic test seam and must still receive only approved
    official URLs.  The normal direct and GT routes are strictly allowlisted.
    """
    if not 1 <= int(target) <= 10:
        raise HarvestError("invalid_target", "target must be an integer from 1 through 10")
    if not 1 <= int(max_requests) <= 60:
        raise HarvestError("invalid_max_requests", "max_requests must be from 1 through 60")
    if transport not in {"gt103", "direct"}:
        raise HarvestError("invalid_transport", "transport must be gt103 or direct")
    day, owner = _day(now), uuid.uuid4().hex
    today = dt.date.fromisoformat(day)
    if not store.acquire_lease("harvest:" + day, owner):
        return {"day": day, "state": "already_running", "collected": 0, "target": target, "quota": DAILY_QUOTA}
    run = _Run(store, day, transport=transport, max_requests=int(max_requests), fetcher=fetcher)
    try:
        seed_ids = _seed_identifiers(seed_catalog)
        method_map = _load_method_map(method_map_path)
        try:
            config = discovery.load_profiles(profiles_path)
            journals = discovery.load_journals(journals_path)
        except discovery.DiscoveryError as exc:
            raise HarvestError(exc.code, exc.message) from exc
        if set(config["profiles"]) != set(method_map["order"]):
            raise HarvestError("method_map_profile_mismatch", "Method map and discovery profiles must name the same modules")
        map_state = store.configure_method_map(method_map)
        quota = min(DAILY_QUOTA, int(target))
        start_total = store.day_count(day)
        if start_total >= quota:
            result = {"day": day, "state": "quota_already_satisfied", "collected": 0, "daily_total": start_total, "target": quota,
                      "shortfall": 0, "shortage": 0, "requests": 0, "route": transport, "method_map": store.map_status()}
            store.record_run(day, result["state"], result)
            return result
        served = _serve_requests(run, journals, config, seed_ids, today, quota, now)
        order = method_map["order"]
        start_at = order.index(map_state["next_module"])
        rotation = [(m, config["profiles"][m], order[(order.index(m) + 1) % len(order)]) for m in order[start_at:] + order[:start_at]]
        # F-06: one accepted domain profile per cycle, after requests and before the method-map module
        # rotation, chosen by its own cursor; it never touches the method-map cursor.
        domain_key, domain_next = None, None
        extras = []
        for extra in store.accepted_profiles():
            try:
                extras.append((extra["profile_key"], discovery.validate_profile(extra["profile"])))
            except discovery.DiscoveryError:
                run.errors.append("invalid_accepted_profile")
        if extras:
            keys = [k for k, _ in extras]
            wanted = store.cursor(DOMAIN_CURSOR_KEY)
            index = keys.index(wanted) if wanted in keys else 0
            domain_key, domain_next = keys[index], keys[(index + 1) % len(keys)]
            rotation.insert(0, (domain_key, dict(extras)[domain_key], None))
        for module, profile, next_module in rotation:
            if store.day_count(day) >= quota:
                break
            if not run.budget_left():
                run.errors.append("budget_exhausted")
                break
            cursor_key = "v2:" + module
            try:
                payload = _search(run, discovery.build_query(profile, config, journals, today=today), store.cursor(cursor_key))
            except (HarvestError, UnicodeDecodeError, json.JSONDecodeError) as exc:
                code = getattr(exc, "code", "invalid_search_response")
                run.errors.append(code)
                if next_module is not None:
                    store.record_module_event(day, module, method_map["hash"], "deferred", code)
                if module == domain_key and code != "budget_exhausted":
                    store.set_cursor(DOMAIN_CURSOR_KEY, domain_next)
                if code == "budget_exhausted":
                    break
                continue
            results = payload["resultList"]["result"]
            outcome = _consume_results(run, results, profile, journals, seed_ids, today, quota=quota,
                                       max_fulltext=MAX_FULLTEXT_PER_MODULE,
                                       map_hash=method_map["hash"] if next_module else None, next_module=next_module)
            next_cursor = payload.get("nextCursorMark")
            if not results:
                store.set_cursor(cursor_key, "*")  # reached the end: start over at the newest page
            elif outcome["page_exhausted"] and isinstance(next_cursor, str):
                store.set_cursor(cursor_key, next_cursor)
            if next_module is not None:
                store.record_module_event(day, module, method_map["hash"], "accepted" if outcome["screened"] else "missing")
            if module == domain_key:
                store.set_cursor(DOMAIN_CURSOR_KEY, domain_next)
        store.add_gate_counts(day, run.gates)
        total = store.day_count(day)
        shortfall = max(0, quota - total)
        state = "completed" if shortfall == 0 else "shortage"
        result = {"day": day, "state": state, "collected": total - start_total, "daily_total": total, "target": quota,
                  "quota_basis": "screened_only", "shortfall": shortfall, "shortage": shortfall,
                  "requests": run.request_count, "route": run.route, "gt103_fallback": run.gt_failed,
                  "gate_counts": dict(sorted(run.gates.items())), "gate_counts_day": store.gate_counts(day),
                  "literature_requests_served": served, "errors": run.errors[:12],
                  "runtime_seconds": round(time.monotonic() - run.started, 3), "method_map": store.map_status()}
        store.record_run(day, state, result)
        return result
    finally:
        store.release_lease("harvest:" + day, owner)
