# Original non-QBA scientific warning guards copied from the same pinned source.
# Only identifiers, operator wording, units and output paths are adapted.
AG_RULE_CODES <- sprintf("OAG-%02d", 1:18)
ag_qc_new <- function() {
  data.frame(code = character(0), severity = character(0), analysis_id = character(0),
             message = character(0), evidence = character(0), action = character(0),
             note = character(0), artifact = character(0), stringsAsFactors = FALSE)
}

ag_qc_add <- function(qc, code, severity, analysis_id, message, evidence, action, artifact,
                      note = NULL) {
  if (!code %in% AG_RULE_CODES) {
    stop(sprintf("OS_INVALID_PARAMETER: '%s' is not a documented AG rule code.", code), call. = FALSE)
  }
  if (!severity %in% c("error", "warning", "note")) {
    stop(sprintf("OS_INVALID_PARAMETER: severity must be error/warning/note, got '%s'.", severity), call. = FALSE)
  }
  if (is.null(note)) note <- action
  if (grepl("(^|[^A-Za-z0-9_-])--[A-Za-z]", note)) {
    stop(sprintf("OS_INVALID_PARAMETER: the reader-facing note for %s names a command-line flag.", code),
         call. = FALSE)
  }
  rbind(qc, data.frame(code = code, severity = severity, analysis_id = analysis_id,
                       message = message, evidence = evidence, action = action,
                       note = note, artifact = artifact, stringsAsFactors = FALSE))
}

ag_qc_kappa <- function(qc, analysis_id, res, labels, thresholds) {
  # OAG-06: sparse expected cells, out-of-bounds analytic CI, bootstrap failures.
  if (is.finite(res$min_expected) && res$min_expected < 5) {
    qc <- ag_qc_add(qc, "OAG-06", "warning", analysis_id,
                    "At least one expected cell count is below 5, so the large-sample interval is approximate.",
                    sprintf("smallest expected cell count %s", ag_fmt(res$min_expected, 2)),
                    "Report the interval as approximate, or rerun with the bootstrap interval method and more data.",
                    "tables/effect_table.csv",
                    note = "The interval should be read as approximate; a sparse table makes the large-sample standard error unreliable.")
  }
  for (r in res$coefficients) {
    if (is.finite(r$ci_lower) && is.finite(r$ci_upper) && (r$ci_lower < -1 || r$ci_upper > 1)) {
      qc <- ag_qc_add(qc, "OAG-06", "warning", analysis_id,
                      sprintf("The analytic interval for %s extends outside the parameter range [-1, 1] and is retained without truncation.",
                              r$coefficient),
                      sprintf("%s interval [%s, %s]", r$coefficient, ag_fmt(r$ci_lower), ag_fmt(r$ci_upper)),
                      "Prefer --ci-method bootstrap, or interpret the interval as an approximation only.",
                      "tables/effect_table.csv",
                      note = "The interval is retained as reported and should be read as an approximation only.")
    }
    if (!is.na(r$bootstrap_failures) && r$bootstrap_failures > 0) {
      qc <- ag_qc_add(qc, "OAG-06", "warning", analysis_id,
                      sprintf("%d bootstrap replicate(s) for %s failed and were dropped from the percentile interval.",
                              r$bootstrap_failures, r$coefficient),
                      sprintf("%d of %d replicates succeeded", r$bootstrap_success, r$bootstrap_reps),
                      "Increase --bootstrap-reps or check for near-degenerate resamples.",
                      "tables/effect_table.csv",
                      note = "The percentile interval rests on the replicates that succeeded, and the number of them is reported with the interval.")
    }
  }
  # OAG-07: paradox.
  if (!is.null(res$binary) && isTRUE(res$paradox$triggered)) {
    qc <- ag_qc_add(qc, "OAG-07", "warning", analysis_id,
                    paste0("The prespecified OmicStat kappa-paradox rule fired: chance-corrected agreement is depressed ",
                           "by imbalanced marginals, so PABAK and the prevalence and bias indices are promoted from the ",
                           "sensitivity block to the main table."),
                    paste(res$paradox$reasons, collapse = "; "),
                    "Read Cohen's kappa together with PABAK and the two indices; never report PABAK alone as a corrected kappa.",
                    "tables/effect_table.csv")
  }
  # OAG-08: marginal divergence.
  if (!is.null(res$binary)) {
    if (abs(res$binary$bias_index) >= thresholds$paradox_bias_index) {
      qc <- ag_qc_add(qc, "OAG-08", "warning", analysis_id,
                      "The two raters differ materially in how often they use the two categories.",
                      sprintf("bias index %s (suite guardrail %s); off-diagonal counts %d and %d",
                              ag_fmt(res$binary$bias_index), ag_fmt(thresholds$paradox_bias_index),
                              as.integer(res$binary$b), as.integer(res$binary$c)),
                      "Show the rater marginals alongside the coefficient and describe the direction of disagreement.",
                      "tables/rater_marginals.csv")
    }
  } else {
    p1 <- res$marginals$rater_1_prop; p2 <- res$marginals$rater_2_prop
    tv <- sum(abs(p1 - p2)) / 2
    if (is.finite(tv) && tv > thresholds$marginal_tv_distance) {
      qc <- ag_qc_add(qc, "OAG-08", "warning", analysis_id,
                      "The two raters' category distributions diverge materially.",
                      sprintf("total-variation distance between the rater marginals %s (suite guardrail %s, disclosed as a guardrail rather than a universal cutoff)",
                              ag_fmt(tv), ag_fmt(thresholds$marginal_tv_distance)),
                      "Show the rater marginals alongside the coefficient and describe which categories drive the divergence.",
                      "tables/rater_marginals.csv")
    }
  }
  qc
}

ag_qc_ba <- function(qc, analysis_id, ba, thresholds, units) {
  if (!isTRUE(ba$clinical_limits_supplied)) {
    qc <- ag_qc_add(qc, "OAG-12", "warning", analysis_id,
                    paste0("No prespecified acceptability limits were prespecified, so this Bland-Altman analysis is ",
                           "descriptive only. The report is therefore blocked from asserting that the two methods can ",
                           "be substituted for one another or that the observed differences fall within an acceptable ",
                           "range, because there is no prespecified benchmark to judge them against."),
                    "--acceptability-limit-lower and --acceptability-limit-upper were not supplied",
                    "Prespecify the acceptable difference interval from the measurement use of the measurement, then rerun.",
                    "draft/methods.txt",
                    note = "Prespecify the acceptable difference interval from the measurement use of the measurement, then rerun; until then the analysis stays descriptive.")
  }
  d <- ba$diagnostics
  if (is.finite(d$heteroscedastic_rho) && abs(d$heteroscedastic_rho) >= thresholds$ba_spearman_rho &&
      is.finite(d$heteroscedastic_p) && d$heteroscedastic_p < 0.05) {
    qc <- ag_qc_add(qc, "OAG-13", "warning", analysis_id,
                    "The absolute difference varies with the magnitude of the measurement (heteroscedastic pattern).",
                    sprintf("Spearman rho between the absolute difference and the pair mean %s, %s (exploratory suite guardrail: absolute rho at or above %s with p below 0.05)",
                            ag_fmt(d$heteroscedastic_rho), ag_fmt_p(d$heteroscedastic_p), ag_fmt(thresholds$ba_spearman_rho)),
                    "Report the limits as approximate across the measurement range; this module never auto-transforms or auto-adjusts for proportional bias.",
                    "figures/bland_altman.png")
  }
  if (is.finite(d$trend_rho) && abs(d$trend_rho) >= thresholds$ba_spearman_rho &&
      is.finite(d$trend_p) && d$trend_p < 0.05) {
    qc <- ag_qc_add(qc, "OAG-13", "warning", analysis_id,
                    "The signed difference is associated with the magnitude of the measurement (proportional-bias pattern).",
                    sprintf("Spearman rho between the difference and the pair mean %s, %s",
                            ag_fmt(d$trend_rho), ag_fmt_p(d$trend_p)),
                    "Describe the trend in the Results; a proportional-bias adjustment changes the estimand and must be requested deliberately.",
                    "figures/bland_altman.png")
  }
  if (is.finite(d$max_abs_studentized) && d$max_abs_studentized > thresholds$ba_studentized) {
    qc <- ag_qc_add(qc, "OAG-13", "warning", analysis_id,
                    "At least one difference is influential relative to the rest.",
                    sprintf("largest externally studentized difference %s (suite guardrail above %s)",
                            ag_fmt(d$max_abs_studentized), ag_fmt(thresholds$ba_studentized)),
                    "Check the pair for a transcription or unit error; do not delete it silently.",
                    "tables/pairs.csv")
  }
  if (is.finite(d$shapiro_p) && d$shapiro_p < 0.05) {
    qc <- ag_qc_add(qc, "OAG-13", "warning", analysis_id,
                    "The differences depart from normality, and the limits of agreement assume approximately normal differences.",
                    sprintf("Shapiro-Wilk on the differences, %s", ag_fmt_p(d$shapiro_p)),
                    "Treat the limits as approximate; this is an exploratory flag and does not define agreement.",
                    "tables/effect_table.csv")
  }
  qc
}

ag_qc_release <- function(qc, analysis_id, checks) {
  bad <- Filter(function(c) !isTRUE(c$ok), checks)
  if (length(bad)) {
    qc <- ag_qc_add(qc, "OAG-18", "error", analysis_id,
                    "A release consistency check failed: at least one artifact disagrees with the canonical result object.",
                    paste(vapply(bad, function(c) c$detail, character(1)), collapse = "; "),
                    "Do not release these artifacts; the run is aborted so no inconsistent scientific claim is published.",
                    "machine/<prefix>_results.json")
  }
  qc
}

