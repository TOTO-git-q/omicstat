# Troubleshooting — clusterprofiler-ora

- `OS_MISSING_PARAMETER` for direct input -> provide selected IDs, the eligible universe, and its selection rule.
- `OS_INVALID_UNIVERSE` -> use every gene eligible for the stated selection; ensure selected IDs are within it.
- `OS_REFDATA_MISSING` -> the requested collection is not registered and installed offline. Use registered GO or have the owner pin the collection.
- `OS_EMPTY_DATA` -> no GO term had a testable overlap under the supplied IDs and size range; check key type and selection rule.
- CO-01 -> some IDs failed annotation mapping; review `--key-type` and the pinned OrgDb version.

## User-supplied gene sets

- `OS_MISSING_PARAMETER` (user file without provenance) -> source, version and identifier type are never guessed -> give `--gene-sets-provenance` or `--gene-sets-source`, `--gene-sets-version` and `--gene-sets-id-type`.
- `OS_REFDATA_MISMATCH` -> the file's SHA-256 differs from the provenance `sha256` (edited after download, or another file's provenance) -> supply the matching pair.
- `OS_GENE_SET_ID_MISMATCH` -> the gene-set ID type differs from the analysis key type (`--key-type`), or the file's IDs do not look like the declared type -> supply gene sets in the analysis ID type, or re-key the input; omicstat does not convert IDs.
- `OS_GENE_SET_SPECIES_MISMATCH` -> the declared gene-set species differs from the analysis species -> use gene sets of the analysed species.
- `OS_GENE_SET_LOW_OVERLAP` -> under 10% of the set genes occur in the analysed features -> usually the wrong ID type, Ensembl version suffixes or species; check both ID types.
