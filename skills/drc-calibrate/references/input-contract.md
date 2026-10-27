# Plate input and statistical scope

One UTF-8 CSV, one plate per run. Fixed columns:
`plate_id,well,role,sample_id,concentration,dilution,response`.
All identities remain text, nonempty, unpadded; wells are unique. `role` is
`blank`, `standard` or `unknown`. Responses are finite raw continuous signals.
Dilution is a reciprocal factor >=1, never a proportion. Missing analysis fields
are refused, while concentration must be empty for blanks/unknowns.

Calibration standards declare positive known concentrations and dilution=1.
Each standard identity denotes one concentration. Each unknown identity has
exactly one dilution. Each nonblank sample/dilution has at least two technical
wells. Supply at least k+2 distinct standards for k=4 or 5 parameters. No automatic
outlier exclusion, weighting, pooling across plates or best-model selection.
`subtract-mean` requires >=2 blank wells and subtracts their mean from every well;
`none` records zero offset and ignores blanks for fitting. Blank uncertainty is
conditioned on, not propagated; the shared correction's effects on assay
validation remain a limitation. Technical well errors are assumed independent,
homoscedastic Gaussian within the standard fit.

Supply assay-validated `lloq` and `uloq` in diluted-well concentration units,
inside the tested standards (0 < LLOQ < ULOQ). These are declared limits, never
estimated or certified from this plate. Unknown means are inverted analytically
through the fitted drc LL4/LL5. Full parameter covariance is propagated with a
central-difference inverse Jacobian, including asymptote derivatives, plus the
independent unknown technical-mean variance (sample SD squared / number of wells).
Intervals use a standard-fit residual-df t quantile and are pointwise. They are
conditional assay uncertainty, not population/biological confidence intervals.
Old drc 3.0-1 absolute ED standard errors omit asymptote chain-rule terms, so they
are not reused for this calculation; native ED point estimates are checked.

Concentrations and interval limits are multiplied by the sample's dilution.
Below/above LOQ, outside tested standards or outside fitted asymptotes: withhold
quantitative unknown estimates/intervals and preserve the sample/status row.
Intervals crossing LOQ remain explicit flags. Standard backfit/recovery rows
are diagnostic only and carry range flags, including undefined inverse results.
CV uses corrected-scale SD/mean at each sample/dilution; nonpositive mean is
undefined and flagged. `max-cv` is user-declared; exceedance blocks readiness.
Canonical effect rows include only quantified samples, with n_unweighted=1
sample per row; all wells/counts/withheld rows remain in the other tables.

Titer mode uses `unknown` serial-dilution wells and optional blanks, no standards
or LOQ flags. Each sample needs k+2 distinct reciprocal dilutions and technical
replicates at each dilution. Fit decreasing response with increasing dilution.
`halfmax` reports the reciprocal dilution at halfway between that sample's
fitted lower/upper asymptotes; `endpoint` reports dilution at the supplied
blank-corrected `endpoint-response`. Supply `titer-definition`; only endpoint
accepts/requires `endpoint-response`. No cross-sample biological test is made.
Out-of-dilution-range titers are withheld; interval crossings are flagged.

The demo is simulated, not measured clinical data: 9 triplicate standards,
12 triplicate unknown specimens with 1x/10x/20x dilutions and 4 blanks (67 wells);
includes low/high out-of-range samples. Additional simulated serial dilution,
asymmetric LL5 and refusal inputs are separately identified. See evidence driver.
