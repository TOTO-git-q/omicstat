"""Semi-supervised label transfer from a verified local scVI model."""
from pathlib import Path
from ospy import sc_module as S, native_options as N
from ospy.errors import OmicstatError

MODULE_VERSION = "1.0.0"


def validate(a):
    if not a["from-run"] or a["input"]:
        raise OmicstatError("OS_MISSING_PARAMETER", "scanvi-annotate requires --from-run scvi-integrate so every model file is hash-verified.")
    if a["labels-col"] == a["prediction-col"]:
        raise OmicstatError("OS_CONFLICTING_PARAMETERS", "prediction column must not overwrite observed labels.")
    if a["max-epochs"] > 400:
        raise OmicstatError("OS_RESOURCE_LIMIT", "this synchronous CPU module supports at most 400 epochs.")


def compute(adata, a, upstream):
    options = N.resolve(a, {'train-size': 'value', 'validation-size': 'value', 'shuffle-set-split': 'boolean', 'adversarial-classifier': 'boolean', 'datasplitter-kwargs': 'object', 'plan-kwargs': 'object', 'use-posterior-mean': 'boolean'})
    import numpy as np
    import pandas as pd
    import scvi
    if not upstream or upstream["module"] != "scvi-integrate":
        raise OmicstatError("OS_HANDOFF_MISMATCH", "upstream must be scvi-integrate, including the trained model.")
    S.require_columns(adata.obs, [a["labels-col"], a["cluster-col"]])
    S.embedding_frame(adata, a["cluster-col"])
    labels = adata.obs[a["labels-col"]].astype(str)
    known = labels != a["unlabeled-category"]
    if not (~known).any() or labels[known].nunique() < 2:
        raise OmicstatError("OS_INVALID_DESIGN", "supply an unlabeled category and at least two observed reference label categories.")
    if labels[known].value_counts().min() < 2:
        raise OmicstatError("OS_INVALID_DESIGN", "every observed label requires at least two reference cells.")
    if adata.n_obs > 20000:
        raise OmicstatError("OS_RESOURCE_LIMIT", "this CPU lane accepts at most 20000 cells.")
    expected_file = upstream["objects"].get("scvi_model_pt")
    feature_file = upstream["objects"].get("scvi_omicstat_features_txt")
    if not expected_file or not feature_file:
        raise OmicstatError("OS_HANDOFF_MISMATCH", "verified scVI model.pt and ordered feature list are missing.")
    features = Path(feature_file["path"]).read_text().splitlines()
    if len(features) != len(set(features)) or not set(features).issubset(adata.var_names):
        raise OmicstatError("OS_HANDOFF_MISMATCH", "model feature identifiers differ from the input.")
    model_data = adata[:, features].copy()
    model_data.layers["counts"] = S.layer(adata, a["counts-layer"], counts=True)[:, adata.var_names.get_indexer(features)].copy()
    base = scvi.model.SCVI.load(dir_path=str(Path(expected_file["path"]).parent), adata=model_data,
                                accelerator="cpu", device="auto", prefix=None, backup_url=None, datamodule=None, allowed_classes_names_list=None)
    model = scvi.model.SCANVI.from_scvi_model(scvi_model=base, unlabeled_category=a["unlabeled-category"],
                                             labels_key=a["labels-col"], adata=model_data, registry=None)
    model.train(max_epochs=a["max-epochs"], n_samples_per_label=a["samples-per-label"], check_val_every_n_epoch=1,
                train_size=options['train-size'], validation_size=options['validation-size'], shuffle_set_split=options['shuffle-set-split'], batch_size=a["batch-size"],
                accelerator="cpu", devices=1, adversarial_classifier=options['adversarial-classifier'], datasplitter_kwargs=options['datasplitter-kwargs'], plan_config=None, plan_kwargs=options['plan-kwargs'],
                datamodule=None, trainer_config=None, deterministic=True, enable_progress_bar=False, enable_checkpointing=False,
                logger=False, num_sanity_val_steps=0)
    probabilities = model.predict(adata=model_data, indices=None, soft=True, batch_size=a["batch-size"],
                                   use_posterior_mean=options['use-posterior-mean'], ig_interpretability=False, ig_args=None, dataloader=None)
    predictions = model.predict(adata=model_data, indices=None, soft=False, batch_size=a["batch-size"],
                                 use_posterior_mean=options['use-posterior-mean'], ig_interpretability=False, ig_args=None, dataloader=None)
    if not isinstance(probabilities, pd.DataFrame) or not probabilities.index.equals(model_data.obs_names):
        raise OmicstatError("OS_RESULT_INCONSISTENT", "prediction probabilities do not preserve cell identifiers.")
    values = probabilities.to_numpy()
    if not np.isfinite(values).all() or np.any(values < 0) or not np.allclose(values.sum(axis=1), 1, rtol=0, atol=1e-5):
        raise OmicstatError("OS_NUMERICAL_DEGENERACY", "invalid classifier probabilities.")
    confidence = values.max(axis=1)
    adata.obs[a["prediction-col"]] = pd.Categorical(np.asarray(predictions).astype(str))
    adata.obs[a["prediction-col"] + "_probability"] = confidence
    cells = pd.DataFrame({"cell": adata.obs_names.astype(str), "observed_label": labels.to_numpy(),
                          "predicted_label": np.asarray(predictions).astype(str), "max_probability": confidence,
                          "below_display_threshold": confidence < a["min-confidence"], "reference_cell": known.to_numpy()})
    probabilities = probabilities.copy()
    probabilities.insert(0, "cell", adata.obs_names.astype(str))
    cross = pd.crosstab(adata.obs[a["cluster-col"]], adata.obs[a["prediction-col"]]).reset_index()
    destination = Path(a["outdir"]) / "objects/scanvi_model"
    model.save(dir_path=str(destination), prefix=None, overwrite=False, save_anndata=False)
    files = {"scanvi_"+p.name.replace(".", "_"): str(p) for p in sorted(destination.iterdir()) if p.is_file()}
    return {"adata": adata, "tables": {"annotations": cells, "label_probabilities": probabilities, "cluster_annotation_crosstab": cross},
            "model_files": files,
            "summary": {"native_options": N.serializable(options), "n_reference_cells": int(known.sum()), "n_query_cells": int((~known).sum()),
                        "n_label_categories": int(labels[known].nunique()), "n_low_confidence": int((confidence < a["min-confidence"]).sum()),
                        "min_confidence": a["min-confidence"], "max_epochs": a["max-epochs"],
                        "probability_interpretation": "uncalibrated model class probability; not validated prediction accuracy"},
            "state": {"annotation": a["annotation"], "label_transfer": "scANVI", "celltype_col": a["prediction-col"],
                      "original_labels_col": a["labels-col"], "batch_corrected_lineage": False}}
