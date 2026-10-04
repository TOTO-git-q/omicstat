"""On-demand literature requests: validation, refusal, keyword sanitation, dedupe, state machine.

A request is a queued *acquisition task*.  Submitting one never performs
network I/O and never blocks; the resident worker serves the queue first in
each cycle (see harvest.harvest_daily).  ``fulfilled`` only means the
acquisition task is complete; every linked candidate remains unreviewed.

States (R2): active = queued, searching; terminal = fulfilled,
partially_fulfilled, unavailable, cancelled, expired.  Deduplication applies
only among active requests.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
import unicodedata
import uuid
from pathlib import Path
from typing import Any, Mapping

from harvest import (ACTIVE_REQUEST_STATES, REQUEST_MAX_ATTEMPTS, TERMINAL_REQUEST_STATES, HarvestStore,
                     TZ_SHANGHAI, _utc_now)
from safety import find_sensitive

ROOT = Path(__file__).resolve().parent
SCHEMA_PATH = ROOT / "schemas" / "literature_request.v1.json"
MAX_REQUEST_BYTES = 4096
MAX_KEYWORDS = 6
MAX_ACTIVE_REQUESTS = 30
MAX_ACTIVE_PER_REQUESTER = 5
KEYWORD_ALLOWED = re.compile(r"[^a-z0-9\- ]+")
STOPWORDS = frozenset("""a an and are as at be been being but by can could did do does for from had has have how if in into is it its
least less may might more most must no nor not of on only or other our should so such than that the their them then there these
they this those to under upon use used using versus vs was we were what when where whether which while who will with within without
would""".split())


class RequestError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def load_schema() -> dict[str, Any]:
    """omicstat fork: the module enum is filled from the method-map registry (plus 'unmapped')."""
    import registry
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    schema["properties"]["module"]["enum"] = registry.module_order() + ["unmapped"]
    return schema


def _check(value: Any, schema: Mapping[str, Any], path: str) -> Any:
    """Validate the JSON-Schema subset used by literature_request.v1.json and apply defaults."""
    kind = schema.get("type")
    if kind == "object":
        if not isinstance(value, dict):
            raise RequestError("invalid_request", f"{path} must be an object")
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extra = sorted(set(value) - set(props))
            if extra:
                raise RequestError("invalid_request", f"{path} has unsupported fields: {', '.join(extra)[:200]}")
        for key in schema.get("required", []):
            if key not in value:
                raise RequestError("invalid_request", f"{path}.{key} is required")
        out = {}
        for key, sub in props.items():
            if key in value:
                out[key] = _check(value[key], sub, f"{path}.{key}")
            elif "default" in sub:
                out[key] = json.loads(json.dumps(sub["default"]))
        return out
    if kind == "string":
        if not isinstance(value, str):
            raise RequestError("invalid_request", f"{path} must be a string")
        text = value.strip()
        if len(text) < schema.get("minLength", 0) or len(text) > schema.get("maxLength", 10**9):
            raise RequestError("invalid_request", f"{path} length must be {schema.get('minLength', 0)}..{schema.get('maxLength')}")
        if "enum" in schema and text not in schema["enum"]:
            raise RequestError("invalid_request", f"{path} must be one of the documented values")
        return text
    if kind == "integer":
        if type(value) is not int:
            raise RequestError("invalid_request", f"{path} must be an integer")
        if value < schema.get("minimum", -10**9) or value > schema.get("maximum", 10**9):
            raise RequestError("invalid_request", f"{path} must be {schema.get('minimum')}..{schema.get('maximum')}")
        return value
    if kind == "array":
        if not isinstance(value, list):
            raise RequestError("invalid_request", f"{path} must be a list")
        if len(value) > schema.get("maxItems", 10**9):
            raise RequestError("invalid_request", f"{path} has more than {schema.get('maxItems')} items")
        return [_check(item, schema.get("items", {}), f"{path}[{i}]") for i, item in enumerate(value)]
    raise RequestError("invalid_schema", f"unsupported schema type at {path}")


def validate_request(request: Any) -> dict[str, Any]:
    if not isinstance(request, dict):
        raise RequestError("invalid_request", "request must be an object")
    try:
        encoded = json.dumps(request, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise RequestError("invalid_request", "request must be finite JSON data") from exc
    if len(encoded) > MAX_REQUEST_BYTES:
        raise RequestError("request_too_large", f"request exceeds {MAX_REQUEST_BYTES} bytes")
    sensitive = find_sensitive(request)
    if sensitive:
        # Refuse outright; nothing from the request is stored.
        raise RequestError("sensitive_content_refused", "Request refused: it appears to contain donor/patient or institution identifiers ("
                           + ", ".join(sensitive) + "). Describe the research method only; never include contact details or record numbers.")
    return _check(request, load_schema(), "request")


def _clean_words(text: str) -> list[str]:
    # F-11: fold accents first (NFKD, drop combining marks); a token that still holds
    # other non-ASCII letters is dropped whole instead of being cut into fragments.
    folded = "".join(ch for ch in unicodedata.normalize("NFKD", text) if unicodedata.category(ch) != "Mn")
    words = []
    for token in folded.casefold().replace("_", " ").split():
        if any(ord(ch) > 127 and ch.isalpha() for ch in token):
            continue
        for word in KEYWORD_ALLOWED.sub(" ", token).split():
            word = word.strip("-")
            if len(word) >= 3 and word not in STOPWORDS and not word.isdigit() and len(word) <= 40:
                words.append(word)
    return words


def extract_keywords(request: Mapping[str, Any]) -> dict[str, list[str]]:
    """Sanitized keywords only; the free text itself never reaches a query."""
    required: list[str] = []
    for condition in request.get("required_conditions", []):
        for word in _clean_words(condition):
            if word not in required and len(required) < MAX_KEYWORDS:
                required.append(word)
    optional: list[str] = []
    for parameter in request.get("parameters_of_interest", []):
        for word in _clean_words(parameter):
            if word not in required and word not in optional and len(required) + len(optional) < MAX_KEYWORDS:
                optional.append(word)
    exclusions = []
    for item in request.get("exclusions", []):
        phrase = " ".join(_clean_words(item))
        if phrase and phrase not in exclusions:
            exclusions.append(phrase)
    return {"required": required, "any_of": optional, "exclusions": exclusions[:8]}


def _norm(items: list[str]) -> list[str]:
    return sorted({re.sub(r"\s+", " ", x.casefold()).strip() for x in items if x.strip()})


def fingerprint(request: Mapping[str, Any]) -> str:
    material = request["module"] + "\n" + json.dumps([_norm(request.get("required_conditions", [])),
                                                       _norm(request.get("parameters_of_interest", []))],
                                                      ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


def _now(now: dt.datetime | None) -> dt.datetime:
    value = now or dt.datetime.now(dt.timezone.utc)
    return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)


def _iso(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat()


def _history(old: str, event: dict[str, Any]) -> str:
    items = json.loads(old) if old else []
    items.append(event)
    return json.dumps(items[-30:], ensure_ascii=False)


def submit(store: HarvestStore, request: Any, *, now: dt.datetime | None = None) -> dict[str, Any]:
    """Validate, dedupe among ACTIVE requests, enforce queue caps, and enqueue.  Immediate return, no network.

    R2: only queued/searching requests are deduplicated; resubmitting the fingerprint of a
    terminal request creates a new request (history records ``resubmission_of``).
    """
    normalized = validate_request(request)
    current = _now(now)
    keywords = extract_keywords(normalized)
    digest = fingerprint(normalized)
    expires = current + dt.timedelta(days=normalized["expires_days"])
    unmapped = normalized["module"] == "unmapped"
    status = "unavailable" if unmapped else "queued"
    gap = None
    if unmapped:
        gap = {"reason": "no_method_gate_for_unmapped_module", "searched": [], "blocked_at": "module_gate",
               "next_action": "Map the question to one of the omicstat modules (method_map.json) and resubmit, or use reference_propose_domain; no search was attempted."}
    active_marks = ",".join("?" * len(ACTIVE_REQUEST_STATES))
    request_id, merged = None, False
    con = store._connection()
    try:
        for attempt in range(2):
            con.execute("BEGIN IMMEDIATE")
            try:
                active = None if unmapped else con.execute(
                    "SELECT request_id FROM literature_requests WHERE fingerprint=? AND status IN (%s) ORDER BY created_at LIMIT 1" % active_marks,
                    (digest, *ACTIVE_REQUEST_STATES)).fetchone()
                if active is not None:
                    con.execute("COMMIT")
                    request_id, merged = active["request_id"], True
                    break
                if not unmapped:
                    total = con.execute("SELECT count(*) FROM literature_requests WHERE status IN (%s)" % active_marks, ACTIVE_REQUEST_STATES).fetchone()[0]
                    mine = con.execute("SELECT count(*) FROM literature_requests WHERE status IN (%s) AND requester=?" % active_marks,
                                       (*ACTIVE_REQUEST_STATES, normalized["requester"])).fetchone()[0]
                    if total >= MAX_ACTIVE_REQUESTS or mine >= MAX_ACTIVE_PER_REQUESTER:
                        raise RequestError("request_queue_full", "The literature-request queue is full (at most %d active requests, %d per requester). "
                                           "Nothing was stored; continue with the existing omicstat module contract and report the evidence gap, or cancel an older request."
                                           % (MAX_ACTIVE_REQUESTS, MAX_ACTIVE_PER_REQUESTER))
                previous = con.execute("SELECT request_id FROM literature_requests WHERE fingerprint=? ORDER BY created_at DESC LIMIT 1", (digest,)).fetchone()
                event: dict[str, Any] = {"at": _iso(current), "to": status, "reason": "submitted"}
                if previous is not None:
                    event["resubmission_of"] = previous["request_id"]
                new_id = "LR-" + uuid.uuid4().hex[:16]
                con.execute("INSERT INTO literature_requests(request_id,fingerprint,module,payload_json,keywords_json,status,max_papers,requester,attempts,created_at,updated_at,expires_at,gap_report_json,history_json) VALUES(?,?,?,?,?,?,?,?,0,?,?,?,?,?)", (
                    new_id, digest, normalized["module"], json.dumps(normalized, ensure_ascii=False, sort_keys=True),
                    json.dumps(keywords, ensure_ascii=False), status, normalized["max_papers"], normalized["requester"],
                    _iso(current), _iso(current), _iso(expires), None if gap is None else json.dumps(gap, ensure_ascii=False),
                    _history("", event)))
                con.execute("COMMIT")
                request_id = new_id
                break
            except sqlite3.IntegrityError:
                if con.in_transaction:
                    con.execute("ROLLBACK")
                if attempt == 1:
                    raise RequestError("request_busy", "The same request is being updated concurrently; retry once later.")
            except Exception:
                if con.in_transaction:
                    con.execute("ROLLBACK")
                raise
    finally:
        con.close()
    result = get_status(store, request_id, now=current)
    result.update({"merged": merged, "blocking": False,
                   "next_action": ("Duplicate of an active request (same module, conditions and parameters); its current state is returned."
                                   if merged else "Queued. Served in the next worker cycle that still has daily capacity - at the latest the first "
                                   "cycle after 00:00 Asia/Shanghai. Do not wait: continue with the existing omicstat module contract and report the evidence gap, "
                                   "or ask the researcher. Check later with reference_request_status.")})
    return result


def expire_due(store: HarvestStore, *, now: dt.datetime | None = None) -> int:
    """Expire ACTIVE requests past expires_at; linked candidates are kept and their count is logged."""
    current = _iso(_now(now))
    con = store._connection()
    try:
        con.execute("BEGIN IMMEDIATE")
        rows = con.execute("SELECT request_id,status,history_json FROM literature_requests WHERE status IN (%s) AND expires_at<=?" % ",".join("?" * len(ACTIVE_REQUEST_STATES)),
                           (*ACTIVE_REQUEST_STATES, current)).fetchall()
        for row in rows:
            linked = con.execute("SELECT count(*) FROM request_links WHERE request_id=?", (row["request_id"],)).fetchone()[0]
            con.execute("UPDATE literature_requests SET status='expired',updated_at=?,history_json=? WHERE request_id=?", (
                current, _history(row["history_json"], {"at": current, "from": row["status"], "to": "expired", "reason": "expires_days elapsed",
                                                        "linked": int(linked)}), row["request_id"]))
        con.execute("COMMIT")
        return len(rows)
    except Exception:
        if con.in_transaction:
            con.execute("ROLLBACK")
        raise
    finally:
        con.close()


def get_status(store: HarvestStore, request_id: Any, *, now: dt.datetime | None = None) -> dict[str, Any]:
    if not isinstance(request_id, str) or not re.fullmatch(r"LR-[0-9a-f]{16}", request_id):
        raise RequestError("invalid_request_id", "request_id must look like LR-<16 hex>")
    expire_due(store, now=now)
    con = store._connection()
    try:
        row = con.execute("SELECT * FROM literature_requests WHERE request_id=?", (request_id,)).fetchone()
        if row is None:
            raise RequestError("not_found", "request not found")
        links = con.execute("SELECT l.candidate_id,l.day,l.counted,c.title,c.status,c.record_json FROM request_links l JOIN candidates c ON c.candidate_id=l.candidate_id WHERE l.request_id=? ORDER BY l.linked_at", (request_id,)).fetchall()
        attempts = con.execute("SELECT day,started_at,finished_at,detail_json FROM request_attempts WHERE request_id=? ORDER BY day", (request_id,)).fetchall()
    finally:
        con.close()
    linked = []
    for link in links:
        record = json.loads(link["record_json"])
        linked.append({"candidate_id": link["candidate_id"], "title": str(link["title"])[:300], "journal": record.get("journal"),
                       "journal_tier": record.get("journal_tier"), "status": link["status"], "review_state": "unreviewed_machine_screened",
                       "newly_collected": bool(link["counted"]), "linked_day": link["day"],
                       "signal_snippet": (record.get("signal") or {}).get("snippet")})
    return {"request_id": row["request_id"], "status": row["status"], "module": row["module"],
            "request": json.loads(row["payload_json"]), "keywords_used": json.loads(row["keywords_json"]),
            "max_papers": row["max_papers"], "progress": {"linked": len(linked), "max_papers": row["max_papers"]},
            "attempts_used": row["attempts"], "attempts_allowed": REQUEST_MAX_ATTEMPTS,
            "state_model": {"active": list(ACTIVE_REQUEST_STATES), "terminal": list(TERMINAL_REQUEST_STATES)},
            "created_at": row["created_at"], "updated_at": row["updated_at"], "expires_at": row["expires_at"],
            "linked_candidates": linked, "attempts": [{"day": a["day"], "started_at": a["started_at"], "finished_at": a["finished_at"], **json.loads(a["detail_json"])} for a in attempts],
            "gap_report": json.loads(row["gap_report_json"]) if row["gap_report_json"] else None,
            "history": json.loads(row["history_json"]),
            "scientific_status": "not_reviewed: fulfilled means the acquisition task completed, not scientific endorsement; linked candidates remain unreviewed.",
            "execution_authorized": False, "automatic_parameter_application": False}


def cancel(store: HarvestStore, request_id: Any, *, now: dt.datetime | None = None) -> dict[str, Any]:
    status = get_status(store, request_id, now=now)
    if status["status"] in TERMINAL_REQUEST_STATES:
        status["cancelled"] = False
        status["note"] = f"Request is already terminal ({status['status']}); nothing changed."
        return status
    current = _iso(_now(now))
    con = store._connection()
    try:
        con.execute("BEGIN IMMEDIATE")
        row = con.execute("SELECT status,history_json FROM literature_requests WHERE request_id=?", (request_id,)).fetchone()
        if row["status"] in ACTIVE_REQUEST_STATES:
            con.execute("UPDATE literature_requests SET status='cancelled',updated_at=?,history_json=? WHERE request_id=?", (
                current, _history(row["history_json"], {"at": current, "from": row["status"], "to": "cancelled", "reason": "cancelled by caller"}), request_id))
        con.execute("COMMIT")
    except Exception:
        if con.in_transaction:
            con.execute("ROLLBACK")
        raise
    finally:
        con.close()
    result = get_status(store, request_id, now=now)
    result["cancelled"] = result["status"] == "cancelled"
    return result


def due_requests(store: HarvestStore, day: str, *, now: dt.datetime | None = None) -> list[dict[str, Any]]:
    """FIFO active requests that have not been attempted on this Shanghai day."""
    expire_due(store, now=now)
    con = store._connection()
    try:
        rows = con.execute("SELECT * FROM literature_requests WHERE status IN (%s) AND attempts<? AND request_id NOT IN (SELECT request_id FROM request_attempts WHERE day=?) ORDER BY created_at, rowid" % ",".join("?" * len(ACTIVE_REQUEST_STATES)),
                           (*ACTIVE_REQUEST_STATES, REQUEST_MAX_ATTEMPTS, day)).fetchall()
        return [{"request_id": r["request_id"], "module": r["module"], "status": r["status"], "attempts": r["attempts"],
                 "max_papers": r["max_papers"], "keywords": json.loads(r["keywords_json"]), "request": json.loads(r["payload_json"])} for r in rows]
    finally:
        con.close()


def linked_count(store: HarvestStore, request_id: str) -> int:
    con = store._connection()
    try:
        return int(con.execute("SELECT count(*) FROM request_links WHERE request_id=?", (request_id,)).fetchone()[0])
    finally:
        con.close()


def start_attempt(store: HarvestStore, request_id: str, day: str) -> bool:
    """Reserve today's single attempt before any network I/O (a crash still consumes it)."""
    now = _utc_now()
    con = store._connection()
    try:
        con.execute("BEGIN IMMEDIATE")
        row = con.execute("SELECT status,attempts,history_json FROM literature_requests WHERE request_id=?", (request_id,)).fetchone()
        if row is None or row["status"] not in ACTIVE_REQUEST_STATES or row["attempts"] >= REQUEST_MAX_ATTEMPTS:
            con.execute("ROLLBACK")
            return False
        if con.execute("SELECT 1 FROM request_attempts WHERE request_id=? AND day=?", (request_id, day)).fetchone():
            con.execute("ROLLBACK")
            return False
        con.execute("INSERT INTO request_attempts(request_id,day,started_at,finished_at,detail_json) VALUES(?,?,?,NULL,?)", (request_id, day, now, "{}"))
        new_status = "searching" if row["status"] == "queued" else row["status"]
        history = row["history_json"] if new_status == row["status"] else _history(row["history_json"], {"at": now, "from": row["status"], "to": new_status, "reason": f"attempt {row['attempts'] + 1} started"})
        con.execute("UPDATE literature_requests SET attempts=attempts+1,status=?,updated_at=?,history_json=? WHERE request_id=?", (new_status, now, history, request_id))
        con.execute("COMMIT")
        return True
    except Exception:
        if con.in_transaction:
            con.execute("ROLLBACK")
        raise
    finally:
        con.close()


def finish_attempt(store: HarvestStore, request_id: str, day: str, detail: Mapping[str, Any]) -> str:
    """Record the attempt and move the state machine; returns the new status."""
    now = _utc_now()
    con = store._connection()
    try:
        con.execute("BEGIN IMMEDIATE")
        row = con.execute("SELECT * FROM literature_requests WHERE request_id=?", (request_id,)).fetchone()
        con.execute("UPDATE request_attempts SET finished_at=?,detail_json=? WHERE request_id=? AND day=?", (now, json.dumps(dict(detail), ensure_ascii=False), request_id, day))
        linked = int(con.execute("SELECT count(*) FROM request_links WHERE request_id=?", (request_id,)).fetchone()[0])
        status, gap = row["status"], row["gap_report_json"]
        if status not in ACTIVE_REQUEST_STATES:
            con.execute("COMMIT")
            return status
        if linked >= row["max_papers"]:
            new = "fulfilled"
        elif row["attempts"] >= REQUEST_MAX_ATTEMPTS:
            # R2: exhausted with some links -> terminal partially_fulfilled (links kept); none -> unavailable.
            new = "partially_fulfilled" if linked > 0 else "unavailable"
            attempts = [{"day": a["day"], **json.loads(a["detail_json"])} for a in con.execute("SELECT day,detail_json FROM request_attempts WHERE request_id=? ORDER BY day", (request_id,))]
            totals: dict[str, int] = {}
            for attempt in attempts:
                for gate, n in (attempt.get("gate_counts") or {}).items():
                    totals[gate] = totals.get(gate, 0) + int(n)
            losses = {k: v for k, v in totals.items() if k not in {"screened", "duplicate"}}
            gap = json.dumps({"reason": "attempts_exhausted_partial" if linked > 0 else "attempts_exhausted", "attempts_used": row["attempts"], "linked_candidates": linked,
                              "max_papers": row["max_papers"], "keywords": json.loads(row["keywords_json"]),
                              "searched": [{"day": a["day"], "hit_count": a.get("hit_count"), "examined": a.get("examined"),
                                            "error": a.get("error"), "query_terms": a.get("query_terms")} for a in attempts],
                              "gate_totals": totals, "blocked_at": max(losses, key=losses.get) if losses else ("no_search_hits" if not totals else "none"),
                              "next_action": "No further automatic retries. Proceed with the existing omicstat module contract and report this gap, broaden the request, or ask a curator."},
                             ensure_ascii=False)
        else:
            new = "searching"  # attempts remain (with or without links); see progress in get_status
        history = row["history_json"] if new == status else _history(row["history_json"], {"at": now, "from": status, "to": new, "reason": f"attempt {row['attempts']} finished with {linked} linked"})
        con.execute("UPDATE literature_requests SET status=?,updated_at=?,gap_report_json=?,history_json=? WHERE request_id=?", (new, now, gap, history, request_id))
        con.execute("COMMIT")
        return new
    except Exception:
        if con.in_transaction:
            con.execute("ROLLBACK")
        raise
    finally:
        con.close()
