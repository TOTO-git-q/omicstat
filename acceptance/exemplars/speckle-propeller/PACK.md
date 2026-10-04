# PACK — speckle-propeller

S0 evidence pack; S1 choices are drafts. This version is the redo after the independent verification of 2026-09-29 (`docs/build/S0_REDO_lane_b.md`); this lane does not write `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | speckle **1.12.0** on Bioconductor `RELEASE_3_23`: `propeller`, `propeller.ttest`, `propeller.anova` Rd/defaults, rendered vignette, NEWS, CITATION and sha256 manifest in `L1_bioc3.23/`. |
| L2 | OSCA 3.23 differential-abundance guide and Phipson et al. 2022 (PMC9563678), URL/sha256 pinned in `L2/manifest.tsv`. |
| L3 | 10 applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | 21 licensed, open-access, PubMed-echoed Methods papers, **20/21 applicable** to condition comparisons; 1/21 calculates relative abundance only. |

## T — table skeleton

Retain the full per-cell-type table: cell-type label, group mean proportions, baseline proportion, statistic, raw `P.Value`, `FDR`, group sample counts, and transform. The locked vignette prints these fields for its CellBench example. Displayed Top-N rows, if any, are only a view of this table. Name the tested contrast and covariates next to the table; do not imply that a nearby gene-level threshold applies to proportions.

## F — figure grammar

Show per-sample cell-type proportions by condition, with one point per biological sample and a group summary. A composition overview can be a stacked proportion plot, but its shares are dependent; pair it with the per-sample view and the full test table. State `logit` or `asin` in the caption when transformed values are plotted. These are S1 draft grammar choices grounded in the L1 vignette and reported sample-level analyses.

## W — wording

Methods template: “Cell-type proportions were computed within biological sample `<sample_key>` and compared across `<group_key>` using speckle `propeller` (v1.12.0; `transform=<...>`, `trend=<...>`, `robust=<...>`). The analysis included `<n>` independent samples by group; `<design/covariates>` and `<adjustment>` were stated explicitly.” Results template: “For `<contrast>`, `<cell type>` had group mean proportions `<...>` and `<...>`, with raw P `<...>` and FDR `<...>`.” Do not describe cell counts as independent condition replicates. The paper that says “arcsin-transformed counts” is recorded verbatim in extraction; L1 documents a transform of proportions.

## V — variant frequencies

Redo after independent verification (2026-09-29): all 21 Methods were re-read and `group_key`, `sample_key`, `cluster_key`, `p_adjust`, `cutoff` re-extracted corpus-wide; ecosystem follows the front end (QC, normalisation, clustering). Counts are recomputed from `extraction.jsonl`.

Denominator: **20 applicable / 21 corpus**. Front end among applicable: **Seurat 16/20, mixed 4/20 (41253754 Seurat + SingleCellExperiment, 38769152 scANVI/batchelor/scater, 41193807 Bioconductor + scanpy, 42319930 scater QC + Seurat), scverse 0/20, Bioconductor-only 0/20**. Seven applicable Methods explicitly identify sample, donor, individual, or biological-replicate proportions (all Seurat); 13/20 do not name the unit. **Zero/21** explicitly describe a per-cell condition test through propeller. The excluded relative-abundance-only paper (PMC13533838) contributes no default frequency.

| Parameter | Seurat (n=16) | Mixed (n=4) | scverse (n=0) | All applicable (n=20) |
|---|---:|---:|---:|---:|
| Explicit sample/donor/replicate unit (`sample_key` or unit) | 7 | 0 | - | 7; not reported 13 |
| Compared groups named (`group_key`) | 15 | 3 | - | 18/20 (one says "conditions" without levels); exact column name `group` in 1 |
| Cell-type unit named (`cluster_key`) | 11 | 2 | - | 13/20; exact column name `cluster ID` in 1 |
| `logit` transform | 2 | 0 | - | 2 |
| Arcsine transform (arcsine 1, arcsin square root 1; one mixed paper says "arcsin-transformed counts") | 2 | 1 | - | 3 |
| Transform not reported | 12 | 3 | - | 15 |
| Exact `robust=T`, `trend=T` | 1 | 0 | - | 1 each |
| Multiple-testing algorithm named: Benjamini-Hochberg | 2 | 0 | - | 2 |
| FDR / adjusted P without algorithm | 2 | 3 | - | 5 |
| Cutoff for the proportion test | FDR 0.05 in 1; P 0.05 (adjusted not stated) in 1 | FDR <= 0.1 in 1 | - | 3/20 |
| Covariates or design written | 3 (`~ 0 + c` with `~ 0 + c + method`; batch; age and gender) | 0 | - | 3 |
| Explicit contrast (pairwise vs control) | 1 | 0 | - | 1 |
| Test or model named | 4 | 0 | - | 4 |
| Exact `min_cells`, `coef` | 0 | 0 | - | 0/20 |

No reported transform has a majority. Among the five reporting a transform, logit appears in 2/5, arcsine variants in 3/5 (arcsine 1, arcsin square root 1, "arcsin-transformed counts" 1), so no single variant is more than half. The official default, not a literature majority, motivates a provisional logit choice. Nearly every Methods names the compared conditions, but very few name the sample column or write the `clusters`/`sample`/`group` arguments, so the exact-key counts stay 1/20 each. One Seurat paper reports `~0+c` and `~0+c+method`; other papers report batch or age and gender covariates. These are study designs, not transferable defaults. No scverse-front-end article is applicable, so no scverse-specific value is established.

## C — replay and printed anchors

Registry #27 / fetch F13 pins the vignette's CellBench `single_cell_data.RData` to the scBenchData commit and verified sha256; `pbmc_props` is package-embedded supplementary data. The locked vignette constructs three technology groups, bootstraps samples and runs `propeller(sce_all)` and `propeller(sce_all, transform="asin")`. Its printed H1975 row is `P.Value=0.01841045, FDR=0.05003357` for logit and `P.Value=0.01578743, FDR=0.04736228` for asin. Match the printed values for that exact recipe, without inventing a numerical tolerance. The bootstrap produces sampling variability and does **not** reproduce true between-donor biological variability; its p-values demonstrate code execution, not a biological conclusion.

## D — function default / official guide / exemplar evidence

| Parameter | Locked function default | Vignette / guide | Exemplar frequency | S1 draft |
|---|---|---|---|---|
| Test unit (D-SP1) | One proportion per biological sample and cluster | Biological replication; vignette's 2+1 sample minimum is mathematical, not a design recommendation | Explicit sample/donor/replicate 7/20 (all Seurat, 7/16); per-cell 0/21 | Require biological sample IDs and condition per sample; guard against per-cell tests |
| Cluster key (D-SP2) | `clusters=NULL`, derived from `x` if supplied | Vignette uses `sce_all$cluster` | Exact column name 1/20 (Seurat); cell-type unit named 13/20 (Seurat 11/16, mixed 2/4) | Require explicit cluster column and retained counts |
| Sample key (D-SP3) | `sample=NULL`, derived from `x` | Vignette uses `sce_all$sample` | Exact column name 1/20 (Seurat); sample unit named 7/20 (Seurat 7/16, mixed 0/4) | Require sample column; check unique sample-to-group assignment |
| Group key (D-SP4) | `group=NULL`, derived from `x` | Vignette uses `sce_all$group` | Exact column name 1/20 (Seurat); compared groups named 18/20 (Seurat 15/16, mixed 3/4) | Explicit condition and reference level |
| Transform (D-SP5) | `"logit"` | Compares logit and `"asin"` | logit 2/20 (Seurat), arcsine family 3/20 (Seurat 2/16, mixed 1/4), not reported 15/20 | Logit provisional; expose asin and report selected scale |
| Method (D-SP6) | `propeller` dispatches to moderated t-test/ANOVA path by groups | Vignette shows group comparison | Four papers name test/model variants, 16/20 do not | Record actual test path; do not infer from package name |
| Design (D-SP7) | Low-level functions require supplied design | OSCA models samples | Written design or covariates 3/20 (Seurat 3/16, mixed 0/4): `~ 0 + c` (+ method), batch, age and gender | Explicit design when covariates or >2 groups exist |
| Contrast (D-SP8) | Low-level `contrasts` must be supplied where used | Vignette compares named groups | Explicit contrast 1/20 (each knockdown vs scramble control, pairwise; Seurat); no `contrasts=` argument printed 20/20 | Explicit contrast and reference level |
| Minimum cells (D-SP9) | No `propeller` minimum-cell argument | Quality filtering before the test is data-specific | Not reported 20/20 | Report filtering and retained sample-cluster pairs |
| Adjustment (D-SP10) | Returned `FDR`; no adjustment argument | Vignette prints `P.Value` and `FDR` | BH named 2/20 (Seurat); FDR or adjusted P without algorithm 5/20 (Seurat 2, mixed 3) | Retain raw P and FDR, name algorithm |
| Cutoff (D-SP11) | No significance cutoff argument | No universal threshold | FDR <= 0.1 in 1/20 (mixed); FDR 0.05 in 1/20 (Seurat); P 0.05, adjusted not stated, in 1/20 (Seurat) | S1 choose display threshold, retain full table |
| Trend (D-SP12) | `FALSE` | Not a universal recommendation | `T` in 1/20 (Seurat) | Explicit FALSE provisionally; sensitivity option |
| Robust (D-SP13) | `TRUE` | Vignette uses default | `T` in 1/20 | Explicit TRUE provisionally |
| Coefficient (D-SP14) | Low-level ANOVA requires supplied `coef` | Example's chosen comparison is specific | Not reported 20/20 | Explicit term for multi-group design |
| Version (X) | 1.12.0 pinned | Locked vignette | Version explicit in 10/20 (Seurat 7/16, mixed 3/4) | Record container version |

## X — version-sensitive items

The NEWS supplied in speckle 1.12.0 describes the old 0.0.3 change of default transform to logit and 0.99.7 addition of `convertDataToList` for general proportion data; it does not state a recent 1.12.0 behavior change. Historical paper versions range from 0.0.1 to 1.4.0, so their unstated defaults must not be projected onto 1.12.0. PMC11021475's JATS puts bibliography reference 101 in superscript after `v0.0.3`; a flattened `v0.0.3101` is not a version.

## S1 drafts and pending decisions

1. Require biological sample IDs, group assignment, per-sample cell counts and a minimum-replication policy. The vignette's bootstrapped CellBench samples are only a replay fixture; S1 must set a defensible biological design guard.
2. Pin `transform="logit"`, `trend=FALSE`, `robust=TRUE` provisionally from L1; expose asin as an explicit alternative and record the choice.
3. Require an explicit design/contrast for covariates or multi-group comparisons; preserve full adjusted and raw-P tables and disclose compositional dependence.
4. Verify front-end conversion retains cluster, sample, condition and raw counts/proportions. Resolve ambiguous proportional-odds and transformed-counts wording through independent S1 review without making those papers defaults.
