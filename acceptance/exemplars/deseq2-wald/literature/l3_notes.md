# deseq2-wald — L3 close-reading notes

Ten articles (layer "L3+L4") read closely beyond the extraction pass. Everything here is in my
own words except quotes of at most 25 words, which are copied verbatim from the Methods regions
returned by `collect.py methods deseq2-wald <PMCID>`. That tool only returns Methods-region text,
never the Results, figure legends or tables, so most statements about how a DEG table or figure
looks could not be checked directly against the article and are marked "not stated" rather than
guessed.

## PMC9977155 (PMID 36577520) — killifish gonad aging, LRT-only

- **DE table presentation**: not stated. The Methods mention a "Table S1" only implicitly through
  the `degPatterns`/DEGreport clustering step; no column layout, sorting or truncation rule for a
  DEG table is given in the retrieved Methods text.
- **Figures**: not stated. No figure is tied to the DESeq2/LRT call in the Methods regions; the
  age-survival curve (Fig. 1B) is unrelated to the expression analysis.
- **Methods sentence structure**: software + version + test + threshold are all in one sentence:
  package (DESeq2 v1.34.0) -> test (LRT, explicitly, run "separately for each sex with each age
  as its own group") -> significance rule (adjusted P-value < 1e-6). This is the one article in
  the corpus where the module's own out-of-scope case (LRT-only, no Wald anywhere) is stated in
  the clearest possible terms, which is why `_applies` = no here.

## PMC11687419 (PMID 39708805) — ZNF143/CTCF, mESC RNA-seq and TT-seq

- **DE table presentation**: not stated in Methods; DEG lists are implied to feed downstream
  GO/pathway steps but no table format is described.
- **Figures**: not stated for either the RNA-seq or the TT-seq DESeq2 call; the Methods regions
  describe ChIP-seq/Hi-C/ATAC-seq heatmaps and metagene profiles in detail but never connect a
  specific figure panel to the RNA-seq or TT-seq differential-expression numbers.
- **Methods sentence structure**: two near-identical, formulaic sentences, one per assay (RNA-seq,
  TT-seq): package+version ("DESeq2 v1.30.1") -> prefilter ("half of the samples to have gene
  counts greater than 10") -> test, named through the internal DESeq2 function rather than the
  word "Wald" ("nbinomWaldTest" function with default parameters") -> significance rule (FDR and
  |log2FC| cutoff). The two sentences differ only in their numeric cutoffs (RNA-seq: FDR<0.01,
  |log2FC|>0 combined with a built-in lfcThreshold of log2(1.5); TT-seq: FDR<0.05, |log2FC|>0.5,
  no stated lfcThreshold), which is a clean illustration of how the same lab can run the same
  pipeline with different thresholds for two different assays in one paper.

## PMC13534236 (PMID 42680562) — ASD de novo structural variants, iPSC-ExN RNA-seq

- **DE table presentation**: not stated; a WGCNA module analysis and GO overrepresentation are
  described downstream of the DEG call, but no DEG table format is given.
- **Figures**: not stated in the Methods text.
- **Methods sentence structure**: single compact sentence chain: prefilter ("more than two counts
  per million (cpm) in at least two of the six samples") -> package+version ("DESeq2 v1.44.0") ->
  significance rule ("adjusted P-value < 0.05"). No test name, no fold-change criterion, no
  design formula despite three genotype groups (WT/CTCF-deletion/full-deletion) being compared.

## PMC13534237 (PMID 42680560) — NPC (nasopharyngeal carcinoma) long-read splicing, DTE analysis

- **DE table presentation**: not stated (no column/sort/truncation description in Methods).
- **Figures**: not stated in Methods.
- **Methods sentence structure**: the most complete single sentence in the whole corpus for this
  module: package+version ("DESeq2 (v1.38.3)") -> comparison groups (NPC tumor vs immortalized
  nasopharyngeal cell lines) -> test, named explicitly ("using the Wald test under a negative
  binomial generalized linear model") -> multiple-testing method, named explicitly
  ("Benjamini-Hochberg correction for multiple testing") -> combined significance/fold-change
  filter in the very next sentence (|log2FC| > 2 and adjusted P < 0.05). This is the cleanest,
  most complete exemplar in the L3 set: every field except shrinkage, prefilter and design is
  explicit and unambiguous.

## PMC12807877 (PMID 41413654) — Npm1/Apc mouse intestinal tumors, RNA-seq

- **DE table presentation**: not stated.
- **Figures**: not stated; GSEA against Reactome/Hallmark gene sets is described downstream of the
  DEG call (used for the Apc+/+ vs ApcloxP/loxP contrast), but no figure is explicitly tied to the
  DESeq2 result table itself.
- **Methods sentence structure**: one sentence covers package+version, model type, test and
  correction method together: "Differential expression analysis was performed using the R package
  DESeq2 (v.1.22.2), using a negative binomial generalized linear model, with significance
  assessed using a Wald test and Benjamini-Hochberg multiple testing correction." No numeric padj
  cutoff, fold-change filter or design formula is given for the RNA-seq call itself; the article's
  separate "Statistics and reproducibility" section states a general P<0.05 threshold, but that is
  explicitly for the Prism-based clinical/behavioural tests (t-test, Mann-Whitney, ANOVA), not for
  the DESeq2 RNA-seq analysis, so it was not attributed to DESeq2 here.

## PMC10719396 (PMID 38092730) — root microbiome metatranscriptomics

- **DE table presentation**: not stated for column layout; the Methods do note that per-strain,
  per-orthogroup and community-scale differential expression are each a separate DESeq2 run, so
  in principle there are (at minimum) three distinct result tables, but nothing about their
  columns, sorting or main-text-vs-supplement placement is given.
- **Figures**: this is the one L3 article where a figure type IS named directly in the Methods:
  "All volcano plots of gene differential expression and strains/class/order abundance were done
  in R with the package EnhancedVolcano ... using DESeq2 outputs." No specific padj/log2FC
  threshold lines or point labels for the volcano plots are described, though.
  No MA plot or heatmap is mentioned for the DESeq2 results specifically.
- **Methods sentence structure**: spread across two sentences rather than one: rationale/
  precondition first ("to detect enough transcripts per gene to compute a Wald test, we did not
  compute DESeq2 results" for underpowered strains), then the shrinkage and cutoff sentence
  ("we used the shrinkage algorithm apeglm... to correct log2-transformed FC values" plus
  "adjusted P values from DESeq2 are inferior to 0.05"). Version and p-adjustment method are not
  given even though this is otherwise one of the more complete descriptions in the corpus.

## PMC8656144 (PMID 34887515) — supermeres/exomeres, mouse liver and miRNA RNA-seq

- **DE table presentation**: not stated for either the small-RNA-seq or the liver RNA-seq call.
- **Figures**: not stated; no figure type is connected to either DESeq2 call in the retrieved
  Methods text (all figure-type mentions in this article's Methods are for microscopy/EV imaging).
- **Methods sentence structure**: both DESeq2 mentions follow the exact same short template,
  repeated with different numbers for the two assays: "DESeq2 was used to detect differential
  expression between X" followed immediately by "[features] with a fold change of >N and FDR <
  M were considered to be significantly differentially expressed." (miRNA: N=2, M=0.05; liver
  genes: N=1.5, M=0.1). No test name, no version, no design formula, no prefilter, no shrinkage
  method in either sentence — a good example of a minimal but internally consistent two-clause
  DESeq2 description repeated per assay.

## PMC12893922 (PMID 41407857) — periportal liver assembloids, bulk RNA-seq

- **DE table presentation**: not stated; a "list of differentially expressed genes" is referenced
  when intersecting with a zonated-gene list, implying at least one DEG table exists, but no
  column/sort/truncation or main-text-vs-supplement detail is given.
- **Figures**: this article is the only one in the L3 set that names specific main-text/extended
  data figure panels for individual DESeq2 comparisons, but only as cross-references for the
  *design formula*, not for a plot type: "the design formula ~ donor + condition_l3 was applied
  (Extended Data Fig. 2)" and "the comparison between DM and EM2 (Fig. 2e)." No volcano, MA or
  heatmap figure is explicitly named for any of the three comparisons.
- **Methods sentence structure**: the richest, most parameter-complete Methods paragraph in the
  whole corpus. For each of three comparisons it gives, in order: design formula -> shrinkage
  method+type ("shrunken using lfcShrink with the ashr method (type = 'ashr')") -> fold-change
  threshold ("applying a fold-change threshold of 1.5") -> significance level ("a significance
  threshold of alpha = 0.05"). A fourth, separate sentence in the same paragraph describes an
  entirely different, LRT-based comparison ("a likelihood ratio test (LRT) with the full model
  ~donor and the reduced model ~1") for "donor-specific genes" -- a rare case where Wald and LRT
  uses of DESeq2 are both spelled out, side by side, in one Methods paragraph, letting a reader
  see exactly why the LRT branch would be out of scope for this module while the three named
  comparisons are in scope.

## PMC7821903 (PMID 33298436) — cell-free plasma mRNA, Alzheimer's disease

- **DE table presentation**: not stated; "Supplementary Table S2" is referenced only for the
  sample-source breakdown, not for a DEG table.
- **Figures**: not stated; a PCA plot is mentioned only to confirm that the site/batch adjustment
  worked, not to display the DEG results themselves.
- **Methods sentence structure**: built up over several sentences rather than one: package+version
  ("DESeq2 (v1.12.4)") -> prefilter ("fewer than 250 total reads across the entire cohort were
  excluded") -> design formula, introduced narratively rather than as a bare formula ("we
  implemented a multifactor negative binomial model '~ source + disease status'") -> correction
  method + cutoff in the final sentence ("Benjamini-Hochberg correction... FDR cutoff of 0.05").
  No test name (Wald/LRT) and no shrinkage method are given anywhere in the paragraph.

## PMC9703767 (PMID 36443871) — mESC Pol II pausing, poly(A) RNA-seq and PRO-Seq/ChAR-Seq

- **DE table presentation**: not stated for either assay's DEG table.
- **Figures**: this article names a figure AND the statistical basis of that figure's values in
  the same sentence, but only for the PRO-Seq assay: "Volcano plots of PRO-Seq were made based on
  the fold changes and p values derived from the Wald test" (Fig. 5A per the preceding sentence).
  This is the source of the "Wald test" value now recorded for this article's `test` parameter (it
  was corrected after an initial pass had marked it "not reported", since the Wald mention sits in
  the PRO-Seq/ChAR-Seq subsection rather than the poly(A) RNA-seq subsection used as the primary
  source for the other parameters). No volcano/MA/heatmap figure is named for the poly(A) RNA-seq
  DESeq2 call itself.
- **Methods sentence structure**: two near-parallel short sentences, one per assay: poly(A)
  RNA-seq — "Differentially expressed genes were detected using DESeq2 with significance cutoffs
  of FDR < 0.05 and fold change > 2, with a minimum read count of 1 in at least one control
  sample of two biological replicates"; PRO-Seq/ChAR-Seq — a Drosophila-spike-in-calibrated count
  table is "subjected to DESeq2 for differential expression analysis, and a cutoff of 0.05 for
  FDR was chosen", with the Wald-test/volcano-plot sentence appearing separately, right after.
  Neither sentence names a package version, a shrinkage method or a design formula.

## Cross-cutting observations for the profile

- Across all 10 L3 articles, a DEG table's column layout, sort order, truncation rule and
  main-text-vs-supplement placement were essentially never stated in the Methods regions this
  tool exposes -- that information lives in Results text, table legends and supplementary-file
  headers, none of which `collect.py methods` returns. Any future profile work that wants this
  information will need a different retrieval path (full text or table/caption extraction), not
  Methods-only text.
- Figure types (volcano/MA/heatmap) tied specifically to a DESeq2 call were named in only 2 of
  10 Methods regions (PMC10719396's EnhancedVolcano sentence; PMC9703767's PRO-Seq volcano/Wald
  sentence). The other 8 either describe unrelated figures (ChIP-seq heatmaps, PCA, microscopy)
  or say nothing about visualization at all.
- When a paper runs DESeq2 more than once in the same Methods (very common -- 6 of the 10 L3
  articles: PMC11687419, PMC8656144, PMC12893922, PMC9703767, and to a lesser extent PMC13534236
  and PMC7821903), the different calls frequently use different numeric cutoffs for the *same*
  parameter (padj, fold-change filter/threshold, or design). A profile or extraction schema that
  assumes "one DESeq2 call per paper" will silently average together or otherwise conflate
  genuinely different analyses unless it keeps a `note` field (as this extraction does) flagging
  the divergence.
