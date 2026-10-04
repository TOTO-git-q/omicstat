gsva_score_qc <- function(r, a, corrected_input) {
  ex <- r$set_table[r$set_table$status == "excluded", , drop = FALSE]
  rows <- list(
    os_qc_rule("GV-01", "set_filter", r$n_excluded > 0, "info",
               "Gene sets were excluded after ID intersection, constant-row removal (filterRows) and size limits.",
               "Report per-set sizes and exclusion reasons (tables/gene_set_sizes.csv).",
               if (nrow(ex)) paste(sprintf("%s: %s", ex$term_id, ex$reason), collapse = "; ") else "0"),
    os_qc_rule("GV-02", "scores_only", TRUE, "info",
               "Scores were generated without group inference; score inference awaits the owner decision (S1 P-3).",
               "Hand the scores on; do not attach test results to them in this module.", ""),
    os_qc_rule("GV-03", "corrected_input", corrected_input, "warning",
               "Input was a batch-corrected matrix; the scores are typed batch_corrected_matrix and are descriptive only.",
               "Use uncorrected expression with batch/SV in the inference design.", ""),
    os_qc_rule("GV-04", "no_kernel", identical(r$kernel, "none"), "info",
               "The auto branch used direct ECDF without a kernel.",
               "Report the n>=200 auto branch.", as.character(ncol(r$scores))),
    os_qc_rule("GV-05", "constant_scores", any(apply(r$scores, 1, stats::sd) == 0), "warning",
               "One or more gene sets have constant scores.",
               "Inspect the score matrix and gene-set overlap.", ""),
    os_qc_rule("GV-06", "constant_rows", r$n_constant_rows > 0, "info",
               "GSVA filterRows removed rows with constant expression before mapping gene sets.",
               "Report the number of removed rows; set sizes are counted after this removal.", as.character(r$n_constant_rows)))
  os_qc_finalize(rows, read_first = "tables/scores.csv")
}
