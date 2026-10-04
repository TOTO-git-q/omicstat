gv_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb"); on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

gsva_score_render <- function(r, a, st, group_col, outdir) {
  score_path <- file.path(outdir, "tables", "scores.csv")
  gv_write_csv(data.frame(feature_id = rownames(r$scores), r$scores, check.names = FALSE), score_path)
  size_path <- file.path(outdir, "tables", "gene_set_sizes.csv")
  gv_write_csv(r$set_table, size_path)
  extra <- "tables/gene_set_sizes.csv"
  figs <- list()
  p <- os_gsva_score_heatmap(r$scores, st, sample_col = a[["sample-col"]], group_col = group_col,
                             min_size = a[["min-size"]], max_size = a[["max-size"]], journal = a$journal)
  figs$score_heatmap <- os_finalize_figure(p, file.path(outdir, "figures", "score_heatmap"), width = "double", journal = a$journal)
  extra <- c(extra, "figures/score_heatmap.png", "figures/score_heatmap.pdf", "figures/score_heatmap.figure_spec.json")
  if (!is.null(st) && !is.null(group_col)) {
    pg <- os_score_by_group(r$scores, st, sample_col = a[["sample-col"]], group_col = group_col, max_sets = 12,
                            value_title = "GSVA score", journal = a$journal)
    figs$score_by_group <- os_finalize_figure(pg, file.path(outdir, "figures", "score_by_group"), width = "double", journal = a$journal)
    extra <- c(extra, "figures/score_by_group.png", "figures/score_by_group.pdf", "figures/score_by_group.figure_spec.json")
  }
  list(score_path = score_path, size_path = size_path, extra_paths = extra, figures = figs)
}

gsva_score_exclusion_summary <- function(tab) {
  ex <- tab[tab$status == "excluded", , drop = FALSE]
  if (!nrow(ex)) return("none excluded")
  cnt <- table(ex$reason)
  paste(sprintf("%d: %s", as.integer(cnt), names(cnt)), collapse = "; ")
}

gsva_score_report <- function(r, a, qc, collection, outdir, templates_path, corrected_input, source_info, figures) {
  used <- r$set_table$n_used_by_gsva[r$set_table$status == "retained"]
  vals <- list(gsva_version = as.character(utils::packageVersion("GSVA")),
               input_source = source_info$sentence, input_object = source_info$object,
               upstream_run = source_info$run_id %||% NULL, upstream_module = source_info$module %||% NULL,
               upstream_scale = source_info$scale %||% NULL, weights_used = FALSE,
               upstream_weights_present = source_info$weights_present %||% NULL,
               input_scale = a[["input-scale"]], input_storage = r$input_storage,
               n_features = r$n_input_features, n_samples = ncol(r$scores),
               kcdf = a$kcdf, kernel = r$kernel,
               collection = a$collection, collection_version = collection$entry$version,
               collection_species = collection$entry$species, collection_sha256 = collection$sha256,
               min_size = a[["min-size"]], max_size = a[["max-size"]], n_constant_rows = r$n_constant_rows,
               n_sets = r$n_input_sets, n_retained = r$n_retained, n_excluded = r$n_excluded,
               exclusion_summary = gsva_score_exclusion_summary(r$set_table),
               size_range = if (length(used)) sprintf("%d-%d, median %s", min(used), max(used), format(stats::median(used))) else "none",
               n_scored = r$n_scored, seed = a$seed,
               inference = FALSE, inference_status = "not performed; score inference awaits the owner decision (S1 P-3)",
               corrected_input = corrected_input,
               corrected_sentence = if (corrected_input) "The input was batch-corrected; the scores are handed on typed batch_corrected_matrix (batch-corrected lineage) and are for display only." else "The input was not batch-corrected.")
  tm <- os_read_templates(templates_path)
  caps <- vapply(names(figures), function(n) sprintf("- **%s** (figures/%s.pdf): %s", n, n, figures[[n]]$spec_obj$caption %||% ""), "")
  text <- c("# gsva-score Methods and Results", "", "## Methods", "",
            os_fill_template(tm$methods, vals), "", "## Results", "",
            os_fill_template(tm$results, vals), "", "## Figure legends", "", caps)
  os_write_text(text, file.path(outdir, "draft", "methods_results.md"))
  vals$qc_triggered <- qc$table$id[qc$table$triggered]
  vals$set_sizes <- r$set_table
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(vals, file.path(outdir, "results", "gsva_score_results.json"),
                       auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = I(10), dataframe = "rows")
}
