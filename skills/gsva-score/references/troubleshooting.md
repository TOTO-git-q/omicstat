# Troubleshooting

- `OS_OWNER_DECISION_PENDING` -> `--reference/--target/--covariates` asked for group inference on the scores. The limma entry and eBayes trend/robust settings for GSVA scores are an owner decision still pending (S1 P-3); run without these flags and take `tables/scores.csv` (or the hand-off) to a later, approved analysis.
- `OS_INVALID_PARAMETER` on integer counts -> use `--input-scale counts --kcdf Poisson`; do not claim auto cannot process counts.
- `OS_REFDATA_MISSING` -> collection or acceptance layer absent from locked offline registry -> provide a fully registered asset with version, species and hash.
- `OS_HANDOFF_MISMATCH` with a limma upstream -> declare the scale the limma run hands on (`logcpm` for voom E, `normalized_array` for arrays).
- `OS_BATCH_CORRECTED_INPUT` downstream -> scores of a batch-corrected matrix are typed batch_corrected_matrix with a corrected lineage; score the uncorrected matrix and put batch/SV in a later design.
- `OS_EMPTY_DATA` -> no gene set keeps between min-size and max-size members after ID intersection and constant-row removal; check the ID namespace (tables/gene_set_sizes.csv of a run with wider limits).
