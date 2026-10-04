# Troubleshooting

- OS_MISSING_PARAMETER -> a scientific choice or input is missing -> supply the required argument; tutorial examples are not defaults.
- OS_INVALID_COUNTS -> fractional, negative, nonfinite or empty counts -> supply raw UMI counts.
- OS_MITO_FEATURES -> mitochondrial pattern matches no genes -> check species and identifiers.
- OS_CHAIN_STATE -> missing or incompatible upstream state -> run seurat-qc then seurat-cluster and use --from-run.
- OS_ECOSYSTEM_MIXED -> other front-end ecosystem -> start a separate chain in that ecosystem.
- OS_HANDOFF_MISMATCH -> changed upstream file or wrong type -> restore upstream output; do not edit its JSON.
- OS_BATCH_CORRECTED_INPUT -> corrected matrix lineage -> provide an uncorrected chain.
- OS_PSEUDOREPLICATION -> condition inference requested across cells -> use muscat-pseudobulk with biological replicates.
