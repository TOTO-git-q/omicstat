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
| `--batch-col` | `required` | string | nuisance batch variable; not an unexamined biological condition |
| `--cluster-col` | `required` | string | existing descriptive cluster metadata |
| `--max-epochs` | `required` | (1, 400) | explicit CPU training budget |
| `--n-neighbors` | `required` | (2, 1000) | explicit neighbors for latent-space graph |
| `--n-latent` | `none` | (2, 1000) | scVI latent dimension; required unless --latent-from-run (reuse trains no model) |
| `--batch-size` | `128` | (2, 4096) | training and inference minibatch size |
| `--min-dist` | `0.5` | (0, 1) | UMAP minimum distance |
| `--features-file` | `none` | path | optional prespecified ordered gene subset (one ID per line); otherwise all genes |
| `--help` | `none` | bool | show this help and exit |

## Explicit package calls

| Function | Explicit arguments |
|---|---|
| `scvi.model.SCVI.setup_anndata` | `adata`, `batch_key`, `categorical_covariate_keys`, `continuous_covariate_keys`, `labels_key`, `layer`, `size_factor_key` |
| `scvi.model.SCVI` | `adata`, `dispersion`, `dropout_rate`, `gene_likelihood`, `latent_distribution`, `n_hidden`, `n_latent`, `n_layers`, `registry`, `use_observed_lib_size` |
| `scvi.model.SCVI.train` | `accelerator`, `batch_size`, `check_val_every_n_epoch`, `datamodule`, `datasplitter_kwargs`, `deterministic`, `devices`, `early_stopping`, `enable_checkpointing`, `enable_progress_bar`, `load_sparse_tensor`, `logger`, `max_epochs`, `num_sanity_val_steps`, `plan_config`, `plan_kwargs`, `shuffle_set_split`, `train_size`, `trainer_config`, `validation_size` |
| `scvi.model.SCVI.get_latent_representation` | `adata`, `batch_size`, `dataloader`, `give_mean`, `indices`, `mc_samples`, `return_dist` |
| `scanpy.pp.neighbors` | `adata`, `copy`, `distances`, `key_added`, `knn`, `method`, `metric`, `metric_kwds`, `n_neighbors`, `n_pcs`, `random_state`, `transformer`, `use_rep` |
| `scanpy.tl.umap` | `a`, `adata`, `alpha`, `b`, `copy`, `gamma`, `init_pos`, `key_added`, `maxiter`, `method`, `min_dist`, `n_components`, `negative_sample_rate`, `neighbors_key`, `random_state`, `spread` |

Every call expression is retained in calls_registry.json. Locked default-formal capture and drift checking remain mandatory; an API-doc URL is not a substitute for execution in the pinned image.

`model.history.items()` reads the trained history dictionary; it is an accessor, not a class-level statistical API with formals.
