"""figure_request.py -- Python modules do not draw publication figures.

ENGINEERING_PLAN 10.5: a Python module writes the data a figure needs
(figure_data/*.csv) plus figure_data/figure_request.json; the R figure layer
renders them through the existing fig_*.R builders and os_finalize_figure
(skills/_shared/scripts/render_figure_request.R, run in omicstat-r as the
final step of the run). So there is exactly one style system, one lint, one
caption generator.

    req = FigureRequest(outdir, module="scanpy-cluster", module_version="1.0.0", journal=args["journal"])
    req.add("umap_clusters", "os_embedding",
            data={"emb": frame(rows, types={"cluster": "factor"}, levels={"cluster": order})},
            args={"group_col": "cluster", "reduction": "UMAP"}, width="single")
    req.add("volcano", "os_volcano", data={"ft": frame(feature_table_rows)},
            args={"padj_threshold": 0.05, "lfc_threshold": 1})
    req.write()                          # -> figure_data/figure_request.json

Data kinds (the R side decodes each into the argument of the same name):
  frame(table, types=None, levels=None)   -> data.frame
  vector(values, type=None, names=None)   -> atomic vector (optionally named)
  matrix(values, row_names, col_names)    -> numeric matrix with dimnames
Column types: character, numeric, integer, logical, factor (with levels).
Numbers are written with 17 significant digits, so R reads back the exact
doubles; files are UTF-8, LF, quoted character cells (R write.csv dialect),
and every file's sha256 is in the request (the renderer refuses a mismatch).
`args` are JSON scalars, arrays (-> R vectors) and objects (-> named lists).
Standard library only. ASCII only.
"""
import math
import os
import re

from .errors import OmicstatError
from .module_kit import sha256_file, write_json

FIGURE_REQUEST_SCHEMA = "omicstat.figure-request.v1"
REQUEST_REL = "figure_data/figure_request.json"
TYPES = ("character", "numeric", "integer", "logical", "factor")
_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
_STEM_RE = re.compile(r"^figures/[A-Za-z0-9][A-Za-z0-9_./-]*$")
WIDTHS = ("single", "onehalf", "double")
FORMATS = ("pdf", "png", "svg")


def _is_na(v):
    return v is None or (isinstance(v, float) and math.isnan(v))


def _infer(values):
    vals = [v for v in values if not _is_na(v)]
    if not vals:
        return "character"
    if all(isinstance(v, bool) for v in vals):
        return "logical"
    if all(isinstance(v, int) and not isinstance(v, bool) for v in vals):
        return "integer" if all(-2147483647 <= v <= 2147483647 for v in vals) else "numeric"
    if all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in vals):
        return "numeric"
    return "character"


def _to_python(v):
    """numpy / pandas scalars -> plain Python (no import of either)."""
    if hasattr(v, "item") and not isinstance(v, (str, bytes)):
        try:
            return v.item()
        except (ValueError, TypeError):
            return v
    return v


def _cell(v, t):
    v = _to_python(v)
    if _is_na(v):
        return "NA"
    if t in ("character", "factor"):
        return '"' + str(v).replace('"', '""') + '"'
    if t == "numeric":
        if isinstance(v, int) and not isinstance(v, bool):
            bits = abs(v).bit_length()
            if bits > 1024 or bits > 53 and v % (1 << (bits - 53)):
                raise OmicstatError("OS_INVALID_PARAMETER", "numeric source integer is not exactly representable as binary64")
        x = float(v)
        if math.isinf(x):
            return "Inf" if x > 0 else "-Inf"
        return "%.17g" % x
    if t == "integer":
        if isinstance(v, bool) or not isinstance(v, int) or not -2147483647 <= v <= 2147483647:
            raise OmicstatError("OS_INVALID_PARAMETER", "integer source value must fit R's non-missing signed 32-bit integer range")
        return str(int(v))
    if t == "logical":
        return "TRUE" if bool(v) else "FALSE"
    raise OmicstatError("OS_INVALID_PARAMETER", "unknown column type %r" % t)


class _Data(dict):
    pass


def frame(table, types=None, levels=None, row_id=None):
    """A data.frame argument; optional row_id becomes an explicit R row-name index.

    The index column is checksum-protected in CSV, then removed from displayed
    annotation tracks. It must contain unique, nonempty string IDs.
    """
    types, levels = dict(types or {}), {k: list(v) for k, v in (levels or {}).items()}
    if hasattr(table, "columns") and hasattr(table, "to_dict"):          # pandas, without importing it
        cols = [str(c) for c in table.columns]
        data = {str(c): [_to_python(x) for x in table[c].tolist()] for c in table.columns}
        for c in table.columns:
            dt = getattr(table[c], "dtype", None)
            if str(dt) == "category" and str(c) not in types:
                types[str(c)] = "factor"
                levels.setdefault(str(c), [str(x) for x in table[c].cat.categories])
    elif isinstance(table, dict):
        cols = [str(c) for c in table]
        data = {str(c): [_to_python(x) for x in table[c]] for c in table}
    else:
        rows = list(table)
        cols = list(dict.fromkeys(k for r in rows for k in r))
        data = {c: [_to_python(r.get(c)) for r in rows] for c in cols}
    n = {len(v) for v in data.values()}
    if len(n) > 1:
        raise OmicstatError("OS_INVALID_PARAMETER", "frame(): columns have different lengths %s" % sorted(n))
    spec = []
    for c in cols:
        t = types.get(c) or _infer(data[c])
        if t not in TYPES:
            raise OmicstatError("OS_INVALID_PARAMETER", "frame(): column %s has unknown type %r" % (c, t))
        col = {"name": c, "type": t}
        if t == "factor":
            lv = levels.get(c) or sorted({str(v) for v in data[c] if not _is_na(v)}, key=lambda s: s.encode("utf-8"))
            bad = sorted({str(v) for v in data[c] if not _is_na(v)} - set(lv))
            if bad:
                raise OmicstatError("OS_INVALID_PARAMETER", "frame(): column %s has values outside its levels: %s" % (c, bad[:5]))
            col["levels"] = [str(x) for x in lv]
        spec.append(col)
    result = _Data(kind="data.frame", columns=spec, data=data, n=(n.pop() if n else 0))
    if row_id is not None:
        ids = data.get(row_id, [])
        if row_id not in data or not ids or any(not isinstance(x, str) or not x for x in ids) or len(set(ids)) != len(ids):
            raise OmicstatError("OS_INVALID_PARAMETER", "frame(): row_id must name unique, nonempty string IDs")
        result["row_id_column"] = row_id
    return result


def vector(values, type=None, names=None):                                # noqa: A002
    values = [_to_python(v) for v in values]
    t = type or _infer(values)
    if t not in TYPES or t == "factor":
        raise OmicstatError("OS_INVALID_PARAMETER", "vector(): type must be character, numeric, integer or logical")
    data = {"value": values}
    cols = [{"name": "value", "type": t}]
    if names is not None:
        names = [str(x) for x in names]
        if len(names) != len(values):
            raise OmicstatError("OS_INVALID_PARAMETER", "vector(): names and values differ in length")
        data = {"name": names, "value": values}
        cols = [{"name": "name", "type": "character"}] + cols
    return _Data(kind="vector", columns=cols, data=data, n=len(values))


def matrix(values, row_names, col_names):
    rows = [[_to_python(x) for x in r] for r in values]
    row_names, col_names = [str(x) for x in row_names], [str(x) for x in col_names]
    if len(rows) != len(row_names) or any(len(r) != len(col_names) for r in rows):
        raise OmicstatError("OS_INVALID_PARAMETER", "matrix(): dimensions and dimnames disagree")
    if not row_names or not col_names or len(set(row_names)) != len(row_names) or any(not x for x in row_names):
        raise OmicstatError("OS_INVALID_PARAMETER", "matrix(): row names must be unique and nonempty")
    if len(set(col_names)) != len(col_names) or "row_id" in col_names or any(not x for x in col_names):
        raise OmicstatError("OS_INVALID_PARAMETER", "matrix(): column names must be unique and not 'row_id'")
    data = {"row_id": row_names}
    for j, c in enumerate(col_names):
        data[c] = [r[j] for r in rows]
    cols = [{"name": "row_id", "type": "character"}] + [{"name": c, "type": "numeric"} for c in col_names]
    return _Data(kind="matrix", columns=cols, data=data, n=len(rows))


def write_data_csv(d, path):
    names = [c["name"] for c in d["columns"]]
    lines = [",".join('"' + n.replace('"', '""') + '"' for n in names)]
    for i in range(d["n"]):
        lines.append(",".join(_cell(d["data"][c["name"]][i], c["type"]) for c in d["columns"]))
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(("\n".join(lines) + "\n").encode("utf-8"))
    return path


class FigureRequest:
    def __init__(self, outdir, module, module_version, journal="nature", colour_registry=None):
        self.outdir = outdir
        self.module, self.module_version, self.journal = module, module_version, journal
        self.colour_registry = colour_registry
        self.figures = []

    def add(self, fig_id, builder, data, args=None, out_stem=None, width="single", height_mm=None,
            formats=("pdf", "png"), caption_context=None, definition=None, evidence_refs=None, sampling_scope=None):
        if not _ID_RE.match(fig_id) or any(f["id"] == fig_id for f in self.figures):
            raise OmicstatError("OS_INVALID_PARAMETER", "figure id %r is invalid or duplicated" % fig_id)
        if not re.match(r"^os_[a-z0-9_]+$", builder):
            raise OmicstatError("OS_INVALID_PARAMETER", "builder %r is not an os_* figure builder" % builder)
        stem = out_stem or "figures/" + fig_id
        if not _STEM_RE.match(stem) or ".." in stem.split("/"):
            raise OmicstatError("OS_INVALID_PARAMETER", "out_stem %r must lie under figures/" % stem)
        if not (width in WIDTHS or (isinstance(width, (int, float)) and not isinstance(width, bool) and width > 0)):
            raise OmicstatError("OS_INVALID_PARAMETER", "width must be one of %s or millimetres" % ", ".join(WIDTHS))
        bad = [f for f in formats if f not in FORMATS]
        if bad or not formats:
            raise OmicstatError("OS_INVALID_PARAMETER", "formats must be a non-empty subset of %s" % ", ".join(FORMATS))
        if caption_context is not None and (not isinstance(caption_context, str) or not caption_context.strip()):
            raise OmicstatError("OS_INVALID_PARAMETER", "caption_context must be a nonempty string")
        if definition is not None:
            from .figure_semantics import validate_definition
            definition = validate_definition(definition)
        if evidence_refs is not None:
            from .figure_semantics import validate_evidence_refs
            evidence_refs = validate_evidence_refs(evidence_refs)
        if sampling_scope is not None:
            from .figure_scope import bound_sampling_scope, SOURCE_REL
            import json
            try:
                with open(os.path.join(self.outdir, SOURCE_REL), encoding='utf-8') as stream:
                    record = json.load(stream)
                expected = bound_sampling_scope(record, sampling_scope['observations_after'], self.outdir)
            except (OSError, ValueError, KeyError, TypeError) as exc:
                raise OmicstatError('OS_INVALID_INPUT', 'figure sampling source is missing or invalid') from exc
            if expected != sampling_scope:
                raise OmicstatError('OS_INVALID_INPUT', 'figure sampling metadata differs from the bound source')
            if not isinstance(caption_context, str) or sampling_scope['caption'] not in caption_context:
                raise OmicstatError('OS_INVALID_INPUT', 'figure caption must include the complete bound sampling scope')
            if 'emb' in data:
                from .figure_scope import check_embedding_scope
                check_embedding_scope(sampling_scope, data['emb'])
        entries = {}
        for arg, d in data.items():
            if not isinstance(d, _Data):
                raise OmicstatError("OS_INVALID_PARAMETER", "data[%r] must come from frame()/vector()/matrix()" % arg)
            rel = "figure_data/%s__%s.csv" % (fig_id, arg)
            path = write_data_csv(d, os.path.join(self.outdir, *rel.split("/")))
            entries[arg] = {"kind": d["kind"], "path": rel, "sha256": sha256_file(path), "n_rows": d["n"],
                            "columns": d["columns"]}
            if d.get("row_id_column") is not None:
                entries[arg]["row_id_column"] = d["row_id_column"]
        clash = sorted(set(entries) & set(args or {}))
        if clash:
            raise OmicstatError("OS_INVALID_PARAMETER", "argument(s) given both as data and as args: %s" % clash)
        self.figures.append({"id": fig_id, "builder": builder, "out_stem": stem, "width": width,
                             "height_mm": height_mm, "formats": list(formats), "data": entries,
                             "args": dict(args or {})})
        if caption_context is not None:
            self.figures[-1]["caption_context"] = caption_context
        if definition is not None:
            self.figures[-1]["definition"] = definition
        if evidence_refs is not None:
            self.figures[-1]["evidence_refs"] = evidence_refs
        if sampling_scope is not None:
            self.figures[-1]["sampling_scope"] = sampling_scope
        return self

    def to_dict(self):
        return {"schema": FIGURE_REQUEST_SCHEMA, "module": self.module, "module_version": self.module_version,
                "journal": self.journal, "colour_registry": self.colour_registry, "figures": self.figures}

    def write(self):
        if not self.figures:
            raise OmicstatError("OS_INVALID_PARAMETER", "figure request has no figures")
        path = os.path.join(self.outdir, *REQUEST_REL.split("/"))
        write_json(self.to_dict(), path, sort_keys=False)
        return path


def validate_request(outdir, rel=REQUEST_REL):
    """Python-side check of a written request (schema, files, sha256); returns a list of problems."""
    import json                                                # noqa: PLC0415
    path = os.path.join(outdir, *rel.split("/"))
    if not os.path.isfile(path):
        return ["no %s" % rel]
    with open(path, encoding="utf-8") as fh:
        req = json.load(fh)
    probs = []
    if req.get("schema") != FIGURE_REQUEST_SCHEMA:
        probs.append("schema tag")
    for f in req.get("figures") or []:
        if f.get('sampling_scope') is not None:
            try:
                from .figure_scope import bound_sampling_scope, SOURCE_REL
                with open(os.path.join(outdir, SOURCE_REL), encoding='utf-8') as stream:
                    record = json.load(stream)
                expected = bound_sampling_scope(record, f['sampling_scope']['observations_after'], outdir)
                if expected != f['sampling_scope'] or expected['caption'] not in (f.get('caption_context') or ''):
                    raise OmicstatError('OS_INVALID_INPUT', 'sampling scope/caption differs from source')
            except (OmicstatError, OSError, ValueError, KeyError, TypeError) as exc:
                probs.append('%s/sampling_scope: %s' % (f.get('id', 'unknown'), exc))
        for field, validator in (("definition", "validate_definition"), ("evidence_refs", "validate_evidence_refs")):
            if f.get(field) is not None:
                from . import figure_semantics
                try:
                    getattr(figure_semantics, validator)(f[field])
                except OmicstatError as exc:
                    probs.append("%s/%s: %s" % (f.get("id", "unknown"), field, exc))
        for arg, d in (f.get("data") or {}).items():
            p = os.path.join(outdir, *d["path"].split("/"))
            if not os.path.isfile(p):
                probs.append("%s/%s: missing %s" % (f["id"], arg, d["path"]))
            elif sha256_file(p) != d["sha256"]:
                probs.append("%s/%s: sha256 mismatch" % (f["id"], arg))
    if not req.get("figures"):
        probs.append("no figures")
    return probs
