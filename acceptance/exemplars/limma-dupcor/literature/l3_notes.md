# limma-dupcor — L3 close-reading notes

One entry per L3+L4 exemplar: how the results of the duplicateCorrelation/lmFit(block=) analysis
part are presented (figures, thresholds), and how the Methods sentence is built (software +
version + function + key arguments). Quotes are verbatim and <= 25 words. "not stated" where the
Methods region retrieved gives no such detail (figure/threshold callouts often sit in Results).

## PMC9668748 / PMID 36323788 — Broad transcriptomic dysregulation across the cerebral cortex in autism (_applies: yes)
Methods sentence names the package but not a version: "The limma R package was used to identify
differentially expressed genes and transcripts in ASD... The limma::duplicateCorrelation function was
used to account for the non-independence of samples derived from the same subject across multiple
brain regions." The blocking unit (same subject, multiple cortical regions) is stated in plain prose
rather than as a `block =` code fragment. Significance is "FDR-corrected P-value <0.05" but the
correction method itself (BH vs. other) is never named. A separate slope-based cross-region comparison
(orthogonal/total-least-squares regression of log2FC) is described as the main figure output (Fig. 1e),
but that is a downstream summary statistic built from the limma results, not itself part of the
duplicateCorrelation model. No consensus-correlation number or two-round voom/dupCor loop is reported.

## PMC10686561 / PMID 38019916 — High-throughput proteomics uncovers exercise training and T2D signatures (_applies: yes)
Unusually explicit, ordered Methods sentence: "the batch effect was added as a covariate... the lmFit
(Limma) function was applied. The average intersubject correlation was estimated by the
duplicateCorrelation function (Limma) and added to the linear model. Empirical Bayes smoothing... were
computed by the eBayes function." Threshold is stated as a relatively loose "significance level set to
10% FDR" after Benjamini-Hochberg adjustment — one of the few papers in this corpus explicit about
using a non-5% FDR cutoff. Figures: PCA (Fig. 1E) is explicitly tied to a *different* limma call
(`removeBatchEffect`, for visualization only), which the Methods carefully distinguishes from the
`lmFit`/`duplicateCorrelation`/`eBayes` chain used for actual DE testing — a clean illustration of the
visualization-vs-testing distinction this project also tracks for sva-batch.

## PMC9237031 / PMID 35760976 — The 22q11.2 region regulates presynaptic gene products (_applies: yes)
Two parallel duplicateCorrelation analyses live in one paper (RNA-seq/Limma-voom and TMT-like
proteomics/Limma), which makes the Methods reading order-dependent: the RNA-seq sentence ("we used
Limma-voom package that enabled to model the non-independent experimental replicates from each clone
with the duplicateCorrelation function... included in the design model by the block design in Limma")
gives no numeric consensus correlation or version, while the proteomics sentence a few lines later
("average estimated inte-replicate correlation was 0.83") does. A careless read could misattribute the
0.83 correlation or the "(v. 3.3.49)" version string to the RNA-seq clone comparison; they belong to the
protein-abundance model instead. No figure/threshold for the RNA-seq dupCor step itself is stated in
the retrieved Methods.

## PMC7695459 / PMID 33169669 — 16p11.2 microdeletion imparts transcriptional alterations in human iPSC (_applies: yes)
The dupCor analysis is explicitly framed as a secondary "validation" method, not the primary DESeq2
pipeline: "The validation differential expression method was performed on integration-negative clones
using the limma/voom pipeline... duplicateCorrelation() applied to account for clone donor through a
linear mixed model. A linear model was fit... using lmFit()... Standard error smoothing using eBayes()
was performed." The Methods sentence walks through the full function chain (voom -> duplicateCorrelation
-> lmFit -> makeContrasts/contrasts.fit -> eBayes) in the order the code was run, ending in a
Benjamini-Hochberg adjusted p<0.05 cutoff — a good template of the "structured" Methods sentence this
project is tracking. Figures: not stated for this validation branch specifically (the primary DESeq2
comparison's shrunken-log2FC figure is described separately).

## PMC9151768 / PMID 35637184 — Cellular and genetic drivers of RNA editing variation in the human brain (_applies: yes)
Two dupCor uses back-to-back: RBP differential expression ("Donor as a repeated measure was controlled
for using the duplicateCorrelation function in limma") and differential-editing-level analysis
("covarying for the possible influence of age, PMI, and donor as a repeated measure using the
duplicateCorrelation function... adjusted... using the Benjamini and Hochberg (BH) method... P value
<0.05 were labeled significant"). Neither sentence gives a limma version number or a numeric consensus
correlation. The paper is a good illustration of "donor" being the repeated-measures unit across two
conceptually different outcome types (RBP expression vs. per-site editing level) using the same
duplicateCorrelation call structure. Figures/thresholds beyond p<0.05: not stated in the retrieved
Methods.

## PMC8971130 / PMID 35140405 — Early prediction of preeclampsia in pregnancy with cell-free RNA (_applies: yes)
The clearest "two-round" duplicateCorrelation example in the corpus, explicitly citing the limma-voom
guide's recommended iteration: "Per the Limma-Voom guide, to account for sample auto-correlation over
time, we ran the function voomWithQualityWeights twice. We first ran it without any blocking on
participant identity... to approximate sample auto-correlation... using duplicateCorrelation. After
estimating correlation, voomWithQualityWeights was run again, this time blocking for participant
identity." A linear model is then fit with `lmFit`, contrasts taken with `makeContrasts`, and
`eBayes` applied — with BH correction at 0.05. This is the one paper where "two_rounds" should be coded
"yes" with confidence rather than inferred; the code-level narrative closely mirrors the official limma
User's Guide recipe. Figures: DEG counts per contrast are given in prose (1,759 / 1,198 / 503 / 330
DEGs) rather than tied to specific figure numbers in the retrieved Methods text.

## PMC7936006 / PMID 33674584 — Mitochondrial arginase-2 is essential for IL-10 metabolic reprogramming (_applies: yes)
An Affymetrix Mouse Genome 430_2 array analyzed with limma + duplicateCorrelation, explicit about using
an *unadjusted* p-value: "Mouse donor was incorporated as a blocking factor in the linear model, with
inter-subject correlation obtained using the duplicate Correlation function... Differentially expressed
probes were selected using an unadjusted p-value < 0.05 and an absolute log2(fold change) >1." This is
a useful negative example for the padj_cutoff/p_adjust_method fields: the paper is explicit that no
multiple-testing correction was applied to the reported cutoff, which a naive "p<0.05" regex match
would otherwise mis-code as an adjusted-p threshold. Figures: romer-based GSEA (C5 GO sets) is the
downstream visualization, not itself tied to a specific threshold statement in the Methods.

## PMC7063821 / PMID 32151270 — Hemispheric asymmetry in the human brain and in Parkinson's disease (_applies: yes)
DNA-methylation (M-value) analysis, not gene expression, but built on the same limma/duplicateCorrelation
machinery: "we added in the limma model a blocking factor to define samples from the same individual
and a correlation coefficient determined by the duplicateCorrelation function," blocking on "both
hemispheres from the same individual" in the replication cohort only (the discovery cohort apparently
has one hemisphere per person, so no blocking there — a detail easy to miss on a fast read).
Significance: Benjamini-Hochberg FDR q<0.05, contrast-by-contrast. Version is given for limma
(v3.30.13) and for lumi (v2.30.0, used for the beta-to-M-value transform) side by side, which is a
clean two-package version statement. Figures/thresholds beyond q<0.05: not stated in the retrieved
Methods.

## PMC10349101 / PMID 37452040 — Increased BMI is linked to systemic inflammation through adipose changes (_applies: yes)
ATAC-seq peak-level (not gene-level) differential accessibility, using voom+limma+duplicateCorrelation
with family structure as the blocking factor rather than a simple repeated-individual design: "We used
the duplicateCorrelation function in limma to account for the repeated measure from the same
individual... the family ID as a blocking factor." Age, sex and FRiP are named as covariates alongside
the blocking factor in the same sentence, and the paper explicitly separates two BMI-stratified
sub-cohorts tested independently with the same pipeline. Significance is "FDR <0.05" with no
correction-method name given. Figures: not stated in the retrieved Methods (WGCNA module follow-up is a
separate downstream section).

## PMC10259477 / PMID 37284822 — Neural circuit-wide analysis of changes to gene expression during deafening (_applies: yes)
The most code-narrated Methods paragraph for this parameter set in the whole corpus: it names the
"consensus correlation approach implemented in limma/voom," specifies `block` as compound (bird ID +
brain region, or bird ID + hemisphere for a second dataset), walks through
`duplicateCorrelation -> lmFit -> contrasts.fit -> eBayes -> topTable` in execution order, and states a
DE cutoff of adjusted p<0.1 (looser than the conventional 0.05) via the Benjamini-Hochberg method
inside `topTable`. It is also the paper most explicit that "these samples are not fully independent...
we considered these samples as technical replicates," directly motivating the blocking choice. No
numeric consensus-correlation value is given, only that it was estimated and passed into `lmFit`.
Figures/thresholds beyond adjusted p<0.1: not stated in the retrieved Methods (fgsea pathway figures are
a separate downstream analysis with their own 0.01/0.05/0.2 thresholds).
