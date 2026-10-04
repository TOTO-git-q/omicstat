# deseq2-lrt QC rules

`DL-01..DL-13` are implemented in `scripts/deseq2_lrt_qc.R`; each result is written to `qc/qc_results.csv`. Input blockers DL-01 to DL-03 stop before fitting and withhold the draft. Full-rank, nested-model and explicit-pre-filter failures are typed design/parameter errors before fitting.

| Rule | Criterion | Source |
|---|---|---|
| DL-01 | non-integer counts, blocker | DESeq2 vignette “Why un-normalized counts?” |
| DL-02 | negative counts, blocker | DESeq2 vignette “Why un-normalized counts?” |
| DL-03 | fewer than two biological replicates in a group (additive model) or interaction cell, blocker | ENGINEERING_PLAN 4.5; DESeq2 vignette replicates FAQ |
| DL-04 | fewer than three replicates in such a group or cell, warning | ENGINEERING_PLAN 4.5 |
| DL-05 | all adjusted P values missing | ENGINEERING_PLAN 4.5 numeric degeneracy |
| DL-06 | more than half of tested features significant | ENGINEERING_PLAN 4.5 numeric degeneracy |
| DL-07 | Cook's outlier features | DESeq2 `results.Rd`; vignette “Approach to count outliers” |
| DL-08 | independent filtering | DESeq2 vignette “Independent filtering of results” |
| DL-09 | engine warnings | shared engine contract |
| DL-10 | symbol mapping loss >5% | CONVENTIONS section 8 |
| DL-11 | dispersion fit fallback | DESeq2 `estimateDispersions.Rd` |
| DL-12 | beta non-convergence | DESeq2 `nbinomLRT.Rd` |
| DL-13 | always remind that one LFC does not describe the joint test | PACK S1 P-3; DESeq2 LRT FAQ |
