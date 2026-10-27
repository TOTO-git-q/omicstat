---
name: glmnet-coxsig
description: >
  Prespecified expression LASSO-Cox signature, frozen external validation and timeROC,
  with optional source-derived Riley planning, penalized bootstrap and aggregate calibration.
  Expression handoff required. Candidate; exact environment, native science and owner review pending.
---
# glmnet-coxsig

## When to use / when not
Prespecified gene-only expression signature development or independent validation, with one
right-censored binary event per biological subject. Default --prediction-workup none retains
the original model, ROC, descriptive KM and outputs. Optional cpm adds the P0-13 B4 workup.
There is no MedStat runtime dependency. No clinical-only model, competing risks, causal claim,
post-selection coefficient P values, DCA, nomogram or automatic pre-CV gene selection.

## Input requirements
Verified expression_matrix handoff and exact clinical subject matching; positive follow-up,
explicit0/1 event coding, ordered prespecified genes, expression scale and common time units.
Inherited100 genes/5000 subjects/20 folds/10 ROC horizons stay unchanged; no downsampling.
Training keeps supplied biological folds (five subjects and two events per holdout), path,
standardization, selection, CV objective/grouped choice and convergence settings. Breslow ties
and glmnet>=5.0 API remain explicit. External validation refuses training overlap, refitting,
retuning, recutting and changed expression scale or gene order.

For cpm, dataset-name is mandatory. Training also needs every listed planning, bootstrap,
baseline and calibration choice. Prior Cox-Snell R2, target shrinkage, event rate/horizon/mean
follow-up and their citation must come from a prespecified external planning source, not this
fit. Count every candidate parameter, at least every candidate gene, never selected coefficients.
Require0<R2<shrinkage<1 and positive common-unit times/rate. Planning and calibration horizons
must agree. External workup accepts only dataset-name; it reuses all frozen training settings.

## Run
The old canonical command and coefficient anchors remain in tests/acceptance.json. All runs
require --development-mode and the original study contract. Explicit --prediction-workup cpm
activates the added contract; its native test runner and dependency status are documented in
VALIDATION.md. The current cloud has no Rscript or Docker. No package is installed by this module.
Native workup is blocked until an OmicStat-owned exact pmsampsize environment closure exists;
the official pmsampsize1.1.3 source archive is acquired and hashed in ENVIRONMENT_REQUIREMENTS.json.
No installation, native/default capture or candidate-image success is inferred from source bytes.

## What gets produced
Original coefficients, CV/path, scores, timeROC, KM/risk tables and typed cox_signature remain.
The optional training workup adds Riley assumptions/results, every bootstrap attempt, original
subject counts, selected-feature frequency, apparent/optimism/corrected C and slope, and a
training-only baseline bound to exact coefficients, gene order, scale, lambda and training IDs.
Both cohorts get aggregate binned calibration, complete bin accounting and numeric slope/CI/OE.
No external diagnostic fit writes back to coefficients, baseline or calibration policy.

## Reading the results
Source CPM selected variables then refitted without penalty. This port deliberately retains
the existing penalized glmnet model; numeric equivalence is not claimed. Bootstrap repeats
the original declared CV/fit inside every resample. Copies of one biological subject keep its
original fold. Actual train/test slopes replace the source constant apparent slope1. Requested,
used and failed replicates are separate; failed draws are never silently replaced. Results
conditioned on successful fits may be biased. Source B>=200 is retained; B>2000 is an explicit
serial resource refusal, never an automatic budget reduction. The source1000 reporting threshold
is a disclosed project convention, not a recommendation or universal precision guarantee.

Source apparent-minus-optimism percentile intervals are labelled as that construction; their
coverage for the penalized adaptation is unverified. Apparent training calibration curves are
not optimism-corrected curves. A separate source-native Cox slope regression is a diagnostic,
not an update to the prediction model. Survival calibration-in-the-large is O/E risk, not a
logistic intercept. Training-only offset-Breslow baseline is estimated at frozen coefficients.

Each calibration point aggregates at least10 original subjects. Its observed event risk is KM
at the fixed horizon; early censoring is never recoded as non-events. Unsupported or undefined
bins are omitted from the plot and retained in accounting, with original/displayed/omitted n.
No smoothing, extrapolation or invented interval. Dataset name and actual numeric slope are
printed in the caption; all figures use the shared OmicStat builder and figure_spec path.

## When a QC rule fires
CXS-01 candidate publication blocker and CXS-02/03 original warnings remain intact.
CXS-04/05/06/07 apply copied CPM-01/04/05/06 formulas to planning adequacy, apparent/corrected
reporting, the source bootstrap reporting threshold and slope reporting. Other source QC
families are outside this selected port and are never asserted as passed. CXS-08 retains failed
resamples, CXS-09 calibration omissions, and CXS-10 the unverified uncertainty adaptation.

## Known limitations
Candidate only. No native parse/CLI/scientific, locked-default, original-source anchor or owner
acceptance has passed here. Source CPM-one-predictor is synthetic logistic AUC, outside this
selected survival port; it cannot certify the new method. Existing official simulated glmnet
CoxExample coefficient references stay unchanged, with native replay and owner binding pending.
No patient source rows or clinical source-smoke fixtures are acquired. Calibration restyle is
not newly implemented by this port; existing five supported restyle families are unchanged.

## Reference files
PORT_SOURCE.json, COPIED_FUNCTIONS.json, ORIGINAL_ANCHOR_STATUS.json, ERROR_MAPPING.json,
PACK.md, VALIDATION.md, GAPS.md, parameters.md, method-basis.md, qc-rules.md,
reporting-templates.md, troubleshooting.md and ENVIRONMENT_REQUIREMENTS.json.
