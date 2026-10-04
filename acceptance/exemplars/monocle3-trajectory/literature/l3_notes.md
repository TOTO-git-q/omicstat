# monocle3 trajectory: L3 close-reading notes

Ten tier-A studies run a Monocle 3 trajectory and are applicable. Exact Methods snippets of at most 25 words and section paths are in `extraction.jsonl`. Root choices are reported as biological orientation decisions, never package defaults. These notes were revised in the targeted redo of 2026-09-29: the verifier found that the Monocle3 arguments in one L4 article (PMC7673705) and several stated settings in the L3 articles had not been extracted; all 30 Methods were re-read and the settings named below now have rows with verbatim snippets. Ecosystem is the front end (QC, normalisation, integration, clustering).

## PMC13553300 — transition and velocity analysis (Seurat)

The study uses Monocle3 1.3.3 and explicitly varies principal-graph `ncenter` (130, 140 or 150) and minimum branch length (15 or 20), chosen so that the graph covers the target region without branching, with `close_loop` set to FALSE. Pseudotime starts from one of the terminal nodes, matching the assumed direction of the transition. These are study sensitivity choices for one transition, not a locked graph-control setting; RNA velocity with scVelo is a separate downstream step.

## PMC9772349 — human glial trajectory (mixed: scater QC + Seurat + scran)

Human data pass QC with scater, normalisation and clustering in Seurat (SCTransform, `FindClusters`), and lineage markers come from `scran::findMarkers`, so the front end crosses Bioconductor and Seurat. PHATE (KNN = 5, three dimensions, decay 50, T = 10) supplies the embedding; clustering is done in monocle3 on the three PHATE dimensions with an algorithm written as "Levine" (recorded as written). `use_partition=F`, `close_loop=F`, `euclidean_distance_ratio`, `geodesic_distance_ratio`, `minimal_branch_len`, `orthogonal_proj_tip` and `rann.k` are given, and the root nodes are OPC cells. PHATE coordinates are external embedding input; the locked `reduce_dimension()` does not thereby acquire a PHATE default.

## PMC8770128 — embryonic trajectory (Seurat)

A Seurat front end precedes Monocle3 trajectory inference and pseudotime calculation. The Methods also discuss starting populations for a separate lineage-tracing simulation; those simulation populations were not counted as Monocle3 root cells. No exact root argument or graph-control value is reported.

## PMC8655033 — cranial suture cell state (Seurat)

This Seurat-front-end trajectory uses UMAP with approximate graph abstraction, removes cell-cycle genes (GO:0007049) and infers trajectory and pseudotime "using ten dimensions" with the CS8-2 population as the root state. The Methods do not say that ten is `preprocess_cds(num_dim=10)`, so the row records "ten dimensions (as written; function not named)".

## PMC12831476 — neuronal pseudotime (Seurat)

The Seurat object and its existing UMAP embeddings are transferred into a Monocle3 CellDataSet for trajectory inference; cells are assigned partitions and cluster identities are retained. Version 1.3.7 is stated. The paper does not report the locked package's UMAP-neighbor, minimum-distance or graph-control arguments.

## PMC9747719 — regenerating tissue (mixed: scater/scran + Seurat)

The front end uses scater and scran functions together with Seurat (SCTransform, `FindNeighbors`, `FindClusters`). The authors use Monocle 3 version 0.1.3, re-process the data with `preprocess_cds` with the number of dimensions set to 100, cluster with `cluster_cells` on the UMAP dimensions, learn a principal graph in UMAP space and identify a root node for each partition. A root per partition is consistent with the official guide's explanation that unreachable partitions otherwise receive infinite pseudotime, but the paper does not name the root nodes.

## PMC8741273 — temporal transcription factors (Seurat)

Seurat precedes a TF-count-matrix trajectory; the UMAP embedding is imported into Monocle3, `learn_graph` is run with default parameters, and a 12 hpf cell is chosen as root. `graph_test` and `find_gene_modules` are named without arguments. The seven PCs mentioned in upstream dimension reduction are not assigned to `preprocess_cds(num_dim=)` without a direct call, and the Scanpy PAGA analysis belongs to a separate step.

## PMC8635426 — cell-state progression (Seurat)

Seurat 3.1.1 does normalisation and clustering; scVelo/PAGA and Scanpy violin plots are downstream, so the label is seurat (earlier: mixed). The Methods print "version 3 0.2.0", retained as an ambiguous 0.2.0 report rather than silently rewritten. A principal graph is learned with default parameters, `principalGraphTest` with Moran's I identifies correlated genes, and cluster 4 is chosen as root because of RNA velocity. No current-version defaults follow from it.

## PMC7648648 — follicle-cell pseudotime (Seurat)

Seurat-selected cell subsets enter historical monocle3 v0.2.1 pseudotime analyses. The subset definition affects the graph; the Methods do not establish a reusable root or current graph-control setting.

## PMC8617197 — pre–pro B cell trajectory (Seurat)

A Seurat object is converted to Monocle 3; `aligncds` residualizes `~S.Score + G2M.Score` for cell cycle, then UMAP and clustering follow in Monocle with a final resolution of 0.0009, giving three partitions that are relabelled so pre–pro B cells share one. A documentation-based earliest-principal-node helper selects a root in the pre–pro B population. `graph_test` with Moran's I and a q-value below 0.05 identifies variable genes. The formula and resolution are dataset-specific.

## Corpus and retrieval caveats

All 30 retained corpus papers directly describe a Monocle 3 trajectory. PMC13575229's JATS has version 1.4.26 followed by superscript reference 59; flattened text reads 1.4.2659. One candidate full text (PMC10901738) returned Europe PMC HTTP 500 during search; the retriever logged it and continued to the 30-paper corpus target. It is not cited as evidence. Old "Monocle3 alpha" papers (PMC7673705, PMC7720616) remain in the corpus but cannot define locked 1.4.27 defaults. PMC7673705 is the richest report of numeric arguments in the corpus (PCA with 30 dimensions, UMAP to two dimensions with Minkowski metric and 5 to 20 neighbours, Louvain-Jaccard clustering, principal graph test with k = 10, Moran's I above 0.1); its STREAM/URD analyses with root mRGC1 are not Monocle3 and are not counted.
