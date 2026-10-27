# Applicable source and OmicStat QC

CXS-01/02/03 retain their original byte-for-byte implementation.
CXS-04 maps CPM-01: actual analytic n below Riley required n; explicit assumptions remain reported.
CXS-05 maps CPM-04: apparent C mentioned without optimism-corrected counterpart.
CXS-06 maps CPM-05: requested B below the source project1000 reporting threshold; no precision claim.
CXS-07 maps CPM-06: a calibration curve without numerical slope reporting.
CXS-08: any failed requested bootstrap, no silent replacements or successful-fit denominator inflation.
CXS-09: any subject omitted from displayed calibration bins; full accounting remains exported.
CXS-10: source uncertainty construction and penalized adaptation remain independently unvalidated.

Only the four applicable source formulas are emitted, preserving their numerical trigger logic.
Source CPM-03/07/08/09/10/11/12/13 describe other workflows and are not passed checks in this port.
No force override, production seal or automatic removal of subjects/predictors is implemented.
