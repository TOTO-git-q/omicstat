# limma-array — L3 close-reading notes

One entry per L3+L4 exemplar: how the results of the microarray/limma analysis part are
presented (figures, thresholds), and how the Methods sentence is built (software + version +
function + key arguments). Quotes are verbatim and <= 25 words. "not stated" where the Methods
region retrieved gives no such detail (figure/threshold callouts often sit in Results, outside
the Methods text this project extracts from).

## PMC12764432 / PMID 41461987 — Antigen reactivity defines tissue-resident memory and exhausted T cells (_applies: no)
This is not a limma-array case: limma's `lmFit` is used to fit linear models on RUV-III-normalised
RNA-seq/pseudobulk count matrices (bulk and pseudobulk contrasts), not on RMA/quantile-normalised
microarray intensities. The one genuine microarray dataset in the paper ("normalized microarray data
... downloaded from cBioPortal") is only fed into the `genefu` `sig.score` function for a published
signature score, never into limma's own fitting/testing machinery. Methods sentence structure: package
name and function ("The limma package was used to fit gene-wise linear models for the given group
structure with the output from RUV-III as an additional model covariate") but no version number, no
normalization step named, and no eBayes/topTable call spelled out. Figures/thresholds: not stated in
the retrieved Methods text (the log2FC scatter and barcode plots that use limma's output are described
in the Results/legends, not here).

## PMC7775110 / PMID 33305733 — The leukocyte non-coding RNA landscape in critically ill patients with sepsis (_applies: yes)
A textbook microarray pipeline: two Affymetrix arrays (HTA 2.0 mRNA array and miRNA 4.1), RMA
background-correction + quantile normalization + log2 transform via `oligo`, SVA/ComBat batch
adjustment, `genefilter` low-expression probe removal, then "comparisons between study groups were
done using the limma method (version 3.36)" with age/sex as additive covariates and a
Benjamini-Hochberg adjusted p<0.01 cutoff. The Methods sentence names software, version and the
significance rule in one place, which is unusually complete for this corpus. No p<0.01 volcano/heatmap
figure is called out inside the Methods text itself (that lives in Results); thresholds are stated in
prose ("significance was demarcated by Benjamini-Hochberg multiple test adjusted probabilities
(adjusted p<0.01)") rather than tied to a specific figure number.

## PMC10709144 / PMID 38049604 — Prostate lineage-specific metabolism governs luminal differentiation (_applies: no)
Not a limma-array case: the passage that names limma is "We used R package limma (v.3.17) ... to fit
each gene in the RNA-seq to the model," applied to log2-transformed TPM values from an RNA-seq
two-factor design, with empirical Bayes moderation and BH-adjusted P<0.01 plus |log2(Coefficient)|>1.
No microarray platform, probe design or array-normalization step appears anywhere near this sentence.
Figures: not stated in the retrieved Methods (Venn diagrams and a clustering heatmap are mentioned as
downstream outputs, but without figure numbers or thresholds attached to the limma step itself).

## PMC8664842 / PMID 34893606 — KDM6B promotes activation of the oncogenic CDK4/6-pRB-E2F pathway (_applies: no)
The paper runs three separate DE analyses side by side (RNA-seq+VOOM+LIMMA, Affymetrix microarray,
and CUT&Tag peaks+VOOM+LIMMA+edgeR), which makes it a good negative control for the module: only the
RNA-seq/CUT&Tag paths use limma; the actual Affymetrix microarray comparison is explicitly done "using
GenePattern program," a t-test tool, not limma. Methods sentence for the microarray part therefore
never mentions limma at all ("we first identify differentially expressed genes in microarray data
using GenePattern program"), while the limma sentence ("Counts were normalized with VOOM and analyzed
with LIMMA within the R statistical environment") is tied to RNA-seq counts. Figures/thresholds for
the microarray comparison: not stated beyond "logFC >= 0.7" used later to select genes for LINCS
comparison, which is downstream of GenePattern, not limma.

## PMC13488902 / PMID 42616886 — Isocaloric switch from low-fat to Western high-fat diet (_applies: yes)
Agilent 8x60K one-color expression arrays, background correction + quantile normalization inside
limma, explicit probe QC (control probes, no-symbol probes, low-background genes excluded; duplicate
probe IDs averaged by mean), paired empirical-Bayes linear model (age/sex covariates), BH-adjusted
P<0.05 defining "significantly differentially expressed," and a *separate* downstream |log2FC|
0.5/0.8 threshold used only to shrink the gene list handed to DAVID pathway enrichment (not to call
DEGs). This is a useful example of a paper reporting a fold-change number that a naive regex would
mis-attribute to the DEG-calling step; reading the paragraph in full is needed to see it belongs to the
enrichment step instead. Figures: not stated in the retrieved Methods text; the WGCNA module figures and
volcano-style DEG summaries are Results-section content.

## PMC9825120 / PMID 36516757 — The hepatic integrated stress response suppresses the somatotroph axis (_applies: yes)
Very compact Methods sentence for an Affymetrix GeneChip mouse 430A array: "RMA normalization was
applied and the limma package was used to identify the differentially expressed genes. Differentially
expressed genes were selected using the Benjamini-Hochberg method to control the FDR at 15%." Notably
the FDR threshold used to call significance (15%) is looser than the conventional 5%, and this is
stated as plain prose rather than tied to a numbered figure or table; no software version, no probe
filter, and no eBayes options are given. Figures/thresholds beyond the 15% FDR: not stated in the
retrieved Methods (downstream figures use asterisk-coded significance from unrelated t-tests, not this
microarray comparison).

## PMC8656144 / PMID 34887515 — Supermeres are functional extracellular nanoparticles (_applies: no)
Limma here is applied to a proteomics dataset (spectral counts of sEV/exomere/supermere fractions,
log2-transformed), not microarray gene-expression intensities: "Differential expression between sEVs,
NV fractions, exomeres and supermeres was identified using Limma. Proteins with a fold change > 2 and
a FDR < 0.05 were considered to be significantly differentially expressed." The Methods sentence gives
a clean fold-change (>2) + FDR (<0.05) pair, but for protein spectral counts rather than array
intensities, so it is excluded from this module's V counts. Figures: not stated in the retrieved
Methods (GSEA figures reference MSigDB gene sets downstream of this cutoff).

## PMC13558077 / PMID 42587147 — Rb-driven transcription limits its tumour-suppressive effects in breast cancer (_applies: yes)
Clean, self-contained microarray Methods paragraph: CEL files read via `oligo::read.celfiles`, RMA
normalization with `target='core'`, probeset-to-gene mapping via `affycoretools::annotateEset`,
low-expression filtering by a median-intensity threshold of 1.5 chosen "through visual inspection of
transcript median distributions in histogram plots," then "differential expression analysis was
conducted using the limma R package... to identify genes significantly altered between control and
palbociclib-treated groups" — with no significance cutoff (p/FDR/logFC) stated for this specific
comparison anywhere in the retrieved Methods text. This is a case where the pipeline up to model
fitting is described in full but the final decision rule for "significantly altered" is left
unspecified. Figures/thresholds: not stated in the retrieved Methods (a separate DESeq2 RNA-seq
analysis in the same paper does report "adjusted P < 0.05" and ComplexHeatmap visualization, but that
is a different analysis, not this microarray one).

## PMC13506345 / PMID 42581186 — Loss of cellular RNA homeostasis contributes to MDA5 activation (_applies: no)
Not a limma-array case: this is an RNA-seq exon/intron-level analysis using `voomLmFit`, `treat`
(1.2-fold threshold) or plain `eBayes`, and `contrasts.fit`, all downstream of `filterByExpr` and
`calcNormFactors` on featureCounts output — no microarray platform is involved. The Methods sentence
is unusually complete on software+version+function+arguments: "Comparisons ... were made using the
contrasts.fit function from the limma package (v.3.50.0)... Empirical Bayes moderated t-tests were
performed against a 1.2-fold change threshold ... using the treat function ... or without a fold
change threshold using the eBayes function." Figures: mean-difference plots and Benjamini-Hochberg
adjusted P<0.05 are described as the visualization/threshold for the intron-retention results, but
that is the DESeq2/IRFinder branch, not this limma-voom branch specifically.

## PMC7648065 / PMID 33159086 — Tp63-expressing adult epithelial stem cells cross lineage boundaries (_applies: yes)
Affymetrix "gene chip cDNA microarrays" (Rat Expression Array 230 2.0 or Rat Gene ST 1.0), processed
"by the Lausanne Genomic Technologies facility using standard protocols" (no normalization algorithm
named), then "P values were calculated using Bioconductor limma package to identify differentially
expressed genes from each group and probe sets with a false discovery rate, p values < 0.05 were
considered significant." The FDR method itself (BH vs. Storey vs. other) is never named, only "a false
discovery rate," which is a recurring gap in this corpus: papers state they controlled FDR without
naming the correction algorithm. Figures/thresholds beyond p<0.05: not stated in the retrieved Methods;
a companion RNA-seq (not array) comparison in the same paper does report an explicit "log2 Fold-change
higher or lower than 2 and an adjusted p value < 0.05" with Benjamini-Hochberg named, but that is the
RNA-seq section, distinct from this microarray section.
