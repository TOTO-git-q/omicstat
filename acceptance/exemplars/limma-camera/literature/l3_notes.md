# limma-camera — L3 close-reading notes

Close reading of the 10 tier-A exemplars (layer `L3+L4`) in the current, re-collected corpus.
Own words; quotes are verbatim fragments (<=25 words) copied from the Methods text retrieved via
`collect.py methods`. "not stated" where the Methods text gives no information on a point.

Unlike round 1 (where 4 of the 10 nominal L3 articles turned out, on close reading, not to apply),
**all 10 of the current L3 set apply** — a direct consequence of tightening the retrieval signal so
that the test name must share a sentence with limma, or be written as `cameraPR` / `mroast` / "camera
function|test|method"; the false positives from the English word "camera" (microscope brand names,
etc.) that inflated round 1's L3 pool are gone. This absence of negative-control examples in the L3
set is itself worth flagging for the verifier.

## PMC8660905 / PMID 34887406 — Il21r-dependent germinal-centre light/dark zone signatures — APPLIES
- **Results presentation**: `camera` p-values for light-zone/dark-zone and Myc-/FOXO1-/mTOR-
  deficiency signatures are paired in the same Methods paragraph with limma's own
  `barcodeplot` function — "Barcode enrichment plot was drawn using limma's barcodeplot
  function" — so this is one of the few papers in the corpus that explicitly names the classic
  camera+barcodeplot combination as companion outputs, one numeric (the test) and one graphical.
- **Methods sentence structure**: the test, package, and version are compressed into a single
  clause mid-sentence — "were performed using the camera function67 of the limma package
  (version 3.1.6.8)" — with every gene signature's provenance given as a separate short sentence
  immediately after (Victora et al. 2010 for LZ/DZ; other citations for Myc-, FOXO1- and
  mTOR-deficiency signatures), rather than grouped into one named database.

## PMC8643633 / PMID 34865122 — BAF155 methylation drives metastasis via super-enhancers — APPLIES
- **Results presentation**: `cameraPR` results on the 50 Hallmark gene sets sit in the same
  Methods paragraph as an entirely separate `kegga` (limma) KEGG-overrepresentation test on
  ChIP-seq peak-associated genes, and a further, non-limma Broad GSEA run on SE-signature and
  IFNα-pathway genes visualized as a heatmap (GItools) and a scatter plot — three different
  gene-set-style analyses are named in one paragraph, only one of which is `cameraPR`.
- **Methods sentence structure**: `cameraPR` is introduced tersely, function name first, with the
  gene-set collection folded into the same short sentence — "Gene set enrichment analysis was
  performed by the cameraPR function from the limma package with the 50 Hallmark gene sets" —
  and no version number, kcdf-equivalent, or downstream ranking statistic is stated for this
  specific sentence (a limma version, 3.44.3, appears earlier but attached to the `kegga` call).

## PMC8630169 / PMID 34845204 — Proteome/metabolome mediation analysis (bariatric surgery) — APPLIES
- **Results presentation**: `Roast`'s "Mixed" test (direction-agnostic pathway change) and a
  separate `CAMERA` pre-ranked run (on Hitman mediation-analysis results against SMPDB) are each
  described for a different result type — one for an integrated protein+metabolite dataset, one
  for a causal-mediation output — and the Roast section explicitly narrates why the "Mixed" test
  was chosen over a directional one ("interested in pathways that change...without regard to
  direction"), a level of methodological justification not seen in the other nine papers.
  Network-style figures (nodes coloured by t-statistic) are used to display individual
  significant analytes, not the pathway-level test results themselves.
- **Methods sentence structure**: both gene(analyte)-set tests are named by their limma function
  names in prose rather than as inline code — "We applied Limma's Roast method to this dataset
  against Small Molecule Pathway Database pathways" and, several sentences later in a different
  subsection, "with the CAMERA pre-ranked pathway analysis method43 from the Limma package" — no
  version number or inter.gene.cor value is given for either.

## PMC11564874 / PMID 39543172 — Self-amplifying RNA RSV prefusion-F vaccine in NHPs — APPLIES
- **Results presentation**: `camera` is run on an Olink Target 48 Cytokine panel (48-analyte serum
  proteomics from vaccinated non-human primates), not on RNA-seq or microarray data — comparing
  0-hour vs 24-hour post-immunization analyte levels across vaccine-dose groups against the MSigDB
  hallmark collection; this is the only proteomics-panel (rather than transcriptomics or
  metabolomics) use of `camera` in the current corpus, and the only line in the whole batch that
  states an explicit limma version (3.50.3) alongside the exact companion-package versions used
  (corrplot 0.92, msigdbr 7.5.1).
- **Methods sentence structure**: the `camera` call is a single short, terminal sentence at the end
  of a paragraph otherwise devoted to PCA and Spearman-correlation analysis of the same cytokine
  data — "Gene set enrichment analysis was performed using the 'camera' test from the limma
  package, with the default settings." — with the gene-set database given in the very next
  sentence and every package version bundled into one trailing, comma-separated list.

## PMC7673760 / PMID 33188013 — Dedifferentiation/neuronal repression in familial Alzheimer's disease — APPLIES
- **Results presentation**: `fry` (limma's self-contained rotation test) is used twice on very
  different inputs — once against a small, investigator-built transcription-factor target
  database, once against the public GOBP collection — both runs ranking genes by a `confect`
  statistic from the `topconfects` package rather than by a limma moderated-t/F statistic
  directly; the same paper runs three further, non-limma GSEA-style methods (fgsea, tmodCERNOtest,
  tmodHG) on the identical ranked lists, so `fry` is one option among five gene-set methods
  applied to overlapping data in one Methods section.
- **Methods sentence structure**: the paper explicitly narrates why the self-contained test was
  chosen over the competitive one — "The self-contained fry test was selected over the
  competitive fgsea test...due to the smaller size of our custom neural TF database." — a rare,
  explicit self-contained-vs-competitive justification tied to gene-set size, not seen elsewhere
  in this corpus.

## PMC12479364 / PMID 40926076 — Divergent cytokine/transcriptional signatures in TFH heterogeneity — APPLIES
- **Results presentation**: `fry` is used only for the single-cell half of the paper (against
  Hallmark/C2/C5 MSigDB collections, with significant gene sets then clustered into overlapping
  "themes" with the `vissE` package); the bulk RNA-seq half of the very same paper, scoring TFH/GC
  B-cell marker gene sets in the DE results, instead uses `fgsea` — an instructive within-paper
  split in which the data modality, not any single lab convention, decides which gene-set tool is
  used.
- **Methods sentence structure**: both subsections are titled identically ("Gene set enrichment
  analysis") in Methods, and differ only in the tool named mid-sentence — "GSEA was performed
  using the fry approach from the limma package on gene sets from the Molecular Signature
  Database" (scRNA-seq) versus "was calculated using the fgsea package" (bulk RNA-seq) — so the
  section heading alone cannot tell a reader which tool was actually run.

## PMC13388965 / PMID 42209519 — Brain FGF2/NCAM1 in FGFR1-dependent breast-cancer brain metastasis — APPLIES
- **Results presentation**: `fry` is run three times on three differently generated expression
  matrices from the same overall workflow — mouse brain-metastasis-microenvironment GeoMx ROIs,
  a separate human tumour-cell GeoMx ROI dataset, and an unrelated in-vitro bulk RNA-seq dataset
  (FGF2/NCAM1-treated cells) that reuses "the same GSEA...as described above" but from
  DESeq2-normalized counts rather than voom output.
- **Methods sentence structure**: the `fry` call is the last of five limma functions named
  verbatim, in quotes, within one long procedural paragraph that narrates the whole limma-voom
  pipeline step by step — "voom" for weights, "fit" for the linear model, "contrasts.fit" for
  coefficients, "ebayes" for moderation, then finally "Enrichment analyses were performed using
  fry from the limma package" — so `fry` reads as the final step of a five-function recipe rather
  than a standalone analysis.

## PMC9314343 / PMID 35879286 — Postmitotic monocyte differentiation requires cohesin-structured chromatin — APPLIES
- **Results presentation**: this is the densest gene-set-testing paper in the current corpus —
  `fry` is run separately on RNA-seq gene sets and on ChIP-seq/ATAC-seq peak sets (with `fgsea`
  substituted only for the CTCF/RAD21 ChIP-seq peak comparisons), `camera` is run separately on
  the ImmuneSigDB subset of MSigDB, and `kegga` (limma's hypergeometric KEGG-overrepresentation
  function) is run as a fourth, distinct limma gene-set method — all shown as `barcodeplot`
  figures across many main and supplementary panels.
- **Methods sentence structure**: each function gets its own short, near-identical sentence
  template — "Gene set enrichment analyzes...were performed using the function X of the limma
  package (v.3.46.0) in R" — repeated almost verbatim for `fry`, `camera` and `kegga` in three
  consecutive sentences, making this simultaneously the clearest and most repetitive example of
  limma's gene-set-testing family across the whole corpus.

## PMC12286861 / PMID 40500437 — Developmental trajectory and evolutionary origin of thymic mimetic cells — APPLIES
- **Results presentation**: `camera`/`cameraPR` compares thymic-epithelial-cell (TEC) mimetic-cell
  signatures against a curated set of background cell-type signatures assembled from three public
  atlases (PanglaoDB, Tabula Muris, MSigDB M8), with background signatures deliberately
  size-matched (within 10%) to the signature under test — an unusually explicit, quantitative
  background-selection rule not seen elsewhere in this corpus; results are reported as signed
  log10(adjusted P) rather than as a raw `camera` output table.
- **Methods sentence structure**: one dense sentence chains together three limma functions as a
  single pipeline — "Relative enrichment of gene signatures was determined with the competitive
  gene set test camera with cameraPR, employing the t-statistic as output by treat as the ranking
  statistic." — and this is one of only two papers in the whole batch that explicitly names
  Benjamini–Hochberg for the gene-set (rather than only the differential-expression) step:
  "The output of camera is a two-sided and Benjamini–Hochberg adjusted P value."

## PMC11146594 / PMID 38719473 — Suv39h-catalyzed H3K9me3 in euchromatic genome organization — APPLIES
- **Results presentation**: `roast` (both directional and non-directional variants, 9999
  rotations) tests one curated "aging signature" against RNA-seq from treated versus control
  muscle, while a second, unrelated Hi-C/`diffHic` analysis of differentially interacting gene
  promoters in the same paper uses `fry` instead — two different limma rotation tests on two
  entirely different data modalities (RNA-seq expression vs Hi-C promoter-interaction counts),
  each paired with limma's own `barcodeplot` for visualization.
- **Methods sentence structure**: the `roast` sentence is compact and function-name-first, with no
  gene-set database named — "Gene set testing of the aging signature and corresponding barcode
  plots were generated using limma's roast and barcodeplot functions." — while the test's key
  tuning parameter is given only in the following sentence rather than the same one ("evaluated
  using both directional and nondirectional roast tests with 9999 rotations"), splitting the
  test's identity and its resampling parameter across two sentences.
