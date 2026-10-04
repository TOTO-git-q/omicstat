---
name: sva-batch
description: >
  Correct a known batch effect (ComBat / ComBat-seq) or estimate surrogate variables for an
  unknown source of variation (sva / svaseq), protecting a required study variable, and produce a
  before/after PCA, a batch report and a Methods/Results draft. The corrected matrix is for
  display and scoring ONLY, never a DE input; sva/svaseq hand on surrogate variables for the DE
  design instead. Triggers: ComBat, ComBat-seq, sva, svaseq, num.sv, surrogate variable, batch
  effect, batch correction, removeBatchEffect, 批次效应, 批次校正, 代理变量, 未知混杂. Use before
  deseq2-wald/edger-qlf/limma-voom when samples were processed in known batches, or a PCA shows
  unexplained structure. NOT for the DE test itself (deseq2-wald/deseq2-lrt/edger-qlf/limma-*
  refuse a batch-corrected matrix with OS_BATCH_CORRECTED_INPUT); NOT for sample QC (deseq2-qc);
  NOT for microarray preprocessing (limma-array).
---
# sva-batch

## When to use / when not
- Use when samples were collected/processed in **known batches** (`--method combat` for
  log-scale/array data, `--method combat_seq` for raw RNA-seq counts) and the batch effect should
  be corrected for display (PCA, clustering) or descriptive scoring, while protecting a required
  study variable.
- Use `--method sva` (log-scale) or `--method svaseq` (raw counts) when the source of unwanted
  variation is **unknown**: it estimates surrogate variables to add to a downstream DE design.
- Not for the differential expression test itself: `read_handoff()` refuses a batch-corrected
  matrix (`OS_BATCH_CORRECTED_INPUT`) whenever a DE module expects a plain count/expression
  matrix. Correct the design instead (known batch or surrogate variables as covariates in
  **deseq2-wald** / **deseq2-lrt** / **edger-qlf** / **limma-voom** / **limma-array**).
- Not for sample-level QC (PCA before any correction, outlier review): run **deseq2-qc** first.

## Input requirements
- `--input`: features x samples, first column the feature id. Raw integer counts for
  `combat_seq`/`svaseq` (SB-01/SB-02 guard it); log-scale/normalized values for `combat`/`sva`.
- `--samples`: one row per sample with the id column (`--sample-col`, default `sample`), the
  protected `--study-var` column, `--batch` (known-batch methods only) and any `--covariates`.
- Or `--from-run <upstream run>`: takes `count_matrix`/`expression_matrix` and `sample_table` from
  the upstream handoff (checked by sha256; an already-corrected upstream matrix is refused too).
- `--study-var` is always required (PACK S1 P-2): the biological effect that must never be
  removed. `--batch` is required for `combat`/`combat_seq` and refused for `sva`/`svaseq`.

## Run
```
Rscript scripts/run_sva_batch.R --input counts.tsv --samples samples.csv \
  --method combat_seq --batch batch --study-var condition --outdir runs/sb1

Rscript scripts/run_sva_batch.R --input logcpm.tsv --samples samples.csv \
  --method svaseq --study-var condition --covariates lab --outdir runs/sb2
```

Every flag, its type and its default come from one spec in the entry script (`SPEC`,
`_shared/scripts/args.R`); `--help` prints it. Invalid input stops with a typed error
(`OS_UNKNOWN_FLAG`, `OS_MISSING_PARAMETER`, `OS_INVALID_PARAMETER`, `OS_CONFLICTING_PARAMETERS`,
`OS_INVALID_DESIGN`, `OS_UNSUPPORTED_DESIGN`). `--spec <run>/provenance/resolved_spec.json`
replays an earlier run.

### Via MCP
Call `omicstat_run` with `module="sva-batch"` and the same flags as `args`; read the result with
`omicstat_read`. The ones that matter most:

| Flag | Default | Effect |
|---|---|---|
| `--method` | required | combat / combat_seq (known `--batch`) or sva / svaseq (unknown source) |
| `--batch` | none | known batch column; required for combat/combat_seq, refused otherwise |
| `--study-var` / `--study-var-type` | required / categorical | the protected variable; combat_seq refuses `continuous` |
| `--covariates` | none | additional protected columns |
| `--num-sv-method` | be | sva/svaseq: "leek" is an explicit sensitivity option (PACK P-3) |

Details and sources: references/parameters.md.

## What gets produced
- `tables/corrected_matrix.csv` -- the display-only corrected matrix (ComBat/ComBat_seq output,
  or `limma::removeBatchEffect` with the estimated surrogate variables for sva/svaseq)
- `tables/batch_report.md` -- batch/study-variable levels and sizes, cross-table, the joint
  design estimability check run before correction (batch + covariates + study variable, as
  ComBat/ComBat_seq build it) with the confounding status (combat/combat_seq), or the number of
  surrogate variables (sva/svaseq), and what the corrected matrix is used for
- `figures/combat_prior` (+ `combat_prior_2`, ... when the batches do not fit one figure height)
  and `tables/combat_prior.csv` (`--method combat` only) -- the ComBat empirical-Bayes prior
  diagnostic (PACK F): kernel density of the per-feature batch-effect estimates (gamma hat,
  delta hat) against the fitted normal / inverse-gamma priors for every batch, with the
  hyper-parameters. Recomputed by the module exactly as `ComBat()` does (`prior.plots` stays
  FALSE: base graphics are not used); ComBat_seq (`shrink = FALSE`) and sva/svaseq fit no such
  prior, and their batch report says so
- `tables/sv_table.csv` (sva/svaseq only) -- one row per sample, columns `SV1..SVn`; add these
  to a downstream DE module's design (new handoff type `sv_table`, see below)
- `figures/batch_pca` (`.pdf`, `.png`, `.figure_spec.json`) -- before/after PCA, "display only"
  captions (SUITE cross-module rule 7); from `_shared/scripts/fig_mod_bulk.R`
  (`os_batch_pca_pair`, FIGURE_STYLE.md sec 19.1)
- `draft/methods_results.md`, `results/sva_batch_results.json` -- both, like the batch report,
  state the models (protected design, fitted/full and null model with your column names) and the
  values every sva/limma call received on the path that ran (ComBat par.prior/mean.only/ref.batch;
  ComBat_seq full_mod/shrink/shrink.disp/covar_mod; num.sv method/B/seed/vfilter; sva/svaseq
  method/B iterations/constant; the display-only removeBatchEffect arguments)
- `qc/qc_results.csv` (SB-01..SB-08), `qc/engine_warnings.csv`
- `objects/handoff.json`: the corrected matrix is named like a plain DE input
  (`count_matrix` for combat_seq/svaseq, `expression_matrix` for combat/sva) but typed
  `batch_corrected_matrix` -- this is deliberate (PACK S1 P-1): `read_handoff()` already refuses
  that type for any other expected type. Also `sample_table`, `colour_registry`, and (sva/svaseq)
  `sv_table`. The ORIGINAL uncorrected matrix is not re-exported: use it directly (your own
  `--input`, or the upstream deseq2-qc run) with `--covariates` naming the batch column or the
  `sv_table` columns in the DE module's own design.
- `provenance/provenance.json`, `provenance/resolved_spec.json`

## Reading the results
Write-up templates and their slots: references/reporting-templates.md. Named failure modes:
- **"Batch effects were corrected with ComBat-seq (sva package)" and nothing else.** State the
  batch variable, the protected study variable/covariates, and what the corrected matrix was used
  for (PACK L3 review: most exemplars omit both).
- **Feeding the corrected matrix to a differential test.** It is for display and descriptive
  scoring only; the standard DE path refuses it (`OS_BATCH_CORRECTED_INPUT`).
- **Regressing out surrogate variables before testing.** Add them to the DE design instead; never
  produce a "cleaned" matrix and test it as if the SVs did not exist (PACK P-3).

## When a QC rule fires
Rules `SB-01..SB-08` -- see references/qc-rules.md. SB-01..SB-04 are blockers decided on the
input (integer/negative counts for the count-based methods, batch levels/sizes for the known-batch
methods): the run stops with `OS_QC_BLOCKER` and no draft. Warnings (SB-05, SB-06, SB-08) must be
read before reporting; SB-07 is informative. Confounding, rank and continuous-study-var-for-
combat_seq problems are typed errors, not QC rows (references/troubleshooting.md).

## Known limitations
- Supervised sva (`controls`) is out of scope for v1: `sva`/`svaseq`'s `controls` argument is
  always `NULL`.
- `ComBat`'s `mean.only`, `ref.batch` and `par.prior` are fixed at their function defaults (PACK
  D-S4: not exposed as flags); a reference-batch train/test workflow is out of scope for v1.
- ComBat_seq's placement of a **continuous** study variable (`group` vs `covar_mod`) is an open
  S1 appendix item (the "clarify" note); `--method combat_seq` refuses `--study-var-type
  continuous` with a typed error rather than guessing (use sva/svaseq instead).

## Reference files
- references/method-basis.md -- sources (package@version, vignette section, citation from the Rd)
- references/parameters.md -- every flag and fixed argument, value and why (PACK P-x)
- references/qc-rules.md -- rule id, severity, criterion, action, source
- references/reporting-templates.md -- the Methods/Results templates the engine fills, and their slots
- references/troubleshooting.md -- symptom -> cause -> fix (English)
