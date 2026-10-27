---
name: omicstat-agreement
description: Explicit-design independent instrument and rater agreement using Bland-Altman limits and their confidence intervals, named ICC forms, and Cohen or Fleiss kappa; an independently adapted OmicStat candidate from pinned MedStat source.
license: MIT
---

# omicstat-agreement

Candidate source adaptation. Native R 4.6.1 acceptance, exact independent
vcd/irr/epiR closure, registered real-data owner figures and visual approval are
pending. The module has no MedStat runtime import, environment or file dependency.

## When to use / when not

Use for a deliberately declared method/rater design: two continuous measurements
on each independent unit; complete balanced ICC ratings; two-rater Cohen kappa;
or at least three complete raters for Fleiss kappa. Agreement does not establish
validity, diagnostic accuracy or universal interchangeability.

Do not use these copied independent-unit methods for repeated/clustered pairs,
variable raters per subject, missing ratings, QBA, survival outcomes or a
data-dependent choice of the most favourable coefficient. No automatic
transformation, bias correction, pair deletion or substitute estimator occurs.

## Input requirements

Supply CSV data, a JSON/YAML/CSV label map, a meaningful StudyContract and explicit
scientific choices. Label the population, measurement, each rater/method and
every categorical level. Wide/long data must have complete stable independent
IDs. Counts input has every declared cell, including zero cells, and explicitly
declares aggregate-unit; individual IDs are not inferred from a counts table.

ICC and Bland-Altman currently require wide numeric input. A measurement unit
and dataset name are mandatory. A name is a caller declaration, not a real-data
receipt. Ordinal level order is explicit; a nominal order is descriptive only.
ICC model, definition, single/average unit, rater population and same-rater design
have no inferred defaults. Fixed-rater absolute agreement needs a rationale for
that fixed target population. Acceptability bounds are optional but must be
paired and justified before analysis; absent bounds means descriptive results.

## Run

Use scripts/run_omicstat_agreement.R --help and --development-mode. Every required
flag and conditional guard is listed in references/parameters.md. Shared --spec
replay, parameter-choice provenance and StudyContract byte binding are retained.
The module never installs a package. Native package versions/formals are unresolved
in this source-only workspace and the separate readiness gate fails closed.

tests/base_parameters.json is an invented physical-item contract test. Its
confidence level, bootstrap size and other settings are not recommendations for
a real experiment. Numeric and label inputs must be chosen for the actual design.

## What gets produced

- effect_table.csv with real native estimates/CIs and an estimand SHA256 per row.
- Bland-Altman: pairs, diagnostics and prespecified-acceptability tables; a shared
  display-only figure with bias, both 95% population limits, each line's pointwise
  CI and optional supplied acceptable bounds.
- Cohen kappa: complete contingency counts/row denominators, marginals and
  agreement summary; a shared count heatmap with count and row-percentage text.
  Two-category data additionally require epiR's PABAK/prevalence/bias companions.
- ICC: explicit model/definition/unit, native F-based CI and optional justified
  adequacy-threshold comparison. Fleiss: subject-bootstrap accounting and category
  distribution. These two routes retain the original tabular scope.
- Candidate-only development_agreement_model handoff, Methods, QC, resolved spec,
  package and input provenance through os_module_finish. Publication stays blocked.

## Reading the results

Bland-Altman uses signed A-minus-B or B-minus-A differences. Population limits
remain bias +/- 1.96 SD. The chosen confidence level controls the CI of the bias
and each limit, not population coverage. Limits of agreement are not a confidence
interval for bias. The copied t-based limit-CI standard error is documented in
references/method-basis.md. Compatibility includes the outer limit-CIs and does
not imply automatic instrument substitution.

Ordinal Cohen kappa keeps linear weighting primary, quadratic weighting as
sensitivity, and unweighted as secondary. Nominal kappa has no distance weighting.
Fleiss uses a different chance model. Subject bootstrap draws whole independent
units; successes, failures, seed and requested count are retained. PABAK never
replaces the primary chance-corrected coefficient. Interpretation bands and QC
thresholds are conventions, not universal adequacy decisions.

## When a QC rule fires

OAG-01 through OAG-13 retain applicable source input, estimability, paradox,
marginal, ICC-design and Bland-Altman diagnostic guards. The original AG-18
interval/count/estimand identity checks are mapped to OAG-18. In particular an
estimate outside its reported CI is still refused, including a bootstrap CI;
the module does not clip or replace it. This is an inherited release condition,
not a claim that all statistically valid bootstrap intervals enclose their point.

OAG-17's automatic psych fallback is explicitly removed: missing irr fails.
Binary companions similarly require actual epiR. OAG-90 always marks independent
acceptance pending. QBA OAG-14 through OAG-16 remain excluded/reserved. See the
precise scope and adaptations in references/PORT_ADAPTATIONS.json and qc-rules.md.

## Known limitations

This is an adapted source port, not byte-identical copying or demonstrated native
numerical equivalence. The irr-only decision differs from the original automatic
psych fallback and remains reviewable. Current native call defaults are not
captured. Original three example cases have 30 expected checks but no freshly
obtained results here. Fleiss bootstrap still lacks an independent printed anchor.

The three public published example tables (SAS SkinCondition 4x4, Bland-Altman
1986 first PEFR readings, Shrout-Fleiss 1979 Table 2) are committed under
tests/fixtures/published_anchor_inputs with a source note and are hash-verified
before the original-anchor runner uses them; no patient-level record is involved. No synthetic contract plot can
serve as owner review. Registered official owner adaptation, native contact sheets,
per-family 20-record visual evidence and owner approval remain in GAPS.md.

## Reference files

- PORT_SOURCE.json and COPIED_FUNCTIONS.json: pinned original identities and exact
  normalized function hashes; original source cache remained read-only.
- PORT_ADAPTATIONS.json and ERROR_MAPPING.json: concrete source changes and codes.
- method-basis.md, qc-rules.md and parameters.md: estimands, preserved guards and CLI.
- tests/anchors.json, official_anchor_inputs.json and refusals.csv: executable
  definitions, not obtained native evidence.
- ../../../docs/build/P0-13-agreement/: coverage, actual tests and unresolved gates.
