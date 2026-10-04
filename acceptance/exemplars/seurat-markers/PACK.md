# PACK -- seurat-markers

Status: S0 evidence collected; S1 decisions drafted, not frozen. This lane writes no `verification.json`.

| Layer | Evidence |
|---|---|
| L1 | Locked CRAN 2026-09-15: Seurat 5.5.1, SeuratObject 5.4.0; `FindAllMarkers` and `FindMarkers` generic/S3 Rd, method defaults, NEWS, CITATION/DESCRIPTION, tagged PBMC tutorial source and rendered guide. Manifest hashes in `L1_cran2026-09-15/manifest.tsv`. |
| L2 | Official Seurat PBMC guided clustering tutorial archived under L1. |
| L3 | Ten applicable close readings in `literature/l3_notes.md`. |
| L4 | Thirty licence-gated OA papers with PubMed efetch echo; 29 applicable: 22 Seurat-only, six mixed, one Bioconductor front end (Seurat used only for markers). One reference-signature-only spatial-deconvolution paper (38110959, mixed) excluded. |

## T -- table skeleton

- One row per cluster and gene: cluster/contrast identity, assay and slot/layer, test, `avg_log2FC`, `pct.1`, `pct.2`, raw and adjusted P, direction, cells per group and gene universe. Keep all tested genes available alongside any display-filtered top markers.
- Cluster-versus-rest marker tables describe cell identities. Condition-level inference needs a separate replicate-aware design, such as pseudobulk; a cell-count P value is not a biological-replicate P value.

## F -- figure grammar

- PBMC guide shows violin, feature and dot plots for selected marker genes and a heatmap of the top ten markers per cluster. Colour and facet by the cluster comparison; show sample distribution when interpreting small clusters. State assay/slot and which filtering created the plotted top list.
- Heatmap colour represents expression, not a hypothesis-test result. Link each displayed gene back to the full marker table and its effect estimate.

## W -- wording

- State whether each call is `FindAllMarkers` cluster-versus-rest or `FindMarkers` between named identities, and distinguish function screening (`min.pct`, `logfc.threshold`) from posthoc reporting (`p_val_adj`, effect and detection thresholds). Report test and adjustment method only when Methods explicitly gives them.
- S2 draft: “Markers for cluster <id> were screened with Seurat <version> on <assay/slot> using <function/test>, contrasting <identities>. We used <screening arguments> and retained <posthoc criteria>; per-cluster cell and gene counts and adjusted P were exported.” State separately if a condition contrast or pseudobulk test was run.

## V -- variant frequencies

Corpus composition after the S0 redo re-read: 29 of 30 papers apply; the front-end ecosystem of the applicable papers is Seurat in 22, mixed in six and Bioconductor in one (41469724: scran/scater front end, Seurat only for the marker calls); none is scverse-only. The one inapplicable paper (38110959, mixed) uses Seurat to pick reference genes for spatial deconvolution without naming a marker call. Denominators are **applicable articles of each ecosystem** (22, six and one); ecosystems are never pooled. `Reported` counts literal Methods values, including explicit posthoc filters and screening rules stated in words ("we tested only genes detected in ..." counts as `min_pct`/`logfc_threshold`); unreported function arguments are not filled from defaults. Where a paper states several calls, the extraction lists the cluster-marker value first and other in-scope calls (FindMarkers condition or subset contrasts, a second FindAllMarkers call) after it; the tables count the first-listed value and flag papers whose only value comes from such a secondary call. Identical numbers written differently (`0.10`/`0.1`) are counted once; percentages are kept as printed.

### Seurat-only (22 applicable)

| Parameter | Reported values and paper counts | Reported / 22 | Not reported / 22 |
|---|---|---:|---:|
| `test` | Wilcoxon: 7; MAST: 3 (one from a FindMarkers contrast only); DESeq2: 2 (one FindMarkers-only call, one on aggregated counts) | 12/22 | 10/22 |
| `min_pct` | 0.25: 5; 0.1: 3 (one from a second DEG call only); 0.05: 1; 15%: 1; 30%: 1; 40%: 1 | 12/22 | 10/22 |
| `logfc_threshold` | 0.25: 7; 0.5: 1; 0: 1 | 9/22 | 13/22 |
| `only_pos` | TRUE: 3; FALSE: 1 (second FindAllMarkers call only) | 4/22 | 18/22 |
| `max_cells_per_ident` | none | 0/22 | 22/22 |
| `min_cells_feature` | none | 0/22 | 22/22 |
| `min_cells_group` | none | 0/22 | 22/22 |
| `assay` | RNA: 1 (second FindAllMarkers call only); pre-integration (unintegrated) data: 1 | 2/22 | 20/22 |
| `slot` | log-normalised data, described in words: 2 | 2/22 | 20/22 |
| `ident_1` | none | 0/22 | 22/22 |
| `ident_2` | none | 0/22 | 22/22 |
| `group_by` | none | 0/22 | 22/22 |
| `latent_vars` | batch as random effect: 1 (genotype FindMarkers only) | 1/22 | 21/22 |
| `p_adjust_method` | Bonferroni: 2; Benjamini–Hochberg FDR: 1 (DESeq2 aggregated counts) | 3/22 | 19/22 |
| `padj_cutoff` | 0.05: 5 (one from enrichment-input DEGs only); 0.01: 3 | 8/22 | 14/22 |
| `logfc_filter` | 0.5: 3 (one from enrichment-input DEGs only); 0.25: 2; 0.1: 1; 2x fold: 1 | 7/22 | 15/22 |
| `min_pct_filter` | 25%: 1; 10%: 1 | 2/22 | 20/22 |
| `seurat_version` | 4.3.0: 7; 4.2.0: 1; 4.0.6: 1; 4.0.3: 1; 4.0: 1; v4: 1; 5.0.1: 1; 5.3.1: 1; 3.2.2: 1; 3.1.5: 1; 3.1.4: 1; v3: 1; 2.3.4: 1 | 19/22 | 3/22 |
| `min_diff_pct` | 0.25: 1 | 1/22 | 21/22 |
| `return_thresh` | 1: 1 | 1/22 | 21/22 |
| `base` | none | 0/22 | 22/22 |
| `features` | none | 0/22 | 22/22 |
| `random_seed` | none | 0/22 | 22/22 |
| `mean_fxn` | none | 0/22 | 22/22 |
| `node` | none | 0/22 | 22/22 |
| `reduction` | none | 0/22 | 22/22 |
| `subset_ident` | none | 0/22 | 22/22 |
| `fc_slot` | none | 0/22 | 22/22 |
| `pseudocount_use` | none | 0/22 | 22/22 |
| `norm_method` | none | 0/22 | 22/22 |
| `recorrect_umi` | none | 0/22 | 22/22 |

### Mixed (six applicable)

| Parameter | Reported values and paper counts | Reported / 6 | Not reported / 6 |
|---|---|---:|---:|
| `test` | Wilcoxon: 2; MAST: 1 (FindMarkers DEA only) | 3/6 | 3/6 |
| `min_pct` | 0.25: 1 | 1/6 | 5/6 |
| `logfc_threshold` | 0.25: 1 | 1/6 | 5/6 |
| `only_pos` | TRUE: 1 | 1/6 | 5/6 |
| `max_cells_per_ident` | none | 0/6 | 6/6 |
| `min_cells_feature` | none | 0/6 | 6/6 |
| `min_cells_group` | none | 0/6 | 6/6 |
| `assay` | none | 0/6 | 6/6 |
| `slot` | none | 0/6 | 6/6 |
| `ident_1` | 3D: 1 (FindMarkers contrast) | 1/6 | 5/6 |
| `ident_2` | 2D: 1 (FindMarkers contrast) | 1/6 | 5/6 |
| `group_by` | none | 0/6 | 6/6 |
| `latent_vars` | line: 1 (FindMarkers contrasts) | 1/6 | 5/6 |
| `p_adjust_method` | Bonferroni: 3 (two from FindMarkers DEGs only) | 3/6 | 3/6 |
| `padj_cutoff` | 0.01: 2 (one from FindMarkers DEGs only); 0.05: 2 | 4/6 | 2/6 |
| `logfc_filter` | 0.25: 2 (one from FindMarkers DEGs only); 1: 1 (FindMarkers DEGs only) | 3/6 | 3/6 |
| `min_pct_filter` | 25%: 1 | 1/6 | 5/6 |
| `seurat_version` | 4.3.0.1: 1; 4.2.0 (with 5.0.3 in a second cohort): 1; 4.0.6: 1; 3.2.2: 1; V3: 1 | 5/6 | 1/6 |
| `min_diff_pct` | none | 0/6 | 6/6 |
| `return_thresh` | none | 0/6 | 6/6 |
| `base` | none | 0/6 | 6/6 |
| `features` | none | 0/6 | 6/6 |
| `random_seed` | none | 0/6 | 6/6 |
| `mean_fxn` | none | 0/6 | 6/6 |
| `node` | none | 0/6 | 6/6 |
| `reduction` | none | 0/6 | 6/6 |
| `subset_ident` | none | 0/6 | 6/6 |
| `fc_slot` | none | 0/6 | 6/6 |
| `pseudocount_use` | none | 0/6 | 6/6 |
| `norm_method` | none | 0/6 | 6/6 |
| `recorrect_umi` | none | 0/6 | 6/6 |

### Bioconductor front end (one applicable)

| Parameter | Reported values and paper counts | Reported / 1 | Not reported / 1 |
|---|---|---:|---:|
| `test` | Wilcoxon: 1 | 1/1 | 0/1 |
| `group_by` | treatment: 1 (FindMarkers condition contrast only) | 1/1 | 0/1 |
| `padj_cutoff` | 1E-05: 1 | 1/1 | 0/1 |
| `logfc_filter` | 2.0: 1 | 1/1 | 0/1 |
| `min_pct_filter` | 25%: 1 | 1/1 | 0/1 |
| `seurat_version` | 5.0.1: 1 | 1/1 | 0/1 |
| all other 25 parameters | none | 0/1 | 1/1 |

No parameter value reaches a majority (more than half) of the 22 Seurat-only papers: the most common test is Wilcoxon (7/22; MAST 3/22), the most common `min.pct` is 0.25 (5/22), the most common `logfc.threshold` is 0.25 (7/22) and the most common version is 4.3.0 (7/22), while Seurat versions are stated in 19/22 papers and range from 2.3.4 to 5.3.1. `only.pos=TRUE` is stated in 3/22. In the six mixed papers no value is shared by more than three papers (Bonferroni 3/6 is exactly half, not a majority); Wilcoxon is the most common named test (2/6). One Seurat-only paper uses DESeq2 on aggregated counts through its marker step, so it cannot be imported as a Seurat function default. Several reported P/effect cutoffs are posthoc display filters or belong to FindMarkers condition contrasts, not to the cluster-marker call. The corpus has no exclusively scverse article; Pegasus, Cobolt, pagoda2/Conos and scanpy occur in mixed workflows; ArchR (RNA QC plus ATAC) and Python velocity tools (scVelo, CellRank, scanpy/dynamo) appear in Seurat-only papers only as neutral, other-modality or downstream tooling.

## C -- anchors

- `acceptance/data/ANCHOR_REGISTRY.md` row 18 uses 10x PBMC 3k F1 from the official Seurat guided tutorial. The same 7,621,991-byte archive was downloaded and SHA256-verified for `seurat-qc`/`seurat-cluster`; `fetch_anchor_data.sh` retains its URL and expected hash `847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5`.
- The versioned PBMC guide calls `FindMarkers(pbmc, ident.1=2)` and `FindAllMarkers(pbmc, only.pos=TRUE)`, then plots top markers. The rendered page's marker rows are smoke candidates pending a locked-image replay; no numerical golden is claimed at S0.

## D -- locked function default / official guide / Seurat-only exemplars

Defaults below are from the archived Seurat 5.5.1 Rd, including `FindMarkers.Seurat`, `.default`, `.Assay`, `.SCTAssay` and `.DimReduc`. `FindMarkers.Seurat` delegates many arguments to its assay method. The guide column is an example, not a binding rule.

| Parameter | Function default (locked version) | Official guide | Seurat-only exemplar evidence | S1 draft |
|---|---|---|---|---|
| `test` | `test.use="wilcox"` | PBMC `FindAllMarkers` default Wilcoxon; a separate ROC example | Wilcoxon: 7; MAST: 3; 2 in other values (12/22 applicable; 10/22 not reported) | pending S1 |
| `min_pct` | `min.pct=0.01` | PBMC guide names it as a speed/filter control, no fixed value | 0.25: 5; 0.1: 3; 4 in other values (12/22 applicable; 10/22 not reported) | pending S1 |
| `logfc_threshold` | `logfc.threshold=0.1` | PBMC ROC example sets 0.25 | 0.25: 7; 2 in other values (9/22 applicable; 13/22 not reported) | pending S1 |
| `only_pos` | `only.pos=FALSE` | PBMC `FindAllMarkers(only.pos=TRUE)` | TRUE: 3; FALSE (second call only): 1 (4/22 applicable; 18/22 not reported) | pending S1 |
| `max_cells_per_ident` | `max.cells.per.ident=Inf` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `min_cells_feature` | `min.cells.feature=3` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `min_cells_group` | `min.cells.group=3` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `assay` | `FindAllMarkers(assay=NULL)`; `FindMarkers.Seurat(assay=NULL)` | not explicitly set | RNA (second call only): 1; pre-integration data: 1 (2/22 applicable; 20/22 not reported) | pending S1 |
| `slot` | `slot="data"` | not explicitly set | log-normalised data described in words: 2 (2/22 applicable; 20/22 not reported) | pending S1 |
| `ident_1` | `FindMarkers.Seurat(ident.1=NULL)` | PBMC compares cluster 2, then cluster 5 | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `ident_2` | `FindMarkers.Seurat(ident.2=NULL)` | PBMC compares cluster 5 against 0 and 3 in another call | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `group_by` | `group.by=NULL` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `latent_vars` | `latent.vars=NULL` | not explicitly set | batch as random effect, FindMarkers contrast only: 1 (1/22 applicable; 21/22 not reported) | pending S1 |
| `p_adjust_method` | Bonferroni adjusted P in Seurat Rd result table | not explicitly set | Bonferroni: 2; 1 in other values (3/22 applicable; 19/22 not reported) | pending S1 |
| `padj_cutoff` | no posthoc default; `FindAllMarkers(return.thresh=0.01)` controls returned rows | not explicitly set | 0.05: 5; 0.01: 3 (8/22 applicable; 14/22 not reported) | pending S1 |
| `logfc_filter` | no separate posthoc default | not explicitly set | 0.5: 3; 0.25: 2; 2 in other values (7/22 applicable; 15/22 not reported) | pending S1 |
| `min_pct_filter` | no separate posthoc default | not explicitly set | 25%: 1; 10%: 1 (2/22 applicable; 20/22 not reported) | pending S1 |
| `seurat_version` | locked Seurat 5.5.1 | tagged v5.5.1 source and rendered guide | 4.3.0: 7; 12 in other values (19/22 applicable; 3/22 not reported) | pending S1 |
| `min_diff_pct` | `min.diff.pct=-Inf` | not explicitly set | 0.25: 1 (1/22 applicable; 21/22 not reported) | pending S1 |
| `return_thresh` | `FindAllMarkers(return.thresh=0.01)` | PBMC leaves it at the function default | 1: 1 (1/22 applicable; 21/22 not reported) | pending S1 |
| `base` | `base=2` for `FindAllMarkers` and Assay FC | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `features` | `features=NULL` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `random_seed` | `random.seed=1` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `mean_fxn` | `FindAllMarkers(mean.fxn=NULL)`; `FindMarkers.DimReduc(rowMeans)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `node` | `FindAllMarkers(node=NULL)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `reduction` | `FindMarkers.Seurat(reduction=NULL)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `subset_ident` | `FindMarkers.Seurat(subset.ident=NULL)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `fc_slot` | `FindMarkers.Assay(fc.slot="data")` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `pseudocount_use` | `FindMarkers.Assay(pseudocount.use=1)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `norm_method` | `FindMarkers.Assay(norm.method=NULL)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |
| `recorrect_umi` | `FindMarkers.SCTAssay(recorrect_umi=TRUE)` | not explicitly set | none (0/22 applicable; 22/22 not reported) | pending S1 |

## X -- version-sensitive behaviour

- Seurat v5 uses assay layers (`Assay5`) and the selected assay/slot must be named; tests requiring counts can override a requested `slot` to `counts` according to the locked Rd.
- The Seurat 5.5.1 tutorial says `presto` accelerates Wilcoxon for large datasets. A backend change may alter performance and possibly tie handling; S2 should replay outputs on the locked image.
- Seurat NEWS records changes to differential expression across v5 releases. Paper version strings range from 2.3.4 to 5.3.1 (Seurat-only papers) and include major-version-only statements (v3, V3, v4); reported arguments are evidence of those papers, not proof that the locked 5.5.1 defaults match historic runs.

## S1 drafts and pending decisions

- P-1 Select the standard cluster-marker test and explicit screening (`min.pct`, `logfc.threshold`, `only.pos`) after reviewing the limited reporting denominator and the official PBMC example. Preserve alternative MAST/ROC routes as named options.
- P-2 Freeze the assay/layer, identity comparison, adjustment and posthoc table filters separately. `FindAllMarkers(return.thresh)` changes returned rows; retain a full tested-gene table for audit.
- P-3 State prominently that cluster marker P values are descriptive for cell identities. Route condition-level inference to a replicate-aware method, not to this table.
- P-4 Replay the PBMC anchor under pinned Seurat and SeuratObject versions, then decide stable marker-row and plot smoke assertions.
