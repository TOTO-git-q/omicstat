# Scientific guards and deliberate adaptations

| Codes | Retained scope |
|---|---|
| OAG-01 / 02 | Complete input, numeric continuous values, integer counts, stable unique IDs/pairs/cells and rectangular ratings; no silent deletion. |
| OAG-03 / 04 | Complete nonblank readable labels, explicit ordinal order, categories within declared levels and scientifically appropriate weighting. Counts now also reject out-of-order zero-frequency categories rather than dropping them. |
| OAG-05 / 06 | Nonestimable zero-variance/chance-denominator failures; sparse expected counts, out-of-range analytic bounds and failed bootstrap draws remain visible. No bound clipping. |
| OAG-07 / 08 | Original paradox and marginal divergence warnings. Thresholds .80/.60/.50/.20/.20 remain disclosed conventions. |
| OAG-09 | At least three complete Fleiss raters, same count per subject, required irr. |
| OAG-10 / 11 | Explicit ICC design, no conflicting sampling declaration, balanced finite estimable matrix, primary native engine required. |
| OAG-12 / 13 | One independent pair; optional paired prespecified acceptable bounds; original heteroscedastic/trend/normality/influence diagnostics; no automatic adjustment. |
| OAG-17 | Missing primary native package is fatal. Original psych fallback is removed, and epiR-only binary companion provenance is required. |
| OAG-18 | Original finite interval and point-within-interval condition, canonical values, counts and estimand-hash identity are checked before finish and again before rendering. |
| OAG-90 | Candidate always blocks publication while native/closure/owner acceptance is pending. |

QBA AG-14 through AG-16 are excluded. The original clinical journal/report/layout
and broad reader-prose scanner are not copied into the OmicStat renderer. Shared
OmicStat schema/provenance/figure rules govern the new surfaces. The complete
original report-level audit suite has not run on the adaptation and is not claimed
as passed. Display names are taken from the explicit label map; raw IDs remain
only in scientific data/provenance. Original warning thresholds and their five
override flags are retained in [0,1] and recorded in metadata. They affect warnings,
never point estimates, CI formulas or selection of an estimator. These conventions
are not scientific recommendations or universal interchangeability thresholds.

Original errors map to registered OS_* codes in ERROR_MAPPING.json. No MS_ code
escapes the adapter. The deny-only OMICSTAT_AGREEMENT_SIMULATE_MISSING test shim
can make an installed package appear missing, never make an absent one present.
Failed output directories and error logs must remain intact; a fresh run uses a
new evidence directory. Never create a success checkpoint to cover a package error.
