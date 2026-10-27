# Acceptance is a permanent draft blocker until genuine environment replay and sealing.
msstats_diff_qc <- function(res, a) {
  ft <- res$ft
  active <- ft$filtered_reason == ""
  rows <- list(
    os_qc_rule("MS-00", "numerical acceptance", TRUE, "blocker",
      "Experimental implementation: rebuilt-environment replay and publication acceptance have not been completed.",
      "Complete PACK acceptance, official anchors, complete suite gates and a real module seal.", "PACK acceptance status"),
    os_qc_rule("MS-01", "replication", min(res$details$n_target, res$details$n_reference) < 3L, "warning",
      "A group has only two biological replicates.", "Interpret uncertainty cautiously.", "Suite replication convention"),
    os_qc_rule("MS-02", "estimable results", !any(active & is.finite(ft$padj)), "blocker",
      "No estimable adjusted P values.", "Inspect data and engine warnings.", "Result validity"),
    os_qc_rule("MS-03", "finite effects", any(active & !is.finite(ft$log2fc)), "blocker",
      "A tested effect is non-finite.", "Inspect full engine table.", "Result validity"),
    os_qc_rule("MS-04", "upstream model issue", (res$details$n_issue_rows %||% 0L) > 0L, "blocker",
      "MSstats reported model issues; issue-specific p-value conventions are preserved, not interpreted as ordinary evidence.",
      "Review full issue column before inference.", "MSstats groupComparisonOutput"))
  os_qc_finalize(rows, "tables/feature_table.csv")
}
