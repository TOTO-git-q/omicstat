---
name: emmeans-contrast
description: >
  Compute prespecified within-stratum pairwise marginal-mean contrasts from a verified lme4-lmm run. Unsealed development module, not registered for production execution.
---

## Candidate local runtime verification (2026-10-15)

The original authoring status below is historical. Role A subsequently built and
executed the isolated `omicstat-r-exp:20261015` runtime. All five modules now pass
real R parsing, development/smoke tests, CLI, every documented scientific enum,
refusal paths, byte-identical table/PNG spec replay and output/handoff hash audits.
Official printed-value comparisons, tolerances and scope are in
`VALIDATION_STATUS.json`; installed formals are in `installed_api.json` and the
candidate L1 export. Figures are candidate baseline renders; Role B owns further
convention work. The modules remain unsealed, unregistered and publication-blocked.

# emmeans-contrast

## Status and scope
Compute prespecified within-stratum pairwise marginal-mean contrasts from a verified lme4-lmm run.
This is an unsealed development implementation. R has not executed in the authoring environment.
Use only an isolated test runtime with --development-mode. Every result carries a blocking DEV-01 QC rule.
No numerical baseline, module seal, publication readiness or locked-version compatibility is claimed.

## Inputs and scientific choices
See references/parameters.md for the exhaustive CLI flag list. The study-contract hash must identify the caller's declared design.
Do not choose a model, averaging population, reference, biological unit, confidence level or multiplicity family from the observed significance.
Input CSVs must contain explicit column names. Missing analysis data are refused; curate and document exclusions upstream.
Technical replicates must never be relabelled as independent biological units.

## Outputs
Native model and metadata RDS files, checked handoff hashes, canonical effect table,
package-native supplementary tables, engine warning log, QC rules and replay/provenance JSON.
The Methods file states that the scientific draft is withheld pending verification.
Plots and full reporting are pending shared-figure-layer implementation. Do not substitute package plots.

## Execution
Entry scripts/run_emmeans_contrast.R through the suite R router after a compatible runtime is built.
All modules require --outdir pointing at a new or empty directory. --spec replays explicit choices.
An existing output directory is never overwritten. The module is deliberately absent from the production router. Handoff object types use a development_ prefix so standard model consumers reject them; emmeans-contrast requires explicit development-mode and the development-only producer marker.

## Boundaries
Only lme4-lmm Gaussian identity-link fits, one factor and optional one by factor, pairwise contrasts on the link scale. Adjustment is separately within each by stratum. No arbitrary external model RDS, custom contrasts or population extrapolation.

## Evidence and unfinished acceptance
See acceptance/exemplars/emmeans-contrast/PACK.md and VALIDATION_STATUS.json.

## When to use / when not

## Input requirements

## Run

## What gets produced

## Reading the results

## When a QC rule fires

## Known limitations

## Reference files
