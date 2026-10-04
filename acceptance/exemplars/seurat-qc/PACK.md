# PACK -- seurat-qc

Status: S0 evidence collected; S1 decisions drafted, not frozen. Independent verification is assigned to the other lane.

| Layer | Evidence |
|---|---|
| L1 | Seurat 5.5.1, SeuratObject 5.4.0; CRAN 2026-09-15 sources, Rd, NEWS, CITATION where present, and Seurat v5.5.1 `pbmc3k_tutorial.Rmd` plus official rendered page with printed values. Hashes: `L1_cran2026-09-15/manifest.tsv`. |
| L2 | Seurat guided PBMC 3k tutorial, source pinned to v5.5.1; rendered page URL and hash in the L1 manifest. |
| L3/L4 | 30 licensed OA full texts with PubMed efetch echo; 10 tier-A L3 close readings; 28/30 applicable (24 Seurat, four mixed). See `literature/`. |

## T -- table skeleton

- Per-sample filtering flow: input cells, removal by detected gene count, mitochondrial fraction and other stated criteria, retained cells; preserve overlapping-criterion counts separately from sequential removals.
- Per-cell QC table: cell ID, sample, `nCount_RNA`, `nFeature_RNA`, `percent.mt`, pass/fail and reason. State units and the mitochondrial gene pattern.

## F -- figure grammar

- Tutorial: violin plots of `nFeature_RNA`, `nCount_RNA` and `percent.mt`; scatterplots of UMI count against mitochondrial percentage and detected genes. Mark the chosen limits and report cells before and after filtering in the caption.

## W -- wording

- L3 wording pattern: specify the specimen and input matrix, Seurat version when given (21/24 Seurat-only applicable Methods state one, three of them as a major version only such as `v4`; the four mixed papers all state one), which cells were removed, and each inequality with its unit. Several papers use sample-specific or percentile rules; describe those as such.
- S2 Methods draft: “Raw counts were loaded into Seurat <version> with `CreateSeuratObject` (`min.cells=<...>`, `min.features=<...>`). Mitochondrial percentage was computed with `PercentageFeatureSet` (`pattern=<...>`); cells were retained under the explicitly stated gene-count and mitochondrial thresholds.” Use paper-specific wording only after L3 close reading.

## V -- variant frequencies

The 30-paper corpus comprises 24 Seurat and six mixed-ecosystem articles (label = ecosystem of the single-cell front end). 24 Seurat and four mixed articles actually perform this QC part (28/30). The other two are excluded because cell QC was done outside Seurat: per-library thresholds on starSOLO output in one, scater QC metrics in the other (both labelled mixed). The four mixed applicable papers cross ecosystems inside the front end: Scanpy preliminary filter then Seurat filter (one), Bioconductor scDblFinder doublet removal (one), Bioconductor decontX ambient-RNA correction in one dataset (one), and scater-based removal of cell-cycle genes before HVG selection (one). Frequencies below use the **24 applicable Seurat papers** only; the mixed papers are reported separately. `collect.py summarize` prints pooled counts and is not used as a Seurat default denominator.

| Parameter | Seurat-only reported values (count / 24 applicable) | Not reported / 24 | Interpretation |
|---|---|---|---|
| Gene filter at object creation (`min.cells` meaning) | 3: 2; 5 and 10 (written "more than five cells", ">10 cells"): one each; 0.1% of all cells: 1 | 19 | No function argument is printed; the values are stated as "genes expressed in fewer than / more than N cells". Reported by 5/24, so no default. |
| Cell filter at object creation (`min.features` meaning) | 200: 2 (paired with the three-cell gene filter) | 22 | Too few reports for a default; in one of the two papers the same 200 floor is restated in the retention filter. |
| `CreateSeuratObject` assay | none | 24 | Tutorial calls are not paper reports. |
| Detected-gene lower limit | 200: 6; 500: 3; 300: 2; 1,000, 50, 800, 2,000 and 600 (plus a day-specific 1,500): one each; percentile, adaptive, top-cell and 3-SD rules: one each | 3 | 200 is **most common**, 6/24, not a majority. One paper's inequalities are ambiguous. |
| Detected-gene upper limit | fixed limits 5,000, 2,000, 11,000, 8,000, 4,000, 4,900, 6,000 and 10,000: one each; day-specific 6,000/5,500: one; percentile, adaptive, sample-specific and 3-SD rules: one each | 10 | No value is repeated as a fixed global limit; one ambiguous paper excluded from numerical counts. |
| UMI lower limit | 1,000: 2; 2,000, 1,300, 1,500, 200: one each; percentile, day-specific and 3-SD rules: one each | 15 | No majority. |
| UMI upper limit | 20,000: 2; 24,000 and 10,000: one each; percentile and 3-SD rules: one each | 18 | No majority. |
| Mitochondrial upper limit | 10%: 6; 5%: 4; 20%: 2; 8%, 30%, 0.2% as written, 0.25 fraction and 0.1 fraction: one each; 7% on a secondary (TCR-seq, Platypus) object with an unquantified main filter: one; adaptive, outlier, 3-SD and ambiguous rules: one each | 2 | 10% is **most common**, 6/24 (7/24 if the 0.1 fraction is read as 10%), not a majority. Fractions remain in the printed units. |
| Mitochondrial gene pattern | `mt-`: 1 | 23 | No consensus from papers. |
| Seurat version | 21 report one (3 as major version only) | 3 | Versions span 3.0 to 5.3.0. |

The four applicable mixed papers (each count / 4 mixed): detected-gene lower limits 500, 200, 250 and 600; upper limits 7,500 and 6,000; UMI upper limit 200,000 in one and an ambiguous "more than 15,000 UMIs" in another; mitochondrial upper limit 10% in two, 20% in one, and 7% (main dataset) with 30% (separate BD Rhapsody datasets) in one; no `min.cells`, `min.features`, assay or pattern reports; versions stated by 4/4. They do not contribute to the Seurat-only frequencies. Every corpus article has an ecosystem label in `extraction.jsonl`. Values marked ambiguous or sample-dependent are not silently converted to fixed cutoffs.

## C -- anchors

- Registry row 15, 10x PBMC 3k (F1), accession 10x `pbmc3k`, URL and sha256 in `acceptance/data/ANCHOR_REGISTRY.md` and `fetch_anchor_data.sh`. Download verified against sha256 `847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5`.
- Official guided tutorial (`L1_cran2026-09-15/Seurat/vignettes/pbmc3k_tutorial.rendered.txt`) prints **13,714 features across 2,700 cells** after `CreateSeuratObject(counts, project="pbmc3k", min.cells=3, min.features=200)`. Its first-cell metadata gives `nCount_RNA=2419`, `nFeature_RNA=779`, `percent.mt=3.0177759`. Tutorial filtering is `nFeature_RNA > 200 & nFeature_RNA < 2500 & percent.mt < 5`. The printed values are candidate smoke assertions; no R replay was run in S0.

## D -- defaults: locked function / official tutorial / exemplar majority

| Parameter | Locked function default | Official PBMC 3k tutorial | Exemplar majority | S1 draft |
|---|---|---|---|---|
| `CreateSeuratObject` `min.cells` | 0 (SeuratObject default method) | 3 | no default: gene filter stated by 5/24 (3 in 2/24; 5, 10 and 0.1% of cells one each); not reported 19/24 | remain undecided |
| `CreateSeuratObject` `min.features` | 0 (SeuratObject default method) | 200 | no default: 200 in 2/24; not reported 22/24 | remain undecided |
| `CreateSeuratObject` `assay` | `"RNA"` | implicit RNA | not reported 24/24 | remain undecided |
| `PercentageFeatureSet` `pattern`, `features`, `col.name`, `assay` | NULL, NULL, NULL, NULL | `pattern="^MT-"`; assigned to `percent.mt` | `mt-` 1/24; not reported 23/24 | use species-aware pattern only after S1 |
| detected-feature lower / upper filter | no fixed function threshold; `subset.Seurat` evaluates the supplied expression | `>200`, `<2500` | lower 200 most common 6/24; no upper value repeated as a fixed global limit | no majority; do not freeze a numerical upper bound |
| mitochondrial fraction upper filter | no fixed function threshold | `<5%` | 10% most common 6/24; 5% 4/24 | S1 must decide by specimen and objective |
| UMI count lower / upper filter | no fixed function threshold | not used | lower 1,000 and upper 20,000 most common (2/24 each) | no majority |

## X -- version-sensitive behaviour

- SeuratObject 5.0.0 introduced `Assay5` layers; code assuming one assay matrix needs an explicit counts layer. Seurat 5.0.0 changed merging to retain layers instead of combining raw count matrices (Seurat NEWS).
- Seurat 5.3.0 fixed `PercentageFeatureSet` to respect its `assay` argument and to warn for absent requested features. SeuratObject 5.4.0 added `droplevels.meta.data` to `subset.Seurat`. These affect QC provenance and metadata after filtering. Sources: package NEWS files in L1.

## S1 drafts and pending decisions

- P-1 Filter thresholds: the tutorial has 200–2,500 genes and <5% mitochondrial content, while the Seurat-only corpus has no majority for any fixed limit. Draft: require explicit specimen-aware cutoffs or a prespecified adaptive rule; display the tutorial preset only as a named replay preset.
- P-2 Mitochondrial gene pattern: the human tutorial uses `^MT-`, but only one Seurat paper (1/24) reports a pattern (`mt-`). Draft: require species-aware prefix verification and allow an explicit feature list.
- P-3 Doublets and overlapping exclusions: record tool, sample scope and removal flow; do not infer counts from a final retained total. The module plan lists Seurat QC functions only, so extra doublet handling needs an explicit S1 scope decision.
- P-4 Mixed front ends: four applicable papers are mixed (one L3 paper uses Scanpy then Seurat; three L4 papers add a Bioconductor front-end step: scDblFinder doublet removal, decontX ambient-RNA correction, scater-based removal of cell-cycle genes). Keep them separately labelled; do not use their cutoffs for the Seurat-only default.
