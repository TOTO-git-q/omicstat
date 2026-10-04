"""Curator-only promotion channel and new-domain registry.

Everything here writes *additive* tables in reference.sqlite.  The seed
``records``/``metadata`` tables are never modified.  Promotion and domain
decisions are CLI-only (administrator via ``docker exec``); the MCP surface can
only *propose* a domain, which changes no rotation, installs no code and
claims no analysis support.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
import uuid
from contextlib import closing
from pathlib import Path
from typing import Any, Callable, Mapping

import discovery
from backup import backup_data_dir
from safety import find_sensitive, strip_bibliographic_locators

import registry

MODULES_PATH = registry.METHOD_MAP_PATH
DOMAIN_KINDS = ("knowledge_domain", "method_family", "analysis_module_request")
ACCEPTABLE_KINDS = ("knowledge_domain", "method_family")
MAX_PROPOSAL_BYTES = 8192

SCHEMA = """
CREATE TABLE IF NOT EXISTS curation_state (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS reviewed_supplement (
  supplement_id TEXT PRIMARY KEY, review_id TEXT NOT NULL UNIQUE, candidate_id TEXT NOT NULL,
  modules_json TEXT NOT NULL, review_json TEXT NOT NULL, candidate_json TEXT NOT NULL, locator_json TEXT NOT NULL,
  curator TEXT NOT NULL, note TEXT, promoted_at TEXT NOT NULL, supplement_version INTEGER NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('active','demoted')), demoted_at TEXT, demoted_by TEXT,
  demote_reason TEXT, demoted_in_version INTEGER, searchable TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS domain_proposals (
  proposal_id TEXT PRIMARY KEY, digest TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, name TEXT NOT NULL,
  payload_json TEXT NOT NULL, status TEXT NOT NULL, created_at TEXT NOT NULL,
  decided_by TEXT, decided_at TEXT, decision_note TEXT
);
CREATE TABLE IF NOT EXISTS domain_taxonomy (
  entry_id TEXT PRIMARY KEY, proposal_id TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, name TEXT NOT NULL,
  curator TEXT NOT NULL, accepted_at TEXT NOT NULL, discovery_profile_key TEXT, profile_validation_json TEXT
);
"""


class CurationError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def known_modules() -> list[str]:
    return registry.module_order(MODULES_PATH)


def _connect(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(str(path), timeout=10, isolation_level=None)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA busy_timeout=10000")
    return con


def ensure_schema(data_dir: Path) -> Path:
    """Create the additive curation tables; back up /data first when upgrading an existing store."""
    path = Path(data_dir) / "reference.sqlite"
    if path.exists():
        with closing(_connect(path)) as con:
            tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "records" in tables and "reviewed_supplement" not in tables:
            backup_data_dir(Path(data_dir), "pre-v2-curation-schema")
    with closing(_connect(path)) as con:
        con.executescript(SCHEMA)
        con.execute("INSERT OR IGNORE INTO curation_state(key,value) VALUES('supplement_version','0')")
        con.execute("INSERT OR IGNORE INTO curation_state(key,value) VALUES('curation_schema','v2')")
    return path


def _clean_name(value: Any, field: str, limit: int, minimum: int = 1) -> str:
    if not isinstance(value, str) or not minimum <= len(value.strip()) <= limit:
        raise CurationError("invalid_input", f"{field} must be a string of {minimum}..{limit} characters")
    return value.strip()


# ------------------------------------------------------------------ reviews

def _reviews(data_dir: Path) -> list[sqlite3.Row]:
    path = Path(data_dir) / "reviews.sqlite"
    if not path.is_file():
        return []
    with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=10)) as con:
        con.row_factory = sqlite3.Row
        return con.execute("SELECT review_id,candidate_id,payload,created_at FROM proposals ORDER BY created_at, review_id").fetchall()


def list_reviews(data_dir: Path, harvest_store: Any, *, pending_only: bool = False) -> dict[str, Any]:
    ref = ensure_schema(data_dir)
    with closing(_connect(ref)) as con:
        promoted = {r["review_id"]: {"supplement_id": r["supplement_id"], "status": r["status"]}
                    for r in con.execute("SELECT review_id,supplement_id,status FROM reviewed_supplement")}
    items = []
    for row in _reviews(data_dir):
        candidate = harvest_store.get_candidate(row["candidate_id"])
        eligible = candidate.get("status") == "screened" and not candidate.get("legacy_flag")
        item = {"review_id": row["review_id"], "candidate_id": row["candidate_id"], "created_at": row["created_at"],
                "candidate_title": str(candidate.get("title", ""))[:200], "candidate_status": candidate.get("status"),
                "legacy_flag": candidate.get("legacy_flag"), "eligible_for_promotion": eligible and row["review_id"] not in promoted,
                "promotion": promoted.get(row["review_id"])}
        if pending_only and row["review_id"] in promoted:
            continue
        items.append(item)
    return {"reviews": items, "total": len(items), "pending_only": pending_only}


def promote(data_dir: Path, harvest_store: Any, *, review_id: str, curator: str, note: str | None = None) -> dict[str, Any]:
    curator = _clean_name(curator, "curator", 80)
    if note is not None and len(note) > 1000:
        raise CurationError("invalid_input", "note must be at most 1000 characters")
    match = next((r for r in _reviews(data_dir) if r["review_id"] == review_id), None)
    if match is None:
        raise CurationError("review_not_found", "No review proposal with that review_id (submit one with reference_submit_review first).")
    review = json.loads(match["payload"])
    required = {"reviewer", "source_locators", "findings", "limitations", "proposed_module_tags"}
    if not required.issubset(review) or not review.get("source_locators") or not review.get("findings"):
        raise CurationError("invalid_review", "Review proposal lacks the required fields.")
    candidate = harvest_store.get_candidate(match["candidate_id"])
    if candidate.get("error"):
        raise CurationError("candidate_not_found", "The reviewed candidate no longer exists.")
    if candidate.get("status") != "screened" or candidate.get("legacy_flag"):
        raise CurationError("candidate_not_screened", "Only v2 'screened' candidates can be promoted (status=%s, legacy=%s)." % (candidate.get("status"), candidate.get("legacy_flag")))
    valid = set(known_modules())
    modules = sorted({m for m in review.get("proposed_module_tags", []) if m in valid} | {candidate.get("module")} & valid)
    signal = candidate.get("signal") or {}
    snapshot = {k: candidate.get(k) for k in ("candidate_id", "title", "journal", "journal_tier", "year", "doi", "pmid", "pmcid", "module", "fulltext_sha256")}
    snapshot["signal_snippet"] = signal.get("snippet")
    locator = {"section_id": signal.get("section_id"), "section_path": signal.get("section_path"),
               "review_source_locators": review.get("source_locators", [])[:20]}
    searchable = " ".join(str(x) for x in [snapshot.get("title"), snapshot.get("journal"), " ".join(modules), signal.get("snippet"),
                                           " ".join(review.get("findings", [])), " ".join(review.get("limitations", []))]).casefold()
    ref = ensure_schema(data_dir)
    with closing(_connect(ref)) as con:
        con.execute("BEGIN IMMEDIATE")
        try:
            existing = con.execute("SELECT supplement_id FROM reviewed_supplement WHERE review_id=?", (review_id,)).fetchone()
            if existing:
                raise CurationError("already_promoted", f"Review {review_id} is already promoted as {existing['supplement_id']}.")
            version = int(con.execute("SELECT value FROM curation_state WHERE key='supplement_version'").fetchone()[0]) + 1
            supplement_id = "RS-" + uuid.uuid4().hex[:12]
            con.execute("INSERT INTO reviewed_supplement(supplement_id,review_id,candidate_id,modules_json,review_json,candidate_json,locator_json,curator,note,promoted_at,supplement_version,status,searchable) VALUES(?,?,?,?,?,?,?,?,?,?,?,'active',?)", (
                supplement_id, review_id, match["candidate_id"], json.dumps(modules), json.dumps(review, ensure_ascii=False, sort_keys=True),
                json.dumps(snapshot, ensure_ascii=False, sort_keys=True), json.dumps(locator, ensure_ascii=False), curator, note, _now(), version, searchable))
            con.execute("UPDATE curation_state SET value=? WHERE key='supplement_version'", (str(version),))
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise
    return {"supplement_id": supplement_id, "review_id": review_id, "candidate_id": match["candidate_id"], "modules": modules,
            "supplement_version": version, "status": "active", "seed_modified": False,
            "note": "Promoted into reviewed_supplement only. Still conditional research context; not a universal default or executable parameter."}


def demote(data_dir: Path, *, supplement_id: str, reason: str, curator: str | None = None) -> dict[str, Any]:
    reason = _clean_name(reason, "reason", 1000)
    ref = ensure_schema(data_dir)
    with closing(_connect(ref)) as con:
        con.execute("BEGIN IMMEDIATE")
        try:
            row = con.execute("SELECT status FROM reviewed_supplement WHERE supplement_id=?", (supplement_id,)).fetchone()
            if row is None:
                raise CurationError("supplement_not_found", "No reviewed_supplement record with that id.")
            if row["status"] == "demoted":
                raise CurationError("already_demoted", "Record is already demoted; nothing changed.")
            version = int(con.execute("SELECT value FROM curation_state WHERE key='supplement_version'").fetchone()[0]) + 1
            con.execute("UPDATE reviewed_supplement SET status='demoted',demoted_at=?,demoted_by=?,demote_reason=?,demoted_in_version=? WHERE supplement_id=?",
                        (_now(), curator, reason, version, supplement_id))
            con.execute("UPDATE curation_state SET value=? WHERE key='supplement_version'", (str(version),))
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise
    return {"supplement_id": supplement_id, "status": "demoted", "supplement_version": version, "row_deleted": False}


def _supplement_item(row: sqlite3.Row) -> dict[str, Any]:
    candidate = json.loads(row["candidate_json"])
    review = json.loads(row["review_json"])
    return {"column": "reviewed_supplement", "label": "S0_verified_or_redone_supplement" if review.get("usage", {}).get("column") == "reviewed_supplement" else "curator_promoted_supplement", "supplement_id": row["supplement_id"],
            "title": str(candidate.get("title"))[:360], "journal": candidate.get("journal"), "journal_tier": candidate.get("journal_tier"),
            "year": candidate.get("year"), "modules": json.loads(row["modules_json"]), "doi": candidate.get("doi"),
            "pmid": candidate.get("pmid"), "pmcid": candidate.get("pmcid"), "findings": review.get("findings", [])[:5],
            "limitations": review.get("limitations", [])[:5], "locator": json.loads(row["locator_json"]),
            "reported_parameters": review.get("usage", {}).get("parameters", []),
            "citations": [candidate], "provenance": review.get("usage", {}).get("provenance"),
            "curator": row["curator"], "promoted_at": row["promoted_at"], "supplement_version": row["supplement_version"]}


def search_supplement(data_dir: Path, term_groups: list[tuple[str, ...]], module: str | None, limit: int, offset: int) -> dict[str, Any]:
    ref = Path(data_dir) / "reference.sqlite"
    rows: list[sqlite3.Row] = []
    if ref.exists():
        with closing(_connect(ref)) as con:
            if con.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='reviewed_supplement'").fetchone():
                rows = con.execute("SELECT * FROM reviewed_supplement WHERE status='active' ORDER BY promoted_at DESC, supplement_id").fetchall()
    hits = []
    for row in rows:
        if module and module not in json.loads(row["modules_json"]):
            continue
        if term_groups and not all(any(t in row["searchable"] for t in group) for group in term_groups):
            continue
        hits.append(_supplement_item(row))
    return {"label": "reviewed_supplement", "total": len(hits), "offset": offset,
            "next_offset": offset + limit if offset + limit < len(hits) else None, "results": hits[offset:offset + limit]}


def get_supplement(data_dir: Path, supplement_id: str) -> dict[str, Any]:
    """Read-only (F-10): never creates tables or backups; a missing table is simply not_found."""
    ref = Path(data_dir) / "reference.sqlite"
    row = None
    if ref.is_file():
        with closing(sqlite3.connect(ref.as_uri() + "?mode=ro", uri=True, timeout=10)) as con:
            con.row_factory = sqlite3.Row
            if con.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='reviewed_supplement'").fetchone():
                row = con.execute("SELECT * FROM reviewed_supplement WHERE supplement_id=?", (supplement_id,)).fetchone()
    if row is None:
        raise CurationError("not_found", "reviewed_supplement record not found")
    item = _supplement_item(row)
    item.update({"status": row["status"], "review": json.loads(row["review_json"]), "candidate_snapshot": json.loads(row["candidate_json"]),
                 "demoted_at": row["demoted_at"], "demote_reason": row["demote_reason"], "note": row["note"]})
    return item


def supplement_status(data_dir: Path) -> dict[str, Any]:
    ref = Path(data_dir) / "reference.sqlite"
    if not ref.exists():
        return {"active": 0, "demoted": 0, "supplement_version": 0, "domain_proposals": {}}
    with closing(_connect(ref)) as con:
        tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "reviewed_supplement" not in tables:
            return {"active": 0, "demoted": 0, "supplement_version": 0, "domain_proposals": {}}
        counts = {r["status"]: r["n"] for r in con.execute("SELECT status, count(*) n FROM reviewed_supplement GROUP BY status")}
        version = int(con.execute("SELECT value FROM curation_state WHERE key='supplement_version'").fetchone()[0])
        proposals = {r["status"]: r["n"] for r in con.execute("SELECT status, count(*) n FROM domain_proposals GROUP BY status")}
    return {"active": counts.get("active", 0), "demoted": counts.get("demoted", 0), "supplement_version": version, "domain_proposals": proposals}


# ------------------------------------------------------------------ domains

def validate_proposal(proposal: Any) -> dict[str, Any]:
    if not isinstance(proposal, dict):
        raise CurationError("invalid_proposal", "proposal must be an object")
    try:
        encoded = json.dumps(proposal, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise CurationError("invalid_proposal", "proposal must be finite JSON data") from exc
    if len(encoded) > MAX_PROPOSAL_BYTES:
        raise CurationError("proposal_too_large", f"proposal exceeds {MAX_PROPOSAL_BYTES} bytes")
    allowed = {"kind", "name", "rationale", "modules_checked", "evidence_locators", "proposer"}
    extra = sorted(set(proposal) - allowed)
    if extra:
        raise CurationError("invalid_proposal", "unsupported fields: " + ", ".join(extra)[:200])
    missing = sorted(allowed - set(proposal))
    if missing:
        raise CurationError("invalid_proposal", "missing fields: " + ", ".join(missing))
    scan = dict(proposal)
    if isinstance(scan.get("evidence_locators"), list):
        scan["evidence_locators"] = [strip_bibliographic_locators(x) if isinstance(x, str) else x for x in scan["evidence_locators"]]
    sensitive = find_sensitive(scan)
    if sensitive:
        raise CurationError("sensitive_content_refused", "Proposal refused: it appears to contain donor/patient or institution identifiers (" + ", ".join(sensitive) + ").")
    if proposal["kind"] not in DOMAIN_KINDS:
        raise CurationError("invalid_proposal", "kind must be knowledge_domain, method_family or analysis_module_request")
    out = {"kind": proposal["kind"], "name": _clean_name(proposal["name"], "name", 120, 3),
           "rationale": _clean_name(proposal["rationale"], "rationale", 2000), "proposer": _clean_name(proposal["proposer"], "proposer", 80)}
    checked = proposal["modules_checked"]
    valid = set(known_modules())
    if not isinstance(checked, list) or not 1 <= len(checked) <= len(valid):
        raise CurationError("invalid_proposal", "modules_checked must list 1..%d existing omicstat modules with the reason each does not apply" % len(valid))
    rows, seen = [], set()
    for item in checked:
        if not isinstance(item, dict) or set(item) != {"module", "reason_not_applicable"} or item["module"] not in valid or item["module"] in seen:
            raise CurationError("invalid_proposal", "each modules_checked item needs a distinct existing module and reason_not_applicable")
        rows.append({"module": item["module"], "reason_not_applicable": _clean_name(item["reason_not_applicable"], "reason_not_applicable", 300)})
        seen.add(item["module"])
    locators = proposal["evidence_locators"]
    if not isinstance(locators, list) or len(locators) > 10 or not all(isinstance(x, str) and 1 <= len(x.strip()) <= 300 for x in locators):
        raise CurationError("invalid_proposal", "evidence_locators must be a list of at most 10 strings (<=300 characters each)")
    out["modules_checked"] = rows
    out["evidence_locators"] = [x.strip() for x in locators]
    return out


def propose_domain(data_dir: Path, proposal: Any) -> dict[str, Any]:
    normalized = validate_proposal(proposal)
    digest = hashlib.sha256(json.dumps(normalized, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()
    ref = ensure_schema(data_dir)
    proposal_id = "DP-" + uuid.uuid4().hex[:12]
    with closing(_connect(ref)) as con:
        inserted = con.execute("INSERT OR IGNORE INTO domain_proposals(proposal_id,digest,kind,name,payload_json,status,created_at) VALUES(?,?,?,?,?,'proposed',?)", (
            proposal_id, digest, normalized["kind"], normalized["name"], json.dumps(normalized, ensure_ascii=False, sort_keys=True), _now())).rowcount
        row = con.execute("SELECT proposal_id,status FROM domain_proposals WHERE digest=?", (digest,)).fetchone()
    return {"proposal_id": row["proposal_id"], "status": row["status"] if not inserted else "proposed", "merged": not inserted,
            "kind": normalized["kind"], "name": normalized["name"],
            "effects": {"rotation_changed": False, "code_installed": False, "analysis_supported": False},
            "note": "Registered only. A curator may accept a knowledge_domain/method_family (and optionally add a validated discovery profile); an analysis_module_request can only be acknowledged into the engineering backlog and never becomes a module automatically. Do not claim support for this analysis."}


def list_domains(data_dir: Path, status: str | None = None) -> dict[str, Any]:
    ref = ensure_schema(data_dir)
    with closing(_connect(ref)) as con:
        rows = con.execute("SELECT * FROM domain_proposals" + (" WHERE status=?" if status else "") + " ORDER BY created_at", (status,) if status else ()).fetchall()
    return {"proposals": [{"proposal_id": r["proposal_id"], "kind": r["kind"], "name": r["name"], "status": r["status"],
                           "created_at": r["created_at"], "decided_by": r["decided_by"], "decided_at": r["decided_at"],
                           "proposal": json.loads(r["payload_json"])} for r in rows]}


def _slug(name: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", name.casefold())).strip("-")[:60] or "domain"


def validate_domain_profile(profile_raw: Any, profile_key: str, *, fetch: Callable[[str], bytes]) -> dict[str, Any]:
    """Schema-check a curator profile and run ONE live Europe PMC probe (must return >=1 whitelisted hit)."""
    from urllib.parse import urlencode
    if not isinstance(profile_raw, dict):
        raise CurationError("invalid_profile", "discovery profile must be a JSON object")
    raw = {**profile_raw, "module": profile_key}
    try:
        profile = discovery.validate_profile(raw)
        config = discovery.load_profiles()
        journals = discovery.load_journals()
    except discovery.DiscoveryError as exc:
        raise CurationError("invalid_profile", exc.message) from exc
    query = discovery.build_query(profile, config, journals, today=dt.date.today())
    url = "https://www.ebi.ac.uk/europepmc/webservices/rest/search?" + urlencode({"query": query + " sort_date:y", "format": "json", "pageSize": 5, "resultType": "lite"})
    try:
        payload = json.loads(fetch(url).decode("utf-8"))
        results = payload["resultList"]["result"]
        hits = int(payload.get("hitCount", 0))
    except Exception as exc:  # network / parse failures all block acceptance
        raise CurationError("profile_validation_unavailable", "Live profile probe failed; nothing was accepted. Retry later.") from exc
    if hits < 1 or not results:
        raise CurationError("profile_validation_failed", "Profile query returned no whitelisted Methods-section hits; not added to rotation.")
    stored = {k: v for k, v in raw.items() if k in {"module", "epmc_query", "meta", "signal_regex", "signal_require_regex", "exclude_regex"}}
    stored["profile_status"] = "ok"
    return {"profile": stored, "validation": {"hit_count": hits, "top_titles": [str(r.get("title"))[:200] for r in results[:5]],
                                               "validated_on": dt.date.today().isoformat()}}


def domain_accept(data_dir: Path, harvest_store: Any, *, proposal_id: str, curator: str, profile: Any = None,
                  fetch: Callable[[str], bytes] | None = None) -> dict[str, Any]:
    curator = _clean_name(curator, "curator", 80)
    ref = ensure_schema(data_dir)
    with closing(_connect(ref)) as con:
        row = con.execute("SELECT * FROM domain_proposals WHERE proposal_id=?", (proposal_id,)).fetchone()
    if row is None:
        raise CurationError("proposal_not_found", "No domain proposal with that id.")
    if row["kind"] not in ACCEPTABLE_KINDS:
        raise CurationError("analysis_module_request_not_acceptable", "analysis_module_request can only be acknowledged with domain-ack (engineering backlog); it never becomes a module automatically.")
    if row["status"] != "proposed":
        raise CurationError("proposal_already_decided", f"Proposal status is {row['status']}; nothing changed.")
    profile_key, validation, stored = None, None, None
    if profile is not None:
        if fetch is None:
            from harvest import _direct_fetch
            fetch = _direct_fetch
        # F-13: never collide with an existing accepted profile key (active or not).
        base = "domain:" + _slug(row["name"])
        profile_key, suffix = base, 2
        while harvest_store.profile_key_taken(profile_key):
            profile_key, suffix = f"{base}-{suffix}", suffix + 1
        checked = validate_domain_profile(profile, profile_key, fetch=fetch)
        stored, validation = checked["profile"], checked["validation"]
    if stored is not None:
        # F-13: write the rotation entry first; compensate (active=0) if the reference transaction fails.
        harvest_store.add_accepted_profile(profile_key, stored, proposal_id, curator)
    try:
        _accept_in_reference(ref, proposal_id, row, curator, profile_key, validation)
    except Exception:
        if stored is not None:
            harvest_store.deactivate_profile(profile_key)
        raise
    return {"proposal_id": proposal_id, "status": "accepted", "kind": row["kind"], "name": row["name"],
            "added_to_rotation": stored is not None, "discovery_profile_key": profile_key, "profile_validation": validation,
            "analysis_supported": False}


def _accept_in_reference(ref: Path, proposal_id: str, row: sqlite3.Row, curator: str, profile_key: str | None,
                         validation: dict[str, Any] | None) -> None:
    with closing(_connect(ref)) as con:
        con.execute("BEGIN IMMEDIATE")
        try:
            current = con.execute("SELECT status FROM domain_proposals WHERE proposal_id=?", (proposal_id,)).fetchone()
            if current["status"] != "proposed":
                raise CurationError("proposal_already_decided", "Proposal was decided concurrently; nothing changed.")
            con.execute("INSERT INTO domain_taxonomy(entry_id,proposal_id,kind,name,curator,accepted_at,discovery_profile_key,profile_validation_json) VALUES(?,?,?,?,?,?,?,?)", (
                "DT-" + uuid.uuid4().hex[:12], proposal_id, row["kind"], row["name"], curator, _now(), profile_key,
                None if validation is None else json.dumps(validation, ensure_ascii=False)))
            con.execute("UPDATE domain_proposals SET status='accepted',decided_by=?,decided_at=? WHERE proposal_id=?", (curator, _now(), proposal_id))
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise


def domain_ack(data_dir: Path, *, proposal_id: str, curator: str, note: str | None = None) -> dict[str, Any]:
    curator = _clean_name(curator, "curator", 80)
    ref = ensure_schema(data_dir)
    with closing(_connect(ref)) as con:
        con.execute("BEGIN IMMEDIATE")
        try:
            row = con.execute("SELECT kind,status FROM domain_proposals WHERE proposal_id=?", (proposal_id,)).fetchone()
            if row is None:
                raise CurationError("proposal_not_found", "No domain proposal with that id.")
            if row["kind"] != "analysis_module_request":
                raise CurationError("use_domain_accept", "domain-ack is only for analysis_module_request; use domain-accept for this kind.")
            if row["status"] != "proposed":
                raise CurationError("proposal_already_decided", f"Proposal status is {row['status']}; nothing changed.")
            con.execute("UPDATE domain_proposals SET status='acknowledged_engineering_backlog',decided_by=?,decided_at=?,decision_note=? WHERE proposal_id=?",
                        (curator, _now(), (note or "")[:1000], proposal_id))
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise
    return {"proposal_id": proposal_id, "status": "acknowledged_engineering_backlog", "module_created": False,
            "note": "Recorded in the engineering backlog only. No analysis module, rotation entry or support claim was created."}


def supplement_usages(data_dir: Path, module: str) -> list[dict[str, Any]]:
    """Read only active, explicitly represented usage evidence; no discovery promotion."""
    path = Path(data_dir) / "reference.sqlite"
    if not path.is_file():
        return []
    with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=10)) as con:
        if not con.execute("SELECT 1 FROM sqlite_master WHERE name='reviewed_supplement'").fetchone():
            return []
        result = []
        for modules, review in con.execute("SELECT modules_json,review_json FROM reviewed_supplement WHERE status='active' ORDER BY supplement_id"):
            if module in json.loads(modules):
                usage = json.loads(review).get("usage")
                if usage and usage.get("column") == "reviewed_supplement":
                    result.append(usage)
        return result
