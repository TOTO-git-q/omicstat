# clusterprofiler-compare — L3 close-reading notes

Close reading of the 10 tier-A, layer "L3+L4" exemplars. Own words; quotes are verbatim
fragments (<=25 words) copied from the Methods text retrieved via `collect.py methods`.
"not stated" where the Methods text (the only section this tool returns) gives no
information on a point — several of these papers describe how compareCluster results are
visualized only in the Results/figure legends, which are outside what this tool retrieves.

## PMC13545235 / PMID 42697881 — Therapy-induced senescence promotes immunogenicity in AML
- **Results presentation**: Methods gives no figure number or plot function for the
  compareCluster output itself; the "Dotplot" and "RidgePlot" function names that do appear
  in this Methods text belong to a different, Seurat-based analysis (per-cell module scores),
  not to the peptide/compareCluster enrichment.
- **Methods sentence structure**: the input list is described first, in the same sentence as
  the function name — "The function compareCluster, from the clusterprofile package, was
  adopted for the over-representation analysis of the union of genes associated with peptides
  per group" — then the three databases and their three matching enrichment functions are
  listed together in one final clause: "were respectively tested with enrichKegg, enrichPathway
  ... and enrichGO function (parameters pvalueCutoff = 0.05, pAdjustMethod = “BH”)."
  No clusterProfiler version is given for this call (a version is given only for ReactomePA).

## PMC8602344 / PMID 34795282 — Single-cell analysis of immune phenotypes in malignant pleural effusion
- **Results presentation**: not a plot for the compareCluster call itself; the paragraph's
  only stated output format is numeric — "the average enrichment score was determined for
  each cluster" — for a separate, KEGG-based metabolic-pathway scoring step, not for the GO
  compareCluster result.
- **Methods sentence structure**: extremely terse, two short sentences, with the fun
  parameter given inline in parentheses rather than as prose: "The gene ontology annotation
  was also performed by Monocle 3 with the compareCluster function (fun = “enrichGO”)."
  followed immediately by the significance sentence ("an False Discovery Rate-corrected P
  value < 0.05"), with no adjustment-method name and no clusterProfiler/Monocle3 version
  given anywhere in the Methods.

## PMC8586142 / PMID 34764255 — Generation of functional ciliated cholangiocytes from hPSCs
- **Results presentation**: not stated; the Methods paragraph ends at the compareCluster call
  itself with no mention of a plotting function for its output (dotplot/cnetplot etc. are not
  named anywhere in this Methods text).
- **Methods sentence structure**: the whole single-cell pipeline is narrated as one long
  chain of named Seurat functions (FindVariableFeatures, RunFastMNN, RunUMAP, FindClusters,
  FindAllMarkers) before compareCluster is reached, and only then are its own arguments given
  in one clause: "using the compareCluster function (function = enrichGO, ontology = BP,
  pvalueCutoff = 0.05)" — no pAdjustMethod and no clusterProfiler version stated for this call,
  though clusterprofiler (v3.14.3) is named earlier in the same paragraph's package list.

## PMC9531456 / PMID 36192798 — H3K18 lactylation marks tissue-specific active enhancers
- **Results presentation**: the only one of the ten that names an explicit plot function for
  the compareCluster/enrichGO output — "GO analysis results were visualized using the dotplot
  function of the R package enrichplot v.1.12.2" — given in a separate "Data visualization"
  subsection, distinct from the "Functional enrichment analysis" subsection that runs the test.
- **Methods sentence structure**: two back-to-back sentences, the first spelling out every
  enrichGO argument (database, versions, adjustment method, "searching for all ontology
  categories"), the second reusing it by reference only — "Comparative GO analysis was
  performed using the compareCluster function ... using the same settings" — so compareCluster
  itself inherits its parameters from the preceding call rather than restating them.

## PMC8454054 / PMID 34548076 — Chromatin accessibility across indicine cattle tissues
- **Results presentation**: not stated for the compareCluster GO output; the only named
  network/visualization function in this Methods text ("Gene Regulatory Network visualization
  ... using Cytoscape 3.6.0") belongs to a separate TF-binding network analysis, unrelated to
  the GO compareCluster call.
- **Methods sentence structure**: the most parameter-complete of the ten — every compareCluster
  argument is spelled out as an explicit `argument = "value"` list in one sentence: "using the
  following parameters: OrgDb = org.Bt.eg.db, fun = “enrichGO,” ont = “ALL,”
  pAdjustMethod = “BH,” pvalueCutoff = 0.05" — with the compared entity (three tissues'
  ChIP-seq peak-associated genes, tissue-specific vs. constitutive) established two sentences
  earlier rather than inside this sentence itself.

## PMC8357957 / PMID 34381042 — Chd1 protects genome integrity at promoters (applies: no)
- **Results presentation**: not stated for compareCluster; no plot function named for the GO
  output in this Methods text (a separate STRING network figure is described for a distinct,
  non-GO protein-interaction analysis).
- **Methods sentence structure**: compareCluster is named only once, generically, as the
  wrapper call — "Gene ontology (GO) pathway enrichment analysis was performed using the
  compareCluster function of clusterProfiler35 (version 3.18.1)" — and every actual parameter
  (the enrichGO sub-function, the ontology, both cutoffs, the BH correction) is given in the
  following sentence as if describing a single enrichGO run, with no second gene list ever
  named; this is why applies = no here (one filtered Chd1-IP protein list, not several).

## PMC12652333 / PMID 41296858 — Polycomb-deposited H2A monoubiquitylation, tissue-specific enhancers
- **Results presentation**: the clearest visualization pipeline of the ten — compareCluster's
  output list is handed to a second package for both clustering and plotting: "the resulting
  lists were clustered with the findPathClusters function of aPEAR" and then "visualized with
  plotPathClusters function of aPEAR" — i.e. a term-similarity network plot, not a dotplot.
- **Methods sentence structure**: compareCluster and enrichGO are described as two parallel,
  separately-invoked calls for two different gene-list types in the same paragraph (ChIP-seq
  peak-associated genes via compareCluster; differentially expressed genes via enrichGO), each
  with its own background gene set spelled out, before the shared org.Ce.eg.db/cutoff/
  pAdjustMethod parameters are given once for both.

## PMC13307697 / PMID 42351220 — Srr2-dependent SOX2 levels govern chromatin/transcription
- **Results presentation**: not stated for the compareCluster GO terms themselves; the
  Methods paragraph's only named plot is for expression values, not enrichment results —
  "Heatmaps were generated using the pheatmap package to display expression patterns"
  across the two genotypes, not the enriched GO terms.
- **Methods sentence structure**: the up/down-regulated gene lists are established two
  sentences before compareCluster is named, then every compareCluster argument is given as an
  explicit list in one clause — "with the following parameters: fun = “enrichGO”,
  OrgDb = “org.Mm.eg.db”, ont = ”BP”" — immediately followed by a second,
  separately-parameterised call to the `simplify` function for redundancy removal, with no
  pAdjustMethod/pvalueCutoff ever stated for the compareCluster call itself.

## PMC8885825 / PMID 35228570 — LKB1 drives stasis and C/EBP-mediated reprogramming
- **Results presentation**: GO term enrichment output (from K-means gene-expression clusters)
  is not plotted with a clusterProfiler function; instead it is exported to a different tool
  entirely — "imported into Cytoscape (v3.8.2) with the EnrichmentMap plugin for network
  construction using default parameters" — and the resulting term network is further processed
  with `igraph`'s edge-betweenness community detection to define secondary "clusters of related
  GO terms".
- **Methods sentence structure**: compareCluster appears last in a five-step chain (STAR
  alignment -> RSEM -> DESeq2 -> GSEA ranked list -> Cytoscape network -> K-means clusters),
  named only in passing — "GO term enrichment analysis was performed using compareCluster in
  ClusterProfiler (v3.14.3)" — with no fun/ontology/cutoff arguments given for this specific
  call anywhere in the Methods.

## PMC13443197 / PMID 42336819 — Stromal/endothelial changes from MGUS to myeloma (applies: no)
- **Results presentation**: not stated for the enrichGO/compareCluster output; the Methods
  paragraph's own next sentence moves straight to a separate GSEA run ("Additionally, GSEA was
  calculated using the Hallmark gene sets ... ranked according to log2FC") without describing
  either analysis's plot.
- **Methods sentence structure**: compareCluster is named jointly with enrichGO as if
  interchangeable, both applied to one already-filtered, singular DEG list — "ORA using the
  functions enrichGO and compareCluster in the package clusterProfiler (v 4.6.2)74 were
  conducted to interpret the enrichment and pathways of the filtered DEGs" — which is why
  applies = no: the sentence gives no second, separately-named list for compareCluster to
  compare against.
