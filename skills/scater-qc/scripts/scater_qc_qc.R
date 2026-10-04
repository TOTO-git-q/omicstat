scater_qc_qc <- function(r, elog) {
  os_qc_finalize(list(
    os_qc_rule("XQ-01", "retained cells", ncol(r$sce) < 2, "blocker", "Too few retained cells for downstream analysis.", "Review explicit QC thresholds.", "PACK T/C; engineering plan 4.5"),
    os_qc_rule("XQ-02", "deprecated API", TRUE, "warning", "Locked scuttle QC API is deprecated; replacement scrapper is absent.", "Owner to decide migration.", "PACK X; scuttle 1.22.0 Rd"),
    os_qc_rule("XQ-03", "engine warnings", os_engine_counts(elog)[["warning"]] > 0, "warning", "Read captured engine warnings.", "Read qc/engine_warnings.csv.", "CONVENTIONS 15")), "tables/flow.csv")
}
