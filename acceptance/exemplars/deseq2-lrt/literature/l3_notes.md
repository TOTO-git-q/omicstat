# deseq2-lrt — L3 close-reading notes

Ten L3+L4 exemplars (current corpus, after the discovery signal was tightened on 2026-09-27 to
require DESeq2 and the LRT in one sentence, and the corpus was re-collected). For each: how the
module's analysis part (DESeq2 LRT with a reduced model on bulk RNA-seq counts) is presented in the
results (figures/thresholds, as far as the retrieved Methods text states them), and how the Methods
sentence is built (software + version + function + key arguments). Quotes are paraphrased/short
(<=25 words) and in my own words otherwise. "not stated" where the retrieved Methods text gives
nothing to go on.

Two exemplars (PMC9678885, PMC10629825) carry over from the round-1 L3 set unchanged, since they are
still in the current corpus; the other eight are new close readings for this round.

## PMC13582980 / PMID 42749737 — Nature Communications (_applies: yes)
Results presentation: not tied to a labeled figure in the retrieved Methods text; the LRT's output is
described only as a bookkeeping detail of the pipeline ("identify genes that are differentially
expressed across all age groups"), immediately after a separate pairwise DESeq2 test on the same
samples that does carry its own fold-change/FDR cutoff.
Methods sentence structure: a single terse sentence names the test (likelihood ratio test), the
package with its own version (DESeq2 v1.44.0 -- distinct from the v1.33.5 cited for the earlier
pairwise test in the same paragraph), and the padj cutoff (0.01) all together, but gives no
reduced=/full= formula; "not stated" for both models.

## PMC9678885 / PMID 36411286 — Nature Communications (_applies: yes)
Results presentation: results are tied to a named figure — "'Core' RUNX1 target genes (Fig. 5) are
defined as padj<0.1 [pairwise]...and LRT padj<0.05"; downstream, GSEA pre-ranking explicitly branches
its ranking statistic by test type ("in the case of LRT, the rank was calculated as
sign(LFC)*-log10(p value)"), showing the paper treats the LRT branch of the analysis differently from
the Wald-test branch even at the enrichment-ranking stage.
Methods sentence structure: one sentence gives full and reduced formulas together ("full model
~ cell_line + shRNA_target, reduced model ~ cell_line"); the padj threshold for this specific LRT (0.05)
appears later, folded into a compound gene-definition sentence that also carries an unrelated pairwise-
comparison threshold (0.1) for the same figure, so the two cutoffs have to be disentangled carefully
when reading it.

## PMC10629825 / PMID 37934560 — eLife (_applies: yes)
Results presentation: not stated with a figure number in the retrieved Methods text; downstream, "the
average log fold-change calculated from the TPMs" (not the LRT's own effect size) is used to build
normalized volcano plots with EnhancedVolcano, one per timepoint.
Methods sentence structure: one sentence gives the full model (~ Treatment + Replicate) and reduced
model (~Replicate) explicitly, naming DESeq2's version (1.36) and explaining the Replicate term's
purpose in parentheses ("as the data is paired") — one of the clearest paired-design LRT sentences in
this corpus, run separately per timepoint rather than pooling all timepoints into one time-course model.

## PMC8563941 / PMID 34728633 — Nature Communications (_applies: yes)
Results presentation: no figure number is tied to the LRT step itself in "Methods > Bulk RNA sequencing";
a later, separate "Pathway analysis" subsection reuses an unlabeled "differentially expressed genes"
list at "p <= 0.05" (small in-house cohort) and, for a larger public validation cohort, explicitly
"p adjusted <=0.05" -- neither sentence says outright that this list is the LRT's own output, so the
threshold that actually governs the LRT call is left ambiguous rather than just absent.
Methods sentence structure: unusually compressed for a three-factor design — one clause names the
covariates ("Multi-factor differential expression analysis for age, smoking, and gender") and the test
("the likelihood ratio test was used for hypothesis testing") back to back, with no formula syntax, no
padj cutoff, and no DESeq2 version anywhere near it.

## PMC12572406 / PMID 41162376 — Nature Communications (_applies: yes)
Results presentation: not tied to a labeled main figure in the retrieved Methods text; the effect size
is instead explained through an approximation formula for the interaction fold-change (a ratio-of-ratios
of the four stress x drug conditions), described in prose rather than shown as a figure call-out, and
heatmaps/volcano plots are mentioned only generically afterward for "Heatmaps and volcano plots."
Methods sentence structure: the most formula-explicit sentence in this batch after PMC12893922 (round 1)
— names the test ("DESeq2 coupled with LRT analysis"), then gives the full model ("stress + drug +
stress:drug") and reduced model ("stress + drug") as quoted R-style terms in the same paragraph, with
the padj cutoff (adjusted p / FDR < 0.1) and correction method (Benjamini-Hochberg) stated one sentence
earlier as the paper's general DEG default rather than repeated for the LRT sentence itself.

## PMC11430494 / PMID 39331709 — Science Advances (_applies: no)
Results presentation: not applicable as a bulk-RNA-seq exemplar — the "DESeq2 likelihood ratio test"
here is run on a pseudo-bulk counts matrix U (samples x genes) aggregated from a published single-cell
atlas (54,313 SCLC + 3,341 LUAD single-cell transcriptomes), reported as a plain count ("6886
differentially expressed genes, including ATR") rather than tied to a labeled main figure.
Methods sentence structure: the paper is explicit about the caveat itself — "Pseudo-bulk differential
expression methods like DESeq2 perform well in scRNA-seq datasets" is stated as a justification in the
very same paragraph as the LRT call, which is exactly why this is a regex true-positive for DESeq2+LRT
but a scope false-positive for this bulk-RNA-seq module.

## PMC7080449 / PMID 32206711 — Science Advances (_applies: yes)
Results presentation: not tied to a labeled figure in the retrieved Methods text; the LRT's DEG output
feeds two different downstream visualizations described only generically -- a principal coordinate
analysis of variance-stabilized counts, and (separately) a pheatmap-based heatmap of DEG counts per
KEGG pathway -- neither call-out names a figure number for the LRT step specifically.
Methods sentence structure: an unusually explanatory sentence pair — first names the test and purpose
("We performed a likelihood ratio test with DESeq2 for each species to identify DEGs...across all time
points"), then immediately glosses what the test contrasts in plain English ("differentially expressed
between all months...from those differentiated within a particular month") before giving the numeric
cutoff (P < 0.01, "i.e., adjusted P value") — reduced=/full= formulas are never spelled out even though
the comparison (across all time points, per species) is described carefully in prose.

## PMC13174499 / PMID 42034059 — Cell Stem Cell (_applies: yes)
Results presentation: the LRT is introduced by its downstream use rather than its own output — "For
K-means clustering, the likelihood ratio test (LRT) from the DESeq2 package was used to identify
differentially expressed genes" — i.e., the Methods text frames the whole sentence around the
clustering step that follows, not a labeled main figure for the DEG list itself.
Methods sentence structure: compact and reuses the padj cutoff from the preceding (separate, non-LRT)
DE analysis by restating it verbatim ("with significance defined as an adjusted p-value < 0.01") rather
than cross-referencing it, so the two analyses read almost identically despite testing different
things; no reduced=/full= formula or design_type language is given for the LRT sentence itself.

## PMC8213717 / PMID 34145235 — Nature Communications (_applies: yes)
Results presentation: the LRT's use is disclosed only in a end-of-paper "Statistics" roundup sentence
that maps statistical tests to figure ranges collectively ("by the likelihood ratio test and Wald test
(two-sided) in DESeq2 package for DEG analysis in RNA-seq data (Figs. 4c, d, 5c, d, and 6c, d...")
rather than in the RNA-seq Methods subsection itself, which only names DESeq2 with "default settings."
Methods sentence structure: split across two non-adjacent subsections — "Methods > RNA-seq" gives the
DESeq2 version (1.20.0) and a generic "q value cutoff of 0.05" with no test named, while "Methods >
Statistics" (many paragraphs later) is the only place the LRT is actually named -- "by the likelihood
ratio test and Wald test (two-sided) in DESeq2 package for DEG analysis in RNA-seq data" -- as one of
several statistical tests tallied per figure panel across the whole paper.

## PMC9135744 / PMID 35618862 — Nature Communications (_applies: no)
Results presentation: not applicable as a bulk-RNA-seq exemplar — the sentence sits in "Methods >
Downstream sequencing analysis" immediately after "Differential expression was performed using the
Wilcoxon Ranked-Sums test in Seurat V4 for single cells," and describes "pseudobulk analysis on our
web-based tool" built from the paper's single-cell RNA-sequencing dataset, not a primary bulk experiment.
Methods sentence structure: the shortest LRT mention in the corpus — "For pseudobulk analysis on our
web-based tool, the likelihood ratio test in DESeq2 V1.32.0 was used" — one clause, one version number,
no design, no cutoff, sandwiched between two other single-cell-specific statistical tools (Seurat
Wilcoxon and MiloR differential abundance) in a list of methods used across the paper's supplementary
web tool rather than a designed multi-group/time-course/interaction comparison.
