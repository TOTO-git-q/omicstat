"""Offline SHA-bound identifier and ortholog maps; no network lookup.

The registry entry's mapping export is shared by R and Python. A package
tarball hash is not a hash of an exported table: mapping.sha256 is mandatory.
"""
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import warnings
from .errors import OmicstatError


def _fail(code, message):
    raise OmicstatError(code, message)


def _snapshot(refdata_id, species, registry, root):
    registry = Path(registry or os.environ.get("OMICSTAT_REFDATA_REGISTRY", "env/refdata_registry.json"))
    try:
        entries = json.loads(registry.read_text(encoding="utf-8"))["entries"]
    except (OSError, ValueError, KeyError) as exc:
        _fail("OS_REFDATA_MISSING", "Cannot read registry: " + str(exc))
    matches = [e for e in entries if e["id"] == refdata_id]
    if len(matches) != 1:
        _fail("OS_REFDATA_MISSING", "Reference ID must resolve exactly once: " + str(refdata_id))
    entry = matches[0]
    if entry.get("species") != species:
        _fail("OS_REFDATA_MISMATCH", "Reference species differs from the explicit request")
    export = entry.get("mapping", {})
    if export.get("format") not in ("parquet", "tsv", "csv"):
        _fail("OS_REFDATA_MISSING", "Python needs a declared exported table format")
    rel = Path(export.get("path", ""))
    digest = export.get("sha256", "")
    if not export.get("path") or rel.is_absolute() or ".." in rel.parts or not re.fullmatch(r"[0-9a-f]{64}", digest):
        _fail("OS_REFDATA_MISSING", "Reference lacks a safe, SHA-bound mapping export")
    root = Path(root or os.environ.get("OMICSTAT_REFDATA_ROOT", str(registry.parent))).resolve()
    path = (root / rel).resolve()
    if not path.is_relative_to(root):
        _fail("OS_REFDATA_MISMATCH", "Mapping symlink escapes the reference root")
    if not path.is_file():
        _fail("OS_REFDATA_MISSING", "Mapping export is missing: " + str(rel))
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        _fail("OS_REFDATA_MISMATCH", "Mapping export SHA256 mismatch")
    return entry, export, path


def _rows(path, fmt):
    if fmt == "parquet":
        try:
            import pyarrow.parquet as pq
        except ImportError:
            _fail("OS_MISSING_PACKAGE", "pyarrow is required for a parquet mapping snapshot")
        table = pq.read_table(path)
        return table.column_names, table.to_pylist()
    if fmt in ("tsv", "csv"):
        with path.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f, delimiter="\t" if fmt == "tsv" else ",")
            return reader.fieldnames or [], list(reader)
    _fail("OS_INVALID_INPUT", "Python mapping requires an exported parquet/TSV/CSV snapshot")


def os_idmap(ids, from_, to, species, refdata_id, *, policy, registry=None, root=None, outdir=None):
    """Return mappings, per-input report and QC; policy must be first/drop/expand.

    first chooses the lexicographically first unique target, independent of
    source row order. drop discards ambiguous IDs; expand retains every target.
    Original input order and repetitions survive in report.query_index.
    """
    if policy not in ("first", "drop", "expand"):
        _fail("OS_INVALID_PARAMETER", "Mapping policy must be first, drop or expand")
    if any(not isinstance(x, str) or not x for x in (from_, to, refdata_id)) or not species:
        _fail("OS_INVALID_PARAMETER", "Explicit identifier columns, species and reference ID required")
    if isinstance(ids, (str, bytes)):
        _fail("OS_INVALID_INPUT", "ids must be a sequence of nonempty strings")
    ids = list(ids)
    if not ids or any(not isinstance(x, str) or not x.strip() for x in ids):
        _fail("OS_INVALID_INPUT", "ids must be nonempty strings; no implicit numeric ID conversion")
    entry, export, path = _snapshot(refdata_id, species, registry, root)
    columns, rows = _rows(path, export.get("format"))
    if from_ not in columns or to not in columns:
        _fail("OS_MISSING_COLUMN", "Requested identifier columns are absent from the snapshot")
    lookup = {}
    for row in rows:
        source, target = row.get(from_), row.get(to)
        if source is not None and target is not None and str(source).strip() and str(target).strip():
            lookup.setdefault(str(source), set()).add(str(target))
    mappings, report, lost = [], [], set()
    for i, source in enumerate(ids, 1):
        targets = sorted(lookup.get(source, set()))
        n = len(targets)
        kept = targets if policy == "expand" else targets[:1]
        if policy == "drop" and n > 1:
            kept = []
        status = "unmapped" if n == 0 else "ambiguous_dropped" if not kept else "ambiguous_first" if n > 1 and policy == "first" else "expanded" if n > 1 else "mapped"
        if not kept:
            lost.add(source)
        for target in kept:
            mappings.append(dict(query_index=i, source_id=source, target_id=target))
        report.append(dict(query_index=i, source_id=source, n_targets=n, n_retained=len(kept),
                           status=status, policy=policy, refdata_id=refdata_id))
    loss = len(lost) / len(set(ids))
    qc = dict(code="OS_IDMAP_LOSS", triggered=loss > .05, loss_fraction=loss,
              n_unique_input=len(set(ids)), n_unique_lost=len(lost), threshold=.05)
    if qc["triggered"]:
        warnings.warn("OS_IDMAP_LOSS: %.2f%% of unique input IDs were lost" % (100 * loss), UserWarning)
    if outdir is not None:
        folder = Path(outdir) / "tables"
        folder.mkdir(parents=True, exist_ok=True)
        with (folder / "idmap_report.csv").open("w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(report[0]), lineterminator="\n")
            writer.writeheader(); writer.writerows(report)
    return dict(mappings=mappings, report=report, qc=qc,
                provenance=dict(refdata_id=refdata_id, version=entry.get("version"),
                                sha256=export["sha256"], species=species, policy=policy))


def os_ortholog(ids, from_species, to_species, *, policy, registry=None, root=None,
                outdir=None, from_="source_id", to="target_id"):
    """Only a declared local ortholog snapshot; never online biomaRt."""
    for species in (from_species, to_species):
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", species):
            _fail("OS_INVALID_PARAMETER", "Ortholog species use registry tokens, e.g. hsapiens")
    ref = "ortholog_" + from_species + "_" + to_species
    result = os_idmap(ids, from_, to, [from_species, to_species], ref,
                      policy=policy, registry=registry, root=root, outdir=outdir)
    result["provenance"]["mapping_kind"] = "ortholog"
    return result
