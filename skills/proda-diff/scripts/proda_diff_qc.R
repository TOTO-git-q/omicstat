# Acceptance is a permanent draft blocker until genuine environment replay and sealing.
proda_diff_qc <- function(res, a) {
  ft <- res$ft
  active <- ft$filtered_reason == ""
  rows <- list(
    os_qc_rule("PD-00", "numerical acceptance", TRUE, "blocker",
      "Experimental implementation: rebuilt-environment replay and publication acceptance have not been completed.",
      "Complete PACK acceptance, official anchors, complete suite gates and a real module seal.", "PACK acceptance status"),
    os_qc_rule("PD-01", "replication", min(res$details$n_target, res$details$n_reference) < 3L, "warning",
      "A group has only two biological replicates.", "Interpret uncertainty cautiously.", "Suite replication convention"),
    os_qc_rule("PD-02", "estimable results", !any(active & is.finite(ft$padj)), "blocker",
      "No estimable adjusted P values.", "Inspect data and engine warnings.", "Result validity"),
    os_qc_rule("PD-03", "finite effects", any(active & !is.finite(ft$log2fc)), "blocker",
      "A tested effect is non-finite.", "Inspect full engine table.", "Result validity"))
  rows[[length(rows) + 1L]] <- os_qc_rule("PD-05", "model convergence", !isTRUE(res$details$converged), "blocker",
    "The proDA model did not converge.", "Inspect convergence diagnostics; do not interpret differential results.", "proDA convergence accessor")
  os_qc_finalize(rows, "tables/feature_table.csv")
}
