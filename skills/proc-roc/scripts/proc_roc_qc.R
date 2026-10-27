proc_roc_qc <- function(res) {
  q <- res$metadata$original_qc
  rows <- lapply(1:23, function(i) {
    code <- sprintf("ROC-%02d", i); found <- q[q$code == code, , drop = FALSE]
    os_qc_rule(code, paste("Copied diagnostic-accuracy guard", code), nrow(found) > 0,
      if (nrow(found) && any(found$severity == "H")) "error" else "warning",
      if (nrow(found)) paste(unique(found$message), collapse = " | ") else "Not triggered; input/identity guards may refuse earlier.",
      if (nrow(found)) "Review declared design and source limitations; do not silently flip direction, delete units or replace uncertainty." else "")
  })
  c(rows, list(os_qc_rule("ROC-24", "Numerical/source identity release", FALSE, "error", "Estimand, table hashes, source counts and native AUC values checked before finish/render."),
    os_qc_rule("ROC-90", "Independent candidate acceptance", TRUE, "blocker",
      "Native R4.6.1 original anchors, exact independent pROC closure/formals, complete figure adapters and genuine real-data owner review are pending.", "No seal, promotion or publication acceptance follows from candidate outputs.")))
}
