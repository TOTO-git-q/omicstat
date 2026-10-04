"""feature_table.py -- the canonical omics result table, Python lane.

Python counterpart of skills/_shared/scripts/feature_table.R (CONVENTIONS.md
sec 1). Same 14 columns, same validation (errors OS_SCHEMA_INVALID, warnings
OS_DEGENERATE / OS_SCHEMA_WARNING), same canonical row order and the SAME
BYTES on disk: write_feature_table() reproduces R's write.csv of
formatC(x, digits = 10, format = "g") cells, so an identical table written by
either lane has an identical sha256 (checked by
skills/_shared/tests/test_render_figure_request.R).

A table is a list of row dicts (column -> value); pandas DataFrames are
accepted by as_feature_table() (via .to_dict("records")) but pandas is never
required. Missing numbers are None or NaN. Standard library only. ASCII only.
"""
import math
import os
import re
import warnings

from .errors import OmicstatError

FEATURE_TABLE_SCHEMA = [
    # (column, type, required)
    ("feature_id", "character", True), ("symbol", "character", False), ("contrast", "character", True),
    ("base_mean", "numeric", False), ("log2fc", "numeric", True), ("log2fc_se", "numeric", False),
    ("stat", "numeric", False), ("pvalue", "numeric", True), ("padj", "numeric", True),
    ("method", "character", True), ("shrinkage", "character", False), ("n_group1", "integer", True),
    ("n_group2", "integer", True), ("filtered_reason", "character", False),
]
COLUMNS = [c for c, _t, _r in FEATURE_TABLE_SCHEMA]
TYPES = {c: t for c, t, _r in FEATURE_TABLE_SCHEMA}
REQUIRED = [c for c, _t, r in FEATURE_TABLE_SCHEMA if r]
_ENS_VERSIONED = re.compile(r"^ENS[A-Z]*G[0-9]+\.[0-9]+$")


def _is_na(v):
    return v is None or (isinstance(v, float) and math.isnan(v))


def _num(v):
    if _is_na(v) or v == "" or v == "NA":
        return None
    return float(v)


def _int(v):
    if _is_na(v) or v == "" or v == "NA":
        return None
    f = float(v)
    return int(f)


def _rows_of(table):
    if hasattr(table, "to_dict"):
        return table.to_dict("records")
    return [dict(r) for r in table]


def as_feature_table(table):
    """Canonical columns, types and row order (contrast, padj with NA last, feature_id).

    As in feature_table.R: a character column absent from the input is filled
    with "", a present one keeps its missing values as NA (None).
    """
    out = []
    rows = _rows_of(table)
    present = set().union(*[set(r) for r in rows]) if rows else set()
    for r in rows:
        row = {}
        for c in COLUMNS:
            v = r.get(c)
            t = TYPES[c]
            if t == "character":
                row[c] = ("" if c not in present else None) if _is_na(v) else str(v)
            elif t == "numeric":
                row[c] = _num(v)
            else:
                row[c] = _int(v)
        if row["feature_id"] and _ENS_VERSIONED.match(row["feature_id"]):
            row["feature_id"] = row["feature_id"].rsplit(".", 1)[0]
        out.append(row)
    out.sort(key=lambda r: ((r["contrast"] or "").encode("utf-8"), r["padj"] is None,
                            r["padj"] if r["padj"] is not None else 0.0, (r["feature_id"] or "").encode("utf-8")))
    return out


def validate_feature_table(ft):
    errors, warns = [], []
    rows = _rows_of(ft)
    cols = set().union(*[set(r) for r in rows]) if rows else set(COLUMNS)
    miss = [c for c in REQUIRED if c not in cols]
    if miss:
        errors.append("OS_SCHEMA_INVALID: missing required column(s): %s" % ", ".join(miss))
    else:
        if any(_is_na(r["feature_id"]) or r["feature_id"] == "" for r in rows):
            errors.append("OS_SCHEMA_INVALID: feature_id has empty values")
        seen, dup = set(), 0
        for r in rows:
            k = (r["contrast"], r["feature_id"])
            dup += k in seen
            seen.add(k)
        if dup:
            errors.append("OS_SCHEMA_INVALID: %d duplicated feature_id within a contrast" % dup)
        if any(_ENS_VERSIONED.match(str(r["feature_id"])) for r in rows):
            errors.append("OS_SCHEMA_INVALID: Ensembl IDs must be stored without version suffix (CONVENTIONS: gene IDs)")
        for pc in ("pvalue", "padj"):
            if any(_num(r[pc]) is not None and not (0 <= _num(r[pc]) <= 1) for r in rows):
                errors.append("OS_SCHEMA_INVALID: %s outside [0, 1]" % pc)
        if any(_num(r["log2fc"]) is not None and not math.isfinite(_num(r["log2fc"])) for r in rows):
            warns.append("OS_DEGENERATE: log2fc contains non-finite values")
        contrasts = list(dict.fromkeys(r["contrast"] for r in rows))
        for ct in contrasts:
            pj = [_num(r["padj"]) for r in rows if r["contrast"] == ct]
            ok = [p for p in pj if p is not None]
            if not ok:
                warns.append("OS_DEGENERATE: padj is NA for every feature in contrast '%s'" % ct)
            elif len(ok) > 1 and all(p < 0.05 for p in ok):
                warns.append("OS_DEGENERATE: every tested feature is significant in contrast '%s'" % ct)
        na_reason = sum(1 for r in rows if _num(r["padj"]) is None and not (r.get("filtered_reason") or ""))
        if na_reason:
            warns.append("OS_SCHEMA_WARNING: %d rows have padj = NA without filtered_reason" % na_reason)
        for nc in ("n_group1", "n_group2"):
            if any(_num(r[nc]) is not None and _num(r[nc]) < 2 for r in rows):
                warns.append("OS_SCHEMA_WARNING: %s < 2 biological replicates" % nc)
    return {"ok": not errors, "errors": errors, "warnings": warns}


def assert_feature_table(ft, label="feature table"):
    v = validate_feature_table(ft)
    if not v["ok"]:
        raise OmicstatError("OS_SCHEMA_INVALID", "%s failed validation: %s" % (label, "; ".join(v["errors"])))
    for w in v["warnings"]:
        warnings.warn(w, stacklevel=2)
    return True


def format_g10(x):
    """One cell of feature_table.R: ifelse(is.na(x), "NA", formatC(x, digits = 10, format = "g")).

    formatC right-justifies to width digits + 1 = 11 (verified in omicstat-r:
    formatC(0.5, digits = 10, format = "g") == "        0.5"); NA is the bare "NA".
    """
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "NA"
    if math.isinf(x):
        return ("Inf" if x > 0 else "-Inf").rjust(11)
    return ("%.10g" % x).rjust(11)


def _q(s):
    return '"' + str(s).replace('"', '""') + '"'


def write_feature_table(ft, path):
    """Byte-identical to feature_table.R write_feature_table() for the same table."""
    rows = _rows_of(ft)
    assert_feature_table(rows)
    lines = [",".join(_q(c) for c in COLUMNS)]
    for r in rows:
        cells = []
        for c in COLUMNS:
            t, v = TYPES[c], r.get(c)
            if t == "numeric":
                cells.append(_q(format_g10(_num(v))))
            elif t == "integer":
                iv = _int(v)
                cells.append("NA" if iv is None else str(iv))
            else:
                cells.append("NA" if _is_na(v) else _q(v))
        lines.append(",".join(cells))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(("\n".join(lines) + "\n").encode("utf-8"))
    return path
