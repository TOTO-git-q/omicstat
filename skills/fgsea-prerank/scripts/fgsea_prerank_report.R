fg_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb"); on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

fgsea_prerank_render <- function(r, a, outdir, rank_meta) {
  table_path <- file.path(outdir, "tables", "enrichment_table.csv")
  fg_write_csv(r$table, table_path)
  fig_paths <- character(0)
  sig <- r$table[!is.na(r$table$padj) & r$table$padj < a$alpha & is.finite(r$table$nes), , drop = FALSE]
  if (nrow(sig)) {
    p <- os_fgsea_nes_figure(r$table, a$alpha, a$collection, journal = a$journal,
                             positive_end = sprintf("%s: %s", rank_meta$metric, rank_meta$positive_end),
                             negative_end = rank_meta$negative_end)
    os_finalize_figure(p, file.path(outdir, "figures", "nes_bar"), journal = a$journal)
    fig_paths <- c(fig_paths, "figures/nes_bar.png", "figures/nes_bar.pdf", "figures/nes_bar.figure_spec.json")
    top <- sig[order(sig$padj, -abs(sig$nes), sig$term_id, method = "radix"), , drop = FALSE][1L, ]
    p <- os_fgsea_curve_figure(r$stats, r$pathways[[top$term_id]], top$term_name,
                               top$nes, top$padj, a$alpha, journal = a$journal)
    os_finalize_figure(p, file.path(outdir, "figures", "gsea_curve"), journal = a$journal)
    fig_paths <- c(fig_paths, "figures/gsea_curve.png", "figures/gsea_curve.pdf", "figures/gsea_curve.figure_spec.json")
  }
  list(table = table_path, figures = fig_paths)
}

fgsea_prerank_report <- function(r, a, qc, outdir, templates_path, metric, collection) {
  n_sig <- sum(!is.na(r$table$padj) & r$table$padj < a$alpha)
  vals <- list(fgsea_version = as.character(utils::packageVersion("fgsea")),
               metric = metric, direction = a$direction, collection = a$collection,
               collection_version = collection$entry$version, collection_species = collection$entry$species,
               collection_sha256 = collection$sha256,
               n_genes = length(r$stats), n_tied = r$n_tied,
               min_size = a[["min-size"]], max_size = a[["max-size"]],
               n_sets = r$n_sets_input, n_retained = r$n_sets_retained,
               n_excluded = r$n_sets_excluded, alpha = a$alpha, n_sig = n_sig, seed = a$seed)
  tm <- os_read_templates(templates_path)
  os_write_text(c("# fgsea-prerank Methods and Results", "", "## Methods", "",
                  os_fill_template(tm$methods, vals), "", "## Results", "",
                  os_fill_template(tm$results, vals)), file.path(outdir, "draft", "methods_results.md"))
  out <- c(vals, list(n_tested = nrow(r$table), qc_triggered = qc$table$id[qc$table$triggered],
                      eps = 1e-50, eps_meaning = "P-value computation floor; not a tolerance"))
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, file.path(outdir, "results", "fgsea_prerank_results.json"),
                       auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null", digits = I(10))
}
