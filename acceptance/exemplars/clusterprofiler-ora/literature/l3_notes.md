# clusterprofiler-ora — L3 close-reading notes

Close reading of the 10 tier-A, most-parameter-rich exemplars (layer `L3+L4`). Own words;
quotes are verbatim fragments (<=25 words) copied from the Methods text retrieved via
`collect.py methods`. "not stated" where the Methods text gives no information on a point.

## PMC10734203 / PMID 38129866 — ENGEP: unmeasured gene expression prediction (spatial transcriptomics)
- **Results presentation**: the enrichGO-style call is not the paper's main result at all — it
  is a one-sentence coda tacked onto the description of "novel spatial patterns from predicted
  gene expression" ("we employ Gene Ontology enrichment analysis using the clusterProfiler R
  package to unveil the biological processes associated with these novel spatial patterns"),
  with no accompanying figure number, dot plot or bar plot mentioned in the Methods text itself.
- **Methods sentence structure**: extremely terse — package name only, no function name
  (enrichGO is implied, not written), no version, no ontology, no cutoff. The only quantitative
  detail given for the whole enrichment step is the *background* gene set, stated in a separate
  clause at the very end of an unrelated results-generation paragraph: "the background gene list
  comprises the union of genes included in the reference datasets." This is a case where the
  input-gene-list definition (SCI-based novel gene-expression pattern clusters, defined several
  paragraphs earlier) is much more detailed than the GO-enrichment call that consumes it.

## PMC9723654 / PMID 36473863 — Extracellular traps from vascular smooth muscle cells drive atherosclerosis
- **Results presentation**: GO/pathway results feed two different downstream displays for two
  different gene-list types in the same clause — "Cluster marker sets and differentially
  expressed genes were tested individually for overrepresentation" — plus a separate cnetplot
  visualization mentioned for the RNA-seq-based clusterProfiler call in a different subsection
  ("Gene ontology (GO) enrichment analysis and cnetplot of selected GOs were done with R package
  clusterProfiler"). AUCell single-cell pathway scoring is run in parallel as a complementary,
  non-ORA display of the same canonical-pathway gene sets.
- **Methods sentence structure**: unusually explicit about the *statistical justification* for
  the test rather than just naming a function — "computation of enrichment P values (the
  enricher R function, default parameters) from the hypergeometric distribution of total genes
  in the background gene set..." — spelling out the classic 4-number hypergeometric contingency
  table in prose instead of just citing enrichGO(). The background/universe is stated plainly
  ("all expressed/detected genes in each case used as a background control") right next to the
  P-value-adjustment clause ("adjusted...using Benjamini–Hochberg correction as before"), so the
  two pieces of information that are usually scattered are, here, adjacent.

## PMC13534237 / PMID 42680560 — Long-read sequencing reveals novel splicing and neojunctions (NPC)
- **Results presentation**: the enrichment step is explicitly a *robustness check* against
  expression-level confounding, not just a discovery step — the paper builds "expression-matched
  permutation" gene sets (200 permutations) and computes an empirical P-value for every enriched
  pathway by comparing its clusterProfiler-derived P-value against the distribution of P-values
  from the permuted, expression-matched gene sets. This means the clusterProfiler result is only
  the first stage of a two-stage significance test, and the more novel second stage is described
  at greater length in the Methods than the clusterProfiler call itself.
- **Methods sentence structure**: package + version + three gene-set collections are all named
  in one sentence ("identified using the MSigDB C2, C5, and Hallmark collections... performed
  using the R package clusterProfiler (version 3.16.1)"), and the *universe* gets its own,
  carefully justified sentence directly afterward ("A matched background gene set was used for
  all enrichment tests and was defined as the intersection of..."), explicitly stating the
  scientific reason for that choice ("reduced potential bias").

## PMC9718532 / PMID 36459481 — Lhx2 is a progenitor-intrinsic modulator of Sonic Hedgehog signalling
- **Results presentation**: the enrichKEGG output is used narrowly to connect two other
  ChIP-seq/ATAC-seq results together — Lhx2 ChIP-seq peaks and ATAC-seq differential-accessible
  regions (DARs) are each independently annotated to nearby genes, and enrichKEGG is run once on
  the resulting Lhx2-associated gene list, feeding directly into the paper's Shh-pathway
  narrative rather than a general survey of enriched terms.
- **Methods sentence structure**: the input-gene definition is spread across the *previous*
  sentence, describing peak annotation with ChIPseeker ("identify the closest gene to the peak
  or genes within 10 kb of the peak") and only then does a short clause name the enrichment call
  itself ("analyzed for gene set overrepresentation with the KEGG database as the reference,
  using the enrichKEGG function in clusterProfiler") — no version, cutoff, or universe given at
  all for the enrichment step; all the specificity in this Methods paragraph is spent on how
  peaks were assigned to genes, not on the enrichment statistics.

## PMC12720443 / PMID 41422243 — Antisense transcription induces expression memory via promoter competition
- **Results presentation**: enrichGO is run three times in parallel on three non-overlapping
  gene categories from the same experiment (genes in 3' overlaps, promoter overlaps, or no
  overlap) and the three result sets are shown together as a single supplementary figure panel,
  with the paper stating explicitly that "only terms with at least one condition with a FDR <
  0.05 are shown" — i.e., the display filters *across* the three parallel runs rather than
  within any one of them.
- **Methods sentence structure**: the clusterProfiler call is written almost like literal R code
  embedded in prose — "enrichGO(OrgDb = org.Mm.eg.db, ont = "BP", pAdjustMethod = "fdr")" — giving
  every function argument by name, which is the most code-like presentation among the 10 L3
  articles; by contrast the input-gene-list restriction ("restricted the analysis to
  GENCODE-annotated transcripts that were detected in our nascent transcriptome assembly") is
  described in plain English one sentence earlier, in a different register from the code-styled
  function call.

## PMC9825192 / PMID 36537238 — CHD8 suppression impacts H3K36 trimethylation and alternative splicing
- **Results presentation**: the GO enrichment result (from the enricher function) is only one of
  two parallel enrichment approaches applied to the identical gene list — the same "genes losing
  H3K4me1, H3K27ac and H3K36me3 peaks in CHD8 knockdown" are also tested against curated,
  non-GO custom gene sets "by using one-tailed Fisher's exact test," and only the non-redundant,
  most significant custom-gene-set hits (P < 0.01) are shown in the main figure — the clusterProfiler-based
  GO/slimGO enrichment results are described but apparently relegated to a supplementary table.
- **Methods sentence structure**: tool, version, and statistical cutoff arrive together in one
  sentence ("tested for enrichment of Gene Ontology (GO) terms with the enricher function from
  clusterProfiler [version 3.10.1] with Benjamini–Hochberg adjusted P-value cut-off of 0.05"),
  followed immediately by a clause naming the *source* of the gene-set annotation itself ("The
  full list of slimGO terms used was downloaded from Ensembl BioMart on September 9, 2019") —
  an unusually explicit provenance statement for the annotation file, rarely seen at this level
  of detail in the other nine articles.

## PMC7688965 / PMID 33239621 — The Hsp70-Hsp90 co-chaperone Hop/Stip1 and the proteostatic balance
- **Results presentation**: two separate GO-enrichment analyses are run on two different
  proteomics datasets with two different tools — the whole-cell MS dataset is analysed with
  clusterProfiler (restricted to Biological Process terms), while the Hop(HA)-IP-MS
  interactome dataset is analysed instead with the Enrichr web server, "focusing on KEGG and
  WIKI pathway-annotated proteins" — i.e., the clusterProfiler-based GO result and the
  Enrichr-based pathway result sit side by side in the same subsection but are not
  interchangeable or merged.
- **Methods sentence structure**: the input-gene selection criterion is unusually quantitative
  and dual-threshold, combining a fold-change cutoff with a multivariate-model importance
  score in one clause — "those proteins, which changed the most (fold change >0.4 or smaller
  than −0.4 and with a VIP value over 1)" — where VIP (variable importance in projection) comes
  from an OPLS-DA model fitted earlier in the same Methods section, so understanding the
  enrichment's input list requires reading a separate multivariate-statistics paragraph first.

## PMC13450225 / PMID 42566510 — Transposable elements and immune dynamics in melanoma epi-immunotherapy
- **Results presentation**: this is the most methodologically layered of the ten — the enricher()
  call is the last step of a multi-stage funnel (TF motif enrichment on differentially
  accessible chromatin -> cis-regulatory element mapping to linked genes -> intersection with
  up-regulated DEGs -> overrepresentation analysis of that final filtered gene set), so the
  "input gene list" for the ORA step is the product of several upstream computational filters,
  each separately named and each with its own threshold (motif fold-enrichment >= 1.3, DA peak
  log2FC >= 0.58 and adjusted P < 0.05, DEG adjusted P < 0.05).
- **Methods sentence structure**: the enricher() call itself is compressed into a single relative
  clause at the end of a long descriptive sentence about the upstream filtering steps — "These
  filtered gene sets were then subjected to overrepresentation analysis using the enricher
  function from clusterProfiler..., using curated gene sets from databases including GO
  biological process categories, Reactome, KEGG, and Hallmark" — with no cutoff, universe or
  version given for the enricher() call itself, in contrast to the very precise numeric
  thresholds given for each of the upstream filtering steps that produced its input.

## PMC10709144 / PMID 38049604 — Prostate lineage-specific metabolism governs luminal differentiation
- **Results presentation**: the enrichment analyses (GSEA and GO ORA) are explicitly confined to
  a *validation/robustness* experiment reported only in an Extended Data figure ("These methods
  apply to Extended Data Fig. 8"), separate from the paper's main KEGG/DAVID-based pathway
  analysis of the primary RNA-seq dataset — i.e., the clusterProfiler-based ORA is a secondary,
  smaller-scale confirmatory analysis (UK5099- and butyrate-treated organoids) rather than the
  headline pathway result of the paper.
- **Methods sentence structure**: up- and down-regulated gene lists are each defined by a
  two-part, symmetric numeric threshold given in full for both directions in one sentence —
  "upregulated genes (log2(Coefficient) > 1, −log10(FDR) > 1) and downregulated genes
  (log2(Coefficient) < −1, −log10(FDR) > 1)" — followed immediately, in the same sentence, by
  the tool name and version ("using the R package clusterProfiler (v.3.17)"), with no separate
  mention of a p-value/q-value cutoff, gene-set database, or universe for the enrichment call
  itself; visualization tool (BoutrosLab.plotting.general) is named in a following sentence.

## PMC11662933 / PMID 39575480 — SNORD116/Prader-Willi hESC neuronal model
- **Results presentation**: the same GO/DO enrichment call is applied three times to three
  differently-combined gene lists (upregulated only, downregulated only, and combined) that were
  themselves derived from a fairly elaborate cross-genotype/cross-background reproducibility
  filter (DEGs retained only if they recur across three separate DESeq2 model specifications and
  survive a permutation test comparing observed vs. shuffled overlap counts) — so the Methods
  paragraph that precedes the enrichment call is considerably longer and more statistically
  involved than the enrichment call itself. Results are shown as dot plots ordered by adjusted
  P-value and fold enrichment, plus a Gene-Concept Network plot from the enrichplot package.
- **Methods sentence structure**: the fullest, most complete single-sentence specification among
  all 30 ORA articles — tool, version, companion package and version, both function names, both
  adjustment arguments and the exact cutoff are all given together: "processed for gene (GO) and
  disease ontology (DO) analysis using the clusterProfiler package (v.4.4.4) and DOSE (v.3.22.1)
  with functions of enrichGO() and enrichDGN(), respectively with options for pAdjustMethod =
  'BH' and qvalueCutoff = 0.05" — and the universe is defined in the very next sentence with
  equal precision ("The universe used was the list of genes in each DESeq2 object generated via
  the 'Background_Condition' contrasts"), with the simplify() redundancy-reduction step and its
  two alternate cutoff values (0.7 or 0.8) given in a third, separate sentence immediately after.
