# Option evidence mapping

Locked defaults are captured in `scripts/calls_registry.json`; tutorial examples are context, not universal scientific choices. Required values are chosen explicitly. See the frozen L1 tutorial and `parameters.md` for meaning and allowed values.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | None | no | `none` |
| `--from-run` | None | no | `none` |
| `--upstream-object` | None | no | `none` |
| `--outdir` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--spec` | None | no | `none` |
| `--study-contract` | None | no | `none` |
| `--species` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--annotation` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--sample-col` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--counts-layer` | no scientific default; consult L1 tutorial example | yes | `layer` |
| `--seed` | 20260925 | no | `seed` |
| `--journal` | 'nature' | no | `none` |
| `--batch-col` | no scientific default; consult L1 tutorial example | yes | `batch_key` |
| `--cluster-col` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--max-epochs` | no scientific default; consult L1 tutorial example | yes | `max_epochs` |
| `--n-neighbors` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--n-latent` | 10 | no | `n_latent` |
| `--batch-size` | 128 | no | `batch_size` |
| `--min-dist` | 0.5 | no | `none` |
| `--features-file` | None | no | `none` |
| `--help` | None | no | `none` |
| `--size-factor-key` | `None` (scvi.model.SCVI.setup_anndata.size_factor_key; value) | no | `size_factor_key` |
| `--categorical-covariate-keys` | `None` (scvi.model.SCVI.setup_anndata.categorical_covariate_keys; list) | no | `categorical_covariate_keys` |
| `--continuous-covariate-keys` | `None` (scvi.model.SCVI.setup_anndata.continuous_covariate_keys; list) | no | `continuous_covariate_keys` |
| `--n-hidden` | `128` (scvi.model.SCVI.n_hidden; value) | no | `n_hidden` |
| `--n-layers` | `1` (scvi.model.SCVI.n_layers; value) | no | `n_layers` |
| `--dropout-rate` | `0.1` (scvi.model.SCVI.dropout_rate; value) | no | `dropout_rate` |
| `--dispersion` | `gene` (scvi.model.SCVI.dispersion; value; gene\|gene-batch\|gene-label\|gene-cell) | no | `dispersion` |
| `--gene-likelihood` | `zinb` (scvi.model.SCVI.gene_likelihood; value; zinb\|nb\|poisson\|normal) | no | `gene_likelihood` |
| `--use-observed-lib-size` | `on` (scvi.model.SCVI.use_observed_lib_size; boolean; on\|off) | no | `use_observed_lib_size` |
| `--latent-distribution` | `normal` (scvi.model.SCVI.latent_distribution; value; normal\|ln) | no | `latent_distribution` |
| `--train-size` | `None` (model.train.train_size; value) | no | `train_size` |
| `--validation-size` | `None` (model.train.validation_size; value) | no | `validation_size` |
| `--shuffle-set-split` | `on` (model.train.shuffle_set_split; boolean; on\|off) | no | `shuffle_set_split` |
| `--early-stopping` | `off` (model.train.early_stopping; boolean; on\|off) | no | `early_stopping` |
| `--datasplitter-kwargs` | `None` (model.train.datasplitter_kwargs; object) | no | `datasplitter_kwargs` |
| `--plan-kwargs` | `None` (model.train.plan_kwargs; object) | no | `plan_kwargs` |
| `--neighbors-method` | `umap` (sc.pp.neighbors.method; value) | no | `none` |
| `--neighbors-transformer` | `none` (sc.pp.neighbors.transformer; nullable_string; none\|pynndescent\|sklearn) | no | `none` |
| `--neighbors-metric` | `None` (sc.pp.neighbors.metric; value) | no | `none` |
| `--neighbors-metric-kwds` | `{}` (sc.pp.neighbors.metric_kwds; object) | no | `none` |
| `--umap-spread` | `1.0` (sc.tl.umap.spread; value) | no | `none` |
| `--umap-maxiter` | `None` (sc.tl.umap.maxiter; value) | no | `none` |
| `--umap-alpha` | `1.0` (sc.tl.umap.alpha; value) | no | `none` |
| `--umap-gamma` | `1.0` (sc.tl.umap.gamma; value) | no | `none` |
| `--umap-negative-sample-rate` | `5` (sc.tl.umap.negative_sample_rate; value) | no | `none` |
| `--umap-init-pos` | `spectral` (sc.tl.umap.init_pos; value) | no | `none` |
| `--umap-a` | `None` (sc.tl.umap.a; value) | no | `none` |
| `--umap-b` | `None` (sc.tl.umap.b; value) | no | `none` |

Structured options accept JSON objects/lists, not Python expressions. `--groups` accepts `all` or a JSON list of cluster names; `--mask-var` names a Boolean var column. Optional numeric values omitted mean the locked `None`. Boolean options use `on`/`off` (and `none` where the API allows it). Partition types name supported leidenalg classes and require a compatible native Leiden implementation. Actual converted native arguments are recorded in the result summary and Methods.
