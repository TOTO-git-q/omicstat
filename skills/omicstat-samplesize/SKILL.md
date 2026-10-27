---
name: omicstat-samplesize
description: A priori laboratory biological-unit or event-count planning for independent means, paired means, ANOVA, proportions and log-rank designs, copied and adapted from pinned MedStat code into an independent OmicStat candidate.
license: MIT
---

# omicstat-samplesize

Candidate source port. Native R 4.6.1 acceptance, independently pinned pwr/gsDesign
dependency closure and owner visual review are pending. This module does not call,
import or install MedStat. Source attribution is in references/PORT_SOURCE.json.

## When to use / when not

Use for an explicitly chosen a priori design and a defensible independent effect
assumption: mean_2sample, mean_paired, anova, prop_2sample or survival_logrank.
This is not a test-selection engine, observed-power calculator, fixed-N MDE solver,
noninferiority/equivalence module, clustered design, repeated-measures model or
sequential trial design. No scientific parameter is automatically recommended.

## Input requirements

There is no row-level outcome dataset. Supply a meaningful StudyContract and all
required scientific declarations. Biological units must be independently allocated
animals, donors, biological samples or separately initiated cultures. Wells,
cells and technical measurements are not automatically independent biological n.
Pairing means the same biological units occur in both conditions.

Every mean/proportion effect is oriented as group1 minus group2. The hazard ratio
is group1 over group2. One-sided direction must agree with the supplied sign.
For survival, absent event probability means required events only; biological N
and recruitment remain unknown. A completed study's own observed effect must not
be repackaged as a priori power.

## Run

Call scripts/run_omicstat_samplesize.R with --help for native argument help.
Use --development-mode explicitly; absence is refused. Provide every required
flag and the design-specific parameters in references/parameters.md. The CLI
uses the shared OmicStat --spec replay.
--study-contract-sha256 can verify supplied contract bytes, never replace them.

The tests/base_parameters.json example is an illustrative numerical contract,
not a recommendation or a registered real-data owner example. Its alpha/power,
effect, allocation and attrition must not be silently reused for a real experiment.

## What gets produced

- tables/plan.csv and tables/scenarios.csv: analyzable counts, separately adjusted
  recruitment counts and required events over the explicitly requested power grid.
- tables/biological_groups.csv: per-group biological counts and separately labelled
  technical measurement budget. Paired conditions share biological units.
- tables/planning_effect.csv: prespecified effect assumption, orientation and units.
  ci_low/ci_high are empty because this is not an estimated effect or confidence interval.
- A typed development_sample_size_plan RDS handoff, candidate QC, Methods text,
  resolved-spec and source/package provenance via os_module_finish.
- The shared os_diag_xy planning-grid figure with typed figure semantics. Grid rows
  never become observed sample counts. Error bars are not invented.

## Reading the results

The independent-mean calculation is equal-variance Student planning. Two supplied
SDs are pooled using the copied RMS rule; it is not a Welch power calculation.
Two-proportion planning uses pwr's arcsine Cohen-h method, not a rewritten normal
approximation. ANOVA assumes equal allocation. Log-rank planning calls
gsDesign::nEvents; the number of events is different from the number of units.

Dropout inflates recruitment per group by ceiling(n / (1 - dropout)) and never
changes analyzable n or required events. Technical repeat counts affect only the
measurement budget. Paired total n counts units once, not once per condition.

The raw mean-effect orientation matches omicstat-groupcompare, but the planning
assumption is not an estimated effect_table and cannot auto-select a downstream
test. The dedicated candidate handoff remains inference_allowed=false. Automatic
groupcompare consumption and scientific consistency adjudication remain pending.

## When a QC rule fires

SSZ-01 through SSZ-06 preserve the six applicable source guards: absent positive
attrition, convention-derived effect, power below 0.8, survival event probability
absent, allocation beyond 3:1 or 1:3, and alpha outside the source convention set.
These warnings do not select or overwrite a value. SSZ-90 always blocks publication
for this unaccepted candidate; SSZ-91 explains technical repeats.

## Known limitations

Native versions/defaults have not been captured in this cloud workspace. Their
absence is explicit in calls_registry.json; a separate readiness gate fails closed.
The copied unequal-allocation search stops at n1=200000. Its former lower-endpoint
off-by-one is separately repaired and has a mandatory native boundary test. No
unavailable package is replaced by hand-written math in the production engine.

R4.6.1 anchor/replay/refusal/figure execution is still pending. The current canonical
fixture is a synthetic declaration without biological data; its figures are contract
diagnostics only. It must not yield an owner contact sheet or needs_visual verdict.
The real-data owner adapter, dependency closure, native formals and scientific/visual
review remain blocking. No golden, seal, accepted router or production image changes.

## Reference files

- references/PORT_SOURCE.json: original immutable source identities, preserved byte-for-byte.
- references/PORT_ADAPTATIONS.json: separate adaptation inventory and current R-source hashes.
- references/method-basis.md: native methods and explicit assumptions.
- references/parameters.md: generated argument table.
- tests/anchors.json and tests/refusals.csv: executable definitions, without fabricated outcomes.
- ../../../docs/build/P0-13-samplesize/: coverage, dependency gaps and source evidence.
