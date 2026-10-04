# deseq2-lrt S4 worklog

Branch `s4/deseq2-qc-lrt`. GT103 run dir `~/omic-build-logs/s4/deseq2-lrt`.

## Verified state
- 2026-09-29: read S3_REVIEW_astra (F1-F3). rnaseqGene workflow source: github mikelove/rnaseqGene
  vignettes/rnaseqGene.Rmd @0d7e27dde3ca (2026-04-14); rendered Bioc 3.23 workflow HTML
  (R 4.6.0 RC, DESeq2_1.52.0) prints head(resTC[order(resTC$padj),], 4) -> printed anchor available.
  Workflow runs the fission LRT with NO pre-filter and results() default alpha = 0.1.
- probe-env (deseq2-qc run dir): workflow code reproduces printed values in the container; results(name = last coef)
  identical to results(); name change leaves P/padj identical; mut-reference fit differs up to 1.6e-5 rel in P.
- F1/F2/F3 DONE (see S4_FIXES.md): f-golden, f-check, f-check2 SMOKE PASSED; lock2 + lockcheck OK;
  figures a0/a1/a2/f3/f2-fallback looked at.

## Next step
- None; final report to coordinator.
