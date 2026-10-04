# clusterprofiler-gsea — L3 close-reading notes

Close reading of the 10 tier-A, most-parameter-rich exemplars (layer `L3+L4`). Own words;
quotes are verbatim fragments (<=25 words) copied from the Methods text retrieved via
`collect.py methods`. "not stated" where the Methods text gives no information on a point.

## PMC9834056 / PMID 36544019 — Inheritance of paternal DNA damage by histone-mediated repair (C. elegans)
- **Results presentation**: this is an unusual use of GSEA — not a differential-expression
  ranked-gene-list test at all, but an enrichment test for whether structural-variant break
  points cluster along particular *chromosomal regions*, i.e. the "gene sets" and the "ranking"
  both relate to genomic position rather than expression fold-change. No dot plot, running-score
  or ridge plot is described for this analysis in the Methods; it feeds directly into the
  paper's discussion of chromosome-scale mutation distribution.
- **Methods sentence structure**: exceptionally compressed — one sentence names the whole
  analysis, tool, version and two numeric parameters together: "the GSEA function of
  clusterProfiler v3.14.3 was used with maxGSSize = 20000 and nPerm = 20000" — with no
  ranking-metric clause, no gene-set-database name and no p-value cutoff given anywhere near it;
  the only other quantitative detail (p and FDR q both < 0.05) appears one sentence earlier, in
  the context of a *different* per-bin statistical test (microhomology permutation), so it is a
  judgement call whether that cutoff was meant to apply to the GSEA step as well.

## PMC13537272 / PMID 42685224 — Activation of transposable elements in Parkinson's disease brain
- **Results presentation**: the identical clusterProfiler gseGO call (same package version, same
  six named arguments) is run independently at least three times across the paper — once on the
  main pseudobulk snRNA-seq clusters, once again as a stricter validation with a TE-penalizing
  differential-expression method, and a third time on bulk RNA-seq from stimulated dopaminergic
  neurons and microglia — each time producing its own ranked-gene GO-term result, with the paper
  explicitly cross-referencing the repeated parameter block ("Ranked list of genes based on
  log2FC was passed to the gseGO() function [ont = ALL...]") rather than restating it in full.
- **Methods sentence structure**: the most code-literal of the ten — the gseGO call is written
  as an almost-verbatim R argument list embedded in a numbered Methods step ("4) GSEA was
  performed using clusterProfiler...Ranked list of genes based on log2FC was passed to the
  gseGO() function [ont = ALL, keyType = SYMBOL, minGSSize = 3, maxGSSize = 800, seed = T,
  pvalueCutoff = 0.05, OrgDb = org.Hs.eg.db..., pAdjustMethod = BH]"), with the differential
  expression step (DESeq2, one sentence earlier) supplying the log2FC ranking metric explicitly.

## PMC9825171 / PMID 36477367 — Structure, binding and function of a Notch transcription complex
- **Results presentation**: GSEA is presented as one of three named analyses run together in a
  single sentence ("GO, GSEA, and KEGG analysis were done within R using clusterProfiler"), and
  the paper uses *two different* significance cutoffs depending on which of two RNA-seq
  comparisons is being analysed (RBPJ rescue vs. L3MBTL3 knockdown), rather than one cutoff
  applied uniformly; the Methods text gives no indication of which figure(s) display which
  cutoff's results.
- **Methods sentence structure**: ranking metric and universe are each given their own short,
  separate sentence directly after the tool-and-cutoff sentence — "Genes were ranked based on
  the Wald test statistic resulting from DESeq2 analysis" and "The universe for this analysis
  was defined as all genes that have detectable read counts in at least one sample" — but the
  gene-set databases tested (GO, KEGG) are only named once, in the first sentence, without
  ontology subtype or version number for clusterProfiler itself.

## PMC10709144 / PMID 38049604 — Prostate lineage-specific metabolism governs luminal differentiation
- **Results presentation**: as in the ORA half of this same paper, the clusterProfiler-based
  GSEA is confined to a secondary validation experiment reported in Extended Data (UK5099- and
  butyrate-treated organoids), run on a coefficient extracted from a two-factor linear model
  rather than a simple two-group contrast; the paper's headline pathway analysis instead uses
  DAVID (KEGG) and the standalone GSEA_4.0.3 desktop application, not clusterProfiler.
- **Methods sentence structure**: the ranking step is described narratively, in the same
  sentence as the direction of sorting, before the tool is even named — "we ranked the genes
  according to their log2(Coefficient) from high to low. GSEA was then performed using the R
  package clusterProfiler (v.3.17)" — with no gene-set database, cutoff or permutation count
  given anywhere in this Methods paragraph; visualization software is named in the following
  sentence instead.

## PMC8617254 / PMID 34824198 — Heterogeneous recruitment abilities to RNA polymerases (yeast growth model)
- **Results presentation**: GSEA here ranks genes by a theoretical/biophysical quantity derived
  from the paper's own mathematical model (a fitted "nonlinear scaling degree," not a
  differential-expression statistic), tested against three qualitatively different kinds of
  gene sets in three separate sub-analyses: KEGG pathways (via a custom BRITE-hierarchy gmt),
  two hand-picked GO cell-cycle terms, and transcription-factor promoter motifs derived from the
  paper's own CentriMo motif-discovery step — i.e. none of the three gene-set collections is
  used as originally distributed; each was custom-built for this paper.
- **Methods sentence structure**: package, version and every numeric GSEA parameter (both
  p/q-value cutoffs and the permutation count) are given together in one sentence up front
  ("using package clusterProfiler (version 3.12.0)... The cut-off criteria were set as both the
  p value and the false discovery rate (FDR) q value < 0.05. The number of permutations used in
  the analysis is 1e5."), and only afterward, in three separate clauses, does the Methods
  explain how each of the three custom gmt files was separately constructed.

## PMC7705019 / PMID 33257699 — Genomic and transcriptomic alterations, drug vulnerability (ACGEJ)
- **Results presentation**: two distinct GSEA-style analyses appear in the same paper under
  different framings — a conventional pathway-vs-normal/tumour GSEA (ranking not restated in
  that sentence) and a second, more unusual use in which GSEA is run not on a differential-
  expression ranking but on a partial Spearman correlation coefficient between each gene and a
  mutational-signature activity score, to ask whether curated cancer hallmark gene sets are
  enriched among "Signature 17-correlated genes" — a mutational-process-driven ranking rather
  than a case-control comparison.
- **Methods sentence structure**: the correlation-based ranking metric is described two
  sentences before GSEA is even mentioned, in a separate paragraph about calculating partial
  Spearman's correlation "controlling for tumour purity and the activities of other four
  signatures," so that by the time the text says "...enriched with Signature 17-correlated genes
  using GSEA on the calculated correlation coefficients," the reader must backtrack to find what
  is actually being ranked; no clusterProfiler version, cutoff or permutation count is restated
  for this specific correlation-based GSEA call (a version, 3.10.1, is given for the separate,
  earlier pathway-activity GSEA elsewhere in the same Methods section).

## PMC13446901 / PMID 42559948 — The cistrome response to hypoxia in HUVECs (MOA-seq)
- **Results presentation**: GSEA is run once per hypoxia time point (1, 3 and 24 hours) and once
  per hierarchical gene-expression cluster within each time point, so the "gene set enrichment
  analysis" step is really a grid of many small GSEA runs, each restricted to only the DEGs that
  fall in one cluster at one time point; outputs (NES, p-values, gene ratios) are exported as
  per-cluster, per-time-point CSV files rather than a single combined figure.
- **Methods sentence structure**: the ranking variable (Log2FC from DESeq2, one clause) and the
  gseGO call (BP ontology, minGSSize/maxGSSize/pvalueCutoff, next clause) are stated in the same
  sentence but the actual multiple-testing correction method is never named, even though a
  p-value cutoff (0.05) is given — an example of a cutoff without a stated adjustment method.

## PMC7592056 / PMID 33110069 — Overcoming resistance to anti-PD-L1 therapy (TCR/scRNA-seq)
- **Results presentation**: clusterProfiler-based GSEA is explicitly run together with (not
  instead of) the enrichR web tool in the same analysis step, and its output (normalized
  enrichment scores from six pooled MSigDB collections: Hallmark, GO BP, BioCarta, KEGG,
  Reactome, PID) is shown only as heatmaps of NES values for "relevant biological pathways,"
  manually selected rather than an unfiltered top-N list; a separate, complementary single-cell
  AUCell analysis is run in parallel as a per-cell robustness check on the same gene sets.
- **Methods sentence structure**: tool names are given together without disambiguating which
  software produced which specific result ("was done using enrichR and clusterProfiler in R"),
  the six source databases are listed together in one sentence, and the enrichment cutoff (p <
  0.05 and FDR q < 0.25) is stated as a single combined criterion in the final sentence of the
  paragraph, with no ranking metric, permutation count or clusterProfiler version given anywhere.

## PMC11610457 / PMID 39284687 — Long-read transcriptomics of ccRCC (DRS/PCR-cDNA-seq)
- **Results presentation**: GSEA output feeds directly into an immune-deconvolution comparison
  in the same Methods subsection ("Tumor purity and tumor-infiltrating immune cell population
  abundance were estimated using..."), so functional enrichment and immune-cell-composition
  estimation are presented as two halves of one combined "Gene set enrichment analysis and
  tumor-infiltrating immune cell analysis" step rather than as separate analyses.
- **Methods sentence structure**: the single most fully parameterised GSEA call among the ten —
  every clusterProfiler argument is named explicitly, each on its own labelled clause: "Permutations
  (nPerm):10,000, minimum gene set size (minGSSize): 5, Maximum gene set size (maxGSSize): 500,
  Minimum P-value (PvalueCutoff) = 0.05, Organism (Orgdb) = org.Hs.eg.db, PAdjustMethod =
  Benjamini–Hochberg (BH)" — yet, despite this exhaustive parameter list, the ranking metric used
  to order genes for GSEA itself is never explicitly stated in this passage (a DEG cutoff of
  Padj <= 0.1 and |log2FC| >= 2 is given earlier, but that defines a DE gene list, not a rank).

## PMC9684078 / PMID 36289336 — Phenotypic plasticity and genetic control in colorectal cancer evolution
- **Results presentation**: GSEA is run on genes differentially expressed between an
  evolutionarily "selected" tumour subclone (inferred from a Bayesian spatial agent-based model
  fit to multi-region sequencing data) and the remaining tumour regions, with an explicit
  permutation-based false-positive control folded into the same sentence — "genes found to be
  differentially expressed in more than 5% of shuffled analyses were excluded" — before the
  enrichment step is even run, so the input gene list itself has already been permutation-
  filtered by the time GSEA sees it. Volcano plots of the DEGs are shown; GSEA results
  themselves are referenced only as "Significant results are shown in Supplementary Fig. 26."
- **Methods sentence structure**: three different clusterProfiler ranked-list functions are
  named together for three different gene-set types in one sentence — "enrichment of Gene
  Ontology annotations, KEGG pathways and Hallmark pathways was tested for (FDR < 0.05) using
  gseGO, gseKEGG and GSEA, respectively, from ClusterProfiler" — with the ranking metric (DESeq2
  test statistic) given in the clause immediately before, and no clusterProfiler version,
  permutation count or gene-set-size limits stated anywhere in this passage.
