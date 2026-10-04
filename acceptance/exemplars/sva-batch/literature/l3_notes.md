# sva-batch — L3 close-reading notes

One entry per L3+L4 exemplar: how the results of the ComBat/ComBat-seq/sva batch-correction step
are presented (figures, thresholds), and how the Methods sentence is built (software + version +
function + key arguments), with special attention to what the corrected matrix (or the surrogate
variables) was actually used for afterwards -- this project's key misuse question. Quotes are
verbatim and <= 25 words. "not stated" where the Methods region retrieved gives no such detail.

## PMC7737297 / PMID 33317623 — Convergent network effects along the axis of gene expression during prostate cancer progression (_applies: yes)
The Methods sentence is terse to the point of being under-specified for this parameter set: "Read
count normalization and differential gene expression analysis was performed using the R packages sva
[100] and DESeq2 [101]." No version number, no `num.sv`/`mod` formula, and — critically — no statement
of *how* sva's surrogate variables were combined with DESeq2 (as design covariates, vs. an explicit
adjustment of the count matrix before testing). Because DESeq2's design formula is never shown, a
reader cannot tell whether this is the textbook-correct "SVs as covariates" pattern or something else.
Downstream, the paper reports "Gene expression changes with an adjusted P value < 0.1 were considered
significant," but does not tie this threshold back to the sva step specifically. This is a good example
of a paper that clearly performs the batch/surrogate-variable step but does not give enough detail in
the Methods for an external reader to reconstruct exactly how it entered the model.

## PMC8849344 / PMID 34939926 — Extent, impact, and mitigation of batch effects in tumor biomarker studies (_applies: no, but instructive)
This whole paper is *about* comparing batch-correction strategies (including ComBat) on protein
immunohistochemistry biomarker scores from tissue microarrays — not RNA/microarray gene expression, so
it is coded `_applies: no` for this module, but it is unusually explicit about ComBat's assumptions and
limits: "ComBat and its derivatives... were initially designed for microarray studies of gene
expression, which include considerably more than one biomarker per sample. This property would
typically limit their use for a protein biomarker quantified on a TMA." The corrected values are then
explicitly fed forward into association testing: "we... estimated associations between Gleason score
and biomarker levels after batch effect mitigation, stratifying by batch" — i.e., the corrected data is
used directly as regression input, exactly the "corrected data used for differential/association
testing" pattern this project is tracking, just demonstrated outside the gene-expression domain the
module targets.

## PMC7775110 / PMID 33305733 — The leukocyte non-coding RNA landscape in critically ill patients with sepsis (_applies: yes)
Clean two-step sentence: "data were evaluated for non-experimental chip effects by means of surrogate
variable analysis (SVA; version 3.28) and adjusted using the combat method (Leek and Storey, 2007)."
The corrected matrix is then explicitly the input to the differential-expression step a few sentences
later: "Comparisons between study groups were done using the limma method (version 3.36)." This is a
rare case in the corpus where the paper gives both the sva version (3.28) and the downstream DE tool's
version (limma 3.36) side by side. No `num.sv`/`mod` formula is given, and no figure/threshold ties
specifically to the SVA/ComBat step (the volcano plots, PCA and dot plots mentioned generically in the
Statistical Methods section belong to the paper as a whole, not to this step in particular).

## PMC8686573 / PMID 34930405 — Chronos: a cell population dynamics model of CRISPR experiments (_applies: no)
ComBat is applied to CRISPR gene-essentiality/fitness-score matrices (Achilles/Project Score Bayes
factors and CERES/Chronos gene-effect scores), not bulk gene-expression data: "Batch effects between
the cell line batches were removed by ComBat." This is a useful counter-example for the module's scope:
the exact same tool, applied to a conceptually similar "matrix of numbers per gene per sample," is
excluded here because the values are CRISPR viability/dependency scores rather than expression levels.

## PMC7705019 / PMID 33257699 — Genomic and transcriptomic alterations associated with drug vulnerability (_applies: yes)
"The ComBat function implemented in the R package sva (v3.28.0) was used to remove the batch effect of
different data sources (i.e., data source as a batch parameter)." The paper is explicit and somewhat
unusual about validating the correction rather than just applying it: "The GSVA scores of featured
pathways and gene signatures in either cohort before and after the processing were highly correlated,"
i.e., they checked that ComBat did not distort downstream pathway/immune-deconvolution scores. The
corrected matrix itself is then "used... for comparative analyses" (cross-cohort TPM comparison,
downstream GSVA and immune-cell-fraction estimates) — a visualization/comparison use rather than a
formal hypothesis test with its own p-value cutoff.

## PMC8744672 / PMID 34903527 — Diverse tumorigenic consequences of human papillomavirus integration (_applies: yes)
"Resulting log2 TPM values were normalized and batch-corrected using Bioconductor SVA function ComBat."
The corrected values feed two separate Z-score-based analyses (gene-level outlier expression near HPV
breakpoints, and exon-level coverage ratios at HPV chimeric-transcript junctions), each converted to a
Z-score and tested with a one-tailed binomial test or chi-squared distribution — i.e., the ComBat output
is the direct input to a formal significance test, just one built from Z-scores rather than
limma/DESeq2's own framework. FDR correction is applied to the resulting P-values, but no adjusted-p
cutoff value is stated in the retrieved Methods (only "P-values were adjusted by FDR multiple testing
correction").

## PMC7784531 / PMID 33242409 — DNA Damage Baseline Predicts Resilience to Space Radiation and Radiotherapy (_applies: no)
ComBat ("Batch effects were corrected using Com-Bat... from the surrogate variable analysis package of
R") is applied to quantitative imaging and flow-cytometry features (DNA-damage foci counts per nucleus,
oxidative-stress signal), not RNA-seq or microarray gene expression — no expression platform is
mentioned anywhere in this paper's Methods. It is a clean illustration that "surrogate variable
analysis" and "ComBat" appear routinely outside transcriptomics, so the regex candidates that flagged
this paper needed a full read to rule out.

## PMC13510735 / PMID 42647619 — Algae-specific immune modulation influences responses to heat and pathogens (_applies: yes)
The most methodologically transparent ComBat-seq sentence in the corpus, including an explicit sanity
check: "we applied ComBat-seq as the covariate and temperature as the variable of interest... This
correction removed host genotype-associated variation while preserving temperature-associated
biological variation... batch-corrected data were then included in a DESeq2 model." Crucially, the
authors also ran the *uncorrected* data through parallel DESeq2 models (`~genotype + treatment +
genotype:treatment`, and per-symbiont-type models) specifically "to confirm that this normalization
approach did not influence our conclusions," reporting that "all analyses yielded consistent results."
This is the strongest example in the corpus of a paper validating that ComBat-seq correction doesn't
manufacture its own DE signal, directly relevant to the corrected_used_for misuse question.

## PMC10703692 / PMID 38036788 — Isoform-level transcriptome-wide association uncovers genetic risk mechanisms (_applies: yes)
Full software+version+function+argument sentence: "Isoform- and gene-level expression was then
batch-corrected using ComBat (sva v3.46.0), using study site as the batch." Distinctively, the batch
correction is only one of several adjustment steps applied in sequence before the expression matrix is
used for its real purpose (eQTL/isoQTL mapping and TWAS model training): age, age-squared, sex, 10
genotype PCs, and 175-200 "hidden covariates" (PEER/HCP-style factors, not sva's own `num.sv` output)
are removed afterward. This is a good example of ComBat being one stage in a longer
covariate-adjustment pipeline feeding a reference panel, rather than the last step before a single
DE test with its own p-value cutoff.

## PMC12667713 / PMID 41125444 — Interpretable phenotype decoding from multicondition sequencing data (ALPINE) (_applies: yes, atypical)
This is a methods/benchmarking paper, not a biological-finding paper: ComBat is one of several batch
tools (alongside Scanorama, Seurat, Harmony, LIGER, scVI, MNN) benchmarked on *simulated* single-cell
data (Symsim) and on pseudobulk aggregates, explicitly to score how well each tool's correction
"disentangles" batch from biology using ARI/NMI/ASW metrics. The direct DE-testing use is stated
plainly: "We compared using either ComBat... or Scanorama... for batch correction... We then compared
using either a Wilcoxon rank-sum test or t-test for differential gene expression analysis," i.e. the
corrected matrix goes straight into a two-group test to measure how many of the ground-truth perturbed
genes each combination recovers (AUPRC). Because the "biological" data here is simulated ground truth,
this paper is a good illustration of ComBat's correctness being the object of study rather than an
assumption the paper is relying on.
