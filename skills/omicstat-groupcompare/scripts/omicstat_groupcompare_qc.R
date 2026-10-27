omicstat_groupcompare_qc <- function(res) {
 distribution <- identical(res$metadata$analysis_mode, "distribution-effects")
 rows <- list(
  os_qc_rule("GPC-01", "Candidate analysis", TRUE, "blocker", "Scientific and visual review are pending.", "Do not treat candidate evidence as accepted."),
  os_qc_rule("GPC-02", "Technical aggregation", if (distribution) isTRUE(res$metadata$technical_aggregation_declared) else res$metadata$input_rows > res$metadata$biological_observations, "warning",
   "Technical means were requested within biological unit and group.", if (distribution) "Review private input identities; aggregate-only output deliberately contains no biological-unit table." else "Review biological_units.csv and technical identities."),
  os_qc_rule("GPC-03", "Multiple unadjusted tests", res$metadata$family_size > 1 && res$metadata$adjustment == "none", "warning",
   "The declared family has multiple tests and no adjustment.", "Treat unadjusted p-values as exploratory; review prespecification."),
  os_qc_rule("GPC-04", "Advisory only", !is.null(res$tables$distribution_advisory), "warning",
   "Source skewness/small-n classification is advisory; Shapiro and Q-Q correlation are reference only.", "Keep the prespecified test; this heuristic is not a model-assumption validity proof."))
 if (distribution) {
  findings <- res$metadata$guardrails$findings
  codes <- unique(vapply(findings, function(z) z$code, ""))
  for (code in codes) {
   group <- Filter(function(z) identical(z$code, code), findings)
   rows[[length(rows) + 1L]] <- os_qc_rule(code, "Source distribution guard", TRUE,
    if (any(vapply(group, function(z) isTRUE(z$blocking), logical(1)))) "blocker" else "warning", group[[1L]]$message,
    "Review aggregate distribution_guardrails and suppressed estimates; do not infer missing values.")
  }
  rows[[length(rows) + 1L]] <- os_qc_rule("GPC-05", "Pointwise descriptive effects", TRUE, "warning",
   "Distribution effects have no P-value family or simultaneous interval coverage.", "Report explicit pointwise inference and the source minimum-cell policy.")
 }
 rows
}
