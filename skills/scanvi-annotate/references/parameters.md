# Parameters

Generated from the entry SPEC and explicit calls registry. Do not edit table cells by hand.

Policy: function defaults from the locked version; official tutorial departures are named below. Scientific choices without a package recommendation are required. No literature-majority claim is made.

| Flag | Default | Allowed | Meaning |
|---|---|---|---|
| `--input` | `none` | path | local AnnData .h5ad file; never downloaded |
| `--from-run` | `none` | path | verified upstream run; exclusive with --input |
| `--upstream-object` | `none` | string | name of the upstream AnnData when more than one exists |
| `--outdir` | `required` | path | new output directory |
| `--spec` | `none` | path | replay provenance/resolved_spec.json |
| `--study-contract` | `none` | path | local StudyContract JSON; must match the upstream hash |
| `--species` | `required` | string | declared organism; not inferred from identifiers |
| `--annotation` | `required` | string | declared feature annotation release |
| `--sample-col` | `required` | string | obs column identifying biological samples |
| `--counts-layer` | `required` | string | raw integer count layer; use X explicitly for .X |
| `--seed` | `20260925` | (0, 2147483647) | fixed random seed |
| `--journal` | `"nature"` | nature, cell, science, generic | shared R figure preset |
| `--labels-col` | `required` | string | reference labels with an explicit unlabeled category |
| `--unlabeled-category` | `required` | string | exact label reserved for query cells |
| `--cluster-col` | `required` | string | existing cluster column for crosstab |
| `--prediction-col` | `"scanvi_label"` | string | new annotation column; observed labels are not overwritten |
| `--max-epochs` | `required` | (1, 400) | explicit CPU training budget |
| `--samples-per-label` | `none` | (1, 100000) | optional label subsampling count; omitted means no subsampling |
| `--batch-size` | `128` | (2, 4096) | training and inference minibatch size |
| `--min-confidence` | `required` | (0, 1) | explicit display/QC probability cutoff; labels are still retained |
| `--help` | `none` | bool | show this help and exit |

## Explicit package calls

| Function | Explicit arguments |
|---|---|
| `scvi.model.SCVI.load` | `dir_path`, `adata`, `accelerator`, `device`, `prefix`, `backup_url`, `datamodule`, `allowed_classes_names_list` |
| `scvi.model.SCANVI.from_scvi_model` | `scvi_model`, `unlabeled_category`, `labels_key`, `adata`, `registry` |
| `scvi.model.SCANVI.train` | `max_epochs`, `n_samples_per_label`, `check_val_every_n_epoch`, `train_size`, `validation_size`, `shuffle_set_split`, `batch_size`, `accelerator`, `devices`, `adversarial_classifier`, `datasplitter_kwargs`, `plan_config`, `plan_kwargs`, `datamodule`, `trainer_config`, `deterministic`, `enable_progress_bar`, `enable_checkpointing`, `logger`, `num_sanity_val_steps` |
| `scvi.model.SCANVI.predict` | `adata`, `indices`, `soft`, `batch_size`, `use_posterior_mean`, `ig_interpretability`, `ig_args`, `dataloader` |

Every call expression is retained in calls_registry.json. Locked default-formal capture and drift checking remain mandatory; an API-doc URL is not a substitute for execution in the pinned image.
