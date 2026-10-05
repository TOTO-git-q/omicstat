---
name: scvi-integrate
description: >
  Integrate multiple batches using a CPU scVI latent model and export auditable tables, a handoff object and an R figure request.
  Use for scvi single-cell workflows. NOT for condition-level cell-as-replicate tests
  (use muscat-pseudobulk). Inputs remain within the scverse front-end ecosystem.
---
# scvi-integrate

## When to use / when not
Integrate multiple batches using a CPU scVI latent model. This module does not select a biological hypothesis or optimize a result to significance.
Use muscat-pseudobulk for condition-level expression inference and speckle-propeller for sample-level proportions.

## Input requirements
A local AnnData `.h5ad` with unique cell/gene IDs, a declared raw-count layer, biological sample column, organism and annotation.
`--from-run` verifies hashes, upstream ecosystem, contract and batch-correction lineage. No network fetch occurs during analysis.

## Run
```bash
python scripts/run_scvi_integrate.py --from-run cluster_run --sample-col sample --counts-layer counts --batch-col batch --cluster-col cluster --max-epochs 100 --n-neighbors 15 --species human --annotation declared_release --outdir run_001
```
Values in this example illustrate syntax, not recommended QC cutoffs or clustering/training choices.
`--help` lists every option; required choices have no implicit fallback. See references/parameters.md.

### Via MCP
Call `omicstat_describe` for this module, then `omicstat_run` with the documented arguments. The same five MCP tools are used.
Python computes tables and figure data; MCP dispatches the figure request to the locked R image afterward.
For direct CLI execution, run `_shared/scripts/render_figure_request.R --run-dir <outdir>` in that R image.

## What gets produced
`tables/*.csv`, `objects/adata.h5ad`, `objects/handoff.json`, `results/scvi_integrate_results.json`,
`figure_data/figure_request.json`, `qc/qc_results.csv`, `provenance/provenance.json` and `provenance/resolved_spec.json`.
`draft/methods_results.md` is withheld if a blocker fires. The R stage creates figures and its render provenance.

## Reading the results
Read the full tables before their displayed subsets. Report denominators and all chosen parameters.
Clustering, marker tests and label probabilities do not by themselves establish condition-level effects or external predictive validity.
Methods and Results use the same result object; templates are in references/reporting-templates.md.

## When a QC rule fires
Read `VI` rules in references/qc-rules.md. Input/state failures are typed errors; blockers withhold the draft.
Warnings preserve numerical outputs and require an interpretation decision.

## Known limitations
CPU-only synchronous execution. scVI/scANVI runs are limited to 20000 cells and 400 requested epochs; completion within the MCP timeout is not guaranteed.
QC/PC/HVG/resolution choices in tutorials are not automatically adopted. Neutral Python-to-R backends preserve the upstream front-end ecosystem and record OS_ECOSYSTEM_CROSSING.
Locked-container numerical replay, generated golden baselines and module locks are recorded in acceptance/exemplars/scvi-integrate/S3_REQUEST.md; independent S3 remains pending.

## Reference files
parameters.md defines flags and explicit calls; method-basis.md lists official sources; qc-rules.md explains blockers;
reporting-templates.md contains filled text templates; troubleshooting.md maps errors to actions.

## 待裁决

科学阈值、分析维数/聚类分辨率、训练充分性与标签可信度由用户显式决定；教程示例不作为普适默认。Python-to-R 中性后端保留上游生态并记录 OS_ECOSYSTEM_CROSSING；完整 PACK C 教程规模和跨平台等价性留给所有者及独立 S3。

## Choosing judgement options

Before choosing `--batch-col`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` for published practice. If no curated evidence exists, show the locked L1 tutorial example and ask the user. See `references/options.md` for the extraction key.
Before choosing `--cluster-col`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` for published practice. If no curated evidence exists, show the locked L1 tutorial example and ask the user. See `references/options.md` for the extraction key.
Before choosing `--max-epochs`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` for published practice. If no curated evidence exists, show the locked L1 tutorial example and ask the user. See `references/options.md` for the extraction key.
Before choosing `--n-neighbors`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` for published practice. If no curated evidence exists, show the locked L1 tutorial example and ask the user. See `references/options.md` for the extraction key.
Before choosing `--n-latent`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` for published practice. If no curated evidence exists, show the locked L1 tutorial example and ask the user. See `references/options.md` for the extraction key.
Before choosing `--features-file`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` for published practice. If no curated evidence exists, show the locked L1 tutorial example and ask the user. See `references/options.md` for the extraction key.
Before choosing `--species`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` if interpretation needs scientific judgement. Use declared study metadata for organism, annotation, sample IDs and count-layer roles; if evidence is absent, show the locked L1 example and ask the user.
Before choosing `--annotation`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` if interpretation needs scientific judgement. Use declared study metadata for organism, annotation, sample IDs and count-layer roles; if evidence is absent, show the locked L1 example and ask the user.
Before choosing `--sample-col`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` if interpretation needs scientific judgement. Use declared study metadata for organism, annotation, sample IDs and count-layer roles; if evidence is absent, show the locked L1 example and ask the user.
Before choosing `--counts-layer`, call `reference_advise(module='scvi-integrate', ...)` and `reference_search` if interpretation needs scientific judgement. Use declared study metadata for organism, annotation, sample IDs and count-layer roles; if evidence is absent, show the locked L1 example and ask the user.

Before choosing any exposed native option in `references/options.md`, consult `reference_advise` and `reference_search` for this module and the study context. If no curated evidence settles a scientific choice, explain the locked default or cited tutorial example and ask the user. See `references/options.md` for CLI values, JSON formats, and S0 keys (`none` where no extraction key is claimed).
