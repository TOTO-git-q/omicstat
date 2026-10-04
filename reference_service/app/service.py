"""Shared bounded reference interface. No statistical execution or rule promotion."""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import threading
import uuid
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
SEED = ROOT / "seed" / "catalog.json"
MAX_RESPONSE_BYTES = 64000
_lock = threading.Lock()
_instances: dict[str, Any] = {}


def data_dir() -> Path:
    # Administrator-controlled process configuration, never tool arguments.
    return Path(os.environ.get("OMICSTAT_REFERENCE_DATA", str(ROOT / "data"))).resolve()


def core():
    from reference_core import ReferenceStore
    with _lock:
        key = str(data_dir() / "reference.sqlite")
        if key not in _instances:
            data_dir().mkdir(parents=True, exist_ok=True)
            _instances[key] = ReferenceStore(Path(key), SEED)
        return _instances[key]


def harvest_store():
    from harvest import HarvestStore
    with _lock:
        key = str(data_dir() / "harvest.sqlite")
        if key not in _instances:
            data_dir().mkdir(parents=True, exist_ok=True)
            _instances[key] = HarvestStore(Path(key))
        return _instances[key]


def fail(code: str, message: str) -> dict:
    return {"status": "needs_input", "error": {"code": code, "message": message},
            "execution_authorized": False, "automatic_parameter_application": False}


def bounded(result: Any) -> dict:
    """Budget the structured object, not a slice of serialized JSON."""
    if not isinstance(result, dict):
        result = {"data": result}
    result = {"interface_version": "1.0", **result}
    raw = json.dumps(result, ensure_ascii=False, allow_nan=False).encode("utf-8")
    if len(raw) <= MAX_RESPONSE_BYTES:
        return result
    return {"interface_version": "1.0", "status": "review_required",
            "response_omitted": True, "reason": "structured_response_budget",
            "complete_response_bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "available_keys": list(result)[:100],
            "next_action": "Reduce search limit, or retrieve a record with a JSON pointer and smaller page limit.",
            "execution_authorized": False, "automatic_parameter_application": False}


def invoke(fn, *args, **kwargs) -> dict:
    try:
        return bounded(fn(*args, **kwargs))
    except (ValueError, TypeError, KeyError, IndexError) as exc:
        result = fail(getattr(exc, "code", "invalid_request"), str(exc)[:1000])
        if getattr(exc, "code", "") in {"seed_mismatch", "invalid_catalog", "dangling_reference"}:
            result["status"] = "blocked"
        return result
    except sqlite3.OperationalError:
        return fail("storage_unavailable", "Reference storage is unavailable or busy; retry once later.")
    except sqlite3.DatabaseError:
        result = fail("storage_error", "Reference storage reported an integrity or database error; an administrator must check /data.")
        result["status"] = "blocked"
        return result
    except (OSError, RuntimeError) as exc:
        return fail(getattr(exc, "code", "reference_unavailable"),
                    getattr(exc, "message", "Reference unavailable. Check local CLI status, acquisition route, and seed integrity."))


def status() -> dict:
    import curation
    return {"status": "review_required", "curated": core().status(),
            "discovery": harvest_store().status(),
            "reviewed_supplement": curation.supplement_status(data_dir()),
            "interface": {"server": "omicstat_reference", "search_columns": ["curated", "reviewed_supplement", "discovery"],
                          "modules": "omicstat method map (registry); modules without curated evidence answer no_curated_evidence_yet",
                          "literature_requests": "reference_request_literature / reference_request_status / reference_cancel_request (queued; never blocks)",
                          "domain_proposals": "reference_propose_domain (registration only)",
                          "promotion": "curator CLI only (cli.py promote/demote); no MCP promotion tool"},
            "execution_authorized": False, "automatic_parameter_application": False,
            "boundary": "Conditional research reference, not biological or clinical authority, engine validation, or permission to execute.",
            "daily_execution": os.environ.get("OMICSTAT_REFERENCE_SCHEDULER", "Local legacy copy; check deployment record before collecting."),
            "deployment": os.environ.get("OMICSTAT_REFERENCE_DEPLOYMENT", "local_legacy_copy")}


def resolve_pointer(value: Any, pointer: str) -> Any:
    if not pointer:
        return value
    if not isinstance(pointer, str) or not pointer.startswith("/") or len(pointer) > 1000:
        raise ValueError("pointer must be an RFC6901-style JSON pointer, for example /record/parameters")
    for raw in pointer[1:].split("/"):
        part = raw.replace("~1", "/").replace("~0", "~")
        if isinstance(value, dict):
            value = value[part]
        elif isinstance(value, list) and part.isdigit():
            value = value[int(part)]
        else:
            raise ValueError("pointer does not identify a record field")
    return value


def get_record(record_type: str, record_id: str, pointer: str = "", offset: int = 0, limit: int = 10) -> dict:
    if type(offset) is not int or offset < 0 or type(limit) is not int or not 1 <= limit <= 50:
        raise ValueError("offset >= 0 and limit 1..50 are required")
    if not isinstance(record_id, str) or not 1 <= len(record_id) <= 200:
        raise ValueError("record_id must have 1..200 characters")
    if record_type == "supplement":
        import curation
        value = curation.get_supplement(data_dir(), record_id)
    else:
        value = (harvest_store().get_candidate(record_id) if record_type == "candidate"
                 else core().get(record_type, record_id))
    if record_type == "candidate" and not value.get("error"):
        review_path = data_dir() / "reviews.sqlite"
        if review_path.is_file():
            with closing(sqlite3.connect(review_path.as_uri() + "?mode=ro", uri=True, timeout=5)) as db:
                rows = db.execute("SELECT review_id,payload,created_at FROM proposals WHERE candidate_id=? ORDER BY created_at DESC LIMIT 10", (record_id,)).fetchall()
                total = db.execute("SELECT count(*) FROM proposals WHERE candidate_id=?", (record_id,)).fetchone()[0]
            value = {**value, "review_proposals": [{"review_id": row[0], "review": json.loads(row[1]),
                      "created_at": row[2], "status": "unapproved_proposal"} for row in rows],
                     "review_proposal_total": total, "review_proposal_limit": 10}
    if not pointer and offset == 0:
        return value
    selected = resolve_pointer(value, pointer)
    if isinstance(selected, dict):
        keys = list(selected)
        page = {k: selected[k] for k in keys[offset:offset + limit]}
        total, end, unit = len(keys), offset + limit, "fields"
    elif isinstance(selected, list):
        page, total, end, unit = selected[offset:offset + limit], len(selected), offset + limit, "items"
    elif isinstance(selected, str):
        # Text chunks are explicit, and always remain JSON strings.
        page, total, end, unit = selected[offset:offset + limit * 100], len(selected), offset + limit * 100, "characters"
    else:
        page, total, end, unit = selected, 1, 1, "scalar"
    return {"record_type": record_type, "record_id": record_id, "pointer": pointer,
            "data": page, "offset": offset, "total": total, "offset_unit": unit,
            "next_offset": end if end < total else None, "partial": offset > 0 or end < total}


COLUMN_LABELS = {
    "curated": "curated_seed_catalog: fixed, versioned seed records (conditional research context)",
    "reviewed_supplement": "reviewed_supplement: curator-promoted or verified/redone S0 evidence (still conditional context)",
    "discovery": "unreviewed_machine_screened: whitelisted journal + Methods-section signal only; nobody has reviewed applicability",
}


def search(query: str = "", module: str | None = None, limit: int = 10, offset: int = 0,
           include_discovery: bool = True) -> dict:
    """Three labelled, never-interleaved columns.  Top-level results stay the curated column."""
    import curation
    if not isinstance(include_discovery, bool):
        raise ValueError("include_discovery must be a boolean")
    store = core()
    curated = store.search(query=query, module=module, limit=limit, offset=offset)
    for item in curated["results"]:
        item["column"] = "curated"
    term_groups = store._term_groups(query)
    normalized_module = curated["module"]
    supplement = curation.search_supplement(data_dir(), term_groups, normalized_module, limit, offset)
    if include_discovery:
        discovered = harvest_store().search_screened(term_groups, normalized_module, limit, offset)
    else:
        discovered = {"label": "unreviewed_machine_screened", "included": False, "total": None, "results": []}
    return {**curated, "column": "curated", "label": COLUMN_LABELS["curated"],
            "columns_order": ["curated", "reviewed_supplement", "discovery"], "column_labels": COLUMN_LABELS,
            "reviewed_supplement": supplement, "discovery": discovered,
            "interpretation": "Columns are separate evidence states; do not merge or rank them together. Discovery items are unreviewed and never parameter-setting authority."}


def list_candidates(module: str | None = None, limit: int = 10, offset: int = 0, include_legacy: bool = False) -> dict:
    if not isinstance(include_legacy, bool):
        raise ValueError("include_legacy must be a boolean")
    return harvest_store().list_candidates(module=module, limit=limit, offset=offset, include_legacy=include_legacy)


def request_literature(request: dict) -> dict:
    import literature_requests
    return literature_requests.submit(harvest_store(), request)


def request_status(request_id: str) -> dict:
    import literature_requests
    return literature_requests.get_status(harvest_store(), request_id)


def cancel_request(request_id: str) -> dict:
    import literature_requests
    return literature_requests.cancel(harvest_store(), request_id)


def propose_domain(proposal: dict) -> dict:
    import curation
    return curation.propose_domain(data_dir(), proposal)


def submit_review(candidate_id: str, review: dict) -> dict:
    """Persist an agent's review proposal without modifying candidates or trusted rules."""
    if not isinstance(review, dict):
        raise ValueError("review must be an object")
    required = {"reviewer", "source_locators", "findings", "limitations", "proposed_module_tags"}
    if not required.issubset(review):
        raise ValueError("review requires reviewer, source_locators, findings, limitations, proposed_module_tags")
    if not isinstance(review["reviewer"], str) or not review["reviewer"].strip():
        raise ValueError("reviewer must be a nonempty string")
    for name in required - {"reviewer"}:
        if not isinstance(review[name], list) or not all(isinstance(x, str) for x in review[name]):
            raise ValueError(f"{name} must be a list of strings")
    if not review["source_locators"] or not review["findings"]:
        raise ValueError("source_locators and findings must not be empty")
    candidate = harvest_store().get_candidate(candidate_id)
    if not candidate or candidate.get("error") or candidate.get("status") in {"not_found", "invalid_request"}:
        raise ValueError("candidate not found")
    payload = json.dumps(review, ensure_ascii=False, sort_keys=True, allow_nan=False)
    if len(payload.encode("utf-8")) > 20000:
        raise ValueError("review payload exceeds 20000 bytes; summarize, do not paste full text")
    digest = hashlib.sha256((candidate_id + "\n" + payload).encode("utf-8")).hexdigest()
    with closing(sqlite3.connect(data_dir() / "reviews.sqlite", timeout=10)) as db, db:
        db.execute("CREATE TABLE IF NOT EXISTS proposals (review_id TEXT PRIMARY KEY, candidate_id TEXT NOT NULL, digest TEXT UNIQUE NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)")
        db.execute("INSERT OR IGNORE INTO proposals VALUES (?,?,?,?,?)", (
            "review-" + uuid.uuid4().hex, candidate_id, digest, payload, datetime.now(timezone.utc).isoformat()))
        row = db.execute("SELECT review_id FROM proposals WHERE digest=?", (digest,)).fetchone()
    return {"review_id": row[0], "candidate_id": candidate_id, "status": "review_required",
            "promotion_performed": False, "automatic_parameter_application": False,
            "next_action": "Only an administrator-curator can promote a proposal for a v2 'screened' candidate into reviewed_supplement (CLI promote); this proposal grants no authority."}
