# gsva-score — L3 close-reading notes

Close reading of the 10 tier-A exemplars (layer `L3+L4`). Own words; quotes are verbatim
fragments (<=25 words) copied from the Methods text retrieved via `collect.py methods`.
"not stated" where the Methods text gives no information on a point.

## PMC7755902 / PMID 33353943 — Asian breast cancers molecular landscape (TCGA + SD cohorts)
- **Results presentation**: GSVA is one of three parallel immune-scoring approaches (alongside
  ESTIMATE and CIBERSORT/TIMER) run over the same RNA-seq TPM matrix, each contributing a
  column to later regression and correlation analyses; the paper explicitly standardises how
  every resulting box plot is drawn ("the boxes indicate 25th percentile, median, and 75th
  percentile"), so GSVA scores are never given their own bespoke figure type, only shared
  conventions with the other immune-scoring methods.
- **Methods sentence structure**: a single dense sentence lists three separate GSVA calls, one
  per gene-set source, chained with "as well as" rather than split into separate paragraphs —
  "as well as with GSVA (v. 1.26) using the combined immune cell gene sets from Bindea et al."
  — package version and gene-set citation sit side by side, but no method (gsva/ssgsea/zscore),
  kcdf or input scale is stated anywhere in this paragraph; the only expression scale named in
  the sentence belongs to the neighbouring ESTIMATE call ("RNA-seq TPM gene expression scores"),
  not restated for GSVA itself.

## PMC12807877 / PMID 41413654 — NPM1 supports WNT-driven hyperproliferation (CRC/HCC)
- **Results presentation**: GSVA appears twice for two different purposes: first, as a
  Python-based GSEApy reimplementation applied directly to whole expression matrices (tumour
  vs normal, or tumour-only) to look at "the variation within tumour samples alone"; second, as
  the genuine GSVA R package producing a single-sample score for one curated Hallmark
  signature ("DNA repair") that is then used as a continuous covariate downstream. The paper
  never visually distinguishes which of its many extended-data panels come from which
  implementation.
- **Methods sentence structure**: version numbers are given for every R package in the chain
  but attached inline as superscript-style citations rather than prose — "to obtain the
  single-sample GSEA score using the GSVA84 (v.1.42.0) R package" — with the upstream gene-set
  source (msigdbr, Hallmark) named in the preceding clause and no method argument, kcdf or
  downstream statistical test mentioned at all for this specific score.

## PMC9705439 / PMID 36443313 — LATS1/2 drives luminal-basal plasticity (mammary)
- **Results presentation**: ssGSEA-projected signature activity (from a package citation, not a
  described function) is used exclusively to stratify TCGA-BRCA patients into two groups by a
  "Total activity" difference score for Kaplan-Meier survival curves, and separately correlated
  against an independent Sox9-high/low signature with Pearson correlation — i.e. GSVA/ssGSEA
  scores in this paper are always intermediate values feeding a second statistic (median split
  survival, or Pearson r), never reported or plotted as raw enrichment scores on their own.
- **Methods sentence structure**: the method name and package are fused into one clause
  — "using a single sample GSEA (ssGSEA) method from the R package GSVA (v1.34.0)" — with the
  input scale given in the very next, separate sentence ("Counts underwent a variance-stabilizing
  transformation using DESeq2 followed by a log transformation"), so package/method and input
  transformation are reported as two consecutive but grammatically independent sentences.

## PMC8683505 / PMID 34921143 — Immune/non-immune cell interactions in HNSCC
- **Results presentation**: a single GSVA score, built from a custom top-100-DEG fibroblast/CAF
  signature (not a public collection), is used only to binarise TCGA HNSCC samples into
  High/Low groups by a mean-value-free median split, feeding directly into a Kaplan-Meier
  overall-survival plot — GSVA here is a one-off derived biomarker, not a systematic pathway
  panel.
- **Methods sentence structure**: unusually terse and generically worded, almost narrating code
  ("A GSVA score was computer per sample using TCGA HNSCC RNAseq data" — note the paper's own
  typo, "computer" for "computed"), with no package version, method argument, kcdf or gene-set
  database named anywhere in this subsection; only the downstream Kaplan-Meier/`survfit()` step
  is described with any specificity.

## PMC7730477 / PMID 33303760 — Single-cell RNA landscape of intratumoral heterogeneity (OS)
- **Results presentation**: this paper runs two conceptually different gene-set methods side by
  side in the same subsection — a modified, self-contained-style competitive test explicitly
  named after limma's CAMERA ("following the modification of the competitive gene set
  enrichment test CAMERA developed by Cillo et al.", embedded in the `SingleSeqGset` package, not
  limma itself) for cluster-vs-rest DE-based GSEA, and separately GSVA for T-cell/macrophage/DC
  subtype activity scores — so a reader has to track two different "competitive" pathway
  numbers computed by two different tools in the same Methods paragraph.
- **Methods sentence structure**: GSVA is introduced only after CAMERA-via-SingleSeqGset, joined
  by "we also applied" — "we also applied the non-parametric and unsupervised algorithm named
  gene set variation analysis (GSVA) to assess the relative pathway activities" — with signature
  gene lists attributed by citation (Chung et al.) rather than a named database, and no method,
  kcdf, input scale or downstream statistical test given for the GSVA step itself.

## PMC10689851 / PMID 38036539 — Interplay of oncogenic pathways and immune microenvironment
- **Results presentation**: GSVA-derived "enrichment scores" for 24 custom microenvironment
  cell-type signatures are purity-adjusted before being displayed as relative-abundance
  ("constituent pattern") plots across tumour clusters, i.e. the raw GSVA number is always
  transformed (divided by 1-purity) before it reaches a figure; a second, unrelated GSVA/ssGSEA
  call scores a curated EZH2-partner Hallmark signature for a completely different survival-type
  panel.
- **Methods sentence structure**: the first GSVA mention buries the package citation at the end
  of a long descriptive clause — "We used gene set variation analysis on these gene sets to
  generate enrichment scores for each cell by using the R package GSVA (v1.46.0)" — while the
  second, later in the same Methods section, instead leads with the method name — "single sample
  GSEA (ssGSEA) approach through the R package GSVA84 (v.1.42.0)" [sic, version differs from the
  first use] — so the same paper cites two different GSVA version numbers in two places.

## PMC8439149 / PMID 33299191 — Wilms tumour anaplasia, immune/genomic landscape
- **Results presentation**: two separate ssGSEA/GSVA calls exist in this paper for two very
  different biological questions — a microenvironment deconvolution compendium (modified
  LM22+MCPcounter) scored with GSVA for tumour-infiltration figures, and an unrelated
  single-sample GSEA score for one MSigDB-derived EZH2-target gene signature used only in a
  drug-sensitivity/stem-cell-network narrative — with no shared figure type between the two.
- **Methods sentence structure**: the first instance names the package inline, quoted like a
  variable name — "using the R package GSVA (v1.46.0)" — after describing how the 364-gene
  compendium was assembled; the second instance omits any method or kcdf and only states
  provenance of the gene set ("EZH2 partners retrieved from the term KAMMINGA_EZH2_TARGETS in
  MSigDB"), with the actual GSVA/ssGSEA sentence reduced to a single clause at the very end
  ("calculated using a single-sample GSEA (ssGSEA) approach through the R package GSVA84").

## PMC8791834 / PMID 34875674 — Multi-omic ML predictor of breast cancer therapy response
- **Results presentation**: three named signatures (GGI, embryonic stem-cell-like, STAT1) are
  scored with both GSVA and ssGSEA from the same package call and then simply thresholded at the
  sample mean into "High"/"Low" categories for later figure panels, rather than plotted as
  continuous scores; a derived paclitaxel-response "metagene" (built from two hand-picked gene
  geometric means, not GSVA/ssGSEA) sits in the same subsection, so a reader must distinguish
  package-derived scores from ad hoc metagene arithmetic in one paragraph.
- **Methods sentence structure**: GSVA and ssGSEA are named together as a pair of methods run
  from one package invocation — "GSVA and ssGSEA were performed using the GSVA R package
  (version 1.34) on (1) the GGI gene set...(3) the STAT1 immune signature" — with the input scale
  given in the very next sentence ("The log-transformed TMM normalized TPM counts were used as
  input to the GSVA package"), and the binarisation rule stated as a separate, third sentence
  ("A high GSVA score was defined as any score above the mean value").

## PMC7720616 / PMID 33287869 — Single-cell transcriptome of an adult human cell atlas (AHCA)
- **Results presentation**: GSVA/GSEA are run generically across "each transcriptional dataset"
  on the fixed panel of 50 Hallmark pathways, with an extra, dataset-specific curated metabolic
  pathway set added only for epithelial cells in two of the atlases (AHCA, HCL) — so the same
  Methods sentence covers a default, atlas-wide pathway panel plus one cell-type-specific
  extension, without a dedicated figure type described for either.
- **Methods sentence structure**: GSVA and GSEA (the Broad desktop tool) are presented as
  interchangeable alternatives joined by "or" in a single sentence — "using R package GSVA
  (version 1.34.0) or GSEA software (version 4.0.3)...with default parameters, respectively" —
  which leaves the reader to infer from "respectively" which figures used which tool; no method
  argument, kcdf, input scale or downstream statistical test is given for the GSVA branch.

## PMC12764429 / PMID 41388153 — Long COVID proinflammatory/immune activation
- **Results presentation**: this is the most method-layered of the ten — a first, custom
  rank-based ssGSEA implementation (its own ECDF-difference formula, spelled out in prose) scores
  leading-edge pathways from a prior GSEA run, feeding an RF classifier whose per-pathway
  importances (Gini decrease) are shown as bar/scatter plots; separately, a plainly worded
  "Statistical analyses" paragraph states that "Sample-level ssGSEA was performed using the GSVA
  (v.1.40) R package" and that scores are compared with box-plot medians and a Mann-Whitney
  U-test — leaving it ambiguous whether the custom implementation and the GSVA-package run are
  the same pathway scores described twice, or two distinct scoring passes.
- **Methods sentence structure**: the GSVA-package sentence is folded into a long, general
  statistics paragraph rather than given its own subheading, immediately followed by an
  explanatory, discursive sentence rather than a numeric threshold — "The ssGSEA analysis
  delineates a comparative exploration of the groups' median values, visually represented
  through the data distribution and median lines" — before finally naming the actual test
  ("The two-sided Mann–Whitney U-test was used to identify significant differences between
  groups").
