# PACK — muscat-pseudobulk

S0 evidence pack; S1 choices remain drafts. This version is the redo after the independent verification of 2026-09-29 (`docs/build/S0_REDO_lane_b.md`); no `verification.json` is written by this lane.

| Layer | Evidence |
|---|---|
| L1 | muscat **1.26.0**, Bioconductor `RELEASE_3_23`: `aggregateData`/`pbDS` Rd, defaults, analysis/detection/simulation/BBHW rendered vignettes, NEWS, CITATION and source git commit with sha256 manifest in `L1_bioc3.23/`. |
| L2 | OSCA multi-sample chapter for Bioconductor 3.23 and the open-access muscat method paper (PMC7705760), pinned by URL and sha256 in `L2/manifest.tsv`. |
| L3 | 10 tier-A, applicable close readings (`literature/l3_notes.md`). |
| L4 | 21 licensed, open-access, whitelisted, PubMed-echoed articles; **14/21** run pseudobulk condition analysis, 7/21 do not (`literature/corpus.jsonl`, `extraction.jsonl`, `efetch/`). |

## T — table skeleton

The locked `pbDS` vignette prints one results table per contrast and cluster, with `gene`, `cluster_id`, `logFC`, `logCPM`, `F`, `p_val`, `p_adj.loc`, and `p_adj.glb`; retain both adjusted-P scopes and the full table. Report sample counts and retained cluster-sample pairs beside each contrast. A displayed Top-N subset may be sorted by adjusted P, but the untruncated table is the reproducible result. The L3 Methods do not establish a single Top-N size.

## F — figure grammar

The vignette's pseudobulk MDS uses MDS1/MDS2 axes, one point per cluster-sample, colour by cluster and shape by group. Add a cluster-by-sample cell-count heatmap before testing to show dropped pairs, and a per-cluster volcano/MA view labelled with the tested contrast and adjusted-P scope. These are draft graphics derived from L1 and the L3 reporting styles; no one exemplar's colour scheme is a rule.

## W — wording

Methods template: “Raw counts were summed within each <cell type/cluster> and biological <sample/donor> using muscat (v1.26.0) `aggregateData(assay="counts", fun="sum", by=c("cluster_id","sample_id"))`. Differential state was tested with `pbDS(method=<explicit>, design=<explicit>, contrast=<explicit>, min_cells=<explicit>, filter=<explicit>)`; <N> samples per condition entered each cluster model.” Results template: “Across <N> retained sample-by-cell-type pseudobulks, <N> genes passed the stated <local/global> adjusted-P criterion in <cell type>.” Do not call cells biological replicates. If a design argument was not specified by a paper, the extraction says `not reported`; it is not silently filled from function defaults.

## V — variant frequencies

Redo after independent verification (2026-09-29): the whole corpus was re-read for design, filter, min_cells, adjusted-P rule and ecosystem; the counts below are recomputed from `extraction.jsonl` (per-parameter and per-ecosystem tally).

Denominator: **14 applicable / 21 corpus**. All 14 applicable articles describe pseudobulk/sample-level condition analysis. The other seven consist of six aggregate-only/benchmark uses and **one explicit per-cell condition model** (PMC13385355). That per-cell model is a planned blocker and contributes **0** to default frequencies. Ecosystem is the front end (QC, normalisation, clustering); a downstream conversion or annotation step in another ecosystem does not make an article mixed. Among the 14: **Seurat 10/14, mixed 4/14 (39048816 SCANPY + Seurat, 41565468 SCANPY, 35383160 scater + Seurat, 42296961 Seurat + Scanpy), scverse 0/14, Bioconductor-only 0/14**. Two excluded articles (34103493, 35290180) are labelled Bioconductor only from the tools named (SingleR, muscat), because no author-run front end is described (`note` in the `_applies` row).

Four applicable articles do **not** test with `pbDS`: two run DESeq2 on muscat pseudobulks (41417727, 38561380), one ROTS (41462339) and one a Wilcoxon rank-sum test (41644562). They still count for the sample-level unit but are kept apart from the `pbDS(method=)` frequencies.

| Parameter | Seurat (n=10) | Mixed (n=4) | scverse (n=0) | All applicable (n=14) |
|---|---|---|---|---|
| Condition test unit | pseudobulk 10/10 | pseudobulk 4/4 | - | pseudobulk 14/14 |
| Test method | pbDS edgeR 4; DESeq2 external 2; ROTS 1; Wilcoxon 1; not reported 2 | pbDS edgeR 2; not reported 2 | - | pbDS edgeR 6, external tests 4, not reported 4 |
| Aggregation assay | counts/raw counts 4, not reported 6 | raw counts / raw UMI counts 2, not reported 2 | - | reported 6, not reported 8 |
| Aggregation `by` | cell type or lineage x sample 4, not reported 6 | cluster x sample or sample x cell type 2, not reported 2 | - | reported 6, not reported 8 |
| Aggregation `fun` | sum 3, not reported 7 | sum 1, not reported 3 | - | sum 4, not reported 10 |
| `min_cells` (pair threshold) | 0/10 (one cluster-level rule: median < 20 cells across samples, 38212464) | 10 cells per sample-cell-type pair 1 | - | pair threshold 10: 1; cluster-level rule 1; not reported 12 |
| Filter before the test | genes with raw counts < 10 in > 8 samples 1, not reported 9 | gene > 1 count in >= 10 cells 1; muscat internal filters without thresholds 1; not reported 2 | - | reported 3, not reported 11 |
| Design (covariates) | "no additional variables" 1 (ROTS), not reported 9 | age + post-mortem interval 1; group only 1; sex + APOE4 + age 1; not reported 1 | - | reported 4, not reported 10 |
| Multiple-testing algorithm | Benjamini-Hochberg 2; FDR, algorithm not named 2; not reported 6 | Benjamini-Hochberg 1; adjusted P, algorithm not named 1; not reported 2 | - | BH 3, unnamed 3, not reported 8 |
| Adjusted-P cutoff for this analysis | 0.05 in 3; 0.05 or 0.1 in 1; "P < 0.05" statement, adjusted vs raw not explicit 1; not reported 5 | 0.05 in 1; not reported 3 (one uses nominal p < 0.05) | - | reported 6, not reported 8 |
| Biological replicates per group | 2 per genotype in 1 | 0/4 | - | 1/14 |
| Version | reported 5 (1.4.0, 1.6.0, 1.8.2, 1.12.0, 1.14) | reported 2 (1.4.0, 1.16.0) | - | 7/14 |
| `scale`, `norm`, `treat`, explicit `contrast=` / `coef=` argument | not reported 10/10 | not reported 4/4 | - | not reported 14/14 |

edgeR is named by 6 of the 10 articles that name a DE test on the muscat pseudobulks, which is more than half of those reporting; all six call it through `pbDS`. The DESeq2, ROTS and Wilcoxon uses are external to `pbDS`. Across all 14 applicable articles edgeR is 6/14, the most common value but not a majority. Sum is 4/4 among articles naming the aggregation function, but only 4/14 overall. No scverse-front-end article is applicable, so no scverse-specific value is established. Compared conditions are named in most Methods, but no article prints a `contrast=` or `coef=` argument, so those rows stay 0/14. Values in adjacent marker, bulk or pathway analyses were not assigned to muscat: for example the `Padj > 0.05` (sic) sentence of 39048816 belongs to MAST/Nebula, and the FDR < 0.1 of 41462339 belongs to lmerTest models.

## C — replay and printed anchors

`acceptance/data/ANCHOR_REGISTRY.md` #26: muscData `Kang18_8vs8`, ExperimentHub **EH2259** (GEO GSE96583), 8 paired lupus donors (control/IFN-β), local F25 `EH2259_muscData_Kang18_8vs8.Rda`. The file was downloaded and passed its registered sha256 in `fetch_anchor_data.sh hub`. The locked analysis vignette calls `aggregateData(sce, assay="counts", fun="sum", by=c("cluster_id","sample_id"))` and prints eight assays/clusters. In the B-cell pseudobulk, `ctrl101` has NOC2L=12 and ISG15=13, while `stim101` has ISG15=1362. `pbDS(pb, verbose=FALSE)` prints B-cell ISG15 `logFC=5.47346`, `p_val=3.0e-21`, `p_adj.loc=9.9e-19`, `p_adj.glb=3.3e-18` (format digits shown in the vignette). Those printed values are hard assertions for its exact recipe, not numerical tolerances. The package-embedded `example_sce` is a small replay fixture, not the primary anchor.

## D — function default / official guide / exemplar evidence

Defaults below are from `L1_bioc3.23/muscat/defaults.tsv` and the corresponding Rd. For vector defaults, the first choice is selected by the package's argument matching; do not infer settings from papers that say only “default parameters.” The vignette's Kang recipe and OSCA 3.23 guide are examples/recommendations, not universal study designs.

| Parameter (profile id) | Function default, locked version | Vignette / official guide | Exemplar frequency | S1 draft |
|---|---|---|---|---|
| Unit (D-MP1) | `pbDS` requires pseudobulk object | Biological replication at sample level; OSCA warns against treating cells as independent replicates | pseudobulk 14/14 applicable; per-cell 1/21 corpus excluded | Require sample IDs and condition assignment; block direct cell-level condition testing |
| `aggregateData(by)` (D-MP2) | `c("cluster_id","sample_id")` | Same in Kang vignette; sample-by-cell-type sum in OSCA | explicit pair 6/14 (Seurat 4/10, mixed 2/4) | Explicit cluster and sample keys; validate one condition per sample |
| `aggregateData(assay)` (D-MP3) | NULL = first assay, which depends on input order | `"counts"` for DS | counts/raw 6/14 (Seurat 4/10, mixed 2/4) | Explicit raw-count assay/layer, no first-assay fallback |
| `aggregateData(fun)` (D-MP4) | first choice `"sum"` | `"sum"` raw counts | sum 4/14 (Seurat 3/10, mixed 1/4); 10 not reported | Explicit `"sum"` |
| `aggregateData(scale)` (D-MP5) | FALSE | Vignette does not scale before testing | 0/14 reported | Explicit FALSE |
| `pbDS(min_cells)` (D-MP6) | 10 per cluster-sample | OSCA's example also removes pairs with <10 cells; threshold is dataset-specific | pair threshold 10 in 1/14 (mixed); cluster-level rule (median < 20 cells across samples) in 1/14 (Seurat); not reported 12 | Explicit 10 provisionally, with retained-pair report |
| `pbDS(method)` (D-MP7) | first choice `"edgeR"` | Kang vignette uses edgeR default; OSCA sample-level bulk test also uses edgeR | pbDS edgeR 6/14 (Seurat 4/10, mixed 2/4); external tests 4/14 (DESeq2 2, ROTS 1, Wilcoxon 1, all Seurat); not reported 4/14 | EdgeR preset, other methods explicit options; never derive from cell-level studies |
| `pbDS(design)` (D-MP8) | NULL → `~ group_id` or design matrix | Vignette shows an explicit design/contrast for stimulated versus control | explicit covariates or formula 4/14 (Seurat 1/10, mixed 3/4): age + post-mortem interval; sex + APOE4 + age; group only; "no additional variables" (ROTS) | Require design from StudyContract; include pairing/covariates when present |
| `pbDS(contrast)` (D-MP9) | NULL | Vignette specifies `stim` against `ctrl` when needed | explicit `contrast=` argument 0/14 (compared conditions are named in most articles) | Explicit contrast and reference level |
| `pbDS(coef)` (D-MP10) | NULL; vignette says last coefficient is tested by default | Explicit coefficient or contrast for complex designs | 0/14 reported | Do not depend on column order; explicit test term |
| `pbDS(filter)` (D-MP11) | first choice `"both"` | Vignette uses package filtering | gene or sample filter before the test 3/14 (Seurat 1/10, mixed 2/4; thresholds differ: raw counts < 10 in > 8 samples; > 1 count in >= 10 cells; internal filters without numbers) | Explicit `"both"`; log dropped samples and genes |
| Normalization (D-MP12) | Internal to chosen bulk method, not a `pbDS` argument | Raw sums then bulk normalization | 0/14 explicitly linked to this muscat comparison | Record method and factors in provenance |
| Multiple-testing method (D-MP13) | No `pbDS` argument; output has local/global adjusted P | Vignette shows both scopes | BH explicit 3/14 (Seurat 2/10, mixed 1/4); FDR or adjusted P without algorithm 3/14 | State algorithm and whether local or global; retain both columns |
| Adjusted-P cutoff (D-MP14) | No `pbDS` cutoff argument | No universal cutoff in vignette | adjusted-P 0.05 in 4/14 (Seurat 3/10, mixed 1/4); 0.05 or 0.1 in 1; P < 0.05 statement (adjusted not explicit) in 1; all joint with fold-change or detection rules | S1 choose reporting threshold; full table retained |
| Biological replicates (D-MP15) | Data design, not a function default | Kang: 8 paired donors | per-group count reported in 1/14 (2 per genotype; Seurat) | Require biological replication; S1 decide minimum/QC |
| Package version (X) | Locked 1.26.0 | Run records the locked version | 7/14 report versions | Pin container; do not reuse historical defaults |
| `pbDS(treat)` (D-MP16) | FALSE | Not used in Kang example | 0/14 reported | Explicit FALSE; thresholded test only by explicit choice |

The replicate requirement is a design guard, not a literature majority; S1 must decide the actual minimum and power/QC rule. `min_cells` is an inclusion threshold, not a numerical tolerance.

## X — version-sensitive items

- muscat 1.25.4 fixes CPM values in `resDS` when `method="limma-voom"`; old numeric examples can differ.
- muscat 1.25.3 renames its edgeR normalization call to `normLibSizes`; record the installed edgeR version and exact pipeline.
- muscat 1.25.1 adds sparse-matrix support for `pbDS`; muscat 1.19.1 added differential detection method `"DD"`, which is a distinct analysis part and not a pseudobulk expression default.
- One paper's JATS puts a superscript citation 115 immediately after `muscat 1.4.0`; plain-text parsing gave `1.4.0115`. `extraction.jsonl` records the XML-verified 1.4.0 and notes the markup.

## S1 drafts and pending decisions

1. Require a sample identifier and reject a condition test that treats cells as independent replicates. The corpus contains one explicit per-cell model (excluded); report it as the planned blocker.
2. Use raw-count sums per cell type × sample and make `method="edgeR"`, `min_cells=10`, `filter="both"`, `treat=FALSE`, and the contrast explicit. The edgeR draft is supported by L1 and the most common reported method, while `min_cells=10` is a guide/default choice with only one supporting paper.
3. Require an explicit design/contrast with reference level, account for paired donors or other covariates, and state local versus global multiple-testing scope. Papers rarely report exact formulas, so no exemplar majority can supply them.
4. Check the scverse and Seurat object conversions preserve raw counts, sample IDs, condition, cluster labels and cell counts. A converted cell is never a new biological replicate.
