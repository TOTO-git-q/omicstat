# Locked package options
JSON values may also use `{ "rds": "local/path.rds" }` to supply a design/contrast matrix, factor, BiocParallel parameter or other native argument object. Only local files; no evaluation of code strings.
All package flags take JSON values: strings must be quoted (`'"edgeR"'` in bash), booleans are `true|false`, lists are JSON objects, arrays are JSON arrays; `null` requests NULL. Omission retains the locked function default.
| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--sling-end-clus` | `NULL` | no | end_cluster |
| `--sling-dist-method` | `"slingshot"` | no | dist_method |
| `--sling-use-median` | `FALSE` | no | use_median |
| `--sling-omega` | `FALSE` | no | omega |
| `--sling-omega-scale` | `1.5` | no | omega_scale |
| `--sling-times` | `NULL` | no | times |
| `--sling-shrink` | `TRUE` | no | shrink |
| `--sling-extend` | `"y"` | no | extend |
| `--sling-reweight` | `TRUE` | no | reweight |
| `--sling-reassign` | `TRUE` | no | reassign |
| `--sling-thresh` | `0.001` | no | curve_thresh |
| `--sling-maxit` | `15` | no | maxit |
| `--sling-stretch` | `2` | no | stretch |
| `--sling-approx-points` | `NULL` | no | approx_points |
| `--sling-smoother` | `"smooth.spline"` | no | smoother |
| `--sling-shrink-method` | `"cosine"` | no | shrink_method |
| `--sling-allow-breaks` | `TRUE` | no | allow_breaks |
| `--gam-conditions` | `NULL` | no | fit_conditions |
| `--gam-u` | `NULL` | no | none |
| `--gam-genes` | `seq_len(nrow(counts))` | no | fit_genes |
| `--gam-weights` | `NULL` | no | fit_weights |
| `--gam-offset` | `NULL` | no | fit_offset |
| `--gam-nknots` | `6` | no | nknots |
| `--gam-verbose` | `TRUE` | no | none |
| `--gam-parallel` | `FALSE` | no | none |
| `--gam-bpparam` | `BiocParallel::bpparam()` | no | none |
| `--gam-control` | `mgcv::gam.control()` | no | none |
| `--gam-sce` | `TRUE` | no | none |
| `--gam-family` | `"nb"` | no | fit_family |
| `--gam-gcv` | `FALSE` | no | none |
| `--association-global` | `TRUE` | no | assoc_global |
| `--association-lineages` | `FALSE` | no | assoc_lineages |
| `--association-l2fc` | `0` | no | assoc_l2fc |
| `--association-npoints` | `2 * tradeSeq::nknots(models)` | no | assoc_npoints |
| `--association-contrasttype` | `"start"` | no | assoc_contrast_type |
| `--association-inverse` | `ifelse(l2fc == 0, "Chol", "eigen")` | no | none |
| --reduced-dim | PCA/UMAP vignette example; use existing upstream embedding | yes | reduced_dim |
| --start-cluster | NULL unsupervised default, or known early cluster (vignette 1) | yes | start_cluster |
| --fit-gam | true, official downstream tradeSeq workflow | no | none |
Choose the root from biological time/state; `auto` deliberately requests unsupervised orientation. Slingshot extend choices: y|n|pc1; dist.method slingshot|simple|scaled.full|scaled.diag|mnn; smoother smooth.spline|loess. nknots=6 is the locked tradeSeq default; additional flexibility can overfit. --gam-genes restricts genes; --gam-U adds covariates; --gam-control controls mgcv.

| --trajectory-rds | none; optional official cached slingshot object | no | none |
| --rng-version | 3.5.0; tradeSeq.Rmd setup | no | none |

## Input, execution and convenience options

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | none | direct input | none |
| `--from-run` | none | input alternative | none |
| `--object-name` | none | if several upstream objects | none |
| `--cluster-col` | named upstream cluster/cell-type metadata | yes | cluster_labels |
| `--counts-layer` | explicit raw-count role; counts vignette example | when raw counts needed | none |
| `--logcounts-layer` | explicit normalized log expression; logcounts vignette example | when normalized expression needed | none |
| `--source-assay` | RNA tutorial example | Seurat input | none |
| `--ecosystem` | seurat / bioconductor / scverse | direct input | none |
| `--outdir` | none | yes | none |
| `--spec` | none; replay resolved_spec.json | no | none |
| `--seed` | 20260925 suite seed (7 for tradeSeq vignette; 1 for CellChat function default) | no | none |
| `--journal` | nature; nature / cell / science / generic | no | none |
