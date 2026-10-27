---
name: survival-expr
description: >
  Associate prespecified expression genes with survival using the existing Cox/KM path,
  optional copied non-PH diagnostics and piecewise HR, or descriptive Aalen-Johansen CIF.
  Requires an expression_matrix handoff and exact biological-subject matching. Candidate only.
---
# survival-expr

## When to use / when not
Use with prespecified expression genes and one positive follow-up time per independent subject.
The default --survival-extension none preserves the original per-gene Cox/KM scientific body.
Opt in to nonph for copied Schoenfeld diagnostics and an explicitly prespecified piecewise HR,
or competing-risks for descriptive Aalen-Johansen cumulative incidence of mutually exclusive
first events. Clinical-only analysis, repeated events, left truncation and interval censoring
remain outside this module. There is no runtime dependency on MedStat.

## Input requirements
An integrity-verified --from-run expression_matrix handoff is mandatory. Candidate, display-only
and batch-corrected upstream objects are refused. Clinical IDs must match every expression
column exactly; all subjects remain. Time must be positive, and the existing event column must
remain explicitly binary. Numeric covariates must be prespecified; no row-derived replication.
The inherited limits remain100 tested genes and5000 subjects. All legacy scientific flags stay
required for compatibility, including flags recorded as inactive in the descriptive CIF branch.

For nonph, explicitly declare dataset-name, primary summary (cox or piecewise), unique transforms
including the original ph-transform, and a positive engineering magnitude. No recommendation
or default silently selects these. Piecewise requires one declared gene, up to10 sorted unique
positive cuts strictly within follow-up, source-native fit acknowledgement, adjustment and a
planned family covering every period. It never chooses cuts or models from a PH P value.

For competing-risks, provide a distinct status column coded0=censored and consecutive1..k first
events, nominate one cause, and declare cif-estimator=aalen-johansen plus cif-interval=none.
The inherited binary event must equal the nominated cause indicator in every subject. At least
two and at most20 event types are supported. The20-cause engineering cap bounds the all-cause
observed-time tables to at most100040 rows under the inherited5000-subject limit; it never silently
merges or discards causes. Use covariates=none, scaling=none and median or prespecified display
cutoff; no optimized outcome-dependent split. Risk times must lie within both groups' support.

## Run
The complete inherited canonical command remains in tests/acceptance.json. Add extension flags
from tests/run_port_cli.py only after reviewing the intended study design. Every run still requires
--development-mode and a study contract. Python tests/run_port_cli.py --out NEW_DIRECTORY runs
actual locked R4.6.1/survival3.8-9, real limma-array handoff creation, four branches, numeric replay
and all declared refusals. Missing R or any dependency is a real blocker, never a skip or install.
The software fixture is entirely invented seed9182 data, not the historical clinical AGE_PROXY
case mentioned in old documentation. No patient rows or package patient datasets are acquired.

## What gets produced
Original Cox/KM mode retains its effect, coefficients, PH, risk, membership and search tables.
Nonph adds every requested term/global diagnostic, source severity/reason and optional complete
piecewise HR periods, event support, independent-subject counts and adjusted P values. Its figures
are original KM/continuous HR plus finite piecewise HR intervals; unavailable periods remain in
the table and are disclosed in the caption. CIF produces aggregate all-cause curves/timepoints,
risk counts, group outcome counts and an explicitly forbidden-KM diagnostic comparison. The CIF
figure uses only the nominated AJ cause and carries dataset name, original n and event counts.
All outputs go through os_module_finish and the shared figure style/figure_spec contract.

## Reading the results
Legacy scientific parameters and estimates are unchanged. The non-PH classifier preserves the
source fixed P0.05 rule separately from --ph-alpha and uses a user-declared engineering magnitude,
not a validated universal cutoff. A missing magnitude can still yield source severity low; inspect
NA/reason and QC instead of treating that as evidence for PH. Source-native piecewise fitting uses
native Cox defaults, explicitly distinct from the original continuous-model ties/max-iter/cox-eps.
The table captures actual package version/formals. Periods are (start,stop]; an event at a cut is
in the earlier period. All periods count original subjects, never independent split rows.

CIF is unadjusted descriptive cumulative incidence, not a gene hazard ratio or causal effect.
The copied primitive supplies point estimates only: no CIF CI, Gray test or adjusted model.
One-minus-KM appears only in a labelled forbidden-estimator diagnostic; it never supplies CIF
or its plot. Competing-event percentage uses all observed outcomes, excluding censored records.

## When a QC rule fires
SRV-01 keeps candidate publication blocked; inherited SRV-02/03/04 rules remain unchanged.
SRV-05 discloses the engineering classification; SRV-06 reports unavailable residual magnitudes;
SRV-07 retains non-estimable periods; SRV-08 discloses point-only CIF; SRV-09 reports competing
share. Do not remove observations, change methods, tune cuts or invent intervals to pass a check.

## Known limitations
No survey inference, RMST, landmark strategy, Fine-Gray, cause-specific regression, Gray test,
CIF intervals or missing-data imputation. Categorical covariates still require explicit upstream
encoding. The new cumulative_incidence figure type has no restyle support yet; the existing five
restyle types remain untouched. Native R/default drift, actual CLI/figures, the original clinical
CR-mgus2-cif anchor and real owner contact sheet remain pending. Synthetic contracts cannot close
those gaps. Original SN-V1 tests RMST, which is outside the selected B3 port.

## Reference files
PORT_SOURCE.json, COPIED_FUNCTIONS.json, ORIGINAL_ANCHOR_STATUS.json, ERROR_MAPPING.json,
PACK.md, VALIDATION.md, GAPS.md, parameters.md, method-basis.md, qc-rules.md,
reporting-templates.md and troubleshooting.md.
