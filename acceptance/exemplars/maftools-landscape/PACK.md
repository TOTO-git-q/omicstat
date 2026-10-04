# PACK — maftools-landscape

S0 evidence and S1 draft. Independent `verification.json` is reserved for the other lane.

| Layer | Evidence |
|---|---|
| L1 | maftools **2.28.0** at Bioconductor `RELEASE_3_23` commit `e5256744f5`: core Rd, 4 source vignettes with rendered text/printed values, NEWS, CITATION and SHA-256 manifest in `L1_bioc3.23/`. |
| L2 | Mayakonda et al. 2018 maftools method article, PMC6211645, pinned by URL and SHA-256 in `L2/`. |
| L3 | Ten applicable tier-A close readings. Three out-of-scope tier-A papers were replaced with direct-use corpus papers after Methods review (`literature/l3_notes.md`). |
| L4 | Thirty licensed open-access, PubMed-echoed articles; **25/30 applicable** to maftools mutation landscape, TMB or interaction analysis. |

## T — table skeleton

Retain a variant-level table keyed by tumor sample, gene, chromosome/position, reference/alternate allele, classification, type, call source and somatic status. Preserve silent and non-silent counts separately. A sample table contains mutation count, callable target territory in Mb, TMB in mutations/Mb, cohort/clinical fields and missingness. A gene table contains mutated samples, frequency denominator and variant-class breakdown. The interaction table retains each tested gene pair, 2×2 counts, odds ratio, raw and adjusted P, and the set of tested genes. Plots use the same sample IDs and gene universe as the tables.

## F — figure grammar

Draw an oncoplot with genes on rows, tumor samples on columns, variant classes visibly distinguished and row/column mutation summaries. State whether top genes are ranked by mutated samples or events, and whether mutation-free samples are displayed. Align clinical annotation with barcodes and show unknowns. TMB plots label the unit mutations/Mb and the denominator territory; any high/low cutoff is a study decision. A co-occurrence/mutual-exclusivity matrix distinguishes effect direction and marks the P adjustment used. Never imply an omitted sample was mutation-free without checking cohort coverage.

## W — wording

Methods template: “Somatic variants from `<caller, reference build, filters, accession>` were supplied as MAF to maftools v2.28.0. `read.maf` used `useAll=<...>`, `isTCGA=<...>`, `removeDuplicatedVariants=<...>` and `<non-synonymous class rule>`, with clinical data joined by `<barcode policy>`. The oncoplot shows `<gene list/top N>` and `<sample universe>`. `tmb` used `<captureRegions or captureSize>` and `<included mutation classes/CNV policy>`. `somaticInteractions` tested `<genes/top N>` by pairwise Fisher exact tests and reported `<raw/adjusted P criterion>`.” Results template: “`<n>` tumors, `<n>` genes and `<n>` non-silent variants were summarized; the median TMB was `<value>` mutations/Mb over `<territory>`. `<gene A>/<gene B>` showed `<co-occurrence or exclusivity>` with odds ratio `<...>` and adjusted P `<...>`.” TMB from panels with different callable territories is not directly interchangeable; mutation plots are descriptive and do not establish driver status.

## V — variant frequencies

Denominator: **25 applicable / 30 corpus**; M4 ecosystem is **n/a for all 30**. Exclusions: unrelated genome-alignment `mafTools` (1), mutational-signature-only uses (3), and preprocessing for a different disease-module analysis without landscape output (1). All reported frequencies below use the 25 applicable papers. The profile has 24 decision fields; unreported function arguments remain “not reported” even when a paper says maftools was used.

| Reported variant | Count / 25 | Not reported / 25 |
|---|---:|---:|
| MAF/call source tied to analysis | TCGA 5 (one also own targeted panel), WES 3, COSMIC v92 1 | 16 |
| Explicit oncoplot top-gene count | 15 in 1 | 24 |
| Variant class rule tied to landscape | non-synonymous 2; high/moderate consequence 1; intronic/silent/UTR exclusion with exceptions 1 | 21 |
| TMB unit | mutations/Mb in 1 | 24 |
| TMB high/low cutoff | 1.5 mutations/Mb in 1 | 24 |
| maftools package version | 2.6.05 in 2; 1.8.10, 2.8.0, 2.8.5, 2.14.0, 2.16.0 in 1 each | 18 |
| `useAll`, `isTCGA`, duplicate removal, `vc_nonSyn`, `rmFlags` | 0 each | 25 each |
| Clinical-data argument and oncoplot ordering/unaltered samples | 0 each | 25 each |
| TMB `captureSize`, `captureRegions`, `ignoreCNV`, `logScale` | 0 each | 25 each |
| Interaction gene set, P cutoff and `plotPadj` | 0 each | 25 each |

No value has a >50% majority of the 25 applicable papers. “Top 15” is the sole reported plot count, not a default. A top-50 expression-gene statement near TMB Methods is deliberately not counted as an oncoplot parameter. A reported R 4.3.0 is not a maftools version.

## C — replay and printed anchor

Registry #32 uses the two **package-embedded** TCGA-LAML files in maftools 2.28.0. The locked Bioconductor source tar SHA-256 is `3dd8980a164fe250c3a6a60155436702aea27a073594f2733b7ec3804eb18fb8`; its `tcga_laml.maf.gz` SHA-256 is `d102b071a052265b6f8ad7947bad1d58d3e3036fd17d6b274f7ea09a376cd6a0` and `tcga_laml_annot.tsv` is `7033030d52868e9a0f35ffd78f45a9d7a126c2edef90cf9e74e4f5d78990a710`. Direct file inspection found **2,207 MAF records across 193 tumor barcodes** and 200 clinical rows. A join must report unmatched clinical rows rather than treating all 200 as tumors.

The locked rendered `maftools` vignette calls `read.maf(maf=laml.maf, clinicalData=laml.clin)` and prints **193 samples, 1,241 genes, 475 silent variants and 1,732 non-silent variants** (2,207 total). These are concrete replay assertions for the exact locked input/recipe once the R runtime is available, alongside MAF/annotation file hashes; they are not generic expectations for every cancer cohort. The vignette illustrates `oncoplot(top=10)` while the function default is 20, and `somaticInteractions(top=25,pvalue=c(0.05,0.1))` while the locked usage default is `c(0.05,0.01)`. The illustrated values are examples, not universal thresholds.

## D — function default / vignette / exemplar evidence

Defaults are from locked Rd usage. “Not reported” means the 25 applicable Methods sections do not state a value; it never means the package used its default.

| Parameter (profile) | Function default, maftools 2.28.0 | Locked vignette | Exemplar evidence (n=25) | S1 draft |
|---|---|---|---|---|
| MAF source (D-MF1) | `read.maf(maf=)` required | embedded TCGA-LAML MAF | TCGA 5, WES 3, COSMIC v92 1; 16 not | Record caller, genome build, filters, accession |
| Non-synonymous classes (D-MF2) | `vc_nonSyn=NULL`; high/moderate consequences built in | vignette states default and override | no explicit override; 25 not | Pin class list and document changes |
| `useAll` (D-MF3) | TRUE; if FALSE only `Mutation_Status=Somatic` | not changed | 25 not | Require explicit somatic-status policy |
| `isTCGA` (D-MF4) | FALSE; TRUE truncates barcode to first 12 characters | input uses TCGA file but does not set arg | 25 not | Set only after barcode-join validation |
| Duplicate variants (D-MF5) | `removeDuplicatedVariants=TRUE` | not changed | 25 not | Pin TRUE unless transcript-level duplication needed |
| Clinical annotation (D-MF6) | `clinicalData=NULL`, `oncoplot(clinicalFeatures=NULL)` | LAML FAB file supplied | 25 no explicit function setting | Validate barcode key and missing categories |
| Oncoplot top (D-MF7) | `top=20` | `top=10` example | 15 in 1; 24 not | Expose N and retain full gene table |
| Oncoplot genes (D-MF8) | `genes=NULL` | example top ranking; custom lists shown separately | 25 not | Explicit list for hypothesis-driven plots |
| Oncoplot sort (D-MF9) | `sortByMutation=FALSE`, `sortByAnnotation=FALSE` | customization vignette demonstrates alternatives | 25 not | Record order, especially for clinical comparison |
| Nonmutated samples (D-MF10) | `removeNonMutated=FALSE` | not a universal recommendation | 25 not | Preserve cohort denominator by default |
| Included classes (D-MF11) | read.maf default high/moderate non-synonymous list | vignette prints 475 silent separately | 4 describe class scope; 21 not | Show class legend and silent/non-silent split |
| TMB capture size (D-MF12) | `captureSize=50` Mb | `tmb(laml)` example uses default | 25 not | Require assay-specific callable territory |
| TMB unit/definition (D-MF13) | mutations per megabase | example returns sample TMB | mutations/Mb 1; 24 not | State variant classes and target territory |
| TMB cutoff (D-MF14) | no high/low cutoff | none prescribed | 1.5 mut/Mb in 1; 24 not | Use a prespecified, assay-aware threshold if needed |
| TMB log plot (D-MF15) | `logScale=TRUE`, plotting only | no universal choice | 25 not | State axis transform separately from TMB values |
| Interaction gene set (D-MF16) | `top=25`, `genes=NULL` | `top=25` example | 25 not | Define gene universe before testing |
| Interaction significance (D-MF17) | `pvalue=c(0.05,0.01)` in usage | example `c(0.05,0.1)` | 25 no cutoff | Report raw and adjusted P; set criterion |
| Version (D-MF18) | 2.28.0 pinned | rendered locked release | seven papers report older versions; 18 not | Store exact package/runtime version |
| FLAG gene removal (D-MF19) | `rmFlags=FALSE` | no universal deletion | 25 not | Show flagged genes; do not silently remove |
| Oncoplot min mutations (D-MF20) | `minMut=NULL` | custom examples | 25 not | State any filter and denominator |
| Oncoplot altered mode (D-MF21) | `altered=FALSE` | no universal choice | 25 not | Record if selected |
| TMB capture regions (D-MF22) | `captureRegions=NULL`; mutually exclusive with size | no target interval supplied for LAML example | 25 not | Prefer assay-specific interval file |
| TMB CNV inclusion (D-MF23) | `ignoreCNV=TRUE` | not changed | 25 not | Pin TRUE for point-mutation TMB; state any change |
| Interaction adjusted-P display (D-MF24) | `plotPadj=FALSE`; `returnAll=TRUE` usage | printed table includes `pAdj` | 25 not | Show multiplicity-adjusted results and tested-pair count |

## X — version-sensitive items

- The locked NEWS has a 2.22.10 entry for oncoplot grid lines, right-bar titles and numeric-annotation color flipping. These change plot rendering, not a biological mutation threshold; no later changelog entry is present in the locked source.
- The `somaticInteractions` Rd usage sets `returnAll=TRUE`, but its argument prose says “Default FALSE.” The usage is the recorded L1 function signature; S1 must check the actual 2.28.0 runtime and explicitly pass the intended value rather than relying on this contradictory documentation.
- `read.maf` classifies high/moderate consequences as non-synonymous by default and removes duplicate transcript mappings per sample; changing `vc_nonSyn` or `removeDuplicatedVariants` can change mutation counts, oncoplot rankings and TMB. Barcodes may change under `isTCGA=TRUE`.

## S1 drafts and pending decisions

1. Validate the MAF schema, genome build, somatic-call source and cohort sample universe; retain variant-level provenance. Join clinical data by barcode and report unmatched rows. Define silent/non-silent classes and duplicate policy before computing any summary.
2. Use one filtered MAF object for summary, oncoplot, TMB and interactions. Require a named capture territory and point-mutation/CNV policy for TMB; do not interpret the 50 Mb function default as an assay fact.
3. Freeze an explicit oncoplot gene count/list, ordering and nonmutated-sample policy. Test co-mutation on a declared gene universe, retain all pairwise results and display adjusted P alongside effect direction. Resolve the `returnAll` documentation conflict in a locked runtime test.
4. Replay TCGA-LAML package data in the future R image and compare the printed 193/1,241/475/1,732 values. Treat deviations as version/input issues to investigate, without applying an invented numeric tolerance.

## S2 verification corrections (2026-10-01)
Applied S0_VERIFICATION_M3M4.md §3 locally; read-only S0 evidence was not edited. Corrected records and independent verification reasons are retained in literature/S2_corrections.json; counts above include the corrected records. No literature frequency determines an engine default.
- PMID 41404730, maf_source: TCGA gene mutation data.
- PMID 34931711, maf_source: COSMIC v92 (TCGA cohorts).
- PMID 39428388, maf_source: TCGA HNSCC MAF (GDCquery_Maf, TCGAbiolinks) and own targeted-panel variants.
- PMID 39428388, variant_classes: intronic, silent and UTR variants removed (except TERT promoter / TP53 5' UTR).
- PMID 37460463, maf_source: in-house WES of ccRCC tumours with matched germline.
