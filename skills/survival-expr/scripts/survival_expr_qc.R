survival_expr_qc_legacy <- function(res) list(
 os_qc_rule("SRV-01", "Candidate analysis", TRUE, "blocker", "Scientific and production review pending.", "Do not publish candidate inference."),
 os_qc_rule("SRV-02", "Exploratory cutpoint", res$metadata$exploratory_cutpoint, "blocker", "Optimized cutoff is exploratory; logrank p withheld.", "Validate a frozen prespecified cutoff in an independent cohort."),
 os_qc_rule("SRV-03", "PH diagnostics", res$metadata$ph_violations > 0, "warning", "Some PH diagnostics are below the declared threshold; no automatic gene filtering.", "Review model assumptions and a prespecified alternative."),
 os_qc_rule("SRV-04", "Unadjusted gene family", res$metadata$family_size > 1 && res$metadata$adjustment == "none", "warning", "Multiple gene Cox tests are unadjusted.", "Review the declared multiplicity family."))

survival_expr_qc <- function(res) {
 m <- res$metadata
 if (is.null(m$survival_extension)) return(survival_expr_qc_legacy(res))
 if (identical(m$survival_extension, "competing-risks")) return(list(
  os_qc_rule("SRV-01", "Candidate analysis", TRUE, "blocker", "Native source-port and owner review remain pending.", "Do not publish candidate inference."),
  os_qc_rule("SRV-08", "Point-only CIF", TRUE, "warning", "Copied AJ estimator has no CI, Gray test or adjusted gene effect.", "Do not interpret absent uncertainty as zero uncertainty."),
  os_qc_rule("SRV-09", "Competing event share", m$competing_share_of_outcomes_pct >= 5, "warning", "Competing share uses all observed outcomes, excluding censored subjects; the copied severity tier never changes the estimator.", "Use Aalen-Johansen; do not use the diagnostic one-minus-KM column as CIF.")))
 c(survival_expr_qc_legacy(res), list(
  os_qc_rule("SRV-05", "Engineering PH magnitude", TRUE, "warning", "Source classification retains P=0.05 and the declared engineering magnitude threshold, separately from legacy ph-alpha.", "Interpret full diagnostics; no automatic model selection or filtering."),
  os_qc_rule("SRV-06", "Missing diagnostic slope", any(!is.finite(res$tables$nonph_diagnostics$delta_loghr[!res$tables$nonph_diagnostics$is_global])), "warning", "Some residual magnitudes cannot be assessed; source low classification with an NA magnitude is not proof of PH.", "Read the NA/multi-df/nonfinite counts and prespecified model."),
  os_qc_rule("SRV-07", "Non-estimable period", !is.null(m$piecewise) && m$piecewise$n_nonestimable > 0, "warning", "Some prespecified periods lack finite HR/CI; complete rows and reasons are retained and failed estimates are never drawn as zero.", "Inspect events per exposure level, warnings and the complete period table.")))
}
