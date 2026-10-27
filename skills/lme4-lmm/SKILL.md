---
name: lme4-lmm
description: >
  Gaussian linear mixed-effects models for repeated subjects. Candidate only; explicit declarations and development-mode are required.
---

# lme4-lmm

## When to use / when not
Gaussian linear mixed-effects models for repeated subjects. Candidate development use only. Do not interpret exploratory fixture runs as clinical evidence or production acceptance. See the source-science limitations in references/source-evidence/SKILL.md.

## Input requirements
A real StudyContract JSON is required; the engine computes its byte SHA256. Declare biological units, design, scale, reference and multiplicity before inspecting significance. Technical repeats never increase biological sample size. See references/parameters.md and tests/acceptance.json.

## Run
Run from the module directory with a new output directory. A prior run can be replayed with --spec and a different --outdir. Required scientific options have no inferred defaults.

```sh
Rscript scripts/run_lme4_lmm.R --input /path/to/fixtures/sleepstudy.csv --response Reaction --subject Subject --formula Reaction ~ period * cohort + (1 | Subject) --estimation REML --singular-tolerance .0001 --ci-level .95 --study-contract /path/to/fixtures/contract.json --development-mode --seed 20261015 --outdir /path/to/new-run
```

## What gets produced
Tables, typed candidate handoff, provenance and replay specification, QC and shared figures. Native model objects stay quarantined. The current module is candidate, with golden/seal stages deferred_by_owner.

## Reading the results
Read QC first. Report effect direction, confidence interval, biological n and multiplicity family. Printed anchors are in tests/anchors.json with absolute tolerances and explicit scope; original obtained/pass fields are not reused as current test results.

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

## P0-13B2 longitudinal handoff

The fitter is unchanged. For an explicitly prespecified categorical group-by-time Gaussian model, pass its verified candidate handoff to `emmeans-contrast --longitudinal`. The post-fit port comes from `TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/longitudinal-change/` and requires the same model and finite df method for means, per-time contrasts and interaction tests. No fit or random-effects fallback is performed by the port. Biological-unit/time duplicates, changed group membership, empty group-time cells, degenerate random covariance and missing declared chronology refuse rather than altering the design. See `../emmeans-contrast/references/longitudinal-validation.md`. Native acceptance and a registered real owner example remain pending.
