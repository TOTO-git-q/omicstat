# deseq2-qc — L3 close-reading notes

Ten L3+L4 exemplars. For each: how the module's analysis part (vst/rlog for QC or visualization)
is presented in the results (figures/thresholds, as far as the retrieved Methods text states them),
and how the Methods sentence is built (software + version + function + key arguments). Quotes are
paraphrased/short (<=25 words) and in my own words otherwise. "not stated" where the retrieved
Methods text gives nothing to go on.

## PMC13584385 / PMID 42754892 — Genome Biology (_applies: no)
Results presentation: not stated. The vst-normalized values feed straight into a per-patient
log2 fold-change and a "top 50 genes" DEG list that is later used as one input track for a TADA-based
variant-prioritization pipeline; no PCA, heatmap or sample-distance figure is described for the vst
step itself in the retrieved Methods text.
Methods sentence structure: two clauses in one sentence — first names the software+version+function
for testing ("DESeq2 (v1.26) function DESeq"), computing a single-sample-vs-cohort comparison; then,
in the same sentence, names the transform ("normalized the results using vst") purely as a step before
computing Log2FC. No blind or ntop argument is mentioned for vst.

## PMC7781603 / PMID 33337321 — eLife (_applies: no)
Results presentation: not stated as a labeled figure. vst-transformed RNA-seq values are one of six
tracks (alongside ChIP-seq and DNA methylation) fed into a UMAP embedding of 10 kb genomic windows/genes;
the two resulting UMAP clusters ("Group1"/"Group2") are separated "based on visual assessment", not a
numeric cutoff.
Methods sentence structure: names the software only in passing ("variance stabilizing transformation
(vst) features of DESeq2", citing Love et al. 2014, no version); the UMAP call itself is the
argument-rich sentence (n_neighbor, n_components, min_dist, random_state), not the vst step.

## PMC12893922 / PMID 41407857 — Nature (_applies: yes)
Results presentation: Methods explicitly names three downstream uses of the same VST matrix in one
sentence (Euclidean distance matrices, PCA, heat maps), plus a batch-corrected version of the VST
values used in "Extended Data Fig. 2a,b" (tissue vs organoid) and a heat map in "Extended Data Fig. 4e"
(with sex-specific genes excluded). No numeric PCA/heatmap threshold (e.g. variance explained) is given.
Methods sentence structure: one sentence chains function name (variance stabilizing transformation,
VST) with all three downstream analyses; a following, separate sentence names the batch-correction tool
(limma's removeBatchEffect) and its batch variable (tissue vs organoid). DESeq2 itself is cited by two
references with no version number anywhere in the passage.

## PMC8664294 / PMID 34755601 — eLife (_applies: yes)
Results presentation: not stated — the sentence describing PCA has no figure/panel reference or
numeric threshold in the retrieved Methods text.
Methods sentence structure: a short, single, self-contained sentence: "Principal component analysis
was performed on counts after the DESeq2 variance stabilizing transformation." Software version
(v1.26.0) and the differential-testing function are given earlier in the paragraph for the general
pipeline, not repeated here; no blind/ntop argument is discussed.

## PMC7688323 / PMID 33239294 — Science Advances (_applies: yes)
Results presentation: not stated with a figure number, but Methods gives an unusual amount of
procedural detail: the PCA is run on a VST matrix that has itself been "adjusted for the batch/replicate
effect" by a named external package (limma) before plotting.
Methods sentence structure: two sentences — first names the transform and its two purposes ("samples
clustering and PCA plot"); second names the correction tool and its version (limma R package v3.44.3).
DESeq2's own version (1.18.1) is stated earlier for the general pipeline, not re-stated for this
transform.

## PMC13493127 / PMID 42623273 — eLife (_applies: yes)
Results presentation: not stated. The subsection is literally titled "Heatmap generation" but gives no
figure number or numeric threshold; the following subsection ("Weighted Venn diagrams") suggests the
heatmap is one of several overlap-related display items, but this link is not stated.
Methods sentence structure: a single sentence names software+function ("DESeq2's regularized log (rlog)
method", Love et al. 2014, no version) and justifies the choice in a subordinate clause ("stabilizes
variance..., enhances unbiased clustering") rather than naming a specific plotting function (no
pheatmap/plotPCA/ComplexHeatmap named).

## PMC12700201 / PMID 41385642 — Science Advances (_applies: yes)
Results presentation: not stated with a figure number, but the Methods are unusually explicit about
mechanics: PCA is run with base-R "prcomp" (not DESeq2's own plotPCA) on the vst matrix; a second,
separate sample-to-sample "dist"-based hierarchical clustering/dendrogram is described; a third,
distinct sample-correlation step (Spearman, via "cor") is also given. No numeric clustering/PCA
threshold is stated for any of the three.
Methods sentence structure: three short, separate sentences, each naming a different base-R function
(prcomp, dist, cor) applied to the same "variance-stabilizing transformed data" produced by the "vst"
function of DESeq2 (v1.38.3, explicitly "using default arguments"); the actual blind/ntop values behind
those "default arguments" are never spelled out.

## PMC10711438 / PMID 37953377 — Nucleic Acids Research (_applies: yes)
Results presentation: Methods names two supplementary figures directly — "Part 1 of Supplementary
Figure S4" for the vst/QC step, and "Supplementary Figure S5" for the resulting sample groupings, which
were "manually curated based on cytological observations" rather than by a hard numeric cutoff.
Methods sentence structure: one sentence explicitly flags the blind argument ("a blind variance
stabilizing transformation (vst)"); a following sentence names two different downstream techniques in
one breath — Pearson-correlation-based hierarchical clustering (stats package) and PCA (FactoMiner
package) — with DESeq2 v1.30.1 given for the overall pipeline just before.

## PMC9710879 / PMID 36449618 — Science Advances (_applies: yes)
Results presentation: not stated with a figure number, but Methods gives unusually complete numeric
detail for the QC step itself: PCA restricted to the "2000 most variable genes" and a sample-to-sample
distance step explicitly named as Euclidean "considering the entire transcriptome"; a separate DEG
threshold (FDR<0.10) is given for a different (differential-expression) step in the same paragraph.
Methods sentence structure: one sentence names function+ntop together ("DESeq2's plotPCA function"
+ "2000 most variable genes"); a second, separate sentence names the distance metric (Euclidean) and the
plotting package (Pheatmap v1.0.12) without naming a specific DESeq2 function for that second step.

## PMC12807868 / PMID 41381884 — Nature Genetics (_applies: yes; UMAP, not PCA)
Results presentation: not stated with a figure number. The 1,000-most-variable-gene UMAP embedding
merges several published mouse tumour-model RNA-seq datasets after VST + z-score normalization and
ComBat_seq batch correction "resulting from different source laboratories and array types" — i.e. the
visualization's stated purpose is to check/handle cross-study batch structure, a QC-flavoured use even
though the technique is UMAP rather than PCA.
Methods sentence structure: one sentence names the normalization function (VST-normalization, DESeq2,
ref. 80) and, in the same breath, chains z-score normalization and ComBat_seq batch correction (also
credited to DESeq2); the ntop argument (1,000 most variable genes) and the visualization package (umap,
v0.2.10.0) are named in a separate, following sentence.

## PMC10703692 / PMID 38036788 — Nature Genetics (_applies: yes; outlier review)
Results presentation: not stated with a figure number; the outlier step is reported purely as a sample-
count outcome ("removed as outliers, resulting in a total of 2,115 samples"), with no plot cited in the
retrieved Methods text.
Methods sentence structure: one sentence names the transform (variance-stabilizing transformation,
DESeq2, ref. 98, version not restated in this passage even though 1.38.3 was given earlier for a sibling
cohort) purely as a normalization step; the very next, separately built sentence names an unrelated
outlier criterion (WGCNA network connectivity score < -3) with no explicit methodological link stated
between the VST normalization and the WGCNA-based outlier call beyond appearing back to back.

## PMC8791277 / PMID 34741808 — Molecular Cell (_applies: yes)
Results presentation: the most explicitly figure-linked exemplar in this set — "To prepare the heatmap
in Figure 3A, VST-transformed...expression values of the 50 most variable genes enriched in
compartment-specific HyPro-seq data with FDR<1E-4 were processed in pheatmap." The FDR<1E-4 threshold
selects which 50 genes are shown, not a property of the transform.
Methods sentence structure: a single sentence gives the figure number, the transform (VST-transformed,
Love et al. 2014, no version), the input gene set and its selection threshold, and the plotting package
(pheatmap) all together.

## PMC13589506 / PMID 42594877 — Cell Reports Medicine (_applies: yes)
Results presentation: not stated with a figure number; described generically as producing "heatmaps"
of z-scored vst values "for the indicated gene sets", implying several unspecified, gene-set-specific
heatmaps recur across the paper rather than one named panel.
Methods sentence structure: one sentence names the function (vst, DESeq2 v1.42.1), states its purpose
(variance stabilizing transformation), and chains the z-scoring and plotting package (pheatmap v1.0.12)
in the same sentence.

## PMC12796325 / PMID 41353448 — Nature Communications (_applies: yes; metatranscriptome)
Results presentation: not stated with a figure number; PCA on "VST normalized values across all ORFs"
appears inside a broader statistics paragraph (Kruskal-Wallis/Dunn's tests across depths/times), reading
as an exploratory/QC step supporting later depth-based comparisons rather than a labeled main figure.
Methods sentence structure: one sentence names the base-R function (prcomp) and its input (VST
normalized values); the VST step itself is described earlier, in a separate sentence that names the
DESeq2 version (v.1.34.0) and its purpose ("read normalization") without linking it explicitly to the
PCA sentence that follows several lines later. Unusual domain: environmental metatranscriptome (whole
seawater community) samples rather than a single-organism experiment.

## PMC8566602 / PMID 34732713 — Nature Communications (_applies: yes)
Results presentation: not stated with a figure number; the dendrograms are framed as testing "the
ability of previously reported cancer gene sets to distinguish cohorts" using two named external
signatures (Mammaprint, PAM50), built with an external tool (Morpheus) rather than a Bioconductor
plotting function.
Methods sentence structure: one sentence names the transform (variance stabilizing transformation, VST
module in DESeq2) purely as a general "downstream analyses" normalizer, with no version stated; a later,
separate sentence names the specific method (hierarchical clustering, Euclidean average-linkage
distances on z-scored VST values) and the external tool (Morpheus).

## PMC7673985 / PMID 33203890 — Nature Communications (_applies: yes)
Results presentation: not stated with a figure number, but the heatmap's gene set is explicitly defined
as "the union of the top 50 genes (by p-value) in each of the pairwise comparisons among the three
groups (n = 121 genes)" — a DE-significance-based selection, not a variance-based one.
Methods sentence structure: one sentence names the transform (variance-stabilizing transformation,
DESeq2 v1.26) and its immediate post-processing ("centered and scaled prior to clustering"); the next
sentence names two different distance metrics for the two heatmap axes (Pearson correlation for
rows/genes, Euclidean for columns/samples) plus the agglomeration method (Ward's criterion, ward.D2) —
the most granular clustering-method description among this module's exemplars.
