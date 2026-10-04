# QC rules

The module uses prefix `VI`.

`VI-01`: version mismatch, blocker, draft withheld. Source: ENGINEERING_PLAN locks 1 and 3.
`VI-02`: fewer than two biological samples, warning; descriptive analyses remain possible. Source: ENGINEERING_PLAN 4.5.

Module-specific rules and their mechanical criteria are in scripts/scvi_integrate_qc.py. They retain full results, never silently change a threshold or estimator. Typed input errors stop before computation.

Figures are only requests until the locked R rendering stage succeeds. A successful numerical run alone does not establish publication readiness.
