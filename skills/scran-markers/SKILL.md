---
name: scran-markers
description: "Run scran-markers using the locked official community workflow and save native results, CSV tables, diagnostic figures and SCE handoff. Triggers: scran-markers, SingleCellExperiment, 单细胞. For condition inference use muscat-pseudobulk; for GSVA use gsva-score."
---
# scran-markers
## Input and run
Run `Rscript scripts/run_scran_markers.R --help` in omicstat-r:2026.10.1. Supply a local SCE RDS or `--from-run` upstream with normalized logcounts. Bioconductor front ends require scater-qc state; scoring accepts explicit conversion through convert.R. Native errors are retained in the engine log.
## Options
[options.md](references/options.md) lists every CLI option, locked values, official examples and S0 parameter keys. Supplementary JSON options pass directly to package functions. All seeds are explicit. `--spec` replays resolved options.
This module describes cluster markers; condition effects require muscat-pseudobulk. Native scoreMarkers has effect summaries and no P values. --route findMarkers exposes the deprecated compatibility path and its native P values. Ranking column and plotted top-N are required display choices; no significance filtering is performed. Owner item: whether six non-cluster studies belong in the S0 corpus remains unresolved.
## Scientific choices and reference service
Before choosing `--cluster-col`, call `reference_advise(module="scran-markers", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. cluster metadata; example colLabels in locked Rd.
Before choosing `--lfc`, call `reference_advise(module="scran-markers", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. native effect threshold; no display-only filtering.
Before choosing `--block-col`, call `reference_advise(module="scran-markers", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. optional blocking column.
Before choosing `--rank-by`, call `reference_advise(module="scran-markers", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. native ranking column; recommend mean.AUC for scoreMarkers or summary.logFC for findMarkers; FDR ranking is ranking, not significance.
Before choosing `--top-n`, call `reference_advise(module="scran-markers", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. display genes per cluster; S0 examples 10 or 100.

## Outputs and interpretation
Native RDS objects in objects/, full native CSV tables in tables/, suite PNG/PDF/figure_spec files in figures/, captured warnings in qc/, actual package versions, functions and option values in draft/methods_results.md, provenance/resolved_spec.json, and objects/handoff.json. Read warning logs before interpreting results. Figures are descriptive.
## 待裁决 / limitations
This module describes cluster markers; condition effects require muscat-pseudobulk. Native scoreMarkers has effect summaries and no P values. --route findMarkers exposes the deprecated compatibility path and its native P values. Ranking column and plotted top-N are required display choices; no significance filtering is performed. Owner item: whether six non-cluster studies belong in the S0 corpus remains unresolved.
S2 build awaits independent S3. No acceptance or installation is claimed.

Marker grouping must vary within at least one biological sample. Sample identity and sample-level condition/donor/batch/time columns are refused with OS_PSEUDOREPLICATION; use muscat-pseudobulk for expression and speckle-propeller for proportions. Without sample information, only the upstream chain cluster column is allowed.
`--sample-col` defaults to `sample`; supply the actual biological sample column when named differently. Blocking on sample with `--block-col` remains allowed.

XM-01 warns when at least 90% of findMarkers rows have FDR < 0.05 or at least 10,000 cells are present: "cell-level P values are near zero for most genes; read effect sizes." scoreMarkers introduces no P values.
