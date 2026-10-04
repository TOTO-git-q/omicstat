# Locked package options
JSON values may also use `{ "rds": "local/path.rds" }` to supply a design/contrast matrix, factor, BiocParallel parameter or other native argument object. Only local files; no evaluation of code strings.
All package flags take JSON values: strings must be quoted (`'"edgeR"'` in bash), booleans are `true|false`, lists are JSON objects, arrays are JSON arrays; `null` requests NULL. Omission retains the locked function default.
| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--prep-drop` | `FALSE` | no | none |
| `--aggregate-fun` | `c("sum", "mean", "median", "prop.detected", "num.detected")` | no | aggregate_fun |
| `--aggregate-scale` | `FALSE` | no | aggregate_scale |
| `--aggregate-verbose` | `TRUE` | no | none |
| `--aggregate-bpparam` | `SerialParam(progressbar = verbose)` | no | none |
| `--ds-method` | `c("edgeR", "DESeq2", "limma-trend", "limma-voom", "DD")` | no | pb_method |
| `--ds-design` | `NULL` | no | design |
| `--ds-coef` | `NULL` | no | coef |
| `--ds-contrast` | `NULL` | no | contrast |
| `--ds-min-cells` | `10` | no | min_cells |
| `--ds-filter` | `c("both", "genes", "samples", "none")` | no | filter |
| `--ds-treat` | `FALSE` | no | treat |
| `--ds-verbose` | `TRUE` | no | none |
| `--ds-bpparam` | `SerialParam(progressbar = verbose)` | no | none |
| --sample-col | vignette sample_id | yes | none |
| --condition-col | vignette group_id | yes | none |
| --reference / --target | ctrl / stim vignette example | yes | contrast |
Methods: edgeR|DESeq2|limma-trend|limma-voom|DD; filtering: both|genes|samples|none. Optional `--ds-design` is a JSON design matrix (rows must follow pseudobulk sample order); `--ds-contrast` and `--ds-coef` control the tested comparison. Default design is ~group_id; paired studies should supply a donor-adjusted design.

| --display-fdr | suite volcano display default 0.05 | no | fdr_cutoff |
| --display-lfc | suite volcano display default 1 | no | none |

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
