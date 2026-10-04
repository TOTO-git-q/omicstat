---
name: scater-qc
description: Generate scater-qc tables, diagnostic figures and a checked single-cell handoff. Triggers include scater-qc, SingleCellExperiment, 单细胞 and 生信. Use only for this module's documented analysis. For condition inference use muscat-pseudobulk; for GSVA use gsva-score.
---
# scater-qc
## When to use / when not
Use for the analysis in method-basis.md. Follow the declared ecosystem and chain state. See Known limitations for scope boundaries.
## Input requirements
Local SCE RDS with unique cell/feature IDs, raw integer counts, declared species/ID namespace and the required chain state. --from-run verifies every hash and propagates the contract and upstream chain. Raw-input paths never bypass object-state validation.
## Run
Run `Rscript scripts/run_scater_qc.R --help` in `omicstat-r:2026.10.1`. Supply the required choices in [parameters.md](references/parameters.md). --spec replays the resolved command and explicit flags override it.
## What gets produced
Full tables under tables/, PDF and PNG figures with captions/figure_spec under figures/, QC rules and captured warnings under qc/, Methods/Results under draft/, results JSON, provenance/resolved_spec.json, and objects/handoff.json with SCE and colour registry.
## Reading the results
Read QC first, then the complete tables and figure captions. Check that choices and input sizes agree with the study. No automatic condition inference is performed.
## When a QC rule fires
Typed input/blocking errors withhold estimation. Read qc/engine_warnings.csv for package warnings. See [qc-rules.md](references/qc-rules.md) and [troubleshooting.md](references/troubleshooting.md).
## Known limitations
待裁决: QC thresholds and mitochondrial feature annotation require explicit input. MAD directions follow perCellQCFilters (lower log2 totals and detected counts; higher untransformed subset percentages). Fixed thresholds are supplied by the user. Compatibility calls are deprecated in scuttle 1.22.0; scrapper is absent in the locked image. No doublet detection or removal.
S2 handover awaits independent S3; no acceptance or installation is claimed.
## Reference files
[method-basis.md](references/method-basis.md), [parameters.md](references/parameters.md), [qc-rules.md](references/qc-rules.md), [reporting-templates.md](references/reporting-templates.md), [troubleshooting.md](references/troubleshooting.md).

## Judgement options and reference service
Before choosing each of `--qc-mode`, `--nmads`, `--min-counts`, `--min-features`, `--max-mito`, `--batch-col` and `--mt-genes`, call `reference_advise(module='scater-qc', ...)` and `reference_search`. If nothing is curated, show the scuttle userguide example (`nmads=3`) and ask the user. Fixed cutoffs depend on tissue and chemistry; batch grouping suits differing library characteristics.
`--metrics-args` and `--filter-args`: named JSON objects exposing supplementary native arguments such as `percent.top`, `threshold`, `use.altexps`, `share.medians`, `share.mads`, `share.missing`, `min.diff`. Omitted entries use locked function defaults; primary CLI flags take precedence. See [options.md](references/options.md).
