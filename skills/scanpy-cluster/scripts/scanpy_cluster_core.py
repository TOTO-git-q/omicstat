"""Normalization, HVGs, PCA, neighbors, Leiden and UMAP; counts are retained."""
from ospy import sc_module as S, native_options as N
from ospy.errors import OmicstatError

MODULE_VERSION = "1.0.1"


def validate(a):
    if a["n-pcs"] >= a["n-hvg"]:
        raise OmicstatError("OS_INVALID_PARAMETER", "--n-pcs must be smaller than --n-hvg.")


def compute(adata, a, upstream):
    options = N.resolve(a, {'normalize-exclude-highly-expressed': 'boolean', 'normalize-max-fraction': 'value', 'log1p-base': 'value', 'hvg-span': 'value', 'hvg-n-bins': 'value', 'hvg-flavor': 'value', 'scale-zero-center': 'boolean', 'pca-zero-center': 'boolean', 'pca-svd-solver': 'nullable_string', 'pca-dtype': 'value', 'neighbors-method': 'value', 'neighbors-transformer': 'nullable_string', 'neighbors-metric': 'value', 'neighbors-metric-kwds': 'object', 'leiden-use-weights': 'boolean', 'leiden-n-iterations': 'value', 'leiden-partition-type': 'partition', 'umap-spread': 'value', 'umap-maxiter': 'value', 'umap-alpha': 'value', 'umap-gamma': 'value', 'umap-negative-sample-rate': 'value', 'umap-init-pos': 'value', 'umap-a': 'value', 'umap-b': 'value'})
    import numpy as np
    import pandas as pd
    import scanpy as sc
    if a["n-pcs"] >= min(adata.n_obs, adata.n_vars) or a["n-hvg"] > adata.n_vars or a["n-neighbors"] >= adata.n_obs:
        raise OmicstatError("OS_INVALID_PARAMETER", "PCs, HVGs and neighbors exceed the supplied data dimensions.")
    if adata.n_obs * a["n-hvg"] > 100_000_000:
        raise OmicstatError("OS_RESOURCE_LIMIT", "centered PCA is limited to 100 million cell-by-HVG values; prespecify fewer HVGs or use a smaller cohort.")
    if a["hvg-batch-col"]:
        S.require_columns(adata.obs, [a["hvg-batch-col"]])
    raw = S.layer(adata, a["counts-layer"], counts=True)
    if np.any(np.asarray(raw.sum(axis=1)).ravel() == 0):
        raise OmicstatError("OS_INVALID_INPUT", "zero-library cells must be removed by scanpy-qc first.")
    adata.X = raw.copy()
    adata.layers["counts"] = raw.copy()
    sc.pp.normalize_total(adata=adata, target_sum=a["target-sum"], exclude_highly_expressed=options['normalize-exclude-highly-expressed'],
                          max_fraction=options['normalize-max-fraction'], key_added="omicstat_size_factor", layer=None, obsm=None, inplace=True, copy=False)
    sc.pp.log1p(adata, base=options['log1p-base'], copy=False, chunked=None, chunk_size=None, layer=None, obsm=None)
    adata.layers["logcounts"] = adata.X.copy()
    sc.pp.highly_variable_genes(adata=adata, layer=None, n_top_genes=a["n-hvg"], min_disp=0.5, max_disp=np.inf,
                               min_mean=0.0125, max_mean=3.0, span=options['hvg-span'], n_bins=options['hvg-n-bins'], flavor=options['hvg-flavor'],
                               subset=False, inplace=True, batch_key=a["hvg-batch-col"], filter_unexpressed_genes=None, check_values=True)
    if int(adata.var["highly_variable"].sum()) <= a["n-pcs"]:
        raise OmicstatError("OS_NUMERICAL_DEGENERACY", "too few variable genes for the requested PCA.")
    work = adata[:, adata.var["highly_variable"].to_numpy()].copy()
    if a["scale"] == "on":
        sc.pp.scale(work, zero_center=options['scale-zero-center'], max_value=a["scale-max"], copy=False, layer=None, obsm=None, mask_obs=None)
    sc.pp.pca(data=work, n_comps=a["n-pcs"], zero_center=options['pca-zero-center'], svd_solver=options['pca-svd-solver'], random_state=a["seed"],
              return_info=False, mask_var=None, use_highly_variable=None, dtype=options['pca-dtype'], copy=False,
              chunked=False, chunk_size=None, layer=None, obsm=None, key_added=None)
    scores, loadings = S.canonical_pca(work.obsm["X_pca"], work.varm["PCs"])
    adata.obsm["X_pca"] = scores
    adata.varm["PCs"] = np.zeros((adata.n_vars, a["n-pcs"]), dtype=loadings.dtype)
    adata.varm["PCs"][adata.var["highly_variable"].to_numpy()] = loadings
    adata.uns["pca"] = work.uns["pca"]
    sc.pp.neighbors(adata=adata, n_neighbors=a["n-neighbors"], n_pcs=a["n-pcs"], distances=None, use_rep="X_pca", knn=True,
                    method=options['neighbors-method'], transformer=options['neighbors-transformer'], metric=options['neighbors-metric'], metric_kwds=options['neighbors-metric-kwds'], random_state=a["seed"],
                    key_added=None, copy=False)
    sc.tl.leiden(adata=adata, resolution=a["resolution"], restrict_to=None, random_state=a["seed"],
                 key_added=a["cluster-col"], adjacency=None, directed=False, use_weights=options['leiden-use-weights'], n_iterations=options['leiden-n-iterations'],
                 partition_type=options['leiden-partition-type'], neighbors_key=None, obsp=None, copy=False, flavor=a["leiden-flavor"])
    stable, mapping = S.canonical_clusters(adata.obs[a["cluster-col"]])
    adata.obs[a["cluster-col"]] = stable
    sc.tl.umap(adata=adata, min_dist=a["min-dist"], spread=options['umap-spread'], n_components=2, maxiter=options['umap-maxiter'],
               alpha=options['umap-alpha'], gamma=options['umap-gamma'], negative_sample_rate=options['umap-negative-sample-rate'], init_pos=options['umap-init-pos'], random_state=a["seed"],
               a=options['umap-a'], b=options['umap-b'], method="umap", neighbors_key=None, key_added=None, copy=False)
    cells = S.embedding_frame(adata, a["cluster-col"])
    cells[a["sample-col"]] = adata.obs[a["sample-col"]].astype(str).to_numpy()
    hvg = adata.var.reset_index(names="feature_id")
    pca = pd.DataFrame(scores, columns=["PC%d" % (i+1) for i in range(scores.shape[1])])
    pca.insert(0, "cell", adata.obs_names.astype(str))
    variance = pd.DataFrame({"component": range(1, scores.shape[1]+1), "variance_ratio": adata.uns["pca"]["variance_ratio"]})
    return {"adata": adata, "tables": {"cell_metadata": cells, "variable_genes": hvg, "pca": pca, "pca_variance": variance},
            "summary": {"native_options": N.serializable(options), "n_hvg": int(work.n_vars), "n_pcs": a["n-pcs"], "n_clusters": len(mapping),
                        "cluster_mapping": mapping, "normalization": "normalize_total followed by log1p", "scaled": a["scale"] == "on"},
            "state": {"normalized": "normalize_total_log1p", "normalized_layer": "logcounts", "raw_counts_layer": "counts",
                      "clusters": a["cluster-col"], "reduction": "X_umap", "batch_corrected_lineage": False}}
