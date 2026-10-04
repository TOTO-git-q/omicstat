# speckle propeller: L3 close-reading notes

Ten tier-A papers are applicable. The notes below were rewritten in the redo of 2026-09-29: the earlier notes were a one-line template ("Explicit values: ...") and the verifier found that almost every propeller sentence names the compared conditions although `group_key` had been recorded once. Each setting named below now has an extraction row with a verbatim snippet (≤25 words) and section path in `extraction.jsonl`. A reported analysis is not interpreted as a package default. Ecosystem is the front end (QC, normalisation, clustering).

## PMC10624900 — human leptomeninges (Seurat)

The Methods say cell-(sub)type proportional differences between AD and the NCI/MCI group were tested with `propeller` from speckle v0.0.3. Compared groups and the cell-(sub)type unit are given; the sample column, transform, design and correction are not stated.

## PMC12627582 — Gli1 stromal cells in the fetal limb (mixed: Seurat + SingleCellExperiment)

The count matrices come from Seurat v4.2.1 and R/Bioconductor SingleCellExperiment packages, then Harmony and a single Seurat object. The propeller test (speckle v0.0.1) compares "conditions" whose levels are not named in this passage, and groups with an FDR of at most 0.1 are called notable; the correction algorithm is not named.

## PMC11192082 — cardiac fibroblast integration (Seurat)

The Methods state the argument mapping in words: sample was set to biological replicates and group to experimental condition (HFpEF versus normal chow and time point, or COVID-19 versus uninfected), with an FDR of 0.05 for significance, speckle v0.0.2. Clustering, integration (cFIT, Harmony, Seurat CCA) and testing are in R; Scanpy is used only for PAGA trajectories, so the front end is Seurat, not mixed.

## PMC12711567 — anti-progestin therapy in breast tissue (mixed: Bioconductor + scanpy)

QC uses DropletUtils and scuttle, batches are merged with batchelor, the graph comes from scran and PCA/UMAP from scater; subclustering then runs in Python with scanpy. This front end crosses Bioconductor and scverse, and lane A labels the same article mixed in scater-qc. The propeller sentence says only that differential abundance testing used `propeller`; no key, transform, design or correction is given.

## PMC13398505 — preeclampsia across gestation (Seurat)

The test accounts for donor variability and gestational age through a linear model on a matrix with donors as rows and conditions as columns, using the design matrices `~ 0 + c` and, for one tissue, `~ 0 + c + method` (two single-cell methods). The donor is the sample unit; speckle 0.0.3.

## PMC13281805 — neuronal microexons in zebrafish (mixed: scater + Seurat)

Quality filtering in R uses scater `isOutlier`, then Seurat v4.3.0 SCT, integration and PCA. Genotype contributions were compared with `propeller` (speckle v1.4.0) with FDR correction; the algorithm is not named, and the FDR of the differential-expression step (BH) is a separate analysis. The earlier version snippet contained a space inserted by the extractor and has been replaced.

## PMC11021475 — uveal melanoma immunogenomics (Seurat)

Cell type proportions were compared by the UMIS level with `propeller` (speckle v0.0.3) using the arcsin square root transformation of proportions. In the JATS the reference number 101 follows v0.0.3, which plain-text parsing reads as `v0.0.3101`; the recorded version is 0.0.3.

## PMC13251834 — early Rett syndrome (Seurat)

Cell type composition testing used `propeller`, taking into account individual samples within each experimental group. Sample unit and group are named; version, transform, design and correction are not stated.

## PMC12950190 — glioblastoma organoid transplantation (Seurat)

Significance of cell type proportion changes was tested with `propeller`, using pairwise comparison of each knockdown condition against the scramble control across all cell types, with p-values adjusted by false discovery rate. This is the one article in the corpus with an explicit reference-level contrast (recorded in `contrast`); the algorithm of the FDR adjustment is not named. The RNAScope section mentions "fluorescent speckles" only as a staining term, not the package.

## PMC11695997 — CXADR and the placental exchange surface (Seurat)

The only paper that prints the arguments: the input data frame built with `FetchData` holds cell ID, sample of origin, cluster ID and group, and `propeller` was run with `robust = T`, `trend = T` and `transform = "logit"` (speckle v1.2.0). The comparison is WT versus CXADR KO, with the inhibit/remove datasets subset to the 24 h time point. These settings are one study's choice and not a corpus default.

## Corpus caveats

PMC13533838 reports propeller for relative abundances without a condition comparison and is inapplicable. PMC12893110 describes the procedure as proportional odds regression with a t-test; this conflicts with the locked Rd, so its wording is retained without an inferred implementation. PMC11156587 says "arcsin-transformed counts", while the locked function transforms proportions. No Methods section explicitly attributes a per-cell condition test to propeller in this corpus.
