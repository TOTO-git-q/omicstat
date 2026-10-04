# qc-rules -- sva-batch

Every rule is evaluated on every run and written to `qc/qc_results.csv` (one row per rule,
triggered or not; columns `id, check, severity, triggered, blocking, message, action, evidence`).
A triggered **blocker** withholds the Methods/Results draft; SB-01..SB-04 are decided on the input
before anything is corrected, so a triggered one stops the run with `OS_QC_BLOCKER` after writing
the QC table. Criteria are mechanical; code: `scripts/sva_batch_qc.R`.

| Rule | Severity | Blocking | Criterion | Action | Source |
|---|---|---|---|---|---|
| SB-01 | blocker | yes | `--method combat_seq`/`svaseq` and any count cell is not a whole number (tolerance 1e-8) | supply raw integer counts; never TPM, FPKM, CPM or an already batch-corrected matrix | sva vignette 'ComBat-Seq for batch adjustment on RNA-Seq count data' ('preserve the integer nature'); svaseq Rd |
| SB-02 | blocker | yes | `--method combat_seq`/`svaseq` and any count cell is negative | the matrix is not counts (log-transformed or centred data) | sva vignette 'ComBat-Seq for batch adjustment on RNA-Seq count data' |
| SB-03 | blocker | yes | `--method combat`/`combat_seq` and `--batch` has fewer than 2 levels | supply a `--batch` with >= 2 levels, or use `--method sva`/`svaseq` if the batch is unknown | ENGINEERING_PLAN 4.5 (design class); ComBat/ComBat_seq Rd ('Batch covariate') |
| SB-04 | blocker | yes | `--method combat`/`combat_seq` and a `--batch` level has fewer than 2 samples | add samples to the small batch level, or drop it before correcting | sva vignette (ComBat's default adjusts mean AND variance; `mean.only = FALSE` needs a per-batch variance) |
| SB-05 | warning | no | `--method combat`/`combat_seq`, categorical `--study-var`: the joint design (batch + covariates + study variable, built as ComBat builds it) is full rank and every study-variable coefficient was checked estimable, but at least one batch x study-variable cell is empty (partial confounding) | contrasts between levels that never share a batch rest on the additive batch model; report the cross-table and the estimability check (both written to `tables/batch_report.md` and the draft) | PACK S1 appendix P-2 (joint estimability of batch and the study variable) |
| SB-06 | warning | no | `--method sva`/`svaseq` and `num.sv` estimated 0 surrogate variables | the display matrix equals the input; try `--num-sv-method leek` as a sensitivity check before concluding there is no hidden structure | sva.Rd / svaseq.Rd; sva vignette sec 4 |
| SB-07 | info | no | `--method sva`/`svaseq` and `num.sv` estimated at least 1/3 as many surrogate variables as samples | many surrogate variables leave few residual degrees of freedom for the downstream DE design; inspect before adding all of them | ENGINEERING_PLAN 4.5 (design class, general degrees-of-freedom caution) |
| SB-08 | warning | no | sva/limma raised at least one warning (`qc/engine_warnings.csv`) | read the warnings before reporting the correction | CONVENTIONS sec 15 |

Design problems that make the model unfittable are typed errors, not rules (mirrors deseq2-wald's
not-full-rank stop), all decided before any sva function is called: `--batch` completely confounded with
`--study-var`, a study-variable coefficient that is not estimable jointly with the batch (partial confounding
that leaves a level inside batches no other level shares), a `--covariates` column confounded with the batch
(each `OS_INVALID_DESIGN`, from the joint design check `sb_joint_check()`), a single-level covariate, a
non-full-rank `mod`/`mod0` or a `--study-var` that adds no independent information beyond
`--covariates` (`OS_INVALID_DESIGN`), a continuous `--study-var` given to `--method combat_seq`
(`OS_UNSUPPORTED_DESIGN`, the S1 appendix "待澄清" item), an unknown level or missing column
(`OS_INVALID_PARAMETER` / `OS_MISSING_COLUMN`). None of these reach `qc/qc_results.csv`.

Console line at the end of every run: `N of 8 rules triggered; read X first`, where X is
`qc/qc_results.csv` when any rule fired and `draft/methods_results.md` otherwise.
