# Source and scientific adaptation

ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/cpm_core.R
ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/calibration_binned.R
ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/cpm_qc.R

PORT_SOURCE.json fixes the complete source commit and every raw Git blob. Eleven selected
function bodies have before/adapted digests and explicit differences. Original OmicStat compute,
render and QC bodies remain unchanged under private legacy names. No source environment is used.

The source penalized-selection/unpenalized-refit model differs from this true penalized signature.
The modified callback repeats the current glmnet call with the same declared preprocessing,
fold identities, alpha1, lambda rule, controls and Breslow ties. Diagnostic slopes are measured.
The source optimism and percentile arithmetic is retained with native and uncertainty limits.
No result-based method switch or automatic calibration update is introduced.

Absolute predictions require a training-only baseline in addition to coefficients. An offset-only
Breslow Cox fit at the fixed LP estimates that baseline without new prediction coefficients;
its cumulative hazard, settings and original signature bytes are bound by SHA256. Exact native
equivalence to an independent fixed-LP risk-set calculation must be tested on the locked lineage.
The source calibration slope deliberately retains its native diagnostic fit defaults and records
actual formals; historical R4.5 captures are not presented as new R4.6.1 observations.

Source helper algorithms and original tests are not evidence of native execution here. See
VALIDATION.md for actual commands, real failures and pending tests; see GAPS.md for owner/S0/evidence
and environment closure. No clinical dataset rows, source plots or proprietary paper panels are copied.
