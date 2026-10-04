# Troubleshooting — clusterprofiler-gsea

- `OS_MISSING_PARAMETER` -> direct rank input needs metric and positive-score direction.
- `OS_RANKING_UNDIRECTIONAL` -> select a single signed contrast, not an LRT or omnibus F statistic.
- `OS_INVALID_INPUT` -> remove duplicate IDs and nonfinite scores; keep all finite rankable genes.
- `OS_REFDATA_MISSING` -> the requested collection has no pinned offline asset. Use registered GO.
- `OS_EMPTY_DATA` -> no gene set overlaps the ranked IDs within the size bounds; inspect identifier type and set range.
