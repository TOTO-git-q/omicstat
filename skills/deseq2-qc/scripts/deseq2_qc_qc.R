# deseq2_qc_qc.R -- qc layer of module deseq2-qc. ASCII only on purpose.
#
# Rules DQ-01..DQ-07 (references/qc-rules.md: criterion, severity, source).
# Input-state rules are decided BEFORE anything is transformed (dq_input_qc):
# a triggered blocker there stops the run after writing qc/qc_results.csv.
# Result rules are decided after the transform (deseq2_qc_qc).
#
# P-2 (sample-outlier statistic/threshold) is class C, pending the owner:
# there is NO rule here that turns a PCA or distance number into an outlier
# call. The descriptive per-sample table (dq_sample_table) is display only.

dq_input_qc <- function(cs, condition_counts) {
  rows <- list(
    os_qc_rule("DQ-01", "integer_counts", cs$n_non_integer > 0, "blocker",
               sprintf("%d count cell(s) are not whole numbers; DESeq2 models raw counts, not normalized or transformed values.", cs$n_non_integer),
               "Supply the un-normalized integer count matrix (e.g. featureCounts / tximport counts); never TPM, FPKM, CPM or batch-corrected values.",
               "DESeq2 vignette, 'Why un-normalized counts?'"),
    os_qc_rule("DQ-02", "negative_counts", cs$n_negative > 0, "blocker",
               sprintf("%d count cell(s) are negative.", cs$n_negative),
               "Counts cannot be negative: the matrix is not a count matrix (check for log-transformed or centred data).",
               "DESeq2 vignette, 'Why un-normalized counts?'"),
    os_qc_rule("DQ-03", "samples_minimum_for_pca", cs$n_samples < DQ_MIN_SAMPLES_FOR_PCA, "blocker",
               sprintf("%d sample(s) in the input; the fixed PCs 1:2 plot needs at least %d samples.", cs$n_samples, DQ_MIN_SAMPLES_FOR_PCA),
               "Add samples; with fewer than 3, prcomp cannot produce two non-trivial principal components.",
               "DESeq2 Rd ?plotPCA (pcsToUse = 1:2); ENGINEERING_PLAN 4.5 (design class)"),
    os_qc_rule("DQ-04", "condition_singleton_group", any(condition_counts$status == "warning"), "warning",
               sprintf("A --condition level has exactly 1 sample (%s): within-group comparison is not available.",
                       paste(sprintf("%s = %d", condition_counts$condition[condition_counts$status == "warning"],
                                    condition_counts$n_replicates[condition_counts$status == "warning"]), collapse = ", ")),
               "Read the PCA and sample-distance figures directly; do not infer a sample-outlier verdict.",
               "PACK T (descriptive per-sample table); ENGINEERING_PLAN 4.5 (design class)"))
  rows
}

deseq2_qc_qc <- function(input_rows, res, elog) {
  n_warn <- os_engine_counts(elog)[["warning"]] %||% 0L
  et <- os_engine_table(elog)
  disp_fallback <- any(et$type == "message" & grepl("local regression fit was automatically substituted", et$message, fixed = TRUE))
  rows <- c(input_rows, list(
    os_qc_rule("DQ-05", "vst_nsub_fallback", res$transform$fallback, "info",
               sprintf("Only %d of %d pre-filtered features had mean normalized count > 5; vst() needs %d, so the engine used varianceStabilizingTransformation() instead.",
                       res$transform$n_eligible, nrow(res$transform$assay), DQ_VST_NSUB),
               "State the direct (non-subsampled) variance-stabilizing transformation in the Methods.",
               "DESeq2 vst() Rd / NEWS 1.9.42 (PACK X)"),
    os_qc_rule("DQ-06", "dispersion_fit_fallback", disp_fallback, "warning",
               "The parametric dispersion trend did not fit; DESeq2 substituted a local regression fit.",
               "State the local fit in the Methods, or rerun with --fit-type local so the choice is explicit.",
               "?estimateDispersions (fitType); DESeq2 vignette 'Local or mean dispersion fit'"),
    os_qc_rule("DQ-07", "engine_warnings", n_warn > 0, "warning",
               sprintf("DESeq2 raised %d warning(s) during the run.", n_warn),
               "Read qc/engine_warnings.csv before reporting anything from this run.",
               "_shared engine contract (CONVENTIONS sec 15)")))
  os_qc_finalize(rows, read_first = "draft/methods_results.md")
}
