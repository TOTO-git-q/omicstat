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
| `--sample-col` | no scientific default; consult L1 tutorial example | yes | `batch_key` |
| `--counts-layer` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--seed` | 20260925 | no | `none` |
| `--journal` | 'nature' | no | `none` |
| `--mito-prefix` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--min-genes` | no scientific default; consult L1 tutorial example; clustering tutorial filtering example: 100 | yes | `min_genes` |
| `--max-genes` | no scientific default; consult L1 tutorial example | yes | `max_genes` |
| `--min-counts` | no scientific default; consult L1 tutorial example | yes | `min_counts` |
| `--max-counts` | no scientific default; consult L1 tutorial example | yes | `max_counts` |
| `--max-mito-percent` | no scientific default; consult L1 tutorial example | yes | `pct_counts_mt` |
| `--min-cells` | no scientific default; consult L1 tutorial example; clustering tutorial filtering example: 3 | yes | `min_cells` |
| `--doublet-mode` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--expected-doublet-rate` | None | no | `expected_doublet_rate` |
| `--doublet-threshold` | None | no | `none` |
| `--scrublet-pcs` | 30 | no | `n_prin_comps` |
| `--help` | None | no | `none` |
| `--sim-doublet-ratio` | `2.0` (sc.pp.scrublet.sim_doublet_ratio; value) | no | `sim_doublet_ratio` |
| `--stdev-doublet-rate` | `0.02` (sc.pp.scrublet.stdev_doublet_rate; value) | no | `stdev_doublet_rate` |
| `--synthetic-doublet-umi-subsampling` | `1.0` (sc.pp.scrublet.synthetic_doublet_umi_subsampling; value) | no | `synthetic_doublet_umi_subsampling` |
| `--knn-dist-metric` | `euclidean` (sc.pp.scrublet.knn_dist_metric; value) | no | `knn_dist_metric` |
| `--normalize-variance` | `on` (sc.pp.scrublet.normalize_variance; boolean; on\|off) | no | `normalize_variance` |
| `--log-transform` | `off` (sc.pp.scrublet.log_transform; boolean; on\|off) | no | `log_transform` |
| `--mean-center` | `on` (sc.pp.scrublet.mean_center; boolean; on\|off) | no | `mean_center` |
| `--use-approx-neighbors` | `none` (sc.pp.scrublet.use_approx_neighbors; boolean; on\|off\|none) | no | `use_approx_neighbors` |
| `--n-neighbors` | `None` (sc.pp.scrublet.n_neighbors; value) | no | `n_neighbors` |

Structured options accept JSON objects/lists, not Python expressions. `--groups` accepts `all` or a JSON list of cluster names; `--mask-var` names a Boolean var column. Optional numeric values omitted mean the locked `None`. Boolean options use `on`/`off` (and `none` where the API allows it). Partition types name supported leidenalg classes and require a compatible native Leiden implementation. Actual converted native arguments are recorded in the result summary and Methods.
