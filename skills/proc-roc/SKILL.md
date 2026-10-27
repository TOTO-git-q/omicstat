---
name: proc-roc
description: Independent-unit biomarker ROC/AUC with explicit class/direction, exploratory cutoffs and adjusted paired DeLong comparisons, adapted from pinned diagnostic-accuracy source.
license: MIT
---

# proc-roc

Partial independent candidate. No native R4.6.1 numerical result, installed pROC
closure, real-data owner sheet or production acceptance is claimed here.
Ported from TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:
skills/diagnostic-accuracy/. OmicStat never calls or imports the MedStat runtime.

## When to use / when not

Use for predeclared numeric markers measured once on each independent biological
or physical unit and compared with an explicitly binary reference standard.
The first marker is the declared primary marker. Additional markers use paired
DeLong primary-versus-rest comparisons and a caller-selected multiplicity method.

Do not use for per-cell/per-lesion clustered observations, repeated measurements,
time-dependent/censored outcomes, fitted multivariable risk model validation,
multi-reader modalities or diagnostic meta-analysis. AUC measures discrimination,
not calibration, causal effect, clinical utility or instrument interchangeability.

## Input requirements

Choose an explicit subject-wide feature_table or feature-by-sample expression_matrix.
Supply either its direct CSV/TSV/RDS path or a typed --from-run object. A separate
sample sheet contains stable unique independent-unit IDs and the binary reference
standard. Both ID sets must match exactly. Aggregate per-gene DE feature tables
are not subject-wide measurements. Selected genes/markers are explicit; no ranking
or feature selection is performed. RDS matrices must be numeric and named.

StudyContract bytes, population/class/marker reader labels, units and dataset name
are required. Handoff hashes/types, changed contracts, display-only inputs and
batch-corrected lineage are checked before inference. A dataset name alone is not
a receipt proving real owner data. No raw clinical fixture rows are distributed.

## Run

Use scripts/run_proc_roc.R --help, the exact required/conditional questions in
references/parameters.md, and --development-mode. --spec replays resolved arguments.
Direct validation precedes output-directory creation. The module never installs
pROC or substitutes a different library/estimator. The native-readiness gate fails
closed until a separately reviewed independent exact dependency closure is bound.

tests/base_parameters.json is the original deterministic synthetic arithmetic
case adapted to OmicStat, not a recommendation for an experiment. Bootstrap 200
is a test setting, not a claimed native default or scientific adequacy threshold.

## What gets produced

- Full AUC and DeLong CI, with actual positive/negative independent counts.
- Paired primary-versus-rest differences and unadjusted pointwise CIs, raw P,
  selected adjusted P, complete family identity/size and undefined-native status.
- A selected primary cutoff's contingency counts, accuracy intervals and LR/DOR;
  zero cells retain uncorrected undefined intervals and a separate 0.5 correction.
- Optional multi-cutoff, assumed-prevalence PPV/NPV, subgroup and indeterminate
  sensitivity tables. Every applicable participant-flow identity is checked.
- Exploratory cutoff-selection bootstrap and declared internal validation,
  including requested/attempted/successful/failed bootstrap counts.
- Independently fitted uncorrected partial AUC with bootstrap uncertainty.
- Shared display-only primary ROC, comparison ROC and partial-region figures,
  numeric source tables, typed figure_spec, resolved spec, QC and provenance.
- Candidate development_roc_model, display-only/inference-disallowed, ready=false.

## Reading the results

Positive/negative class and common direction are mandatory. The original automatic
direction fit is audit-only; its AUC never replaces a reported result. Full AUC
and partial AUC come from distinct objects. J is sensitivity + specificity - 1,
not pROC's differently scaled 'youden' coordinate. Negative J is mathematically
possible and retains the original review warning rather than being clipped.

Numeric cutoffs require a prior source/rationale. Youden or closest-to-top-left
selection is always exploratory and apparent accuracy is optimistic. Its bootstrap
reselects the cutoff each draw. The original first-best point tie convention and
pROC's original bootstrap tie failure remain; no random/omit workaround is used.

The source's internal bootstrap cap min(requested,200) is retained and explicitly
reported. Out-of-bag validation averages per-resample estimates, not pooled repeated
predictions as independent subjects. Original pooled-LOO binomial intervals are
labelled descriptive, not a complete dependent-CV performance interval. The original
explicit missing-validation override remains an unresolved high QC condition.

P0-13 specifically requires explicit correction for multiple markers. The chosen
method applies to the whole primary-versus-rest P-value family, preserving raw P.
Difference CIs remain unadjusted pointwise intervals. ROC band CIs are pointwise
at fixed specificities, not simultaneous and not confidence intervals for AUC.

## When a QC rule fires

ROC-01..23 map the original scientific guards. Identity failures, absent labels,
nonfinite input, clustered IDs, different paired sets, missing exploration
companions and changed source bindings are typed refusals. A shared explicit-device
renderer refuses a stray Rplots.pdf. ROC-24 verifies tables/native counts/estimand
binding; ROC-90 always records pending acceptance. No direction reversal, imputation,
subsampling, alternate covariance or new cutoff is used to make a gate pass.

## Known limitations

Rscript and Docker are absent in this workspace. Exact independent pROC package
inventory/source pin and native formals are unresolved. The additional installed-
prefix lint failure for proc-roc is kept, not bypassed. Native original anchors,
same-input before/after numerical checks, replay, refusals, chain and figures are
definitions awaiting genuine R4.6.1 execution. Source/static tests cannot certify them.

The score-distribution and participant-flow figure adapters are still pending;
the checked flow table is available. No MedStat report theme, clinical prose or
STARD checklist was copied. The official pROC aSAH owner example remains unbound
because actual source SHA256/version bytes have not been obtained. There is no
owner_review declaration for synthetic canonical data. Future real inputs/fitted
objects must remain private; only reviewed aggregates may be uploaded. Per-family
20-record visual evidence and owner approval remain open. See build GAPS.md.

## Reference files

- PORT_SOURCE.json, COPIED_FUNCTIONS.json and source patches: exact original blob
  identities and reviewable code adaptation, without a byte-equivalence claim.
- PORT_ADAPTATIONS.json and method-basis.md: preserved methods and exact changes.
- ERROR_MAPPING.json and qc-rules.md: source-to-suite refusal mapping.
- tests/anchors.json and refusals.csv: unexecuted native expectations.
- tests/owner_anchor_pending.json: missing genuine dataset identity and receipt.
- ../../../docs/build/P0-13-proc-roc/: scope, actual test logs and remaining gates.
