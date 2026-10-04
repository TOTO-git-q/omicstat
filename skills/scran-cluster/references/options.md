# Native options and evidence mapping

| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| --input | none | no / conditional | none |
| --from-run | none | no / conditional | none |
| --outdir | none | yes | none |
| --spec | none | no / conditional | none |
| --n-hvg | none | yes | hvg_n |
| --n-pcs | none | yes | pca_components |
| --graph-k | none | yes | graph_k |
| --cluster-method | walktrap | no | graph_cluster_method |
| --resolution | none | no / conditional | none |
| --quick-method | igraph | no | quickcluster_method |
| --quick-min-size | 100 | no | quickcluster_min_size |
| --pool-sizes | 21 | no | sumfactor_sizes |
| --pseudo-count | 1 | no | lognorm_pseudocount |
| --block-col | none | no / conditional | none |
| --sample-col | none | no / conditional | none |
| --batch-col | none | no / conditional | none |
| --umap-neighbors | none | yes | umap_neighbors |
| --umap-min-dist | 0.01 | no | umap_min_dist |
| --quickcluster-args | none | no / conditional | none |
| --pool-args | none | no / conditional | none |
| --lognorm-args | none | no / conditional | none |
| --variance-args | none | no / conditional | none |
| --hvg-args | none | no / conditional | none |
| --pca-args | none | no / conditional | none |
| --graph-args | none | no / conditional | none |
| --umap-args | none | no / conditional | none |
| --seed | 100 | no | seed |
| --journal | nature | no | none |

Required study choices have no implicit default. JSON argument files expose all supplementary arguments of their named locked functions, including delegated `...` arguments; missing entries use native defaults. Primary flags take precedence. `calls_registry.json` contains container-read function/method defaults. Examples are demonstrations, never literature-derived defaults.
