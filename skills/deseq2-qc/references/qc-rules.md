# qc-rules -- deseq2-qc

Every rule is evaluated on every run and written to `qc/qc_results.csv` (one row per rule,
triggered or not; columns `id, check, severity, triggered, blocking, message, action, evidence`).
A triggered **blocker** withholds the Methods/Results draft; DQ-01..DQ-03 are decided on the input
before any transform is computed, so a triggered one stops the run with `OS_QC_BLOCKER` after
writing the QC table. Criteria are mechanical; code: `scripts/deseq2_qc_qc.R`.

**P-2 (sample-outlier statistic/threshold) is class C, pending the module owner.** No rule below
turns a PCA score or sample distance into an outlier call, a warning keyed to a
threshold, or an automatic removal; `tables/sample_qc_descriptive.csv` is descriptive display only.

| Rule | Severity | Blocking | Criterion | Action | Source |
|---|---|---|---|---|---|
| DQ-01 | blocker | yes | any count cell is not a whole number (tolerance 1e-8) | supply raw integer counts (featureCounts / tximport counts), never TPM, FPKM, CPM or batch-corrected values | vignette "Why un-normalized counts?" |
| DQ-02 | blocker | yes | any count cell is negative | the matrix is not counts (log-transformed or centred data) | vignette "Why un-normalized counts?" |
| DQ-03 | blocker | yes | fewer than 3 samples in the input | add samples; `prcomp` cannot produce two non-trivial principal components (PCs 1:2) with fewer than 3 samples | `?plotPCA` (`pcsToUse = 1:2`); ENGINEERING_PLAN 4.5 (design class) |
| DQ-04 | warning | no | a `--condition` level has exactly 1 sample | within-group comparison is unavailable; read the PCA/distance figures directly | PACK T (descriptive per-sample table); ENGINEERING_PLAN 4.5 (design class) |
| DQ-05 | info | no | fewer than 1,000 pre-filtered features have mean normalized count > 5 and `--transform vst` | `vst()` cannot subsample the required rows; the engine uses `varianceStabilizingTransformation()` instead -- state the direct transformation in the Methods | `?vst`; NEWS 1.9.42 (PACK X) |
| DQ-06 | warning | no | DESeq2 printed "a local regression fit was automatically substituted" (parametric dispersion trend failed) | state the local fit in the Methods or rerun with `--fit-type local` | `?estimateDispersions`; vignette "Local or mean dispersion fit" |
| DQ-07 | warning | no | DESeq2 raised at least one warning (`qc/engine_warnings.csv`) | read the warnings before reporting anything from this run | `_shared` engine contract (CONVENTIONS sec 15) |

Design problems that make the model unfittable are typed errors, not rules: a design that is not
full rank (a covariate confounded with `--condition`) stops with `OS_INVALID_DESIGN` before DESeq2
runs; matrix columns and sample table that disagree stop with `OS_INVALID_DESIGN`; a complex design
(covariates, or 3+ condition levels) without an explicit `--min-samples` stops with
`OS_MISSING_PARAMETER`.

Console line at the end of every run: `N of 7 rules triggered; read X first`, where X is
`qc/qc_results.csv` when any rule fired and `draft/methods_results.md` otherwise.
