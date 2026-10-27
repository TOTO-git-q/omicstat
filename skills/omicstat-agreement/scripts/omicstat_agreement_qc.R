omicstat_agreement_qc <- function(res) {
  q <- res$metadata$original_qc
  # Original rules can emit several rows (e.g. sparse cells and out-of-range CI).
  # Aggregate evidence under one suite QC ID; never discard a triggered warning.
  rows <- lapply(c(1:13, 17:18), function(i) {
    code <- sprintf("OAG-%02d", i); found <- q[q$code == code, , drop = FALSE]
    os_qc_rule(code, paste("Copied agreement scientific guard", code), nrow(found) > 0,
      if (nrow(found) && any(found$severity == "error")) "error" else "warning",
      if (nrow(found)) paste(unique(found$message), collapse = " | ") else "Not triggered; fatal input guards run before calculation.",
      if (nrow(found)) paste(unique(found$action), collapse = " | ") else "",
      if (nrow(found)) paste(unique(found$evidence), collapse = " | ") else "")
  })
  c(rows, list(os_qc_rule("OAG-90", "Independent candidate acceptance", TRUE, "blocker",
    "Native R4.6.1 anchors, exact independent package capture and real-data owner review are pending.",
    "Do not infer module acceptance or universal method interchangeability from this candidate output.")))
}
