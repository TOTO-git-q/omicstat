# muscat pseudobulk: L3 close-reading notes

Ten applicable tier-A studies were selected after Methods review. The automatic search ranking initially placed three aggregate-only/benchmark papers in L3; those remain in L4 but are excluded from the parameter denominator. The notes below summarize the accessible Methods in our own words and were rewritten in the redo of 2026-09-29 after the verifier found that several notes described settings (covariates, gene filter, minimum-cell rule, adjusted-P rule) that had not been carried into `extraction.jsonl`. Every setting named below now has an extraction row with a verbatim snippet. Ecosystem is the front end (QC, normalisation, clustering).

## PMC10667257 — childhood nephrotic syndrome (Seurat)

A Seurat object is converted to SingleCellExperiment, counts are aggregated by broad immune lineage and individual with `aggregateData`, and INS versus healthy control is tested with edgeR. The Statistical analysis section separates BH adjustment for this pseudobulk comparison from Bonferroni-adjusted Wilcoxon tests used for cluster markers; the latter is not a muscat setting. A gene-list filter (present in at least 10% of cells, |log2FC| at least 0.65) is applied after the test, so it is not recorded as a pre-test filter. The generic sentence "P-values < 0.05 were considered significant" follows the Padj sentence but does not say the 0.05 refers to Padj; the extraction keeps that ambiguity in the value and the note. No covariates are stated.

## PMC11423886 — plant brassinosteroid signalling (Seurat)

Raw counts are summed per cell type and sample with `aggregateData`, then `pbDS` with edgeR. A gene is called when the FDR-adjusted P is at most 0.05, the absolute fold change at least 1.5 and the detection frequency at least 5% in one genotype. These are three joint call criteria of this study, not universal settings; the multiple-testing algorithm is not named. Design, gene filter and minimum cells are not stated.

## PMC11338834 — Alzheimer multi-region analysis (mixed: SCANPY + Seurat + muscat)

Cell clustering and annotation use SCANPY, sample alignment and subsetting use Seurat, and the cognitive-resilience differential expression uses muscat in R, so the front end crosses ecosystems. In the muscat paragraph, genes must have more than one count in at least ten cells, counts are summed per participant and cell type, edgeR is run through muscat with age at death and post-mortem interval as covariates, and BH adjustment is applied locally in each cell type. The `Padj > 0.05` (sic) sentence and the MAST/Nebula/Wilcoxon covariates belong to another analysis and are not copied into the muscat rows; no adjusted-P cutoff is stated for muscat.

## PMC10984943 — breast cancer fibroblasts (Seurat)

The paper validates a Seurat cell-level result with muscat sample-level aggregation and then runs DESeq2 on the pseudobulks. This is an applicable pseudobulk condition workflow, but the DESeq2 call is external to `pbDS`; PACK D keeps it apart from the `pbDS(method=)` choices. The Methods give no design, filter, minimum-cell or adjusted-P setting for this comparison.

## PMC10181823 — lung microvascular regeneration (Seurat)

Seurat 3.1.5 is the front end. The Methods say muscat generated pseudobulk profiles for each cluster and tested experimental groups with default parameters unless otherwise specified, without listing them. This supports the sample-level category but no `min_cells`, filter, design or test method.

## PMC8983670 — acute mouse hippocampal stress (mixed: scater + Seurat)

QC uses SoupX, scDblFinder and scater, normalisation uses sctransform and clustering uses Seurat 3.2.2, so the front end crosses Bioconductor and Seurat. The JATS XML gives `1.4.0` followed by superscript reference 115; plain-text extraction concatenates them into `1.4.0115`, and the version is recorded as 1.4.0. The muscat sentence gives only "pseudo-bulk method"; edgeR and DESeq2 statements elsewhere in this multi-omics Methods belong to bulk and TRAP sequencing.

## PMC13401735 — recurrent GBM CAR T cell therapy (mixed: Seurat + Scanpy)

QC is stated with both Seurat and Scanpy. Raw UMI counts are aggregated per sample and cell type, sample-cell-type pairs with fewer than ten cells are dropped, muscat's internal filters are applied without thresholds, and `pbDS` with edgeR fits a negative-binomial model with the group variable as the only predictor. Calls use nominal p < 0.05 and |fold change| > 2, so no adjusted-P cutoff is recorded for this analysis. The ten-cell rule is this study's inclusion criterion, not a numerical tolerance or literature-wide threshold. Other cell-level tests in the paper are kept separate.

## PMC10834368 — Long COVID immune response (Seurat)

Seurat is the front end (Cell Ranger matrices, sctransform, Louvain clustering); the counts are put into a SingleCellExperiment only for muscat. Before `aggregateData`, clusters 9 and 10 are excluded because the median cell count across samples is below 20, a cluster-level rule that is recorded as `min_cells` with that wording rather than as a per-pair threshold. After aggregation, genes with raw counts below ten in more than eight samples are removed, then `pbDS` with edgeR is run. Volcano plots mark genes passing an adjusted P of 0.05 or 0.1 as indicated. The DESeq2 bulk analysis, GLMM proportion tests and Holm-corrected tests of the same paper are not muscat settings. The earlier label mixed was replaced by seurat because the only other ecosystem is the downstream conversion.

## PMC8885825 — LKB1-driven lung cancer cell state (Seurat)

Seurat v3.2.0 does pre-processing, normalisation and Louvain clustering. Clusters are collapsed into pseudobulk samples for a restored versus non-restored comparison using muscat v1.4.0; SingleR/scater, Monocle3 and velocyto are downstream steps, so the label is seurat rather than mixed. DESeq2 is named for a separate bulk comparison. Muscat method, design, filter and minimum cells are not reported.

## PMC12176638 — root response to soil stress (Seurat)

The paper sums raw RNA-assay counts per cell type and sample and tests with edgeR through `pbDS`. A gene is called when the FDR-adjusted P is at most 0.05, |fold change| at least 1.5 and detection at least 10% in any included condition. The earlier snippet came from the bulk RNA-seq paragraph and has been replaced by the sentence in the muscat paragraph.

## Excluded but counted for the blocker

PMC13385355 says the endometriosis condition comparisons used muscat **cell-level models** on an RNA assay with capture batch as a covariate. It is `_applies=no` for this pseudobulk module and is the **one explicitly per-cell condition test in the 21-paper corpus**. It cannot set a default. Six other exclusions use muscat only to aggregate for a different purpose or compare simulation methods; their reasons are in the `_applies` notes. One earlier `replicates` row of the simulation paper PMC8595682 was a LaTeX fragment of a sample-size formula and has been reset to not reported.
