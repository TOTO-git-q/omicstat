# PACK -- seurat-cluster

Status: S0 evidence collected; S1 choices drafted, not frozen. No `verification.json` is written by this lane.

| Layer | Evidence |
|---|---|
| L1 | Seurat 5.5.1, SeuratObject 5.4.0 and sctransform 0.4.3 from locked CRAN snapshot 2026-09-15. Rd, NEWS, CITATION where shipped, Seurat v5.5.1 tagged tutorial sources and rendered official pages with printed output. See `L1_cran2026-09-15/manifest.tsv`. |
| L2 | Seurat PBMC 3k guided clustering and SCTransform tutorials, both archived under L1 with versioned source and rendered page hashes. |
| L3 | Ten applicable tier-A close readings in `literature/l3_notes.md`. |
| L4 | Thirty licence-gated OA articles with PubMed efetch echo. **27/30 applicable**: 18 Seurat-only, nine mixed; two spatial-spot papers and one older t-SNE-only workflow excluded (all three carry the `seurat` label). |

## T -- table skeleton

- Per-cell cluster assignment table: cell ID, sample, assay/layer, normalization route, selected PCs, graph, resolution, algorithm and cluster label. Summarize cluster size by sample, with small clusters visible rather than silently omitted.
- HVG table: feature, mean/variance statistic and selected rank. A cluster marker table belongs to `seurat-markers`; cluster labels alone do not establish cell type or condition effects.

## F -- figure grammar

- PBMC tutorial: variable-feature scatter with top genes labelled; PCA loading/embedding views and elbow plot for dimension choice; UMAP 1/2 coloured by cluster, directly labelled where legible. State which graph/PC dimensions and resolution generated the colours.
- UMAP is a two-dimensional display of the high-dimensional graph solution. The tutorial cautions against biological conclusions from the display alone; cluster claims need marker and sample checks.

## W -- wording

- L3 wording pattern: identify the count matrix and Seurat version, normalization route, HVG count, PCA dimensions used for neighbours, graph and clustering algorithm/resolution, then UMAP inputs. Reports vary; an unreported argument remains unreported even if the locked function has a default.
- S2 Methods draft: “Counts were processed in Seurat <version> using <LogNormalize with scale factor / SCTransform settings>; <n> variable genes informed PCA. A neighbour graph on PCs <range> was clustered with <algorithm> at resolution <value>; UMAP used the stated reduction and seed.” Do not describe clusters as condition-level significance.

## V -- variant frequencies

Corpus composition: 21 articles labelled `seurat` and nine `mixed`; of these, **18 Seurat-only and nine mixed are applicable** (the three inapplicable articles are all `seurat`-labelled). Ecosystems are never pooled: the first table reports **Seurat-only counts / 18 applicable papers**, the second **mixed counts / 9 applicable papers**. Every count, including `Reported`, uses the applicable denominator of its ecosystem. A value is called a majority only if it exceeds half of that applicable denominator (more than 9/18, more than 4.5/9); otherwise the leading value is only the most common, and a value reported by one or two papers is never treated as a default.

Counting rules: when an article reports several analyses, the count uses its main analysis (first value in `extraction.jsonl`; the other values stay in the extraction row); values written differently (`0.10`/`0.1`, `first 40 PCs`/`1:40 PCs`/`40 PCs`) are counted once as the same value; a value that the paper states "as default" counts as reported.

| Parameter | Seurat-only values (count / 18 applicable) | Reported / 18 | Not reported / 18 |
|---|---|---:|---:|
| `normalization_route` | NormalizeData: 9; SCTransform: 4 (main route; seven papers name SCTransform somewhere, three of them only for an integration step or a secondary dataset) | 13 | 5 |
| `normalization_method` | LogNormalize (stated or described as total-count scaling plus log): 3; count-per-million: 1 | 4 | 14 |
| `scale_factor` | 10000: 2; 10^6 (count-per-million): 1 | 3 | 15 |
| `sct_variable_features_n` | none | 0 | 18 |
| `sct_vst_flavor` | v2 (cross-species arm only): 1 | 1 | 17 |
| `sct_vars_to_regress` | three different covariate sets (Ig V-gene variance; gene count, UMI count, mitochondrial and ribosomal percentages; DIG, Malat1, mitochondrial percentage and cell-cycle scores in a secondary re-processing): 1 each | 3 | 15 |
| `hvg_method` | vst: 4; mean.var.plot or mean/dispersion cut-offs: 2 | 6 | 12 |
| `hvg_n` | 2000: 6; 3000: 1; 4000 (integration features): 1 | 8 | 10 |
| `scale_vars_to_regress` | mitochondrial percentage (with UMI count in one): 2; cell-cycle scores (subclusters): 1 | 3 | 15 |
| `scale_center` | TRUE: 1 | 1 | 17 |
| `scale_scale` | TRUE: 2 | 2 | 16 |
| `pca_npcs` | 30: 2; 100: 1 | 3 | 15 |
| `pca_features` | variable/HVG features: 6 (one with TCR, mitochondrial and HLA genes removed) | 6 | 12 |
| `neighbor_dims` | 30 PCs: 3; 40 PCs: 3; 50 PCs: 1; 50 ICs: 1; 35 Harmony dimensions: 1; 25 WNN dimensions: 1; 16: 1; 15: 1 | 12 | 6 |
| `neighbor_k` | 20 (stated as default): 1 | 1 | 17 |
| `neighbor_prune` | none | 0 | 18 |
| `cluster_resolution` | 0.5: 3 (one of them a 0.5/1/2/3 series whose final integrated run used 0.5); 0.8: 2; 1: 2; 0.4, 0.6, 0.9, 1.3, 1.5 and 3: 1 each | 13 | 5 |
| `cluster_algorithm` | Louvain: 5; SLM: 1 | 6 | 12 |
| `cluster_seed` | none | 0 | 18 |
| `umap_dims` | 30: 2; 16 PCs, 20 Harmony dimensions, 25 WNN dimensions, 35 Harmony dimensions, 40 PCs and 50 ICs: 1 each | 8 | 10 |
| `umap_neighbors` | 30 (stated as Seurat v4 default): 1 | 1 | 17 |
| `umap_min_dist` | 0.3 (stated as Seurat v4 default): 1 | 1 | 17 |
| `umap_metric` | correlation (umap-learn): 1 | 1 | 17 |
| `umap_seed` | 42: 1 | 1 | 17 |
| `seurat_version` | major v4: 12 (4.3.0: 3; 4.0.3: 2; 4.0, 4.0.0, 4.0.2, 4.0.4, 4.0.6, 4.3 and 4.3.0.1: 1 each); major v3: 4 (3.1.1, 3.1.4, 3.1.5, 3.2.2); major v5: 1 (5.0.1) | 17 | 1 |

In the 18 applicable Seurat-only papers, NormalizeData is the most common main route (9/18, exactly half, so not a majority) and SCTransform is the main route in 4/18. Seven papers use SCTransform somewhere, three of them only for an integration step or a secondary dataset. The guided PBMC tutorial uses LogNormalize, and the separate SCTransform tutorial is the alternative. vst is the stated HVG method in 4/18 and 2,000 HVGs in 6/18; neither is a majority. No fixed cluster resolution is a majority: 0.5 is the most common main value (3/18), 0.8 and 1 appear in 2/18 each, and several studies report specimen-specific or repeated resolutions. Neighbour dimensions split between 30 and 40 PCs (3/18 each). Louvain is named in 5/18 and SLM in 1/18, and 12/18 do not name the algorithm. One paper (PMID 36517595) states UMAP n.neighbors 30 and min.dist 0.3 as Seurat v4 defaults, plus metric correlation with umap-learn and seed 42; the other 17/18 state none of these arguments. The only majority in the table is major Seurat version 4 (12/18); the most common exact version, 4.3.0, appears in 3/18. An unstated default is never counted as a paper-reported value.

| Parameter (mixed) | Mixed values (count / 9 applicable) | Reported / 9 | Not reported / 9 |
|---|---|---:|---:|
| `normalization_route` | NormalizeData or Seurat log-normalisation: 5; SCTransform: 2 | 7 | 2 |
| `normalization_method` | log-normalisation: 2 | 2 | 7 |
| `sct_variable_features_n` | 3000 (stated as default): 1 | 1 | 8 |
| `hvg_method` | vst: 2; mean.var.plot: 1 | 3 | 6 |
| `hvg_n` | 2000: 4 (in one only for two of its datasets); 1000: 1 | 5 | 4 |
| `pca_npcs` | 20: 2; 50: 1 | 3 | 6 |
| `pca_features` | variable/HVG features: 4 | 4 | 5 |
| `neighbor_dims` | 20 PCs: 2; 14 PCs: 1; 50 PCs: 1 | 4 | 5 |
| `cluster_resolution` | 0.8: 2; 0.4, 0.5, 0.65, 10 (Leiden) and a 0.1-6 search: 1 each | 7 | 2 |
| `cluster_algorithm` | Louvain: 5; Leiden (Louvain also run): 1 | 6 | 3 |
| `umap_dims` | 20 (PCs or Harmony components): 2 | 2 | 7 |
| `seurat_version` | major v3: 4 (v3, 3.1.4, 3.1.5, 3.2.2); major v4: 3 (4.1.0, 4.1.1, 4.2.0); major v5: 1 (5.3.0) | 8 | 1 |
| all other parameters | none | 0 | 9 |

The nine applicable mixed articles are tabulated separately and are not pooled into the Seurat-only counts. In each of them some front-end step runs outside Seurat. Three are benchmark or method papers that run several ecosystems' pipelines. Two use scran/scPipe or scDblFinder QC. Two use batchelor fastMNN integration. One uses DropletUtils and scvi-tools Solo for QC. One uses MultiMAP/Scrublet with a SCANPY benchmark arm. The per-article `_applies` notes give the step split. The corpus has no exclusively scverse or Bioconductor article.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 16, 10x PBMC 3k (F1); URL and sha256 are in the registry and `fetch_anchor_data.sh`. The 7,621,991-byte archive was downloaded and verified in this lane against sha256 `847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5`.
- The Seurat 5.5.1 guided page prints `FindNeighbors(dims=1:10)` then `FindClusters(resolution=0.5)`: **2,638 graph nodes, 95,927 edges, nine communities**, and first five identities `2, 3, 2, 1, 6`; UMAP uses dims 1:10. These are printed-value smoke candidates. S0 has no R replay, so the later container test must check whether the pinned package and dependencies reproduce them; if not, preserve the page as a workflow anchor and use a verified replay assertion.
- SCTransform tutorial uses `SCTransform(vars.to.regress="percent.mt")`, then uses RunPCA, `RunUMAP(dims=1:30)`, `FindNeighbors(dims=1:30)` and FindClusters. This is an alternative workflow, not a value to average with the LogNormalize path.

## D -- defaults: locked Seurat method / official tutorial / Seurat-only exemplars

The locked method defaults below come from `L1_cran2026-09-15/Seurat/defaults.tsv`, parsed from the `*.Seurat` Rd usages. Values in the exemplar column are explicit Methods reports, counted as in V: `n/18` = Seurat-only papers with that value / 18 applicable Seurat-only papers; the mixed set is given separately as `n/9` and is never pooled. "Majority" requires more than half of the applicable denominator; otherwise the leading value is only the "most common", and a value reported by one or two papers is not a default. No S1 default is frozen in this draft.

| Parameter | Function default (locked version) | Official tutorial | Exemplar evidence | S1 draft |
|---|---|---|---|---|
| `normalization_route` | `no single function default` | PBMC: NormalizeData; SCTransform tutorial alternative | Seurat-only: NormalizeData 9/18 (most common, not a majority), SCTransform 4/18 as main route (7/18 use it somewhere); mixed: NormalizeData/log-normalisation 5/9, SCTransform 2/9 | pending S1 |
| `normalization_method` | `LogNormalize` | LogNormalize | Seurat-only: LogNormalize 3/18, count-per-million 1/18; mixed: log-normalisation 2/9 | explicit value to be decided at S1 |
| `scale_factor` | `10000` | 10000 | Seurat-only: 10000 2/18, 10^6 (CPM) 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `sct_variable_features_n` | `3000` | default in SCTransform example | Seurat-only: 0/18; mixed: 3000 (stated default) 1/9 | explicit value to be decided at S1 |
| `sct_vst_flavor` | `v2` | v2 default; v1 alternative | Seurat-only: v2 1/18 (cross-species arm only); mixed: 0/9 | explicit value to be decided at S1 |
| `sct_vars_to_regress` | `NULL` | percent.mt | Seurat-only: three different covariate sets, 1/18 each; mixed: 0/9 | pending S1 |
| `hvg_method` | `vst` | vst | Seurat-only: vst 4/18 (most common), mean.var.plot-type 2/18; mixed: vst 2/9, mean.var.plot 1/9 | explicit value to be decided at S1 |
| `hvg_n` | `2000` | 2000 | Seurat-only: 2000 6/18 (most common), 3000 1/18, 4000 integration features 1/18; mixed: 2000 4/9, 1000 1/9 | explicit value to be decided at S1 |
| `scale_vars_to_regress` | `NULL` | PBMC example presents percent.mt regression as an optional variant | Seurat-only: mitochondrial percentage 2/18, cell-cycle scores 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `scale_center` | `TRUE` | not explicitly set | Seurat-only: TRUE 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `scale_scale` | `TRUE` | not explicitly set | Seurat-only: TRUE 2/18; mixed: 0/9 | explicit value to be decided at S1 |
| `pca_npcs` | `50` | not explicitly set | Seurat-only: 30 2/18, 100 1/18; mixed: 20 2/9, 50 1/9 | explicit value to be decided at S1 |
| `pca_features` | `NULL` | variable features | Seurat-only: variable/HVG features 6/18; mixed: 4/9 | explicit value to be decided at S1 |
| `neighbor_dims` | `1:10` | 1:10 PBMC; 1:30 SCTransform | Seurat-only: 30 PCs 3/18 and 40 PCs 3/18 (tied most common), six other values 1/18 each; mixed: 20 PCs 2/9, 14 and 50 PCs 1/9 each | pending S1 |
| `neighbor_k` | `20` | not explicitly set | Seurat-only: 20 (stated default) 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `neighbor_prune` | `1/15` | not explicitly set | Seurat-only: 0/18; mixed: 0/9 | explicit value to be decided at S1 |
| `cluster_resolution` | `0.8` | 0.5 PBMC; not explicitly set in SCTransform tutorial | Seurat-only: 0.5 3/18 (most common), 0.8 2/18, 1 2/18, six values 1/18 each; mixed: 0.8 2/9, five other values 1/9 each | pending S1 |
| `cluster_algorithm` | `1` | Louvain in PBMC example | Seurat-only: Louvain 5/18 (most common), SLM 1/18, 12/18 unstated; mixed: Louvain 5/9 (majority), Leiden 1/9 | explicit value to be decided at S1 |
| `cluster_seed` | `0` | not explicitly set | Seurat-only: 0/18; mixed: 0/9 | explicit value to be decided at S1 |
| `umap_dims` | `NULL` | 1:10 PBMC; 1:30 SCTransform | Seurat-only: 30 2/18, six other values 1/18 each; mixed: 20 2/9 | pending S1 |
| `umap_neighbors` | `30L` | not explicitly set | Seurat-only: 30 (stated as default) 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `umap_min_dist` | `0.3` | not explicitly set | Seurat-only: 0.3 (stated as default) 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `umap_metric` | `cosine` | not explicitly set | Seurat-only: correlation (umap-learn) 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `umap_seed` | `42L` | not explicitly set | Seurat-only: 42 1/18; mixed: 0/9 | explicit value to be decided at S1 |
| `seurat_version` | `Seurat 5.5.1 locked` | 5.5.1 page header | Seurat-only: major v4 12/18 (majority), exact 4.3.0 3/18 (most common), v3 4/18, v5 1/18; mixed: v3 4/9, v4 3/9, v5 1/9 | explicit value to be decided at S1 |

## X -- version-sensitive behaviour

- SeuratObject 5.0 introduced `Assay5` layers, and Seurat 5.0 merges samples into layers rather than one combined counts matrix; the selected assay/layer must be explicit before normalization or integration.
- Seurat 5.0.1 fixed forwarding extra `SCTransform.StdAssay` arguments to `sctransform::vst`; Seurat 5.2.0 changed the Leiden backend to `leidenbase` and reset a nonpositive Leiden seed to 1. Older exemplar calls can yield different clusters.
- Seurat 5.5.0 fixed factor-level ordering and graph-neighbour list handling; 5.5.1 added `uwot.init` to RunUMAP and fixed metadata setting when FindClusters receives multiple resolutions plus a custom cluster name. These are from the archived NEWS, not inferred from paper dates.

## S1 drafts and pending decisions

- P-1 Normalization route: guided PBMC tutorial uses LogNormalize and 2,000 HVGs; among the 18 applicable Seurat-only papers NormalizeData is the main route in nine (half, not a majority) and SCTransform in four, while seven use SCTransform somewhere (three only for integration or a secondary dataset) and five name no route. Draft: offer named LogNormalize and SCTransform workflows, choose by input/study purpose and record the route; owner decides the standard entry.
- P-2 Cluster granularity and dimensions: the function defaults are 0.8 resolution and 1:10 neighbour dims; PBMC tutorial uses 0.5 and 1:10; exemplar resolutions and dimensions vary. Draft: show multiple prespecified resolutions and stability/marker diagnostics, then commit one before downstream marker interpretation. Owner chooses the standard preset and any size-dependent rule.
- P-3 Randomness and UMAP: `FindClusters(random.seed=0)` and `RunUMAP(seed.use=42L)` are locked defaults; arguments must be explicit in S2. Draft: define one suite seed and record graph/UMAP backend, PC choice, numerical tolerances and BLAS/thread settings before goldens.
- P-4 Mixed workflows: nine applicable papers run part of the front end outside Seurat or compare pipelines across ecosystems. Preserve their ecosystem label and do not import their parameter counts into the Seurat-only default. The method-paper and spatial negative cases are useful router checks.
