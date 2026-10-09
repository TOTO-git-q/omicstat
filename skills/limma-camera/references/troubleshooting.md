# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `OS_REFDATA_MISSING` | Default Hallmark entry is unresolved offline. | Use a SHA-256 registered local collection, such as `limma_gender_genes` for acceptance. |
| `OS_HANDOFF_MISMATCH` | Upstream object is ambiguous, malformed, or tampered. | Select one `--upstream-object` and inspect its handoff manifest. |
| `OS_INVALID_DESIGN` | Groups are insufficient or model terms are collinear. | Supply two groups with at least two samples each and a full-rank design. |
| `OS_UNSUPPORTED_DESIGN` | A rank-only input was sent to a self-contained test, or block was sent to camera. | Choose the question and an input the method supports. |
| Printed camera anchor differs | limma >= 3.66.0 voom uses adaptive.span = TRUE; the guide was printed with span 0.5. | The guide-path anchor uses `voom(..., adaptive.span = FALSE)` and matches; the suite route keeps the locked default (S4_ANCHOR_TRACE). |
| `OS_UNSUPPORTED_DESIGN` from a limma-dupcor run | camera cannot model the upstream block. | Ask a self-contained question (fry/roast/mroast use the block) or add `--acknowledge-block-ignored` (LC-06). |
| `OS_CONFLICTING_PARAMETERS` with `--from-run` of a limma run | A flag would rebuild the upstream design, contrast, weights or block, or override ranked_list metadata. | Drop the flag; the upstream objects are used unchanged. |
| `OS_BATCH_CORRECTED_INPUT` | The object is batch-corrected or of a corrected lineage. | Test uncorrected data with batch in the design. |

## User-supplied gene sets

- `OS_MISSING_PARAMETER` (user file without provenance) -> source, version and identifier type are never guessed -> give `--gene-sets-provenance` or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`.
- `OS_REFDATA_MISMATCH` -> the file's SHA-256 differs from the provenance `sha256` (edited after download, or another file's provenance) -> supply the matching pair.
- `OS_GENE_SET_ID_MISMATCH` -> the gene-set ID type differs from the analysis key type (`--feature-id-type`), or the file's IDs do not look like the declared type -> supply gene sets in the analysis ID type, or re-key the input; omicstat does not convert IDs.
- `OS_GENE_SET_SPECIES_MISMATCH` -> the declared gene-set species differs from the analysis species -> use gene sets of the analysed species.
- `OS_GENE_SET_LOW_OVERLAP` -> under 10% of the set genes occur in the analysed features -> usually the wrong ID type, Ensembl version suffixes or species; check both ID types.
