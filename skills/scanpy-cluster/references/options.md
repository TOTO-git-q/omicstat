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
| `--counts-layer` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--seed` | 20260925 | no | `none` |
| `--journal` | 'nature' | no | `none` |
| `--n-hvg` | no scientific default; consult L1 tutorial example; clustering tutorial Cell 27: 2000 | yes | `n_top_genes` |
| `--n-pcs` | no scientific default; consult L1 tutorial example | yes | `n_pcs` |
| `--n-neighbors` | no scientific default; consult L1 tutorial example | yes | `n_neighbors` |
| `--resolution` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--cluster-col` | 'cluster' | no | `none` |
| `--target-sum` | None | no | `target_sum` |
| `--hvg-batch-col` | None | no | `batch_key` |
| `--scale-max` | None | no | `none` |
| `--min-dist` | 0.5 | no | `none` |
| `--help` | None | no | `none` |
| `--normalize-exclude-highly-expressed` | `off` (sc.pp.normalize_total.exclude_highly_expressed; boolean; on\|off) | no | `exclude_highly_expressed` |
| `--normalize-max-fraction` | `0.05` (sc.pp.normalize_total.max_fraction; value) | no | `max_fraction` |
| `--log1p-base` | `None` (sc.pp.log1p.base; value) | no | `base` |
| `--hvg-span` | `0.3` (sc.pp.highly_variable_genes.span; value) | no | `hvg_span` |
| `--hvg-n-bins` | `20` (sc.pp.highly_variable_genes.n_bins; value) | no | `hvg_n_bins` |
| `--hvg-flavor` | `seurat` (sc.pp.highly_variable_genes.flavor; value; seurat\|cell_ranger\|seurat_v3\|seurat_v3_paper) | no | `hvg_flavor` |
| `--scale-zero-center` | `on` (sc.pp.scale.zero_center; boolean; on\|off) | no | `none` |
| `--pca-zero-center` | `on` (sc.pp.pca.zero_center; boolean; on\|off) | no | `zero_center` |
| `--pca-svd-solver` | `none` (sc.pp.pca.svd_solver; value; none\|arpack\|auto\|full\|randomized\|covariance_eigh) | no | `svd_solver` |
| `--pca-dtype` | `float32` (sc.pp.pca.dtype; value; float32\|float64) | no | `pca_dtype` |
| `--neighbors-method` | `umap` (sc.pp.neighbors.method; value) | no | `neighbors_method` |
| `--neighbors-transformer` | `none` (sc.pp.neighbors.transformer; nullable_string; none\|pynndescent\|sklearn) | no | `neighbors_transformer` |
| `--neighbors-metric` | `None` (sc.pp.neighbors.metric; value) | no | `metric` |
| `--neighbors-metric-kwds` | `{}` (sc.pp.neighbors.metric_kwds; object) | no | `neighbors_metric_kwds` |
| `--leiden-use-weights` | `on` (sc.tl.leiden.use_weights; boolean; on\|off) | no | `leiden_use_weights` |
| `--leiden-n-iterations` | `-1` (sc.tl.leiden.n_iterations; value) | no | `leiden_n_iterations` |
| `--leiden-partition-type` | `none` (sc.tl.leiden.partition_type; partition; none\|RBConfigurationVertexPartition\|CPMVertexPartition\|ModularityVertexPartition\|RBERVertexPartition\|SignificanceVertexPartition\|SurpriseVertexPartition) | no | `leiden_partition_type` |
| `--umap-spread` | `1.0` (sc.tl.umap.spread; value) | no | `umap_spread` |
| `--umap-maxiter` | `None` (sc.tl.umap.maxiter; value) | no | `umap_maxiter` |
| `--umap-alpha` | `1.0` (sc.tl.umap.alpha; value) | no | `umap_alpha` |
| `--umap-gamma` | `1.0` (sc.tl.umap.gamma; value) | no | `umap_gamma` |
| `--umap-negative-sample-rate` | `5` (sc.tl.umap.negative_sample_rate; value) | no | `umap_negative_sample_rate` |
| `--umap-init-pos` | `spectral` (sc.tl.umap.init_pos; value) | no | `umap_init_pos` |
| `--umap-a` | `None` (sc.tl.umap.a; value) | no | `umap_a` |
| `--umap-b` | `None` (sc.tl.umap.b; value) | no | `umap_b` |
| `--scale` | `off` (cited clustering tutorial; `on` selects scaling) | no | `none` |

Structured options accept JSON objects/lists, not Python expressions. `--groups` accepts `all` or a JSON list of cluster names; `--mask-var` names a Boolean var column. Optional numeric values omitted mean the locked `None`. Boolean options use `on`/`off` (and `none` where the API allows it). Partition types name supported leidenalg classes and require a compatible native Leiden implementation. Actual converted native arguments are recorded in the result summary and Methods.

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--leiden-flavor` | `igraph` (retained tutorial branch); `leidenalg` for partition-type | no | `leiden_flavor` |

Scaling is disabled on the cited clustering tutorial path. Select `--scale on` to reproduce the previous scaled workflow; `--scale-zero-center` and `--scale-max` apply only on that branch. PCA signs and cluster labels retain the suite canonicalization; native partitions and graphs are verified independently. `seurat_v3` / `seurat_v3_paper` use the preserved raw counts layer; `seurat` / `cell_ranger` use log-normalized expression, as required by the native API.
