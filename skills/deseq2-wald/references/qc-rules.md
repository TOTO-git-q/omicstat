# qc-rules -- deseq2-wald

Every rule is evaluated on every run and written to `qc/qc_results.csv` (one row per rule,
triggered or not; columns `id, check, severity, triggered, blocking, message, action, evidence`).
A triggered **blocker** withholds the Methods/Results draft; DW-01..DW-03 are decided on the input
before anything is fitted, so a triggered one stops the run with `OS_QC_BLOCKER` after writing the
QC table. Criteria are mechanical; code: `scripts/deseq2_wald_qc.R`.

| Rule | Severity | Blocking | Criterion | Action | Source |
|---|---|---|---|---|---|
| DW-01 | blocker | yes | any count cell is not a whole number (tolerance 1e-8) | supply raw integer counts (featureCounts / tximport counts), never TPM, FPKM, CPM or batch-corrected values | vignette "Why un-normalized counts?" |
| DW-02 | blocker | yes | any count cell is negative | the matrix is not counts (log-transformed or centred data) | vignette "Why un-normalized counts?" |
| DW-03 | blocker | yes | a compared group (`--reference` or `--target`) has < 2 biological replicates | add biological replicates; without them the dispersion is not estimable from the data | ENGINEERING_PLAN 4.5 (design class); vignette FAQ on data without replicates |
| DW-04 | warning | no | a compared group has 2 replicates (< 3) | report replicate numbers next to every result; power is low | ENGINEERING_PLAN 4.5 (design class) |
| DW-05 | error | no | every adjusted P value is NA | check the pre-filter, the replicate numbers and `qc/engine_warnings.csv` | ENGINEERING_PLAN 4.5 (numeric degeneracy) |
| DW-06 | warning | no | more than 50% of tested features have padj < `--alpha` | inspect the sample PCA (deseq2-qc) for a confounded design, sample swap or normalization problem before reporting | ENGINEERING_PLAN 4.5 ("all features significant"); the 50% line is this module's S1 choice |
| DW-07 | info | no | at least one feature has padj = NA because of a Cook's distance outlier | the features carry `filtered_reason = outlier`; look at their counts | vignette "Approach to count outliers"; `?results` (`cooksCutoff`) |
| DW-08 | info | no | at least one feature was removed by independent filtering | report the number tested, not the number supplied | vignette "Independent filtering of results" |
| DW-09 | warning | no | DESeq2 / apeglm raised at least one warning (`qc/engine_warnings.csv`) | read the warnings: a failed parametric dispersion fit or rows that did not converge change how results are read | CONVENTIONS sec 15 |
| DW-10 | warning | no | `--gene-annotation` given and > 5% of tested features have no symbol | check that the annotation matches the ID space and release of the counts | CONVENTIONS sec 8 |
| DW-11 | warning | no | DESeq2 printed "a local regression fit was automatically substituted" (parametric dispersion trend failed) | state the local fit in the Methods or rerun with `--fit-type local` | `?estimateDispersions`; vignette "Local or mean dispersion fit" |
| DW-12 | info | no | at least one feature has `mcols(dds)$betaConv == FALSE` | check those features before reporting them | `?nbinomWaldTest` |

Design problems that make the model unfittable are typed errors, not rules: a design that is not
full rank (condition confounded with a covariate) stops with `OS_INVALID_DESIGN` before DESeq2 runs;
matrix columns and sample table that disagree stop with `OS_INVALID_DESIGN`; unknown levels stop
with `OS_INVALID_PARAMETER`.

Console line at the end of every run: `N of 12 rules triggered; read X first`, where X is
`qc/qc_results.csv` when any rule fired and `draft/methods_results.md` otherwise.
