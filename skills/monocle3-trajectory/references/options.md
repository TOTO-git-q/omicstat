# Locked package options
JSON values may also use `{ "rds": "local/path.rds" }` to supply a design/contrast matrix, factor, BiocParallel parameter or other native argument object. Only local files; no evaluation of code strings.
All package flags take JSON values: strings must be quoted (`'"edgeR"'` in bash), booleans are `true|false`, lists are JSON objects, arrays are JSON arrays; `null` requests NULL. Omission retains the locked function default.
| option | locked default / vignette value | required? | S0 extraction parameter key |
|---|---|---|---|
| `--cds-verbose` | `FALSE` | no | none |
| `--learn-use-partition` | `TRUE` | no | use_partition |
| `--learn-close-loop` | `TRUE` | no | close_loop |
| `--learn-learn-graph-control` | `NULL` | no | learn_graph_control |
| `--learn-verbose` | `FALSE` | no | none |
| `--order-reduction-method` | `"UMAP"` | no | reduction_method |
| `--order-root-pr-nodes` | `NULL` | no | root_pr_nodes |
| `--order-root-cells` | `NULL` | no | root_cells |
| `--order-verbose` | `FALSE` | no | none |
| `--test-neighbor-graph` | `c("knn", "principal_graph")` | no | graph_test_neighbor |
| `--test-reduction-method` | `"UMAP"` | no | reduction_method |
| `--test-k` | `25` | no | graph_test_k |
| `--test-method` | `c("Moran_I")` | no | graph_test_method |
| `--test-alternative` | `"greater"` | no | graph_test_alternative |
| `--test-expression-family` | `"quasipoisson"` | no | graph_test_family |
| `--test-cores` | `1` | no | none |
| `--test-verbose` | `FALSE` | no | none |
| `--test-nn-control` | `list()` | no | none |
| --partition-col | official cluster_cells partitions copied upstream | yes | none |
| --root-rationale | earliest developmental time in guide | yes | root_rationale |
| --root-time-col / --root-time-value | embryo.time.bin / 130-170 guide example; alternative is --order-root-cells or --order-root-pr-nodes | conditional | root_rationale |
| --graph-genes-file | all genes; explicit subset only | no | use_genes |
A root is a scientific judgement: select known early cells/states and explain it. Roots must cover each partition intended for traversal; unreachable partitions remain Inf. learn_graph close_loop true/use_partition true are locked defaults; --learn-learn-graph-control is the full JSON control list. graph_test neighbor_graph=principal_graph follows the differential guide (function default knn); k=25, Moran_I, greater, quasipoisson are locked defaults. This backend preserves UMAP/clusters/partitions. Preprocessing/alignment belongs in the supplied object, as demonstrated by the anchor fixture.

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
