# PACK -- scran-markers

Status: S0 evidence collected; S1 decisions drafted, not frozen. No `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | Bioconductor RELEASE_3_23 scran 1.40.0; locked scoreMarkers/findMarkers Rd including S4 defaults, NEWS, DESCRIPTION and rendered scran vignette in `L1_bioc3.23/manifest.tsv`. |
| L2 | Locked scran vignette loads Grun pancreas; locked scoreMarkers Rd provides a `mockSCE` marker example. |
| L3 | Ten applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | Thirty licence-gated OA articles with PubMed efetch echo; 19 applicable (13 Bioconductor-only, five mixed, one Seurat front end). |

## T -- table skeleton

- Per-cluster gene table: gene ID, cluster, comparison set, mean/min AUC, mean/min Cohen’s d, mean logFC, detected fraction, rank and selection flag. Store the input assay, normalization and any sample block.
- If compatibility `findMarkers` is used, keep test type, pairwise grouping, combined P/FDR and direction in a separate table; do not label descriptive effect rankings as biological-replicate tests.

### Scope rule (written 2026-09-29; also in the profile `note` of `tools/lit/discovery_profiles.json`)

Cluster-marker detection only: scran `findMarkers`/`scoreMarkers`/`pairwiseTTests`/`pairwiseWilcox` run on expression clusters or cell types. Comparisons whose groups are not expression clusters (genetic subclones, perturbation vs control, condition contrasts) are `_applies = no`. They are listed here with the evidence they carry; whether S1 counts them is a pending owner decision (S1 item P-5).

Excluded because the groups are not expression clusters or cell types (evidence kept in the `_applies` note of `extraction.jsonl`, not counted in V/D):

| PMID | Ecosystem label | Grouping | Evidence the paper states |
|---|---|---|---|
| 39587361 | seurat | genetic structural-variant subclones | `findMarkers`; two-sided Welch t-test (test type t); cell type as a covariate through the `design` argument; up-regulated genes only (direction up); FDR ≤ 0.05; log fold change ≥ 0.1 |
| 40341143 | mixed | single-perturbation CRISPR cells vs non-targeting cells | `findMarkers`; scran v1.32.0; target genes at log2 fold change ≥ 0.25 in absolute value |
| 35858557 | bioconductor | WT vs KO genotype within cell populations | `pairwiseWilcox` (Wilcoxon rank-sum); FDR < 0.05 |
| 40500437 | bioconductor | signature-defined populations, proportion of Foxn1-expressing cells | `findMarkers` as a binomial test (test type binom) |
| 39097589 | mixed | TF-perturbed vs unperturbed cells; GEDI-inferred activities | `scoreMarkers`; scran v1.30.0; mean standardised Cohen’s d as effect |
| 39026254 | mixed | gene clusters over neighbourhood logFC vectors (genes, not cells) | `findMarkers`; `pval.type = "any"`; top 3 neighbourhoods per gene set |

The verifier read 39587361 as applicable (mixed at the time): the scran marker machinery is run, only the source of the labels differs. The rule stays as written; this contrary view is an open owner item (P-5).

Within applicable articles, a condition contrast is not recorded either: 39349459 runs `findMarkers` for each condition after vs before co-culture; only its cluster `scoreMarkers` run counts.

Excluded for other reasons (no scran marker function on scRNA clusters): 34878841 (SciPy Mann-Whitney after scran size factors), 37828140 (`modelGeneVar` for HVGs only), 32490811 (scran normalisation only), 40498845 (`pseudoBulkDGE`, cKO vs control), 38923993 (scRNA markers with Seurat only; scran 1.28.2 `clusterCells` and `scoreMarkers` (paper: “scoreMaerkers”) appear only on InfinityFlow flow-cytometry clusters, another modality; open item P-6).

## F -- figure grammar

- Show marker heatmap or dot plot by cluster and sample, with expression and detection fraction; label the selected effect summary and top-N/threshold rule.
- Display effect distributions or pairwise contrast panels when a single ranked list hides opposing cluster comparisons.

## W -- wording

- Report the grouping unit, `scoreMarkers`/`findMarkers` route, assay and normalization, block/pairings/`lfc`, effect statistic, ranking/filter rule and any compatibility test method. Cluster marker scores describe the observed cells; avoid a treatment-effect claim from cell-level comparisons.
- S2 draft: “For each <cluster>, `scoreMarkers` in scran <version> scored pairwise differences in <logcounts assay> with <block/pairings/lfc>. Genes were ranked by <effect summary> and selected by <rule>; expression and detection across clusters and samples were plotted.”
- Evidence for the wording: the grouping unit is the most often stated item (18/19 applicable papers; clusters in 12; cell types, populations or subsets in the other six); the effect summary is stated by 6/13 Bioconductor-only papers and by none of the five mixed papers; `lfc` by one paper in each of these two groups.

## V -- variant frequencies

Corpus labels (rule 7, ecosystem of the single-cell front end): 17 Bioconductor-only (13 applicable, four inapplicable), nine mixed (five applicable, four inapplicable), three Seurat (one applicable, two inapplicable) and one scverse (inapplicable). Mixed means the front end itself crosses ecosystems; Seurat, scverse or other packages used only downstream (markers of another package, label transfer, module scores) or on another modality do not make an article mixed. Values are counted **within applicable ecosystem groups**, with denominators 13, 5 and 1; no pooled majority. “Majority” means strictly more than half of that denominator. Function names are normalised (`scoreMarker` and `FindMarkers` written for scran are counted as `scoreMarkers` and `findMarkers`; the paper spelling is kept in the row note).

### Bioconductor-only (13 applicable)

| Parameter | Reported values and paper counts | Reported / applicable | Not reported / applicable |
|---|---|---:|---:|
| `marker_route` | scoreMarkers: 7; findMarkers: 6 | 13/13 | 0/13 |
| `effect_summary` | mean AUC: 2; Cohen’s d: 1; mean.logFC.cohen: 1; log2FC: 1; summary logFC (from the pairwise comparison with the lowest p-value): 1 | 6/13 | 7/13 |
| `reference_group` | none | 0/13 | 13/13 |
| `block` | sample: 1; plate: 1 | 2/13 | 11/13 |
| `pairings` | all pairs of clusters: 1 | 1/13 | 12/13 |
| `direction` | up: 1 | 1/13 | 12/13 |
| `min_logfc` | none | 0/13 | 13/13 |
| `pval_type` | any: 1 | 1/13 | 12/13 |
| `test_type` | one-sided Welch t-test: 1; pairwise t test: 1; Wilcoxon rank sum test: 1 | 3/13 | 10/13 |
| `lfc` | 0.1: 1 | 1/13 | 12/13 |
| `min_cells` | none | 0/13 | 13/13 |
| `padj_cutoff` | none | 0/13 | 13/13 |
| `top_n` | 100: 2; 10: 1 | 3/13 | 10/13 |
| `scran_version` | 1.14.1: 1; 1.18.7: 1; 1.22.1: 1; 1.24.1: 1; 1.30.2: 1; 1.32.0: 1; 1.34.0: 1 | 7/13 | 6/13 |
| `assay_type` | log-normalized values: 1 | 1/13 | 12/13 |
| `groups` | none | 0/13 | 13/13 |
| `subset_row` | none | 0/13 | 13/13 |
| `threshold` | 1 (mean.logFC.cohen > 1): 1 | 1/13 | 12/13 |
| `rank_by` | mean AUC: 2; significance: 1; Cohen’s d: 1; absolute log2FC: 1 | 5/13 | 8/13 |
| `cluster_unit` | clusters: 8; clusters and cell types (two runs): 1; populations: 1; broad cell types: 1; MkP subsets: 1 | 12/13 | 1/13 |
| `marker_heatmap` | dot plot: 1 | 1/13 | 12/13 |
| `row_data` | none | 0/13 | 13/13 |
| `full_stats` | none | 0/13 | 13/13 |
| `bpparam` | none | 0/13 | 13/13 |
| `min_prop` | none | 0/13 | 13/13 |
| `log_p` | none | 0/13 | 13/13 |
| `sorted` | none | 0/13 | 13/13 |
| `add_summary` | none | 0/13 | 13/13 |
| `gene_names` | none | 0/13 | 13/13 |

### Mixed (5 applicable)

| Parameter | Reported values and paper counts | Reported / applicable | Not reported / applicable |
|---|---|---:|---:|
| `marker_route` | findMarkers: 5 | 5/5 | 0/5 |
| `effect_summary` | none | 0/5 | 5/5 |
| `reference_group` | none | 0/5 | 5/5 |
| `block` | plate: 1 | 1/5 | 4/5 |
| `pairings` | none | 0/5 | 5/5 |
| `direction` | up: 3; up and down (two one-sided runs): 1 | 4/5 | 1/5 |
| `min_logfc` | none | 0/5 | 5/5 |
| `pval_type` | any: 1 | 1/5 | 4/5 |
| `test_type` | wilcox: 1 | 1/5 | 4/5 |
| `lfc` | 0.5: 1 | 1/5 | 4/5 |
| `min_cells` | none | 0/5 | 5/5 |
| `padj_cutoff` | none | 0/5 | 5/5 |
| `top_n` | 10: 2 (one also 50 for GO enrichment) | 2/5 | 3/5 |
| `scran_version` | 1.16.0: 2 | 2/5 | 3/5 |
| `assay_type` | logged normalized read counts: 1 | 1/5 | 4/5 |
| `groups` | none | 0/5 | 5/5 |
| `subset_row` | none | 0/5 | 5/5 |
| `threshold` | none | 0/5 | 5/5 |
| `rank_by` | none | 0/5 | 5/5 |
| `cluster_unit` | clusters: 3; annotated cell types: 1; cell types: 1 | 5/5 | 0/5 |
| `marker_heatmap` | heatmap: 1 | 1/5 | 4/5 |
| `row_data` | none | 0/5 | 5/5 |
| `full_stats` | none | 0/5 | 5/5 |
| `bpparam` | none | 0/5 | 5/5 |
| `min_prop` | none | 0/5 | 5/5 |
| `log_p` | none | 0/5 | 5/5 |
| `sorted` | none | 0/5 | 5/5 |
| `add_summary` | none | 0/5 | 5/5 |
| `gene_names` | none | 0/5 | 5/5 |

### Seurat front end (1 applicable)

37555828 runs `scoreMarkers` (paper: `scoreMarker`) on T-cell subtypes after a Seurat front end: `marker_route` scoreMarkers 1/1, `cluster_unit` T-cell subtypes 1/1; every other parameter 0/1. A single paper sets no default.

Among the 13 Bioconductor-only applicable articles, `scoreMarkers` is the majority route (7/13); `findMarkers` is used by 6/13. Clusters are the most common grouping unit (9/13 including the paper that also scores cell types). No other parameter is reported by more than half of the 13; the effect summary (6/13) and ranking rule (5/13) have no majority value, `mean AUC` being the most common (2/13 each), and `lfc`, `block`, `direction`, `pval_type` and the test type are each stated by at most three papers. In the five mixed papers, `findMarkers` is used by all five and `direction = "up"` by a majority (3/5; 4/5 state an up direction, one of them together with down); every other value comes from one or two papers. No `min_logfc` value is recorded in any group: the former 2.0 of 41469724 was a Seurat `FindAllMarkers` threshold.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 23: `GrunPancreasData()` EH2687, 1,728 cells and 20,148 features. The 9.2 MB `counts.rds` was downloaded and SHA256-verified for scran-cluster: `237f99410659bb6614f2cbc2cd1fcb2a5d242230c97490c87f324a59bbac246d`. `fetch_anchor_data.sh hub` records the URL and hash.
- Locked scran vignette loads Grun; locked scoreMarkers Rd demonstrates a `mockSCE` with k-means groups and prints `out[[1]]`. S1 may replay the package example first, then Grun-derived groups; no R replay or numeric golden is claimed in S0.

## D -- locked function default / official guide / Bioconductor-only exemplars

Defaults come from scran 1.40.0 defining S4 Rd, not a paper’s historical version. Thirteen applicable Bioconductor-only papers form the exemplar denominator.

| Parameter | Function default (locked version) | Official guide | Bioconductor-only exemplar evidence | S1 draft |
|---|---|---|---|---|
| `marker_route` | `scoreMarkers` is explicit caller choice; `findMarkers` is a separate deprecated compatibility route | locked Rd illustrates `scoreMarkers(sce,groups=kout$cluster)`; `findMarkers` examples are compatibility | scoreMarkers: 7; findMarkers: 6 (13/13 applicable; scoreMarkers majority 7/13) | pending S1 |
| `effect_summary` | `scoreMarkers` returns AUC, Cohen’s d, logFC and detected-fraction summaries; ranking metric is caller choice | Rd describes mean/min/max AUC and Cohen’s d; ranking chosen for biological question | mean AUC: 2; Cohen’s d: 1; mean.logFC.cohen: 1; log2FC: 1; summary logFC: 1 (6/13 applicable) | pending S1 |
| `reference_group` | pairwise groups, no fixed reference | not explicitly set | none (0/13 applicable) | pending S1 |
| `block` | `scoreMarkers.ANY(block=NULL)`; forwarded `findMarkers` pairwise tests may block | not explicitly set | sample: 1; plate: 1 (2/13 applicable) | pending S1 |
| `pairings` | `scoreMarkers.ANY(pairings=NULL)` | not explicitly set | all pairs of clusters: 1 (1/13 applicable) | pending S1 |
| `direction` | forwarded to `findMarkers` pairwise tests; no fixed value in its own Rd | not explicitly set | up: 1 (1/13 applicable) | pending S1 |
| `min_logfc` | no `min.logFC` argument; `scoreMarkers(lfc=0)` shifts effect threshold | not explicitly set | none (0/13 applicable) | pending S1 |
| `pval_type` | `findMarkers.ANY(pval.type=c("any","some","all"))`, first `any` | not explicitly set | any: 1 (1/13 applicable) | pending S1 |
| `test_type` | `findMarkers.ANY(test.type=c("t","wilcox","binom"))`, first `t` | not explicitly set | one-sided Welch t-test: 1; pairwise t test: 1; Wilcoxon rank sum test: 1 (3/13 applicable) | pending S1 |
| `lfc` | `scoreMarkers.ANY(lfc=0)`; forwarded in `findMarkers` tests | not explicitly set | 0.1: 1 (1/13 applicable) | pending S1 |
| `min_cells` | no `min.cells` in core S4 signatures | not explicitly set | none (0/13 applicable) | pending S1 |
| `padj_cutoff` | no automatic significance cutoff in `scoreMarkers`; `findMarkers` returns adjusted values | not explicitly set | none (0/13 applicable) | pending S1 |
| `top_n` | not fixed in either function; output is caller-filtered | not explicitly set | 100: 2; 10: 1 (3/13 applicable) | pending S1 |
| `scran_version` | locked scran 1.40.0 | release 3.23 source and rendered vignette | 1.14.1, 1.18.7, 1.22.1, 1.24.1, 1.30.2, 1.32.0, 1.34.0: 1 each (7/13 applicable) | pending S1 |
| `assay_type` | `scoreMarkers.SummarizedExperiment(assay.type="logcounts")`; same for `findMarkers` | Rd example log-normalizes mock SCE before scoring | log-normalized values: 1 (1/13 applicable) | pending S1 |
| `groups` | SCE methods default `groups=colLabels(x,onAbsence="error")`; ANY requires groups | example uses k-means cluster labels | none as an argument (0/13 applicable); grouping unit recorded under `cluster_unit` | pending S1 |
| `subset_row` | `scoreMarkers.ANY(subset.row=NULL)` | not explicitly set | none (0/13 applicable) | pending S1 |
| `threshold` | no generic output threshold; caller filters effects | not explicitly set | 1 (mean.logFC.cohen > 1): 1 (1/13 applicable) | pending S1 |
| `rank_by` | caller chooses summary/effect column | Rd example suggests ranking by an effect summary column | mean AUC: 2; significance: 1; Cohen’s d: 1; absolute log2FC: 1 (5/13 applicable) | pending S1 |
| `cluster_unit` | caller-supplied groups; cells are descriptive units, not biological replicates | not explicitly set | clusters: 8; clusters and cell types: 1; populations: 1; broad cell types: 1; MkP subsets: 1 (12/13 applicable) | pending S1 |
| `marker_heatmap` | no plotting default in `scoreMarkers`/`findMarkers` | not explicitly set | dot plot: 1 (1/13 applicable) | pending S1 |
| `row_data` | `scoreMarkers.ANY(row.data=NULL)`; `findMarkers.ANY(row.data=NULL)` | not explicitly set | none (0/13 applicable) | pending S1 |
| `full_stats` | `full.stats=FALSE` in both ANY methods | not explicitly set | none (0/13 applicable) | pending S1 |
| `bpparam` | `BPPARAM=SerialParam()` in both ANY methods | not explicitly set | none (0/13 applicable) | pending S1 |
| `min_prop` | `findMarkers.ANY(min.prop=NULL)`; effective 0.5 for `pval.type="some"` | not explicitly set | none (0/13 applicable) | pending S1 |
| `log_p` | `findMarkers.ANY(log.p=FALSE)` | not explicitly set | none (0/13 applicable) | pending S1 |
| `sorted` | `findMarkers.ANY(sorted=TRUE)` | not explicitly set | none (0/13 applicable) | pending S1 |
| `add_summary` | `findMarkers.ANY(add.summary=FALSE)` | not explicitly set | none (0/13 applicable) | pending S1 |
| `gene_names` | forwarded pairwise test argument; no direct default in locked core signatures | not explicitly set | none (0/13 applicable) | pending S1 |

## X -- version-sensitive behaviour

- scran 1.40 NEWS fixes AUC calculation in `scoreMarkers`/`pairwiseWilcox` for many tied values. S1 numerical replay must use the locked 1.40 implementation.
- The locked `findMarkers` Rd describes it as deprecated and points to `scrapper::scoreMarkers.se`; `scoreMarkers` Rd emphasizes descriptive effect sizes because cells from discovered clusters are not independent biological replicates. The engineering plan still names scran `scoreMarkers`, so S1 must decide the supported frontend while preserving semantics.
- Historical papers may call an argument `test=` (38959321, scran 1.16.0) or spell `scoreMarker` singular; do not assume these match locked `findMarkers(test.type=...)` or `scoreMarkers` without replay. 38959321 also documents a scran 1.16.0 inconsistency between one-sided and `direction = "any"` tests when `lfc > 0` and works around it with two one-sided runs.
- A paper’s Cohen’s d cutoff above one is an effect threshold; it is not a P value or output tolerance.
- Thresholds printed next to a scran call can belong to another package’s marker call in the same sentence (41469724: LFC ≥ 2.0, adjusted P ≤ 1E-05 and ≥ 25% detection are Seurat `FindAllMarkers` settings); they are not scran evidence.

## S1 drafts and pending decisions

- P-1 Choose `scoreMarkers` effect ranking as the planned route or a supported `scrapper` wrapper, and define the compatibility `findMarkers` path separately.
- P-2 Freeze the marker effect summary (mean/min AUC, Cohen’s d, logFC), `lfc`, blocking, gene filters and top-N rule. The Bioconductor-only evidence gives no majority effect rule (effect summary 6/13, most common mean AUC 2/13).
- P-3 Keep mixed Seurat and scverse marker settings outside the Bioconductor preset. For actual condition effects, route to pseudobulk or paired-sample analysis.
- P-4 Replay locked `mockSCE` and Grun-derived cluster examples before fixing output columns, heatmap ordering, seeds and numeric tolerances.
- P-5 (owner, open) Count the six non-cluster-grouping papers of section T (39587361, 40341143, 35858557, 40500437, 39097589, 39026254) or not. They add test-type (t, Wilcoxon, binomial), `pval.type`, direction, FDR and design/blocking evidence that the counted papers rarely state. The verifier read 39587361 as applicable; the rule currently excludes it.
- P-6 (owner, open) Borderline applicability kept as recorded: 35922411 (groups are MkP subsets whose definition the Methods do not state; counted), 38959321 (features are spike-in-normalised microbial read counts across sorted cell types; counted), 38923993 (scran `scoreMarkers` only on flow-cytometry clusters; not counted). Label items for the cross-module check: 38127790 and 32840210 kept mixed because Seurat clustering is part of their front end only as a validation or secondary integration.
