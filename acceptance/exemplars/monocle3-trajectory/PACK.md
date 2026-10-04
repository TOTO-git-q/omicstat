# PACK — monocle3-trajectory

S0 evidence pack and S1 draft. This version is the targeted redo after the independent verification of 2026-09-29 (`docs/build/S0_REDO_lane_b.md`); this lane does not write `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | monocle3 **1.4.27**, GitHub commit `536f1033d6de7c957f26a1f403f81efbd825e0db`: core Rd/defaults, NEWS, CITATION, README and source vignette with sha256 manifest in `L1_github/`. The source vignette points to the website and has no substantive printed trajectory table. |
| L2 | Official getting-started, trajectory and differential-analysis web guides fetched as HTML and rendered text with URL/sha256 manifest in `L2/`. The site has no stated matching commit, so it is guide evidence, not locked function-default evidence. |
| L3 | 10 applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | 30 licensed, open-access, PubMed-echoed papers; **30/30 applicable** Monocle 3 trajectory analyses. |

## T — table skeleton

Retain one row per cell with cell ID, biological sample, cell type/cluster, partition, UMAP coordinates, root node or root cell, pseudotime and reachability status. A graph-node/edge table records branches, leaves and graph-control settings. For graph-associated genes, retain full Moran's I, raw P and adjusted Q tables with the chosen neighbor graph. A Top-N gene display is only a view; it must not replace the full table.

## F — figure grammar

Plot the same learned graph over the low-dimensional embedding twice: color by biological cell label and by pseudotime, with root, branches and partition labels. Show unreachable cells distinctly rather than forcing a finite pseudotime. A trajectory-gene heatmap or branch panel may use a clearly stated subset of the full gene table. Axis labels name the reduction, and a caption names root rationale, sample mix and whether coordinates were transferred from a Seurat or AnnData front end.

## W — wording

Methods template: “Cells from `<samples/conditions>` were converted to a monocle3 cell_data_set (v1.4.27, commit `536f103`). After `<preprocess/alignment>`, `<embedding>` and partitions, `learn_graph(use_partition=<...>, close_loop=<...>)` learned the principal graph. `<root cells/nodes>` were chosen because `<biological rationale>`, and `order_cells` assigned pseudotime relative to those roots.” Results template: “`<n>` cells in `<n>` partitions were reachable from the stated roots; `<n>` had infinite/unassigned pseudotime. `<branch>` connected `<cell states>` in the learned graph.” Pseudotime is an inferred ordering, not elapsed physical time or evidence of lineage causality by itself.

## V — variant frequencies

Targeted redo after independent verification (2026-09-29): the verifier found nine Monocle3 arguments stated in PMC7673705 (33158872) that had been left unextracted; all 30 Methods were re-read for every numeric Monocle3 argument, and the counts below are recomputed from `extraction.jsonl` per ecosystem. Ecosystem is the front end (QC, normalisation, clustering); a downstream step in another ecosystem (for example scVelo velocity) does not make an article mixed.

Denominator: **30 applicable / 30 corpus**. Front end: **Seurat 26/30, mixed 4/30 (36543778 scater QC + Seurat; 36513650 scater/scran + Seurat; 34882453 fastMNN + Seurat; 36543915 scanpy/scVI front end feeding Monocle3 in R), scverse 0/30, Bioconductor-only 0/30**. Three relabels: 41402467 (Seurat 4.4.0 pipeline, scVelo only downstream) and 34851663 (Seurat 3.1.1, scVelo/Scanpy plots downstream) were scverse/mixed and are now Seurat; 34882453 (fastMNN batch correction before Seurat) was Seurat and is now mixed; 36543915 was scverse and is now mixed under the lane B rule that a Python front end feeding an R module is mixed. Sixteen/30 papers identify a root rationale; 14/30 do not. No one biological root choice occurs twice, let alone in a majority. No applicable paper has a scverse-only front end, so no scverse-specific Monocle default follows.

| Reported variant | Seurat (n=26) | Mixed (n=4) | scverse (n=0) | All applicable (n=30) |
|---|---:|---:|---:|---:|
| Biological root rationale | 13 | 3 | 0 | 16; not reported 14 |
| Exact `root_pr_nodes` ID | 2 | 0 | 0 | 2; not reported 28 |
| Embedding source or type stated | 11 | 3 | 0 | 14; not reported 16 |
| `preprocess_cds` method / dimensions stated | 2 / 3 | 1 / 1 | 0 / 0 | 3 / 4 (PCA 2; dimensions 30, 100, ten as written, and 25 in `align_cds`) |
| Normalisation method | 2 (log with residual model; none) | 0 | 0 | 2 |
| UMAP metric / neighbors | 1 / 1 | 0 / 0 | 0 / 0 | 1 / 1 |
| `cluster_cells` method | 2 (Louvain-Jaccard; Leiden) | 1 ("Levine algorithm" as written) | 0 | 3 |
| `cluster_cells` k / resolution | 1 / 2 | 0 / 0 | 0 / 0 | 1 / 2 |
| `use_partition` stated | 2 (FALSE; main partition only) | 1 (FALSE) | 0 | 3 |
| `close_loop=F` | 1 | 1 | 0 | 2 |
| `learn_graph` control: default parameters stated without values | 5 | 0 | 0 | 5 |
| `learn_graph` control: explicit values | 3 | 1 | 0 | 4 |
| `graph_test` neighbor graph / k / method | 2 / 1 / 5 | 0 / 0 / 0 | 0 / 0 / 0 | 2 / 1 / 5 (all Moran's I) |
| Adjusted-P cutoff for the graph test | 1 (q < 0.05) | 0 | 0 | 1 |
| Cell-cycle or UMI residual formula | 2 | 0 | 0 | 2 |
| Historical monocle3 version | 11 | 1 | 0 | 12; not reported 18 |
| Gene set used for ordering | 3 | 0 | 0 | 3 |

Moran's I is the only `graph_test` statistic ever named, 5/5 among the five that name it, but only 5/30 overall, so it is not a corpus majority. The 12 versions include two "Monocle3 alpha" studies and several 0.x releases whose defaults cannot be projected onto the locked 1.4.27. Upstream Seurat `resolution` and PC counts, or a Scanpy/PHATE embedding, are not silently reclassified as monocle3 function arguments. The 16 roots differ by biological system; the **most common root-selection principle** is early/progenitor identity, but the exact annotation is context-specific and has no common value. Root choice is therefore required and documented rather than defaulted.

## C — replay and printed anchors

Registry #29 / fetch F15a–c pins the official Packer and Zhu *C. elegans* embryo RDS expression, cell metadata and gene annotation files. All three downloaded files passed their registered sha256. The rendered guide shows `depts.washington.edu:/` in its RDS URL; F15a–c use the working `depts.washington.edu/` URLs and pin their bytes. The official trajectory guide constructs a `cell_data_set`, preprocesses and aligns it, reduces dimensions, clusters, calls `learn_graph`, then selects a principal-graph root with the highest fraction of cells in `embryo.time.bin="130-170"` before `order_cells(root_pr_nodes=...)`. It explains that cells in a partition without a reachable root have infinite pseudotime. Replay should assert input dimensions (registry lists 20,222 genes × 6,188 cells), matching cell/gene metadata, a valid root and finite/infinite reachability semantics. No stable printed numeric pseudotime or graph score is present in the pinned guide, so none is invented as a tolerance-based assertion.

## D — function default / official guide / exemplar evidence

Defaults are from locked Rd and `defaults.tsv`; guide examples are contextual. Frequencies count the 30 applicable papers. “Not an argument” marks an input or biological choice, not a hidden default.

| Parameter (profile) | Function default, locked build | Official workflow guide | Exemplar evidence (n=30) | S1 draft |
|---|---|---|---|---|
| `input_counts` (D-MT1) | new_cell_data_set takes expression_data | Packer expression matrix | raw count matrix 1/30; TF count matrix 1/30 (both Seurat); not reported 28/30 | Require count layer and metadata |
| `preprocess_method` (D-MT2) | PCA first choice | preprocess_cds in guide | PCA named 2/30 (Seurat); `preprocess_cds` without method 1/30 (mixed); not reported 27/30 | Explicit PCA/LSI branch |
| `num_dim` (D-MT3) | 50 | data-dependent preprocessing | 30 in 1 (Seurat); ten dimensions as written in 1 (Seurat); 100 in 1 (mixed); 25 PCs in `align_cds` in 1 (Seurat); not reported 26/30 | Report chosen dimensions |
| `norm_method` (D-MT4) | log first choice | preprocess_cds workflow | log with a residual model 1/30; none 1/30 (both Seurat); not reported 28/30 | Explicit normalization |
| `use_genes` (D-MT5) | NULL | no universal gene set | gene filters in 3/30 (Seurat): dispersion above fit and mean UMI > 0.1; mean expression and dispersion ratio > 0.15; cell-cycle genes (GO:0007049) removed; not reported 27/30 | Report included genes |
| `pseudo_count` (D-MT6) | NULL | not set in guide | not reported 30/30 | Explicit if changed |
| `scaling` (D-MT7) | TRUE | preprocessing applies scaling | not reported 30/30 | Pin TRUE provisionally |
| `reduction_method` (D-MT8) | UMAP first choice | UMAP graph and pseudotime | UMAP named 7/30 (Seurat; one is 3D); UMAP embedding or coordinates taken from another front end or from the original authors 4/30 (Seurat); UMAP dimensions used for `cluster_cells` 1/30 (mixed); UMAP coordinates 1/30 (mixed); three PHATE dimensions imported 1/30 (mixed); not reported 16/30 | Record embedding source |
| `umap_metric` (D-MT9) | cosine | not universal | Minkowski 1/30 (Seurat); not reported 29/30 | Pin only with provenance |
| `umap_min_dist` (D-MT10) | 0.1 | not universal | not reported 30/30 | Pin only with provenance |
| `umap_n_neighbors` (D-MT11) | 15 | not universal | 5-20, set empirically per cell type, 1/30 (Seurat); not reported 29/30 | Pin only with provenance |
| `cluster_k` (D-MT12) | 20 | cluster_cells uses graph | 25 in 1/30 (Seurat); not reported 29/30 | Record k |
| `cluster_method` (D-MT13) | leiden first choice | clusters/partitions before graph | Louvain-Jaccard 1/30 and Leiden 1/30 (Seurat); "Levine algorithm" as written 1/30 (mixed); not reported 27/30 | Record method |
| `cluster_resolution` (D-MT14) | NULL | not universal | 1e-3 in 1/30 and 0.0009 in 1/30 (both Seurat); not reported 28/30 | Explicit if changed |
| `partition_qval` (D-MT15) | 0.05 | guide displays partitions | not reported 30/30 | Record partition rule |
| `use_partition` (D-MT16) | TRUE | one graph per partition | FALSE 2/30 (Seurat 1 "no partitions", mixed 1); main partition only 1/30 (Seurat); not reported 27/30 | Pin TRUE provisionally |
| `close_loop` (D-MT17) | TRUE | learn_graph may close loops | FALSE 2/30 (Seurat 1, mixed 1); not reported 28/30 | Explicit with graph QC |
| `learn_graph_control` (D-MT18) | NULL | no shared graph-control list | 9/30 say something: default parameters stated without values 5/30 (Seurat); explicit values 4/30: ncenter 130/140/150 with minimal_branch_len 15/20 (Seurat); geodesic_distance_ratio 0.5 with minimal_branch_len 5 (Seurat); rann.k=45 (Seurat); euclidean_distance_ratio=0.5, geodesic_distance_ratio=0.7, minimal_branch_len=100, orthogonal_proj_tip=TRUE, rann.k=100 (mixed); not reported 21/30 | Only explicit study-specific values |
| `root_cells` (D-MT19) | NULL | choose biological roots | not reported 30/30 | Require root or root node |
| `root_pr_nodes` (D-MT20) | NULL | guide selects earliest node | Y_4 1/30; Y_376 1/30; not reported 28/30 | Require root or root cell |
| `root_rationale` (D-MT21) | biological choice, not argument | earliest embryo time-bin helper | earliest differentiation cluster 1/30; cluster identities and marker genes 1/30; highest canonical progenitor-marker expression 1/30; NOA cells / earliest disease timepoint 1/30; NMP cluster 1/30; uninjured high stem/progenitor markers 1/30; OPC cells 1/30; CS8-2 population 1/30; root per partition 1/30; 12 hpf dataset cell 1/30; Mesenchymal cells 1/30; cluster 4 1/30; vertex Y_376 enriched for GW10 cells 1/30; treated SBC population 1/30; pre–pro B cell population 1/30; not reported 15/30 | Require stated evidence |
| `graph_test_neighbor` (D-MT22) | knn first choice | principal graph option available | principal graph 2/30 (Seurat); not reported 28/30 | Explicit graph for gene test |
| `graph_test_k` (D-MT23) | 25 | not universal | 10 in 1/30 (Seurat); not reported 29/30 | Record k if used |
| `graph_test_method` (D-MT24) | Moran_I | guide uses graph-associated genes | Moran's I 5/30 (Seurat; `graph_test` 3, `principalGraphTest` 2); not reported 25/30 | Record test method |
| `fdr_cutoff` (D-MT25) | no analysis-wide cutoff argument | no universal significance threshold | q < 0.05 in 1/30 (Seurat); not reported 29/30 | Retain full table; choose display threshold |
| `version` (D-MT26) | 1.4.27 pinned commit | website guide not commit-pinned | 1.4.26 1/30; 1.3.7 1/30; 1.3.3 1/30; 1.3.1 1/30; 1.3.0 1/30; 1.0.0 1/30; 0.2.3.0 1/30; 0.2.1 1/30; 0.2.0 (reported as version 3 0.2.0) 1/30; 0.1.3 1/30 (mixed); Monocle3 alpha 2/30; not reported 18/30 | Store commit and version |
| `alignment_group` (D-MT27) | NULL | example aligns batches | batch effect via `align_cds` 1/30 (Seurat); not reported 29/30 | Explicit batch metadata |
| `alignment_k` (D-MT28) | 20 | not universal | not reported 30/30 | Record if alignment used |
| `residual_formula` (D-MT29) | NULL | embryo guide subtracts background covariates | ~S.Score + G2M.Score 1/30; number of UMI 1/30 (both Seurat); not reported 28/30 | Explicit formula if used |
| `max_components` (D-MT30) | 2 | guide plots 2D embedding | 2 in 1/30 (Seurat); not reported 29/30 | Record dimensionality |
| `umap_fast_sgd` (D-MT31) | FALSE | not universal | not reported 30/30 | Pin FALSE provisionally |
| `umap_nn_method` (D-MT32) | annoy | not universal | not reported 30/30 | Pin only with provenance |
| `cluster_num_iter` (D-MT33) | 2 | not universal | not reported 30/30 | Record iterations |
| `cluster_weight` (D-MT34) | FALSE | not universal | not reported 30/30 | Pin FALSE provisionally |
| `cluster_seed` (D-MT35) | 42 | guide does not override | not reported 30/30 | Record seed |
| `graph_test_alternative` (D-MT36) | greater | not universal | not reported 30/30 | Report alternative |
| `graph_test_family` (D-MT37) | quasipoisson | not universal | not reported 30/30 | Report family |

A paper's “default parameters” statement does not report what its historical package version actually used. In particular, the one PHATE-based study enters external coordinates; it does not change the locked `reduce_dimension()` choices. Graph branch-length controls are topology choices, not numeric tolerances.

## X — version-sensitive items

- NEWS 1.4.25 fixes `graph_test()` on R 4.5.0 and changes gene aggregation speed. NEWS 1.4.15 fixes partition calculation for widely separated clusters; saved old partitions may differ. NEWS 1.2.9 set `cluster_cells(random_seed=42)` and added Annoy nearest-neighbor support. The locked source version is 1.4.27 even though the latest NEWS heading is 1.4.25.
- PMC13575229's JATS has v1.4.26 followed by superscript reference 59, flattened as v1.4.2659. PMC8635426 literally reports “version 3 0.2.0,” which is ambiguous. Historical Monocle3 alpha studies cannot define locked defaults.
- The source vignette contains only a short package description and points to the website; the separately pinned website guide has no commit stated as matching the package source. This limits numeric replay assertions from L1.

## S1 drafts and pending decisions

1. Require an explicit biological root per traversed partition, a root-selection rationale, and a reachability report. Do not silently choose a UMAP corner or arbitrary cluster. For data with known time points, an earliest-time-bin helper is a guide-supported option.
2. Pin and record preprocessing, alignment covariates, embedding source, clustering/partition settings, graph controls and random seed. A Seurat or AnnData embedding transferred into the CDS must be identified as such.
3. Retain all cell-level pseudotime and graph data, including infinite/unreachable values, plus full graph-associated gene results. Label plots with sample/condition mix to avoid interpreting batch segregation as a biological branch.
4. Validate the F15a–c local anchor files and exact guide recipe in S1 with R; no R execution or invented numeric outputs are part of S0.
