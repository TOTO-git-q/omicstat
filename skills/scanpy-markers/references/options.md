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
| `--cluster-col` | no scientific default; consult L1 tutorial example | yes | `groupby` |
| `--expression-layer` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--purpose` | no scientific default; consult L1 tutorial example | yes | `none` |
| `--test` | 't-test' | no | `method` |
| `--alpha` | 0.05 | no | `none` |
| `--top-n` | 5 | no | `none` |
| `--help` | None | no | `none` |
| `--mask-var` | `None` (sc.tl.rank_genes_groups.mask_var; value) | no | `mask_var` |
| `--groups` | `all` (sc.tl.rank_genes_groups.groups; groups) | no | `groups` |
| `--reference` | `rest` (sc.tl.rank_genes_groups.reference; value) | no | `reference` |
| `--n-genes` | `None` (sc.tl.rank_genes_groups.n_genes; value) | no | `n_genes` |
| `--rankby-abs` | `off` (sc.tl.rank_genes_groups.rankby_abs; boolean; on\|off) | no | `rankby_abs` |
| `--corr-method` | `benjamini-hochberg` (sc.tl.rank_genes_groups.corr_method; value; benjamini-hochberg\|bonferroni) | no | `corr_method` |
| `--tie-correct` | `off` (sc.tl.rank_genes_groups.tie_correct; boolean; on\|off) | no | `tie_correct` |

Structured options accept JSON objects/lists, not Python expressions. `--groups` accepts `all` or a JSON list of cluster names; `--mask-var` names a Boolean var column. Optional numeric values omitted mean the locked `None`. Boolean options use `on`/`off` (and `none` where the API allows it). Partition types name supported leidenalg classes and require a compatible native Leiden implementation. Actual converted native arguments are recorded in the result summary and Methods.
