# edger-qlf troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `OS_QC_BLOCKER: EQ-01/02` | not raw nonnegative integer counts | Supply original RNA-seq counts |
| `OS_QC_BLOCKER: EQ-03` | compared group lacks biological replication | Add replicates |
| `OS_INVALID_DESIGN` | group/covariate model rank deficient | Remove a confounded covariate |
| `OS_INVALID_PARAMETER: --treat-fc` | threshold is between 0 and 1 | Give a prespecified linear FC >1, or 0 for the QLF F-test |
| Too few genes after filtering | filterByExpr thresholds/design | Review design and locked filter defaults before changing a threshold |
| `--from-run` refuses corrected matrix | sva-batch display output is not valid DE input | Pass original counts with batch variables in the design |
| BCV plot differs from edgeR plotBCV | this suite shows tagwise points and common reference only | Read its caption; use edgeR directly for the trended overlay |
