#!/usr/bin/env python3
"""Publication contracts, provenance and review finalization for omicstat.

This module never estimates or re-estimates a statistic. It inventories and
validates artifacts already produced by an R engine. The canonical effect-table
validation itself remains in R and is supplied to ``finalize_run`` by the MCP
server after calling validate_effect_table_cli.R.
"""

from __future__ import annotations

import copy
import csv
import datetime as dt
from decimal import Decimal, InvalidOperation
import fnmatch
import hashlib
import json
import math
import mimetypes
import os
import re
import subprocess
import uuid
from contextlib import contextmanager
import threading
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

import package_identity

try:
    import jsonschema
except ImportError:  # fail-safe is handled by validate_instance
    jsonschema = None


HERE = os.path.dirname(os.path.abspath(__file__))
SUITE = os.path.dirname(HERE)
SHARED = os.path.join(SUITE, "skills", "_shared")
SCHEMA_DIR = os.path.join(SHARED, "schemas")
RULE_DIR = os.path.join(SHARED, "publication")

STUDY_CONTRACT_VERSION = "omicstat.study-contract.v1"
REVIEW_VERSION = "omicstat.publication-review.v1"
MANIFEST_VERSION = "omicstat.publication-manifest.v1"
ARTIFACT_INDEX_VERSION = "omicstat.artifact-index.v1"
STATUS_VALUES = (
    "blocked",
    "needs_input",
    "review_required",
    "ready_for_manuscript_integration",
)
MANIFEST_REL = "provenance/publication_manifest.json"
REVIEW_REL = "publication/review.json"
INDEX_REL = "publication/artifact_index.json"
OUTLINE_REL = "publication/results_outline.md"
VALUE_MAP_REL = "publication/value_map.json"
EVIDENCE_SNAPSHOT_DIR = "publication/evidence-snapshots"
COMMIT_FAILURE_REL = "publication/commit_failure.json"
COMMIT_MARKER_REL = "publication/commit.json"
INTEGRITY_EXCLUSIONS = [MANIFEST_REL]
PUBLICATION_DYNAMIC = {MANIFEST_REL, REVIEW_REL, INDEX_REL, OUTLINE_REL, VALUE_MAP_REL}
_REGISTRY_LOCKS: Dict[str, threading.Lock] = {}
_REGISTRY_LOCKS_GUARD = threading.Lock()

# These files are rewritten by finalization.  Evidence may not point at them,
# including through Windows spelling aliases (case, slash, dot/space) or a
# filesystem alias.  Use a platform-independent canonical spelling here: a
# manifest made on Linux must remain safe when opened on Windows.
_PUBLICATION_DYNAMIC_CANONICAL = {
    path.casefold() for path in PUBLICATION_DYNAMIC
}
_CONTRACT_PLACEHOLDERS = {
    "", "-", "_", "n/a", "na", "none", "null", "unknown", "unavailable",
    "unspecified", "tbd", "todo", "default", "placeholder", "not applicable",
}

FIGURE_EXT = {".png", ".pdf", ".jpg", ".jpeg", ".svg", ".tif", ".tiff", ".eps"}
TEXT_EXT = {".md", ".csv", ".txt", ".json", ".yml", ".yaml", ".tsv"}
CORE_EFFECT_COLUMNS = {
    "term", "level", "analysis_id", "effect_type", "estimate", "ci_low",
    "ci_high", "ci_level", "p_value", "p_adjusted", "p_adj_method",
    "n_unweighted", "n_events", "design_df", "weighted", "stratum_var",
    "stratum", "test_name", "model_spec_hash", "notes",
}


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def json_safe(
    value: Any,
    warnings: Optional[List[Dict[str, str]]] = None,
    path: str = "$",
) -> Any:
    """Return a strictly JSON-safe copy and optionally record lossy coercions."""
    if isinstance(value, str):
        normalized = re.sub(r"[\ud800-\udfff]", "\ufffd", value)
        if normalized != value and warnings is not None:
            warnings.append({
                "code": "OS_JSON_INVALID_UNICODE",
                "path": path,
                "message": "unpaired Unicode surrogate was replaced with U+FFFD",
            })
        return normalized
    if isinstance(value, float) and not math.isfinite(value):
        if warnings is not None:
            warnings.append({
                "code": "OS_JSON_NONFINITE",
                "path": path,
                "message": "non-finite numeric value was serialized as null",
            })
        return None
    if value is None or isinstance(value, (int, float, bool)):
        return value
    if isinstance(value, dict):
        result = {}
        original_keys = {}
        for key, child in value.items():
            raw_key = str(key)
            safe_key = json_safe(raw_key, warnings, "%s/<key>" % path)
            if safe_key in result and warnings is not None:
                warnings.append({
                    "code": "OS_JSON_KEY_COLLISION", "path": path,
                    "message": "distinct keys normalize to the same JSON key",
                    "keys": [original_keys[safe_key], raw_key],
                })
            original_keys[safe_key] = raw_key
            result[safe_key] = json_safe(child, warnings, "%s/%s" % (path, safe_key))
        return result
    if isinstance(value, (list, tuple, set)):
        return [json_safe(v, warnings, "%s/%d" % (path, i)) for i, v in enumerate(value)]
    return str(value)


def _read_json(path: str) -> Dict[str, Any]:
    with open(_native_path(path), encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("expected a JSON object in " + path)
    return data


def _native_path(path: str) -> str:
    """Use the extended Windows form only at the filesystem boundary.

    A publication artifact may combine a caller temporary directory, run UUID,
    content-addressed evidence filename, and atomic suffix.  That legitimate
    nesting can exceed legacy MAX_PATH even after every component passed the
    safe-path checks.  Stored manifest paths remain portable strings.
    """
    if os.name != "nt":
        return path
    absolute = os.path.abspath(path)
    if absolute.startswith("\\\\?\\"):
        return absolute
    if absolute.startswith("\\\\"):
        return "\\\\?\\UNC\\" + absolute[2:]
    return "\\\\?\\" + absolute


def _atomic_write_text(path: str, text: str) -> None:
    native_path = _native_path(path)
    os.makedirs(os.path.dirname(native_path), exist_ok=True)
    temporary = "%s.tmp-%s" % (native_path, uuid.uuid4().hex)
    try:
        with open(temporary, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        os.replace(temporary, native_path)
    finally:
        if os.path.exists(temporary):
            try:
                os.remove(temporary)
            except OSError:
                pass


def _atomic_write_bytes(path: str, content: bytes) -> None:
    """Restore an exact prior manifest/registry byte stream during rollback."""
    native_path = _native_path(path)
    os.makedirs(os.path.dirname(native_path), exist_ok=True)
    temporary = "%s.tmp-%s" % (native_path, uuid.uuid4().hex)
    try:
        with open(temporary, "wb") as fh:
            fh.write(content)
        os.replace(temporary, native_path)
    finally:
        if os.path.exists(temporary):
            try:
                os.remove(temporary)
            except OSError:
                pass


def write_json(path: str, value: Any) -> None:
    _atomic_write_text(
        path,
        json.dumps(
            json_safe(value), ensure_ascii=False, indent=2, sort_keys=False,
            allow_nan=False,
        ) + "\n",
    )


def load_schema(name: str) -> Dict[str, Any]:
    return _read_json(os.path.join(SCHEMA_DIR, "%s.v1.schema.json" % name))


def validate_instance(instance: Any, schema_name: str) -> List[str]:
    if jsonschema is None:
        return ["jsonschema is not installed; could not validate %s v1" % schema_name]
    schema = load_schema(schema_name)
    validator = jsonschema.Draft202012Validator(
        schema, format_checker=jsonschema.FormatChecker()
    )
    errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.absolute_path))
    rendered = []
    for err in errors:
        location = "/" + "/".join(str(p) for p in err.absolute_path)
        rendered.append("%s: %s" % (location if location != "/" else "$", err.message))
    if schema_name == "literature_evidence" and isinstance(instance, dict):
        providers = {str(item.get("source", "")).strip().lower()
                     for item in instance.get("source_verifications", [])
                     if isinstance(item, dict) and str(item.get("source", "")).strip()}
        if len(providers) < 2:
            rendered.append("/source_verifications: at least two distinct providers are required")
    return rendered


def _canonical_relative_path(value: str) -> str:
    """Canonical, case-insensitive relative spelling for identity checks."""
    normalized = os.path.normpath(value.replace("\\", "/")).replace("\\", "/")
    # Windows aliases a trailing dot/space to the same path.  Treat those as
    # aliases everywhere, rather than allowing a cross-platform false-ready.
    return "/".join(part.rstrip(". ") for part in normalized.split("/")).casefold()


def _is_dynamic_relative_path(value: Any) -> bool:
    return isinstance(value, str) and _canonical_relative_path(value) in _PUBLICATION_DYNAMIC_CANONICAL


def _is_dynamic_evidence_path(outdir: str, location: str) -> bool:
    """Reject dynamic publication evidence by spelling *or* file identity.

    ``safe_join_under`` separately refuses symlinks and Windows reparse
    components.  ``samefile`` additionally catches a hard-link or other
    filesystem alias when both paths exist.
    """
    if _is_dynamic_relative_path(location):
        return True
    try:
        candidate = safe_join_under(outdir, location, require_exists=True)
    except (OSError, ValueError):
        return False
    for dynamic_rel in PUBLICATION_DYNAMIC:
        try:
            dynamic_path = safe_join_under(outdir, dynamic_rel, require_exists=True)
        except (OSError, ValueError):
            continue
        try:
            if os.path.samefile(candidate, dynamic_path):
                return True
        except OSError:
            continue
    return False


def _meaningful_contract_value(value: Any) -> bool:
    """Whether a declaration contains a semantic, non-placeholder string.

    Numbers, booleans, nulls, and containers made solely from those values do
    not identify a study construct.  Rich real-world declarations remain
    supported: identifier strings, definitions, estimands, and variable
    descriptions may be nested with numeric metadata.
    """
    if isinstance(value, str):
        text = value.strip()
        # Compare whole phrases after folding case, whitespace, and benign
        # punctuation.  This rejects ``Not specified``, ``N/A``, ``T.B.C.``,
        # etc., without rejecting a real sentence that merely contains one of
        # those words in meaningful context.
        phrase = re.sub(r"[^a-z0-9]+", " ", text.casefold()).strip()
        phrase_placeholders = {
            "not specified", "not available", "not provided", "not applicable",
            "not known", "not determined", "not reported", "not collected",
            "to be confirmed", "to be determined", "tbc", "t b c", "tbd", "t b d", "unknown",
            "na", "n a", "available", "provided", "applicable", "specified",
            "not stated", "not disclosed", "not documented", "not defined",
            "to be decided", "tba", "t b a", "pending", "not yet specified",
        }
        if (not text or text.casefold() in _CONTRACT_PLACEHOLDERS
                or phrase in phrase_placeholders):
            return False
        return re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?", text) is None
    if isinstance(value, dict):
        return bool(value) and any(
            isinstance(key, str) and key.strip() and _meaningful_contract_value(child)
            for key, child in value.items()
        )
    if isinstance(value, (list, tuple)):
        return bool(value) and any(_meaningful_contract_value(child) for child in value)
    return False


def _semantic_declaration_errors(contract: Dict[str, Any]) -> List[str]:
    """Require typed study semantics for a contract that may become ready.

    The historical free-form contract is deliberately still schema-compatible:
    callers need not break merely to obtain a ``needs_input`` review.  It is
    not, however, a sufficient ready boundary.  These explicit fields prevent
    arbitrary nested prose from impersonating population, estimand, timing, or
    analytical-policy declarations.
    """
    declarations = contract.get("semantic_declarations")
    if not isinstance(declarations, dict):
        return ["/semantic_declarations: field-specific declarations are required before ready status"]
    expected = {
        "study_design": ("design_type",),
        "population": ("definition",),
        "estimand": ("measure", "target"),
        "exposure": ("variable_or_intervention",),
        "comparator": ("definition",),
        "missing_data": ("strategy",),
        "multiplicity": ("strategy",),
    }
    errors: List[str] = []
    for section, keys in expected.items():
        value = declarations.get(section)
        if not isinstance(value, dict):
            errors.append("/semantic_declarations/%s: typed declaration is required" % section)
            continue
        for key in keys:
            if not _meaningful_contract_value(value.get(key)):
                errors.append("/semantic_declarations/%s/%s: requires a non-placeholder value" % (section, key))
    outcomes = declarations.get("outcomes")
    if not isinstance(outcomes, list) or not outcomes:
        errors.append("/semantic_declarations/outcomes: at least one typed outcome is required")
    else:
        for index, outcome in enumerate(outcomes):
            if not isinstance(outcome, dict):
                errors.append("/semantic_declarations/outcomes/%d: typed outcome is required" % index)
                continue
            for key in ("identity", "timing"):
                if not _meaningful_contract_value(outcome.get(key)):
                    errors.append("/semantic_declarations/outcomes/%d/%s: requires a non-placeholder value" % (index, key))
    return errors


def _study_contract_semantic_errors(contract: Dict[str, Any]) -> List[str]:
    """Enforce semantic content beyond JSON-schema shape validation."""
    errors: List[str] = []
    declared = (
        "study_design", "analysis_population", "estimand", "exposure_or_intervention",
        "comparator", "missing_data", "multiplicity",
    )
    for field in declared:
        if field in contract and not _meaningful_contract_value(contract[field]):
            errors.append("/%s: requires a non-placeholder semantic declaration" % field)
    for field in ("covariates", "analysis_sets"):
        values = contract.get(field)
        if isinstance(values, list):
            for index, value in enumerate(values):
                if not _meaningful_contract_value(value):
                    errors.append("/%s/%d: requires a non-placeholder semantic declaration" % (field, index))
    outcomes = contract.get("outcomes")
    if isinstance(outcomes, list):
        for index, outcome in enumerate(outcomes):
            if not isinstance(outcome, dict):
                continue
            identity = [outcome.get(key) for key in ("name", "definition") if key in outcome]
            timing = [outcome.get(key) for key in ("timepoint", "time_horizon") if key in outcome]
            if identity and not any(_meaningful_contract_value(value) for value in identity):
                errors.append("/outcomes/%d: name or definition must be semantically meaningful" % index)
            if timing and not any(_meaningful_contract_value(value) for value in timing):
                errors.append("/outcomes/%d: timepoint or time_horizon must be semantically meaningful" % index)
    return errors + _semantic_declaration_errors(contract)


def _legacy_semantic_declarations(contract: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Adapt established descriptive v1 calls only when their named fields suffice."""
    def pick(value: Any, keys: Sequence[str]) -> Optional[str]:
        values = [value] if isinstance(value, str) else [value.get(key) for key in keys] if isinstance(value, dict) else []
        return next((str(item).strip() for item in values if _meaningful_contract_value(item)), None)
    population = pick(contract.get("analysis_population"), ("population", "definition", "description", "cohort_id", "eligibility"))
    measure = pick(contract.get("estimand"), ("measure", "summary_measure", "effect_measure"))
    target = pick(contract.get("estimand"), ("target", "definition", "timepoint", "time_horizon"))
    exposure = pick(contract.get("exposure_or_intervention"), ("variable_or_intervention", "variable", "name", "definition"))
    comparator = pick(contract.get("comparator"), ("definition", "variable", "name"))
    missing = pick(contract.get("missing_data"), ("strategy", "method", "definition"))
    multiplicity = pick(contract.get("multiplicity"), ("strategy", "method", "definition"))
    design = pick(contract.get("study_design"), ("design_type", "type", "definition"))
    outcomes = []
    for outcome in contract.get("outcomes", []) if isinstance(contract.get("outcomes"), list) else []:
        identity = pick(outcome, ("identity", "name", "definition"))
        timing = pick(outcome, ("timing", "timepoint", "time_horizon"))
        if identity and timing:
            outcomes.append({"identity": identity, "timing": timing})
    if not all((design, population, measure, target, exposure, comparator, missing, multiplicity, outcomes)):
        return None
    return {
        "study_design": {"design_type": design}, "population": {"definition": population},
        "estimand": {"measure": measure, "target": target},
        "exposure": {"variable_or_intervention": exposure}, "comparator": {"definition": comparator},
        "outcomes": outcomes, "missing_data": {"strategy": missing},
        "multiplicity": {"strategy": multiplicity},
    }


def normalize_study_contract(contract: Optional[Dict[str, Any]]) -> Tuple[Optional[Dict[str, Any]], List[str]]:
    if contract is None:
        return None, []
    if not isinstance(contract, dict):
        return None, ["$: study_contract must be an object"]
    def normalize_strings(value: Any) -> Any:
        if isinstance(value, str):
            return value.strip()
        if isinstance(value, list):
            return [normalize_strings(item) for item in value]
        if isinstance(value, dict):
            return {key: normalize_strings(item) for key, item in value.items()}
        return copy.deepcopy(value)

    normalized = normalize_strings(contract)
    normalized.setdefault("schema_version", STUDY_CONTRACT_VERSION)
    if "semantic_declarations" not in normalized:
        adapted = _legacy_semantic_declarations(normalized)
        if adapted is not None:
            normalized["semantic_declarations"] = adapted
    return normalized, (validate_instance(normalized, "study_contract")
                        + _study_contract_semantic_errors(normalized))


def sha256_file(path: str, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    # Keep portable paths in manifests, but use the same Windows long-path
    # spelling for every filesystem observation as the atomic writer.  A deep
    # run directory can otherwise write a closed snapshot through ``\\?\``
    # and immediately misreport that same snapshot as absent through its
    # legacy spelling.
    with open(_native_path(path), "rb") as fh:
        while True:
            chunk = fh.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def _evidence_snapshot_path(outdir: str, digest: str) -> str:
    return safe_join_under(outdir, "%s/%s.bin" % (EVIDENCE_SNAPSHOT_DIR, digest.casefold()))


def snapshot_reviewer_evidence(outdir: str, decisions: Any) -> Dict[str, Any]:
    """Ingest validated reviewer bytes under their content hash before commit.

    Later commit checks validate this immutable-by-hash copy, rather than a
    mutable source path.  An attempted snapshot overwrite is detected by its
    digest and cannot silently change an accepted decision.
    """
    normalized = validate_reviewer_decisions(outdir, decisions)
    for decision in normalized.values():
        for location in decision.get("evidence_locations", []):
            digest = decision["evidence_sha256"][location]
            source = safe_join_under(outdir, location, require_exists=True)
            target = _evidence_snapshot_path(outdir, digest)
            # Snapshot paths are content-addressed and their parent is created
            # lazily.  Make that lifecycle explicit before existence checks so
            # a first reviewer-evidence commit never depends on a fixture
            # having pre-created `publication/evidence-snapshots`.
            native_target = _native_path(target)
            os.makedirs(os.path.dirname(native_target), exist_ok=True)
            if os.path.isfile(native_target):
                if sha256_file(native_target).casefold() != digest.casefold():
                    raise ValueError("reviewer evidence snapshot hash collision: %s" % location)
                continue
            with open(_native_path(source), "rb") as fh:
                content = fh.read()
            if hashlib.sha256(content).hexdigest().casefold() != digest.casefold():
                raise ValueError("reviewer evidence changed while snapshotting: %s" % location)
            _atomic_write_bytes(target, content)
            # _atomic_write_bytes returns only after its writer has closed and
            # its replace completed. Verify through the same native spelling
            # before a later finalizer boundary consumes this snapshot.
            if not os.path.isfile(native_target):
                raise OSError("reviewer evidence snapshot write did not complete: %s" % location)
    return normalized


def validate_reviewer_decisions(outdir: str, decisions: Any, *, use_snapshots: bool = False) -> Dict[str, Any]:
    """Validate every persisted decision against fixed local evidence.

    This is intentionally a core invariant rather than an MCP-input check:
    manifests imported from another output tree take the same path as newly
    supplied decisions and therefore cannot bypass evidence verification.
    """
    if decisions is None:
        return {}
    if not isinstance(decisions, dict):
        raise ValueError("reviewer_decisions must be an object keyed by rule_id")
    normalized_decisions = copy.deepcopy(decisions)
    sha_pattern = re.compile(r"^[a-fA-F0-9]{64}$")
    for raw_rule_id, decision in normalized_decisions.items():
        rule_id = str(raw_rule_id).strip()
        if not rule_id or not isinstance(decision, dict):
            raise ValueError("invalid reviewer decision for %s" % raw_rule_id)
        disposition = decision.get("decision")
        if disposition not in {"accepted", "rejected", "pending"}:
            raise ValueError("invalid reviewer decision for %s" % rule_id)
        if not str(decision.get("decided_at", "")).strip():
            raise ValueError("reviewer decision for %s requires decided_at" % rule_id)
        locations = decision.get("evidence_locations", [])
        hashes = decision.get("evidence_sha256", {})
        if disposition in {"accepted", "rejected"}:
            if not str(decision.get("reviewer", "")).strip():
                raise ValueError("reviewer decision for %s requires reviewer" % rule_id)
            if (not isinstance(locations, list) or not locations
                    or any(not isinstance(item, str) or not item.strip() for item in locations)):
                raise ValueError("reviewer decision for %s requires evidence_locations" % rule_id)
            if not isinstance(hashes, dict):
                raise ValueError("reviewer evidence requires evidence_sha256 for %s" % rule_id)
            if len(set(locations)) != len(locations) or set(hashes) != set(locations):
                raise ValueError("reviewer evidence requires exact evidence_sha256 coverage for %s" % rule_id)
        elif locations or hashes:
            if (not isinstance(locations, list) or not isinstance(hashes, dict)
                    or any(not isinstance(item, str) or not item.strip() for item in locations)
                    or len(set(locations)) != len(locations) or set(hashes) != set(locations)):
                raise ValueError("pending reviewer evidence requires exact evidence_sha256 coverage for %s" % rule_id)
        for location in locations:
            expected = hashes.get(location)
            if not isinstance(expected, str) or not sha_pattern.fullmatch(expected):
                raise ValueError("reviewer evidence requires evidence_sha256: %s" % location)
            if re.match(r"^https?://", location, re.I):
                raise ValueError("reviewer evidence must be a fixed local artifact: %s" % location)
            if _is_dynamic_evidence_path(outdir, location):
                raise ValueError("reviewer evidence cannot reference dynamic publication artifacts: %s" % location)
            try:
                local = (_evidence_snapshot_path(outdir, expected)
                         if use_snapshots else safe_join_under(outdir, location, require_exists=True))
                if use_snapshots and not os.path.isfile(_native_path(local)):
                    # A missing snapshot is evidence loss, not a transient
                    # condition. Do not delay or mask it with a retry.
                    raise ValueError("reviewer evidence snapshot is unavailable: %s" % location)
                actual = sha256_file(local)
            except (OSError, ValueError) as exc:
                raise ValueError("reviewer evidence is not a readable fixed artifact: %s" % location) from exc
            if actual.lower() != expected.lower():
                raise ValueError("reviewer evidence SHA-256 mismatch: %s" % location)
    return normalized_decisions


def _identity_json(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _expected_code_inventory(entry_path: str) -> List[Dict[str, str]]:
    """Recompute the executable code closure from the local repository."""
    entry = safe_join_under(SUITE, entry_path, require_exists=True)
    roots = [os.path.dirname(entry), os.path.join(SHARED, "scripts")]
    # Python lane (ENGINEERING_PLAN 10.6): a run_*.py module also executes its
    # .py scripts and the shared Python layer (same closure as server.py).
    python_entry = entry.lower().endswith(".py")
    code_ext = (".r", ".py") if python_entry else (".r",)
    if python_entry:
        roots.append(os.path.join(SHARED, "py"))
    paths = {
        os.path.join(SUITE, "mcp", "server.py"),
        os.path.join(SUITE, "mcp", "publication.py"),
        os.path.join(SHARED, "scripts", "validate_effect_table_cli.R"),
        os.path.join(SHARED, "scripts", "effect_table.R"),
    }
    for root in roots:
        if _has_link_or_reparse_component(root):
            raise ValueError("reparse component in executable code root")
        for current, dirs, files in os.walk(root):
            dirs[:] = [name for name in dirs
                       if not _is_link_or_reparse(os.path.join(current, name))]
            for name in files:
                path = os.path.join(current, name)
                in_scripts = os.path.normcase(os.path.abspath(current)).startswith(
                    os.path.normcase(os.path.abspath(os.path.join(SHARED, "scripts"))))
                if name.lower().endswith(".r") or (name.lower().endswith(code_ext) and not in_scripts):
                    paths.add(path)
    inventory = []
    for path in sorted(paths):
        if not os.path.isfile(path) or _is_link_or_reparse(path):
            raise ValueError("executable code path is unavailable")
        inventory.append({
            "path": os.path.relpath(path, SUITE).replace("\\", "/"),
            "sha256": sha256_file(path),
        })
    return inventory


def _recompute_dirty_identity(entry_path: str) -> Dict[str, Any]:
    """Recreate server-side dirty-tree evidence from observed repository bytes."""
    def git_bytes(args: List[str]) -> bytes:
        result = subprocess.run(["git"] + args, cwd=SUITE, stdin=subprocess.DEVNULL,
                                capture_output=True, timeout=30, check=False)
        if result.returncode != 0:
            raise RuntimeError("git identity command failed")
        return result.stdout
    status = git_bytes(["status", "--porcelain=v1", "--untracked-files=normal", "-z"])
    diff = git_bytes(["diff", "--binary", "HEAD"])
    untracked_raw = git_bytes(["ls-files", "--others", "--exclude-standard", "-z"])
    untracked = []
    for raw in untracked_raw.split(b"\0"):
        if not raw:
            continue
        rel = raw.decode("utf-8", "surrogateescape").replace("\\", "/")
        path = safe_join_under(SUITE, rel, require_exists=True)
        if not os.path.isfile(path) or _is_link_or_reparse(path):
            raise ValueError("untracked identity path is not a regular file")
        untracked.append({"path": rel, "sha256": sha256_file(path)})
    untracked.sort(key=lambda item: item["path"])
    inventory = _expected_code_inventory(entry_path)
    inventory_json = _identity_json(inventory)
    untracked_json = _identity_json(untracked)
    return {
        "status_sha256": hashlib.sha256(status).hexdigest(),
        "diff_sha256": hashlib.sha256(diff).hexdigest(),
        "untracked_sha256": hashlib.sha256(untracked_json).hexdigest(),
        "code_inventory_sha256": hashlib.sha256(inventory_json).hexdigest(),
        "worktree_sha256": hashlib.sha256(b"\0".join((status, diff, untracked_json, inventory_json))).hexdigest(),
        "code_inventory": inventory,
    }


def _verify_dirty_identity(identity: Any, entry_path: Optional[str], commit: Optional[str]) -> bool:
    """Require a stored identity to equal the current repository observation."""
    if not isinstance(identity, dict) or not entry_path or not commit:
        return False
    try:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=SUITE, stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=10, check=False)
        if head.returncode != 0 or head.stdout.strip().casefold() != commit.casefold():
            return False
        observed = _recompute_dirty_identity(entry_path)
        return all(identity.get(field) == observed[field] for field in (
            "status_sha256", "diff_sha256", "untracked_sha256", "code_inventory_sha256",
            "worktree_sha256", "code_inventory",
        ))
    except (OSError, RuntimeError, ValueError):
        return False


def _observed_repository_state(entry_path: Optional[str]) -> Tuple[Optional[str], Optional[bool], Optional[Dict[str, Any]]]:
    """Read Git state at the trust boundary; never trust caller-supplied state."""
    if not entry_path:
        return None, None, None
    try:
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=SUITE,
                              stdin=subprocess.DEVNULL, capture_output=True,
                              text=True, timeout=10, check=False)
        if head.returncode != 0 or not re.fullmatch(r"[a-fA-F0-9]{40}", head.stdout.strip()):
            return None, None, None
        identity = _recompute_dirty_identity(entry_path)
        # SHA-256 of zero bytes is the only clean porcelain digest.  Retaining
        # the status digest in the identity makes the boolean derivation
        # independently auditable without accepting a caller assertion.
        dirty = identity["status_sha256"] != hashlib.sha256(b"").hexdigest()
        return head.stdout.strip(), dirty, identity
    except (OSError, RuntimeError, ValueError):
        return None, None, None


def _current_manifest_provenance_is_bound(manifest: Dict[str, Any]) -> bool:
    """Re-sample code/repository state immediately at the commit boundary."""
    versions = manifest.get("software_versions")
    if not isinstance(versions, dict):
        return False
    repository = versions.get("repository")
    entry = versions.get("module_entry_script")
    if not isinstance(repository, dict) or not isinstance(entry, dict):
        return False
    # Only an archive with no .git can use the immutable build identity.  This
    # preserves live worktree dirty-state observation and fails closed for a
    # missing, malformed, tampered, or inventory-mismatched package record.
    if not os.path.exists(os.path.join(SUITE, ".git")):
        identity = package_identity.load_and_verify(Path(SUITE))
        package_record = repository.get("package_identity")
        return bool(identity and repository.get("commit") == identity["source_commit"]
                    and repository.get("dirty") is False and isinstance(package_record, dict)
                    and package_record.get("source_tree") == identity["source_tree"]
                    and package_record.get("inventory_sha256") == identity["inventory_sha256"])
    entry_path = entry.get("path")
    commit, dirty, observed_identity = _observed_repository_state(entry_path)
    if commit is None or dirty is None or observed_identity is None:
        return False
    if repository.get("commit") != commit or repository.get("dirty") is not dirty:
        return False
    if dirty:
        return repository.get("worktree_identity") == observed_identity
    return repository.get("worktree_identity") is None


def normalize_provenance(software_versions: Any, engine: str) -> Tuple[Dict[str, Any], List[str]]:
    """Return schema-stable provenance plus release-blocking missing fields."""
    supplied = dict(json_safe(software_versions) or {}) if isinstance(software_versions, dict) else {}
    sha_pattern = re.compile(r"^[a-fA-F0-9]{64}$")
    image_pattern = re.compile(r"^sha256:[a-fA-F0-9]{64}$")

    def text_or_unknown(key: str) -> str:
        value = supplied.get(key)
        return str(value).strip() if isinstance(value, str) and value.strip() else "unknown"

    def hash_value(key: str, fallback: str) -> str:
        value = supplied.get(key)
        return value if isinstance(value, str) and sha_pattern.fullmatch(value) else sha256_file(fallback)

    python_packages = supplied.get("python_packages")
    if not isinstance(python_packages, dict):
        python_packages = {}
    python_packages = {str(key): str(value) for key, value in python_packages.items()
                       if str(key).strip() and str(value).strip()}
    r_packages = supplied.get("r_packages")
    if not isinstance(r_packages, dict):
        r_packages = {}
    r_packages = {str(key): str(value) for key, value in r_packages.items()
                  if str(key).strip() and str(value).strip()}
    repository = supplied.get("repository") if isinstance(supplied.get("repository"), dict) else {}
    supplied_commit = repository.get("commit")
    if not isinstance(supplied_commit, str) or not re.fullmatch(r"[a-fA-F0-9]{40}", supplied_commit):
        supplied_commit = None
    supplied_dirty = repository.get("dirty") if isinstance(repository.get("dirty"), bool) else None
    worktree_identity = repository.get("worktree_identity")
    identity_fields = (
        "status_sha256", "diff_sha256", "untracked_sha256", "code_inventory_sha256",
        "worktree_sha256",
    )
    identity_ok = isinstance(worktree_identity, dict)
    inventory = worktree_identity.get("code_inventory") if identity_ok else None
    if identity_ok:
        identity_ok = all(
            isinstance(worktree_identity.get(field), str)
            and sha_pattern.fullmatch(worktree_identity[field])
            for field in identity_fields
        )
    if identity_ok:
        identity_ok = isinstance(inventory, list) and bool(inventory)
    inventory_paths = set()
    if identity_ok:
        for item in inventory:
            path = item.get("path") if isinstance(item, dict) else None
            digest = item.get("sha256") if isinstance(item, dict) else None
            if (not isinstance(path, str) or not path or os.path.isabs(path)
                    or ".." in path.replace("\\", "/").split("/")
                    or not isinstance(digest, str) or not sha_pattern.fullmatch(digest)):
                identity_ok = False
                break
            canonical = _canonical_relative_path(path)
            if canonical in inventory_paths:
                identity_ok = False
                break
            inventory_paths.add(canonical)
    entry = supplied.get("module_entry_script") if isinstance(supplied.get("module_entry_script"), dict) else {}
    entry_path = entry.get("path") if isinstance(entry.get("path"), str) and entry.get("path").strip() else None
    entry_hash = entry.get("sha256")
    if not isinstance(entry_hash, str) or not sha_pattern.fullmatch(entry_hash):
        entry_hash = None
    observed_commit, observed_dirty, observed_identity = _observed_repository_state(entry_path)
    package_record = repository.get("package_identity")
    archive_identity = None
    # A release archive has no Git metadata by design.  Re-observe its
    # build-generated byte inventory here rather than accepting the caller's
    # provenance assertion.  Git worktrees deliberately retain the normal
    # dirty-state path above.
    if not os.path.exists(os.path.join(SUITE, ".git")):
        candidate = package_identity.load_and_verify(Path(SUITE))
        if (candidate is not None and isinstance(package_record, dict)
                and package_record.get("source_tree") == candidate["source_tree"]
                and package_record.get("inventory_sha256") == candidate["inventory_sha256"]
                and supplied_commit == candidate["source_commit"]
                and supplied_dirty is False):
            archive_identity = candidate
            observed_commit, observed_dirty, observed_identity = (
                candidate["source_commit"], False, None
            )
    # Persist only observations.  A supplied value remains a consistency
    # assertion, never an authority that can turn a dirty checkout clean.
    commit = observed_commit
    dirty = observed_dirty
    if identity_ok:
        required_inventory = {
            _canonical_relative_path("mcp/server.py"),
            _canonical_relative_path("mcp/publication.py"),
            _canonical_relative_path("skills/_shared/scripts/validate_effect_table_cli.R"),
            _canonical_relative_path("skills/_shared/scripts/effect_table.R"),
        }
        if entry_path:
            required_inventory.add(_canonical_relative_path(entry_path))
        if not required_inventory.issubset(inventory_paths):
            identity_ok = False
        elif entry_path and entry_hash:
            entry_item = next(
                (item for item in inventory if _canonical_relative_path(item["path"])
                 == _canonical_relative_path(entry_path)),
                None,
            )
            if entry_item is None or entry_item["sha256"].casefold() != entry_hash.casefold():
                identity_ok = False
    if dirty is True and (observed_identity is None or worktree_identity != observed_identity):
        identity_ok = False
    session_info = supplied.get("r_session_info")
    if not isinstance(session_info, str) or not session_info.strip():
        session_info = None
    image_id = supplied.get("container_image_id")
    if not isinstance(image_id, str) or not image_pattern.fullmatch(image_id):
        image_id = None

    # Python lane: the omicstat-py interpreter that ran the module (versions,
    # image ID); present only for run_*.py modules, so R-module provenance is unchanged.
    python_engine = supplied.get("python_engine")
    python_engine = json_safe(python_engine) if isinstance(python_engine, dict) else None

    normalized = {
        "python": text_or_unknown("python"),
        "mcp": text_or_unknown("mcp"),
        "r": text_or_unknown("r"),
        "execution_engine": engine,
        "python_packages": python_packages,
        "r_session_info": session_info,
        "r_packages": r_packages,
        "repository": {
            "commit": commit,
            "dirty": dirty,
            "worktree_identity": worktree_identity if identity_ok else None,
            "package_identity": ({
                "source_tree": archive_identity["source_tree"],
                "inventory_sha256": archive_identity["inventory_sha256"],
            } if archive_identity is not None else None),
        },
        "module_entry_script": {"path": entry_path, "sha256": entry_hash},
        "container_image_id": image_id,
        "container_image_warning": (str(supplied.get("container_image_warning"))
                                    if supplied.get("container_image_warning") else None),
        "effect_validator_sha256": hash_value(
            "effect_validator_sha256", os.path.join(SHARED, "scripts", "validate_effect_table_cli.R")
        ),
        "publication_module_rules_sha256": hash_value(
            "publication_module_rules_sha256", os.path.join(RULE_DIR, "module_rules_v1.json")
        ),
        "publication_universal_rules_sha256": hash_value(
            "publication_universal_rules_sha256", os.path.join(RULE_DIR, "universal_rules_v1.json")
        ),
        "publication_finalizer_sha256": hash_value("publication_finalizer_sha256", __file__),
    }
    if python_engine is not None:
        normalized["python_engine"] = python_engine
    gaps = []
    for field in ("python", "mcp", "r"):
        if normalized[field].lower() in {"unknown", "unavailable"}:
            gaps.append(field)
    if not python_packages:
        gaps.append("python_packages")
    elif any(value.lower() in {"unknown", "unavailable"} for value in python_packages.values()):
        gaps.append("python_packages.version")
    if not session_info:
        gaps.append("r_session_info")
    if not r_packages:
        gaps.append("r_packages")
    elif any(value.lower() in {"unknown", "unavailable"} for value in r_packages.values()):
        gaps.append("r_packages.version")
    if commit is None or supplied_commit != commit:
        gaps.append("repository.commit")
    if dirty is None or supplied_dirty is not dirty:
        gaps.append("repository.dirty")
    if dirty is True and not identity_ok:
        gaps.append("repository.worktree_identity")
    if entry_path is None or entry_hash is None:
        gaps.append("module_entry_script")
    if engine == "container" and image_id is None:
        gaps.append("container_image_id")
    if python_engine is not None:
        if str(python_engine.get("python", "unknown")).lower() in {"unknown", "unavailable", ""}:
            gaps.append("python_engine.python")
        if not python_engine.get("packages"):
            gaps.append("python_engine.packages")
    return normalized, gaps


def _is_link_or_reparse(path: str) -> bool:
    """Do not follow symlinks, Windows junctions, or any reparse point."""
    try:
        stat = os.lstat(_native_path(path))
    except OSError:
        return False
    return os.path.islink(_native_path(path)) or bool(getattr(stat, "st_file_attributes", 0) & 0x400)


def _has_link_or_reparse_component(path: str) -> bool:
    path = os.path.abspath(path)
    drive, tail = os.path.splitdrive(path)
    current = drive + os.sep if drive else os.sep
    for component in tail.replace("/", "\\").split("\\"):
        if not component:
            continue
        current = os.path.join(current, component)
        if os.path.lexists(_native_path(current)) and _is_link_or_reparse(current):
            return True
    return False


def safe_join_under(root: str, relative: str, *, require_exists: bool = False) -> str:
    """Join a relative artifact path without following link/reparse components."""
    if not isinstance(relative, str) or not relative or os.path.isabs(relative):
        raise ValueError("unsafe relative path")
    normalized = relative.replace("\\", "/")
    parts = normalized.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        raise ValueError("unsafe relative path: %r" % relative)
    root = os.path.abspath(root)
    if not os.path.isdir(_native_path(root)) or _is_link_or_reparse(root):
        raise ValueError("unsafe root")
    candidate = root
    for part in parts:
        candidate = os.path.join(candidate, part)
        if os.path.lexists(_native_path(candidate)) and _is_link_or_reparse(candidate):
            raise ValueError("link/reparse path refused: %s" % relative)
    parent_real = os.path.realpath(os.path.dirname(candidate))
    root_real = os.path.realpath(root)
    if os.path.commonpath([os.path.normcase(parent_real), os.path.normcase(root_real)]) != os.path.normcase(root_real):
        raise ValueError("path escapes root: %s" % relative)
    if require_exists and not os.path.exists(_native_path(candidate)):
        raise ValueError("missing path: %s" % relative)
    return candidate


def _normalize_category(category: str) -> str:
    normalized = str(category or "other").strip().lower()
    if normalized in {"narrative", "report", "reports"}:
        return "draft"
    if normalized in {
        "tables", "figures", "draft", "qc", "provenance", "publication",
        "machine", "other",
    }:
        return normalized
    return "other"


def classify_artifact(relpath: str, aliases: Optional[Dict[str, str]] = None) -> str:
    normalized_path = relpath.replace("\\", "/")
    parts = normalized_path.split("/")
    name = parts[-1].lower()
    first = parts[0].lower() if len(parts) > 1 else ""
    for pattern, target in (aliases or {}).items():
        pattern = str(pattern).replace("\\", "/").lower()
        if (fnmatch.fnmatch(normalized_path.lower(), pattern)
                or fnmatch.fnmatch(name, pattern)
                or fnmatch.fnmatch(first, pattern)):
            return _normalize_category(target)
    if first in {"tables", "figures", "qc", "provenance", "publication", "machine"}:
        return first
    if first == "figure_data":
        # Python lane (ENGINEERING_PLAN 10.5): data + request the R render step
        # draws from -- machine input of a figure, never a result table.
        return "machine"
    if first in {"draft", "report"}:
        return "draft"
    stem, ext = os.path.splitext(name)
    if ext in FIGURE_EXT:
        return "figures"
    if "qc" in re.split(r"[._-]", stem) or "warning" in stem or "guard" in stem:
        return "qc"
    if any(token in stem for token in ("session", "provenance", "manifest", "spec_used")):
        return "provenance"
    if any(token in stem for token in ("draft", "methods", "results", "legend", "caption")):
        return "draft"
    if ext in {".json", ".rds", ".rda"}:
        return "machine"
    if ext in {".csv", ".md", ".txt", ".docx", ".tsv", ".xlsx"}:
        return "tables"
    return "other"


def safe_walk_under(outdir: str) -> Tuple[List[Tuple[str, str]], List[str]]:
    """Enumerate only ordinary files below ``outdir`` without following redirects.

    This is deliberately the one walker used by publication and server scans.
    A link, junction, or reparse point is evidence of an unsafe output tree,
    never a silently skipped directory.
    """
    root = os.path.abspath(outdir)
    if not os.path.isdir(_native_path(root)) or _has_link_or_reparse_component(root):
        return [], ["unsafe output root: " + root]
    root_real = os.path.realpath(root)
    files: List[Tuple[str, str]] = []
    errors: List[str] = []
    pending = [root]
    while pending:
        current = pending.pop()
        try:
            entries = sorted(list(os.scandir(_native_path(current))), key=lambda entry: entry.name)
        except OSError as exc:
            errors.append("unreadable artifact directory: %s: %s" % (os.path.relpath(current, root), exc))
            continue
        for entry in entries:
            # Keep portable paths for relative-path and manifest processing;
            # entry metadata was obtained through the native directory handle.
            full = os.path.join(current, entry.name)
            rel = os.path.relpath(full, root).replace("\\", "/")
            if _is_link_or_reparse(full):
                errors.append("unsafe link/reparse artifact: " + rel)
                continue
            try:
                real = os.path.realpath(full)
                if os.path.commonpath([os.path.normcase(real), os.path.normcase(root_real)]) != os.path.normcase(root_real):
                    errors.append("artifact escapes output root: " + rel)
                    continue
                if entry.is_dir(follow_symlinks=False):
                    pending.append(full)
                elif entry.is_file(follow_symlinks=False):
                    files.append((rel, full))
            except OSError as exc:
                errors.append("unreadable artifact: %s: %s" % (rel, exc))
    return files, errors


def _iter_files(outdir: str) -> Iterable[Tuple[str, str]]:
    # Compatibility iterator for established callers. Callers needing blocking
    # evidence use ``collect_file_records`` / ``safe_walk_under`` directly.
    return iter(safe_walk_under(outdir)[0])


def collect_file_records(
    outdir: str,
    exclusions: Sequence[str] = (),
    aliases: Optional[Dict[str, str]] = None,
) -> Tuple[List[Dict[str, Any]], List[str]]:
    excluded = {p.replace("\\", "/") for p in exclusions}
    records: List[Dict[str, Any]] = []
    errors: List[str] = []
    walked, walk_errors = safe_walk_under(outdir)
    errors.extend(walk_errors)
    for rel, full in walked:
        if rel in excluded or ".tmp-" in os.path.basename(rel):
            continue
        try:
            records.append({
                "path": rel,
                "bytes": os.path.getsize(_native_path(full)),
                "sha256": sha256_file(full),
                "category": classify_artifact(rel, aliases),
                "media_type": mimetypes.guess_type(full)[0] or "application/octet-stream",
            })
        except OSError as exc:
            errors.append("%s: %s" % (rel, exc))
    return records, errors


def _flatten_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from _flatten_strings(child)
    elif isinstance(value, (list, tuple)):
        for child in value:
            yield from _flatten_strings(child)


def collect_input_records(args: Dict[str, Any], base: str,
                          allowed_roots: Optional[Sequence[str]] = None) -> Tuple[List[Dict[str, Any]], List[str]]:
    seen = set()
    records = []
    errors = []
    roots = [os.path.realpath(os.path.abspath(root)) for root in (allowed_roots or [base])]
    for value in _flatten_strings(args):
        candidate = value if os.path.isabs(value) else os.path.join(base, value)
        candidate = os.path.abspath(candidate)
        if not os.path.isfile(_native_path(candidate)):
            continue
        if _has_link_or_reparse_component(candidate):
            errors.append("unsafe input refused: " + str(value))
            continue
        candidate = os.path.realpath(candidate)
        safe = False
        for root in roots:
            try:
                safe = (os.path.commonpath([os.path.normcase(candidate), os.path.normcase(root)])
                        == os.path.normcase(root))
            except ValueError:
                continue
            if safe:
                break
        if not safe:
            errors.append("unsafe input refused: " + str(value))
            continue
        if candidate in seen or not os.path.isfile(_native_path(candidate)):
            continue
        seen.add(candidate)
        records.append({
            "path": candidate,
            "bytes": os.path.getsize(_native_path(candidate)),
            "sha256": sha256_file(candidate),
        })
    return records, errors


def _truth(value: Any) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "t", "yes", "y", "blocked"}


def _severity(value: Any) -> str:
    raw = str(value or "").strip().lower()
    # "blocker" is the omicstat QC vocabulary (ENGINEERING_PLAN; module qc_results.csv).
    if raw in {"hard_error", "critical", "fatal", "fail", "blocked", "blocker"}:
        return "critical"
    if raw in {"error", "high"}:
        return "error"
    if raw in {"major", "medium", "warning", "warn"}:
        return "warning"
    return "info"


def scan_qc(outdir: str) -> Dict[str, Any]:
    """Normalize the known QC CSV dialects without treating diagnostic tables as rules."""
    findings: List[Dict[str, Any]] = []
    checked = 0
    for rel, full in _iter_files(outdir):
        if not rel.lower().endswith(".csv"):
            continue
        in_qc = classify_artifact(rel) == "qc" or rel.lower().startswith("qc/")
        if not in_qc:
            continue
        try:
            with open(_native_path(full), encoding="utf-8-sig", newline="") as fh:
                rows = list(csv.DictReader(fh))
        except (OSError, csv.Error):
            continue
        if not rows:
            continue
        fields = set(rows[0])
        id_field = next((x for x in ("id", "code", "qc_id", "rule_id") if x in fields), None)
        message_field = "message" if "message" in fields else None
        if not id_field or not message_field:
            continue
        trigger_field = "triggered" if "triggered" in fields else None
        status_field = "status" if "status" in fields else None
        warning_file = "warning" in os.path.basename(rel).lower()
        for row in rows:
            checked += 1
            status = str(row.get(status_field, "") if status_field else "").strip().upper()
            if trigger_field:
                triggered = _truth(row.get(trigger_field))
            elif status_field:
                triggered = status in {"WARN", "WARNING", "FAIL", "ERROR", "BLOCKED", "TRIGGERED"}
            else:
                triggered = warning_file
            if not triggered:
                continue
            raw_severity = row.get("severity", status)
            explicit_blocking = _truth(row.get("blocking")) if "blocking" in fields else False
            blocking = explicit_blocking or status in {"FAIL", "ERROR", "BLOCKED"}
            evidence = next((row.get(k) for k in ("evidence", "evidence_artifact", "artifact") if row.get(k)), "")
            action = next((row.get(k) for k in ("action", "suggested_action", "note") if row.get(k)), "")
            findings.append({
                "id": str(row.get(id_field) or "?").strip(),
                "severity": _severity(raw_severity),
                "message": re.sub(r"\s+", " ", str(row.get(message_field) or "")).strip(),
                "blocking": bool(blocking),
                "action": re.sub(r"\s+", " ", str(action)).strip(),
                "evidence": re.sub(r"\s+", " ", str(evidence)).strip(),
                "source": rel,
            })
    return {
        "checked": checked,
        "triggered": len(findings),
        "blocking": sum(1 for item in findings if item["blocking"]),
        "findings": findings,
    }


def find_effect_table_candidates(outdir: str) -> Dict[str, List[str]]:
    canonical: List[str] = []
    invalid_named: List[str] = []
    local: List[str] = []
    for rel, full in _iter_files(outdir):
        if not rel.lower().endswith(".csv") or classify_artifact(rel) == "qc":
            continue
        try:
            with open(_native_path(full), encoding="utf-8-sig", newline="") as fh:
                reader = csv.reader(fh)
                header = next(reader, [])
                row_count = sum(1 for _ in reader)
        except (OSError, csv.Error, UnicodeError):
            continue
        columns = set(header)
        if CORE_EFFECT_COLUMNS.issubset(columns):
            canonical.append(rel)
        elif "effect_table" in os.path.basename(rel).lower():
            invalid_named.append(rel)
        else:
            has_ci = ({"ci_low", "ci_high"} <= columns or {"lower", "upper"} <= columns)
            if "estimate" in columns and has_ci and "p_value" in columns and 0 < row_count <= 60:
                local.append(rel)
    return {
        "canonical": sorted(canonical),
        "invalid_named": sorted(invalid_named),
        "local": sorted(local),
    }


def _normalize_semantic_value(value: Any) -> Optional[str]:
    text = str(value if value is not None else "").strip()
    return None if text.lower() in {"", "na", "n/a", "null", "none", "."} else text


def _semantic_equal(field: str, left: Any, right: Any) -> bool:
    left, right = _normalize_semantic_value(left), _normalize_semantic_value(right)
    if left is None or right is None:
        return left == right
    try:
        a, b = Decimal(left), Decimal(right)
    except InvalidOperation:
        return left == right
    if not a.is_finite() or not b.is_finite():
        return False
    if field in {"n_unweighted", "n_events"}:
        return a == b and a == a.to_integral_value() and b == b.to_integral_value()
    if a == b:
        return True
    # A displayed decimal denotes its normal half-unit rounding interval.
    def interval(value: Decimal, raw: str) -> Tuple[Decimal, Decimal]:
        places = max(0, -value.as_tuple().exponent) if "e" not in raw.lower() else 12
        half = Decimal(5).scaleb(-(places + 1))
        return value - half, value + half
    a_low, a_high = interval(a, left)
    b_low, b_high = interval(b, right)
    return max(a_low, b_low) <= min(a_high, b_high)


_SEMANTIC_ALIASES = {
    "analysis_id": ("analysis_id", "analysis", "model", "model_id"),
    "term": ("term", "variable", "outcome", "parameter", "label"),
    "level": ("level", "contrast", "comparison", "group"),
    "stratum": ("stratum", "subgroup"),
    "effect_type": ("effect_type", "measure", "effect_measure"),
    "estimate": ("estimate", "effect", "value"),
    "ci_low": ("ci_low", "lower", "lower_ci", "lcl"),
    "ci_high": ("ci_high", "upper", "upper_ci", "ucl"),
    "p_value": ("p_value", "p", "pvalue"),
    "n_unweighted": ("n_unweighted", "n", "sample_size"),
    "n_events": ("n_events", "events"),
}


def _semantic_row(row: Dict[str, Any]) -> Optional[Tuple[str, Dict[str, Any]]]:
    lowered = {str(key).strip().lower(): value for key, value in row.items()}
    if "feature_id" in lowered and any(k in lowered for k in ("log2fc", "pvalue", "padj")):
        fields = ("log2fc", "log2fc_se", "base_mean", "stat", "pvalue", "padj", "n_group1", "n_group2")
        return "feature|" + json.dumps([lowered.get("contrast", ""), lowered["feature_id"]]), {
            k: lowered.get(k) for k in ("contrast", "feature_id") + fields}
    if "estimate" not in lowered and "effect" not in lowered:
        keys = tuple(k for k in ("comparison_cluster", "contrast", "term_id", "cluster", "celltype", "cell", "feature_id", "sample", "batch", "stage", "group", "metric", "variable") if k in lowered)
        numeric = {k: v for k, v in lowered.items() if _number(v) is not None and k not in keys}
        if keys and numeric:
            return "summary|" + json.dumps([[k, lowered[k]] for k in keys]), {**numeric, **{k: lowered[k] for k in keys}}
    mapped = {
        target: next((lowered[name] for name in names if name in lowered), None)
        for target, names in _SEMANTIC_ALIASES.items()
    }
    # Do not invent a key from an arbitrary result JSON. A comparable record
    # has a named estimate plus at least one identifying label.
    if _normalize_semantic_value(mapped["estimate"]) is None or not any(
            _normalize_semantic_value(mapped[key]) is not None
            for key in ("analysis_id", "term", "level", "stratum", "effect_type")):
        return None
    key = "|".join(_normalize_semantic_value(mapped.get(field)) or "" for field in
                   ("analysis_id", "term", "level", "stratum", "effect_type"))
    return key, mapped


def _semantic_json_rows(value: Any) -> List[Dict[str, Any]]:
    if isinstance(value, list) and all(isinstance(item, dict) for item in value):
        return value
    if isinstance(value, dict):
        for key in ("rows", "data", "results", "estimates"):
            rows = value.get(key)
            if isinstance(rows, list) and all(isinstance(item, dict) for item in rows):
                return rows
        return [value]
    return []


def _read_csv(outdir: str, rel: str) -> List[Dict[str, str]]:
    with open(_native_path(safe_join_under(outdir, rel, require_exists=True)), encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def _number(value: Any) -> Optional[Decimal]:
    if isinstance(value, bool) or value is None:
        return None
    try:
        number = Decimal(str(value).replace(",", ""))
        return number if number.is_finite() else None
    except InvalidOperation:
        return None


_NUMBER_RE = re.compile(r"(?<![\w.])[-+]?(?:(?:\d{1,3}(?:,\d{3})+(?!\d)|\d+)(?:\.\d+)?|\.\d+)(?:[eE][-+]?\d+)?%?(?!\w|\.\d)")


def _result_scalars(outdir: str) -> List[Tuple[str, Dict[str, Any], str, Any]]:
    result = []
    def visit(value, source, context, prefix=""):
        if isinstance(value, dict):
            context = {**context, **{k: value[k] for k in ("contrast", "sample", "batch", "cluster", "comparison_cluster", "group") if k in value}}
            for key, child in value.items():
                if "version" not in key.lower():
                    visit(child, source, context, prefix + key + ".")
        elif isinstance(value, list):
            for child in value:
                visit(child, source, context, prefix)
        elif _number(value) is not None:
            result.append((source, context, prefix.rstrip(".").split(".")[-1], value))
    for rel, full in _iter_files(outdir):
        if rel.lower().endswith(".json") and (rel.startswith("results/") or rel.lower() == "results.json" or rel.lower().endswith("_results.json")) and not _is_dynamic_relative_path(rel):
            try:
                with open(_native_path(full), encoding="utf-8-sig") as fh:
                    visit(json.load(fh), rel, {})
            except (OSError, ValueError, UnicodeError):
                continue
    return result


def _text_coverage(outdir: str, canonical_paths: Sequence[str]) -> Dict[str, Any]:
    numbers = []
    for rel in canonical_paths:
        try:
            numbers.extend(n for row in _read_csv(outdir, rel) for k, v in row.items()
                           if k not in {"feature_id", "symbol", "contrast", "term_id", "sample", "cell"}
                           for n in [_number(v)] if n is not None)
        except (OSError, ValueError, csv.Error, UnicodeError):
            continue
    numbers.extend(_number(v) for _, _, _, v in _result_scalars(outdir))
    try:
        for row in _read_csv(outdir, "qc/qc_results.csv"):
            for key, value in row.items():
                if any(word in key.lower() for word in ("evidence", "observed", "threshold", "value")):
                    numbers.extend(_number(m.group().rstrip("%")) for m in _NUMBER_RE.finditer(value or ""))
    except (OSError, ValueError, csv.Error, UnicodeError):
        pass
    errors = []
    try:
        if not os.path.lexists(os.path.join(outdir, "draft", "number_sources.json")):
            raise FileNotFoundError("optional number sources absent")
        with open(safe_join_under(outdir, "draft/number_sources.json", require_exists=True), encoding="utf-8-sig") as fh:
            declared = json.load(fh)
        if not isinstance(declared, dict) or not isinstance(declared.get("numbers", []), list):
            raise ValueError("number_sources must be an object with a numbers list")
        for item in declared.get("numbers", []):
            if isinstance(item, dict) and item.get("source") and _number(item.get("value")) is not None:
                numbers.append(_number(item["value"]))
            else:
                errors.append("number_sources entries require a finite value and source")
    except FileNotFoundError:
        pass
    except (OSError, ValueError, UnicodeError) as exc:
        errors.append(str(exc))
    numbers = sorted(set(n for n in numbers if n is not None))
    files = set()
    for rel, _ in _iter_files(outdir):
        if rel.startswith("draft/") and rel.lower().endswith(".md"):
            files.add(rel)
        if classify_artifact(rel) == "figures" and rel.lower().endswith((".png", ".pdf", ".svg")):
            files.update(_caption_evidence(outdir, rel))
    total, mismatches = 0, []
    for rel in sorted(files):
        try:
            with open(safe_join_under(outdir, rel, require_exists=True), encoding="utf-8-sig") as fh:
                body = fh.read()
                if rel.lower().endswith(".json"):
                    spec = json.loads(body)
                    if not isinstance(spec, dict):
                        raise ValueError("caption figure specification must be an object")
                    body = str(spec.get("caption", ""))
        except (OSError, ValueError, UnicodeError) as exc:
            errors.append(str(exc)); continue
        for sentence in re.split(r"(?<=[.!?])\s+|\n", body):
            # Preserve the original sentence in evidence while excluding versions,
            # artifact paths, URLs and identifiers from numeric tokenization.
            scan = re.sub(r"(?i)\b(?:v(?:ersion)?\s*[:=]?\s*)?\d+\.\d+\.\d+(?:[.-]\w+)*|\b(?:version|v)\s*[:=]?\s*\d+\.\d+", " ", sentence)
            scan = re.sub(r"(?:https?://|(?:figures|tables|results|objects)/)\S+|\b[A-Za-z_]+\d+[\w.-]*", " ", scan)
            for match in _NUMBER_RE.finditer(scan):
                raw = match.group(); printed = _number(raw.rstrip("%"))
                if printed is None or (raw.isdigit() and 1900 <= printed <= 2099):
                    continue
                total += 1
                half = Decimal("0.5").scaleb(printed.as_tuple().exponent)
                # Integers are counts; decimals/scientific values use their printed precision.
                candidates = [printed] if printed.as_tuple().exponent >= 0 and "e" not in raw.lower() else None
                def matches(value):
                    return value == printed if candidates else abs(value - printed) <= half
                covered = any(matches(n) or (raw.endswith("%") and matches(n * 100)) for n in numbers)
                if not covered:
                    mismatches.append({"source": rel, "number": raw, "sentence": sentence.strip()})
    return {"status": "checked" if files else "not_present", "coverage_share": (total - len(mismatches)) / total if total else 1.0,
            "numbers_checked": total, "sources": sorted(files), "mismatches": mismatches, "errors": errors}


def _case_flow_check(outdir: str, canonical_paths: Sequence[str]) -> Dict[str, Any]:
    ledgers, comparisons, mismatches = [], [], []
    scalars = _result_scalars(outdir)
    tables = {}
    for rel, _ in _iter_files(outdir):
        if rel.lower().endswith(".csv") and not _is_dynamic_relative_path(rel):
            try:
                tables[rel] = _read_csv(outdir, rel)
            except (OSError, ValueError, csv.Error, UnicodeError):
                continue
    contrast_scopes = {r.get("contrast") for rel in canonical_paths for r in tables.get(rel, []) if r.get("contrast")}
    def compare(source, context, field, expected, aliases):
        for target, target_context, key, value in scalars:
            if key not in aliases or any(k in target_context and target_context[k] != v for k, v in context.items()):
                continue
            if any(k in target_context and k not in context for k in ("sample", "batch", "cluster", "comparison_cluster", "group")):
                continue
            if "contrast" in context and "contrast" not in target_context and len(contrast_scopes) > 1:
                continue
            item = {"ledger": source, "source": target, "context": context, "field": field, "expected": expected, "observed": value}
            comparisons.append(item)
            if _number(expected) != _number(value):
                mismatches.append(item)
    for rel in canonical_paths:
        rows = tables.get(rel, [])
        if not rows or "filtered_reason" not in rows[0] or "feature_id" not in rows[0]:
            continue
        grouped = {}
        for row in rows:
            grouped.setdefault(row.get("contrast", ""), []).append(row)
        for contrast, group in grouped.items():
            reasons = {}
            for row in group:
                reason = row.get("filtered_reason") or "unfiltered"
                reasons[reason] = reasons.get(reason, 0) + 1
            context = {"contrast": contrast} if contrast else {}
            ledger = {"source": rel, "context": context, "features_in_table": len(group), "filtered_by_reason": reasons}
            ledgers.append(ledger)
            # These suite tables contain fitted features; independent padj filtering is not prefiltering.
            compare(rel, context, "n_tested", len(group), {"n_tested", "n_tested_features"})
            for source, result_context, key, value in scalars:
                if key != "n_prefiltered_out" or (contrast and result_context.get("contrast") != contrast):
                    continue
                inputs = [v for src, ctx, k, v in scalars if src == source and ctx == result_context and k == "n_input_features"]
                if len(inputs) == 1:
                    expected = len(group) + _number(value)
                    ledger["features_in"] = inputs[0]
                    ledger["prefiltered_out"] = value
                    item = {"ledger": rel, "source": source, "context": context, "field": "n_input_features", "expected": str(expected), "observed": inputs[0]}
                    comparisons.append(item)
                    if _number(inputs[0]) != expected:
                        mismatches.append(item)
            for field, aliases in (("n_group1", {"n_group1", "n_target"}), ("n_group2", {"n_group2", "n_reference", "n_ref"})):
                values = {_number(r.get(field)) for r in group} - {None}
                if len(values) == 1:
                    compare(rel, context, field, str(next(iter(values))), aliases)
                elif len(values) > 1:
                    # Conflicting denominators within a contrast are themselves a matched ledger check.
                    item = {"ledger": rel, "source": rel, "context": context, "field": field, "observed": sorted(str(v) for v in values)}
                    comparisons.append(item); mismatches.append(item)
    for rel, rows in tables.items():
        name = os.path.basename(rel).lower()
        if not rows:
            continue
        if name in {"filter_flow.csv", "flow.csv"} or "retention" in name:
            ledgers.append({"source": rel, "rows": rows})
            if "stage" in rows[0] and "n_cells" in rows[0]:
                compare(rel, {}, "n_input_cells", rows[0]["n_cells"], {"n_input_cells", "n_input"})
                compare(rel, {}, "n_cells", rows[-1]["n_cells"], {"n_cells", "n_retained", "n_retained_cells"})
            elif "retained" in rows[0]:
                for field, aliases in (("input", {"n_input", "n_input_cells"}), ("retained", {"n_retained", "n_cells", "n_retained_cells"})):
                    if all(_number(r.get(field)) is not None for r in rows):
                        compare(rel, {}, field, str(sum(_number(r[field]) for r in rows)), aliases)
            # Independent cell audit permits checking QC runs without a result denominator JSON.
            for audit_rel, audit in tables.items():
                if not audit or "cell" not in audit[0]:
                    continue
                flag = next((k for k in ("retained", "pass", "discard") if k in audit[0]), None)
                if flag is None:
                    continue
                kept = sum((not _truth(r[flag])) if flag == "discard" else _truth(r[flag]) for r in audit)
                expected = (_number(rows[-1].get("n_cells")) if "stage" in rows[0]
                            else sum(_number(r.get("retained")) or 0 for r in rows))
                if expected is not None:
                    item = {"ledger": rel, "source": audit_rel, "field": "retained", "expected": str(expected), "observed": kept}
                    comparisons.append(item)
                    if expected != kept:
                        mismatches.append(item)
                for row in rows:
                    group_key = next((k for k in ("sample", "batch") if k in row and k in audit[0]), None)
                    if group_key and _number(row.get("retained")) is not None:
                        subset = [r for r in audit if r[group_key] == row[group_key]]
                        observed = sum((not _truth(r[flag])) if flag == "discard" else _truth(r[flag]) for r in subset)
                        item = {"ledger": rel, "source": audit_rel, "context": {group_key: row[group_key]}, "field": "retained", "expected": row["retained"], "observed": observed}
                        comparisons.append(item)
                        if _number(row["retained"]) != observed:
                            mismatches.append(item)
        if "sample" in rows[0] and ("proportion" in rows[0] or "sample" in name):
            count = len({r["sample"] for r in rows})
            ledgers.append({"source": rel, "n_samples": count})
            compare(rel, {}, "n_samples", count, {"n_samples"})
    return {"status": "checked" if comparisons else "not_present", "ledgers": ledgers,
            "comparisons": comparisons, "mismatches": mismatches}


def semantic_value_map(outdir: str, canonical_paths: Sequence[str]) -> Dict[str, Any]:
    """Compare canonical and other mappable CSV/JSON by a common semantic key."""
    values: Dict[str, Dict[str, Any]] = {}
    conflicts: List[Dict[str, Any]] = []
    coverage_gaps: List[Dict[str, Any]] = []
    included: List[str] = []
    skipped: List[str] = []
    unmappable: List[str] = []
    fields = ("estimate", "ci_low", "ci_high", "p_value", "n_unweighted", "n_events")
    canonical_set = {str(path).replace("\\", "/") for path in canonical_paths}
    # Feature discovery belongs here, not in the effect-table R validator.
    for rel, _ in _iter_files(outdir):
        if rel.startswith("tables/") and rel.lower().endswith(".csv"):
            try:
                rows = _read_csv(outdir, rel)
                if rows:
                    mapped = _semantic_row(rows[0])
                    feature = {"feature_id", "log2fc", "pvalue", "padj"} <= set(rows[0])
                    summary = mapped is not None and mapped[0].startswith("summary|") and not (set(rows[0]) & {"feature_id"})
                    if feature or summary:
                        canonical_set.add(rel)
            except (OSError, ValueError, csv.Error, UnicodeError):
                continue
    canonical_paths = sorted(canonical_set)
    candidates = set(canonical_set)
    walked, walk_errors = safe_walk_under(outdir)
    for rel, _full in walked:
        lower = rel.lower()
        if not lower.endswith((".csv", ".json")):
            continue
        if _is_dynamic_relative_path(rel) or classify_artifact(rel) == "qc":
            skipped.append(rel)
        else:
            candidates.add(rel)
    for error in walk_errors:
        conflicts.append({"key": "<unsafe-tree>", "sources": [], "error": error})
    for rel in sorted(candidates):
        try:
            path = safe_join_under(outdir, rel, require_exists=True)
            if rel.lower().endswith(".csv"):
                with open(_native_path(path), encoding="utf-8-sig", newline="") as fh:
                    rows = list(csv.DictReader(fh))
            else:
                with open(_native_path(path), encoding="utf-8-sig") as fh:
                    rows = _semantic_json_rows(json.load(fh))
            mapped_rows = 0
            for row_no, row in enumerate(rows, 2):
                semantic = _semantic_row(row)
                if semantic is not None and semantic[0].startswith("summary|") and not rel.startswith("tables/"):
                    semantic = None
                if semantic is None:
                    continue
                mapped_rows += 1
                key, mapped = semantic
                if key.startswith("summary|"):
                    # Different native measurements (e.g. counts vs VST) share
                    # row labels but are not estimates of the same quantity.
                    key = "summary|" + rel + "|" + key.removeprefix("summary|")
                row_fields = fields if not key.startswith(("feature|", "summary|")) else tuple(mapped)
                item = {field: _normalize_semantic_value(mapped.get(field, "")) for field in row_fields}
                for field in ("analysis_id", "term", "level", "stratum", "effect_type"):
                    item[field] = _normalize_semantic_value(mapped.get(field, ""))
                item["sources"] = ["%s:%d" % (rel, row_no)]
                for field, value in list(item.items()):
                    if field not in row_fields or value is None:
                        continue
                    try:
                        nonfinite = not Decimal(value).is_finite()
                    except InvalidOperation:
                        nonfinite = False
                    if nonfinite:
                        conflicts.append({"code": "OS_VALUE_NONFINITE", "key": key, "field": field,
                                          "value": value, "source": item["sources"][0]})
                        item[field] = None
                if key in values:
                    prior = values[key]
                    differences = []
                    for field in row_fields:
                        left, right = prior.get(field), item.get(field)
                        if (left is None) != (right is None):
                            coverage_gaps.append({
                                "key": key, "field": field,
                                "missing_sources": prior["sources"] if left is None else item["sources"],
                                "present_sources": item["sources"] if left is None else prior["sources"],
                            })
                            if left is None:
                                prior[field] = right
                        elif left is not None and right is not None and not _semantic_equal(field, left, right):
                            differences.append({"field": field, "left": left, "right": right,
                                                "left_sources": prior["sources"], "right_sources": item["sources"]})
                    if differences:
                        conflicts.append({"key": key, "differences": differences})
                    prior["sources"].extend(item["sources"])
                else:
                    values[key] = item
            if mapped_rows:
                included.append(rel)
            elif rel in canonical_set:
                conflicts.append({"key": "<unmappable-canonical>", "sources": [rel],
                                  "error": "canonical source contained no mappable semantic rows"})
            else:
                unmappable.append(rel)
        except (OSError, ValueError, csv.Error, UnicodeError) as exc:
            conflicts.append({"key": "<unreadable>", "sources": [rel], "error": str(exc)})
    return {
        "schema_version": "omicstat.semantic-value-map.v1",
        "canonical_sources": list(canonical_paths),
        "included_sources": included,
        "skipped_sources": skipped,
        "unmappable_sources": unmappable,
        "values": values,
        "conflicts": conflicts,
        "coverage_gaps": coverage_gaps,
        "text_coverage": _text_coverage(outdir, canonical_paths),
        "case_flow": _case_flow_check(outdir, canonical_paths),
    }


def load_rule_catalogs(module: str) -> Dict[str, Any]:
    universal_path = os.path.join(RULE_DIR, "universal_rules_v1.json")
    module_path = os.path.join(RULE_DIR, "module_rules_v1.json")
    missing = [p for p in (universal_path, module_path) if not os.path.isfile(p)]
    if missing:
        return {
            "ok": False,
            "version": "builtin-minimum-v1",
            "universal": [],
            "module": None,
            "errors": ["rule catalog missing: " + p for p in missing],
        }
    try:
        universal = _read_json(universal_path)
        modules = _read_json(module_path)
        module_rule = next(
            (item for item in modules.get("modules", []) if item.get("module") == module), None
        )
        errors = []
        if module_rule is None:
            errors.append("no module publication rule for " + module)
        return {
            "ok": not errors,
            "version": "universal:%s,module:%s" % (
                universal.get("version", "unknown"), modules.get("version", "unknown")
            ),
            "universal": list(universal.get("rules", [])),
            "module": module_rule,
            "errors": errors,
        }
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return {
            "ok": False,
            "version": "builtin-minimum-v1",
            "universal": [],
            "module": None,
            "errors": ["rule catalog unreadable: %s" % exc],
        }


def _png_dimensions(path: str) -> Optional[Tuple[int, int]]:
    try:
        with open(_native_path(path), "rb") as fh:
            header = fh.read(24)
    except OSError:
        return None
    if (len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n"
            or header[12:16] != b"IHDR"):
        return None
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")


def _caption_evidence(outdir: str, figure_path: str) -> List[str]:
    stem = os.path.splitext(os.path.basename(figure_path))[0].lower()
    evidence: List[str] = []
    for rel, full in _iter_files(outdir):
        lower = rel.lower()
        if lower == os.path.splitext(figure_path)[0].lower() + ".figure_spec.json":
            evidence.append(rel)
            continue
        if not lower.endswith((".md", ".txt")) or rel in {OUTLINE_REL}:
            continue
        sidecar_stem = os.path.splitext(os.path.basename(lower))[0]
        explicit_sidecar = (
            sidecar_stem in {stem, stem + "_caption", stem + "-caption",
                             stem + "_legend", stem + "-legend"}
            or (stem in sidecar_stem and any(x in sidecar_stem for x in ("caption", "legend")))
        )
        mentions_figure = False
        try:
            if os.path.getsize(_native_path(full)) <= 2 * 1024 * 1024:
                with open(_native_path(full), encoding="utf-8", errors="replace") as fh:
                    body = fh.read().lower()
                mentions_figure = os.path.basename(figure_path).lower() in body
        except OSError:
            pass
        if explicit_sidecar or mentions_figure:
            evidence.append(rel)
    return sorted(set(evidence))


def _expectation_matches(
    expectation: str, records: Sequence[Dict[str, Any]]
) -> List[str]:
    """Conservative filename/category evidence, not a semantic content check."""
    phrase = expectation.lower()
    category = None
    if any(x in phrase for x in ("figure", "plot", "curve", "forest", "funnel")):
        category = "figures"
    elif "table" in phrase:
        category = "tables"
    elif any(x in phrase for x in ("qc", "warning")):
        category = "qc"
    elif "provenance" in phrase:
        category = "provenance"
    elif any(x in phrase for x in ("draft", "narrative", "methods", "results text")):
        category = "draft"
    if category:
        return [r["path"] for r in records if r.get("category") == category]

    stop = {
        "and", "or", "when", "used", "requested", "output", "outputs",
        "analysis", "model", "primary", "plot", "table", "figure", "log",
    }
    tokens = [
        token for token in re.findall(r"[a-z0-9]+", phrase)
        if len(token) >= 4 and token not in stop
    ]
    if not tokens:
        return []
    return [
        r["path"] for r in records
        if any(token in r["path"].lower() for token in tokens)
    ]


def automated_publication_checks(
    outdir: str,
    records: Sequence[Dict[str, Any]],
    module_rule: Dict[str, Any],
    effect_validation: Dict[str, Any], value_map: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    expectations = []
    for expected in module_rule.get("artifact_expectations", []) or []:
        matches = _expectation_matches(str(expected), records)
        expectations.append({
            "expectation": str(expected),
            "check_type": "artifact_name_or_category",
            "status": "present" if matches else "not_found",
            "matched_artifacts": matches[:20],
        })

    figures = []
    for record in records:
        if record.get("category") != "figures":
            continue
        rel = str(record["path"])
        full = os.path.join(outdir, *rel.split("/"))
        ext = os.path.splitext(rel)[1].lower()
        dimensions = _png_dimensions(full) if ext == ".png" else None
        captions = _caption_evidence(outdir, rel)
        figures.append({
            "path": rel,
            "caption_sidecar_status": "present" if captions else "not_found",
            "caption_evidence": captions,
            "pixel_dimensions": (
                {"width": dimensions[0], "height": dimensions[1]}
                if dimensions else None
            ),
            "dimension_check": (
                "read" if dimensions else ("invalid_png" if ext == ".png" else "not_applicable")
            ),
        })
    canonical = effect_validation.get("canonical", []) or []
    effect_failures = (
        effect_validation.get("invalid_named", [])
        or effect_validation.get("errors", [])
        or any(not item.get("ok") for item in effect_validation.get("files", []) or [])
    )
    if effect_failures:
        effect_status = "fail"
    elif canonical:
        effect_status = "pass"
    else:
        effect_status = "not_present"
    return {
        "effect_table_schema": {
            "status": effect_status,
            "validator": "skills/_shared/scripts/validate_effect_table_cli.R",
            "validated_files": sum(
                1 for item in effect_validation.get("files", []) or [] if item.get("ok")
            ),
        },
        "artifact_expectations": expectations,
        "figures": figures,
        "cross_artifact_numeric_consistency": {
            "status": "fail" if (value_map or {}).get("conflicts") else "warning",
            "reason": "Canonical effect-table rows were keyed and compared; other CSV/JSON and readable narrative/caption checks remain pending.",
            "conflicts": (value_map or {}).get("conflicts", []),
        },
    }


def finding(
    rule_id: str,
    category: str,
    severity: str,
    message: str,
    recommendation: str,
    *,
    evidence: Sequence[str] = (),
    artifacts: Sequence[str] = (),
    blocking: bool = False,
    human_review: bool = False,
    check_status: str = "warning",
) -> Dict[str, Any]:
    return {
        "rule_id": rule_id,
        "category": category,
        "severity": severity,
        "message": message,
        "evidence_locations": list(evidence),
        "affected_artifacts": list(artifacts),
        "recommendation": recommendation,
        "blocking": bool(blocking),
        "human_review": bool(human_review),
        "check_status": check_status,
    }


def _engine_records(records: Sequence[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [r for r in records if not _is_dynamic_relative_path(r.get("path", ""))]


def engine_anchor_digest(records: Sequence[Dict[str, Any]]) -> str:
    stable = [{k: r.get(k) for k in ("path", "bytes", "sha256")} for r in records]
    stable.sort(key=lambda r: str(r["path"]))
    return hashlib.sha256(json.dumps(stable, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def verify_existing_integrity(base_manifest: Dict[str, Any], outdir: str) -> List[Dict[str, Any]]:
    """Compare to the first engine-output anchor; never promote later bytes."""
    findings = []
    if "engine_outputs" not in base_manifest and "outputs" not in base_manifest:
        return findings
    expected_records = base_manifest.get("engine_outputs")
    if not isinstance(expected_records, list):
        expected_records = _engine_records(base_manifest.get("outputs", []) or [])
    current, errors = collect_file_records(outdir, PUBLICATION_DYNAMIC)
    expected = {str(r.get("path")): str(r.get("sha256")) for r in expected_records}
    actual = {str(r.get("path")): str(r.get("sha256")) for r in _engine_records(current)}
    changed = sorted(path for path in set(expected) & set(actual) if expected[path] != actual[path])
    missing = sorted(set(expected) - set(actual))
    added = sorted(set(actual) - set(expected))
    if errors:
        added.extend(errors)
    if changed or missing or added:
        details = (["changed: " + x for x in changed] + ["missing: " + x for x in missing]
                   + ["unexpected: " + x for x in added])
        findings.append(finding(
            "PUB-INTEGRITY-001", "universal_hard", "critical",
            "Engine artifact anchor mismatch: " + "; ".join(details[:12]),
            "Restore the original engine outputs or create a new UUID run; the anchor is immutable.",
            evidence=[MANIFEST_REL], artifacts=changed + missing + added,
            blocking=True, check_status="fail",
        ))
    stored_digest = base_manifest.get("engine_anchor_digest")
    if stored_digest and stored_digest != engine_anchor_digest(expected_records):
        findings.append(finding("PUB-INTEGRITY-002", "universal_hard", "critical",
            "Manifest engine anchor digest does not match its recorded engine outputs.",
            "Restore the original manifest from the registry baseline.", evidence=[MANIFEST_REL],
            blocking=True, check_status="fail"))
    return findings


def _accepted_human_decision(decision: Any) -> bool:
    if not (isinstance(decision, dict) and decision.get("decision") == "accepted"
            and bool(str(decision.get("reviewer", "")).strip())):
        return False
    locations = decision.get("evidence_locations")
    hashes = decision.get("evidence_sha256")
    if (not isinstance(locations, list) or not locations
            or not all(isinstance(location, str) for location in locations)):
        return False
    return (len(set(locations)) == len(locations)
            and all(not re.match(r"^https?://", location, re.I)
                    and not _is_dynamic_relative_path(location)
                    for location in locations)
            and isinstance(hashes, dict) and set(hashes) == set(locations)
            and all(isinstance(value, str) and re.fullmatch(r"[a-fA-F0-9]{64}", value)
                    for value in hashes.values()))


def _status(findings: Sequence[Dict[str, Any]], reviewer_decisions: Optional[Dict[str, Any]] = None,
            rule_execution: Optional[Sequence[Dict[str, Any]]] = None) -> str:
    reviewer_decisions = reviewer_decisions or {}
    if any(item.get("blocking") for item in findings):
        return "blocked"
    if any(item.get("check_status") == "needs_input" for item in findings):
        return "needs_input"
    def unresolved(item: Dict[str, Any]) -> bool:
        decision = reviewer_decisions.get(item.get("rule_id"), {})
        accepted = _accepted_human_decision(decision)
        # Only a genuine human item can be resolved; warnings from automated
        # checks remain review-required unless explicitly human-reviewable.
        return not (accepted and item.get("human_review"))
    if any((item.get("human_review") or item.get("check_status") in {"warning", "not_checked"})
           and unresolved(item) for item in findings):
        return "review_required"
    # Findings are not a complete execution ledger: an otherwise clean run
    # must not become ready merely because no finding happened to be emitted.
    # Journal preferences are intentionally excluded from this release gate.
    if rule_execution and any(
            item.get("applicable", True) and item.get("category") != "journal_specific"
            and item.get("status") not in {"pass", "decision"}
            for item in rule_execution):
        return "review_required"
    return "ready_for_manuscript_integration"


def build_review(
    *,
    outdir: str,
    run_id: str,
    module: str,
    exit_code: Optional[int],
    timed_out: bool,
    artifact_count: int,
    study_contract: Optional[Dict[str, Any]],
    contract_errors: Sequence[str],
    effect_validation: Dict[str, Any],
    qc: Dict[str, Any],
    integrity_findings: Sequence[Dict[str, Any]],
    output_records: Sequence[Dict[str, Any]],
    reviewer_decisions: Optional[Dict[str, Any]] = None,
    value_map: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    catalogs = load_rule_catalogs(module)
    module_rule = catalogs.get("module") or {}
    automated_checks = automated_publication_checks(
        outdir,
        output_records,
        module_rule,
        effect_validation, value_map,
    )
    findings: List[Dict[str, Any]] = list(integrity_findings)
    case_flow = (value_map or {}).get("case_flow", {})
    if case_flow.get("status") == "checked":
        mismatches = case_flow.get("mismatches", [])
        findings.append(finding(
            "PUB-U-001", "universal_hard", "warning",
            "Denominator ledger checked; %d mismatch(es)." % len(mismatches),
            "Review feature filtering, cell retention and biological sample denominators.",
            evidence=[VALUE_MAP_REL], human_review=True, blocking=False,
            check_status="fail" if mismatches else "pass"))
    from module_seal import verify_module_seal
    seal = verify_module_seal(Path(SUITE), module)
    if not seal["ok"]:
        findings.append(finding(
            "PUB-LOCK-001", "universal_hard", "critical",
            "The analysis module is unsealed or its bound source/baseline changed: " + "; ".join(seal["problems"][:5]),
            "Complete the pinned-container acceptance and regenerate the real module lock before manuscript use.",
            evidence=["skills/" + module + "/module_lock.json"], blocking=True, check_status="fail",
        ))
    if timed_out or exit_code not in (0, None):
        findings.append(finding(
            "PUB-EXEC-001", "universal_hard", "critical",
            "The analysis timed out or returned a non-zero exit code.",
            "Resolve the engine failure before using any output in a manuscript.",
            evidence=["MCP execution envelope"], blocking=True, check_status="fail",
        ))
    if artifact_count == 0:
        findings.append(finding(
            "PUB-ARTIFACT-001", "universal_hard", "critical",
            "No analysis artifact was produced.",
            "Run the module successfully before publication review.",
            blocking=True, check_status="fail",
        ))
    if contract_errors:
        findings.append(finding(
            "PUB-CONTRACT-001", "design_conditional", "error",
            "StudyContract v1 is invalid: " + "; ".join(contract_errors[:5]),
            "Correct the contract fields and re-run publication validation.",
            blocking=True, check_status="fail",
        ))
    elif study_contract is None:
        findings.append(finding(
            "PUB-CONTRACT-001", "design_conditional", "warning",
            "No StudyContract v1 was supplied, so design-dependent reporting cannot be completed.",
            "Supply study_contract with population, estimand, exposure/intervention, comparator, outcomes, covariates, missing-data, multiplicity, and analysis-set declarations.",
            check_status="needs_input",
        ))

    invalid_named = effect_validation.get("invalid_named", [])
    validator_files = effect_validation.get("files", []) or []
    invalid_files = [item for item in validator_files if not item.get("ok")]
    validator_errors = effect_validation.get("errors", []) or []
    if isinstance(validator_errors, str):
        validator_errors = [validator_errors]
    if invalid_named or invalid_files or validator_errors:
        affected = list(invalid_named) + [str(item.get("path", "")) for item in invalid_files]
        details = [str(x) for x in validator_errors]
        for item in invalid_files:
            errors = item.get("errors", [])
            if isinstance(errors, str):
                errors = [errors]
            details.extend(str(x) for x in errors)
        findings.append(finding(
            "PUB-U-002", "universal_hard", "critical",
            "A canonical effect-table artifact failed the shared R schema validator. "
            + "; ".join(details[:4]),
            "Repair the producing module or withhold the affected estimate table.",
            evidence=affected, artifacts=affected, blocking=True, check_status="fail",
        ))
    if (value_map or {}).get("conflicts"):
        findings.append(finding("PUB-U-003", "universal_hard", "critical",
            "Canonical semantic value-map conflict(s) were found for the same estimate key.",
            "Repair conflicting output before publication.", evidence=[VALUE_MAP_REL],
            blocking=True, check_status="fail"))

    policy = module_rule.get("effect_table_policy") or {}
    canonical_ok = any(item.get("ok") for item in validator_files)
    module_messages: List[str] = []
    module_blocking = False
    # v0 callers deliberately have no design contract.  They retain the
    # documented ``needs_input`` review state instead of being promoted to a
    # contract-shaped hard failure solely because a design-dependent rule
    # cannot yet be evaluated.  Calls that provide a contract remain strict.
    if (study_contract is not None and policy
            and not policy.get("allow_no_effect_table", False) and not canonical_ok):
        module_messages.append(
            "The module publication rule requires a validated canonical effect table, but none was found."
        )
        module_blocking = True

    missing_expectations = [
        item["expectation"]
        for item in automated_checks["artifact_expectations"]
        if item["status"] == "not_found"
    ]
    if missing_expectations:
        module_messages.append(
            "Filename/category inventory did not locate expected artifact(s): "
            + "; ".join(missing_expectations)
            + ". This is a conservative presence check, not a semantic content check."
        )

    if qc.get("blocking", 0):
        affected = [item.get("source", "") for item in qc.get("findings", []) if item.get("blocking")]
        findings.append(finding(
            "PUB-QC-001", "universal_hard", "critical",
            "%d blocking engine QC finding(s) were triggered." % qc["blocking"],
            "Resolve the blocking module QC findings before using results.",
            evidence=affected, artifacts=affected, blocking=True, check_status="fail",
        ))

    if not catalogs.get("ok"):
        findings.append(finding(
            "PUB-RULES-001", "advisory", "warning",
            "; ".join(catalogs.get("errors", [])) or "Publication rules could not be loaded.",
            "Restore and validate the shared rule catalogs, then repeat review.",
            human_review=True, check_status="not_checked",
        ))
    elif module_rule:
        if not module_messages:
            module_messages.append(
                "Module-specific narrative and diagnostic requirements require reviewer confirmation: "
                + "; ".join(module_rule.get("required_diagnostics", [])[:4])
            )
        findings.append(finding(
            str(module_rule.get("rule_id", "PUB-MODULE-001")),
            str(module_rule.get("category", "design_conditional")),
            "error" if module_blocking else "warning",
            " ".join(module_messages),
            "Confirm the module rule against the declared design and listed artifacts.",
            evidence=["skills/_shared/publication/module_rules_v1.json"],
            artifacts=list(effect_validation.get("local", [])),
            blocking=module_blocking,
            human_review=not module_blocking,
            check_status="fail" if module_blocking else "not_checked",
        ))

    figure_paths = [r["path"] for r in output_records if r.get("category") == "figures"]
    if figure_paths:
        figure_problems = [
            item["path"] for item in automated_checks["figures"]
            if item["caption_sidecar_status"] != "present"
            or item["dimension_check"] == "invalid_png"
        ]
        findings.append(finding(
            "PUB-U-004", "universal_hard", "warning",
            "Automated figure inventory checked PNG dimensions and caption-sidecar evidence; "
            "%d figure(s) lacked caption evidence or had an unreadable PNG header. "
            "Accessibility, font size, and clipping remain human-review items."
            % len(figure_problems),
            "Inspect every figure at manuscript size and record the human decision.",
            artifacts=figure_problems or figure_paths,
            human_review=True,
            check_status="warning" if figure_problems else "not_checked",
        ))

    text_coverage = (value_map or {}).get("text_coverage", {})
    if not (value_map or {}).get("conflicts") and text_coverage.get("status") == "checked":
        mismatches = text_coverage.get("mismatches", [])
        findings.append(finding(
            "PUB-U-003", "universal_hard", "warning",
            "Numeric text coverage was %.3f; %d uncovered number(s)." % (text_coverage.get("coverage_share", 0), len(mismatches)),
            "Review uncovered sentences, caption direction, rounding and declared number sources.",
            evidence=[VALUE_MAP_REL], human_review=True, blocking=False,
            check_status="fail" if mismatches or text_coverage.get("errors") else "pass"))
    elif not (value_map or {}).get("conflicts"):
        findings.append(finding(
            "PUB-U-003", "universal_hard", "warning",
            "Canonical tables were automatically checked through semantic_value_map; readable narrative, DOCX, caption direction and rounding remain human review.",
            "Compare narrative, tables, captions, and manifest before integration.",
            evidence=[VALUE_MAP_REL], human_review=True, check_status="not_checked",
        ))

    # A rule has one review record. Merge repeated integrity/module reports so
    # finding IDs remain stable and unambiguous for downstream automation.
    unique: Dict[str, Dict[str, Any]] = {}
    for item in findings:
        rule_id = item["rule_id"]
        if rule_id not in unique:
            unique[rule_id] = item
            continue
        prior = unique[rule_id]
        prior["message"] += " " + item["message"]
        prior["evidence_locations"] = sorted(set(
            prior["evidence_locations"] + item["evidence_locations"]
        ))
        prior["affected_artifacts"] = sorted(set(
            prior["affected_artifacts"] + item["affected_artifacts"]
        ))
        prior["blocking"] = prior["blocking"] or item["blocking"]
        prior["human_review"] = prior["human_review"] or item["human_review"]
        if item["check_status"] == "fail":
            prior["check_status"] = "fail"
    findings = list(unique.values())

    reviewer_decisions = reviewer_decisions or {}
    # Every applicable release-gating rule receives an execution record and a
    # reviewable finding when the finalizer did not actually check it. This
    # prevents an empty findings list from impersonating an all-pass review.
    execution_rules = list(catalogs.get("universal", [])) + ([module_rule] if module_rule else [])
    def rule_is_applicable(rule: Dict[str, Any]) -> bool:
        # A figure-readability/caption check has no subject when no figure was
        # produced. Keep it traceable as explicitly not applicable instead of
        # creating an irrelevant pending reviewer task.
        return not (str(rule.get("rule_id", "")) in {"PUB-U-004", "PUB-U-006"}
                    and not figure_paths)
    for rule in execution_rules:
        rule_id = str(rule.get("rule_id", rule.get("id", "unknown")))
        category = str(rule.get("category", "advisory"))
        if category == "journal_specific" or not rule_is_applicable(rule) or rule_id in unique:
            continue
        findings.append(finding(
            rule_id, category, _severity(rule.get("severity")),
            "This applicable publication rule was not automatically checked.",
            "Record a reviewer decision with fixed evidence before manuscript integration.",
            evidence=["skills/_shared/publication/universal_rules_v1.json"],
            human_review=True, check_status="not_checked",
        ))
    # The additional records above are unique by construction; rebuild the
    # lookup used by the execution ledger.
    unique = {item["rule_id"]: item for item in findings}
    findings = list(unique.values())
    human_review_pending = [{
        "rule_id": "PUB-U-003",
        "scope": "cross_artifact_consistency",
        "reason": automated_checks["cross_artifact_numeric_consistency"]["reason"],
        "artifacts": [r["path"] for r in output_records],
    }]
    if figure_paths:
        human_review_pending.append({
            "rule_id": "PUB-U-004",
            "scope": "figure_visual_quality",
            "reason": "Font readability, clipping, axis meaning, and colour accessibility require visual inspection.",
            "artifacts": figure_paths,
        })
    if module_rule:
        human_review_pending.append({
            "rule_id": str(module_rule.get("rule_id", "PUB-MODULE-001")),
            "scope": "module_narrative_and_diagnostics",
            "reason": "Required diagnostics and narrative points require design-aware confirmation.",
            "artifacts": [],
        })

    existing_pending = {item["rule_id"] for item in human_review_pending}
    for rule in execution_rules:
        rule_id = str(rule.get("rule_id", rule.get("id", "unknown")))
        item = unique.get(rule_id)
        if (not rule_is_applicable(rule) or str(rule.get("category", "")) == "journal_specific"
                or not item or not item.get("human_review") or rule_id in existing_pending):
            continue
        human_review_pending.append({
            "rule_id": rule_id,
            "scope": "publication_rule",
            "reason": item["message"],
            "artifacts": list(item.get("affected_artifacts", [])),
        })

    human_review_pending = [item for item in human_review_pending if not
                            _accepted_human_decision(reviewer_decisions.get(item["rule_id"]))]
    rule_execution = [
        {
            "rule_id": str(rule.get("rule_id", rule.get("id", "unknown"))),
            "category": str(rule.get("category", "advisory")),
            "applicable": rule_is_applicable(rule),
            "status": (
                "not_checked" if not rule_is_applicable(rule)
                else ("decision" if _accepted_human_decision(reviewer_decisions.get(str(rule.get("rule_id", rule.get("id", "unknown")))))
                      else ("warning" if str(rule.get("category", "")) == "journal_specific"
                            else next((item["check_status"] for item in findings
                                       if item["rule_id"] == str(rule.get("rule_id", rule.get("id", "unknown")))), "not_checked")))
            ),
            "evidence": next((item["evidence_locations"] for item in findings
                              if item["rule_id"] == str(rule.get("rule_id", rule.get("id", "unknown")))), []),
        }
        for rule in execution_rules
    ]
    applicable_count = sum(1 for item in rule_execution if item["applicable"])
    checked_count = sum(1 for item in rule_execution if item["applicable"] and item["status"] != "not_checked")
    pending_count = sum(1 for item in rule_execution if item["applicable"] and item["status"] in {"not_checked", "needs_input", "warning"})
    status = _status(findings, reviewer_decisions, rule_execution)
    review = {
        "schema_version": REVIEW_VERSION,
        "run_id": run_id,
        "module": module,
        "status": status,
        "reviewed_at": utc_now(),
        "rules_version": catalogs.get("version", "builtin-minimum-v1"),
        "summary": {
            "applicable": applicable_count,
            "checked": checked_count,
            "pending": pending_count,
            "triggered": len(findings),
            "blocking": sum(1 for item in findings if item["blocking"]),
            "human_review": sum(1 for item in findings if item["human_review"]),
        },
        "automated_checks": automated_checks,
        "rule_execution": rule_execution,
        "human_review_pending": human_review_pending,
        "reviewer_decisions": reviewer_decisions,
        "findings": findings,
    }
    errors = validate_instance(review, "publication_review")
    if errors:
        raise RuntimeError("PublicationReview v1 failed its own schema: " + "; ".join(errors))
    return review


def _outline(review: Dict[str, Any], records: Sequence[Dict[str, Any]],
             contract: Optional[Dict[str, Any]], value_map: Dict[str, Any]) -> str:
    tables = [r["path"] for r in records if r.get("category") == "tables"]
    figures = [r["path"] for r in records if r.get("category") == "figures"]
    lines = [
        "# Results outline", "",
        "Publication status: `%s`." % review["status"], "",
        "## Methods", "",
        "- Study design: %s." % ((contract or {}).get("study_design") or "requires StudyContract input"),
        "## Results", "",
        "- Use only estimates that passed the canonical effect-table and module QC checks.",
        "## Tables and figures", "",
    ]
    for key, value in list((value_map.get("values") or {}).items())[:12]:
        estimate = value.get("estimate")
        if estimate is not None:
            identity = [str(value.get(field)).strip() for field in
                        ("analysis_id", "term", "level", "stratum", "effect_type")
                        if value.get(field) is not None and str(value.get(field)).strip()]
            label = " - ".join(identity) or "reported estimate"
            clauses = [str(estimate)]
            if value.get("ci_low") is not None and value.get("ci_high") is not None:
                clauses.append("CI %s to %s" % (value["ci_low"], value["ci_high"]))
            if value.get("p_value") is not None:
                clauses.append("p=%s" % value["p_value"])
            sources = value.get("sources") or []
            source = " (source: `%s`)" % sources[0] if sources else ""
            lines.append("- Machine-derived estimate for %s: %s%s." %
                         (label, "; ".join(clauses), source))
    lines.append("- Numeric text coverage: %s; coverage share: %s." % (value_map.get("text_coverage", {}).get("status", "not_present"), value_map.get("text_coverage", {}).get("coverage_share", "unavailable")))
    lines.append("- Denominator ledger: %s; mismatches: %d." % (value_map.get("case_flow", {}).get("status", "not_present"), len(value_map.get("case_flow", {}).get("mismatches", []))))
    lines.append("")
    for path in tables[:20]:
        lines.append("- Table artifact: `%s`" % path)
    for path in figures[:20]:
        lines.append("- Figure artifact: `%s`" % path)
    if not tables and not figures:
        lines.append("- No table or figure artifact was indexed.")
    lines.extend(["", "## Limitations", ""])
    for item in review["findings"]:
        lines.append("- %s: %s" % (item["rule_id"], item["message"]))
    return "\n".join(lines) + "\n"


def _memory_record(rel: str, value: Any, *, text: bool = False) -> Dict[str, Any]:
    """Return the record a candidate artifact will have after transaction commit."""
    if text:
        content = str(value).encode("utf-8")
    else:
        content = (json.dumps(json_safe(value), ensure_ascii=False, indent=2,
                              sort_keys=False, allow_nan=False) + "\n").encode("utf-8")
    return {
        "path": rel, "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest(),
        "category": classify_artifact(rel),
        "media_type": mimetypes.guess_type(rel)[0] or "application/octet-stream",
    }


def finalize_run(
    base_manifest: Dict[str, Any],
    *,
    study_contract: Optional[Dict[str, Any]],
    effect_validation: Dict[str, Any],
    software_versions: Dict[str, Any],
    input_base: str,
    allowed_input_roots: Optional[Sequence[str]] = None,
    write_manifest: bool = True,
) -> Dict[str, Any]:
    """Write the five standard publication artifacts and return the full manifest."""
    serialization_warnings: List[Dict[str, str]] = []
    manifest = copy.deepcopy(json_safe(base_manifest, serialization_warnings))
    raw_outdir_text = str(manifest["outdir"])
    if any(part == ".." for part in re.split(r"[\\/]", raw_outdir_text)):
        raise ValueError("unsafe output directory")
    raw_outdir = os.path.abspath(raw_outdir_text)
    if _is_link_or_reparse(raw_outdir):
        raise ValueError("unsafe output directory")
    outdir = os.path.realpath(raw_outdir)
    run_id = str(manifest["run_id"])
    module = str(manifest["module"])
    catalogs = load_rule_catalogs(module)
    artifact_aliases = (catalogs.get("module") or {}).get("artifact_aliases", {}) or {}
    os.makedirs(_native_path(safe_join_under(outdir, "publication")), exist_ok=True)
    os.makedirs(_native_path(safe_join_under(outdir, "provenance")), exist_ok=True)

    contract, contract_errors = normalize_study_contract(study_contract)
    integrity_findings = verify_existing_integrity(manifest, outdir)
    manifest["reviewer_decisions"] = snapshot_reviewer_evidence(
        outdir, manifest.get("reviewer_decisions", {})
    )
    provenance_versions, provenance_gaps = normalize_provenance(
        software_versions, str(manifest.get("engine"))
    )
    if provenance_gaps:
        integrity_findings.append(finding(
            "PUB-PROVENANCE-001", "universal_hard", "critical",
            "Required reproducibility provenance is unavailable: " + ", ".join(provenance_gaps),
            "Capture repository, module-script, Python/R package, R session, and container identity before release.",
            evidence=[MANIFEST_REL], blocking=True, check_status="fail",
        ))
    # Rebuild every dynamic artifact in memory.  Excluding all dynamic paths
    # makes a prior incomplete generation unable to influence this candidate.
    initial_records, record_errors = collect_file_records(
        outdir, list(PUBLICATION_DYNAMIC), artifact_aliases
    )
    engine_outputs = manifest.get("engine_outputs")
    if not isinstance(engine_outputs, list):
        engine_outputs = _engine_records(initial_records)
    anchor_digest = str(manifest.get("engine_anchor_digest") or engine_anchor_digest(engine_outputs))
    qc = scan_qc(outdir)
    if record_errors:
        integrity_findings.append(finding(
            "PUB-INTEGRITY-002", "universal_hard", "critical",
            "One or more artifacts could not be hashed: " + "; ".join(record_errors[:5]),
            "Close or repair unreadable artifacts and repeat validation.",
            blocking=True, check_status="fail",
        ))
    request_args = (manifest.get("request") or {}).get("args", manifest.get("args", {}))
    if not isinstance(request_args, dict):
        request_args = {}
    inputs, input_errors = collect_input_records(request_args, input_base, allowed_input_roots)
    if input_errors:
        integrity_findings.append(finding(
            "PUB-INPUT-001", "universal_hard", "critical",
            "One or more declared inputs could not be hashed: " + "; ".join(input_errors[:5]),
            "Repair or remove unreadable/disallowed inputs before publication review.",
            blocking=True, check_status="fail",
        ))
    value_map = semantic_value_map(outdir, effect_validation.get("canonical", []) or [])
    review = build_review(
        outdir=outdir,
        run_id=run_id,
        module=module,
        exit_code=manifest.get("exit_code"),
        timed_out=bool(manifest.get("timed_out", False)),
        artifact_count=int(manifest.get("artifact_count", len(initial_records)) or 0),
        study_contract=contract,
        contract_errors=contract_errors,
        effect_validation=effect_validation,
        qc=qc,
        integrity_findings=integrity_findings,
        output_records=initial_records,
        reviewer_decisions=manifest.get("reviewer_decisions"),
        value_map=value_map,
    )
    outline = _outline(review, initial_records, contract, value_map)
    indexed_records = sorted(initial_records + [
        _memory_record(VALUE_MAP_REL, value_map),
        _memory_record(REVIEW_REL, review),
        _memory_record(OUTLINE_REL, outline, text=True),
    ], key=lambda item: item["path"])
    index_errors = list(record_errors)
    artifact_index = {
        "schema_version": ARTIFACT_INDEX_VERSION,
        "run_id": run_id,
        "module": module,
        "generated_at": utc_now(),
        "artifacts": indexed_records,
        "errors": index_errors,
        "integrity_exclusions": [INDEX_REL, MANIFEST_REL],
    }
    output_records = sorted(indexed_records + [
        _memory_record(INDEX_REL, artifact_index),
    ], key=lambda item: item["path"])
    output_errors = list(record_errors)
    seed = next((request_args.get(key) for key in ("seed", "random-seed", "random_seed")
                 if request_args.get(key) is not None), None)

    manifest.update({
        "schema_version": MANIFEST_VERSION,
        "status": review["status"],
        "created_at": manifest.get("created_at") or utc_now(),
        "request": {
            "module": module,
            "engine": manifest.get("engine"),
            "args": request_args,
            "study_contract": contract,
        },
        "software_versions": provenance_versions,
        "random_seed": seed,
        "inputs": inputs,
        "outputs": output_records,
        "qc": qc,
        "rules_version": review["rules_version"],
        "integrity_exclusions": INTEGRITY_EXCLUSIONS,
        "publication_review": REVIEW_REL,
        "artifact_index": INDEX_REL,
        "results_outline": OUTLINE_REL,
        "value_map": VALUE_MAP_REL,
        "effect_table_validation": effect_validation,
        "engine_outputs": engine_outputs,
        "engine_anchor_digest": anchor_digest,
        "serialization_warnings": serialization_warnings,
        "reviewer_decisions": manifest.get("reviewer_decisions", {}),
        "runtime": {
            "execution_engine": manifest.get("engine"),
            "versions": {
                "python": provenance_versions["python"],
                "mcp": provenance_versions["mcp"],
                "r": provenance_versions["r"],
            },
            "container_image_id": provenance_versions.get("container_image_id"),
            "container_image_warning": provenance_versions.get("container_image_warning"),
        },
        "validator": {
            "effect_table": "skills/_shared/scripts/validate_effect_table_cli.R",
            "path": "skills/_shared/scripts/validate_effect_table_cli.R",
            "sha256": provenance_versions["effect_validator_sha256"],
            "status": ("executed" if effect_validation.get("canonical") and effect_validation.get("files")
                       else ("failed" if effect_validation.get("canonical") or effect_validation.get("errors")
                             else "not_applicable")),
        },
        "finalizer": {"path": "mcp/publication.py", "sha256": sha256_file(__file__)},
        "rule_catalog_hashes": {
            "universal": sha256_file(os.path.join(RULE_DIR, "universal_rules_v1.json")),
            "module": sha256_file(os.path.join(RULE_DIR, "module_rules_v1.json")),
        },
        "literature_provenance": manifest.get("literature_provenance", {
            "status": "not_supplied", "citations": [],
        }),
        "structured_warnings": manifest.get("structured_warnings", []),
    })
    if output_errors:
        manifest["output_hash_errors"] = output_errors
        manifest["status"] = "blocked"
    if input_errors:
        manifest["input_hash_errors"] = input_errors
    # Recheck immediately before schema validation/write so a concurrent
    # evidence mutation cannot leave a decision carrying a stale digest.
    manifest["reviewer_decisions"] = validate_reviewer_decisions(
        outdir, manifest.get("reviewer_decisions", {}), use_snapshots=True
    )
    errors = validate_instance(manifest, "publication_manifest")
    if errors:
        raise RuntimeError("PublicationManifest v1 failed its own schema: " + "; ".join(errors))
    manifest["_publication_transaction"] = {
        "artifacts": {
            VALUE_MAP_REL: value_map,
            REVIEW_REL: review,
            OUTLINE_REL: outline,
            INDEX_REL: artifact_index,
        },
    }
    if write_manifest:
        _commit_publication_group(manifest)
    return manifest


def read_publication_manifest(outdir: str) -> Optional[Dict[str, Any]]:
    path = safe_join_under(outdir, MANIFEST_REL)
    if not os.path.isfile(_native_path(path)):
        return None
    manifest = _read_json(path)
    if manifest.get("status") == "ready_for_manuscript_integration":
        if os.path.exists(_native_path(_commit_failure_path(outdir))) or not _ready_commit_marker_is_valid(outdir, manifest):
            raise ValueError("publication ready state lacks a valid atomic commit marker")
    return manifest


@contextmanager
def _registry_lock(registry_root: str) -> Iterable[None]:
    """Serialize registry CAS independently from the output-tree manifest."""
    os.makedirs(_native_path(registry_root), exist_ok=True)
    key = os.path.normcase(os.path.abspath(registry_root))
    with _REGISTRY_LOCKS_GUARD:
        lock = _REGISTRY_LOCKS.setdefault(key, threading.Lock())
    with lock:
        lock_path = os.path.join(registry_root, ".publication-registry.lock")
        with open(_native_path(lock_path), "a+b") as fh:
            fh.seek(0)
            if not fh.read(1):
                fh.seek(0)
                fh.write(b"0")
                fh.flush()
            try:
                if os.name == "nt":
                    import msvcrt
                    fh.seek(0)
                    msvcrt.locking(fh.fileno(), msvcrt.LK_LOCK, 1)
                else:
                    import fcntl
                    fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
                yield
            finally:
                if os.name == "nt":
                    fh.seek(0)
                    msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1)
                else:
                    fcntl.flock(fh.fileno(), fcntl.LOCK_UN)


def _registry_record(manifest: Dict[str, Any], manifest_digest: str,
                     previous: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    record = {
        "schema_version": "omicstat.run-registry.v1",
        "run_id": manifest["run_id"],
        "module": manifest["module"],
        "outdir": manifest["outdir"],
        "manifest_path": os.path.join(manifest["outdir"], *MANIFEST_REL.split("/")),
        "status": manifest["status"],
        "manifest_digest": manifest_digest,
        "engine_anchor_digest": manifest.get("engine_anchor_digest"),
        "updated_at": utc_now(),
    }
    if previous:
        # Preserve the first immutable manifest digest separately. The current
        # manifest digest is auditable and may change only through finalization.
        record["initial_manifest_digest"] = previous.get("initial_manifest_digest", previous.get("manifest_digest"))
    else:
        record["initial_manifest_digest"] = manifest_digest
    return record


def _check_registry_cas(path: str, manifest: Dict[str, Any],
                        expected_previous_digest: Optional[str]) -> Optional[Dict[str, Any]]:
    if not os.path.exists(_native_path(path)):
        return None
    previous = _read_json(path)
    if (previous.get("run_id") != manifest["run_id"]
            or previous.get("engine_anchor_digest") != manifest.get("engine_anchor_digest")):
        raise ValueError("registry baseline conflict; refusing to replace run anchor")
    if not expected_previous_digest or previous.get("manifest_digest") != expected_previous_digest:
        raise ValueError("registry update requires the verified previous manifest digest")
    return previous


def _snapshot_bytes(path: str) -> Optional[bytes]:
    if not os.path.isfile(_native_path(path)):
        return None
    with open(_native_path(path), "rb") as fh:
        return fh.read()


def _restore_snapshot(path: str, prior: Optional[bytes]) -> None:
    if prior is None:
        if os.path.exists(_native_path(path)):
            os.remove(_native_path(path))
    else:
        _atomic_write_bytes(path, prior)


def _commit_failure_path(outdir: str) -> str:
    return safe_join_under(outdir, COMMIT_FAILURE_REL)


def _commit_marker_path(outdir: str) -> str:
    return safe_join_under(outdir, COMMIT_MARKER_REL)


def _write_commit_marker(outdir: str, manifest: Dict[str, Any]) -> None:
    """Atomically expose a fully written ready generation to readers."""
    manifest_path = safe_join_under(outdir, MANIFEST_REL, require_exists=True)
    marker = {
        "schema_version": "omicstat.publication-commit.v1",
        "status": manifest["status"],
        "run_id": manifest["run_id"],
        "manifest_sha256": sha256_file(manifest_path),
        "committed_at": utc_now(),
    }
    _atomic_write_text(_commit_marker_path(outdir), json.dumps(marker, sort_keys=True) + "\n")


def _ready_commit_marker_is_valid(outdir: str, manifest: Dict[str, Any]) -> bool:
    try:
        marker = _read_json(_commit_marker_path(outdir))
        manifest_path = safe_join_under(outdir, MANIFEST_REL, require_exists=True)
        return (marker.get("schema_version") == "omicstat.publication-commit.v1"
                and marker.get("status") == "ready_for_manuscript_integration"
                and marker.get("run_id") == manifest.get("run_id")
                and marker.get("manifest_sha256") == sha256_file(manifest_path))
    except (OSError, ValueError):
        return False


def _write_commit_failure_marker(outdir: str, reason: Exception) -> None:
    """Fail closed if a filesystem fault prevents restoring a generation."""
    payload = {
        "schema_version": "omicstat.publication-commit-failure.v1",
        "status": "blocked",
        "reason": "publication transaction fault isolation",
        "error_type": type(reason).__name__,
        "recorded_at": utc_now(),
    }
    _atomic_write_text(_commit_failure_path(outdir), json.dumps(payload, sort_keys=True) + "\n")


def _commit_publication_group(manifest: Dict[str, Any], *, registry_path: Optional[str] = None,
                              previous_registry: Optional[Dict[str, Any]] = None) -> None:
    """Commit every ready-bearing artifact as one rollback unit.

    Filesystems cannot atomically rename seven unrelated paths.  The next-best
    release invariant is exact byte snapshots of all members followed by
    rollback of *every* member on a write or final-evidence failure.  Candidate
    review/outline bytes are never written before late blockers are folded into
    the status reducer.
    """
    transaction = manifest.get("_publication_transaction")
    artifacts = transaction.get("artifacts") if isinstance(transaction, dict) else None
    if not isinstance(artifacts, dict) or set(artifacts) != {
            VALUE_MAP_REL, REVIEW_REL, OUTLINE_REL, INDEX_REL}:
        raise ValueError("missing complete publication artifact transaction")
    outdir = manifest["outdir"]
    manifest_path = safe_join_under(outdir, MANIFEST_REL)
    paths = {rel: safe_join_under(outdir, rel) for rel in PUBLICATION_DYNAMIC}
    if registry_path:
        paths["registry"] = registry_path
    snapshots = {key: _snapshot_bytes(path) for key, path in paths.items()}
    persistent_manifest = copy.deepcopy(manifest)
    persistent_manifest.pop("_publication_transaction", None)
    try:
        # This is the commit trust boundary: a dirty-bit assertion produced at
        # request time cannot race a changed server/finalizer into a ready run.
        if (persistent_manifest.get("status") == "ready_for_manuscript_integration"
                and not _current_manifest_provenance_is_bound(persistent_manifest)):
            raise ValueError("repository provenance changed before publication commit")
        validate_reviewer_decisions(outdir, persistent_manifest.get("reviewer_decisions", {}), use_snapshots=True)
        for rel in (VALUE_MAP_REL, REVIEW_REL, OUTLINE_REL, INDEX_REL):
            if rel == OUTLINE_REL:
                _atomic_write_text(paths[rel], artifacts[rel])
            else:
                write_json(paths[rel], artifacts[rel])
        write_json(manifest_path, persistent_manifest)
        if (persistent_manifest.get("status") == "ready_for_manuscript_integration"
                and not _current_manifest_provenance_is_bound(persistent_manifest)):
            raise ValueError("repository provenance changed during publication commit")
        validate_reviewer_decisions(outdir, persistent_manifest.get("reviewer_decisions", {}), use_snapshots=True)
        if registry_path:
            digest = sha256_file(manifest_path)
            write_json(registry_path, _registry_record(persistent_manifest, digest, previous_registry))
        # A fault or evidence race at either late boundary restores all five
        # artifacts, the manifest, and registry to their exact prior bytes.
        if (persistent_manifest.get("status") == "ready_for_manuscript_integration"
                and not _current_manifest_provenance_is_bound(persistent_manifest)):
            raise ValueError("repository provenance changed after publication commit")
        validate_reviewer_decisions(outdir, persistent_manifest.get("reviewer_decisions", {}), use_snapshots=True)
        if persistent_manifest.get("status") == "ready_for_manuscript_integration":
            _write_commit_marker(outdir, persistent_manifest)
    except Exception as commit_exc:
        try:
            for key, path in paths.items():
                _restore_snapshot(path, snapshots[key])
        except Exception as rollback_exc:
            try:
                _write_commit_failure_marker(outdir, rollback_exc)
            except OSError:
                # The original exception remains the best available evidence;
                # no ready registry record is emitted because registry writing
                # is after all publication checks.
                pass
            raise RuntimeError(
                "publication transaction failed and rollback could not restore consistency; "
                "original commit fault is retained as context"
            ) from rollback_exc
        # A write-side transaction failure is itself a fault-isolation event:
        # callers must receive the stable transaction contract rather than an
        # implementation-specific filesystem exception.  The original error
        # remains the explicit exception cause and the on-disk marker keeps
        # recovery diagnosable even when byte restoration did succeed.
        if isinstance(commit_exc, OSError) and registry_path is None:
            try:
                _write_commit_failure_marker(outdir, commit_exc)
            except OSError:
                pass
            raise RuntimeError(
                "publication transaction failed and rollback could not restore consistency; "
                "original commit fault is retained as cause"
            ) from commit_exc
        raise
    failure_marker = _commit_failure_path(outdir)
    if os.path.exists(_native_path(failure_marker)):
        os.remove(_native_path(failure_marker))
    manifest.pop("_publication_transaction", None)


def commit_manifest_and_registry(registry_root: str, manifest: Dict[str, Any], *,
                                 expected_previous_digest: Optional[str] = None) -> str:
    """CAS-check and transactionally commit all publication artifacts/registry."""
    path = os.path.join(registry_root, "%s.json" % manifest["run_id"])
    manifest_path = safe_join_under(manifest["outdir"], MANIFEST_REL)
    with _registry_lock(registry_root):
        previous = _check_registry_cas(path, manifest, expected_previous_digest)
        if previous:
            if not os.path.isfile(_native_path(manifest_path)) or sha256_file(manifest_path) != expected_previous_digest:
                raise ValueError("current manifest changed before registry commit")
        _commit_publication_group(manifest, registry_path=path, previous_registry=previous)
    return path


def write_registry(registry_root: str, manifest: Dict[str, Any], *,
                   expected_previous_digest: Optional[str] = None) -> str:
    """Register an already-written manifest, retaining CAS semantics."""
    os.makedirs(_native_path(registry_root), exist_ok=True)
    path = os.path.join(registry_root, "%s.json" % manifest["run_id"])
    manifest_path = safe_join_under(manifest["outdir"], MANIFEST_REL, require_exists=True)
    with _registry_lock(registry_root):
        previous = _check_registry_cas(path, manifest, expected_previous_digest)
        manifest_digest = sha256_file(manifest_path)
        record = _registry_record(manifest, manifest_digest, previous)
        write_json(path, record)
    return path


def lookup_registry(registry_root: str, run_id: str, *, verify_current: bool = True) -> Dict[str, Any]:
    normalized = str(uuid.UUID(run_id))
    record = _read_json(os.path.join(registry_root, normalized + ".json"))
    if record.get("run_id") != normalized:
        raise ValueError("registry run_id mismatch")
    outdir = str(record.get("outdir", ""))
    if os.path.basename(os.path.normpath(outdir)) != normalized:
        raise ValueError("registry outdir is not the run UUID leaf")
    if _is_link_or_reparse(outdir):
        raise ValueError("registry outdir traverses a link/reparse point")
    if verify_current:
        if os.path.exists(_native_path(_commit_failure_path(outdir))):
            raise ValueError("publication commit is fault-isolated; refusing untrusted state")
        manifest_path = safe_join_under(outdir, MANIFEST_REL, require_exists=True)
        actual = sha256_file(manifest_path)
        if actual != record.get("manifest_digest"):
            raise ValueError("registry manifest digest mismatch; refusing untrusted validation")
        current_manifest = _read_json(manifest_path)
        if current_manifest.get("run_id") != normalized:
            raise ValueError("registry manifest run_id mismatch")
        if current_manifest.get("engine_anchor_digest") != record.get("engine_anchor_digest"):
            raise ValueError("registry engine anchor mismatch; refusing untrusted validation")
        if (current_manifest.get("status") == "ready_for_manuscript_integration"
                and not _ready_commit_marker_is_valid(outdir, current_manifest)):
            raise ValueError("publication ready state lacks a valid atomic commit marker")
    return record
