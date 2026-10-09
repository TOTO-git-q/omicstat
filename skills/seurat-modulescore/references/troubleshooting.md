# Troubleshooting

- OS_MISSING_PARAMETER -> a scientific choice or input is missing -> supply the required argument; tutorial examples are not defaults.
- OS_INVALID_COUNTS -> fractional, negative, nonfinite or empty counts -> supply raw UMI counts.
- OS_MITO_FEATURES -> mitochondrial pattern matches no genes -> check species and identifiers.
- OS_CHAIN_STATE -> missing or incompatible upstream state -> run seurat-qc then seurat-cluster and use --from-run.
- OS_ECOSYSTEM_MIXED -> other front-end ecosystem -> start a separate chain in that ecosystem.
- OS_HANDOFF_MISMATCH -> changed upstream file or wrong type -> restore upstream output; do not edit its JSON.
- OS_BATCH_CORRECTED_INPUT -> corrected matrix lineage -> provide an uncorrected chain.
- OS_PSEUDOREPLICATION -> condition inference requested across cells -> use muscat-pseudobulk with biological replicates.

## User-supplied gene sets

- `OS_MISSING_PARAMETER` (user file without provenance) -> source, version and identifier type are never guessed -> give `--gene-sets-provenance` or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`.
- `OS_REFDATA_MISMATCH` -> the file's SHA-256 differs from the provenance `sha256` (edited after download, or another file's provenance) -> supply the matching pair.
- `OS_GENE_SET_ID_MISMATCH` -> the gene-set ID type differs from the analysis key type (`--feature-id-type`), or the file's IDs do not look like the declared type -> supply gene sets in the analysis ID type, or re-key the input; omicstat does not convert IDs.
- `OS_GENE_SET_SPECIES_MISMATCH` -> the declared gene-set species differs from the analysis species -> use gene sets of the analysed species.
- `OS_GENE_SET_LOW_OVERLAP` -> under 10% of the set genes occur in the analysed features -> usually the wrong ID type, Ensembl version suffixes or species; check both ID types.
