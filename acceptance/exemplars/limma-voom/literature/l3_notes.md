# limma-voom — L3 close-reading notes

Close reading of the 10 tier-A, most-parameter-rich exemplars (layer `L3+L4`). Own words;
quotes are verbatim fragments (<=25 words) copied from the Methods text retrieved via
`collect.py methods`. "not stated" where the Methods text gives no information on a point.

## PMC7755902 / PMID 33353943 — Asian breast cancers molecular landscape (TCGA + SD cohorts)
- **Results presentation**: DE genes feed pathway analysis via Reactome, restricted to the
  "top 1000 ranked genes" by absolute log fold-change, plus a separate GSEA (v3.0) run on
  quantile-normalised counts against Hallmark/KEGG gene sets; no specific main-text figure
  number is given in the Methods paragraph itself for the DE gene list.
- **Methods sentence structure**: normalization is described first, and attributed to a
  *different* package than the one that does the testing — "normalised using the 'Trimmed
  Mean of M-values' method implemented in the edgeR (v. 3.20.9) R package", then "transformed
  into logCPM using the voom function from the limma package" (no limma version repeated here,
  though limma v.3.34.9 is given earlier in a different subsection, for subtyping) — then the
  test is described only generically ("empirical Bayes moderation of the standard errors
  towards a common value from a linear model fit"), and finally a combined significance clause
  (FDR<0.001 and absolute log fold-change>0.2), with a second, much stricter pathway-analysis
  filter (FDR<1e-50) mentioned separately.

## PMC9724437 / PMID 36474250 — pan-cancer roles of primate-specific genes (TCGA)
- **Results presentation**: log2FC values from limma feed a rescaled ssGSEA display
  ("For Fig. 2b and c, we rescaled the raw enrichment scores"); a separate, stricter |log2FC|
  cutoff (0.6) is tested as a robustness check and shown in a supplementary figure ("the
  patterns shown in Fig. 2e were largely unchanged as in Fig. S2d").
- **Methods sentence structure**: normalization and the voom call are folded into one clause
  describing the overall workflow ("after performing routinely used upper-quantile
  normalization and voom transformation") rather than naming discrete functions; the package
  and version are given separately and only once ("we implemented the widely used limma
  package v3.34.9"); the significance criterion (FDR<0.05) and the fold-change filter
  (|log2FC|>=0.4) are introduced in two separate sentences, several sentences apart, each
  tied to a different purpose (defining DE genes, then further filtering the DE list).

## PMC13506345 / PMID 42581186 — MDA5 activation via intron-retained RNA (cytoplasmic RNA-seq)
- **Results presentation**: the most figure-rich of the ten — intron-level DE results are shown
  as mean-difference plots (log2 average expression vs log2 fold change), and gene-level
  exon-vs-intron log2FC comparisons are also plotted per gene, both highlighting genes passing
  "Benjamini-Hochberg adjusted P values < 0.05"; a separate `roast` gene-set test against iCLIP
  peak scores is visualized with `barcodeplot`, comparing genes/introns "with scores higher
  than the 95% percentile" against a null.
- **Methods sentence structure**: exceptionally explicit and code-like, naming a full function
  chain in build order — filter ("filterByExpr function, incorporating the design matrix"),
  normalization ("calcNormFactors function with the TMM method"), transform+fit
  ("voom method ... a linear model was fit using the edgeR voomLmFit function"), contrast
  ("contrasts.fit function from the limma package (v.3.50.0)"), and finally two parallel test
  calls for two different purposes — "the treat function for differential expression analysis"
  (with an explicit 1.2-fold-change argument) "or ... the eBayes function ... for subsequent
  comparison to iCLIP data" (no fold-change threshold) — i.e. the same fitted model is tested
  two different ways depending on what the result will be used for.

## PMC10637000 / PMID 37950299 — transposable-element-mediated cis-regulation (voom is not the RNA-seq test here)
- **Results presentation**: not applicable to limma-voom for this paper — its bulk RNA-seq DE
  calling (Methods > Differential expression analysis-based cis-regulatory TE subfamily
  detection) uses edgeR's classic `exactTest`, reporting DE genes at two alternative
  stringencies side by side ("Benjamini-Hochberg adjusted p values <0.05 (stringent DE
  calling), or ... p values < 0.05 (lenient DE calling)"), then combines up/down-regulated
  results into "a single table" ranked by AUC against a CRISPRi-derived ground truth.
- **Methods sentence structure**: VOOM appears in a completely different Methods subsection
  (Methods > ChIP-seq) describing differential ChIP-seq peak binding — "Differential analysis
  between conditions has been performed with VOOM ... counted on the union of all peaks" —
  with normalization named separately and attributed explicitly to the limma package ("using
  the TMM method ... as it is implemented in the limma package of Bioconductor"). This is a
  clean example of a paper where the voom/limma signal that the retrieval regex picks up
  belongs to a ChIP-seq peak analysis, not the bulk RNA-seq gene-expression analysis.

## PMC8664842 / PMID 34893606 — KDM6B / CDK4/6-pRB-E2F pathway (RNA-seq + microarray + ATAC-seq + CUT&Tag)
- **Results presentation**: the RNA-seq DEG list (FDR<0.05) is used as input to GSEA;
  a parallel Affymetrix microarray dataset is analyzed by t-test (not limma) for comparison,
  so the paper juxtaposes an RNA-seq/limma-voom result against a microarray/t-test result for
  the same biological question; no figure number is given for the RNA-seq DEG list itself in
  the Methods paragraph.
- **Methods sentence structure**: unusually terse for the RNA-seq part — a single sentence
  names both steps together without a package version ("Counts were normalized with VOOM and
  analyzed with LIMMA within the R statistical environment"), followed immediately by the
  significance sentence ("Significance was defined as having a false discovery rate (FDR) <
  0.05"). This contrasts with the same paper's ATAC-seq/CUT&Tag paragraphs elsewhere in the
  Methods, which name explicit versions for R, edgeR and limma.

## PMC9683707 / PMID 36417539 — EPAS1 enhancer, hypoxia response (two independent bulk RNA-seq experiments)
- **Results presentation**: a custom "blunting score" is computed from the DE results
  (an interaction term between genotype and condition) and tested for a shift from zero with a
  one-sample t-test; a second, independent mouse-tissue RNA-seq experiment's per-tissue P
  values are converted to z-scores and combined across seven tissues with `mashr`, so the
  DE test itself is only an intermediate step feeding a cross-tissue meta-analysis, not a
  per-tissue volcano/MA plot.
- **Methods sentence structure**: both experiments use the identical short phrase "limma-voom
  with default settings" — package name plus the qualifier "default settings" standing in for
  any stated filter, normalization or eBayes argument; the only parameter given anywhere is a
  filter, and only in the second (mouse tissue) experiment ("filter_by_expression() function in
  EdgeR"), not repeated in the first (cell-line) experiment's paragraph.

## PMC13558064 / PMID 42557328 — amygdala astrocyte primary cilium (RiboTag bulk RNA-seq)
- **Results presentation**: region-specific astrocyte genes are defined by comparing one
  region's IP samples "with the average of IP samples from the other 13 regions", i.e. a
  one-vs-rest design across 14 CNS regions combined by batch correction, rather than a single
  two-group comparison; no figure number is given for this specific bulk RNA-seq DEG list in
  the Methods paragraph itself.
- **Methods sentence structure**: package+version+threshold given together in one sentence
  ("Bioconductor package limmaVoom (v.3.60) with the adjusted P value threshold set at
  <0.05"), immediately followed by a second, differently-purposed threshold sentence defining
  "astrocyte-enriched genes" (log2[IP/input] > 1, adjusted P < 0.05, IP FPKM > 1) — i.e. two
  distinct significance criteria appear back to back for two different gene-list definitions,
  and neither a filter nor a normalization method is named for the underlying limma-voom call
  itself (batch correction via RUVr is described instead, one sentence earlier).

## PMC10667096 / PMID 37903863 — MASLD integrated gene-to-outcome database
- **Results presentation**: DEGs (F3/F4 vs F0/F1 fibrosis stage) feed a `glmnet` lasso-penalized
  Cox regression to build a prognostic signature, then a Kaplan-Meier/time-dependent ROC
  analysis; a `shiny`-based gene browser is built for interactive exploration, so the intended
  "figure" is explicitly an interactive app rather than a static plot ("A 'shiny' interface was
  created to allow scientists to visualize the results ... according to NASH-CRN fibrosis
  stage").
- **Methods sentence structure**: package+version stated as a single quoted tool name
  ("'limma-voom' (v.3.28.14)"), normalization named in its own short sentence beforehand
  ("Reads were normalized using the weighted trimmed mean of M values method"), and the
  significance criterion combines both an adjustment method and a fold-change cutoff in one
  sentence ("an adjusted P value according to the Benjamini-Hochberg procedure of P < 0.05 and
  absolute FC >=1"); the same cutoff sentence is repeated verbatim later in the Methods for a
  second comparison (F3/F4 vs F0/F1 again, in a different paragraph), i.e. the paper restates
  its own criterion rather than cross-referencing it.

## PMC10635649 / PMID 37902626 — colour polymorphism in a moth (wing developmental RNA-seq)
- **Results presentation**: DE genes are called separately per developmental stage from a
  contrast matrix (four stage-specific genotype contrasts: h72, d5, Premel, Mel), so the result
  is a set of four parallel gene lists rather than one; genome-wide expression is also checked
  with an MDS plot ("evaluated the genome-wide gene expression using MDS using the plotMDS
  function of the limma package") as a QC/overview figure rather than the DE result itself.
- **Methods sentence structure**: the fullest function chain of the ten — filter
  ("filterByExpr function in limma"), with the actual gene-count-reduction numbers given in
  the same sentence (17,615 to 11,330 genes); normalization ("calcNormFactors function with TMM
  normalisation in limma"); fit ("fit the design matrix using the voom function"); contrast
  ("fit the contrast matrix to the data using the contrasts.fit function"); and test ("used the
  eBayer function on the fit dataset" — apparently a typo for eBayes) — each step in its own
  clause, in the exact order the code would call them, ending with the correction method
  (Benjamini-Hochberg) in a final clause of the same long sentence.

## PMC7673985 / PMID 33203890 — upper airway gene expression, COVID-19 vs other respiratory viruses
- **Results presentation**: DE p-values from three-group comparisons (SARS-CoV-2 / other virus
  / no virus) feed a heatmap built from "the union of the top 50 genes (by p-value) in each of
  the pairwise comparisons among the three groups (n = 121 genes)", using a *different*
  transformation (DESeq2's variance-stabilizing transformation, not voom output) for the
  heatmap display than for the DE test itself; a second, independent nasopharyngeal-swab
  dataset is re-analyzed with the identical limma/voom recipe for replication, described in a
  separate but nearly identical sentence.
- **Methods sentence structure**: package+version+normalization+method named together in one
  sentence ("R package limma50 (v. 3.42) using quantile normalization, the voom method, and the
  design: ~0 + viral status + gender + age"), with the covariate design formula spelled out
  inline as part of the same sentence rather than described separately; the test itself is
  named only descriptively ("a moderated t-statistic"), and the correction method
  (Benjamini-Hochberg) is given in the next sentence, without a numeric cutoff for the primary
  three-group DE analysis (a cutoff appears later, but for a distinct downstream regression
  analysis against viral load).
