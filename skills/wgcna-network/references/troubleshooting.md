# Troubleshooting

OS_INVALID_INPUT -> nonfinite or constant data -> explicitly preprocess and document exclusions.

OS_INVALID_DESIGN -> numeric traits missing or not matched -> supply one row per expression sample.

OS_BATCH_CORRECTED_INPUT -> corrected lineage -> supply uncorrected normalized expression.

OS_HANDOFF_MISMATCH -> invalid checksum, object type or scale -> regenerate upstream.

OS_MISSING_PARAMETER -> no power or rationale -> select power from fit and mean connectivity, then record it.
