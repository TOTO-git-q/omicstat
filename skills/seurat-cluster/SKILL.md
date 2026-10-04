---
name: seurat-cluster
description: >
  Run seurat-cluster and produce audited single-cell tables, figures and a Methods/Results draft.
  Use for Seurat cluster, 单细胞, 质控, 聚类, 整合, marker or 模块打分 as appropriate.
  NOT for condition-level differential inference (use muscat-pseudobulk) or a Bioconductor front end (use scater-qc or scran-cluster).
---
# seurat-cluster

## When to use / when not
Use for the cluster stage of a Seurat chain. Keep one front-end ecosystem. Condition inference uses muscat-pseudobulk; cell proportions use speckle-propeller.

## Input requirements
QC receives raw integer counts; other modules receive --from-run from seurat-qc / seurat-cluster as applicable, or an unmodified Seurat RDS carrying the same chain state. Cell/sample identifiers must match exactly.

## Run
```bash
Rscript scripts/run_seurat_cluster.R --help
```
Supply --input or the supported --from-run and --outdir plus required scientific parameters listed in references/parameters.md. --spec replays resolved parameters; explicit flags override it. MCP registration awaits independent S3.

## What gets produced
Tables under tables/, standard PDF/PNG figures with captions and figure_spec, draft/methods_results.md, qc/qc_results.csv, qc/engine_warnings.csv, results/results.json, provenance/resolved_spec.json and objects/handoff.json with hashed Seurat, cell metadata and colour registry.

## Reading the results
Read QC and the full audited tables first. Descriptive cell-level results do not establish condition differences. Every threshold and input state is recorded in the draft and provenance.

## When a QC rule fires
Rules OSC-01..03 are sourced in references/qc-rules.md. Input blockers stop before a draft.

## Known limitations
Independent S3 acceptance is pending. No automatic doublet removal, annotation, gene synonym lookup, gene-set thresholding or condition inference. Scientific thresholds and dimensions need explicit prespecification. Spatial scoring applicability is an owner evidence question, not an inferred suite policy.

## Reference files
See references/method-basis.md, parameters.md, qc-rules.md, reporting-templates.md and troubleshooting.md.

## Choosing options / 待裁决

Choose LogNormalize for the PBMC library-size normalization workflow, or SCTransform for the separate UMI variance-stabilizing workflow. Choose PCs using the elbow and biology, neighbors using desired local scale, HVGs using data size and study design, and resolution by inspecting markers and sample structure. hvg-method accepts vst, mean.var.plot or dispersion. hvg-batch-col implements the Harmony tutorial union of per-batch HVGs.

Before choosing `--normalization`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--n-hvg`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--n-pcs`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--dims`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--neighbors`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--umap-neighbors`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--resolution`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--scale-factor`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--algorithm`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--min-dist`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--normalize-normalization-method`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--sct-vars-to-regress`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--sct-vst-flavor`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.
Before choosing `--umap-metric`, call `reference_advise(module='seurat-cluster', …)` and `reference_search` for published practice; if no curated evidence exists, show the example/default in references/options.md and ask the user.

See references/options.md for every option, locked defaults, tutorial examples and S0 parameter keys. Alternative native routes may need additional locked packages; package errors are captured.

Native controls: `--cluster-initial-membership`, `--cluster-node-sizes`, `--hvg-mean-function`, `--hvg-dispersion-function`, `--sct-reference-model`, `--sct-residual-features`. These bind FindClusters initial membership/node sizes, HVG mean/dispersion functions and SCTransform reference model/residual features. Before choosing these options, consult `reference_advise` and `reference_search`; if no evidence is curated, show the locked defaults in references/options.md and ask the user. Function names are Seurat names or package::function; the SCT reference is an offline RDS model.
