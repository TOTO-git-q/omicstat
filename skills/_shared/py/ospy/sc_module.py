"""Single-cell engine contracts; computation stays in each module's core.

No scientific package is imported until input validation. Modules share safe
I/O, chain validation, deterministic tables and the R-only figure boundary.
"""
from __future__ import annotations

import importlib.metadata as metadata
import json
import os
from pathlib import Path
from typing import Any

from . import args as A, engine_run, handoff as H, module_kit as K
from . import figure_request as F, feature_table as FT
from .errors import OmicstatError
from .seed import set_seed, THREAD_VARS

VERSION = "1.0.0"
STATE_KEY = "omicstat_chain_state_json"


def common_flags():
    return [
        A.os_flag("input", "path", must_exist=True, help="local AnnData .h5ad file; never downloaded"),
        A.os_flag("from-run", "path", must_exist=True, help="verified upstream run; exclusive with --input"),
        A.os_flag("upstream-object", "string", help="name of the upstream AnnData when more than one exists"),
        A.os_flag("outdir", "path", required=True, help="new output directory"),
        A.os_flag("spec", "path", must_exist=True, help="replay provenance/resolved_spec.json"),
        A.os_flag("study-contract", "path", must_exist=True, help="local StudyContract JSON; must match the upstream hash"),
        A.os_flag("species", "string", required=True, help="declared organism; not inferred from identifiers"),
        A.os_flag("annotation", "string", required=True, help="declared feature annotation release"),
        A.os_flag("sample-col", "string", required=True, help="obs column identifying biological samples"),
        A.os_flag("counts-layer", "string", required=True, help="raw integer count layer; use X explicitly for .X"),
        A.os_flag("seed", "int", default=20260925, range=(0, 2147483647), help="fixed random seed"),
        A.os_flag("embedding-width", "enum", default="single", values=["single", "onehalf", "double"], help="embedding figure width preset"),
        A.os_flag("embedding-height-mm", "num", range=(1, 1000), help="explicit embedding figure height in mm"),
        A.os_flag("colour-registry", "path", must_exist=True, help="seeded figure colour registry JSON"),
        A.os_flag("cell-list", "path", must_exist=True, help="explicit display-only cell selection; CSV cell column or one ID per line"),
        A.os_flag("display-max-per-group", "int", range=(1, 2147483647), help="embedding drawing cap only; analysis objects and tables retain all cells"),
        A.os_flag("label-placement", "enum", default="median", values=["median", "largest-island"], help="embedding label coordinates; largest-island requires explicit DBSCAN parameters"),
        A.os_flag("label-island-eps", "num", range=(1e-12, 1e12), help="DBSCAN eps in embedding units for largest-island labels"),
        A.os_flag("label-island-min-samples", "int", range=(1, 2147483647), help="DBSCAN min_samples for largest-island labels"),
        A.os_flag("label-style", "enum", default="plain", values=["plain", "halo"], help="embedding label rendering; halo adds a white outline and label spacing (display only)"),
        A.os_flag("journal", "enum", default="nature", values=["nature", "cell", "science", "generic"], help="shared R figure preset"),
    ]


def require_columns(frame, columns):
    for col in columns:
        if col not in frame:
            raise OmicstatError("OS_MISSING_COLUMN", "missing metadata column '%s'." % col)
        if frame[col].isna().any() or frame[col].astype(str).eq("").any():
            raise OmicstatError("OS_INVALID_INPUT", "metadata column '%s' has missing values." % col)


def validate_counts(matrix):
    import numpy as np
    from scipy import sparse
    values = matrix.data if sparse.issparse(matrix) else np.asarray(matrix)
    if values.dtype.kind not in "biuf" or not np.isfinite(values).all():
        raise OmicstatError("OS_INVALID_INPUT", "counts must be finite numeric values.")
    if np.any(values < 0) or np.any(values != np.floor(values)):
        raise OmicstatError("OS_INVALID_INPUT", "raw counts must be nonnegative integers; normalized values are not counts.")


def layer(adata, name, *, counts=False):
    if name == "X":
        matrix = adata.X
    elif name in adata.layers:
        matrix = adata.layers[name]
    else:
        raise OmicstatError("OS_MISSING_LAYER", "requested layer '%s' does not exist." % name)
    if matrix is None:
        raise OmicstatError("OS_MISSING_LAYER", "requested expression matrix is absent.")
    if counts:
        validate_counts(matrix)
    return matrix


def canonical_clusters(values):
    """Stable IDs: decreasing size, then original UTF-8 label order."""
    from collections import Counter
    import pandas as pd
    labels = [str(v) for v in values]
    counts = Counter(labels)
    levels = sorted(counts, key=lambda x: (-counts[x], x.encode("utf-8")))
    mapping = {old: str(i) for i, old in enumerate(levels)}
    return pd.Categorical([mapping[v] for v in labels], categories=list(mapping.values())), mapping


def canonical_pca(scores, loadings):
    import numpy as np
    scores, loadings = np.asarray(scores).copy(), np.asarray(loadings).copy()
    if scores.shape[1] != loadings.shape[1] or not np.isfinite(loadings).all():
        raise OmicstatError("OS_INVALID_INPUT", "invalid PCA axes.")
    for j in range(loadings.shape[1]):
        pivot = int(np.argmax(np.abs(loadings[:, j])))
        if loadings[pivot, j] < 0:
            scores[:, j] *= -1
            loadings[:, j] *= -1
    return scores, loadings


def embedding_frame(adata, group_col, key="X_umap"):
    import numpy as np
    import pandas as pd
    require_columns(adata.obs, [group_col])
    if key not in adata.obsm:
        raise OmicstatError("OS_MISSING_REDUCTION", "run the matching front-end clustering module first (%s missing)." % key)
    coordinates = np.asarray(adata.obsm[key])
    if coordinates.shape != (adata.n_obs, 2) or not np.isfinite(coordinates).all():
        raise OmicstatError("OS_INVALID_INPUT", "a finite two-dimensional UMAP is required.")
    return pd.DataFrame({"cell": adata.obs_names.astype(str), "x": coordinates[:, 0],
                         "y": coordinates[:, 1], group_col: adata.obs[group_col].to_numpy()})


def marker_dot_data(adata, expression, cluster_col, genes):
    import numpy as np
    import pandas as pd
    genes = list(dict.fromkeys(str(g) for g in genes))
    indices = adata.var_names.get_indexer(genes)
    if (indices < 0).any():
        raise OmicstatError("OS_INVALID_INPUT", "marker figure contains unknown genes.")
    groups = adata.obs[cluster_col].astype(str).to_numpy()
    rows = []
    for group in sorted(set(groups), key=lambda x: x.encode("utf-8")):
        selected = expression[groups == group, :][:, indices]
        means = np.asarray(selected.mean(axis=0)).ravel()
        fractions = np.asarray((selected > 0).sum(axis=0)).ravel() / selected.shape[0] * 100.0
        rows.extend({"cluster": group, "gene": g, "avg_exp": float(m), "pct_exp": float(p)}
                    for g, m, p in zip(genes, means, fractions))
    return pd.DataFrame(rows)


def batch_mixing(connectivities, batches):
    """Descriptive neighborhood mixing, not a test of biological validity."""
    import numpy as np
    from scipy import sparse
    import pandas as pd
    graph = sparse.csr_matrix(connectivities, copy=True)
    graph.setdiag(0)
    graph.eliminate_zeros()
    labels = np.asarray(batches).astype(str)
    if graph.shape != (len(labels), len(labels)):
        raise OmicstatError("OS_INVALID_INPUT", "neighbor graph axes disagree with cells.")
    same = np.empty(len(labels), dtype=float)
    entropy = np.empty(len(labels), dtype=float)
    categories = sorted(set(labels))
    for i in range(len(labels)):
        start, end = graph.indptr[i:i+2]
        neighbors, weights = graph.indices[start:end], graph.data[start:end]
        total = float(weights.sum())
        if total <= 0:
            same[i] = entropy[i] = float("nan")
            continue
        same[i] = float(weights[labels[neighbors] == labels[i]].sum() / total)
        probs = np.array([weights[labels[neighbors] == c].sum() / total for c in categories])
        probs = probs[probs > 0]
        entropy[i] = float(-(probs * np.log(probs)).sum() / np.log(len(categories))) if len(categories) > 1 else 0.0
    return pd.DataFrame({"same_batch_weight_fraction": same, "normalized_batch_entropy": entropy})


def read_input(a, module=None):
    if bool(a["input"]) == bool(a["from-run"]):
        raise OmicstatError("OS_MISSING_PARAMETER", "supply exactly one of --input and --from-run.")
    contract_hash = K.sha256_file(a["study-contract"]) if a["study-contract"] else None
    if a["study-contract"]:
        with open(a["study-contract"], encoding="utf-8") as stream:
            if not isinstance(json.load(stream), dict):
                raise OmicstatError("OS_INVALID_INPUT", "StudyContract must be a JSON object.")
    upstream = None
    path = a["input"]
    if a["from-run"]:
        upstream = H.read_handoff(a["from-run"], front_end_ecosystem="scverse", contract_hash=contract_hash)
        names = [name for name, item in upstream["objects"].items() if item["type"] == "AnnData"]
        if a["upstream-object"]:
            names = [n for n in names if n == a["upstream-object"]]
        if len(names) != 1:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "select exactly one upstream AnnData with --upstream-object.")
        H.assert_uncorrected(upstream, names[0], "single-cell analysis")
        path = upstream["objects"][names[0]]["path"]
        contract_hash = contract_hash or upstream.get("contract_hash")
    if not str(path).lower().endswith(".h5ad"):
        raise OmicstatError("OS_ECOSYSTEM_MIXED", "the scverse front end accepts only AnnData .h5ad files.")
    try:
        import anndata as ad
    except ImportError as exc:
        raise OmicstatError("OS_DEPENDENCY_MISSING", "use the locked omicstat-py image (anndata missing).") from exc
    adata = ad.read_h5ad(filename=path, backed=None, as_sparse=(), as_sparse_fmt=__import__("scipy").sparse.csr_matrix, chunk_size=6000)
    if adata.n_obs < 2 or adata.n_vars < 2:
        raise OmicstatError("OS_EMPTY_DATA", "at least two cells and two genes are required.")
    if not adata.obs_names.is_unique or not adata.var_names.is_unique:
        raise OmicstatError("OS_INVALID_INPUT", "cell and gene identifiers must be unique; no silent renaming is performed.")
    if any(not str(v) for v in adata.obs_names) or any(not str(v) for v in adata.var_names):
        raise OmicstatError("OS_INVALID_INPUT", "empty cell or gene identifiers.")
    state = dict((upstream or {}).get("state") or {})
    embedded = adata.uns.get(STATE_KEY)
    if embedded is not None:
        try:
            embedded = json.loads(str(embedded))
        except (TypeError, ValueError) as exc:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "invalid embedded single-cell chain state.") from exc
        if not isinstance(embedded, dict):
            raise OmicstatError("OS_HANDOFF_MISMATCH", "embedded chain state must be an object.")
        for key in ("front_end_ecosystem", "batch_corrected_lineage", "species", "annotation", "display_only"):
            if key in state and key in embedded and state[key] != embedded[key]:
                raise OmicstatError("OS_HANDOFF_MISMATCH", "embedded and external chain state disagree on %s." % key)
        state = {**embedded, **state}
    if state.get("front_end_ecosystem", "scverse") != "scverse":
        raise OmicstatError("OS_ECOSYSTEM_MIXED", "the embedded chain came from another front-end ecosystem.")
    if state.get("batch_corrected_lineage") is True:
        raise OmicstatError("OS_BATCH_CORRECTED_INPUT", "this object descends from batch-corrected expression.")
    for key in ("species", "annotation"):
        if key in state and state[key] != a[key]:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "declared %s differs from the upstream chain." % key)
    if module == "scanpy-markers" and (state.get("display_only") is True or a.get("cell-list")):
        raise OmicstatError("OS_DISPLAY_ONLY_INPUT", "display-curated cells cannot be used for markers or DE; use the uncurated analysis run.")
    if a.get("cell-list"):
        from .display import read_cells
        cells = read_cells(a["cell-list"])
        if not set(cells).issubset(set(adata.obs_names)):
            raise OmicstatError("OS_CELL_MISMATCH", "cell-list contains cells absent from the input object.")
        adata = adata[cells].copy()
        state = {**state, "display_only": True, "display_selection": "explicit cell-list"}
    if not a.get("purpose") == "cluster-description":
        require_columns(adata.obs, [a["sample-col"]])
    layer(adata, a["counts-layer"], counts=True)
    return adata, upstream, path, state, contract_hash


def write_table(table, path):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    table.to_csv(path, index=False, float_format="%.17g", lineterminator="\n", na_rep="NA")


def standard_qc(res, a, prefix, module_dir, extra=()):
    versions = json.loads((Path(module_dir) / "scripts/calls_registry.json").read_text())["package_versions"]
    mismatches = []
    for package, want in versions.items():
        try:
            have = metadata.version(package)
        except metadata.PackageNotFoundError:
            have = "missing"
        if have != want:
            mismatches.append("%s: %s != %s" % (package, have, want))
    rows = [K.qc_rule(prefix + "-01", "locked_versions", bool(mismatches), "blocker",
                      "Analysis package versions differ from the locked environment.",
                      "Rerun in omicstat-py:2026.09.1 before using the draft.", "; ".join(mismatches)),
            K.qc_rule(prefix + "-02", "sample_replication", (res["adata"].obs[a["sample-col"]].nunique() if a["sample-col"] in res["adata"].obs else 0) < 2,
                      "warning", "Fewer than two biological samples are present.",
                      "Treat these results as descriptive; no condition-level inference.", "ENGINEERING_PLAN 4.5")]
    rows.extend(extra)
    return K.qc_finalize(rows, "tables/" + next(iter(res["tables"])) + ".csv")


def write_outputs(res, a, module, module_dir, upstream, state, contract_hash, qc, figures, module_version=VERSION):
    outdir = Path(a["outdir"])
    adata = res["adata"]
    state = {**state, **res.get("state", {}), "front_end_ecosystem": "scverse", "seed": a["seed"],
             "species": a["species"], "annotation": a["annotation"], "sample_col": a["sample-col"]}
    adata.uns[STATE_KEY] = json.dumps(state, sort_keys=True, allow_nan=False)
    object_path = outdir / "objects/adata.h5ad"
    object_path.parent.mkdir(parents=True, exist_ok=True)
    adata.write_h5ad(filename=object_path, compression="gzip", compression_opts=4, as_dense=())
    objects = {"adata": {"path": str(object_path), "type": "AnnData"}}
    outputs = ["objects/adata.h5ad", "objects/handoff.json"]
    for name, table in res["tables"].items():
        rel = "tables/%s.csv" % name
        if name == "feature_table":
            FT.write_feature_table(FT.as_feature_table(table), str(outdir / rel))
        else:
            write_table(table, outdir / rel)
        outputs.append(rel)
        objects[name] = {"path": str(outdir / rel), "type": "feature_table" if name == "feature_table" else "cell_metadata" if name == "cell_metadata" else "analysis_table"}
    # Learned model files are handed off individually and hashed, not opaque directories.
    for name, path in res.get("model_files", {}).items():
        objects[name] = {"path": str(path), "type": "scvi_model_file"}
        outputs.append(Path(path).relative_to(outdir).as_posix())
    H.write_handoff(str(outdir), H.os_run_id(str(outdir)), module, module_version, objects,
                    contract_hash=contract_hash, ecosystem="scverse", state=state,
                    upstream_runs=(upstream or {}).get("upstream_runs") or [])
    from . import display as D
    registry = res.get("colour_registry")
    if a.get("colour-registry"):
        registry = D.read_registry(a["colour-registry"])
    elif registry is None and upstream and "colour_registry" in upstream["objects"]:
        registry = D.read_registry(upstream["objects"]["colour_registry"]["path"])
    if registry is not None:
        registry_path = outdir / "objects/colour_registry.json"
        K.write_json(registry, str(registry_path))
        objects["colour_registry"] = {"path": str(registry_path), "type": "colour_registry"}
        outputs.append("objects/colour_registry.json")
        H.write_handoff(str(outdir), H.os_run_id(str(outdir)), module, module_version, objects,
                        contract_hash=contract_hash, ecosystem="scverse", state=state,
                        upstream_runs=(upstream or {}).get("upstream_runs") or [])
    request = F.FigureRequest(str(outdir), module, module_version, journal=a["journal"], colour_registry="objects/colour_registry.json" if registry is not None else None)
    for fig_id, builder, data, kwargs in figures:
        selected = {key: a[key] for key in ("min-genes", "max-genes", "min-counts", "max-counts", "max-mito-percent",
                    "min-cells", "doublet-mode", "n-hvg", "n-pcs", "resolution", "n-neighbors", "alpha", "test",
                    "n-latent", "max-epochs", "min-confidence", "scale") if key in a and a[key] is not None}
        if res["summary"].get("representation_reused"):
            selected.pop("n-pcs", None)
        if res["summary"].get("latent_reused"):
            selected.pop("max-epochs", None)
            selected.pop("n-latent", None)
        context = ("Analysis: %s; %d retained cells, %d retained genes, %d biological sample(s). Prespecified settings: %s."
                   % (module, adata.n_obs, adata.n_vars, (adata.obs[a["sample-col"]].nunique() if a["sample-col"] in adata.obs else 0),
                      "; ".join("%s=%s" % item for item in selected.items())))
        if res["summary"].get("latent_reused"):
            context += " Existing X_scVI coordinates were reused; no model was trained in this run."
        if res["summary"].get("representation_reused"):
            context += " The existing representation was used; PCA and scaling were not recomputed."
        if builder == "os_embedding":
            data, kwargs = D.embedding_data(data, kwargs, a)
        if state.get("display_only"):
            context += " Display only: curated cells must not be used for proportions, pseudobulk, markers or DE."
        request.add(fig_id, builder, data=data, args=kwargs, caption_context=context,
                    width=a.get("embedding-width", "single") if builder == "os_embedding" else "single",
                    height_mm=a.get("embedding-height-mm") if builder == "os_embedding" else None)
    request.write()
    outputs.append(F.REQUEST_REL)
    K.write_qc_results(qc, str(outdir))
    values = {**res["summary"], "module": module, "module_version": module_version, "seed": a["seed"],
              "n_cells": int(adata.n_obs), "n_genes": int(adata.n_vars),
              "n_samples": int((adata.obs[a["sample-col"]].nunique() if a["sample-col"] in adata.obs else 0)),
              "parameters": {k: v for k, v in a.items() if k not in ("help", "outdir", "input", "from-run", "spec", "study-contract")},
              "state": state, "qc_triggered": [r["id"] for r in qc["table"] if r["triggered"]]}
    values["package_versions"] = {p: metadata.version(p) for p in json.loads((Path(module_dir)/"scripts/calls_registry.json").read_text())["package_versions"]}
    summary = "results/%s_results.json" % module.replace("-", "_")
    K.write_json(values, str(outdir / summary))
    outputs.extend([summary, "qc/qc_results.csv"])
    templates = K.read_templates(str(Path(module_dir)/"references/reporting-templates.md"))
    if not qc["blocking"]:
        methods_template = templates.get("methods_reuse", templates["methods"]) if values.get("latent_reused") else templates["methods"]
        if values.get("representation_reused"):
            methods_template = templates.get("methods_rep", methods_template)
        method = K.fill_template(methods_template, values)
        results_template = templates.get("results_rep", templates["results"]) if values.get("representation_reused") else templates["results"]
        result = K.fill_template(results_template, values)
        parameters = json.dumps(values["parameters"], indent=2, sort_keys=True)
        K.write_text(["# %s: Methods and Results" % module, "", "## Methods", method, "Software versions: " + json.dumps(values["package_versions"], sort_keys=True),
                      "", "## Results", result, "", "## Resolved parameters", "```json", parameters, "```",
                      "", "## Native arguments", "```json", json.dumps(res["summary"].get("native_options", {}), indent=2, sort_keys=True), "```",
                      "", "## Figure legends", "Legends and plot metadata are generated by the shared R renderer.",
                      "These results are not ready for publication until the R figure step and publication validation pass."],
                     str(outdir / "draft/methods_results.md"))
        outputs.append("draft/methods_results.md")
    else:
        K.write_text(["Draft withheld: blocking QC rules " + ", ".join(qc["blocking_ids"])], str(outdir/"qc/draft_withheld.txt"))
    return outputs, values


def run_module(argv, spec, module, module_dir, compute, report, qc_fn, validate, module_version=VERSION):
    """Ten-stage entry implementation with package-independent --help."""
    a = A.os_parse_args(spec, K.spec_argv(argv))
    if a["help"]:
        A.os_print_help(spec)
        return 0
    validate(a)
    if a.get("label-placement") == "largest-island" and (a.get("label-island-eps") is None or a.get("label-island-min-samples") is None):
        raise OmicstatError("OS_MISSING_PARAMETER", "largest-island labels require --label-island-eps and --label-island-min-samples.")
    outdir = Path(a["outdir"]).resolve()
    for protected in (a["input"], a["from-run"]):
        if protected and (outdir == Path(protected).resolve() or outdir in Path(protected).resolve().parents):
            raise OmicstatError("OS_INVALID_PARAMETER", "output must not contain or overwrite an input run.")
    if any((outdir / name).exists() for name in ("tables", "draft", "objects/adata.h5ad")):
        raise OmicstatError("OS_OUTPUT_EXISTS", "use a fresh --outdir to avoid stale analysis artifacts.")
    outdir.mkdir(parents=True, exist_ok=True)
    a["outdir"] = str(outdir)
    for variable in THREAD_VARS:
        os.environ[variable] = "1"
    elog = engine_run.EngineLog(str(outdir))
    adata, upstream, input_path, state, contract_hash = elog.capture("input", read_input, a, module)
    seeds = set_seed(a["seed"])
    try:
        res = elog.capture("compute", compute, adata, a, upstream)
    except ImportError as exc:
        raise OmicstatError("OS_DEPENDENCY_MISSING", "run in the locked omicstat-py image: %s" % exc) from exc
    qc = elog.capture("qc", qc_fn, res, a, module_dir)
    figures = elog.capture("figure_request", report, res, a)
    outputs, summary = elog.capture("report", write_outputs, res, a, module, module_dir, upstream, state, contract_hash, qc, figures, module_version)
    inputs = {"input": input_path}
    for key in ("study-contract", "features-file", "cell-list", "colour-registry", "marker-panel", "label-map"):
        if a.get(key):
            inputs[key] = a[key]
    for key in ("latent-from-run", "reference-run", "query-run"):
        if a.get(key):
            inputs[key] = str(Path(a[key]) / "objects/handoff.json")
    K.write_provenance(str(outdir), module, module_version, K.canonical_argv(spec, a),
                       entry_script="run_%s.py" % module.replace("-", "_"), seed=a["seed"],
                       inputs=inputs, outputs=outputs, upstream=upstream, seed_record=seeds,
                       packages=list(summary["package_versions"]), extra={"analysis_summary": summary, "contract_hash": contract_hash})
    print(K.closing_line(qc), flush=True)
    if qc["blocking"]:
        raise OmicstatError("OS_QC_BLOCKED", "blocking QC: " + ", ".join(qc["blocking_ids"]))
    return 0
