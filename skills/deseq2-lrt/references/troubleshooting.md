# deseq2-lrt troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `OS_MISSING_PARAMETER` on min-samples | LRT has no two-group default pre-filter rule | Give an explicit positive `--min-samples` |
| `OS_INVALID_DESIGN` on full/reduced | Models are rank-deficient or not nested | Remove confounding; retain adjustment terms in both formulas |
| `OS_QC_BLOCKER: DL-01/02/03` | Input is not raw counts or design cells lack replicates | Supply integer counts and adequate biological replication |
| `OS_INVALID_PARAMETER` on report-coef | Name is absent from `resultsNames(dds)` | Use a printed coefficient name from the fitted design |
| `OS_MISSING_PARAMETER` on pattern-clustering | Explicit gene list or time field absent | Supply --pattern-genes and --time-col; consult the reference service for the selection rule |
| Empty heatmap/trajectory | Fewer than two LRT-significant features | Read the full table; no figure is claimed |
| Many `padj=NA` | Cook's filtering or independent filtering | Inspect filtered_reason and QC rows DL-07/08 |
