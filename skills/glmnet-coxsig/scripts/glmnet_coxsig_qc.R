glmnet_coxsig_qc_legacy <- function(res) list(
 os_qc_rule("CXS-01","Candidate signature",TRUE,"blocker","Scientific and production acceptance pending.","Do not publish or apply clinically."),
 os_qc_rule("CXS-02","Training performance",res$metadata$mode=="train","warning","Training ROC is apparent, not independent validation.","Validate the frozen signature in an independent cohort."),
 os_qc_rule("CXS-03","Uninformative risk split",!res$metadata$km_available,"warning","Frozen cutoff leaves fewer than two subjects in a group; KM omitted.","Report the noninformative split without moving the cutoff."))

glmnet_coxsig_qc <- function(res) {
 rows <- glmnet_coxsig_qc_legacy(res); m <- res$metadata
 if (is.null(m$prediction_workup)) return(rows)
 w <- m$cpm_workup
 if (m$mode == "train") {
  s <- res$tables$planning_summary
  source <- .os_cxs_port$run_qc(list(strict = FALSE, n_cc = m$n_biological,
   sample_size = list(sample_size = s$required_n, assumed_source = s$source),
   draft_text = c(res$method, "apparent and optimism-corrected C; numerical calibration slope in calibration_performance.csv"),
   boot_B = w$bootstrap_B_requested, calibration_curve_drawn = nrow(res$tables$calibration_binned) > 0))
  # Only the four applicable source checks are used. No DCA, nomogram, split-sample
  # or binary-outcome calibration guard is asserted for this survival signature.
  ids <- c("CPM-01", "CPM-04", "CPM-05", "CPM-06")
  ids_new <- c("CXS-04", "CXS-05", "CXS-06", "CXS-07")
  for (i in seq_along(ids)) {
   r <- source[source$id == ids[i], , drop = FALSE]
   rows[[length(rows) + 1L]] <- os_qc_rule(ids_new[i], paste("Copied source", ids[i]), r$triggered, "warning", r$message,
    "Read the explicit source-copy limitation and complete numerical tables; do not promote the candidate.")
  }
 }
 c(rows, list(
  os_qc_rule("CXS-08", "Failed bootstrap replicates", w$bootstrap_B_failed > 0, "warning",
   "Some requested training resamples failed; corrected estimates condition on successful fits and may be biased. All attempts are counted, never replaced.", "Inspect the training run's bootstrap_attempts.csv and frozen requested/used/failed counts. Do not relabel them all successful."),
  os_qc_rule("CXS-09", "Calibration bin omissions", w$n_bin_subjects_omitted > 0, "warning",
   "Some subjects are absent from displayed bins because minimum-size or horizon/interval support fails. They remain in original n and accounting.", "Report omitted bins; do not extend follow-up or fabricate zero estimates."),
  os_qc_rule("CXS-10", "Source uncertainty adaptation", TRUE, "warning",
   "Source bootstrap percentile construction is retained, with an actual penalized-model slope. Native coverage and model-equivalence acceptance are not established.", "Treat the numeric interval as the named source construction, not an independently validated confidence guarantee.")))
}
