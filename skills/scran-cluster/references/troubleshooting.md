# Troubleshooting
- OS_MISSING_PARAMETER -> an explicit study choice was omitted -> provide the named flag; examples are not defaults.
- OS_INVALID_INPUT -> assays, labels or IDs fail validation -> provide unique IDs, finite raw counts and appropriate normalized logcounts.
- OS_ECOSYSTEM_MIXED -> a front end changes ecosystems -> continue the original front-end ecosystem.
- OS_HANDOFF_MISMATCH -> hashes or state differ -> rerun the upstream producer; do not edit handoff metadata.
- OS_BATCH_CORRECTED_INPUT -> corrected values enter inference -> use original logcounts/counts and batch metadata.
- OS_REFDATA_MISSING -> an offline licensed collection is unavailable -> provision approved data outside the analysis run.
- OS_ENGINE_WARNING -> a locked package reported a warning -> inspect qc/engine_warnings.csv.
