# Troubleshooting

- `OS_INVALID_INPUT: ... raw counts` -> the input was normalized, fractional, negative, or had an empty library -> provide uncorrected integer counts.
- `OS_INVALID_DESIGN: design is not full rank` -> a covariate is confounded with condition -> revise the study design or comparison.
- `OS_QC_BLOCKER: fewer than 100 genes` -> the voom trend has too little information after filtering -> inspect count depth and `--min-count`.
- A warning about limited biological replication -> only two samples in one group -> report the uncertainty; no sample is automatically excluded.
