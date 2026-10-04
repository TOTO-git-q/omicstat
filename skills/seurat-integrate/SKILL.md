---
name: seurat-integrate
description: >
  Run seurat-integrate and produce audited single-cell tables, figures and a Methods/Results draft.
  Use for Seurat integrate, 单细胞, 质控, 聚类, 整合, marker or 模块打分 as appropriate.
  NOT for condition-level differential inference (use muscat-pseudobulk) or a Bioconductor front end (use scater-qc or scran-cluster).
---
# seurat-integrate

## When to use / when not
Use for the integrate stage of a Seurat chain. Keep one front-end ecosystem. Condition inference uses muscat-pseudobulk; cell proportions use speckle-propeller.

## Input requirements
QC receives raw integer counts; other modules receive --from-run from seurat-qc / seurat-cluster as applicable, or an unmodified Seurat RDS carrying the same chain state. Cell/sample identifiers must match exactly.

## Run
```bash
Rscript scripts/run_seurat_integrate.R --help
```
Supply --input or the supported --from-run and --outdir plus required scientific parameters listed in references/parameters.md. --spec replays resolved parameters; explicit flags override it. MCP registration awaits independent S3.

## What gets produced
Tables under tables/, standard PDF/PNG figures with captions and figure_spec, draft/methods_results.md, qc/qc_results.csv, qc/engine_warnings.csv, results/results.json, provenance/resolved_spec.json and objects/handoff.json with hashed Seurat, cell metadata and colour registry.

## Reading the results
Read QC and the full audited tables first. Descriptive cell-level results do not establish condition differences. Every threshold and input state is recorded in the draft and provenance.

## When a QC rule fires
Rules SI-01..03 are sourced in references/qc-rules.md. Input blockers stop before a draft.

## Known limitations
Independent S3 acceptance is pending. No automatic doublet removal, annotation, gene synonym lookup, gene-set thresholding or condition inference. Scientific thresholds and dimensions need explicit prespecification. Spatial scoring applicability is an owner evidence question, not an inferred suite policy.

## Reference files
See references/method-basis.md, parameters.md, qc-rules.md, reporting-templates.md and troubleshooting.md.

## Choosing options / 待裁决

Choose RunHarmony to wrap the Harmony Seurat-object tutorial; choose HarmonyIntegration for the Seurat v5 split-layer workflow (RNA/LogNormalize here). Specify a technical batch covariate supported by study design; do not automatically remove a biological condition. Dimensions/neighbor counts/resolution require review on the corrected embedding. Harmony penalty/iteration defaults stay at locked values unless evidence supports an override.

Before choosing `--method`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--batch-col`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--dims`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--neighbors`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--umap-neighbors`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--resolution`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--sigma`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--theta`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--lambda`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--max-iter`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-options-tau`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-options-block-size`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-options-max-iter-cluster`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-options-epsilon-cluster`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-options-epsilon-harmony`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-nclust`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--harmony-early-stop`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--integrate-nclust`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--integrate-tau`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--integrate-block-size`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--integrate-max-iter-cluster`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--integrate-epsilon-cluster`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--integrate-epsilon-harmony`, call `reference_advise(module='seurat-integrate', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.

See references/options.md for every option, locked defaults, tutorial examples and S0 parameter keys. Alternative native routes may need additional locked packages; package errors are captured.

`--harmony-project-dim TRUE|FALSE` controls native RunHarmony genomic loading projection (locked TRUE). Before choosing it, consult `reference_advise` and `reference_search`; show the locked default and ask the user if no curated evidence exists.
