# Troubleshooting

- `OS_HANDOFF_MISMATCH` for ranked_list -> upstream lacks the exact typed feature_id,symbol,score file or its hash changed -> regenerate the upstream full ranking.
- `OS_INVALID_INPUT` for scores -> values are nonfinite, duplicate, or unsorted -> export all rankable genes with finite directional Wald statistics or moderated t, descending.
- `OS_REFDATA_MISSING` -> collection is not pinned for the locked image -> register version, asset and SHA-256 offline before running; Hallmark needs owner M1-3.
- `OS_REFDATA_MISMATCH` -> local GMT differs from its registry hash -> restore the locked asset.
- No significant sets -> inspect the full table and ranking provenance; do not subset to significant genes and rerun as preranked GSEA.
