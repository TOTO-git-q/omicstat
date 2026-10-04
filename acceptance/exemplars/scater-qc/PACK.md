# PACK -- scater-qc

Status: S0 evidence collected; S1 decisions drafted, not frozen. This lane writes no `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | Bioconductor RELEASE_3_23: scater 1.40.2 and scuttle 1.22.0; defining scuttle Rd for `perCellQCMetrics`, `perCellQCFilters`, `isOutlier`, S4 method defaults, NEWS where shipped, package metadata and rendered vignettes. Manifest in `L1_bioc3.23/manifest.tsv`. |
| L2 | scater overview and scuttle user guide archived under L1. The scater overview calls `addPerCellQC` on Zeisel brain and plots resulting metrics; it does not freeze a filter cutoff. |
| L3 | Ten applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | Thirty licence-gated OA articles with PubMed efetch echo; 29 applicable: six Bioconductor-only and 23 mixed. One spatial-spot case excluded. |

## T -- table skeleton

- Cell-level QC table: cell ID, sample/batch, assay, total counts, detected genes, mitochondrial/spike-in fractions, each filter flag, final discard flag and reason. Include input and retained counts by sample and doublet status when available.
- Threshold table: metric, direction, transformation, `nmads`, reference subset/batch, computed threshold, any fixed guardrail and discarded-cell count. Keep estimated MAD bounds separate from explicit hard cutoffs.

## F -- figure grammar

- scater overview plots total counts versus detected genes and total counts versus mitochondrial percent, coloured/faceted by tissue. Add per-sample distributions and threshold lines before/after filtering; show retained and discarded cells visibly.
- A low count or high mitochondrial fraction is a QC signal, not proof of a particular biology. Document gene-set annotation (e.g. `mt-` for Zeisel) and show whether a reference batch drives the MAD calculation.

## W -- wording

- Name the metric function and assay, feature subsets, outlier direction, MAD count, log transform, batch/reference subset and any fixed limits. `perCellQCFilters` applies lower MAD outliers for totals/detected and higher MAD outliers for subset percentages; a paper's fixed 10% mitochondrial rule is not that function's default.
- S2 Methods draft: “Per-cell metrics were computed from <counts assay> in scuttle <version> using <mitochondrial and other feature sets>. Low library size/detected features and high control-feature fraction were flagged by <MAD settings and batch rule>; <hard limits> were then applied. The per-sample flow table records all discarded cells.”

## V -- variant frequencies

Ecosystem rule: the label follows the article's single-cell front end (QC, normalisation, HVGs, reduction, integration, clustering). `mixed` means that front end crosses ecosystems (e.g. scater/scuttle QC followed by Seurat normalisation or clustering, or a scanpy subclustering); Seurat used only downstream (e.g. `FindMarkers`, CITE-seq normalisation) does not make an article mixed. Corpus split under this rule: seven Bioconductor-only (six applicable, one spatial-spot case inapplicable) and 23 mixed (all applicable); zero exclusively Seurat or scverse. All values below are literal Methods reports with **applicable paper** denominators per ecosystem (6 and 23); the two ecosystems are never pooled. "Majority" means more than half of that ecosystem's applicable denominator; otherwise "most common". The Bioconductor-only denominator of six is small: it can show which settings occur, not a stable frequency, and it cannot by itself set a suite default.

### Bioconductor-only (six applicable)

Papers: 41372142, 38081826, 37581929, 36517604, 40926076, 33020483.

| Parameter | Reported values and paper counts | Reported / 6 | Not reported / 6 |
|---|---|---:|---:|
| `qc_function` | isOutlier: 1; perCellQCMetrics + isOutlier: 1; addPerCellQCMetric: 1; perCellQCMetrics + quickPerCellQC: 1; calculateQCMetrics + plotPCA outlier detection: 1 | 5/6 | 1/6 |
| `assay_type` | none | 0/6 | 6/6 |
| `mt_feature_definition` | none | 0/6 | 6/6 |
| `subset_percent` | mitochondrial: 4; mitochondrial and rRNA: 1 (mitochondrial named in 5, majority) | 5/6 | 1/6 |
| `detection_limit` | none | 0/6 | 6/6 |
| `percent_top` | none | 0/6 | 6/6 |
| `batch` | per sample (QC run separately per sample): 1 | 1/6 | 5/6 |
| `nmads` | 3 (high mitochondrial, stated as scuttle default): 1; metric-specific 3 high transcripts / 1 low transcripts and detected / 2 high mito and rRNA: 1 | 2/6 | 4/6 |
| `outlier_type` | higher for mitochondrial: 1; both for transcripts, lower for detected, higher for mito/rRNA: 1 | 2/6 | 4/6 |
| `outlier_log` | none | 0/6 | 6/6 |
| `min_diff` | none | 0/6 | 6/6 |
| `libsize_cutoff` | per-experiment UMI minima (>3000/>3700 first mixing; >2750 to >3700 second mixing; >10,000/>15,000 HeLa): 1; 5,000-UMI minimum in the oligodendrocyte subset only: 1 | 2/6 | 4/6 |
| `features_cutoff` | per-experiment gene minima (>800 Pdgfra; >1000 BCR::ABL1 cell lines; >200 patient sample): 1; sample-specific lower gene limit printed as `10 × 10–2.5` to `10 × 10–2.75`: 1 | 2/6 | 4/6 |
| `mito_cutoff` | per-experiment two-sided windows (>2% and <28%; >1% and <75%; >1% and <30%; >1% and <50%; >3-6% and <25%): 1; 10% maximum in the oligodendrocyte subset only: 1; ≥20% excluded (main dataset): 1 | 3/6 | 3/6 |
| `doublet_method` | scDblFinder: 1 | 1/6 | 5/6 |
| `scater_version` | 1.20.1: 1; 1.22: 1; 1.12.2: 1 | 3/6 | 3/6 |
| `scuttle_version` | 1.4.0 (written `1.4` in one paper): 2; 1.12.0: 1 | 3/6 | 3/6 |
| `subsets` | none | 0/6 | 6/6 |
| `threshold` | none | 0/6 | 6/6 |
| `use_altexps` | none | 0/6 | 6/6 |
| `sum_field` | none | 0/6 | 6/6 |
| `detected_field` | none | 0/6 | 6/6 |
| `sub_fields` | none | 0/6 | 6/6 |
| `isoutlier_subset` | used for poor-quality batch 6: 1 | 1/6 | 5/6 |
| `share_medians` | none | 0/6 | 6/6 |
| `share_mads` | none | 0/6 | 6/6 |
| `share_missing` | none | 0/6 | 6/6 |

### Mixed (23 applicable)

| Parameter | Reported values and paper counts | Reported / 23 | Not reported / 23 |
|---|---|---:|---:|
| `qc_function` | isOutlier: 6; calculateQCMetrics: 3; scater metrics without a function name: 2; quickPerCellQC: 1; perCellQCMetrics + quickPerCellQC: 1; perCellQCMetrics + quickPerCellQC + isOutlier: 1; addPerCellQC: 1 | 15/23 | 8/23 |
| `assay_type` | none | 0/23 | 23/23 |
| `mt_feature_definition` | chrM and MitoCarta3.0: 1; Mouse.MitoCarta3.0: 1 | 2/23 | 21/23 |
| `subset_percent` | mitochondrial: 14; mitochondrial plus ribosomal/riboprotein: 3; mitochondrial plus spike-in/ERCC: 2; mitochondrial/nuclear proportion: 1 (mitochondrial named in 20, majority) | 20/23 | 3/23 |
| `detection_limit` | none | 0/23 | 23/23 |
| `percent_top` | <90% of counts from top 100 features: 1 | 1/23 | 22/23 |
| `batch` | per 10X lane (separate processing): 1 | 1/23 | 22/23 |
| `nmads` | 3: 5 (most common; not a majority) | 5/23 | 18/23 |
| `outlier_type` | both: 1; both tails (multivariate outlyingness): 1; lower for library size/detected and higher for mito: 1; higher for mitochondrial: 1 | 4/23 | 19/23 |
| `outlier_log` | log10 for library size and detected genes: 1; TRUE: 1 | 2/23 | 21/23 |
| `min_diff` | none | 0/23 | 23/23 |
| `libsize_cutoff` | <1000 UMIs: 4; <1000 transcripts: 1; 5 other unique values (0.45e5-1.45e5 counts; 400-30,000 UMIs; per-organoid windows; ≥150,000 endogenous counts; <100,000 reads) | 10/23 | 13/23 |
| `features_cutoff` | 10 unique values (e.g. >200 and <1750; >1200; >300; <200 Seurat pre-filter; per-organoid windows; >2000; ≥1500; <1000; per-sample <500/<250/<50; `102.5`/`103` as printed) | 10/23 | 13/23 |
| `mito_cutoff` | >10%: 5; 6 other unique values (<22%; <5%; >5%; >6% or 6-10% per organoid; <20%; <15%) | 11/23 | 12/23 |
| `doublet_method` | papers naming each tool (one paper can name several): scDblFinder: 4; DoubletFinder: 3; hashtag-based (HTODemux or HTO barcodes): 2; DoubletDetection: 1; scds: 1; demuxlet: 1; scran doubletCells: 1; TCR rearrangement-based: 1 | 10/23 | 13/23 |
| `scater_version` | 1.14.6: 2; 1.22.0: 2; 1.18.6: 2; 1.10.1: 2; 6 other unique values | 14/23 | 9/23 |
| `scuttle_version` | 1.4.0: 1; 1.18.6 (as printed): 1; 1.10.2: 1 | 3/23 | 20/23 |
| `subsets` | none | 0/23 | 23/23 |
| `threshold` | none | 0/23 | 23/23 |
| `use_altexps` | none | 0/23 | 23/23 |
| `sum_field` | none | 0/23 | 23/23 |
| `detected_field` | none | 0/23 | 23/23 |
| `sub_fields` | none | 0/23 | 23/23 |
| `isoutlier_subset` | none | 0/23 | 23/23 |
| `share_medians` | none | 0/23 | 23/23 |
| `share_mads` | none | 0/23 | 23/23 |
| `share_missing` | none | 0/23 | 23/23 |

In both ecosystems the mitochondrial fraction is the one QC subset named by a majority of applicable papers (5/6 and 20/23). A 3-MAD rule is the most common printed MAD multiple in mixed papers (5/23, not a majority); in the Bioconductor-only set it appears once, and one paper uses metric-specific multiples (3/1/2). Fixed limits are study-specific: a 10% mitochondrial maximum is the most common mixed value (5/23), and Bioconductor-only papers report per-experiment or per-subset windows rather than one shared cutoff. Several articles combine MAD bounds and hard limits. The `102.5`/`103` (PMID 36306352) and `10 × 10–2.5` (PMID 37581929) gene-cutoff strings are exactly as printed in JATS and are not silently interpreted as exponents.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 20: scRNAseq `ZeiselBrainData()` (EH2580–EH2582; GEO GSE60361), 3,005 cells × 21,135 features, as in scater's locked overview. The counts, rowData and colData RDS files were downloaded in this lane and SHA256-verified: `4357e6850705c096c8c1276f32b415628dcc16c51ba2c61a36598948ca12a215`, `39ab99d7e8d1387103214b0be92a2e4acd83d46715f5b876dbc5d014c678fb12`, `652d0476cf3274d8d7804f5096b55580c6b298a2f4fa288f1d8934afad70405f`. `fetch_anchor_data.sh hub` retains the accession URLs and hashes.
- The overview's `grep("mt-", rownames(example_sce))` mitochondrial subset and diagnostic plots are workflow smoke candidates. No R replay was run in S0; freeze retained-cell counts only after running the locked image.

## D -- locked function default / official guide / Bioconductor-only exemplars

The defaults are from defining scuttle 1.22.0 Rd, including S4 `perCellQCMetrics` methods (`L1_bioc3.23/scuttle/defaults.tsv`, with the SummarizedExperiment and SingleCellExperiment method rows as in the Rd usage). The six-paper Bioconductor-only denominator is shown explicitly; mixed papers are counted only in V. Function defaults are not imputed into papers that do not print an argument.

| Parameter | Function default (locked version) | Official guide | Bioconductor-only exemplar evidence | S1 draft |
|---|---|---|---|---|
| `qc_function` | no universal route; scuttle exports metrics and filters | scater overview uses `addPerCellQC` to compute metrics | isOutlier: 1; perCellQCMetrics + isOutlier: 1; addPerCellQCMetric: 1; perCellQCMetrics + quickPerCellQC: 1; calculateQCMetrics + plotPCA: 1 (5/6 applicable) | pending S1 |
| `assay_type` | `perCellQCMetrics.SingleCellExperiment(assay.type="counts")` | not explicitly set | none (0/6 applicable) | pending S1 |
| `mt_feature_definition` | caller-supplied `subsets` | `grep("mt-", rownames(example_sce))` on Zeisel | none (0/6 applicable) | pending S1 |
| `subset_percent` | `subsets=NULL` | Mito subset percent plotted against library size | mitochondrial: 4; mitochondrial and rRNA: 1 (5/6 applicable) | pending S1 |
| `detection_limit` | soft-deprecated alias; `threshold=0` | not explicitly set | none (0/6 applicable) | pending S1 |
| `percent_top` | `percent.top=integer(0)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `batch` | `isOutlier(batch=NULL)` | not explicitly set | per sample (separate QC runs): 1 (1/6 applicable) | pending S1 |
| `nmads` | `isOutlier(nmads=3)` | not explicitly set | 3 (high mito): 1; metric-specific 3/1/2: 1 (2/6 applicable) | pending S1 |
| `outlier_type` | `isOutlier(type=c("both","lower","higher"))`, first choice both | not explicitly set | higher for mito: 1; per-metric directions: 1 (2/6 applicable) | pending S1 |
| `outlier_log` | `isOutlier(log=FALSE)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `min_diff` | `isOutlier(min.diff=NA)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `libsize_cutoff` | no fixed cutoff; lower MAD outlier in perCellQCFilters | diagnostic scatter; no fixed cutoff printed | per-experiment UMI minima: 1; subset-only 5,000 UMIs: 1 (2/6 applicable) | pending S1 |
| `features_cutoff` | no fixed cutoff; lower MAD outlier in perCellQCFilters | diagnostic scatter; no fixed cutoff printed | per-experiment gene minima: 1; per-sample lower limit (as printed): 1 (2/6 applicable) | pending S1 |
| `mito_cutoff` | no fixed cutoff; higher MAD outlier in perCellQCFilters | diagnostic scatter; no fixed cutoff printed | per-experiment two-sided windows: 1; subset-only 10% maximum: 1; ≥20% excluded: 1 (3/6 applicable) | pending S1 |
| `doublet_method` | outside core scuttle QC calls | not explicitly set | scDblFinder: 1 (1/6 applicable) | pending S1 |
| `scater_version` | locked scater 1.40.2 | release 3.23 overview | 1.20.1: 1; 1.22: 1; 1.12.2: 1 (3/6 applicable) | pending S1 |
| `scuttle_version` | locked scuttle 1.22.0 | scater overview loads scuttle utilities | 1.4.0 (once written 1.4): 2; 1.12.0: 1 (3/6 applicable) | pending S1 |
| `subsets` | `perCellQCMetrics(subsets=NULL)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `threshold` | `perCellQCMetrics(threshold=0)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `use_altexps` | `perCellQCMetrics.SingleCellExperiment(use.altexps=NULL)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `sum_field` | `perCellQCFilters(sum.field="sum")` | not explicitly set | none (0/6 applicable) | pending S1 |
| `detected_field` | `perCellQCFilters(detected.field="detected")` | not explicitly set | none (0/6 applicable) | pending S1 |
| `sub_fields` | `perCellQCFilters(sub.fields=NULL)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `isoutlier_subset` | `isOutlier(subset=NULL)` | not explicitly set | used for poor-quality batch 6: 1 (1/6 applicable) | pending S1 |
| `share_medians` | `isOutlier(share.medians=FALSE)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `share_mads` | `isOutlier(share.mads=FALSE)` | not explicitly set | none (0/6 applicable) | pending S1 |
| `share_missing` | `isOutlier(share.missing=TRUE)` | not explicitly set | none (0/6 applicable) | pending S1 |

## X -- version-sensitive behaviour

- The locked scuttle Rd marks `perCellQCMetrics` and `perCellQCFilters` deprecated in favour of scrapper's `computeRnaQcMetrics` and `suggestRnaQcThresholds`; the plan still names the scuttle functions. S1 must decide whether to retain these compatibility calls in the locked image.
- scater re-exports some scuttle functions. The initial L1 exporter captured only the re-export help stub; the collector now skips `\docType{import}` so the defining scuttle Rd and defaults are archived.
- `perCellQCMetrics` has S4 method defaults for matrix, SummarizedExperiment and SingleCellExperiment inputs; the SCE `assay.type="counts"` and `use.altexps=NULL` matter. `isOutlier` also has batch sharing controls that cannot be inferred from an unqualified “MAD filtering” paper.

## S1 drafts and pending decisions

- P-1 Choose a standard feature-subset definition per species and assay, with mitochondrial annotation hash, and make batch-specific thresholds explicit. Zeisel's lowercase `mt-` rule is an example, not a universal prefix.
- P-2 Choose MAD directions/transformations and whether hard guardrails supplement adaptive bounds. The Bioconductor-only corpus has six applicable papers; three print fixed limits, all per-experiment or per-subset, so there is no shared fixed-threshold value to adopt.
- P-3 Decide how scuttle's deprecated QC calls are supported versus a scrapper migration; preserve the plan's declared input/output contract and record versioned behavior.
- P-4 Replay Zeisel in the locked image and freeze flow counts and diagnostic plots; keep doublet removal as a named downstream operation rather than silently including it in the QC metric default.
