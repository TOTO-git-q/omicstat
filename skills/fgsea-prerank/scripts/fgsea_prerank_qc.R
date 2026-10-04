fgsea_prerank_qc <- function(r, a, elog) {
  rows <- list(
    os_qc_rule("FG-01", "ranking_ties", r$n_tied > 0, "warning",
               "The ranking has tied scores; their order may affect enrichment scores.",
               "Report the tie count and ranking statistic.", as.character(r$n_tied)),
    os_qc_rule("FG-02", "gene_set_size", r$n_sets_excluded > 0, "info",
               "Some gene sets were excluded after intersection with the ranked IDs.",
               "Report size limits and retained/excluded counts.", as.character(r$n_sets_excluded)),
    os_qc_rule("FG-03", "adjusted_p_missing", anyNA(r$table$padj), "warning",
               "Some tested sets have no adjusted P value.", "Inspect log2err and the full result table.",
               as.character(sum(is.na(r$table$padj)))),
    os_qc_rule("FG-04", "no_significant_sets", !any(!is.na(r$table$padj) & r$table$padj < a$alpha), "info",
               "No tested gene set reached the declared BH threshold.", "Report all tested sets.",
               as.character(a$alpha)))
  os_qc_finalize(rows, read_first = "tables/enrichment_table.csv")
}
