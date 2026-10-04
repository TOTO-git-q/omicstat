# QC rules

The module uses prefix `YC`.

`YC-01`: version mismatch, blocker, draft withheld. Source: ENGINEERING_PLAN locks 1 and 3.
`YC-02`: fewer than two biological samples, warning; descriptive analyses remain possible. Source: ENGINEERING_PLAN 4.5.

Module-specific rules and their mechanical criteria are in scripts/scanpy_cluster_qc.py. They retain full results, never silently change a threshold or estimator. Typed input errors stop before computation.

Figures are only requests until the locked R rendering stage succeeds. A successful numerical run alone does not establish publication readiness.
