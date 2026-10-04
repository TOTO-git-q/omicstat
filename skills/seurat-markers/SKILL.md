---
name: seurat-markers
description: >
  Run seurat-markers and produce audited single-cell tables, figures and a Methods/Results draft.
  Use for Seurat markers, 单细胞, 质控, 聚类, 整合, marker or 模块打分 as appropriate.
  NOT for condition-level differential inference (use muscat-pseudobulk) or a Bioconductor front end (use scater-qc or scran-cluster).
---
# seurat-markers

## When to use / when not
Use for the markers stage of a Seurat chain. Keep one front-end ecosystem. Condition inference uses muscat-pseudobulk; cell proportions use speckle-propeller.

## Input requirements
QC receives raw integer counts; other modules receive --from-run from seurat-qc / seurat-cluster as applicable, or an unmodified Seurat RDS carrying the same chain state. Cell/sample identifiers must match exactly.

## Run
```bash
Rscript scripts/run_seurat_markers.R --help
```
Supply --input or the supported --from-run and --outdir plus required scientific parameters listed in references/parameters.md. --spec replays resolved parameters; explicit flags override it. MCP registration awaits independent S3.

## What gets produced
Tables under tables/, standard PDF/PNG figures with captions and figure_spec, draft/methods_results.md, qc/qc_results.csv, qc/engine_warnings.csv, results/results.json, provenance/resolved_spec.json and objects/handoff.json with hashed Seurat, cell metadata and colour registry.

## Reading the results
Read QC and the full audited tables first. Descriptive cell-level results do not establish condition differences. Every threshold and input state is recorded in the draft and provenance.

## When a QC rule fires
Rules SM-01..03 are sourced in references/qc-rules.md. Input blockers stop before a draft.

## Known limitations
Independent S3 acceptance is pending. No automatic doublet removal, annotation, gene synonym lookup, gene-set thresholding or condition inference. Scientific thresholds and dimensions need explicit prespecification. Spatial scoring applicability is an owner evidence question, not an inferred suite policy.

## Reference files
See references/method-basis.md, parameters.md, qc-rules.md, reporting-templates.md and troubleshooting.md.

## Choosing options / 待裁决

Use mode=all to describe each cluster against the remaining cells, or contrast with ident-1 and optional ident-2 for prespecified identities. Wilcoxon is the locked default; native alternatives are exposed. Screening min-pct/logfc-threshold changes genes tested, only-pos changes returned directions, and return-thresh changes returned rows. display-lfc-filter only changes the separate display table. Select an unintegrated RNA or appropriately prepared SCT assay; condition inference needs muscat-pseudobulk. Dotplot uses log1p(mean(expm1(data))) scaled per gene; heatmap shows cluster means of available native scale.data genes.

Before choosing `--ident-1`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--ident-2`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--min-pct`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--logfc-threshold`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--only-pos`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--test`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--assay`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--return-thresh`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--display-lfc-filter`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-min-diff-pct`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-only-pos`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-max-cells-per-ident`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-latent-vars`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-min-cells-feature`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-min-cells-group`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--markers-base`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--contrast-latent-vars`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--contrast-only-pos`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--contrast-min-diff-pct`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--contrast-max-cells-per-ident`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--contrast-min-cells-feature`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--contrast-min-cells-group`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--features`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--group-by`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--node`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--slot`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--subset-ident`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--fc-slot`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--pseudocount-use`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--recorrect-umi`, call `reference_advise(module='seurat-markers', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.

See references/options.md for every option, locked defaults, tutorial examples and S0 parameter keys. Alternative native routes may need additional locked packages; package errors are captured.

`--markers-base` binds both all and contrast comparisons (locked 2). `--markers-mean-fxn package::function` supplies a native mean callable in both routes (locked NULL). Preserve native effect column names and interpret a custom mean function on its own scale. Before choosing these options, consult `reference_advise` and `reference_search`; if evidence is absent, show the defaults and ask the user.
