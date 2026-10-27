omicstat_ddct_qc <- function(res) list(
 os_qc_rule("DDC-01", "Candidate analysis", TRUE, "blocker", "Scientific and visual review are pending.", "Do not treat candidate evidence as accepted."),
 os_qc_rule("DDC-02", "Assay declaration", TRUE, "warning", "Equal near-two efficiency and stable reference are user declarations, not estimated here.", "Inspect assay-validation provenance and assay validation data."),
 os_qc_rule("DDC-03", "Descriptive only", res$metadata$inference == "descriptive", "warning", "No biological hypothesis test or CI was requested.", "Technical-SD ranges cannot establish population inference."),
 os_qc_rule("DDC-04", "Multiple unadjusted tests", res$metadata$inference != "descriptive" && res$metadata$family_size > 1 && res$metadata$adjustment == "none", "warning",
  "Multiple biological tests have no p adjustment.", "Review prespecified exploratory status and multiplicity."))
