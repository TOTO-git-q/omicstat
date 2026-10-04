# PACK -- scran-cluster

Status: S0 evidence collected; S1 decisions drafted, not frozen. This lane writes no `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | Bioconductor RELEASE_3_23: scran 1.40.0, scuttle 1.22.0, scater 1.40.2 and bluster 1.22.0; Rd (including S4 method defaults), NEWS/metadata and rendered package vignettes. `L1_bioc3.23/manifest.tsv`. |
| L2 | scran Grun-pancreas vignette, scater overview, scuttle user guide and bluster clustering/diagnostics vignettes archived under L1. |
| L3 | Ten tier-A close readings in `literature/l3_notes.md`; nine are applicable after the S0 redo (41324988 was re-judged inapplicable: its scran call is a side step). |
| L4 | Thirty licence-gated OA articles with PubMed efetch echo; 23 applicable: six Bioconductor-only and 17 mixed. Seven use scran only for a separate DE, annotation, variance, multimodal-integration or bulk step rather than this route. |

## T -- table skeleton

- Cell-level assignment table: cell ID, sample, size factor, selected HVGs, PCA dimension/variance, graph method and cluster label. Provide per-sample cluster sizes and a separate table of factor/HVG diagnostics.
- Gene variance table: feature, mean, technical fitted variance, biological residual, FDR and selected flag. Keep the normalization recipe and input assay visible in each exported table.

## F -- figure grammar

- Show size-factor versus library-size diagnostics, mean-variance trend and chosen HVGs, PCA variance/elbow or denoising diagnostic, graph-cluster size/stability, and UMAP coloured by cluster and sample. State which PCs and graph produced colours.
- A 2D UMAP is a display; marker and sample checks support biological labels. Separate pre-integration from corrected embeddings where fastMNN is used.

## W -- wording

- Report `quickCluster`/pooling settings, size-factor handling, `logNormCounts` pseudocount and assay, HVG model and number/FDR, PCA selection, graph parameter object and UMAP inputs. If a paper uses scran only for normalization before Seurat clustering, describe that mixed route explicitly.
- S2 draft: “Counts were normalized using <quickCluster/pooled factor recipe> in scran/scuttle <versions>; <HVG rule> genes were modeled with <block>. <n> PCs informed <bluster graph method/k>, and UMAP used <input/dimensions/seed>. Cluster sizes and sample composition were exported.”

## V -- variant frequencies

Corpus labels (article-level front-end ecosystem, re-judged in the S0 redo): eight Bioconductor-labelled (six applicable, two inapplicable), 19 mixed (17 applicable, two inapplicable), two Seurat-only and one scverse (Python) front end (all three inapplicable). Two labels follow a main-session cross-module reconciliation: 41372142 is Bioconductor-only (its Seurat step is a single patient sample, kept only as context after the main value) and the inapplicable 34878841 keeps its original Bioconductor label. Mixed workflows combine a scran/scater step with a Seurat, scanpy or custom step before the cluster labels (or benchmark several ecosystems); their values, including Seurat-side PCA/k/resolution/algorithm values, are kept in the mixed table only and are never pooled with Bioconductor-only values. Tables use **applicable articles per ecosystem** as denominators (6 and 17). Function defaults are not imputed from "default parameters". Where an article reports several analyses, the cell shows the main value first and the others after `; ` with their context.

Slot definitions used in the redo: `graph_method` = the graph type (SNN/kNN) or, when no type is stated, the named graph-building/graph-clustering function (`clusterCells`, `FindNeighbors`, `FindClusters`); `graph_cluster_method` = the community algorithm (walktrap, Louvain, Leiden); `graph_shared` = TRUE for a stated SNN graph, FALSE for a stated kNN graph; `umap_components` = number of input dimensions given to UMAP (the `calculateUMAP(pca=)` sense used in D); `pca_rank` = number of components stated as computed; `pca_method` records a named implementation only.

edits ok=5 errors=0
written
scran-cluster: rows=990 corpus=30 errors=0 warnings=0
corpus by eco: Counter({'mixed': 19, 'bioconductor': 8, 'seurat': 2, 'scverse': 1})
applicable by eco: Counter({'mixed': 17, 'bioconductor': 6})
### Bioconductor-only (6 applicable)

| Parameter | Reported values and paper counts | Reported / 6 | Not reported / 6 |
|---|---|---:|---:|
| `normalization_route` | `logNormCounts`: 2; `deconvolution with scran`: 1; `pooled size factors via scran`: 1; `computeSumFactors`: 1 | 5/6 | 1/6 |
| `quickcluster_method` | none | 0/6 | 6/6 |
| `quickcluster_min_size` | none | 0/6 | 6/6 |
| `sumfactor_clusters` | `six broad populations from preliminary clustering`: 1 | 1/6 | 5/6 |
| `sumfactor_min_mean` | `top 20% expressed genes`: 1 | 1/6 | 5/6 |
| `sumfactor_sizes` | none | 0/6 | 6/6 |
| `sumfactor_positive` | none | 0/6 | 6/6 |
| `lognorm_pseudocount` | `1`: 1 | 1/6 | 5/6 |
| `hvg_method` | `modelGeneVar`: 1; `modelGeneVar; FindVariableFeatures vst (BCR::ABL1 patient sample)`: 1; `coefficient of variation`: 1 | 3/6 | 3/6 |
| `hvg_n` | `top 15%`: 1; `3327 (resulting from the 10% FDR threshold)`: 1; `top 15% (post-normalisation round); top 20% (initial round)`: 1 | 3/6 | 3/6 |
| `hvg_fdr` | `0.1`: 1 | 1/6 | 5/6 |
| `pca_method` | `randomized PCA (irlba v2.3.5)`: 1; `irlba (v2.3.3)`: 1 | 2/6 | 4/6 |
| `pca_components` | `25`: 1; `30; 50 (UMAP input)`: 1; `30; 15 (FindNeighbors, BCR::ABL1 patient sample)`: 1; 2 other unique values | 5/6 | 1/6 |
| `graph_method` | `clusterCells`: 1; `kNN graph`: 1; `clusterCells; Seurat FindNeighbors (BCR::ABL1 patient sample)`: 1; 2 other unique values | 5/6 | 1/6 |
| `graph_k` | `60; 100 (oligodendrocyte subset)`: 1; `21`: 1; `50`: 1 | 3/6 | 3/6 |
| `graph_cluster_method` | `Walktrap (igraph v1.2.9)`: 1; `Louvain (igraph)`: 1 | 2/6 | 4/6 |
| `graph_resolution` | none | 0/6 | 6/6 |
| `umap_neighbors` | `30`: 1 | 1/6 | 5/6 |
| `umap_min_dist` | `0.2`: 1 | 1/6 | 5/6 |
| `umap_components` | `50 PCs`: 1; `30 PCs; 20 dimensions (BCR::ABL1 patient sample)`: 1 | 2/6 | 4/6 |
| `seed` | `42 (UMAP random initialisation)`: 1 | 1/6 | 5/6 |
| `scran_version` | `1.20.1`: 2; `1.30.2`: 1; `1.24.1`: 1; `1.12.1`: 1 | 5/6 | 1/6 |
| `scater_version` | `1.20.1`: 1 | 1/6 | 5/6 |
| `bluster_version` | none | 0/6 | 6/6 |
| `quickcluster_block` | none | 0/6 | 6/6 |
| `quickcluster_graph_fun` | none | 0/6 | 6/6 |
| `sumfactor_ref_clust` | none | 0/6 | 6/6 |
| `lognorm_center` | none | 0/6 | 6/6 |
| `modelgenevar_block` | `condition ID`: 1 | 1/6 | 5/6 |
| `pca_rank` | `30`: 1; `20`: 1 | 2/6 | 4/6 |
| `graph_shared` | `FALSE (kNN graph)`: 1 | 1/6 | 5/6 |
| `graph_use_dimred` | `PCA (30 PCs)`: 1; `PCA (20 components; merged RNA and ADT)`: 1 | 2/6 | 4/6 |

### Mixed (17 applicable)

| Parameter | Reported values and paper counts | Reported / 17 | Not reported / 17 |
|---|---|---:|---:|
| `normalization_route` | `computeSumFactors`: 3; `scran normalization`: 3; `computeSumFactors; multiBatchNorm`: 3; 8 other unique values | 17/17 | 0/17 |
| `quickcluster_method` | none | 0/17 | 17/17 |
| `quickcluster_min_size` | none | 0/17 | 17/17 |
| `sumfactor_clusters` | none | 0/17 | 17/17 |
| `sumfactor_min_mean` | `0.5`: 1 | 1/17 | 16/17 |
| `sumfactor_sizes` | `minimum 100, maximum 200`: 1 | 1/17 | 16/17 |
| `sumfactor_positive` | none | 0/17 | 17/17 |
| `lognorm_pseudocount` | `1`: 3 | 3/17 | 14/17 |
| `hvg_method` | `modelGeneVar`: 3; `modelGeneVar; getTopHVGs`: 1; `Seurat SelectIntegrationFeatures`: 1; 10 other unique values | 15/17 | 2/17 |
| `hvg_n` | `2000`: 2; `1000 (NCD subset analyses)`: 1; `2000; 1500 (clustering benchmark)`: 1; 7 other unique values | 11/17 | 6/17 |
| `hvg_fdr` | `0.05`: 3; `0.1`: 1 | 4/17 | 13/17 |
| `pca_method` | `RunPCA (Seurat)`: 2; `RunPCA (cross-species integration)`: 1; `runPCA`: 1; 2 other unique values | 6/17 | 11/17 |
| `pca_components` | `20`: 2; `50`: 2; `15; 20 (reclustering after removing non-iNKT clusters)`: 1; 9 other unique values | 14/17 | 3/17 |
| `graph_method` | `SNN graph`: 3; `Seurat FindClusters`: 2; `SNN graph (Seurat FindNeighbors)`: 2; 5 other unique values | 12/17 | 5/17 |
| `graph_k` | `5, 10, 30, 50 and 100 (scran clustering benchmark)`: 1; `20`: 1; `20; 5 and 100 (sensitivity)`: 1 | 3/17 | 14/17 |
| `graph_cluster_method` | `Louvain (igraph cluster_louvain); fast greedy, Louvain, walktrap (scran clustering benchmark)`: 1; `Leiden (Seurat RunLeiden)`: 1; `SNN modularity optimisation (FindClusters; algorithm not named)`: 1; 6 other unique values | 9/17 | 8/17 |
| `graph_resolution` | `0.8`: 1; `0.2-1.4 (Seurat clustering benchmark)`: 1; `1.5; 0.8 (per-cell-type clustering)`: 1; 7 other unique values | 10/17 | 7/17 |
| `umap_neighbors` | `30; 100 (CD34+ HSC and embryoid body)`: 1 | 1/17 | 16/17 |
| `umap_min_dist` | `0.3; 0.5 (CD34+ HSC and embryoid body)`: 1 | 1/17 | 16/17 |
| `umap_components` | `20 PCs`: 3; `50 (MNN-corrected PCs)`: 1; `elbow-selected top PCs (normally 15-30)`: 1; 4 other unique values | 9/17 | 8/17 |
| `seed` | none | 0/17 | 17/17 |
| `scran_version` | `1.14.6`: 4; `1.18.7`: 1; `1.10.2`: 1; 3 other unique values | 9/17 | 8/17 |
| `scater_version` | `1.14.0`: 1; `1.14.6`: 1; `1.10.1`: 1; 2 other unique values | 5/17 | 12/17 |
| `bluster_version` | none | 0/17 | 17/17 |
| `quickcluster_block` | none | 0/17 | 17/17 |
| `quickcluster_graph_fun` | none | 0/17 | 17/17 |
| `sumfactor_ref_clust` | none | 0/17 | 17/17 |
| `lognorm_center` | none | 0/17 | 17/17 |
| `modelgenevar_block` | none | 0/17 | 17/17 |
| `pca_rank` | `20 (cross-species integration)`: 1; `30; 100 (geometric sketch PCA)`: 1; `15; 25 (mouse embryo mRNA)`: 1 | 3/17 | 14/17 |
| `graph_shared` | `TRUE (SNN graph)`: 5; `FALSE (kNN graph)`: 1 | 6/17 | 11/17 |
| `graph_use_dimred` | `PCA (top 20 PCs)`: 2; `PCA (first 15 PCs of HVGs)`: 1; `MNN-corrected PCA subspace`: 1; 9 other unique values | 13/17 | 4/17 |

Bioconductor-only (n = 6): every reported value is carried by one or two papers, so none is a majority or a default. Normalisation is scran/scuttle-based in 5/6 (`logNormCounts` 2; deconvolution, pooled size factors and `computeSumFactors` one paper each). Graph `k` is 60, 21 and 50 in three different papers; `clusterCells` is named in 2/6; the community algorithm is walktrap in 1/6 and Louvain in 1/6; no paper states a resolution. The UMAP neighbour/`min_dist`/seed settings (30, 0.2, 42; 50 input PCs) come from a single paper (42566536). scran 1.20.1 is the most common version (2/6); no paper states a bluster version.

Mixed (n = 17): a scran pooled/deconvolution size-factor route (any wording: `computeSumFactors`, `quickCluster` + `computeSumFactors`, scran pooling/normalisation, batch-aware scran/batchelor) is the main normalisation in 14/17, a majority of the mixed papers; two use `logNormCounts` without pooled factors and one uses Seurat normalisation. `modelGeneVar` is the most common main HVG method (6/17, no majority), 2000 the most common main HVG number (5/17) and 20 the most common main PC number (5/17). Where a graph type is stated it is SNN in 5/17 and kNN in 1/17; the algorithm is Louvain in 4/17 and Leiden in 3/17; `k` is stated in only 3/17 (20 in two papers, one of them with a 5/100 sensitivity check; one benchmark grid). The ten reported resolutions are study-specific, five of them scanned ranges or sensitivity sets. One mixed paper states UMAP neighbours/`min_dist` (for a Coralysis probability space) and none states a seed. There is no across-ecosystem pooled majority.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 21: scRNAseq `GrunPancreasData()` (EH2687), 1,728 cells and 20,148 features. The `counts.rds` file (9.2 MB) was downloaded and SHA256-verified in this lane: `237f99410659bb6614f2cbc2cd1fcb2a5d242230c97490c87f324a59bbac246d`. `fetch_anchor_data.sh hub` records the URL/hash; column metadata are rebuilt by the package from column names.
- The locked scran vignette loads Grun, runs `scrapper::analyze.se`, then illustrates `quickCluster` and `computeSumFactors(clusters=clusters)` and prints a size-factor summary. These are smoke candidates; no R replay or numerical golden is claimed in S0.

## D -- locked function default / official guide / Bioconductor-only exemplars

Defaults come from locked Rd and the defining scuttle pooling methods, not historical paper versions. Several wrappers delegate to S4 methods or bluster; the exact method is stated below. Six Bioconductor-only applicable papers form the exemplar denominator (S0 redo; three former Bioconductor-only papers were re-labelled mixed and two mixed papers re-labelled Bioconductor-only).

| Parameter | Function default (locked version) | Official guide | Bioconductor-only exemplar evidence | S1 draft |
|---|---|---|---|---|
| `normalization_route` | no one-call default; `computeSumFactors` compatibility wrapper to scuttle pooling | Grun: `quickCluster` then `computeSumFactors` | logNormCounts: 2; deconvolution with scran: 1; pooled size factors via scran: 1; computeSumFactors: 1 (5/6 applicable) | pending S1 |
| `quickcluster_method` | `quickCluster.ANY(method=c("igraph","hclust"))`, first is igraph | not explicitly set | none (0/6 applicable) | pending S1 |
| `quickcluster_min_size` | `quickCluster.ANY(min.size=100)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `sumfactor_clusters` | `pooledSizeFactors.ANY(clusters=NULL)` | Grun passes preliminary clusters | six broad populations from preliminary clustering: 1 (1/6 applicable) | pending S1 |
| `sumfactor_min_mean` | `pooledSizeFactors.ANY(min.mean=NULL)` | not explicitly set | top 20% expressed genes: 1 (1/6 applicable) | pending S1 |
| `sumfactor_sizes` | `pooledSizeFactors.ANY(sizes=seq(21,101,5))` | not explicitly set | none (0/6 applicable) | pending S1 |
| `sumfactor_positive` | `pooledSizeFactors.ANY(positive=TRUE)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `lognorm_pseudocount` | `logNormCounts.SCE(pseudo.count=1)` | not explicitly set | 1: 1 (1/6 applicable) | pending S1 |
| `hvg_method` | `modelGeneVar` is explicit caller choice | vignette starts with `scrapper::analyze.se`; no direct HVG preset | modelGeneVar: 2; coefficient of variation: 1 (3/6 applicable) | pending S1 |
| `hvg_n` | `getTopHVGs(n=NULL, prop=NULL, var.threshold=0)` | not explicitly set | top 15%: 2; 3327 (count from a 10% FDR rule): 1 (3/6 applicable) | pending S1 |
| `hvg_fdr` | `getTopHVGs(fdr.threshold=NULL)` | not explicitly set | 0.1: 1 (1/6 applicable) | pending S1 |
| `pca_method` | `fixedPCA` or `denoisePCA` caller choice | not explicitly set | irlba (randomized) PCA: 2 (2/6 applicable) | pending S1 |
| `pca_components` | `fixedPCA(rank=50)`; `denoisePCA` data-driven | vignette demonstrates data-driven `denoisePCANumber` | 30: 2 (one with 50 for UMAP); 25: 1; 20: 1; 24: 1 (5/6 applicable) | pending S1 |
| `graph_method` | `clusterCells(BLUSPARAM=NNGraphParam())` | bluster guide demonstrates graph clustering, no suite-wide preset | clusterCells: 2; kNN graph: 1; scran/igraph graph clustering, type not named: 2 (5/6 applicable) | pending S1 |
| `graph_k` | `NNGraphParam(k=10)` | not explicitly set | 60: 1; 21: 1; 50: 1 (3/6 applicable) | pending S1 |
| `graph_cluster_method` | `NNGraphParam(cluster.fun="walktrap")` | not explicitly set | walktrap: 1; Louvain: 1 (2/6 applicable) | pending S1 |
| `graph_resolution` | no fixed resolution in `NNGraphParam` Rd | not explicitly set | none (0/6 applicable) | pending S1 |
| `umap_neighbors` | `calculateUMAP.ANY(n_neighbors=15)` via `runUMAP` | not explicitly set | 30: 1 (1/6 applicable) | pending S1 |
| `umap_min_dist` | forwarded to uwot; not fixed in scater Rd | not explicitly set | 0.2: 1 (1/6 applicable) | pending S1 |
| `umap_components` | `calculateUMAP.ANY(pca=50)` for expression matrix; NULL for supplied dimred | not explicitly set | 50 PCs: 1; 30 PCs: 1 (2/6 applicable) | pending S1 |
| `seed` | not fixed by `runUMAP` Rd | not explicitly set | 42 (UMAP initialisation): 1 (1/6 applicable) | pending S1 |
| `scran_version` | locked scran 1.40.0 | release 3.23 scran vignette | 1.20.1: 2; 1.30.2: 1; 1.24.1: 1; 1.12.1: 1 (5/6 applicable) | pending S1 |
| `scater_version` | locked scater 1.40.2 | scater overview provides PCA/UMAP diagnostics | 1.20.1: 1 (1/6 applicable) | pending S1 |
| `bluster_version` | locked bluster 1.22.0 | release 3.23 bluster diagnostics | none (0/6 applicable) | pending S1 |
| `quickcluster_block` | `quickCluster.ANY(block=NULL)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `quickcluster_graph_fun` | `quickCluster.ANY(graph.fun="walktrap")` | not explicitly set | none (0/6 applicable) | pending S1 |
| `sumfactor_ref_clust` | `pooledSizeFactors.ANY(ref.clust=NULL)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `lognorm_center` | `logNormCounts.SCE(center.size.factors=TRUE)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `modelgenevar_block` | `modelGeneVar(block=NULL)` | not explicitly set | condition ID: 1 (1/6 applicable) | pending S1 |
| `pca_rank` | `fixedPCA(rank=50)` | not explicitly set | 30: 1; 20: 1 (2/6 applicable) | pending S1 |
| `graph_shared` | `NNGraphParam(shared=TRUE)` | not explicitly set | FALSE (kNN graph): 1 (1/6 applicable) | pending S1 |
| `graph_use_dimred` | `clusterCells(use.dimred=NULL)` | not explicitly set | PCA: 2 (2/6 applicable) | pending S1 |

## X -- version-sensitive behaviour

- In scran 1.40.0, `computeSumFactors` is retained as a compatibility wrapper; its Rd delegates to scuttle `computePooledFactors`/`pooledSizeFactors`. The latter supplies the pool-size and positivity defaults.
- The locked scran vignette says many older functions are no longer routine and starts its Grun example with `scrapper::analyze.se`; the engineering plan still names the scran/scuttle chain. `clusterCells` Rd is deprecated in favour of calling bluster directly. S1 must choose the supported wrapper/direct route.
- `runUMAP` delegates to `calculateUMAP` and onward to uwot; its `n_neighbors=15` is in scater Rd, but a `min_dist` value is not fixed there. Do not turn a paper's UMAP setting into a locked scater default.

## S1 drafts and pending decisions

- P-1 Decide whether the suite exposes the plan's `quickCluster`/pooling/HVG/PCA/bluster chain directly or a `scrapper::analyze.se` preset; preserve exact stage outputs either way.
- P-2 Freeze the factor pool sizes, blocked variance model, HVG rule, PCA selection and bluster graph parameter object. The six Bioconductor-only papers have no majority-backed graph `k`, algorithm, PC number or HVG count (every value is carried by one or two papers).
- P-3 Keep normalization/cluster settings from mixed Seurat routes out of the Bioconductor preset. Surface an ecosystem switch as a separate route in S1 rather than silently combining defaults.
- P-4 Replay Grun in the locked image; only then freeze size-factor summaries, graph labels and UMAP smoke assertions with explicit random seeds and numerical tolerances.
