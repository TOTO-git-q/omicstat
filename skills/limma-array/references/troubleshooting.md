# Troubleshooting

- `OS_MISSING_PARAMETER: supply --control-ids` -> the engine cannot know control probes -> provide IDs or declare upstream removal.
- `OS_MISSING_PARAMETER: non-Agilent platforms require` -> no preset is frozen -> supply both `--trend` and `--robust` explicitly and inspect the mean-variance diagnostic.
- `OS_INVALID_INPUT: above-background data` -> the detection matrix does not align exactly -> provide 0/1 data with the same probe and array IDs.
- `OS_INVALID_DESIGN` -> the comparison is not estimable -> revise the condition and covariate design.
- `OS_INVALID_DESIGN: condition has K levels` -> more than two groups are present -> add `--keep-other-levels` to fit them all (only target vs reference is tested) or subset the arrays upstream.
- `OS_MISSING_COLUMN: --probe-annotation` -> the annotation needs `feature_id`, `symbol`, `entrez` columns (empty values are allowed and reported as unmapped).
- `OS_INVALID_INPUT: no retained probe ID occurs in the probe annotation` -> the annotation is keyed by another ID type -> key it by the matrix probe IDs.
- `OS_INVALID_PARAMETER: --background-k exceeds` -> k is larger than the number of arrays.
