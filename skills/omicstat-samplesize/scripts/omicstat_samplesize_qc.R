omicstat_samplesize_qc <- function(res) {
  q <- res$metadata$original_qc
  copied <- lapply(seq_len(nrow(q)), function(i)
    os_qc_rule(sub("^SS-", "SSZ-", q$id[i]), paste("Copied planning guard", q$id[i]),
      q$triggered[i], "warning", q$message[i],
      "Review the stated planning assumption; the guard never changes alpha, power, effect or design."))
  c(copied, list(
    os_qc_rule("SSZ-90", "Candidate planning module", TRUE, "blocker",
      "Pinned-image native anchors, dependency capture and owner review remain required.",
      "Do not use a candidate planning result as accepted study-design approval."),
    os_qc_rule("SSZ-91", "Technical repeats excluded from biological n", res$metadata$technical_replicates > 1,
      "info", "Technical measurements do not increase independent biological replication.",
      "Read biological_groups.csv; paired conditions share the same independent units.")))
}
