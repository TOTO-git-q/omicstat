"""Typed scientific figure metadata. Standard library only; never fits an estimator.

Source tables are column-oriented arrays. Numeric values retain IEEE-754 precision;
non-finite infinities have an explicit mask because JSON itself has no Inf value.
Legacy requests remain valid. Typed definitions are checked before writing and again
by the allowlisted R renderer. Hashing is shared with fig_semantics.R.
"""
import copy
import hashlib
import json
import math
from .errors import OmicstatError

VERSION = "omicstat.figure-semantics.v1"
HASH = "omicstat.typed-table.sha256.v1"
ROLES = {"observed", "aggregate", "model_grid", "prediction", "partial_residual", "simulation_truth", "known_annotation", "fitted_cluster", "draw", "reference", "display_only"}
STATES = {"available", "observed", "true_zero", "missing", "untested", "failed", "unknown", "reference", "nonsignificant", "nonestimable", "unreachable", "undefined_constant", "undefined_single_sample", "undefined_nonfinite_reference", "infinite", "excluded", "display_only", "out_of_domain"}
STATISTICS = {"raw_p", "adjusted_p", "qvalue", "local_fdr", "posterior_probability", "posterior_inclusion_probability"}


def _fail(message):
    raise OmicstatError("OS_INVALID_INPUT", "figure semantics: " + message)


def _string(value, name):
    if not isinstance(value, str) or not value:
        _fail(name + " requires a nonempty string; use explicit unknown")
    return value


def _ids(values, name, empty=False):
    values = list(values)
    if (not values and not empty) or any(not isinstance(v, str) or not v.strip() for v in values) or len(set(values)) != len(values):
        _fail(name + " requires unique complete string IDs")
    return values


def _missing(v):
    return v is None or isinstance(v, float) and math.isnan(v)


def _numeric(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _finite(v):
    return _numeric(v) and math.isfinite(v)


def _scalar(v, name, low=-math.inf, high=math.inf):
    if not _finite(v) or not low <= v <= high:
        _fail(name + " is outside its finite declared domain")
    return v


def _table(table):
    if not isinstance(table, dict) or not table or any(not isinstance(k, str) or not k for k in table):
        _fail("table requires named columns")
    if any(not isinstance(v, (tuple, list)) for v in table.values()):
        _fail("table columns must be arrays, including one-row tables")
    if len({len(v) for v in table.values()}) != 1:
        _fail("table columns have different lengths")
    # Refuse precision loss before any float conversion (including overflow).
    # Integers with >53 bits are exact only when their low bits are all zero.
    for column in table.values():
        for value in column:
            if isinstance(value, int) and not isinstance(value, bool):
                bits = abs(value).bit_length()
                if bits > 1024 or bits > 53 and value % (1 << (bits - 53)):
                    _fail("integer source value is not exactly representable as binary64")
    return len(next(iter(table.values())))


def source_ids(table, keys):
    n = _table(table)
    if not n or not keys or not set(keys) <= table.keys():
        _fail("source table needs rows and explicit key columns")
    for key in keys:
        if any(not isinstance(v, str) or not v.strip() for v in table[key]):
            _fail("source keys must be explicit nonempty string IDs")
    result = [table[keys[0]][i] if len(keys) == 1 else json.dumps([table[k][i] for k in keys], ensure_ascii=False, separators=(",", ":")) for i in range(n)]
    return _ids(result, "source keys")


def table_sha256(table, ids):
    n = _table(table)
    ids = _ids(ids, "hash source IDs")
    if n != len(ids):
        _fail("source IDs and rows differ")
    def cell(v):
        if _missing(v): return "null"
        if isinstance(v, bool): return "b:1" if v else "b:0"
        if _numeric(v):
            number = ("Inf" if v > 0 else "-Inf") if math.isinf(v) else ("0" if v == 0 else format(float(v), ".17g"))
            return "n:" + number
        if not isinstance(v, str): _fail("nested source cells are not supported")
        return "s:" + v
    def token(v):
        b = v.encode("utf-8")
        return str(len(b)).encode("ascii") + b":" + b
    columns = sorted(table, key=lambda x: x.encode("utf-8"))
    chunks = [(HASH + "\n").encode("ascii")] + [token("s:" + c) for c in columns]
    for i in sorted(range(n), key=lambda i: ids[i].encode("utf-8")):
        chunks.append(token("s:" + ids[i]))
        chunks.extend(token(cell(table[c][i])) for c in columns)
    return hashlib.sha256(b"".join(chunks)).hexdigest()


def _restore(table, ids, mask):
    table = copy.deepcopy(table)
    seen = set()
    for entry in mask:
        ident, column, kind = entry["source_id"], entry["column"], entry["kind"]
        if ident not in ids or column not in table or kind not in ("positive_infinity", "negative_infinity"):
            _fail("invalid nonfinite source mask")
        if (ident, column) in seen: _fail("duplicate nonfinite source mask")
        seen.add((ident, column))
        i = ids.index(ident)
        value = table[column][i]
        expected = math.inf if kind == "positive_infinity" else -math.inf
        if not _missing(value) and value != expected: _fail("nonfinite mask contradicts source")
        table[column][i] = expected
    for c, values in table.items():
        for i, v in enumerate(values):
            if _numeric(v) and math.isinf(v) and (ids[i], c) not in seen:
                _fail("infinite source value has no lossless mask")
    return table


def validate_uncertainty(u, ids):
    for name in ("target", "kind", "method", "coverage_scope", "resampling_unit", "availability"):
        _string(u.get(name), "uncertainty " + name)
    if u["kind"] not in {"none", "distribution", "observation_quantile", "IQR", "SD", "SE", "CI", "CrI", "PI", "baseline_range", "estimator_mapping"}: _fail("unknown uncertainty kind")
    if u["availability"] not in {"available", "partial", "unavailable", "not_applicable"}: _fail("unknown uncertainty availability")
    if u["coverage_scope"] not in {"pointwise", "simultaneous_grid", "simultaneous_continuous", "distribution", "not_applicable", "unknown"}: _fail("unknown coverage scope")
    if u["kind"] in {"CI", "CrI", "PI", "observation_quantile"}:
        if not _finite(u.get("level")) or not 0 < u["level"] < 1: _fail("interval requires an explicit level between zero and one")
    elif u.get("level") is not None: _fail("SD/SE/distribution/range must not acquire a confidence level")
    if u["coverage_scope"].startswith("simultaneous") and not u.get("joint_source"): _fail("simultaneous coverage needs a joint source")
    if u.get("joint_source") is not None: _validate_joint_source(u["joint_source"])
    if u["kind"] == "none" and u["availability"] in {"available", "partial"}: _fail("no uncertainty cannot contain available intervals")
    if u["kind"] == "estimator_mapping" and (u.get("rows") is not None or u["coverage_scope"] != "not_applicable"): _fail("mapping connectors are not uncertainty intervals")
    if not isinstance(u.get("summary_coverage_required"), bool): _fail("explicit summary coverage policy is required")
    for name in ("inner_draws", "outer_repeats"):
        if u.get(name) is not None and (not _finite(u[name]) or u[name] < 1 or int(u[name]) != u[name]): _fail("draw/repeat counts must be positive integers")
    if u["availability"] in {"unavailable", "not_applicable"}:
        _string(u.get("reason"), "unavailable interval reason")
        if u.get("rows") is not None and _table(u["rows"]): _fail("unavailable uncertainty contains rows")
        return
    rows = u.get("rows")
    _table(rows)
    if not {"source_id", "lower", "estimate", "upper"} <= rows.keys(): _fail("interval rows lack required columns")
    interval_ids = _ids(rows["source_id"], "interval IDs")
    if not set(interval_ids) <= set(ids): _fail("intervals reference another source/grid")
    if u["availability"] == "available" and set(interval_ids) != set(ids): _fail("available intervals must cover source IDs")
    if u["availability"] == "partial": _string(u.get("reason"), "partial interval reason")
    for lo, est, hi in zip(rows["lower"], rows["estimate"], rows["upper"]):
        if not all(_finite(x) for x in (lo, est, hi)) or lo > hi: _fail("interval endpoints must be finite and ordered")
        if u["summary_coverage_required"] and not lo <= est <= hi: _fail("source_conflict: summary lies outside enclosing interval")
    domain = u.get("domain")
    if domain is not None and (len(domain) != 2 or not all(_finite(x) for x in domain) or domain[0] >= domain[1]): _fail("domain must have increasing finite bounds")


def uncertainty(target, kind, method, coverage_scope, resampling_unit, availability, rows=None, level=None, reason=None, joint_source=None, inner_draws=None, outer_repeats=None, conditioned_on=None, summary_coverage_required=True, domain=None, estimate_column="estimate"):
    result = dict(target=target, kind=kind, method=method, coverage_scope=coverage_scope, resampling_unit=resampling_unit, availability=availability, rows=rows, level=level, reason=reason, joint_source=joint_source, inner_draws=inner_draws, outer_repeats=outer_repeats, conditioned_on=conditioned_on, summary_coverage_required=summary_coverage_required, domain=domain, estimate_column=estimate_column)
    validate_uncertainty(result, [] if rows is None else rows["source_id"])
    if rows is not None and domain is not None:
        result["out_of_domain_ids"] = [i for i, lo, hi in zip(rows["source_id"], rows["lower"], rows["upper"]) if lo < domain[0] or hi > domain[1]]
    return result


def layer(ident, source, source_key, data_role, quantity, unit, independent_ids=None, independent_unit="unknown", states=None, uncertainty=None, transform=None, provenance=None, population_id="unknown", value_columns=None):
    ids = source_ids(source, source_key)
    mask = [{"source_id": ids[i], "column": col, "kind": "positive_infinity" if v > 0 else "negative_infinity"} for col, vals in source.items() for i, v in enumerate(vals) if _numeric(v) and math.isinf(v)]
    raw = {c: [None if _missing(v) or _numeric(v) and math.isinf(v) else v for v in vals] for c, vals in source.items()}
    if independent_ids is not None and len(independent_ids) != len(ids): _fail("independent IDs must map every source row")
    result = dict(id=ident, data_role=data_role, quantity=quantity, unit=unit, source_key=list(source_key), source_ids=ids, value_columns=None if value_columns is None else list(value_columns), source_sha256=table_sha256(source, ids), hash_algorithm=HASH, raw_source=raw, nonfinite_cells=mask, population_id=population_id, independent_unit=independent_unit, independent_ids=None if independent_ids is None else dict(zip(ids, independent_ids)), n_rows=len(ids), n_observations=len(ids) if data_role == "observed" else 0, n_independent=None if independent_ids is None else len(set(independent_ids)), states=states or {"source_id": ids, "state": ["observed" if data_role == "observed" else "available"] * len(ids), "reason": ["provided"] * len(ids)}, uncertainty=uncertainty, transform=transform, provenance=provenance or [])
    _validate_layer(result)
    return result


def _validate_layer(l):
    for key in ("id", "quantity", "unit", "data_role", "independent_unit", "population_id"): _string(l.get(key), "layer " + key)
    if l["data_role"] not in ROLES: _fail("unknown data role")
    ids = source_ids(l["raw_source"], l["source_key"])
    raw = _restore(l["raw_source"], ids, l.get("nonfinite_cells", []))
    if ids != l["source_ids"] or l["hash_algorithm"] != HASH or table_sha256(raw, ids) != l["source_sha256"]: _fail("layer source IDs/hash changed")
    if l["n_rows"] != len(ids) or l["n_observations"] != (len(ids) if l["data_role"] == "observed" else 0): _fail("grid/repeat counts cannot inflate observed n")
    ii = l.get("independent_ids")
    if ii is None:
        if l.get("n_independent") is not None: _fail("independent n cannot be guessed")
    elif l["independent_unit"] in {"unknown", "not_applicable"} or set(ii) != set(ids) or any(not isinstance(v, str) or not v for v in ii.values()) or l["n_independent"] != len(set(ii.values())): _fail("independent-unit mapping/count is inconsistent")
    if l.get("value_columns") is not None:
        cols = _ids(l["value_columns"], "value columns")
        if not set(cols) <= raw.keys(): _fail("declared value column absent")
        if l["quantity"] in {"probability", "posterior_probability", "posterior_inclusion_probability"} and any(not _missing(v) and (not _finite(v) or not 0 <= v <= 1) for c in cols for v in raw[c]): _fail("explicit probability value column outside [0,1]")
    s = l["states"]; _table(s)
    if not {"source_id", "state", "reason"} <= s.keys() or set(_ids(s["source_id"], "state IDs")) != set(ids): _fail("states must resolve every source ID")
    if any(v not in STATES for v in s["state"]) or any(not isinstance(v, str) or not v for v in s["reason"]): _fail("state type/reason is missing")
    if "value" in s and any(k == "true_zero" and v != 0 for k, v in zip(s["state"], s["value"])): _fail("true zero requires numeric zero")
    _validate_layer_transform(l.get("transform"), raw)
    for pos, state in enumerate(s["state"]):
        if state == "true_zero":
            col = s.get("source_column", [None]*len(ids))[pos]
            if col not in raw: _fail("true_zero must name its actual source column")
            value = raw[col][ids.index(s["source_id"][pos])]
            if not _finite(value) or value != 0: _fail("true_zero contradicts raw source value")
    u = l.get("uncertainty")
    if u is not None:
        validate_uncertainty(u, ids)
        if u["target"] != l["quantity"]: _fail("interval target differs from layer estimand")
        if u.get("rows") is not None:
            col = u.get("estimate_column")
            if col not in raw: _fail("interval estimate column absent")
            for ident, estimate in zip(u["rows"]["source_id"], u["rows"]["estimate"]):
                value = raw[col][ids.index(ident)]
                if not _finite(value) or not math.isclose(estimate, value, rel_tol=1e-12, abs_tol=1e-12): _fail("interval summary differs from source estimate")


def statistic(ident, values, ids, statistic_kind, method="unknown", adjustment="unknown", family_id="unknown", family_size=None, null="unknown", alternative="unknown", threshold=None, zero_policy="reported_zero_precision_unknown"):
    _string(ident, "statistic ID"); ids = _ids(ids, "statistic IDs")
    if statistic_kind not in STATISTICS: _fail("unknown statistic kind")
    if len(values) != len(ids) or any(not _missing(v) and (not _finite(v) or not 0 <= v <= 1) for v in values): _fail("P/probability values must be in [0,1] or missing")
    for v in (method, adjustment, family_id, null, alternative, zero_policy): _string(v, "statistic provenance")
    if family_size is not None and (not _finite(family_size) or family_size < sum(_finite(v) for v in values) or int(family_size) != family_size): _fail("family size must be an integer covering finite supplied statistics")
    if statistic_kind == "raw_p" and adjustment not in ("none", "unknown"): _fail("raw P cannot be adjusted")
    if threshold is not None: _scalar(threshold, "threshold", 0, 1)
    clean = [None if _missing(v) else v for v in values]
    return dict(id=ident, statistic_kind=statistic_kind, values=dict(zip(ids, clean)), source_ids=ids, method=method, adjustment=adjustment, family_id=family_id, family_size=family_size, null=null, alternative=alternative, threshold=threshold, n_reported=len(ids), n_finite=sum(_finite(v) for v in values), n_missing=sum(_missing(v) for v in values), n_zero=sum(v == 0 for v in values), zero_policy=zero_policy, decision=None if threshold is None else dict(zip(ids, ["unknown" if v is None else "below_threshold" if v < threshold else "not_below_threshold" for v in clean])))


def ratio(quantity, numerator_ids, denominator_ids, numerator_unit, denominator_unit, estimate, kind="fraction", tolerance=1e-10):
    _string(quantity, "ratio quantity"); ni = _ids(numerator_ids, "numerator", True); di = _ids(denominator_ids, "denominator", True)
    _string(numerator_unit, "numerator unit"); _string(denominator_unit, "denominator unit"); _scalar(tolerance, "tolerance", 0)
    if kind not in ("fraction", "rate"): _fail("unknown ratio kind")
    if kind == "fraction" and (not set(ni) <= set(di) or numerator_unit != denominator_unit): _fail("fraction requires a subset in identical units")
    reconstructed = len(ni) / len(di) if di else None
    if di:
        _scalar(estimate, "ratio estimate")
        if abs(estimate - reconstructed) > tolerance: _fail("ratio does not reconstruct from ID sets")
    elif not _missing(estimate): _fail("zero denominator is undefined, not zero")
    return dict(quantity=quantity, kind=kind, numerator=dict(ids=ni, unit=numerator_unit, n=len(ni)), denominator=dict(ids=di, unit=denominator_unit, n=len(di)), estimate=estimate if di else None, reconstructed=reconstructed, tolerance=tolerance, state="observed" if di else "undefined_zero_denominator")


def definition(quantity, observation_unit, independent_unit, unit, eligible_set, subset, aggregation, layers, numerator=None, denominator=None, ratios=None, statistics=None, comparisons=None, source_conflicts=None, notes=None):
    result = dict(semantic_version=VERSION, quantity=quantity, observation_unit=observation_unit, independent_unit=independent_unit, unit=unit, numerator=numerator, denominator=denominator, eligible_set=copy.deepcopy(eligible_set), subset=copy.deepcopy(subset), aggregation=aggregation, layers=copy.deepcopy(layers), ratios=ratios or [], statistics=statistics or [], comparisons=comparisons or [], source_conflicts=source_conflicts or [], notes=notes or [])
    validate_definition(result)
    return result


def validate_definition(d):
    if not isinstance(d, dict): _fail("definition must be an object")
    if d.get("semantic_version") != VERSION: _fail("unknown semantic version")
    for n in ("quantity", "observation_unit", "independent_unit", "unit", "aggregation"): _string(d.get(n), n)
    for n in ("eligible_set", "subset"):
        x = d[n]
        if x.get("status") not in {"known", "unknown", "not_applicable"}: _fail("population status is unknown")
        _string(x.get("rule"), n + " rule")
        if x["status"] == "known": _ids(x.get("ids", []), n + " IDs", True)
        elif x.get("ids"): _fail("unknown population cannot contain invented IDs")
    if d["eligible_set"]["status"] == d["subset"]["status"] == "known" and not set(d["subset"].get("ids", [])) <= set(d["eligible_set"].get("ids", [])): _fail("subset outside eligible set")
    _ids([l["id"] for l in d["layers"]], "layer IDs")
    for l in d["layers"]: _validate_layer(l)
    populations = {}
    for l in d["layers"]:
        if l["data_role"] != "observed" or l["population_id"] == "unknown": continue
        pop = populations.setdefault(l["population_id"], dict(unit=l["independent_unit"], ids={}))
        if pop["unit"] != l["independent_unit"]: _fail("one population has conflicting independent units")
        for ident, person in (l.get("independent_ids") or {}).items():
            if ident in pop["ids"] and pop["ids"][ident] != person: _fail("one observation maps to conflicting independent IDs")
            pop["ids"][ident] = person
    for name in ("numerator", "denominator"): _validate_named_set(d.get(name), name)
    _ids([s["id"] for s in d.get("statistics", [])], "statistic IDs", True)
    for s in d.get("statistics", []):
        if not set(s["source_ids"]) <= {i for l in d["layers"] for i in l["source_ids"]}: _fail("statistic rows do not resolve to retained layers")
        if set(s["values"]) != set(s["source_ids"]): _fail("statistic values not in source order")
        checked = statistic(s["id"], [s["values"][i] for i in s["source_ids"]], s["source_ids"], s["statistic_kind"], **{k:s.get(k) for k in ("method", "adjustment", "family_id", "family_size", "null", "alternative", "threshold", "zero_policy")})
        for k in ("n_reported", "n_finite", "n_missing", "n_zero", "decision"):
            if s[k] != checked[k]: _fail("statistic counts/decisions inconsistent")
    for r in d.get("ratios", []):
        checked = ratio(r["quantity"], r["numerator"]["ids"], r["denominator"]["ids"], r["numerator"]["unit"], r["denominator"]["unit"], r["estimate"], r["kind"], r["tolerance"])
        if r != checked: _fail("ratio counts/state/reconstruction inconsistent")
    _ids([c["id"] for c in d.get("comparisons", [])], "comparison IDs", True)
    for c in d.get("comparisons", []):
        for n in ("model_id", "test_id", "endpoint", "source_result_id", "statistic_id", "family_id", "paired_unit"): _string(c.get(n), "comparison " + n)
        matches = [s for s in d.get("statistics", []) if s["id"] == c["statistic_id"]]
        if len(matches) != 1 or c["source_result_id"] not in matches[0]["source_ids"] or c["family_id"] != matches[0]["family_id"]: _fail("comparison does not resolve to a source result/family")
        if len(_ids(c["endpoint_ids"], "comparison endpoints")) < 2: _fail("comparison needs two endpoints")
    return copy.deepcopy(d)


def validate_evidence_refs(refs, record_root=None):
    """Resolve pinned records when a local root is supplied; never infer engine validity."""
    from pathlib import Path
    for entry in refs:
        _string(entry.get("family"), "evidence family")
        if entry.get("status") not in {"pending", "sufficient_design_evidence"}: _fail("evidence cannot imply numerical acceptance")
        keys = set()
        for r in entry.get("records", []):
            for n in ("record_id", "path", "independent_figure_key", "sha256", "source_ref", "support"): _string(r.get(n), "evidence " + n)
            p = Path(r["path"])
            if p.is_absolute() or ".." in p.parts or len(r["sha256"]) != 64 or any(c not in "0123456789abcdef" for c in r["sha256"]): _fail("evidence requires safe path and SHA256")
            if record_root is not None:
                root = Path(record_root).resolve()
                p = (root / p).resolve()
                if root not in p.parents: _fail("evidence symlink escapes its record root")
                if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != r["sha256"]: _fail("evidence record missing or hash changed")
                doc = json.loads(p.read_text())
                if doc.get("record_id", doc.get("id")) != r["record_id"] or doc.get("independent_figure_key") != r["independent_figure_key"]: _fail("evidence ID/key does not resolve")
            if r["record_id"] != "0242" and r.get("eligible_for_family") is True: keys.add(r["independent_figure_key"])
        if entry.get("independent_records", len(keys)) != len(keys): _fail("evidence count includes duplicates, companions or ineligible records")
        if entry["status"] == "sufficient_design_evidence" and (record_root is None or len(keys) < 20): _fail("family evidence remains pending below20 verified independent records")
    return copy.deepcopy(refs)


def display_transform(values, kind="identity", source_scale="raw", unit="unknown", pseudocount=0, invalid="error", offset=0, ticks=None, reference=None):
    """Display-only conversion with explicit raw values and auditable exclusions."""
    kinds = {"identity", "log", "log2", "log10", "log1p", "sqrt", "exp", "inverse_logit", "folded_ratio"}
    if kind not in kinds or invalid not in {"error", "missing"}: _fail("unknown display transform or invalid policy")
    _string(source_scale, "source scale"); _string(unit, "source unit")
    _scalar(pseudocount, "pseudocount", 0); _scalar(offset, "offset")
    if pseudocount and kind not in {"log", "log2", "log10", "log1p"}: _fail("transform does not apply a pseudocount")
    if kind != "identity" and source_scale.startswith("display:"): _fail("display transform cannot be applied twice")
    if kind in {"log", "log2", "log10", "log1p", "folded_ratio"} and "log" in source_scale: _fail("log input must not be logged again")
    if kind == "inverse_logit" and source_scale != "logit": _fail("inverse logit requires logit source")
    if kind == "exp" and source_scale != "log_link": _fail("exp conversion requires log-link source")
    def transform(v):
        if _missing(v): return None
        if not _numeric(v): _fail("display values must be numeric")
        try:
            if kind == "identity": out = v
            elif kind == "log": out = math.log(v+pseudocount)
            elif kind == "log2": out = math.log2(v+pseudocount)
            elif kind == "log10": out = math.log10(v+pseudocount)
            elif kind == "log1p": out = math.log1p(v+pseudocount)
            elif kind == "sqrt": out = math.sqrt(v)
            elif kind == "exp": out = math.exp(v)
            elif kind == "inverse_logit": out = 1/(1+math.exp(-v)) if v >= 0 else math.exp(v)/(1+math.exp(v))
            else: out = math.exp(abs(math.log(v)))
        except (ValueError, OverflowError): return None
        return out if math.isfinite(out) else None
    raw, shown, states = [None if _missing(v) else v for v in values], [], []
    for v in raw:
        result = transform(v)
        bad = _finite(v) and result is None
        if bad and invalid == "error": _fail("display transform outside finite domain")
        states.append("missing" if _missing(v) else "infinite" if not _finite(v) else "out_of_domain" if bad else "true_zero" if v == 0 else "observed")
        shown.append(None if result is None else result + offset)
    def axis(x):
        if x is None: return None
        mapped = [transform(v) for v in x]
        if any(v is None for v in mapped): _fail("tick/reference outside transform domain")
        return [v+offset for v in mapped]
    return dict(raw=raw, display=shown, state=states, definition=dict(source_scale=source_scale, display_scale="display:"+kind, unit=unit, transform=kind, base={"log":math.e,"log2":2,"log10":10,"log1p":math.e,"folded_ratio":math.e}.get(kind), direction_preserved=kind!="folded_ratio", pseudocount=pseudocount, offset=offset, operation_order=["source", "pseudocount_when_declared", "transform", "display_offset"], invalid_policy=invalid, n_display_excluded=sum(v is None for v in shown), statistics_use="raw"), ticks_raw=ticks, ticks_display=axis(ticks), reference_raw=reference, reference_display=axis(reference), display_only=True)


def analysis_values(value):
    if isinstance(value, dict) and value.get("display_only") is True: _fail("display-only values cannot enter analysis; select retained raw source")
    return value


def layer_transform(source, column, **kwargs):
    _string(column, "transform source column")
    if column not in source: _fail("transform source column absent")
    return dict(source_column=column, operation=display_transform(source[column], **kwargs))


def _validate_layer_transform(transform, raw):
    if transform is None: return
    col = transform.get("source_column"); _string(col, "transform source column")
    if col not in raw: _fail("transform column absent")
    op = transform["operation"]; d = op["definition"]
    if any(_numeric(v) and math.isinf(v) for v in raw[col]): _fail("attached transforms require finite or missing raw values; retain infinite source untransformed")
    if op["raw"] != raw[col]: _fail("display transform raw values differ from source")
    checked = display_transform(op["raw"], d["transform"], d["source_scale"], d["unit"], d["pseudocount"], d["invalid_policy"], d["offset"], op.get("ticks_raw"), op.get("reference_raw"))
    for name in ("display", "ticks_display", "reference_display"):
        a, b = op.get(name), checked[name]
        if a is None and b is None: continue
        if a is None or b is None or len(a) != len(b): _fail("display transform dimensions differ")
        for x, y in zip(a, b):
            if _missing(x) and _missing(y): continue
            if not _finite(x) or not _finite(y) or not math.isclose(x, y, rel_tol=1e-12, abs_tol=1e-12): _fail("display transform does not replay")
    if op["state"] != checked["state"] or op.get("display_only") is not True or d["statistics_use"] != "raw" or d["n_display_excluded"] != checked["definition"]["n_display_excluded"]: _fail("display-only transform state/firewall changed")


def _validate_named_set(x, name):
    if x is None: return
    if not isinstance(x, dict) or x.get("status") not in {"known", "unknown", "not_applicable"}: _fail(name+" requires explicit set status")
    _string(x.get("unit"), name+" unit"); _string(x.get("rule"), name+" rule")
    if x["status"] == "known":
        ids = _ids(x.get("ids", []), name+" IDs", True)
        if x.get("n") is not None and x["n"] != len(ids): _fail(name+" count differs from IDs")
    elif x.get("ids") or x.get("n") is not None: _fail(name+" unknown/not applicable cannot invent IDs/count")


def _validate_joint_source(j):
    if not isinstance(j, dict) or j.get("kind") not in {"covariance", "paired_draws"}: _fail("joint source requires supplied covariance or paired draws")
    ids = _ids(j.get("parameter_ids", []), "joint parameter IDs")
    w = j.get("weights", {})
    if set(w) != set(ids) or any(not _finite(v) for v in w.values()): _fail("joint weights must be finite and keyed")
    sha = j.get("source_sha256", "")
    if len(sha) != 64 or any(c not in "0123456789abcdef" for c in sha): _fail("joint source requires pinned SHA256")
    if j.get("interval_computed") is not False: _fail("renderer never computes an interval from a joint source")
    if j["kind"] == "covariance":
        cv = j.get("supplied_covariance", [])
        n = len(ids)
        if len(cv) != n or any(len(row) != n for row in cv) or any(not _finite(v) for row in cv for v in row): _fail("joint covariance dimensions/finite values invalid")
        if any(not math.isclose(cv[i][k],cv[k][i],rel_tol=1e-12,abs_tol=1e-12) for i in range(n) for k in range(n)): _fail("joint covariance not symmetric")
        # Semidefinite Cholesky check, including zero pivots. No estimator fit.
        L = [[0.0]*n for _ in range(n)]
        for i in range(n):
            for k in range(i+1):
                v = cv[i][k]-sum(L[i][a]*L[k][a] for a in range(k))
                if i == k:
                    if v < -1e-10: _fail("joint covariance not positive semidefinite")
                    L[i][k] = math.sqrt(max(v,0))
                elif L[k][k] > 1e-12: L[i][k] = v/L[k][k]
                elif abs(v) > 1e-10: _fail("joint covariance not positive semidefinite")
        variance = sum(w[ids[i]]*cv[i][k]*w[ids[k]] for i in range(n) for k in range(n))
        if not _finite(j.get("contrast_variance")) or not math.isclose(j["contrast_variance"],variance,rel_tol=1e-12,abs_tol=1e-12): _fail("joint contrast variance changed")
    else:
        draws = j.get("paired_draws", []); draw_ids = _ids(j.get("draw_ids", []),"paired draw IDs")
        if len(draws) != len(draw_ids) or any(len(row)!=len(ids) for row in draws) or any(not _finite(v) for row in draws for v in row): _fail("paired draws must preserve full keyed rows/parameters")
        if j.get("contrast_variance") is not None: _fail("paired draws do not infer a variance or interval")
