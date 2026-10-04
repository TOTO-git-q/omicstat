## 2026-09-27 07:25 UTC retriever (haiku)

**Search**: deseq2-lrt
- hit_count: 498
- candidates_fetched: 345
- gates: screened=30, excluded_by_regex=17, licence_not_countable=4
- corpus: 30
- l3: 10

**L1 from Bioconductor 3.23**:
- DESeq2 1.52.0 @ RELEASE_3_23 (commit: 16aeab6d61)
- DEGreport 1.48.0 @ RELEASE_3_23 (commit: bc514a8283)

Next: extraction

## 2026-09-27 08:35 UTC extractor (sonnet)
- Articles 1-7 done: PMC13526022 (42668313, no - LRT is an ordinal mixed-effects clinical model, not
  DESeq2), PMC9977155 (36577520, yes - LRT per sex/age group, degPatterns), PMC8783694 (34731091, yes -
  three full/reduced model pairs per cell line, Pearson-distance gene clustering), PMC7752919 (33349639,
  no - Cox-model log-likelihood ratio test), PMC13590504 (42764283, no - glmer.nb LRT on ant brood
  production), PMC12893922 (41407857, yes - explicit full=~donor / reduced=~1), PMC11641009 (39671488,
  no - Seurat 'bimod' LRT on scRNA-seq).
- Every `_applies=no` case so far is a regex false positive: 'likelihood ratio test' hits from Cox
  models, mixed-effects/GLMM statistics, or Seurat/scRNA-seq marker tests, not DESeq2 on bulk RNA-seq.
- Next: PMC8791832 (34856602), then the remaining 22 articles.

## 2026-09-27 08:55 UTC extractor (sonnet)
- Articles 8-17 done: PMC8791832 (34856602, no - Seurat bimod LRT again), PMC13496182 (42627896, yes),
  PMC12700204 (41385634, no - lme4 LRT on mutation burden), PMC11621772 (39639049, yes - explicit
  full=~replicate+condition / reduced=~replicate, time course), PMC10698142 (38052795, no - PAML
  codeML branch-site LRT), PMC9729117 (36471071, no - single-particle-tracking spot-detection LRT),
  PMC13522794 (42567163, yes - DESeq2 LRT with tumor-purity covariate, FDR<0.05), PMC9678885 (36411286,
  yes - explicit full=~cell_line+shRNA_target / reduced=~cell_line), PMC8626495 (34836963, yes -
  test="LRT", reduced=~1, alpha=0.1, minFC=1.3 all stated as literal DESeq2 arguments), PMC7695459
  (33169669, no - WGCNA module-trait LRT via anova()/Chisq).
- Next: PMC13450217 (42566531), then the final 13 articles.

## 2026-09-27 09:15 UTC extractor (sonnet)
- Articles 18-30 done (module complete): PMC13450217 (42566531, yes - time-course LRT, mfuzz fuzzy
  c-means), PMC10663454 (37990021, yes - full=size+date+treatment vs reduced null models, DEGreport),
  PMC7580003 (33092630, yes - LRT across time points, GPClust time-series clustering), PMC13438604
  (42520124, no - ambiguous custom negative-binomial LRT, DESeq2 not explicitly named for this test),
  PMC11610591 (39271291, no - IsoTools beta-binomial LRT for splicing, not DESeq2), PMC10841842
  (37963019, no - LRT explicitly rejected in favor of Kolmogorov-Smirnov), PMC8617201 (34824214, no -
  PAML branch-site LRT), PMC13557617 (42479456, no - Seurat/Signac LRT on snATAC DARs), PMC10629825
  (37934560, yes - full=~Treatment+Replicate / reduced=~Replicate, paired per-timepoint), PMC9630410
  (36323682, no - Clonality package LRT on WES mutation sharing), PMC8663557 (34554929, yes - LRT for
  3-way comparisons), PMC7529769 (33004787, no - mgcv GAMM seasonality LRT), PMC12804086 (41224999, no -
  spatial NB-GAM spline LRT on Xenium data).
- extraction.jsonl: 134 lines (30 articles; _applies yes=13, no=17). Every `_applies=no` case is a
  regex false positive: 'likelihood ratio test'/'LRT' matched a non-DESeq2 statistical test (Cox models,
  lme4/GLMM, PAML codeML dN/dS, Seurat/Signac single-cell marker or accessibility tests, WGCNA
  module-trait association, particle-tracking spot detection, IsoTools splicing, Clonality mutation
  sharing, mgcv GAMM, spatial NB-GAM). One case (PMC13438604) is genuinely ambiguous: a likelihood
  ratio test on a "negative binomial model" without DESeq2 explicitly named for that step.
- Next: l3_notes.md for the 10 L3+L4 articles (42668313, 36577520, 41407857, 34856602, 41385634,
  36471071, 36411286, 33169669, 37963019, 37934560), then collect.py summarize + commit.

## 2026-09-27T08:14:54Z main session
- signal tightened (DESeq2 and LRT in one sentence); search rerun: corpus 30 (7 kept from round 1, all applicable; 23 new). Round-1 extraction lines of articles no longer in the corpus stay in extraction.jsonl but are not counted (summarize reads the corpus).
- next: top-up extraction of the 23 new articles, new L3 notes

## 2026-09-27T09:40:00Z extractor (sonnet) -- top-up round after signal tightening
- Confirmed resume point: corpus re-collected (30 articles); 7 kept from round 1 already have
  extraction lines (PMC8783694, PMC10663454, PMC9678885, PMC7580003, PMC13522794, PMC13450217,
  PMC10629825); 23 new articles need extraction.
- Articles 1-13 of 23 done: PMC13582980 (42749737, yes - LRT across all age groups, padj<0.01,
  K-means clustering of altered proteins/transcripts), PMC9663569 (36376298, yes - LRT between
  sorted T-cell subsets, pheatmap/Ward's D clustering), PMC9622893 (36316305, yes - LRT for paired
  CAF/KPC shBrca2 vs shControl comparisons, Padj<0.1, |log2FC|>0.5), PMC8602323 (34795257, yes - LRT
  DE gene set at FDR<0.05 used for dimensionality reduction), PMC7803671 (32916091, no - ZinbWave+
  DESeq2 LRT explicitly applied to Patch-seq **single-cell** RNA-seq data), PMC13462894 (42386760,
  yes - explicit full=treatment+timepoint+interaction / reduced=treatment+timepoint, padj<=0.05 BH),
  PMC11537486 (39499645, yes - LRT on tRNA decoder-family bulk counts, flagged as tRNA-seq not mRNA),
  PMC8563941 (34728633, yes - multi-factor age/smoking/gender LRT, no cutoff tied to it explicitly),
  PMC7428014 (32796835, yes - literal DESeq(test="LRT", reduced=~1) across 7 mouse tissues, tRNA-seq),
  PMC10560206 (37805579, yes - LRT to detect/remove sequencing-batch-associated genes, QC use),
  PMC10542369 (37777536, yes - LRT with genotype as factor of interest, RUV covariate, padj<0.05),
  PMC11449483 (39361025, yes - LRT or Wald 'as appropriate' on public bulk liver transcriptomes, no
  LRT-specific values stated), PMC12572406 (41162376, yes - explicit full="stress+drug+stress:drug" /
  reduced="stress+drug" interaction-effect design, padj<0.1 BH).
- All snippets re-verified with `collect.py check` (FOUND) before appending; several verbatim
  snippets had to keep inline citation numbers (e.g. "pheatmap133") or curly quotes/apostrophes
  exactly as in the source XML for the check to pass.
- Ambiguous/borderline calls flagged via `note`: two articles (PMC11537486, PMC7428014) are DESeq2
  LRT on **tRNA-seq** bulk counts rather than standard mRNA RNA-seq -- kept as applies=yes (same
  statistical framework, bulk count data) but flagged for reviewer attention. PMC10560206's LRT is a
  batch-effect QC step, not the paper's primary biological comparison -- design_type recorded as
  stated ("association with sequencing batch") rather than forced into multi-group/time-course/
  interaction. Several padj/lfc values that appear in the same Methods paragraph but for a
  textually-separate DESeq2 step (e.g. a pairwise Wald test, or a different dataset/cohort) were
  marked "not reported" for the LRT parameter with a `note` pointing to which other analysis they
  belong to, per the no-inference rule.
- Next: remaining 10 articles (PMC12391433, PMC7080449, PMC13174499, PMC8213717, PMC10356864,
  PMC9135744, PMC11430494, PMC10577566, PMC8528489, PMC7371425), then l3_notes.md, summarize, commit.

## 2026-09-27T10:05:00Z extractor (sonnet) -- top-up round complete
- Articles 14-23 of 23 done: PMC8528489 (34553686, yes - DESeq2 LRT testing diet effect using day 3/5
  fly midgut data; two unrelated custom-GLM 'likelihood ratio test' mentions elsewhere are NOT DESeq2),
  PMC7371425 (32687059, yes - LRT used specifically for factors with >2 levels vs Wald for 2-level
  factors, IHW p-value adjustment), PMC11430494 (39331709, no - DESeq2 LRT run on a pseudo-bulk counts
  matrix aggregated from a published single-cell SCLC/LUAD atlas, not primary bulk RNA-seq), PMC10577566
  (37691488, no - DESeq2 LRT/nbinomlrt() applied to ATAC-seq differential-accessibility peak counts, not
  RNA-seq gene counts), PMC12391433 (40866353, yes - explicit full=genotype+time+genotype:time /
  reduced=genotype+time, genotype x time interaction, yeast sporulation time course, DPGP downstream
  temporal clustering), PMC13174499 (42034059, yes - LRT DEGs feed K-means clustering, padj<0.01),
  PMC8213717 (34145235, yes - LRT confirmed only in an end-of-paper Statistics summary sentence tallying
  tests per figure, not in the RNA-seq Methods subsection itself), PMC10356864 (37468470, yes - explicit
  full model with a time term vs reduced model lacking it, diel/circadian cycling analysis per sex,
  FDR<0.05), PMC9135744 (35618862, no - DESeq2 LRT on a pseudobulk aggregate of single-cell data,
  explicitly following a Seurat single-cell Wilcoxon test in the same sentence group), PMC7080449
  (32206711, yes - LRT across all time points per fish species, padj<0.01, DESeq2 v1.18; L3 exemplar).
- All 23 top-up articles complete. extraction.jsonl now covers all 30 corpus articles (23 new + 7 kept
  from round 1); orphaned round-1 lines for articles no longer in the corpus are left in place per
  instructions (summarize filters by corpus membership for the per-parameter table, though its top-line
  "N of M corpus papers apply" count is a pre-existing script quirk that sums _applies=yes across ALL
  extraction.jsonl pmids, including the 6 orphaned round-1 yes-articles no longer in corpus -- printed
  32 of 30 for that reason; the per-parameter breakdown below it is correctly corpus-filtered and sums
  to 26, the true applies=yes count for the current 30-article corpus).
- Current corpus _applies tally: 26 yes / 4 no (of 30). The 4 no: PMC7803671 (ZinbWave+DESeq2 LRT on
  Patch-seq single-cell data), PMC11430494 and PMC9135744 (DESeq2 LRT on pseudo-bulk aggregates of
  single-cell RNA-seq, not primary bulk RNA-seq), PMC10577566 (DESeq2 LRT on ATAC-seq accessibility
  peaks, not RNA-seq counts).
- Two borderline "yes" calls flagged for reviewer attention: PMC11537486 and PMC7428014 run DESeq2 LRT
  on bulk tRNA-seq (decoder-family / anticodon-level) counts rather than standard mRNA RNA-seq; kept as
  applies=yes (same bulk count-data statistical framework) but noted.
- l3_notes.md rewritten for the current 10-article L3+L4 set (PMC13582980, PMC9678885, PMC10629825,
  PMC8563941, PMC12572406, PMC11430494, PMC7080449, PMC13174499, PMC8213717, PMC9135744): 2 notes kept
  unchanged from round 1 (PMC9678885, PMC10629825, still in the current corpus), 8 written new; notes
  for the 8 round-1 L3 articles no longer in this corpus (PMC13526022, PMC9977155, PMC12893922,
  PMC8791832, PMC12700204, PMC9729117, PMC7695459, PMC10841842) were dropped.
- Every snippet in extraction.jsonl and l3_notes.md re-verified with `collect.py check` (FOUND) before
  being written; several needed curly quotes/apostrophes or inline citation numbers (e.g. "pheatmap133")
  copied exactly as in the source XML.
- Next: `collect.py summarize deseq2-lrt`, `find vendor -name __pycache__` check, commit
  acceptance/exemplars/deseq2-lrt/literature/.

## 2026-09-27T08:40:11Z independent verifier (sonnet)
- `collect.py sample deseq2-lrt --frac 0.2 --seed omicstat-s0` -> 6 PMIDs: 34728633 (PMC8563941),
  35618862 (PMC9135744), 36316305 (PMC9622893), 36411286 (PMC9678885), 37777536 (PMC10542369),
  42566531 (PMC13450217).
- Echo: fresh PubMed esummary call per sampled PMID (tool=omicstat, email=omicstat-s0@example.invalid,
  $OMICSTAT_CONTACT_EMAIL unset) -- title and year matched corpus.jsonl for all 6 (echo_checked=6,
  echo_passed=6).
- Every non-empty snippet re-checked with `collect.py check` -> FOUND, all <=25 words. Every
  'not reported' line re-checked by reading the full Methods (`collect.py methods deseq2-lrt <PMCID>`)
  -- value genuinely absent for the LRT step in every case, including two lines where a value for a
  DIFFERENT analysis in the same paper's Methods was correctly left unattributed with a note
  (PMC9622893 p_adjust_method: FDR stated only for the separate PSC 3-group comparison, not the CAF/KPC
  LRT; PMC10542369 pattern_clustering: UMAP/PCA clustering named only for a separate Protocol-B
  patient-line comparison, not the RUV-covariate LRT).
- _applies verified for all 6: PMC9135744 correctly 'no' (DESeq2 LRT run on a pseudobulk aggregate of
  10X single-cell clusters, confirmed by reading the full single-cell Methods pipeline); the other 5
  correctly 'yes' (DESeq2 test=LRT full-vs-reduced model on primary bulk RNA-seq/MARS-seq/SMART-seq2
  counts, none Wald-only or a different analysis).
- PMC13450217's padj_cutoff/lfc_filter correctly sourced from the TE-level subsection that explicitly
  names 'DESeq2 and a likelihood ratio test' with those thresholds; a differently-scoped padj<0.05
  elsewhere in the paper (pairwise 18h-vs-28h gene-level comparison) was correctly left unattributed.
- PMC11537486 / PMC7428014 (tRNA-seq judgment calls) were not in this sample; not re-checked here.
- records_checked=46, records_passed=46, pass_rate=1.0000, echo 6/6 -> verdict: pass.
- verification.json and this worklog entry written; extraction.jsonl untouched. Resume point: module
  deseq2-lrt literature stage complete (search -> extraction -> verification all done); next step per
  PACK.md is the main-session V-section counts / D-section table, not further verifier work.
