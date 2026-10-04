# Options
JSON values may also use `{ "rds": "local/path.rds" }` to supply a design/contrast matrix, factor, BiocParallel parameter or other native argument object. Only local files; no evaluation of code strings.
| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--singler-method` | `NULL` | no | method |
| `--singler-genes` | `"de"` | no | genes |
| `--singler-sd-thresh` | `1` | no | sd_thresh |
| `--singler-de-method` | `"classic"` | no | de_method |
| `--singler-de-n` | `NULL` | no | de_n |
| `--singler-de-args` | `list()` | no | none |
| `--singler-aggr-ref` | `FALSE` | no | aggr_ref |
| `--singler-aggr-args` | `list()` | no | none |
| `--singler-recompute` | `TRUE` | no | none |
| `--singler-restrict` | `NULL` | no | restrict |
| `--singler-hint-sce` | `TRUE` | no | none |
| `--singler-quantile` | `0.8` | no | quantile |
| `--singler-fine-tune` | `TRUE` | no | fine_tune |
| `--singler-tune-thresh` | `0.05` | no | tune_thresh |
| `--singler-fine-tune-combined` | `fine.tune` | no | none |
| `--singler-prune` | `TRUE` | no | none |
| `--singler-assay-type-test` | `"logcounts"` | no | assay_type_test |
| `--singler-assay-type-ref` | `"logcounts"` | no | assay_type_ref |
| `--singler-check-missing-test` | `FALSE` | no | check_missing_test |
| `--singler-check-missing-ref` | `check.missing` | no | check_missing_ref |
| `--singler-check-missing` | `TRUE` | no | none |
| `--singler-num-threads` | `1` | no | none |
| `--singler-bnparam` | `NULL` | no | none |
| `--singler-bpparam` | `NULL` | no | none |
| `--prune-nmads` | `3` | no | prune_nmads |
| `--prune-min-diff-med` | `-Inf` | no | min_diff_med |
| `--prune-min-diff-next` | `0` | no | min_diff_next |
| `--prune-get-thresholds` | `FALSE` | no | none |
| --reference | Muraro vignette example | yes | reference |
| --reference-label-col | label | yes | label_level |

## Input, execution and convenience options

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | none | direct input | none |
| `--from-run` | none | input alternative | none |
| `--object-name` | none | if several upstream objects | none |
| `--cluster-col` | named upstream cluster/cell-type metadata | yes | none |
| `--counts-layer` | explicit raw-count role; counts vignette example | when raw counts needed | none |
| `--logcounts-layer` | explicit normalized log expression; logcounts vignette example | when normalized expression needed | none |
| `--source-assay` | RNA tutorial example | Seurat input | none |
| `--ecosystem` | seurat / bioconductor / scverse | direct input | none |
| `--outdir` | none | yes | none |
| `--spec` | none; replay resolved_spec.json | no | none |
| `--seed` | 20260925 suite seed (7 for tradeSeq vignette; 1 for CellChat function default) | no | none |
| `--journal` | nature; nature / cell / science / generic | no | none |
| `--reference-name` | Muraro example | yes | reference |
| `--reference-version` | EH2692-EH2693 example | yes | reference_version |
| `--species` | human example; user declaration | yes | none |
| `--unit` | cell; cell / cluster | no | annotation_unit |
| `--test-role` | logcounts; logcounts / counts | no | assay_type_test |
| `--de-method` | classic; classic / wilcox / t (wilcox guide single-cell example) | no | de_method |
| `--de-n` | NULL | no | de_n |
| `--aggr-ref` | false; false / true | no | aggr_ref |
| `--fine-tune` | true; true / false | no | fine_tune |
| `--quantile` | 0.8 | no | quantile |
| `--tune-thresh` | 0.05 | no | tune_thresh |
| `--nmads` | 3 | no | prune_nmads |
