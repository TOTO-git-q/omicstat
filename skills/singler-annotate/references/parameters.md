# Parameters

Defaults follow locked function formals; the official single-cell reference vignette recommends `--de-method wilcox`. No atlas is selected automatically. Input paths and scientific reference choice are explicit.

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--input` | none | path | Clustered SCE/Seurat RDS or h5ad |
| `--from-run` | none | path | Verified handoff; exclusive with input |
| `--object-name` | none | string | Required when multiple upstream single-cell objects |
| `--cluster-col` | required | string | Carry source clusters unchanged |
| `--counts-layer` | none | string | Explicit raw count layer mapping |
| `--logcounts-layer` | none | string | Explicit normalized layer mapping |
| `--source-assay` | none | string | Required for Seurat |
| `--ecosystem` | none | seurat, bioconductor, scverse | Required for direct input; preserve chain ecosystem |
| `--outdir` | required | path | Output directory |
| `--spec` | none | path | Resolved replay |
| `--seed` | 20260925 | integer | Randomness lock |
| `--journal` | nature | nature, cell, science, generic | Shared figure style |
| `--reference` | required | path | Labelled SCE with normalized logcounts |
| `--reference-name` | required | string | Reference identity |
| `--reference-version` | required | string | Reference release/date; hash recorded |
| `--species` | required | string | User declares compatible species |
| `--reference-label-col` | required | string | Observed reference labels |
| `--unit` | cell | cell, cluster | SingleR clusters=NULL; D-SR3 |
| `--test-role` | logcounts | logcounts, counts | D-SR4; source role explicitly mapped |
| `--de-method` | classic | classic, wilcox, t | Locked default; wilcox recommended for single-cell reference, D-SR5 |
| `--de-n` | none | positive integer | Locked NULL adaptive marker count, D-SR12 |
| `--aggr-ref` | false | false, true | Locked FALSE, D-SR13 |
| `--fine-tune` | true | false, true | D-SR6 |
| `--quantile` | 0.8 | 0 to 1 | D-SR15 |
| `--tune-thresh` | 0.05 | 0 to 1 | D-SR16 |
| `--nmads` | 3 | 0 to 100 | PruneScores locked default, D-SR8 |
| `--help` | off | switch | List every option |

## Fixed arguments (generated from calls_registry.json)

| Function | Argument | Value | Locked default | Source |
|---|---|---|---|---|
| `SingleR::SingleR` | `test` | `input SCE` | `` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `ref` | `reference SCE` | `` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `labels` | `reference-label-col` | `` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `method` | `NULL` | `NULL` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `clusters` | `NULL (cell); cluster-col (cluster)` | `NULL` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `genes` | `"de"` | `"de"` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `sd.thresh` | `1` | `1` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `de.method` | `classic` | `"classic"` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `de.n` | `None` | `NULL` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `de.args` | `list()` | `list()` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `aggr.ref` | `False` | `FALSE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `aggr.args` | `list()` | `list()` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `recompute` | `TRUE` | `TRUE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `restrict` | `NULL` | `NULL` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `hint.sce` | `TRUE` | `TRUE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `quantile` | `0.8` | `0.8` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `fine.tune` | `True` | `TRUE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `tune.thresh` | `0.05` | `0.05` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `fine.tune.combined` | `True` | `fine.tune` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `prune` | `TRUE` | `TRUE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `assay.type.test` | `logcounts` | `"logcounts"` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `assay.type.ref` | `"logcounts"` | `"logcounts"` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `check.missing.test` | `True` | `FALSE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `check.missing.ref` | `True` | `check.missing` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `check.missing` | `TRUE` | `TRUE` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `num.threads` | `1` | `1` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `BNPARAM` | `NULL` | `NULL` | PACK D; container formals 2026-10-01 |
| `SingleR::SingleR` | `BPPARAM` | `BiocParallel::SerialParam()` | `NULL` | PACK D; container formals 2026-10-01 |
| `SingleR::pruneScores` | `results` | `` | `` | PACK D; container formals 2026-10-01 |
| `SingleR::pruneScores` | `nmads` | `3` | `3` | PACK D; container formals 2026-10-01 |
| `SingleR::pruneScores` | `min.diff.med` | `-Inf` | `-Inf` | PACK D; container formals 2026-10-01 |
| `SingleR::pruneScores` | `min.diff.next` | `0` | `0` | PACK D; container formals 2026-10-01 |
| `SingleR::pruneScores` | `get.thresholds` | `FALSE` | `FALSE` | PACK D; container formals 2026-10-01 |

## 待裁决

Reference selection, reference species compatibility, and aggregation for a large atlas need user scientific input. No automatic atlas selection. Python front end feeding R: preserve upstream ecosystem and flag crossing until owner decision. PlotScoreHeatmap score-heatmap grammar is rendered through shared figure code; exact native scaling comparison is pending; native pheatmap output is not a publication renderer.
