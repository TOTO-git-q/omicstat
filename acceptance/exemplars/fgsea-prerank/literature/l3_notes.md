# fgsea-prerank — L3 close-reading notes

Close reading of the 10 tier-A, layer "L3+L4" exemplars. Own words; quotes are verbatim
fragments (<=25 words) copied from the Methods text retrieved via `collect.py methods`.
"not stated" where the Methods text (the only section this tool returns) gives no
information on a point. Across this set, only two of the ten papers name an actual plot
function for the fgsea output in their Methods section — the rest describe only the
statistic (NES, p value) that fgsea returns, leaving the plot itself to the Results/figure
legends, which this tool does not retrieve.

## PMC10703680 / PMID 38052989 — In vitro modeling of the human dopaminergic system (organoids)
- **Results presentation**: not stated for the fgsea call itself; the paragraph instead
  describes a battery of custom, non-standard "enrichment lists" (striatum/cortex signature
  genes, a GO-term-plus-own-markers ventral-midbrain list, a VoxHunt top-100-pallial gene
  list) used as the gene sets, with no plot function named for any of them.
- **Methods sentence structure**: the two clusterProfiler-family tools are named back to back,
  in one clause each, as if interchangeable steps of the same pipeline — "gene set
  overrepresentation analysis of differentially expressed genes was conducted using
  clusterprofiler v4.4.4, and gene set enrichment analysis was performed with fgsea v1.22.0" —
  then a separate sentence lists every custom gene set by name and source, each with its own
  in-line citation, rather than naming one canonical database (Hallmark/KEGG/GO).

## PMC7733508 / PMID 33311484 — A meta-learning approach for genomic survival analysis
- **Results presentation**: not stated; the paragraph's only descriptive detail about the
  fgsea output is procedural, not visual — it "calculates a cumulative gene set enrichment
  statistic value for each gene set" — with no NES/plot terminology used anywhere.
- **Methods sentence structure**: unusually, the ranked list fed to fgsea is not a
  differential-expression statistic at all but a model-interpretability output — "all the
  genes, together with their ranked risk scores were incorporated in the gene set enrichment
  analysis with the fgsea R package40" — introduced only after two other, non-GSEA gene-
  prioritization approaches (hypergeometric overrepresentation of the top/bottom 10%) are
  described first as alternatives.

## PMC7773548 / PMID 33357438 — RTEL1 regulates G4/R-loops to avert replication-transcription collisions
- **Results presentation**: one of only two exemplars in this set that names a plotting
  step for the fgsea output, though a generic one rather than a named fgsea function —
  "visualized with a custom script based on the “ggplot2” package (v. 3.3.0)".
- **Methods sentence structure**: package name, version, and the object being tested are all
  given in one short sentence — "Enrichment analysis for fragile sites and R-loops was
  performed using the “fgsea” package (v. 1.14.0)" — with the ranking statistic
  described separately, in a different Methods subsection ("Quantification and Statistical
  Analysis"), as "the fgsea framework in R with the associated t-based testing statistics",
  i.e. the rank metric and the package call are described two subsections apart.

## PMC12807877 / PMID 41413654 — Nucleophosmin supports WNT-driven hyperproliferation
- **Results presentation**: not stated for either fgsea run; the Methods paragraph instead
  lists, by name, every Reactome/Hallmark pathway that is later shown as significant — "the
  following Reactome or Hallmark pathways are shown: Hallmark Myc V1, Hallmark Myc V2" — which
  functions as a pathway inventory rather than a description of a chart type.
- **Methods sentence structure**: the same phrase, "Functional analyses were performed with the fGSEA package99" is reused twice for two different data types (Riboseq/cytoplasmic RNA,
  then proteomics), with only the second occurrence adding its ranking metric inline —
  "preranking genes by test difference" — while the first occurrence states no ranking metric
  at all, relying on the reader to infer it from the differential-expression step described
  earlier in the same subsection.

## PMC9977678 / PMID 36509106 — Active eosinophils regulate host defence in colitis
- **Results presentation**: not stated for the FGSEA call; the only reporting-related detail
  given is the multiple-testing outcome, not a chart — "filtered for significantly enriched
  gene sets (Bonferroni-adjusted P < 0.05)".
- **Methods sentence structure**: the ranking formula is given as literal R code inside the
  prose rather than described in words — "in R, ‘- log(p_val)*sign(avg_log2FC)’" —
  immediately followed by the package call itself, "GSEA was performed on this pre-ranked list
  using the R package FGSEA ... with default parameters and the GO Biological Process
  database", so the algorithm variant (Simple vs Multilevel) is left unstated ("default
  parameters" standing in for it), unlike the sister paper PMC8810382 below which names
  FGSEA-simple explicitly for the same ranking formula.

## PMC8820740 / PMID 34939924 — FMRP regulates mRNAs encoding distinct functions in dendrites
- **Results presentation**: not stated; no plot, NES, or p-value-reporting convention is
  named anywhere in this short paragraph.
- **Methods sentence structure**: the shortest fgsea Methods passage in the set — two
  sentences total, the gene sets described as coming from a different tool entirely rather
  than a named database — "GSEA was performed using the fgsea package (Korotkevich et al.,
  2021) using the gene lists from module detection as pathways" — i.e. the pathway
  collection here is itself the output of an upstream HumanBase functional-module-detection
  step, not MSigDB/KEGG/GO.

## PMC12878702 / PMID 41406961 — Distinct components of mRNA vaccines instruct germinal centre responses
- **Results presentation**: not stated for the fgsea call; the paragraph ends at the test
  itself with no plot or table format mentioned.
- **Methods sentence structure**: the ranking formula, gene set, and test are compressed into
  one long sentence built around the contrast being tested — "testing genes ranked by
  −log10 p-value (signed by log fold change) for enrichment of a previously published
  LIPSTIC signature34 with the R package fgsea" — so the single custom signature (LIPSTIC)
  takes the place of a named collection like Hallmark or GO.

## PMC11623926 / PMID 39641768 — Increased inflammatory signature in myeloid cells of NSCLC
- **Results presentation**: not stated for the fgsea plot; the only reported output detail is
  the significance rule itself — "Significant gene set enrichment was determined only for
  adjusted p < 0.05" — given as a separate, later sentence in a different Methods subsection
  ("Statistical Analysis") rather than beside the fgsea call.
- **Methods sentence structure**: fgsea is named for the scRNA-seq layer specifically, with an
  unusual ranking input for a pre-ranked method — "the AUC rank of DEGs obtained with and
  without CHIP for each cluster was used as input" — i.e. an AUCell-style per-cell/per-cluster
  AUC score stands in for the more usual log-fold-change or test-statistic ranking.

## PMC8770127 / PMID 34937944 — Targeting SWI/SNF ATPases in enhancer-addicted prostate cancer
- **Results presentation**: the other of the two exemplars that names its own plot function,
  and the only one in the set to name an actual fgsea function for it — "the plotEnrichment
  function was used to plot enrichment for the pathways of interest" — i.e. fgsea's own
  built-in enrichment-curve plot, not a third-party package.
- **Methods sentence structure**: the gene sets are defined before the test is named at all —
  first two custom, study-specific knockdown signatures (ERG, FOXA1: "containing 250
  significantly downregulated genes"), then a named collection reused from elsewhere ("For AR
  and MYC, the Hallmark gene signatures were used") — and only after both are established does
  the sentence turn to the method: "perform a fast pre-ranked GSEA using fgsea bioconductor
  package39 in R."

## PMC8810382 / PMID 34875673 — Signature of long-lived memory CD8+ T cells in acute SARS-CoV-2 infection
- **Results presentation**: not stated as a plot; the paragraph instead specifies the
  reproducibility and reporting convention in unusual detail — a fixed random seed
  ("set the seed value (‘set.seed(42)’ in R) before execution to make the results
  reproducible") and the final filter, "filtered for gene sets that were significantly
  enriched with adjusted P < 0.1" — rather than a chart type.
- **Methods sentence structure**: the most explicit of the ten about which fgsea algorithm
  variant is used — "We used the FGSEA-simple procedure with 100,000 permutations" — named
  together with the gene set and organism in the same sentence, and immediately followed by a
  second sentence naming the actual significance-testing call, "the function fgsea::fgsea()
  was used, which performs a P value estimation based on an adaptive multi-level split
  Monte-Carlo scheme" — i.e. the paper names both the simple/permutation description and the
  underlying adaptive multilevel estimator in two consecutive sentences, without reconciling
  that fgsea::fgsea() itself dispatches to the multilevel algorithm once gene sets are large.
