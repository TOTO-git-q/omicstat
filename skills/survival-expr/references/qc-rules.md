# QC rules

SRV-01: candidate/production blocker, unchanged.
SRV-02: inherited optimized-cutpoint exploratory blocker, unchanged.
SRV-03: inherited PH diagnostic warning, unchanged.
SRV-04: inherited unadjusted family warning, unchanged.
SRV-05: fixed source P0.05 and explicit engineering magnitude are separate from legacy ph-alpha.
SRV-06: NA or multi-df residual magnitude is unassessed, not proof of PH; source reason is retained.
SRV-07: non-estimable piecewise periods remain in tables with event support and warnings. No zero HR substitution.
SRV-08: AJ port is point-only; absent CI/Gray is unavailable, never zero uncertainty.
SRV-09: competing share denominator includes all outcomes, not all subjects; diagnostic tiers never change estimator.

Shared positive-time, identity, upstream integrity, independent-subject and finite-data guards
remain mandatory. New conditions and exact codes are registered in tests/refusals.csv. R tests
retain source survey rejection, collision, event-code continuity and forbidden-estimator guards.
