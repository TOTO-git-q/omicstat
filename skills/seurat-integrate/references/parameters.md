# Parameters

| Flag | Default | Allowed / purpose | Source |
|---|---|---|---|
| --input | none | path: Raw counts for QC; chain-state Seurat RDS for other modules | locked formals / transport contract |
| --from-run | none | path: Verified upstream Seurat run directory | locked formals / transport contract |
| --outdir | required | path: Run output directory | user_required |
| --spec | none | path: Replay prior provenance/resolved_spec.json | locked formals / transport contract |
| --seed | 20260925 | int: Recorded RNG seed | locked formals / transport contract |
| --journal | nature | enum: Figure preset | locked formals / transport contract |
| --method | required | enum: Explicit integration method | user_required |
| --batch-col | required | string: Metadata batch covariate | user_required |
| --dims | required | int: Prespecified number of input PCs | user_required |
| --neighbors | required | int: Prespecified graph or UMAP neighbor count | user_required |
| --umap-neighbors | required | int: Prespecified graph or UMAP neighbor count | user_required |
| --resolution | required | num: Prespecified resolution on corrected reduction | user_required |
| --sigma | 0.1 | num: Harmony soft clustering width | locked formals / transport contract |
| --theta | none | num: Optional Harmony diversity penalty; absent uses API NULL | locked formals / transport contract |
| --lambda | none | num: Optional Harmony ridge penalty; absent uses API NULL | locked formals / transport contract |
| --max-iter | 10 | int: Harmony maximum integration iterations | locked formals / transport contract |
| --min-dist | 0.3 | num: UMAP minimum distance | locked formals / transport contract |

All fixed package arguments and their locked function defaults are recorded in scripts/calls_registry.json. Every result-affecting argument is explicit at its call site. --help lists transport flags. Seed 20260925 follows the builder contract.

## 待裁决
Scientific choices not settled by documentation are required inputs. Tutorial values are examples, never silently chosen.

## Advanced options

Each advanced flag takes a JSON scalar or array (e.g. `false`, `0.3`, `"cosine"`, `[0.1,8]`). Omit it to use the locked default recorded below; JSON `null` passes NULL. For infinite cutoffs use the JSON string `"Inf"` or `"-Inf"`. These are passed directly to Seurat, which validates them. Structural object/assay/reduction names belong to the workflow.

| Flag | Default | Required? | S0 key |
|---|---|---|---|
| --harmony-options-alpha | none | no; effective locked default `0.2` | none |
| --harmony-options-tau | none | no; effective locked default `0` | none |
| --harmony-options-block-size | none | no; effective locked default `0.05` | none |
| --harmony-options-max-iter-cluster | none | no; effective locked default `4` | none |
| --harmony-options-epsilon-cluster | none | no; effective locked default `0.001` | none |
| --harmony-options-epsilon-harmony | none | no; effective locked default `0.01` | none |
| --harmony-options-batch-prop-cutoff | none | no; effective locked default `1e-05` | none |
| --harmony-nclust | none | no; effective locked default `NULL` | none |
| --harmony-early-stop | none | no; effective locked default `TRUE` | none |
| --harmony-ncores | none | no; effective locked default `1` | none |
| --integrate-new-reduction | none | no; effective locked default `"harmony"` | none |
| --integrate-nclust | none | no; effective locked default `NULL` | none |
| --integrate-tau | none | no; effective locked default `0` | none |
| --integrate-block-size | none | no; effective locked default `0.05` | none |
| --integrate-max-iter-cluster | none | no; effective locked default `20L` | none |
| --integrate-epsilon-cluster | none | no; effective locked default `1e-5` | none |
| --integrate-epsilon-harmony | none | no; effective locked default `0.01` | none |
| --graph-prune-SNN | none | no; effective locked default `1/15` | none |
| --graph-nn-method | none | no; effective locked default `"annoy"` | none |
| --graph-n-trees | none | no; effective locked default `50` | none |
| --graph-annoy-metric | none | no; effective locked default `"euclidean"` | none |
| --graph-nn-eps | none | no; effective locked default `0` | none |
| --graph-l2-norm | none | no; effective locked default `FALSE` | none |
| --cluster-modularity-fxn | none | no; effective locked default `1` | none |
| --cluster-algorithm | none | no; effective locked default `1` | none |
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
