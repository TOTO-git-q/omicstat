# deseq2-lrt report: deterministic tables, joint-test figures and filled draft.
.dl_num <- function(x) ifelse(is.na(x), "NA", formatC(x, digits = 10, format = "g"))
.dl_write_csv <- function(df, path) {
  out <- df
  for (k in names(out)) if (is.numeric(out[[k]])) out[[k]] <- .dl_num(out[[k]])
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}
.dl_matrix_csv <- function(m, path) {
  d <- data.frame(feature_id = rownames(m), m, check.names = FALSE)
  .dl_write_csv(d, path)
}
# The display transformation actually run (core.R), written as the call (S4 F2).
dl_display_transform <- function(r, a) {
  if (isTRUE(r$vst_fallback)) {
    sprintf(paste0("DESeq2::varianceStabilizingTransformation(blind = FALSE, fitType = \"%s\") -- the direct VST, because ",
                   "only %d features had a mean normalized count > 5, fewer than vst()'s nsub = %d"),
            a[["fit-type"]], r$n_vst_eligible, DL_VST_NSUB)
  } else {
    sprintf("DESeq2::vst(blind = FALSE, nsub = %d, fitType = \"%s\")", DL_VST_NSUB, a[["fit-type"]])
  }
}
# Which features a figure shows and why (S4 F2): the source set is the LRT's
# BH-adjusted P < alpha, ranked by adjusted P; n samples.
.dl_selection_text <- function(n_shown, n_sig, a, r) {
  sprintf(paste0("Features shown: the %d with the smallest BH-adjusted P among the %d features with adjusted P < %s ",
                 "in the likelihood ratio test (full %s vs reduced %s); n = %d samples."),
          n_shown, n_sig, format(a$alpha), r$design$full_formula, r$design$reduced_formula, ncol(r$norm))
}
deseq2_lrt_render <- function(r, ft, a, outdir, colour_reg) {
  tabs <- list(feature_table = file.path(outdir, "tables", "feature_table.csv"),
               full = file.path(outdir, "tables", "deseq2_lrt_results_full.csv"),
               norm = file.path(outdir, "tables", "normalized_counts.csv"),
               vst = file.path(outdir, "tables", "vst_matrix.csv"),
               sf = file.path(outdir, "tables", "size_factors.csv"))
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  write_feature_table(ft, tabs$feature_table)
  .dl_write_csv(dl_full_table(r, ft), tabs$full)
  .dl_matrix_csv(r$norm[ft$feature_id, , drop = FALSE], tabs$norm)
  .dl_matrix_csv(r$vst[ft$feature_id, , drop = FALSE], tabs$vst)
  .dl_write_csv(data.frame(sample = names(r$size_factors), size_factor = unname(r$size_factors), stringsAsFactors = FALSE), tabs$sf)
  cd <- data.frame(sample = rownames(r$sample_table), stringsAsFactors = FALSE)
  cd[[a[["group-col"]]]] <- as.character(r$sample_table[[a[["group-col"]]]])
  if (!is.null(a[["time-col"]])) cd[[a[["time-col"]]]] <- as.character(r$sample_table[[a[["time-col"]]]])
  sig <- ft[!is.na(ft$padj) & ft$padj < a$alpha, , drop = FALSE]
  figs <- list()
  if (nrow(sig) >= 2) {
    p <- os_top_heatmap(r$vst, sig, cd, a[["group-col"]], n = a[["top-n"]], reference = a[["group-reference"]], journal = a$journal)
    n_shown <- length(attr(p, "os_meta")$data$feature_ids)
    p <- os_with_meta(p, caption = paste(attr(p, "os_meta")$caption, .dl_selection_text(n_shown, nrow(sig), a, r),
                                         sprintf(paste0("Transformed expression = %s, a display transformation computed after the fit; ",
                                                        "it does not enter the likelihood ratio test."), dl_display_transform(r, a))))
    figs$top_heatmap <- os_finalize_figure(p, file.path(outdir, "figures", "top_heatmap"), journal = a$journal)
    if (!is.null(a[["time-col"]])) {
      p <- os_lrt_trajectory(r$norm, sig, r$sample_table, time_col = a[["time-col"]], group_col = a[["group-col"]],
                             n = min(12L, a[["top-n"]]), reference = a[["group-reference"]], journal = a$journal)
      n_shown <- length(attr(p, "os_meta")$data$feature_ids)
      p <- os_with_meta(p, caption = paste(attr(p, "os_meta")$caption, .dl_selection_text(n_shown, nrow(sig), a, r),
                                           sprintf(paste0("Normalized counts = DESeq2 counts(dds, normalized = TRUE) (size factors, sfType = \"%s\"); ",
                                                          "no variance-stabilizing transformation is applied in this figure."), a[["sf-type"]])))
      figs$trajectory <- os_finalize_figure(p, file.path(outdir, "figures", "trajectory"), journal = a$journal)
    }
  }
  list(tables = tabs, figures = figs)
}
deseq2_lrt_results_json <- function(r, ft, cnt, a, outdir, qc) {
  out <- list(module = DL_MODULE, module_version = DL_MODULE_VERSION,
              full = r$design$full_formula, reduced = r$design$reduced_formula,
              tested_terms = as.list(r$design$tested_terms), df = r$design$df,
              report_coefficient = r$used_coef, header_log2fc = r$header_log2fc, header_pvalue = r$header_pvalue,
              n_input_features = r$n_input, n_tested = cnt$n_tested, n_significant = cnt$n_sig,
              n_padj_na = cnt$n_padj_na, n_cooks_outliers = cnt$n_outlier, n_independent_filtered = cnt$n_indep_filtered,
              prefilter_min_count = a[["min-count"]], prefilter_min_samples = r$prefilter$min_samples_used,
              alpha = a$alpha, fit_type = a[["fit-type"]], sf_type = a[["sf-type"]],
              display_transform = if (isTRUE(r$vst_fallback)) "varianceStabilizingTransformation" else "vst",
              display_transform_blind = FALSE, display_transform_nsub = if (isTRUE(r$vst_fallback)) NA_integer_ else DL_VST_NSUB,
              display_transform_fallback = isTRUE(r$vst_fallback), n_vst_eligible = r$n_vst_eligible,
              n_samples = ncol(r$norm),
              qc_triggered = qc$table$id[qc$table$triggered], draft_withheld = qc$blocking)
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, file.path(outdir, "results", "deseq2_lrt_results.json"), auto_unbox = TRUE, pretty = TRUE,
                       digits = I(10), na = "null", null = "null")
}
deseq2_lrt_draft <- function(r, cnt, a, qc, rend, templates_path, outdir) {
  path <- file.path(outdir, "draft", "methods_results.md")
  if (qc$blocking) {
    os_write_text(c("# deseq2-lrt: draft withheld", "", "Read qc/qc_results.csv before reporting."), path)
    return(invisible(path))
  }
  tp <- os_read_templates(templates_path)
  v <- list(deseq2_version = as.character(utils::packageVersion("DESeq2")), r_version = as.character(getRversion()),
            n_input = format(r$n_input, big.mark = ","), n_tested = format(cnt$n_tested, big.mark = ","),
            min_count = a[["min-count"]], min_samples = r$prefilter$min_samples_used,
            full = r$design$full_formula, reduced = r$design$reduced_formula,
            terms = paste(r$design$tested_terms, collapse = ", "), df = r$design$df,
            fit_type = a[["fit-type"]], sf_type = a[["sf-type"]], alpha = format(a$alpha),
            coef = r$used_coef, n_sig = format(cnt$n_sig, big.mark = ","), n_padj_na = format(cnt$n_padj_na, big.mark = ","),
            n_samples = ncol(r$norm), display_transform = dl_display_transform(r, a), top_n = a[["top-n"]],
            n_traj = min(12L, a[["top-n"]]))
  caps <- vapply(names(rend$figures), function(n) sprintf("- **%s**: %s", n, rend$figures[[n]]$spec_obj$caption %||% ""), "")
  os_write_text(c("# deseq2-lrt: Methods and Results draft", "", "## Methods", "", os_fill_template(tp$methods, v), "",
                  "## Results", "", os_fill_template(tp$results, v), "", "## Figure legends", "", caps), path)
  invisible(path)
}
