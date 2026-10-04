# sva_batch_qc.R -- qc layer of module sva-batch. ASCII only on purpose.
#
# Rules SB-01..SB-08 (references/qc-rules.md: criterion, severity, source).
# Input-state rules (SB-01..SB-04) are decided BEFORE the correction is
# computed (sb_input_qc): a triggered blocker stops the run after writing
# qc/qc_results.csv, exactly like DW-01..DW-03 in deseq2-wald. Design
# problems that make the model unfittable (full confounding, a study-variable
# contrast or covariate confounded with the batch in the joint design, a
# non-full-rank mod/mod0, a continuous study variable given to ComBat_seq) are typed
# errors raised in sva_batch_core.R and never reach this table -- mirrors
# deseq2-wald's dw_design not-full-rank stop.

sb_input_qc <- function(cs, method, batch_factor) {
  is_count_method <- method %in% SB_COUNT_METHODS
  is_known_batch <- method %in% SB_KNOWN_BATCH_METHODS
  batch_tab <- if (is_known_batch) table(batch_factor) else integer(0)
  rows <- list(
    os_qc_rule("SB-01", "integer_counts", is_count_method && cs$n_non_integer > 0, "blocker",
               sprintf("%d count cell(s) are not whole numbers; --method %s models raw counts.", cs$n_non_integer, method),
               "Supply the un-normalized integer count matrix; never TPM, FPKM, CPM or an already batch-corrected matrix.",
               "sva vignette 'ComBat-Seq for batch adjustment on RNA-Seq count data' ('preserve the integer nature'); svaseq Rd (moderated log transform of counts)"),
    os_qc_rule("SB-02", "negative_counts", is_count_method && cs$n_negative > 0, "blocker",
               sprintf("%d count cell(s) are negative.", cs$n_negative),
               "Counts cannot be negative: the matrix is not a count matrix (check for log-transformed or centred data).",
               "sva vignette 'ComBat-Seq for batch adjustment on RNA-Seq count data'"),
    os_qc_rule("SB-03", "batch_levels_minimum", is_known_batch && length(batch_tab) < 2, "blocker",
               sprintf("--batch has %d level(s); a batch effect needs at least 2.", length(batch_tab)),
               "Supply a --batch column with at least 2 levels, or use --method sva/svaseq if the batch is unknown.",
               "ENGINEERING_PLAN 4.5 (design class); ComBat/ComBat_seq Rd ('Batch covariate')"),
    os_qc_rule("SB-04", "batch_samples_minimum", is_known_batch && length(batch_tab) >= 2 && any(batch_tab < 2), "blocker",
               sprintf("Samples per --batch level: %s; ComBat/ComBat_seq (mean.only = FALSE) needs at least 2 per level to estimate a batch variance.",
                       paste(sprintf("%s = %d", names(batch_tab), as.integer(batch_tab)), collapse = ", ")),
               "Add samples to the small batch level, or drop it before correcting.",
               "sva vignette 'Applying the ComBat function to adjust for known batches' (mean.only option; default adjusts mean AND variance)"))
  rows
}

sva_batch_qc <- function(input_rows, r, a, elog) {
  n_warn <- os_engine_counts(elog)[["warning"]] %||% 0L
  confound_partial <- identical(r$confound$status, "partial")
  is_sv_method <- a$method %in% SB_UNKNOWN_BATCH_METHODS
  n_sv_high <- is_sv_method && !is.na(r$n.sv) && r$n.sv > 0 && r$n.sv >= floor(r$n_samples / 3)
  rows <- c(input_rows, list(
    os_qc_rule("SB-05", "batch_study_var_confounded", a$method %in% SB_KNOWN_BATCH_METHODS && confound_partial, "warning",
               sprintf("--batch and --study-var are partially confounded: %s of the batch x study-variable cells are empty (%s).",
                       r$confound$empty_cells %||% NA_integer_, r$confound$estimability_check %||% "no estimability check recorded"),
               paste0("Every study-variable coefficient was checked estimable in the joint design, but contrasts between levels that never share a batch ",
                      "rest on the additive batch model; report the cross-table (tables/batch_report.md) alongside the result."),
               "PACK S1 appendix P-2 (joint estimability of batch and the study variable)"),
    os_qc_rule("SB-06", "no_surrogate_variables", is_sv_method && !is.na(r$n.sv) && r$n.sv == 0, "warning",
               "num.sv estimated 0 surrogate variables; the display matrix equals the input (nothing was regressed out).",
               "No hidden batch structure was detected at the current num.sv method/seed; try --num-sv-method leek as a sensitivity check before concluding there is none.",
               "sva.Rd / svaseq.Rd ('the number of surrogate variables to use'); sva vignette sec 4"),
    os_qc_rule("SB-07", "many_surrogate_variables", n_sv_high, "info",
               sprintf("num.sv estimated %d surrogate variable(s) for %d samples (>= 1/3 of the samples).", if (is.na(r$n.sv)) 0L else r$n.sv, r$n_samples),
               "Many surrogate variables leave few residual degrees of freedom for the downstream DE design; inspect them before adding all of them.",
               "ENGINEERING_PLAN 4.5 (design class, general degrees-of-freedom caution)"),
    os_qc_rule("SB-08", "engine_warnings", n_warn > 0, "warning",
               sprintf("%d warning(s) were raised by sva/limma during the run.", n_warn),
               "Read qc/engine_warnings.csv before reporting the correction.",
               "_shared engine contract (CONVENTIONS sec 15)")))
  os_qc_finalize(rows, read_first = "draft/methods_results.md")
}
