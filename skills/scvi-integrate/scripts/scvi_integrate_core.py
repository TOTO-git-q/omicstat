"""CPU scVI latent integration; raw counts and original cluster labels survive."""
from pathlib import Path
from ospy import sc_module as S, native_options as N
from ospy.errors import OmicstatError

MODULE_VERSION = "1.1.0"


def validate(a):
    if bool(a["leiden-resolution"]) != bool(a["scvi-cluster-col"]):
        raise OmicstatError("OS_MISSING_PARAMETER", "supply --leiden-resolution and --scvi-cluster-col together.")
    if a["scvi-cluster-col"] == a["cluster-col"]:
        raise OmicstatError("OS_INVALID_PARAMETER", "scvi-cluster-col must be a new column; carried clusters cannot change.")
    if a["max-epochs"] > 400:
        raise OmicstatError("OS_RESOURCE_LIMIT", "this synchronous CPU module supports at most 400 requested epochs.")


def compute(adata, a, upstream):
    options = N.resolve(a, {'size-factor-key': 'value', 'categorical-covariate-keys': 'list', 'continuous-covariate-keys': 'list', 'n-hidden': 'value', 'n-layers': 'value', 'dropout-rate': 'value', 'dispersion': 'value', 'gene-likelihood': 'value', 'use-observed-lib-size': 'boolean', 'latent-distribution': 'value', 'train-size': 'value', 'validation-size': 'value', 'shuffle-set-split': 'boolean', 'early-stopping': 'boolean', 'datasplitter-kwargs': 'object', 'plan-kwargs': 'object', 'neighbors-method': 'value', 'neighbors-transformer': 'nullable_string', 'neighbors-metric': 'value', 'neighbors-metric-kwds': 'object', 'umap-spread': 'value', 'umap-maxiter': 'value', 'umap-alpha': 'value', 'umap-gamma': 'value', 'umap-negative-sample-rate': 'value', 'umap-init-pos': 'value', 'umap-a': 'value', 'umap-b': 'value'})
    import numpy as np
    import pandas as pd
    import scanpy as sc
    import scvi
    S.require_columns(adata.obs, [a["batch-col"], a["cluster-col"]])
    if adata.n_obs > 20000:
        raise OmicstatError("OS_RESOURCE_LIMIT", "this CPU lane accepts at most 20000 cells; larger runs require an owner-approved execution plan.")
    if adata.obs[a["batch-col"]].nunique() < 2:
        raise OmicstatError("OS_INVALID_DESIGN", "integration requires at least two explicitly declared batches.")
    if a["n-neighbors"] >= adata.n_obs:
        raise OmicstatError("OS_INVALID_PARAMETER", "--n-neighbors must be smaller than the number of cells.")
    before = S.embedding_frame(adata, a["batch-col"])
    if "connectivities" not in adata.obsp:
        raise OmicstatError("OS_MISSING_REDUCTION", "run scanpy-cluster first; uncorrected connectivities are required for paired diagnostics.")
    raw = S.layer(adata, a["counts-layer"], counts=True)
    adata.layers["counts"] = raw.copy()
    original_clusters = adata.obs[a["cluster-col"]].copy()
    model_data = adata
    if a["features-file"]:
        features = [x.strip() for x in Path(a["features-file"]).read_text().splitlines() if x.strip()]
        if len(features) < 2 or len(set(features)) != len(features) or not set(features).issubset(set(adata.var_names)):
            raise OmicstatError("OS_INVALID_INPUT", "features-file must name at least two unique, observed genes.")
        model_data = adata[:, features].copy()
    model = None
    reuse_state = {}
    if a["latent-from-run"]:
        from ospy.display import read_run
        previous, latent_handoff = read_run(a["latent-from-run"])
        if latent_handoff["module"] != "scvi-integrate":
            raise OmicstatError("OS_HANDOFF_MISMATCH", "latent-from-run must be a scvi-integrate run.")
        latent_state = latent_handoff.get("state", {})
        for key in ("species", "annotation"):
            if latent_state.get(key) not in (None, a.get(key)):
                raise OmicstatError("OS_HANDOFF_MISMATCH", "latent-from-run metadata differs: " + key)
        if latent_state.get("display_only") is True:
            reuse_state["display_only"] = True
        if not set(adata.obs_names).issubset(set(previous.obs_names)):
            raise OmicstatError("OS_CELL_MISMATCH", "input cells must match or be a subset of latent-from-run.")
        if "X_scVI" not in previous.obsm:
            raise OmicstatError("OS_MISSING_REDUCTION", "latent-from-run has no X_scVI.")
        latent = np.asarray(previous[adata.obs_names].obsm["X_scVI"]).copy()
    else:
        # Locked constructor defaults remain explicit options alongside covariates, training and feature choices.
        scvi.model.SCVI.setup_anndata(adata=model_data, layer="counts", batch_key=a["batch-col"], labels_key=None,
                                      size_factor_key=options['size-factor-key'], categorical_covariate_keys=options['categorical-covariate-keys'], continuous_covariate_keys=options['continuous-covariate-keys'])
        model = scvi.model.SCVI(adata=model_data, registry=None, n_hidden=options['n-hidden'], n_latent=a["n-latent"], n_layers=options['n-layers'],
                                dropout_rate=options['dropout-rate'], dispersion=options['dispersion'], gene_likelihood=options['gene-likelihood'], use_observed_lib_size=options['use-observed-lib-size'],
                                latent_distribution=options['latent-distribution'])
        model.train(max_epochs=a["max-epochs"], accelerator="cpu", devices=1, train_size=options['train-size'], validation_size=options['validation-size'],
                    shuffle_set_split=options['shuffle-set-split'], load_sparse_tensor=False, batch_size=a["batch-size"], early_stopping=options['early-stopping'],
                    datasplitter_kwargs=options['datasplitter-kwargs'], plan_config=None, plan_kwargs=options['plan-kwargs'], datamodule=None, trainer_config=None,
                    deterministic=True, enable_progress_bar=False, enable_checkpointing=False, logger=None,
                    check_val_every_n_epoch=1, num_sanity_val_steps=0)
        latent = model.get_latent_representation(adata=model_data, indices=None, give_mean=True, mc_samples=5000,
                                                  batch_size=a["batch-size"], return_dist=False, dataloader=None)
    if not np.isfinite(latent).all():
        raise OmicstatError("OS_NUMERICAL_DEGENERACY", "scVI returned nonfinite latent coordinates.")
    adata.obsm["X_scVI"] = latent
    adata.obsm["X_umap_uncorrected"] = adata.obsm["X_umap"].copy()
    sc.pp.neighbors(adata=adata, n_neighbors=a["n-neighbors"], n_pcs=None, distances=None, use_rep="X_scVI", knn=True,
                    method=options['neighbors-method'], transformer=options['neighbors-transformer'], metric=options['neighbors-metric'], metric_kwds=options['neighbors-metric-kwds'], random_state=a["seed"],
                    key_added="scvi_neighbors", copy=False)
    sc.tl.umap(adata=adata, min_dist=a["min-dist"], spread=options['umap-spread'], n_components=2, maxiter=options['umap-maxiter'],
               alpha=options['umap-alpha'], gamma=options['umap-gamma'], negative_sample_rate=options['umap-negative-sample-rate'], init_pos=options['umap-init-pos'], random_state=a["seed"],
               a=options['umap-a'], b=options['umap-b'], method="umap", neighbors_key="scvi_neighbors", key_added=None, copy=False)
    if a["leiden-resolution"] is not None:
        if a["scvi-cluster-col"] in adata.obs:
            raise OmicstatError("OS_INVALID_PARAMETER", "scvi-cluster-col already exists; choose a new column.")
        sc.tl.leiden(adata=adata, resolution=a["leiden-resolution"], restrict_to=None, random_state=a["seed"],
                     key_added=a["scvi-cluster-col"], adjacency=None, directed=False, use_weights=True, n_iterations=-1,
                     partition_type=None, neighbors_key="scvi_neighbors", obsp=None, copy=False, flavor="igraph")
    if not adata.obs[a["cluster-col"]].equals(original_clusters):
        raise OmicstatError("OS_RESULT_INCONSISTENT", "integration must not change cluster labels.")
    after = S.embedding_frame(adata, a["batch-col"])
    before["stage"], after["stage"] = "before", "after"
    diagnostics = []
    for stage, key in [("before", "connectivities"), ("after", "scvi_neighbors_connectivities")]:
        frame = S.batch_mixing(adata.obsp[key], adata.obs[a["batch-col"]])
        frame.insert(0, "cell", adata.obs_names.astype(str))
        frame["stage"] = stage
        diagnostics.append(frame)
    latent_table = pd.DataFrame(latent, columns=["latent_%d" % (i+1) for i in range(latent.shape[1])])
    latent_table.insert(0, "cell", adata.obs_names.astype(str))
    files, history = {}, []
    if model is not None:
        destination = Path(a["outdir"]) / "objects/scvi_model"
        model.save(dir_path=str(destination), prefix=None, overwrite=False, save_anndata=False)
        feature_path = destination / "omicstat_features.txt"
        feature_path.write_text("\n".join(model_data.var_names.astype(str)) + "\n", encoding="utf-8")
        files = {"scvi_"+p.name.replace(".", "_"): str(p) for p in sorted(destination.iterdir()) if p.is_file()}
        for metric, frame in model.history.items():
            if hasattr(frame, "columns"):
                for epoch, row in frame.iterrows():
                    for column, value in row.items():
                        history.append({"metric": str(metric), "series": str(column), "epoch": int(epoch), "value": float(value)})
    return {"adata": adata, "tables": {"latent_coordinates": latent_table, "embedding_comparison": pd.concat([before, after], ignore_index=True),
                                        "batch_mixing": pd.concat(diagnostics, ignore_index=True), "training_history": pd.DataFrame(history, columns=["metric", "series", "epoch", "value"])},
            "model_files": files,
            "summary": {"native_options": N.serializable(options), "n_batches": int(adata.obs[a["batch-col"]].nunique()), "n_model_genes": int(model_data.n_vars) if model is not None else None,
                        "n_latent": int(latent.shape[1]), "max_epochs": a["max-epochs"], "batch_key": a["batch-col"],
                        "latent_reused": bool(a["latent-from-run"]), "expression_corrected": False, "cluster_labels_changed": False},
            "state": {**reuse_state, "integration": "scVI", "integrated_embedding": "X_scVI", "batch_col": a["batch-col"],
                      "raw_counts_layer": "counts", "batch_corrected_embedding": True, "batch_corrected_lineage": False,
                      "scvi_model_subdir": "objects/scvi_model" if model is not None else None,
                      "latent_from_run": a["latent-from-run"]}}
