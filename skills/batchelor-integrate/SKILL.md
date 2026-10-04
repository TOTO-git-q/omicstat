---
name: batchelor-integrate
description: "Run batchelor-integrate using the locked official community workflow and save native results, CSV tables, diagnostic figures and SCE handoff. Triggers: batchelor-integrate, SingleCellExperiment, 单细胞. For condition inference use muscat-pseudobulk; for GSVA use gsva-score."
---
# batchelor-integrate
## Input and run
Run `Rscript scripts/run_batchelor_integrate.R --help` in omicstat-r:2026.10.1. Supply a local SCE RDS or `--from-run` upstream with normalized logcounts. Bioconductor front ends require scater-qc state; scoring accepts explicit conversion through convert.R. Native errors are retained in the engine log.
## Options
[options.md](references/options.md) lists every CLI option, locked values, official examples and S0 parameter keys. Supplementary JSON options pass directly to package functions. All seeds are explicit. `--spec` replays resolved options.
Batch definition, HVG count, correction rank/neighbours and plotting dimensions require explicit input. Vignette correction.Rmd uses 5000 HVGs and native d=50/k=20; smaller values are useful for small diagnostics, larger ranks retain more variation. Assess biology preservation separately from batch mixing. Integration never establishes condition effects; marker input stays original logcounts. Native multiBatchNorm and fastMNN options are exposed, including merge.order via --mnn-args.
## Scientific choices and reference service
Before choosing `--batch-col`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. batch metadata column; scientific batch definition.
Before choosing `--n-hvg`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. HVG number; correction vignette example 5000.
Before choosing `--n-pcs`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. fastMNN rank; locked default 50, explicit study choice.
Before choosing `--mnn-k`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. MNN neighbours; locked default 20.
Before choosing `--umap-dims`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. corrected dimensions for UMAP.
Before choosing `--umap-neighbors`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. UMAP neighbours; locked default 15.
Before choosing `--mixing-k`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. neighbours for descriptive batch purity.
Before choosing `--cos-norm`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. cosine normalization.
Before choosing `--ndist`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. MNN distance cutoff.
Before choosing `--auto-merge`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. automatically select merge order.
Before choosing `--umap-min-dist`, call `reference_advise(module="batchelor-integrate", ...)` and `reference_search` for published practice. If nothing is curated, show the locked vignette example and ask the user. uwot locked minimum distance.

## Outputs and interpretation
Native RDS objects in objects/, full native CSV tables in tables/, suite PNG/PDF/figure_spec files in figures/, captured warnings in qc/, actual package versions, functions and option values in draft/methods_results.md, provenance/resolved_spec.json, and objects/handoff.json. Read warning logs before interpreting results. Figures are descriptive.
## 待裁决 / limitations
Batch definition, HVG count, correction rank/neighbours and plotting dimensions require explicit input. Vignette correction.Rmd uses 5000 HVGs and native d=50/k=20; smaller values are useful for small diagnostics, larger ranks retain more variation. Assess biology preservation separately from batch mixing. Integration never establishes condition effects; marker input stays original logcounts. Native multiBatchNorm and fastMNN options are exposed, including merge.order via --mnn-args.
S2 build awaits independent S3. No acceptance or installation is claimed.
