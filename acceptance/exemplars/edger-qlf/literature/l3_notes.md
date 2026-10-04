# edger-qlf — L3 close-reading notes

Close reading of the 10 tier-A, most-parameter-rich exemplars (layer `L3+L4`). Own words;
quotes are verbatim fragments (<=25 words) copied from the Methods text retrieved via
`collect.py methods`. "not stated" where the Methods text gives no information on a point.

## PMC7755388 / PMID 33350385 — honey bee behavior (RNAseq + ATACseq, edgeR both)
- **Results presentation**: DEG lists per pairwise behavioral-group comparison (thresholded at
  FDR<0.05) are not shown as a main-text table; the Methods says they are "given in
  Supplementary file 3", and the parallel ATAC-seq DAP lists go to "Supplementary file 4".
  Downstream, TF-motif enrichment against these DEG/DAP sets is summarized with
  hypergeometric/q-value tests and, for motifs enriched in both, plotted as CentriMo binding
  probability curves ("shown in Figure 3B-C"). No volcano or MA plot is named in the Methods.
- **Methods sentence structure**: package name only ("edgeR"), no version number anywhere in
  the RNA-seq or ATAC-seq paragraphs; function names are not spelled out either — the test is
  described generically as "quasi-likelihood F-tests for each pairwise comparison of groups,
  with FDR correction for multiple testing", following a filter clause (CPM<1 in >=2 samples)
  and a normalization clause (TMM) in the same short paragraph.

## PMC13577898 / PMID 42680952 — Isthmin-2 preeclampsia (ISM2 knockdown RNA-seq)
- **Results presentation**: edgeR's output feeds a GSEA against MSigDB Hallmark and cell-type
  signature ('C8') collections, ranked by `sign(log2FC) x -log10(p)`; the actual DEG counts or
  a volcano/MA figure are not described in the Methods paragraph itself (the paragraph is
  bioinformatic-pipeline-only, figures are elsewhere in the paper).
- **Methods sentence structure**: unusually complete "code-like" chain — package+version first
  ("For edgeR (v4.0.16) analysis"), then the exact function used to import counts
  ("makeDGEList"), then normalization by name and function ("calcNormFactors" function ... TMM),
  then the fit function ("glmQLFit"), then the test function with its explicit numeric argument
  ("glmTreat" function of edgeR with at least 20% fold change, i.e. lfc = log2(1.2)).

## PMC9825163 / PMID 36229039 — INRI-seq in vitro translation oligo pool
- **Results presentation**: "differentially translated" oligos (not genes) are the unit of
  result; Methods gives no figure/table pointer for this specific list, though a related
  off-target screen against the oligo pool is described just after.
- **Methods sentence structure**: package+version stated first ("edgeR (v3.30.0)"), then a
  bespoke filter formula given as prose ("cutoff was calculated by dividing 10/L, where L is
  the minimum library size in millions"), then normalization by name (TMM), then a two-verb
  function chain that is internally inconsistent — dispersions are said to be estimated "with
  the glmFit function" (glmFit is normally the non-QL fit) while the model is still called
  "quasi-likelihood", and the test itself does use "the glmQLFTest function" — then a combined
  significance clause (FDR-adjusted P<0.001 and log2FC>1).

## PMC7713251 / PMID 33273453 — TGFβ enhancer chromatin opening (RNA-seq is limma, not edgeR)
- **Results presentation**: DE genes are shown as MA plots of log2FC vs average log2CPM
  ("Supplementary Fig. 4a"), CPM-distribution boxplots ("Supplementary Fig. 4b"), and a log2FC
  heatmap for selected genes ("Fig. 2h"); genes are then bucketed into
  early/late/transient-up/down categories using a |log2FC|>1 rule applied on top of the
  significance test, across two treatment timepoints (2 h and 12 h) vs vehicle.
- **Methods sentence structure**: names two packages side by side in one clause ("voom/limma
  (v.3.34.9) and edgeR (v.3.20.9) Bioconductor packages") but the actual test named afterward is
  purely a limma one, described only generically ("empirical BAYES moderated t-statistics test
  with adjustments for multiple comparison") — no eBayes()/voom()/lmFit() function names are
  given, and edgeR itself is not named again in this specific sentence. edgeR's own
  glmQLFit()/glmLRT() functions do appear elsewhere in the same Methods, but only for the
  ATAC-seq and ChIP-seq peak analyses (a separate paragraph), not this RNA-seq paragraph.

## PMC9710884 / PMID 36449607 — Zika virus sfRNA / ZIKV mutants, iPSC organoid RNA-seq
- **Results presentation**: no figure number is given in the Methods paragraph itself; DE
  results across three named contrasts feed a z-score/GOplot combined display and GO/KEGG
  enrichment via DAVID, plotted with ggplot2.
- **Methods sentence structure**: package+version first ("edgeR v.3.24.0"), filter and
  normalization stated as one sentence ("Low-abundance reads (<1 cpm) were removed... normalized
  to library sizes and composition bias using the trimmed mean of M values method"), then a
  model-building clause ("quasi-likelihood negative binomial generalized log-linear model"),
  then the explicit test function tied to three named contrasts ("The quasi-likelihood F test
  (glmQLFTest) was then applied to the contrasts WT-Mock, xrRNA2'-Mock, and (WT-Mock)-(xrRNA2'-
  Mock)"), then a separate significance-cutoff sentence (FDR-corrected P<0.05).

## PMC7665889 / PMID 33186096 — Smchd1 maternal-effect gene, allele-specific RNA-seq
- **Results presentation**: DE results are "visualized with Glimma", an interactive MD-plot
  tool, rather than a static main-text figure named in the Methods; a separate, non-edgeR-QL
  pipeline (logistic regression / beta-binomial) is used for the imprinted-gene analysis and
  reported as % silent-allele-proportion differences, so the QL-test results and the imprinting
  results are two visibly different result types in the same paper.
- **Methods sentence structure**: package+version+citation together ("edgeR v3.24.0 (Robinson
  et al., 2010; McCarthy et al., 2012)"), normalization named with its own citation ("TMM method
  (Robinson and Oshlack, 2010)"), the test named generically but with its own citation
  ("quasi-likelihood F-tests (Lun et al., 2016)"), correction named with citation
  ("Benjamini-Hochberg method (Benjamini and Hochberg, 1995)"), and finally a combined numeric
  cutoff in its own sentence ("adjusted p-value<0.05 and log2-fold-change>1") — i.e. every
  pipeline step gets its own literature citation, a distinctly citation-dense Methods style.

## PMC10620403 / PMID 37914685 — A2AR eGFP reporter mouse, sorted-cell RNA-seq
- **Results presentation**: DEGs (ranked by fold change) feed a pre-ranked GSEA against MSigDB
  Hallmark gene sets and a previously published STAT5 signature; visualized as row-mean-centered
  heatmaps (pheatmap) of log2(CPM+0.5) and a PCA on the most variable genes — no specific
  main-text figure number is given in the Methods paragraph itself.
- **Methods sentence structure**: package name given twice with two citation numbers but no
  version number ("EdgeR package58,59"), normalization named explicitly with its method
  ("TMM (trimmed means of M-values) method into log2 counts per million (CPM)"), the test
  described only descriptively, without an explicit function name ("The quasi-likelihood F test
  statistical test method based on the generalized linear model (glm) framework"), followed by
  two separate short sentences for correction (Benjamini-Hochberg) and cutoff (FDR<0.05).

## PMC7642293 / PMID 33144576 — SWI/SNF SMARCA4 knockdown, prostate cancer RNA-seq
- **Results presentation**: unsupervised clustering on the top 500 most-variable genes
  (Euclidean distance, Ward linkage) is described but not tied to a figure number in the
  Methods; DEGs (FDR<0.05, >2-fold) feed a GSEA Preranked run against C2 canonical-pathway and
  Hallmark ('H') gene sets, ranked by the T-statistic from the DE analysis.
- **Methods sentence structure**: package+version named mid-paragraph, after the CPM-filter
  clause ("Genes with log2-CPM <1 in more than three samples were removed ... performed using
  the edgeR v3.28.1 package"), then normalization and test named together in one sentence
  ("Normalization was performed using the 'TMM' (weighted trimmed mean) method and differential
  expression was assessed using the quasi-likelihood F-test"), then a combined significance
  clause in the next sentence (FDR<0.05 and >2-fold).

## PMC13558064 / PMID 42557328 — amygdala astrocyte primary cilium (edgeR used on snRNA-seq pseudobulk, not the paper's genuine bulk RNA-seq)
- **Results presentation**: the paper explicitly scopes down what it shows here — "We report
  the astrocyte data for the primary cilium-related genes here" — implying a gene-set-focused
  rather than genome-wide DEG table/volcano plot for this specific PSD-vs-control contrast; no
  figure number is given in the Methods paragraph.
- **Methods sentence structure**: fully "code-like" — package+version first ("edgeR (v.4.2.1)"),
  then the fit and test functions named explicitly with their parentheses ("quasi-likelihood
  negative binomial regression with glmQLFit(), and testing was carried out with
  glmQLFTest()"), then normalization and filter also given as explicit function calls in one
  sentence ("Normalization was conducted using the TMM method via calcNormFactors(), and lowly
  expressed genes were filtered with filterByExpr()"), then covariates named (age, sex, batch),
  then correction named (Benjamini-Hochberg) but with no accompanying numeric FDR cutoff in this
  sentence. Important: this is the paper's snRNA-seq-pseudobulk analysis; its separate, genuine
  bulk (RiboTag) astrocyte RNA-seq analysis, described earlier in the same Methods section,
  uses limma-voom instead of edgeR — so the two RNA-seq-shaped analyses in this one paper use
  two different packages depending on data origin (pseudobulked single-nucleus vs true bulk).

## PMC10619980 / PMID 37910019 — Drosophila sleep induction, whole-brain RNA-seq
- **Results presentation**: DEGs (dual criterion: FDR<0.05 and fold-change>1.5, reported in the
  Methods itself both as a fold-change and as the equivalent logfc>0.58) feed a DAVID GO
  enrichment run; no main-text figure or table number is given in the Methods paragraph.
- **Methods sentence structure**: the most citation-dense of the ten — package+version+citation
  first ("edgeR (version 3.16.5) (Robinson et al., 2010)"), then three separate clauses each
  crediting a different edgeR sub-step to its own paper: TMM normalization ("Robinson and
  Oshlack, 2010"), Cox-Reid profile-adjusted dispersion estimation ("McCarthy et al., 2012"),
  and the quasi-likelihood F-test itself ("Lun et al., 2016"); the low-expression filter (mean
  CPM<5 in both groups) and the dual significance criterion (FDR<0.05 and fold-change>1.5 / or
  logfc>0.58) are each given their own short sentence afterward.
