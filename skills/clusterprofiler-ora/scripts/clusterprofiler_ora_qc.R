co_qc <- function(r, a, elog) {
  rows <- list(
    os_qc_rule("CO-01", "mapped background", r$n_mapped_background < r$n_candidate, "warning",
               if (identical(a$database, "custom")) "Some eligible IDs are not annotated to any user-supplied gene set." else
                 "Some eligible IDs did not map to the pinned OrgDb.",
               if (identical(a$database, "custom")) "Check the input key type and the user GMT identifiers." else
                 "Check the input key type and annotation version.",
               sprintf("%d/%d mapped", r$n_mapped_background, r$n_candidate)),
    os_qc_rule("CO-02", "adjusted P", !any(!is.na(r$raw$p.adjust) & r$raw$p.adjust < a$alpha), "info",
               "No tested GO term reaches the specified BH threshold.", "Report the full tested table and smallest adjusted P.",
               sprintf("%d tested", nrow(r$raw))),
    os_qc_rule("CO-03", "engine warnings", os_engine_counts(elog)[["warning"]] > 0, "warning",
               "The package emitted a warning.", "Read qc/engine_warnings.csv."))
  os_qc_finalize(rows, read_first = "tables/enrichment_full.csv")
}
