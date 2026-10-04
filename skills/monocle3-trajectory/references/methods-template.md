# Methods template

Monocle3 {version} (536f1033) learn_graph and order_cells used the existing UMAP, clusters and partitions with the stated roots and biological rationale. graph_test used the recorded neighbor graph, k, method and expression family on the stated gene set. Infinite pseudotime was retained for unreachable cells.

The engine fills its short Methods output from actual native function arguments, package versions and seed; all result-affecting options are recorded in the same output and provenance.
