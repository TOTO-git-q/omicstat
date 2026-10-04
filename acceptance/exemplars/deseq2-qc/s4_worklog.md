# deseq2-qc S4 worklog

Branch `s4/deseq2-qc-lrt` (from integrate/m1m2 @fb63e52). GT103 run dir `~/omic-build-logs/s4/deseq2-qc`.

## Verified state
- 2026-09-29: read brief, S3_REVIEW_astra (F1 only), S3_REPORT sec 2-5, PACK (C/F/T/W + S1 appendix).
- probe-env: DESeq2 1.52.0 ships extdata/pasilla_gene_counts.tsv.gz + annotation, identical to acceptance pasilla;
  plotPCA.DESeqTransform body printed (rowVars, order decreasing, prcomp, percentVar[pcsToUse]).
- F1 DONE: vignette oracle in smoke test (full matrix, all PCs w/ sign alignment, percentVar, full distances;
  supplement matrix + percentVar); engine writes tables/sample_distances.csv; wording tightened; v1.1.0.
  f1-golden + f1-check SMOKE PASSED; lock + lockcheck OK; 4 PNGs looked at. S4_FIXES.md written.

## Next step
- None for deseq2-qc (commit done with F1). Continue in deseq2-lrt worklog.
