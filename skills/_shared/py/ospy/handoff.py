"""handoff.py -- the --from-run chaining contract (ENGINEERING_PLAN 1.3, 10.3).

Python counterpart of skills/_shared/scripts/handoff.R; reads and writes the
SAME objects/handoff.json (schema omicstat.handoff.v1), so a chain can pass
between the lanes where the plan allows it (back-end modules; front ends stay
in one ecosystem). Additions of plan part 10: ecosystem "scverse" and the
object type "AnnData" (an .h5ad file).

Rejections are typed (OmicstatError):
  OS_HANDOFF_MISSING    no objects/handoff.json in the --from-run directory
  OS_HANDOFF_MISMATCH   object type differs, a file's sha256 differs, unknown
                        schema, an AnnData object that is not an .h5ad file
  OS_ECOSYSTEM_MIXED    a front-end single-cell module received another
                        ecosystem's chain (Seurat / Bioconductor / scverse)
  OS_CONTRACT_MISMATCH  the StudyContract hash differs from the chain's
  OS_BATCH_CORRECTED_INPUT  a "batch_corrected_matrix" object requested as
                        anything else (never enters a differential test)
The key "upstream_runs" (oldest first, ending with the writing run) is what
mcp/server.py copies into the manifest field of the same name. Standard
library only. ASCII only.
"""
import json
import os
import re

from .errors import OmicstatError
from .module_kit import sha256_file

OS_HANDOFF_SCHEMA = "omicstat.handoff.v1"
OS_ECOSYSTEMS = ("seurat", "bioconductor", "scverse", "neutral")
OS_BATCH_CORRECTED_TYPE = "batch_corrected_matrix"
OS_BATCH_LINEAGE_ALLOWED = ("batch_corrected_matrix", "sample_table", "gene_sets", "colour_registry")
ANNDATA_TYPE = "AnnData"
ANNDATA_EXT = ".h5ad"


def os_run_id(run_dir):
    """Use the MCP UUID rather than the container mount basename (R4)."""
    value = os.environ.get("OMICSTAT_RUN_ID", "")
    if not value:
        return os.path.basename(os.path.normpath(run_dir))
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", value):
        raise OmicstatError("OS_INVALID_PARAMETER", "OMICSTAT_RUN_ID must contain 1-128 safe identifier characters.")
    return value


def assert_uncorrected(upstream, name, purpose="inference"):
    obj = upstream.get("objects", {}).get(name)
    if obj is None:
        raise OmicstatError("OS_HANDOFF_MISMATCH", "upstream run has no object '%s'." % name)
    if obj.get("type") == OS_BATCH_CORRECTED_TYPE or upstream.get("state", {}).get("batch_corrected_lineage") is True:
        raise OmicstatError("OS_BATCH_CORRECTED_INPUT", "object '%s' is batch-corrected or derived from corrected data; not used for %s." % (name, purpose))
    return True


def _rel_under(root, path):
    root_abs = os.path.realpath(root)
    p = os.path.realpath(path)
    if not os.path.exists(p):
        raise OmicstatError("OS_INVALID_PARAMETER", "handoff object path does not exist: %s" % path)
    if os.path.commonpath([root_abs, p]) != root_abs or p == root_abs:
        return None
    return os.path.relpath(p, root_abs).replace(os.sep, "/")


def write_handoff(run_dir, run_id, module, module_version, objects, contract_hash=None,
                  ecosystem="neutral", state=None, upstream_runs=()):
    """objects: {name: {"path": <file under run_dir>, "type": <class string>}}.

    type examples: "AnnData" (.h5ad), "feature_table", "colour_registry",
    "count_matrix", "batch_corrected_matrix". Returns the handoff.json path.
    """
    if ecosystem not in OS_ECOSYSTEMS:
        raise OmicstatError("OS_INVALID_PARAMETER", "ecosystem must be one of %s." % ", ".join(OS_ECOSYSTEMS))
    if str(run_id) == os.path.basename(os.path.normpath(run_dir)):
        run_id = os_run_id(run_dir)
    obj_dir = os.path.join(run_dir, "objects")
    os.makedirs(obj_dir, exist_ok=True)
    objs = []
    for nm in sorted(objects, key=lambda s: s.encode("utf-8")):
        o = objects[nm]
        rel = _rel_under(run_dir, o["path"])
        if rel is None:
            raise OmicstatError("OS_INVALID_PARAMETER", "handoff object '%s' is outside the run directory." % nm)
        if o["type"] == ANNDATA_TYPE and not rel.endswith(ANNDATA_EXT):
            raise OmicstatError("OS_INVALID_PARAMETER", "handoff object '%s' of type AnnData must be an %s file." % (nm, ANNDATA_EXT))
        objs.append({"name": nm, "type": o["type"], "path": rel, "sha256": sha256_file(o["path"])})
    st = {k: (state or {})[k] for k in sorted(state or {}, key=lambda s: s.encode("utf-8"))}
    doc = {"schema": OS_HANDOFF_SCHEMA, "run_id": run_id, "module": module, "module_version": module_version,
           "ecosystem": ecosystem, "contract_hash": contract_hash, "state": st,
           "upstream_runs": [str(u) for u in upstream_runs] + [run_id], "objects": objs}
    path = os.path.join(obj_dir, "handoff.json")
    with open(path, "wb") as fh:
        fh.write((json.dumps(doc, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8"))
    return path


def read_handoff(from_run, expect=None, front_end_ecosystem=None, contract_hash=None):
    """Verify, then describe, the objects of an upstream run.

    expect: {object name: expected type}. front_end_ecosystem: for single-cell
    FRONT-END modules (qc, cluster, integrate, markers) the ecosystem this
    module belongs to ("scverse" for the Python lane); None for neutral
    (back-end) modules. Returns {run_id, module, module_version, ecosystem,
    contract_hash, state, upstream_runs, objects: {name: {path, type, sha256}}}.
    """
    path = os.path.join(from_run, "objects", "handoff.json")
    if not os.path.isfile(path):
        raise OmicstatError("OS_HANDOFF_MISSING", "no objects/handoff.json under --from-run %s" % from_run)
    try:
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (ValueError, OSError) as exc:
        raise OmicstatError("OS_HANDOFF_MISMATCH", "unreadable handoff document: %s" % exc) from exc
    if not isinstance(doc, dict):
        raise OmicstatError("OS_HANDOFF_MISMATCH", "handoff must be an object.")
    if doc.get("schema") != OS_HANDOFF_SCHEMA:
        raise OmicstatError("OS_HANDOFF_MISMATCH", "unknown handoff schema tag.")
    eco = doc.get("ecosystem")
    if eco not in OS_ECOSYSTEMS or not isinstance(doc.get("state") or {}, dict):
        raise OmicstatError("OS_HANDOFF_MISMATCH", "invalid ecosystem or chain state.")
    front = (doc.get("state") or {}).get("front_end_ecosystem", eco) if eco == "neutral" else eco
    if front_end_ecosystem is not None and front != "neutral" and front != front_end_ecosystem:
        raise OmicstatError("OS_ECOSYSTEM_MIXED",
                            "this %s front-end module cannot continue a %s chain (upstream module %s). "
                            "A chain's front end stays in one ecosystem; start a new chain instead."
                            % (front_end_ecosystem, front, doc.get("module")))
    up_hash = doc.get("contract_hash")
    if contract_hash is not None and up_hash is not None and up_hash != contract_hash:
        raise OmicstatError("OS_CONTRACT_MISMATCH",
                            "the StudyContract differs from the one used upstream; a changed contract starts a new chain.")
    out = {}
    if not isinstance(doc.get("objects"), list):
        raise OmicstatError("OS_HANDOFF_MISMATCH", "objects must be an array.")
    for o in doc.get("objects") or []:
        if not isinstance(o, dict) or not isinstance(o.get("name"), str) or not o.get("name"):
            raise OmicstatError("OS_HANDOFF_MISMATCH", "invalid handoff object record.")
        nm = o["name"]
        if nm in out:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "duplicate handoff object '%s'." % nm)
        rel = str(o.get("path", ""))
        if os.path.isabs(rel) or ".." in rel.replace("\\", "/").split("/"):
            raise OmicstatError("OS_HANDOFF_MISMATCH", "handoff object '%s' has a path outside the run (%s)." % (nm, rel))
        p = os.path.join(from_run, *rel.split("/"))
        if os.path.commonpath([os.path.realpath(from_run), os.path.realpath(p)]) != os.path.realpath(from_run):
            raise OmicstatError("OS_HANDOFF_MISMATCH", "handoff symlink escapes the run directory.")
        if not os.path.isfile(p):
            raise OmicstatError("OS_HANDOFF_MISMATCH", "handoff object '%s' is missing (%s)." % (nm, rel))
        if sha256_file(p) != o.get("sha256"):
            raise OmicstatError("OS_HANDOFF_MISMATCH",
                                "sha256 of '%s' differs from handoff.json (file changed after the upstream run)." % nm)
        if o.get("type") == ANNDATA_TYPE and not rel.endswith(ANNDATA_EXT):
            raise OmicstatError("OS_HANDOFF_MISMATCH", "object '%s' is declared AnnData but is not an %s file." % (nm, ANNDATA_EXT))
        out[nm] = {"path": os.path.abspath(p).replace(os.sep, "/"), "type": o.get("type"), "sha256": o.get("sha256")}
    for nm, want in (expect or {}).items():
        if nm not in out:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "upstream run has no object '%s'." % nm)
        if (doc.get("state") or {}).get("batch_corrected_lineage") is True and want not in OS_BATCH_LINEAGE_ALLOWED:
            raise OmicstatError("OS_BATCH_CORRECTED_INPUT", "upstream object '%s' derives from batch-corrected data." % nm)
        if out[nm]["type"] == OS_BATCH_CORRECTED_TYPE and want != OS_BATCH_CORRECTED_TYPE:
            raise OmicstatError("OS_BATCH_CORRECTED_INPUT",
                                "object '%s' of upstream run %s (%s) is a batch-corrected matrix; it is for display and "
                                "scoring only and never enters a differential test. Use the uncorrected data and put the "
                                "batch (or the surrogate variables) in the design instead." % (nm, doc.get("run_id"), doc.get("module")))
        if out[nm]["type"] != want:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "object '%s' has type '%s', expected '%s'." % (nm, out[nm]["type"], want))
    return {"run_id": doc.get("run_id"), "module": doc.get("module"), "module_version": doc.get("module_version"),
            "ecosystem": eco, "contract_hash": up_hash, "state": doc.get("state") or {},
            "upstream_runs": list(doc.get("upstream_runs") or []), "objects": out,
            "batch_corrected_lineage": (doc.get("state") or {}).get("batch_corrected_lineage") is True}
