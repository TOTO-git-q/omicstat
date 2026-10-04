# PACK — immunedeconv-infiltration

S0 evidence and S1 draft. Independent `verification.json` is reserved for the other lane.

| Layer | Evidence |
|---|---|
| L1 | immunedeconv **2.1.4**, GitHub commit `e625e6c28ed14a30f9f40f159925cc9f0df4fa49`: core Rd, defaults, README, three source vignettes, embedded Racle fixture and hash manifest in `L1_github/`. The pinned source has no NEWS or CITATION file; absence is recorded. GitHub-pinned ConsensusTME, EPIC, MCPcounter, mMCPcounter and xCell dependency docs are also in L1 with their pinned commits and source hashes. |
| L2 | Sturm et al. 2019 method benchmark PMC6612828; a SHA-pinned rendered website article that labels package version 2.1.4 and includes printed Racle output. The website does not expose an immutable build commit, so printed values are supplemental, not yet locked-runtime assertions. |
| L3 | Ten applicable tier-A close readings (`literature/l3_notes.md`). |
| L4 | Twenty-five licensed open-access, PubMed-echoed articles from 43 query hits; **23/25 applicable** to bulk-expression immune estimation. |

## T — table skeleton

Keep a gene × biological-sample input matrix with source, species, gene-identifier mapping, non-log scale and normalization. The long result table has `method`, `sample`, `cell_type`, estimate, output unit/semantics (fraction or score), reference/signature, package/dependency version and any failure/NA reason. Preserve per-method results separately. A sample metadata table records tumor/non-tumor indication, platform, biological group and paired/independent design. If group comparisons are requested, retain all cell types, effect sizes, raw/adjusted P and the tested sample count. Never place xCell/MCP-counter scores in the same numeric column as EPIC/quanTIseq fractions without a unit tag.

## F — figure grammar

Show one heatmap or panel per method with a clearly labelled scale. EPIC/quanTIseq fractions may use 0–1 legends; xCell, MCP-counter and ESTIMATE panels require their own arbitrary or method-specific score legends. Label sample groups and biological replicates, display missing estimates, and state gene coverage/reference compatibility. A between-group plot should show sample points, not only bars, and include the test and multiplicity correction. Cross-method agreement is a sensitivity comparison, not a pooled cell fraction.

## W — wording

Methods template: “Non-log bulk expression (`<TPM/CPM/other>`) with `<gene symbols>` for `<n>` biological samples was analyzed by immunedeconv v2.1.4 with `<named bundled method(s)>`. We set `tumor=<...>`, `arrays=<...>`, `indications=<...>` when relevant and used `<reference/signature/version>`. `<method>` reports `<fraction or score>` for `<cell types>`; `<paired/unpaired test>` with `<correction>` compared `<groups>`.” Results template: “`<cell type>` had `<effect and unit>` across `<n>` samples using `<method>`, adjusted P `<...>`.” State that different method scales cannot be compared directly. CIBERSORT/CIBERSORTx may appear in a literature count, but their licensed source and LM22 are not bundled or used to set executable defaults.

## V — variant frequencies

Denominator: **23 applicable / 25 corpus**; M4 ecosystem is **n/a for all 25**. Two exclusions are an ATAC-seq reference benchmark and ssGSEA of an “Immunedeconv signature set” without package deconvolution. Twenty-one of 23 name at least one method; two use the wrapper without a precise method run list. Named-method counts overlap because papers run several methods: quanTIseq **8/23**, EPIC **7/23**, MCP-counter **6/23**, xCell **4/23**, ESTIMATE **4/23**, TIMER **3/23**, ABIS **2/23**, ConsensusTME **2/23**. “Most common” is quanTIseq at 8/23; no method has a >50% corpus majority.

| Variant or reporting fact | Applicable count (n=23) | Not reported / not applicable |
|---|---:|---:|
| Explicit CIBERSORT-family run | 9/23: classic CIBERSORT 8, CIBERSORTx web 1 | 14/23 no explicit run. Of the classic eight, six use the wrapper and two use a separate analysis/web portal. |
| Bulk input scale tied to deconvolution | TPM 5, CPM 1 | 17/23 not reported |
| Tumor switch | `FALSE` 1 | 22/23 not reported |
| Array switch | `TRUE` 1 | 22/23 not reported |
| Gene exclusion argument | literal `rmgenes="none"` 1 | 22/23 not reported; not a default |
| Reference/signature named | LM22 in 2 CIBERSORT uses | 21/23 not reported for this field |
| Output explicitly called fractions | 2/23 (quanTIseq/EPIC contexts) | 21/23 do not state a reliable unit in Methods |
| Group test for inferred estimates | Wilcoxon rank-sum 1, paired t test 1, Mann–Whitney U 1 | 20/23 not reported |
| Multiple-testing policy | unadjusted P in 1 | 22/23 not reported |
| Exact package version | 2.1.0 in 4, 2.0.0 in 2, 2.0.4/2.1.3/1.1.5 in 1 each | 14/23 not reported |
| `indications`, `column`, `scale_mrna`, `expected_cell_types` | 0/23 each | 23/23 each |

CIBERSORT appears in the count even when it was run outside the immunedeconv wrapper. PMC8728303 merely lists CIBERSORT among package algorithms; it is **not** counted as a run. PMC13495209 actually uses CIBERSORTx on its separate web platform; it is not a bundled wrapper default. CIBERSORT absolute-mode scores remain arbitrary-unit scores according to the pinned vignette even where an application paper calls them “absolute fractions.”

## C — replay and printed anchor

Registry #33 uses package-embedded `dataset_racle.rda`, SHA-256 `7a3e69c89b16df3986e4d02f3dbba949be3c61321d2173a7356c1ac67ce2bef0`, from the pinned source tarball SHA-256 `6fc21444679d9d09319930a93c0dbf93b749cc4d6f2718555ad33cd192999883`. The locked Rd describes **four metastatic-melanoma RNA-seq samples** with `expr_mat` (gene symbols × samples) and independent FACS `ref` measurements (`sample`, `cell_type`, `true_fraction`). The pinned source vignette runs `deconvolute(dataset_racle$expr_mat, "quantiseq")`; this is the exact fixture recipe. The version-labelled rendered website displays sample columns `LAU125`, `LAU355`, `LAU1255`, `LAU1314` and a B-cell row of 0.02, 0.43, 0.02, 0.49 after two-decimal printing. These website numbers are a **provisional comparison** because that website is not commit-pinned; S1 must run the pinned package/dependencies and record the actual full-precision output. The data hash and four-sample structure are input assertions, and the FACS reference enables a separate accuracy comparison. Printed two-decimal rounding is not a replay tolerance.

## D — function default / vignette / exemplar evidence

The locked `deconvolute` interface has result-affecting switches shared across methods; `...` may pass native method arguments. Its default `method=deconvolution_methods` is a method list, **not** a validated single-method choice. The pinned vignette uses quanTIseq for one Racle example, not a universal recommendation. Frequencies use 23 applicable Methods papers.

| Parameter (profile) | Function default, pinned source | Pinned vignette / guide | Exemplar evidence (n=23) | S1 draft |
|---|---|---|---|---|
| Method (D-ID1) | `method=deconvolution_methods` | Racle example uses `quantiseq`; guide describes method-specific scales | quanTIseq 8, EPIC 7, MCP-counter 6, others fewer; two unspecified | Require named bundled method matching question/output unit |
| CIBERSORT use (D-ID2) | Wrapper has entry points but licensed files are absent | explicit user-supplied `CIBERSORT.R` and `LM22.txt` | classic 8, CIBERSORTx web 1; 14 not explicit | Count only; no bundled default or redistribution |
| Input scale (D-ID3) | numeric non-log gene × sample matrix | non-log HGNC symbols | TPM 5, CPM 1; 17 not | Validate non-log data and method input constraints |
| Gene identifiers (D-ID4) | HGNC symbols in rows / `fData` | gene symbol rownames | one mouse-to-human symbol mapping; 22 not | Require identifier mapping and coverage report |
| Organism (D-ID5) | `deconvolute` human; `deconvolute_mouse` separate | mouse vignette is a separate branch | 0/23 state a wrapper organism argument; TISMO is a murine study | Explicit human/mouse route; do not reuse human signatures silently |
| Tumor switch (D-ID6) | `tumor=TRUE`; affects EPIC/quanTIseq | example uses tumor melanoma | FALSE 1; 22 not | Set from sample biology |
| Arrays (D-ID7) | `arrays=FALSE`; affects quanTIseq/CIBERSORT | RNA-seq example | TRUE 1; 22 not | Set by assay platform |
| TIMER indication (D-ID8) | `indications=NULL` | method-specific cancer indication | 23 not | Require supported cancer type when TIMER used |
| ExpressionSet column (D-ID9) | `column="gene_symbol"` | matrix example has rownames | 23 not | Validate if ExpressionSet supplied |
| Remove genes (D-ID10) | `rmgenes=NULL` | no noisy-gene exclusion in basic example | `"none"` 1; 22 not | Require a named, justified list if used |
| mRNA scaling (D-ID11) | `scale_mrna=TRUE` | correction applies to EPIC/quanTIseq | 23 not | Pin for absolute-method analysis and report |
| Expected cell types (D-ID12) | `expected_cell_types=NULL` | xCell restriction optional | 23 not | Set only with prior biological knowledge |
| Custom signature (D-ID13) | method-specific `...`; no universal custom matrix | guide allows some custom signatures; CIBERSORT file is external | 23 no bundled-method custom setting | Version and license any permitted reference |
| Reference dataset (D-ID14) | method's packaged reference unless overridden | Racle example relies on quanTIseq reference | LM22 in 2 CIBERSORT uses; 21 not | Log method reference/version and gene overlap |
| ESTIMATE branch (D-ID15) | separate `deconvolute_estimate` or `method="estimate"` | immune/stromal/purity scores | ESTIMATE named among methods in 4/23; 0/23 state score-specific settings | Keep scores/purity distinct from fractions |
| Output scale (D-ID16) | method-dependent: EPIC/quanTIseq fractions; xCell/MCP-counter scores | guide gives comparison semantics | 2 explicit fraction reports; 21 not reliable | Attach unit and allowed comparison axes |
| Group test (D-ID17) | no deconvolute test | no universal test | Wilcoxon 1, paired t 1, Mann–Whitney 1; 20 not | Choose from biological design |
| P adjustment (D-ID18) | none in deconvolute | no universal correction | unadjusted 1; 22 not | Correct across tested cell types as prespecified |
| P cutoff (D-ID19) | none | no universal cutoff | 23 not reported for infiltration comparison | Define reporting threshold separately |
| Version (D-ID20) | immunedeconv 2.1.4 and pinned deps | website labels 2.1.4 | older versions in 9; 14 not | Store wrapper and dependency versions |

## X — version-sensitive items

- The pinned main source has no NEWS or CITATION file. No release-change claim is inferred; package and five GitHub dependency commits are recorded in the L1 manifest/sources table. Native method implementations may differ when dependencies drift, so S1 replay must use those pins.
- JATS in PMC9271073 has immunedeconv `v2.0.4` plus superscript citation 107. The flat Methods renderer joins them as `v2.0.4107`; this pack counts **2.0.4** and records the markup reason.
- The v2.1.4 vignette says quanTIseq/EPIC yield cell fractions, MCP-counter/xCell yield cross-sample scores, and CIBERSORT absolute mode remains arbitrary-unit. This affects table/figure semantics. The documentation website lacks a commit pin; printed Racle values are provisional until locked-runtime replay.
- CIBERSORT is not bundled at the pinned commit. Its code and LM22 require a separate license/download. A paper’s use, including web-portal runs, cannot become an executable bundled method default.

## S1 drafts and pending decisions

1. Require non-log expression with validated HGNC identifiers and biological sample IDs. Check tumor/array switches, organism, reference gene overlap and explicit method selection before running.
2. Offer bundled EPIC/quanTIseq when an interpretable fraction is required, and MCP-counter/xCell/ESTIMATE when their score semantics fit the question. Keep method outputs separate and report comparisons only on valid axes. No method crosses a 50% exemplar majority, so choose by scientific output and locked documentation, not popularity.
3. Keep CIBERSORT/CIBERSORTx out of bundled defaults and fixtures. Count the nine papers in the evidence summary; any future user-supplied licensed path requires a separate explicit integration decision.
4. Replay the four-sample Racle fixture and compare the pinned output with FACS `ref`; record package/dependency versions and full-precision values. Select group test/adjustment from biological sample design and report all cell types, not only significant ones.

## S2 corrections and restricted executable scope (2026-10-01)
Independent verification §3: input_scale adds TPM for 32647202 and 36368318, TPM/VST for 35810190; the 32647202 snippet must read non-immune, without inserted whitespace. Original S0 extraction is retained with a correction ledger; original V counts are historical and cannot define defaults.
Locked-runtime scope: only GPL-3 quantiseqr 1.20.0 bundled TIL10 via immunedeconv 2.1.4 enabled. EPIC 1.1.7 has academic/noncommercial/redistribution restrictions; MCP-counter 1.2.0 attempts a network signature download offline. Other backends are unverified and refused. Native Racle replay is the numerical authority; website B-cell rounded values remain supplemental.

## S2 restricted executable scope
Only GPL-3 quantiseqr 1.20.0 bundled TIL10 via immunedeconv 2.1.4 enabled. EPIC 1.1.7 has academic/noncommercial/redistribution restrictions; MCP-counter 1.2.0 attempts a network signature download offline. Other backends are unverified and refused. Native Racle replay is the numerical authority; website B-cell rounded values remain supplemental.
