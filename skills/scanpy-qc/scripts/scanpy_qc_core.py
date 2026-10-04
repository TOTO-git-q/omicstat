"""Raw-count QC and an explicit, auditable cell/gene selection (scanpy)."""
from ospy import sc_module as S, native_options as N
from ospy.errors import OmicstatError

MODULE_VERSION = "1.0.0"


def validate(a):
    if a["min-genes"] > a["max-genes"] or a["min-counts"] > a["max-counts"]:
        raise OmicstatError("OS_INVALID_PARAMETER", "minimum QC thresholds cannot exceed maxima.")
    if a["doublet-mode"] != "skip" and (a["expected-doublet-rate"] is None or a["doublet-threshold"] is None):
        raise OmicstatError("OS_OWNER_DECISION_PENDING", "doublet scoring/filtering requires explicit --expected-doublet-rate and --doublet-threshold.")
    if a["doublet-mode"] == "skip" and (a["expected-doublet-rate"] is not None or a["doublet-threshold"] is not None):
        raise OmicstatError("OS_CONFLICTING_PARAMETERS", "doublet parameters have no effect with --doublet-mode skip.")


def compute(adata, a, upstream):
    options = N.resolve(a, {'sim-doublet-ratio': 'value', 'stdev-doublet-rate': 'value', 'synthetic-doublet-umi-subsampling': 'value', 'knn-dist-metric': 'value', 'normalize-variance': 'boolean', 'log-transform': 'boolean', 'mean-center': 'boolean', 'use-approx-neighbors': 'boolean', 'n-neighbors': 'value'})
    import numpy as np
    import pandas as pd
    import scanpy as sc
    raw = S.layer(adata, a["counts-layer"], counts=True)
    adata.X = raw.copy()
    adata.layers["counts"] = raw.copy()
    adata.var["mito"] = adata.var_names.str.startswith(a["mito-prefix"])
    # percent_top=None is the official PBMC workflow's choice, not a QC cutoff.
    sc.pp.calculate_qc_metrics(adata=adata, expr_type="counts", var_type="genes", qc_vars=["mito"],
                               percent_top=None, layer="counts", use_raw=False, inplace=True, log1p=True, parallel=None)
    min_genes, _ = sc.pp.filter_cells(data=adata, min_counts=None, min_genes=a["min-genes"],
                                    max_counts=None, max_genes=None, inplace=False, copy=False)
    min_counts, _ = sc.pp.filter_cells(data=adata, min_counts=a["min-counts"], min_genes=None,
                                     max_counts=None, max_genes=None, inplace=False, copy=False)
    obs = adata.obs
    failures = pd.DataFrame({"below_min_genes": ~min_genes, "above_max_genes": obs["n_genes_by_counts"].to_numpy() > a["max-genes"],
                             "below_min_counts": ~min_counts, "above_max_counts": obs["total_counts"].to_numpy() > a["max-counts"],
                             "above_mito_percent": obs["pct_counts_mito"].fillna(100).to_numpy() > a["max-mito-percent"]}, index=adata.obs_names)
    keep = ~failures.any(axis=1).to_numpy()
    if keep.sum() < 2:
        raise OmicstatError("OS_EMPTY_DATA", "QC leaves fewer than two cells; inspect explicit thresholds.")
    selected = adata[keep, :].copy()
    gene_keep, gene_ncells = sc.pp.filter_genes(data=selected, min_counts=None, min_cells=a["min-cells"],
                                              max_counts=None, max_cells=None, inplace=False, copy=False)
    if gene_keep.sum() < 2:
        raise OmicstatError("OS_EMPTY_DATA", "gene filtering leaves fewer than two genes.")
    selected = selected[:, gene_keep].copy()
    doublet_score = pd.Series(np.nan, index=adata.obs_names, dtype=float)
    predicted = pd.Series(False, index=adata.obs_names, dtype=bool)
    if a["doublet-mode"] != "skip":
        if min(selected.shape) <= a["scrublet-pcs"]:
            raise OmicstatError("OS_INVALID_PARAMETER", "--scrublet-pcs must be below both retained dimensions.")
        sc.pp.scrublet(adata=selected, adata_sim=None, batch_key=a["sample-col"],
                      sim_doublet_ratio=options['sim-doublet-ratio'], expected_doublet_rate=a["expected-doublet-rate"], stdev_doublet_rate=options['stdev-doublet-rate'],
                      synthetic_doublet_umi_subsampling=options['synthetic-doublet-umi-subsampling'], knn_dist_metric=options['knn-dist-metric'], normalize_variance=options['normalize-variance'],
                      log_transform=options['log-transform'], mean_center=options['mean-center'], n_prin_comps=a["scrublet-pcs"], use_approx_neighbors=options['use-approx-neighbors'],
                      get_doublet_neighbor_parents=False, n_neighbors=options['n-neighbors'], threshold=a["doublet-threshold"],
                      verbose=False, copy=False, random_state=a["seed"])
        doublet_score.loc[selected.obs_names] = selected.obs["doublet_score"].to_numpy()
        predicted.loc[selected.obs_names] = selected.obs["predicted_doublet"].to_numpy()
        if a["doublet-mode"] == "filter":
            selected = selected[~selected.obs["predicted_doublet"].to_numpy(), :].copy()
            if selected.n_obs < 2:
                raise OmicstatError("OS_EMPTY_DATA", "doublet filtering leaves fewer than two cells.")
    # Keep the exact per-cell prefilter metrics, including overlapping failure reasons.
    audit = obs[[a["sample-col"], "n_genes_by_counts", "total_counts", "pct_counts_mito"]].copy()
    audit.insert(0, "cell", adata.obs_names.astype(str))
    for column in failures:
        audit[column] = failures[column].to_numpy()
    audit["doublet_score"] = doublet_score.to_numpy()
    audit["predicted_doublet"] = predicted.to_numpy()
    audit["retained"] = adata.obs_names.isin(selected.obs_names)
    gene_audit = pd.DataFrame({"feature_id": adata.var_names.astype(str), "n_cells_before_doublet_filter": gene_ncells,
                               "retained": gene_keep})
    flow = pd.DataFrame({"stage": ["input", "cell_qc", "gene_qc", "doublet_filter"],
                          "n_cells": [adata.n_obs, int(keep.sum()), int(keep.sum()), selected.n_obs],
                          "n_genes": [adata.n_vars, adata.n_vars, int(gene_keep.sum()), selected.n_vars]})
    return {"adata": selected, "tables": {"cell_qc": audit, "gene_qc": gene_audit, "filter_flow": flow},
            "summary": {"native_options": N.serializable(options), "n_input_cells": int(adata.n_obs), "n_input_genes": int(adata.n_vars),
                        "n_removed_cells": int(adata.n_obs - selected.n_obs), "n_mito_genes": int(adata.var["mito"].sum()),
                        "n_predicted_doublets": int(predicted.sum()), "doublet_mode": a["doublet-mode"]},
            "state": {"qc_complete": True, "normalized": False, "raw_counts_layer": "counts",
                      "doublet_handling": a["doublet-mode"], "batch_corrected_lineage": False}}
