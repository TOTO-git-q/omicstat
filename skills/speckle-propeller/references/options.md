# Locked package options
JSON values may also use `{ "rds": "local/path.rds" }` to supply a design/contrast matrix, factor, BiocParallel parameter or other native argument object. Only local files; no evaluation of code strings.
All package flags take JSON values: strings must be quoted (`'"edgeR"'` in bash), booleans are `true|false`, lists are JSON objects, arrays are JSON arrays; `null` requests NULL. Omission retains the locked function default.
| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--prop-trend` | `FALSE` | no | trend |
| `--prop-robust` | `TRUE` | no | robust |
| `--prop-transform` | `"logit"` | no | transform |
| `--props-transform` | `NULL` | no | transform |
| --sample-col | vignette sample | yes | sample_key |
| --condition-col | vignette group | yes | group_key |
Transform: logit|asin; locked logit default, vignette demonstrates both. `--prop-trend false` / `--prop-robust true` are locked defaults. More than two groups invokes ANOVA; two groups invokes the package t-test. A paired/covariate-specific analysis is outside this simple propeller wrapper and requires a separate design-aware workflow.

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
