# Troubleshooting

- `OS_HANDOFF_MISMATCH` for ranked_list -> upstream lacks the exact typed feature_id,symbol,score file or its hash changed -> regenerate the upstream full ranking.
- `OS_INVALID_INPUT` for scores -> values are nonfinite, duplicate, or unsorted -> export all rankable genes with finite directional Wald statistics or moderated t, descending.
- `OS_REFDATA_MISSING` -> collection is not pinned for the locked image -> register version, asset and SHA-256 offline before running; Hallmark needs owner M1-3.
- `OS_REFDATA_MISMATCH` -> local GMT differs from its registry hash -> restore the locked asset.
- No significant sets -> inspect the full table and ranking provenance; do not subset to significant genes and rerun as preranked GSEA.

## User-supplied gene sets

- `OS_MISSING_PARAMETER` (user file without provenance) -> source, version and identifier type are never guessed -> give `--gene-sets-provenance` or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`.
- `OS_REFDATA_MISMATCH` -> the file's SHA-256 differs from the provenance `sha256` (edited after download, or another file's provenance) -> supply the matching pair.
- `OS_GENE_SET_ID_MISMATCH` -> the gene-set ID type differs from the analysis key type (`--feature-id-type`), or the file's IDs do not look like the declared type -> supply gene sets in the analysis ID type, or re-key the input; omicstat does not convert IDs.
- `OS_GENE_SET_SPECIES_MISMATCH` -> the declared gene-set species differs from the analysis species -> use gene sets of the analysed species.
- `OS_GENE_SET_LOW_OVERLAP` -> under 10% of the set genes occur in the analysed features -> usually the wrong ID type, Ensembl version suffixes or species; check both ID types.
