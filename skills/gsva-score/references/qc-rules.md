# QC rules

| Rule | Severity | Criterion | Action | Source |
|---|---|---|---|---|
| GV-01 | info | Sets excluded after ID intersection, constant-row removal or size limits | Report per-set sizes and reasons (tables/gene_set_sizes.csv) | PACK P-2 |
| GV-02 | info | Scores only (always) | Hand the scores on; inference is owner-pending | PACK P-3 |
| GV-03 | warning | Batch-corrected matrix scored | Scores typed batch_corrected_matrix, descriptive only; use original data plus covariates for inference | PACK P-3; SUITE rule 7 |
| GV-04 | info | Auto selected no kernel | Report n>=200 ECDF branch | GSVA gsvaParam.Rd kcdfNoneMinSampleSize; PACK P-1 |
| GV-05 | warning | Constant score row | Inspect gene-set overlap | GSVA gsva.Rd Value |
| GV-06 | info | GSVA filterRows removed constant-expression rows | Report the count; sizes are after this removal | GSVA gsvaParam.Rd filterRows |

Nonfinite expression, counts without explicit Poisson, a missing offline collection, a limma hand-off whose scale disagrees with `--input-scale`, and any inference request (`OS_OWNER_DECISION_PENDING`) stop before a draft with typed OS_* errors.
