# Parameters

| Flag | Default | Allowed / purpose | Source |
|---|---|---|---|
| --input | none | path: Raw counts for QC; chain-state Seurat RDS for other modules | locked formals / transport contract |
| --from-run | none | path: Verified upstream Seurat run directory | locked formals / transport contract |
| --outdir | required | path: Run output directory | user_required |
| --spec | none | path: Replay prior provenance/resolved_spec.json | locked formals / transport contract |
| --seed | 20260925 | int: Recorded RNG seed | locked formals / transport contract |
| --journal | nature | enum: Figure preset | locked formals / transport contract |
| --normalization | required | enum: Required normalization route | user_required |
| --n-hvg | required | int: Prespecified feature or dimension or neighbor count | user_required |
| --n-pcs | required | int: Prespecified feature or dimension or neighbor count | user_required |
| --dims | required | int: Prespecified feature or dimension or neighbor count | user_required |
| --neighbors | required | int: Prespecified feature or dimension or neighbor count | user_required |
| --umap-neighbors | required | int: Prespecified feature or dimension or neighbor count | user_required |
| --resolution | required | num: Prespecified clustering resolution | user_required |
| --scale-factor | 10000 | num: LogNormalize library scale factor | locked formals / transport contract |
| --algorithm | 1 | int: Clustering algorithm: Louvain 1, refined 2, SLM 3, Leiden 4 | locked formals / transport contract |
| --min-dist | 0.3 | num: UMAP minimum distance | locked formals / transport contract |

All fixed package arguments and their locked function defaults are recorded in scripts/calls_registry.json. Every result-affecting argument is explicit at its call site. --help lists transport flags. Seed 20260925 follows the builder contract.

## 待裁决
Scientific choices not settled by documentation are required inputs. Tutorial values are examples, never silently chosen.

## Advanced options

Each advanced flag takes a JSON scalar or array (e.g. `false`, `0.3`, `"cosine"`, `[0.1,8]`). Omit it to use the locked default recorded below; JSON `null` passes NULL. For infinite cutoffs use the JSON string `"Inf"` or `"-Inf"`. These are passed directly to Seurat, which validates them. Structural object/assay/reduction names belong to the workflow.

| Flag | Default | Required? | S0 key |
|---|---|---|---|
| --normalize-normalization-method | none | no; effective locked default `"LogNormalize"` | none |
| --normalize-margin | none | no; effective locked default `1` | none |
| --hvg-selection-method | none | no; effective locked default `"vst"` | none |
| --hvg-loess-span | none | no; effective locked default `0.3` | none |
| --hvg-clip-max | none | no; effective locked default `"auto"` | none |
| --hvg-num-bin | none | no; effective locked default `20` | none |
| --hvg-binning-method | none | no; effective locked default `"equal_width"` | none |
| --hvg-mean-cutoff | none | no; effective locked default `c(0.1, 8)` | none |
| --hvg-dispersion-cutoff | none | no; effective locked default `c(1, Inf)` | none |
| --scale-vars-to-regress | none | no; effective locked default `NULL` | none |
| --scale-split-by | none | no; effective locked default `NULL` | none |
| --scale-model-use | none | no; effective locked default `"linear"` | none |
| --scale-use-umi | none | no; effective locked default `FALSE` | none |
| --scale-do-scale | none | no; effective locked default `TRUE` | none |
| --scale-do-center | none | no; effective locked default `TRUE` | none |
| --scale-scale-max | none | no; effective locked default `10` | none |
| --scale-block-size | none | no; effective locked default `1000` | none |
| --scale-min-cells-to-block | none | no; effective locked default `3000` | none |
| --sct-do-correct-umi | none | no; effective locked default `TRUE` | none |
| --sct-ncells | none | no; effective locked default `5000` | none |
| --sct-variable-features-rv-th | none | no; effective locked default `1.3` | none |
| --sct-vars-to-regress | none | no; effective locked default `NULL` | none |
| --sct-do-scale | none | no; effective locked default `FALSE` | none |
| --sct-do-center | none | no; effective locked default `TRUE` | none |
| --sct-clip-range | none | no; effective locked default `c(-sqrt(ncol(x)/30),sqrt(ncol(x)/30))` | none |
| --sct-vst-flavor | none | no; effective locked default `"v2"` | none |
| --sct-conserve-memory | none | no; effective locked default `FALSE` | none |
| --sct-return-only-var-genes | none | no; effective locked default `TRUE` | none |
| --pca-rev-pca | none | no; effective locked default `FALSE` | none |
| --pca-weight-by-var | none | no; effective locked default `TRUE` | none |
| --pca-approx | none | no; effective locked default `TRUE` | none |
| --graph-prune-SNN | none | no; effective locked default `1/15` | none |
| --graph-nn-method | none | no; effective locked default `"annoy"` | none |
| --graph-n-trees | none | no; effective locked default `50` | none |
| --graph-annoy-metric | none | no; effective locked default `"euclidean"` | none |
| --graph-nn-eps | none | no; effective locked default `0` | none |
| --graph-l2-norm | none | no; effective locked default `FALSE` | none |
| --cluster-modularity-fxn | none | no; effective locked default `1` | none |
| --cluster-leiden-method | none | no; effective locked default `c("leidenbase", "igraph")` | none |
| --cluster-leiden-objective-function | none | no; effective locked default `c("modularity", "CPM")` | none |
| --cluster-n-start | none | no; effective locked default `10` | none |
| --cluster-n-iter | none | no; effective locked default `10` | none |
| --cluster-group-singletons | none | no; effective locked default `TRUE` | none |
| --umap-umap-method | none | no; effective locked default `"uwot"` | none |
| --umap-n-components | none | no; effective locked default `2L` | none |
| --umap-metric | none | no; effective locked default `"cosine"` | none |
| --umap-n-epochs | none | no; effective locked default `NULL` | none |
| --umap-learning-rate | none | no; effective locked default `1` | none |
| --umap-spread | none | no; effective locked default `1` | none |
| --umap-set-op-mix-ratio | none | no; effective locked default `1` | none |
| --umap-local-connectivity | none | no; effective locked default `1L` | none |
| --umap-repulsion-strength | none | no; effective locked default `1` | none |
| --umap-negative-sample-rate | none | no; effective locked default `5L` | none |
| --umap-a | none | no; effective locked default `NULL` | none |
| --umap-b | none | no; effective locked default `NULL` | none |
| --umap-uwot-sgd | none | no; effective locked default `FALSE` | none |
| --umap-uwot-approx-pow | none | no; effective locked default `FALSE` | none |
| --umap-uwot-init | none | no; effective locked default `"spectral"` | none |
| --umap-metric-kwds | none | no; effective locked default `NULL` | none |
| --umap-angular-rp-forest | none | no; effective locked default `FALSE` | none |
| --umap-densmap | none | no; effective locked default `FALSE` | none |
| --umap-dens-lambda | none | no; effective locked default `2` | none |
| --umap-dens-frac | none | no; effective locked default `0.3` | none |
| --umap-dens-var-shift | none | no; effective locked default `0.1` | none |

| --hvg-batch-col | none | optional union of per-batch HVGs, as harmony Seurat vignette | user choice |
