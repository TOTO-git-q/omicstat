---
name: lme4-lmm
description: >
  Fit prespecified Gaussian experimental-endpoint mixed models with one biological-unit grouping factor. Unsealed development module, not registered for production execution.
---

## Candidate local runtime verification (2026-10-15)

The original authoring status below is historical. Role A subsequently built and
executed the isolated `omicstat-r-exp:20261015` runtime. All five modules now pass
real R parsing, development/smoke tests, CLI, every documented scientific enum,
refusal paths, byte-identical table/PNG spec replay and output/handoff hash audits.
Official printed-value comparisons, tolerances and scope are in
`VALIDATION_STATUS.json`; installed formals are in `installed_api.json` and the
candidate L1 export. Candidate figure conventions and the owner-selected LMM defaults are
documented below and in the supplemental figure evidence. The modules remain unsealed, unregistered and publication-blocked.

# lme4-lmm

## Status and scope
Fit prespecified Gaussian experimental-endpoint mixed models with one biological-unit grouping factor.
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
Default main figures are the coloured descriptive subject profiles and group response profile, with legends below when grouped. The response profile exports `tables/response_profile.csv` (group, x, n_subjects, mean, ci_low, ci_high): mean of subject means ± 95% CI across subjects; descriptive, not model-adjusted. Observations are averaged within subject/group/x before equal-weight averaging across subjects. Intervals use Student t with n_subjects - 1 df; fewer than two subjects gives no interval. The first fixed predictor supplies the categorical or linear x axis; the same fitted grouping predictor and house colours as the subject profiles are used. With no additional grouping factor, one neutral profile is shown. An intercept-only model has no predictor profile.

`tables/effect_table.csv` remains unchanged and is always written; `tables/fixed_effects.csv` also supplies term, estimate, native SE, CI/level and Wald method (df unavailable for this normal approximation). Fixed effects are normally reported in text/tables. Add the bare switch `--effect-plot` to draw the existing fixed-effect forest plot as supplementary output; it is off by default and preserved by spec replay. Residual diagnostics remain diagnostic output.

This owner-selected convention follows the screened published sample: response or subject profiles in 22/27 mixed-model figures, versus effect-interval/forest panels in 2/27. These purposive figure counts are not a prevalence estimate for all papers. See `docs/build/EXPERIMENTAL_FIGURES.md` and the supplemental Role F candidate figure record. Do not substitute package plots.

## Execution
Entry scripts/run_lme4_lmm.R through the suite R router after a compatible runtime is built.
All modules require --outdir pointing at a new or empty directory. --spec replays explicit choices.
An existing output directory is never overwritten. The module is deliberately absent from the production router. Handoff object types use a development_ prefix so standard model consumers reject them; emmeans-contrast requires explicit development-mode and the development-only producer marker.

## Boundaries
Only a Gaussian endpoint, one subject grouping term and explicit ML/REML. No GLMM, time-residual covariance, model selection or automatic coefficient p-values. Wald fixed-effect intervals are labelled explicitly.

## Evidence and unfinished acceptance
See acceptance/exemplars/lme4-lmm/PACK.md and VALIDATION_STATUS.json.

## When to use / when not

## Input requirements

## Run

## What gets produced

## Reading the results

## When a QC rule fires

## Known limitations

## Reference files
