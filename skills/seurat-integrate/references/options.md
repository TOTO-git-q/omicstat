# Options and reference-service evidence keys

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --harmony-project-dim | TRUE | no | none |
| --input | none | no | none |
| --from-run | none | no | none |
| --outdir | required | yes | none |
| --spec | none | no | none |
| --seed | 20260925 | no | none |
| --journal | nature | no | none |
| --method | required; example RunHarmony; alternative official Seurat HarmonyIntegration | yes | integration_route |
| --batch-col | required; example stim | yes | batch_variable |
| --dims | required; example 20 | yes | input_dims |
| --neighbors | required; example 20 | yes | none |
| --umap-neighbors | required; example 30 | yes | none |
| --resolution | required; example 0.5 | yes | none |
| --sigma | 0.1 | no | sigma |
| --theta | none | no | theta |
| --lambda | none | no | lambda |
| --max-iter | 10 | no | max_iter_harmony |
| --min-dist | 0.3 | no | none |
| --harmony-options-alpha | locked 0.2; effective `0.2` | no | none |
| --harmony-options-tau | locked 0; effective `0` | no | tau |
| --harmony-options-block-size | locked 0.05; effective `0.05` | no | block_size |
| --harmony-options-max-iter-cluster | locked 4; effective `4` | no | max_iter_cluster |
| --harmony-options-epsilon-cluster | locked 0.001; effective `0.001` | no | epsilon_cluster |
| --harmony-options-epsilon-harmony | locked 0.01; effective `0.01` | no | epsilon_harmony |
| --harmony-options-batch-prop-cutoff | locked 1e-05; effective `1e-05` | no | none |
| --harmony-nclust | locked <absent>; effective `NULL` | no | nclust |
| --harmony-early-stop | locked <absent>; effective `TRUE` | no | early_stop |
| --harmony-ncores | locked <absent>; effective `1` | no | none |
| --integrate-new-reduction | none | no | none |
| --integrate-nclust | locked <absent>; effective `NULL` | no | nclust |
| --integrate-tau | locked <absent>; effective `0` | no | tau |
| --integrate-block-size | locked <absent>; effective `0.05` | no | block_size |
| --integrate-max-iter-cluster | locked <absent>; effective `20L` | no | max_iter_cluster |
| --integrate-epsilon-cluster | locked <absent>; effective `1e-5` | no | epsilon_cluster |
| --integrate-epsilon-harmony | locked <absent>; effective `0.01` | no | epsilon_harmony |
| --graph-prune-SNN | locked 1/15; effective `1/15` | no | none |
| --graph-nn-method | locked "annoy"; effective `"annoy"` | no | none |
| --graph-n-trees | locked 50; effective `50` | no | none |
| --graph-annoy-metric | locked "euclidean"; effective `"euclidean"` | no | none |
| --graph-nn-eps | locked 0; effective `0` | no | none |
| --graph-l2-norm | locked FALSE; effective `FALSE` | no | none |
| --cluster-modularity-fxn | locked 1; effective `1` | no | none |
| --cluster-algorithm | locked 1; effective `1` | no | none |
| --cluster-leiden-method | locked c("leidenbase", "igraph"); effective `c("leidenbase", "igraph")` | no | none |
| --cluster-leiden-objective-function | locked c("modularity", "CPM"); effective `c("modularity", "CPM")` | no | none |
| --cluster-n-start | locked 10; effective `10` | no | none |
| --cluster-n-iter | locked 10; effective `10` | no | none |
| --cluster-group-singletons | locked TRUE; effective `TRUE` | no | none |
| --umap-umap-method | locked "uwot"; effective `"uwot"` | no | none |
| --umap-n-components | locked 2L; effective `2L` | no | none |
| --umap-metric | locked "cosine"; effective `"cosine"` | no | none |
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

Choose RunHarmony to wrap the Harmony Seurat-object tutorial; choose HarmonyIntegration for the Seurat v5 split-layer workflow (RNA/LogNormalize here). Specify a technical batch covariate supported by study design; do not automatically remove a biological condition. Dimensions/neighbor counts/resolution require review on the corrected embedding. Harmony penalty/iteration defaults stay at locked values unless evidence supports an override.

Sources: locked PACK C/D and archived PBMC, Harmony Seurat, or cell-cycle tutorial. Advanced flags accept JSON values; package call defaults and the exact forwarded expressions are in calls_registry.json. Transport parameters are suite contracts. No literature counts determine defaults.
