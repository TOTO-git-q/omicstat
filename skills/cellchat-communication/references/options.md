# Locked package options
JSON values may also use `{ "rds": "local/path.rds" }` to supply a design/contrast matrix, factor, BiocParallel parameter or other native argument object. Only local files; no evaluation of code strings.
All package flags take JSON values: strings must be quoted (`'"edgeR"'` in bash), booleans are `true|false`, lists are JSON objects, arrays are JSON arrays; `null` requests NULL. Omission retains the locked function default.
| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--create-datatype` | `c("RNA", "spatial")` | no | datatype |
| `--create-coordinates` | `NULL` | no | coordinates |
| `--create-spatial-factors` | `NULL` | no | spatial_factors |
| `--create-assay` | `NULL` | no | assay |
| `--create-do-sparse` | `T` | no | none |
| `--db-non-protein` | `FALSE` | no | none |
| `--subset-features` | `NULL` | no | none |
| `--genes-data-use` | `NULL` | no | none |
| `--genes-group-by` | `NULL` | no | group_by |
| `--genes-idents-use` | `NULL` | no | none |
| `--genes-invert` | `FALSE` | no | none |
| `--genes-group-dataset` | `NULL` | no | none |
| `--genes-pos-dataset` | `NULL` | no | none |
| `--genes-group-de-combined` | `FALSE` | no | none |
| `--genes-features-name` | `"features"` | no | none |
| `--genes-only-pos` | `TRUE` | no | none |
| `--genes-features` | `NULL` | no | none |
| `--genes-return-object` | `TRUE` | no | none |
| `--genes-thresh-pc` | `0` | no | none |
| `--genes-thresh-fc` | `0` | no | none |
| `--genes-thresh-p` | `0.05` | no | none |
| `--genes-do-de` | `TRUE` | no | none |
| `--genes-do-fast` | `TRUE` | no | none |
| `--genes-min-cells` | `10` | no | filter_min_cells |
| `--interactions-features-name` | `"features"` | no | none |
| `--interactions-variable-both` | `TRUE` | no | none |
| `--interactions-features` | `NULL` | no | none |
| `--interactions-return-object` | `TRUE` | no | none |
| `--prob-type` | `c("triMean", "truncatedMean", "thresholdedMean", "median")` | no | type |
| `--prob-trim` | `0.1` | no | trim |
| `--prob-lr-use` | `NULL` | no | lr_use |
| `--prob-raw-use` | `TRUE` | no | raw_use |
| `--prob-population-size` | `FALSE` | no | population_size |
| `--prob-distance-use` | `TRUE` | no | distance_use |
| `--prob-interaction-range` | `250` | no | interaction_range |
| `--prob-scale-distance` | `0.01` | no | scale_distance |
| `--prob-k-min` | `10` | no | k_min |
| `--prob-contact-dependent` | `TRUE` | no | contact_dependent |
| `--prob-contact-range` | `NULL` | no | contact_range |
| `--prob-contact-knn-k` | `NULL` | no | contact_knn_k |
| `--prob-contact-dependent-forced` | `FALSE` | no | contact_dependent_forced |
| `--prob-do-symmetric` | `TRUE` | no | do_symmetric |
| `--prob-nboot` | `100` | no | nboot |
| `--prob-seed-use` | `1L` | no | seed_use |
| `--prob-kh` | `0.5` | no | kh |
| `--prob-n` | `1` | no | hill_n |
| `--filter-min-cells` | `10` | no | filter_min_cells |
| `--filter-min-samples` | `NULL` | no | filter_min_samples |
| `--filter-rare-keep` | `FALSE` | no | rare_keep |
| `--filter-nonfilter-keep` | `FALSE` | no | nonfilter_keep |
| `--pathway-net` | `NULL` | no | none |
| `--pathway-pairlr-use` | `NULL` | no | pairlr_use |
| `--pathway-thresh` | `0.05` | no | p_cutoff |
| `--aggregate-sources-use` | `NULL` | no | sources_use |
| `--aggregate-targets-use` | `NULL` | no | targets_use |
| `--aggregate-signaling` | `NULL` | no | signaling_use |
| `--aggregate-pairlr-use` | `NULL` | no | pairlr_use |
| `--aggregate-remove-isolate` | `TRUE` | no | remove_isolate |
| `--aggregate-thresh` | `0.05` | no | p_cutoff |
| `--aggregate-return-object` | `TRUE` | no | none |
| `--communication-net` | `NULL` | no | none |
| `--communication-slot-name` | `"net"` | no | centrality_slot |
| `--communication-sources-use` | `NULL` | no | sources_use |
| `--communication-targets-use` | `NULL` | no | targets_use |
| `--communication-signaling` | `NULL` | no | signaling_use |
| `--communication-pairlr-use` | `NULL` | no | pairlr_use |
| `--communication-thresh` | `0.05` | no | p_cutoff |
| `--communication-datasets` | `NULL` | no | none |
| `--communication-ligand-pvalues` | `NULL` | no | none |
| `--communication-ligand-logfc` | `NULL` | no | none |
| `--communication-ligand-pct-1` | `NULL` | no | none |
| `--communication-ligand-pct-2` | `NULL` | no | none |
| `--communication-receptor-pvalues` | `NULL` | no | none |
| `--communication-receptor-logfc` | `NULL` | no | none |
| `--communication-receptor-pct-1` | `NULL` | no | none |
| `--communication-receptor-pct-2` | `NULL` | no | none |
| `--centrality-slot-name` | `"netP"` | no | centrality_slot |
| `--centrality-net` | `NULL` | no | none |
| `--centrality-net-name` | `NULL` | no | none |
| `--centrality-thresh` | `0.05` | no | p_cutoff |
| --db-species | human skin tutorial example human | yes | database |
| --db-subset | Secreted Signaling tutorial example | yes | database |
| --cluster-col | labels tutorial example | yes | group_by |
Probability estimator choices triMean|truncatedMean|thresholdedMean|median; trim=0.1 locked default. Minimum cells=10 and nboot=100 are package/tutorial defaults. Choose database species/subset deliberately; the tutorial warns about using the entire v2 database indiscriminately. Explicit seed flag controls permutations (suite seed default; tutorial example seed.use=1). Advanced spatial arguments are exposed but spatial/condition-comparison workflows require separate evidence and S3; the tested wrapper is a single RNA network.
The pinned package does not export the tutorial optional `projectData`; projected expression is unavailable in this wrapper. `--prob-raw-use false` is refused. The supported official RNA tutorial uses raw.use=TRUE (meaning unprojected normalized expression).

## Input, execution and convenience options

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--input` | none | direct input | none |
| `--from-run` | none | input alternative | none |
| `--object-name` | none | if several upstream objects | none |
| `--counts-layer` | explicit raw-count role; counts vignette example | when raw counts needed | none |
| `--logcounts-layer` | explicit normalized log expression; logcounts vignette example | when normalized expression needed | none |
| `--source-assay` | RNA tutorial example | Seurat input | assay |
| `--ecosystem` | seurat / bioconductor / scverse | direct input | none |
| `--outdir` | none | yes | none |
| `--spec` | none; replay resolved_spec.json | no | none |
| `--seed` | 20260925 suite seed (7 for tradeSeq vignette; 1 for CellChat function default) | no | none |
| `--journal` | nature; nature / cell / science / generic | no | none |
