"""Descriptive cluster markers; never a condition-level differential test."""
from ospy import sc_module as S, native_options as N
from ospy.errors import OmicstatError

MODULE_VERSION = "1.0.0"


def validate(a):
    if a["purpose"] != "cluster-description":
        raise OmicstatError("OS_PSEUDOREPLICATION", "condition comparisons require muscat-pseudobulk with biological sample replication.")
    if a["cluster-col"] == a["sample-col"]:
        raise OmicstatError("OS_PSEUDOREPLICATION", "sample identities cannot be used as cell clusters.")


def compute(adata, a, upstream):
    options = N.resolve(a, {'mask-var': 'value', 'groups': 'groups', 'reference': 'value', 'n-genes': 'value', 'rankby-abs': 'boolean', 'corr-method': 'value', 'tie-correct': 'boolean'})
    import numpy as np
    import pandas as pd
    import scanpy as sc
    from scipy import sparse
    S.require_columns(adata.obs, [a["cluster-col"]])
    group = adata.obs[a["cluster-col"]].astype(str)
    if group.nunique() < 2 or group.value_counts().min() < 2:
        raise OmicstatError("OS_INVALID_DESIGN", "at least two clusters with at least two cells each are required.")
    expression = S.layer(adata, a["expression-layer"])
    values = expression.data if sparse.issparse(expression) else np.asarray(expression)
    if not np.isfinite(values).all() or np.any(values < 0):
        raise OmicstatError("OS_INVALID_INPUT", "marker expression must be finite nonnegative natural-log1p expression.")
    if upstream and upstream["state"].get("normalized_layer") not in (None, a["expression-layer"]):
        raise OmicstatError("OS_HANDOFF_MISMATCH", "expression layer differs from the normalized upstream layer.")
    adata.obs[a["cluster-col"]] = pd.Categorical(group, categories=sorted(group.unique()))
    # use_raw=False prevents a stale AnnData.raw from silently taking precedence.
    sc.tl.rank_genes_groups(adata=adata, groupby=a["cluster-col"], mask_var=options['mask-var'], use_raw=False, groups=options['groups'],
                            reference=options['reference'], n_genes=options['n-genes'], rankby_abs=options['rankby-abs'], pts=True,
                            key_added="omicstat_markers", copy=False, method=a["test"],
                            corr_method=options['corr-method'], tie_correct=options['tie-correct'],
                            layer=None if a["expression-layer"] == "X" else a["expression-layer"])
    native = sc.get.rank_genes_groups_df(adata=adata, group=None, key="omicstat_markers", pval_cutoff=None, log2fc_min=None, log2fc_max=None, gene_symbols=None)
    rows = []
    result = adata.uns["omicstat_markers"]
    counts = group.value_counts()
    raw = S.layer(adata, a["counts-layer"], counts=True)
    means = dict(zip(adata.var_names.astype(str), np.asarray(raw.mean(axis=0)).ravel()))
    for cluster in result["names"].dtype.names:
        for index, gene in enumerate(result["names"][cluster]):
            rows.append({"feature_id": str(gene), "symbol": str(gene), "contrast": "%s vs %s" % (cluster, a["reference"]),
                         "base_mean": float(means[str(gene)]), "log2fc": float(result["logfoldchanges"][cluster][index]),
                         "log2fc_se": np.nan, "stat": float(result["scores"][cluster][index]),
                         "pvalue": float(result["pvals"][cluster][index]), "padj": float(result["pvals_adj"][cluster][index]),
                         "method": "scanpy-%s-descriptive" % a["test"], "shrinkage": "none",
                         "n_group1": int(counts[cluster]), "n_group2": int(adata.n_obs-counts[cluster]) if a["reference"] == "rest" else int(counts[a["reference"]]),
                         "filtered_reason": "", "cluster": str(cluster), "replicate_unit": "cell (descriptive only)"})
    table = pd.DataFrame(rows).sort_values(["cluster", "padj", "feature_id"], kind="stable", na_position="last").reset_index(drop=True)
    display = table[table["padj"] <= a["alpha"]].groupby("cluster", sort=True).head(a["top-n"])
    if display.empty:
        display = table.groupby("cluster", sort=True).head(a["top-n"])
    genes = list(dict.fromkeys(display["feature_id"]))
    dot = S.marker_dot_data(adata, expression, a["cluster-col"], genes)
    return {"adata": adata, "tables": {"feature_table": table, "marker_details": table, "rank_genes_groups_native": native, "marker_dot_data": dot},
            "summary": {"native_options": N.serializable(options), "n_tested_rows": len(table), "n_clusters": len(result["names"].dtype.names),
                        "reference": options["reference"], "groups": options["groups"],
                        "mask_var": options["mask-var"], "rankby_abs": options["rankby-abs"],
                        "corr_method": options["corr-method"], "tie_correct": options["tie-correct"],
                        "requested_n_genes": options["n-genes"],
                        "mask_var_text": str(options["mask-var"]), "n_genes_text": str(options["n-genes"]),
                        "n_significant_rows": int((table["padj"] <= a["alpha"]).sum()), "test": a["test"],
                        "inference": "descriptive_cluster_markers", "p_adjustment_family": "within each cluster contrast", "alpha": a["alpha"]},
            "state": {"marker_purpose": "cluster-description", "clusters": a["cluster-col"]}}
