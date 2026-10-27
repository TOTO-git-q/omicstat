---
name: emmeans-contrast
description: >
  Declared marginal contrasts from a verified lme4 candidate model. Candidate only; explicit declarations and development-mode are required.
---

# emmeans-contrast

## When to use / when not
Declared marginal contrasts from a verified lme4 candidate model. Candidate development use only. Do not interpret exploratory fixture runs as clinical evidence or production acceptance. See the source-science limitations in references/source-evidence/SKILL.md.

## Input requirements
A real StudyContract JSON is required; the engine computes its byte SHA256. Declare biological units, design, scale, reference and multiplicity before inspecting significance. Technical repeats never increase biological sample size. See references/parameters.md and tests/acceptance.json.

## Run
Run from the module directory with a new output directory. A prior run can be replayed with --spec and a different --outdir. Required scientific options have no inferred defaults.

```sh
Rscript scripts/run_emmeans_contrast.R --from-run /path/to/fixtures/upstream --factor period --weights equal --df-method asymptotic --adjust none --ci-level .95 --study-contract /path/to/fixtures/contract.json --development-mode --seed 20261015 --outdir /path/to/new-run
```

## What gets produced
Tables, typed candidate handoff, provenance and replay specification, QC and shared figures. Native model objects stay quarantined. The current module is candidate, with golden/seal stages deferred_by_owner.

## Reading the results
Read QC first. Report effect direction, confidence interval, biological n and multiplicity family. Printed anchors are in tests/anchors.json with absolute tolerances and explicit scope; original obtained/pass fields are not reused as current test results.

Marginal-mean confidence intervals are explicitly unadjusted pointwise intervals; their overlap is not a pairwise significance test. Pairwise inference uses the contrast table and declared within-stratum multiplicity. `inference_families.csv` and metadata preserve each summary's native adjustment annotations and family row counts. Native CI and P adjustments can differ, so the summary adjustment label alone must not be used as a CI-method label.

## When a QC rule fires
Any blocker prevents manuscript inference. Resolve input/design problems upstream; never bypass them or relabel technical repeats. tests/refusals.csv binds typed nonzero entry-point refusals.

## Known limitations
No owner visual/scientific acceptance or production seal. Cloud developer package versions may differ from the original R4.6.1 image. Historical source evidence is archived with its commit and is not fresh acceptance. The 24 canonical table comparison requires the independently preserved evidenceH manifest; absence is a blocked gate, not a pass.

## Reference files
- references/parameters.md: declared CLI interface
- installed_api.json and scripts/calls_registry.json: source candidate API evidence
- tests/anchors.json, tests/acceptance.json, tests/refusals.csv: executable checks
- references/source-evidence/provenance.json: exact source snapshot provenance
- ../_shared/STUDY_CONTRACT.md: shared byte/hash contract

## P0-13B2 explicit longitudinal port

Ported from `TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/longitudinal-change/`. Select `--longitudinal --factor <group> --by <categorical-time> --time-levels <all-times-in-order> --dataset-name <actual-label>` only after fitting the prespecified Gaussian group-by-time model in `lme4-lmm`.

The original mode and its within-by pairwise convention remain unchanged. Longitudinal mode instead retains the source `revpairwise` direction, provides EMM tables, raw and jointly adjusted per-time contrast tables and the interaction from `emmeans::joint_tests`. Same df method does not mean every contrast and omnibus test has the same numerical denominator df. Both actual df columns are retained.

Choose `--adjust none|bonferroni|holm|sidak` explicitly. The corrected family is all group contrasts across all times, using `by=NULL`, and raw P never becomes adjusted P. Mean and raw contrast CIs remain pointwise. Native messages identify adjusted-CI behavior, which can differ from the requested P correction, especially Holm. `tukey` and asymptotic df are refused only in this new mode. Existing finite-df ceiling stays 3000 fitted rows; no automatic alternate model, ceiling increase, filtering or asymptotic fallback.

This bounded port requires one fitted row per biological unit/time, group constant within unit, complete observed group-time cells, a two-way interaction and categorical time. Continuous-time, trial MMRM, GEE, GLMM, survey and automatic model-selection branches are not transplanted. Repeated values at one time must be curated upstream under an explicit technical-replicate rule.

See references/LONGITUDINAL_PORT_ADAPTATIONS.json and longitudinal-validation.md. Original source anchors and exact native before/after checks are declared, with R4.6.1 numerical and PNG/owner verification still pending. Synthetic source fixtures are contracts, not owner contact sheets. Native official nonclinical `nlme::Soybean` is a proposed real example; its exact package/data binding and owner registration are pending independent executor evidence.
