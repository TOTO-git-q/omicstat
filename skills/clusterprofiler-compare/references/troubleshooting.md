# Troubleshooting — clusterprofiler-compare

- `OS_MISSING_COLUMN` -> include every required manifest field and `feature_id` in each list/background CSV.
- `OS_INVALID_UNIVERSE` -> give every gene eligible for the list's selection rule; selected genes must be a proper subset.
- CX-01 -> lists do not share one selectable population; inspect list_definitions.csv and interpret separate ORA results.
- `OS_REFDATA_MISSING` -> the requested offline collection is not pinned; use registered GO.
- `OS_EMPTY_DATA` -> no list has a testable GO overlap; verify key type and set-size bounds.

## User-supplied gene sets

- `OS_MISSING_PARAMETER` (user file without provenance) -> source, version and identifier type are never guessed -> give `--gene-sets-provenance` or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`.
- `OS_REFDATA_MISMATCH` -> the file's SHA-256 differs from the provenance `sha256` (edited after download, or another file's provenance) -> supply the matching pair.
- `OS_GENE_SET_ID_MISMATCH` -> the gene-set ID type differs from the analysis key type (`--key-type`), or the file's IDs do not look like the declared type -> supply gene sets in the analysis ID type, or re-key the input; omicstat does not convert IDs.
- `OS_GENE_SET_SPECIES_MISMATCH` -> the declared gene-set species differs from the analysis species -> use gene sets of the analysed species.
- `OS_GENE_SET_LOW_OVERLAP` -> under 10% of the set genes occur in the analysed features -> usually the wrong ID type, Ensembl version suffixes or species; check both ID types.
