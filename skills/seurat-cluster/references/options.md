# Options and reference-service evidence keys

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none | no | none |
| --from-run | none | no | none |
| --outdir | required | yes | none |
| --spec | none | no | none |
| --seed | 20260925 | no | none |
| --journal | nature | no | none |
| --normalization | required; example LogNormalize | yes | normalization_route |
| --n-hvg | required; example 2000 | yes | hvg_n |
| --n-pcs | required; example 50 | yes | pca_npcs |
| --dims | required; example 10 | yes | neighbor_dims |
| --neighbors | required; example 20 | yes | neighbor_k |
| --umap-neighbors | required; example 30 | yes | umap_neighbors |
| --resolution | required; example 0.5 | yes | cluster_resolution |
| --scale-factor | 10000 | no | scale_factor |
| --algorithm | 1 | no | cluster_algorithm |
| --min-dist | 0.3 | no | umap_min_dist |
| --normalize-normalization-method | locked "LogNormalize"; effective `"LogNormalize"` | no | normalization_method |
| --normalize-margin | locked 1; effective `1` | no | none |
| --hvg-selection-method | locked "vst"; effective `"vst"` | no | none |
| --hvg-loess-span | locked 0.3; effective `0.3` | no | none |
| --hvg-clip-max | locked "auto"; effective `"auto"` | no | none |
| --hvg-num-bin | locked 20; effective `20` | no | none |
| --hvg-binning-method | locked "equal_width"; effective `"equal_width"` | no | none |
| --hvg-mean-cutoff | locked c(0.1, 8); effective `c(0.1, 8)` | no | none |
| --hvg-dispersion-cutoff | locked c(1, Inf); effective `c(1, Inf)` | no | none |
| --scale-vars-to-regress | locked NULL; effective `NULL` | no | none |
| --scale-split-by | locked NULL; effective `NULL` | no | none |
| --scale-model-use | locked "linear"; effective `"linear"` | no | none |
| --scale-use-umi | locked FALSE; effective `FALSE` | no | none |
| --scale-do-scale | locked TRUE; effective `TRUE` | no | none |
| --scale-do-center | locked TRUE; effective `TRUE` | no | none |
| --scale-scale-max | locked 10; effective `10` | no | none |
| --scale-block-size | locked 1000; effective `1000` | no | none |
| --scale-min-cells-to-block | locked 3000; effective `3000` | no | none |
| --sct-do-correct-umi | locked TRUE; effective `TRUE` | no | none |
| --sct-ncells | locked 5000; effective `5000` | no | none |
| --sct-variable-features-rv-th | locked 1.3; effective `1.3` | no | none |
| --sct-vars-to-regress | locked NULL; effective `NULL` | no | sct_vars_to_regress |
| --sct-do-scale | locked FALSE; effective `FALSE` | no | none |
| --sct-do-center | locked TRUE; effective `TRUE` | no | none |
| --sct-clip-range | locked c(-sqrt(x = ncol(x = object[[assay]])/30), sqrt(x = ncol(x = object[[assay]])/30)); effective `c(-sqrt(ncol(x)/30),sqrt(ncol(x)/30))` | no | none |
| --sct-vst-flavor | locked "v2"; effective `"v2"` | no | sct_vst_flavor |
| --sct-conserve-memory | locked FALSE; effective `FALSE` | no | none |
| --sct-return-only-var-genes | locked TRUE; effective `TRUE` | no | none |
| --pca-rev-pca | locked FALSE; effective `FALSE` | no | none |
| --pca-weight-by-var | locked TRUE; effective `TRUE` | no | none |
| --pca-approx | locked <absent>; effective `TRUE` | no | none |
| --graph-prune-SNN | locked 1/15; effective `1/15` | no | none |
| --graph-nn-method | locked "annoy"; effective `"annoy"` | no | none |
| --graph-n-trees | locked 50; effective `50` | no | none |
| --graph-annoy-metric | locked "euclidean"; effective `"euclidean"` | no | none |
| --graph-nn-eps | locked 0; effective `0` | no | none |
| --graph-l2-norm | locked FALSE; effective `FALSE` | no | none |
| --cluster-modularity-fxn | locked 1; effective `1` | no | none |
| --cluster-leiden-method | locked c("leidenbase", "igraph"); effective `c("leidenbase", "igraph")` | no | none |
| --cluster-leiden-objective-function | locked c("modularity", "CPM"); effective `c("modularity", "CPM")` | no | none |
| --cluster-n-start | locked 10; effective `10` | no | none |
| --cluster-n-iter | locked 10; effective `10` | no | none |
| --cluster-group-singletons | locked TRUE; effective `TRUE` | no | none |
| --umap-umap-method | locked "uwot"; effective `"uwot"` | no | none |
| --umap-n-components | locked 2L; effective `2L` | no | none |
| --umap-metric | locked "cosine"; effective `"cosine"` | no | umap_metric |
| --umap-n-epochs | locked NULL; effective `NULL` | no | none |
| --umap-learning-rate | locked 1; effective `1` | no | none |
| --umap-spread | locked 1; effective `1` | no | none |
| --umap-set-op-mix-ratio | locked 1; effective `1` | no | none |
| --umap-local-connectivity | locked 1L; effective `1L` | no | none |
| --umap-repulsion-strength | locked 1; effective `1` | no | none |
| --umap-negative-sample-rate | locked 5L; effective `5L` | no | none |
| --umap-a | locked NULL; effective `NULL` | no | none |
| --umap-b | locked NULL; effective `NULL` | no | none |
| --umap-uwot-sgd | locked FALSE; effective `FALSE` | no | none |
| --umap-uwot-approx-pow | locked FALSE; effective `FALSE` | no | none |
| --umap-uwot-init | locked "spectral"; effective `"spectral"` | no | none |
| --umap-metric-kwds | locked NULL; effective `NULL` | no | none |
| --umap-angular-rp-forest | locked FALSE; effective `FALSE` | no | none |
| --umap-densmap | locked FALSE; effective `FALSE` | no | none |
| --umap-dens-lambda | locked 2; effective `2` | no | none |
| --umap-dens-frac | locked 0.3; effective `0.3` | no | none |
| --umap-dens-var-shift | locked 0.1; effective `0.1` | no | none |
| --hvg-batch-col | none | no | none |
| --cluster-initial-membership | NULL | no | none |
| --cluster-node-sizes | NULL | no | none |
| --hvg-mean-function | FastExpMean | no | none |
| --hvg-dispersion-function | FastLogVMR | no | none |
| --sct-reference-model | NULL | no | none |
| --sct-residual-features | NULL | no | none |

Choose LogNormalize for the PBMC library-size normalization workflow, or SCTransform for the separate UMI variance-stabilizing workflow. Choose PCs using the elbow and biology, neighbors using desired local scale, HVGs using data size and study design, and resolution by inspecting markers and sample structure. hvg-method accepts vst, mean.var.plot or dispersion. hvg-batch-col implements the Harmony tutorial union of per-batch HVGs.

Sources: locked PACK C/D and archived PBMC, Harmony Seurat, or cell-cycle tutorial. Advanced flags accept JSON values; package call defaults and the exact forwarded expressions are in calls_registry.json. Transport parameters are suite contracts. No literature counts determine defaults.

