# Troubleshooting

- `OS_OWNER_DECISION_PENDING` -> `--reference/--target/--covariates` asked for group inference on the scores. The limma entry and eBayes trend/robust settings for GSVA scores are an owner decision still pending (S1 P-3); run without these flags and take `tables/scores.csv` (or the hand-off) to a later, approved analysis.
- `OS_INVALID_PARAMETER` on integer counts -> use `--input-scale counts --kcdf Poisson`; do not claim auto cannot process counts.
- `OS_REFDATA_MISSING` -> collection or acceptance layer absent from locked offline registry -> provide a fully registered asset with version, species and hash.
- `OS_HANDOFF_MISMATCH` with a limma upstream -> declare the scale the limma run hands on (`logcpm` for voom E, `normalized_array` for arrays).
- `OS_BATCH_CORRECTED_INPUT` downstream -> scores of a batch-corrected matrix are typed batch_corrected_matrix with a corrected lineage; score the uncorrected matrix and put batch/SV in a later design.
- `OS_EMPTY_DATA` -> no gene set keeps between min-size and max-size members after ID intersection and constant-row removal; check the ID namespace (tables/gene_set_sizes.csv of a run with wider limits).

## User-supplied gene sets

- `OS_MISSING_PARAMETER` (user file without provenance) -> source, version and identifier type are never guessed -> give `--gene-sets-provenance` or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`.
- `OS_REFDATA_MISMATCH` -> the file's SHA-256 differs from the provenance `sha256` (edited after download, or another file's provenance) -> supply the matching pair.
- `OS_GENE_SET_ID_MISMATCH` -> the gene-set ID type differs from the analysis key type (`--feature-id-type`), or the file's IDs do not look like the declared type -> supply gene sets in the analysis ID type, or re-key the input; omicstat does not convert IDs.
- `OS_GENE_SET_SPECIES_MISMATCH` -> the declared gene-set species differs from the analysis species -> use gene sets of the analysed species.
- `OS_GENE_SET_LOW_OVERLAP` -> under 10% of the set genes occur in the analysed features -> usually the wrong ID type, Ensembl version suffixes or species; check both ID types.
