# deseq2_qc_report.R -- report layer of module deseq2-qc. ASCII only on purpose.
#
# Tables, figures (ONLY through the _shared figure layer: os_pca_plot,
# os_sample_distance, os_diag_xy -- all pre-existing builders, no new one was
# needed for this module), the results JSON and the Methods/Results draft.
# The draft text comes from the ```template blocks of
# references/reporting-templates.md (os_read_templates), so the
# documentation and the engine share one text.

.dq_num <- function(x, digits = 10) ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "g"))

.dq_write_csv <- function(df, path) {
  out <- df
  for (k in names(out)) if (is.numeric(out[[k]])) out[[k]] <- .dq_num(out[[k]])
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

.dq_matrix_csv <- function(m, path, id = "feature_id") {
  df <- data.frame(m, check.names = FALSE)
  df <- cbind(stats::setNames(data.frame(rownames(m), stringsAsFactors = FALSE), id), df)
  .dq_write_csv(df, path)
}

deseq2_qc_render <- function(res, a, outdir, colour_reg) {
  tabs <- list(sample_qc = file.path(outdir, "tables", "sample_qc_descriptive.csv"),
               transform = file.path(outdir, "tables", sprintf("%s_matrix.csv", a$transform)),
               sf = file.path(outdir, "tables", "size_factors.csv"),
               dist = file.path(outdir, "tables", "sample_distances.csv"))
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  st <- dq_sample_table(res, a)
  .dq_write_csv(st, tabs$sample_qc)
  .dq_matrix_csv(res$transform$assay, tabs$transform)
  # The sample-to-sample Euclidean distances behind figures/sample_distance
  # (vignette `dist(t(assay(vsd)))`), written so they can be checked.
  .dq_matrix_csv(as.matrix(stats::dist(t(res$transform$assay), method = "euclidean")), tabs$dist, id = "sample")
  .dq_write_csv(data.frame(sample = names(res$size_factors), size_factor = unname(res$size_factors),
                           condition = as.character(res$design$coldata[names(res$size_factors), a$condition]),
                           stringsAsFactors = FALSE), tabs$sf)

  cd <- data.frame(sample = rownames(res$design$coldata), stringsAsFactors = FALSE)
  cd[[a$condition]] <- as.character(res$design$coldata[[a$condition]])
  if (!is.null(a[["shape-col"]])) cd[[a[["shape-col"]]]] <- as.character(res$design$coldata[[a[["shape-col"]]]])

  transform_label <- sprintf("DESeq2 %s (blind = TRUE, sample QA)", a$transform)
  figs <- list()
  p <- os_pca_plot(res$pca, cd, group_col = a$condition, shape_col = a[["shape-col"]], reference = NULL,
                   pcs = c(1, 2), colour_registry = colour_reg, journal = a$journal)
  p <- os_with_meta(p, caption = sprintf("Sample QA: %s. %s", transform_label, attr(p, "os_meta")$caption))
  figs$pca <- os_finalize_figure(p, file.path(outdir, "figures", "pca"), journal = a$journal)

  p <- os_sample_distance(res$transform$assay, cd, group_col = a$condition, reference = NULL, journal = a$journal)
  p <- os_with_meta(p, caption = sprintf("Sample QA: %s. %s", transform_label, attr(p, "os_meta")$caption))
  figs$sample_distance <- os_finalize_figure(p, file.path(outdir, "figures", "sample_distance"), journal = a$journal)

  sf_df <- data.frame(sample = names(res$size_factors),
                      log10_library_size = log10(colSums(DESeq2::counts(res$dds))[names(res$size_factors)]),
                      size_factor = unname(res$size_factors), stringsAsFactors = FALSE)
  p <- os_diag_xy(sf_df, x = "log10_library_size", y = "size_factor", kind = "points",
                  xlab = "log10(library size)", ylab = "Size factor",
                  caption = sprintf(paste0("Size factor (DESeq2::estimateSizeFactors, type = %s) versus log10 library size ",
                                          "for each of the %d samples. A diagnostic display, not a test."), a[["sf-type"]], ncol(res$transform$assay)),
                  figure_type = "size_factor_diagnostic", journal = a$journal)
  figs$size_factor <- os_finalize_figure(p, file.path(outdir, "figures", "size_factor"), journal = a$journal)

  if (!is.null(res$supplement)) {
    transform_label_supp <- sprintf("DESeq2 %s (blind = FALSE, post-hoc display using the experimental design)", a$transform)
    p <- os_pca_plot(res$pca_supplement, cd, group_col = a$condition, shape_col = a[["shape-col"]], reference = NULL,
                     pcs = c(1, 2), colour_registry = colour_reg, journal = a$journal)
    p <- os_with_meta(p, caption = sprintf("Supplementary (not the primary QA figure): %s. %s", transform_label_supp, attr(p, "os_meta")$caption))
    figs$pca_blind_false <- os_finalize_figure(p, file.path(outdir, "figures", "pca_blind_false"), journal = a$journal)
    .dq_matrix_csv(res$supplement$assay, file.path(outdir, "tables", sprintf("%s_matrix_blind_false.csv", a$transform)))
  }
  list(tables = tabs, figures = figs, sample_table = st)
}

deseq2_qc_results_json <- function(res, a, outdir, qc) {
  pv <- res$pca$percent_var
  out <- list(module = DQ_MODULE, module_version = DQ_MODULE_VERSION,
              design = res$design$formula_text, condition = a$condition, condition_levels = as.list(res$levels),
              n_input_features = res$n_input, n_prefiltered_out = res$n_input - nrow(res$transform$assay),
              n_tested = nrow(res$transform$assay), n_samples = res$n_samples,
              prefilter_min_count = a[["min-count"]], prefilter_min_samples = res$prefilter$min_samples_used,
              prefilter_simple_design = res$prefilter$simple_design,
              transform = a$transform, transform_blind = TRUE, transform_fallback = res$transform$fallback,
              fit_type = a[["fit-type"]], sf_type = a[["sf-type"]], ntop_requested = a$ntop, ntop = res$pca$ntop,
              pc1_percent_var = pv[1], pc2_percent_var = pv[2],
              blind_false_supplement = isTRUE(a[["blind-false-supplement"]]),
              qc_triggered = qc$table$id[qc$table$triggered], draft_withheld = qc$blocking)
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, file.path(outdir, "results", "deseq2_qc_results.json"), auto_unbox = TRUE, pretty = TRUE,
                       digits = I(10), na = "null", null = "null")
}

dq_template_values <- function(res, a) {
  transform_detail <- if (identical(a$transform, "rlog")) {
    sprintf("DESeq2::rlog(blind = TRUE, fitType = \"%s\")", a[["fit-type"]])
  } else if (isTRUE(res$transform$fallback)) {
    sprintf("DESeq2::varianceStabilizingTransformation(blind = TRUE, fitType = \"%s\") because only %d features had mean normalized count > 5 (vst nsub = %d)",
            a[["fit-type"]], res$transform$n_eligible, DQ_VST_NSUB)
  } else {
    sprintf("DESeq2::vst(blind = TRUE, nsub = %d, fitType = \"%s\")", DQ_VST_NSUB, a[["fit-type"]])
  }
  supplement_detail <- if (isTRUE(a[["blind-false-supplement"]])) {
    supp_call <- if (identical(a$transform, "vst") && !isTRUE(res$supplement$fallback)) {
      sprintf("DESeq2::vst(blind = FALSE, nsub = %d, fitType = \"%s\")", DQ_VST_NSUB, a[["fit-type"]])
    } else {
      sprintf("DESeq2::%s(blind = FALSE, fitType = \"%s\")",
              if (isTRUE(res$supplement$fallback)) "varianceStabilizingTransformation" else a$transform, a[["fit-type"]])
    }
    sprintf("A supplementary design-aware display used %s and was kept separate from the primary sample QA.", supp_call)
  } else "No blind = FALSE supplement was requested."
  out <- list(deseq2_version = as.character(utils::packageVersion("DESeq2")),
              r_version = as.character(getRversion()),
              n_input = format(res$n_input, big.mark = ","),
              n_tested = format(nrow(res$transform$assay), big.mark = ","),
              min_count = a[["min-count"]], min_samples = res$prefilter$min_samples_used,
              design = res$design$formula_text, condition = a$condition,
              transform = a$transform, transform_detail = transform_detail,
              sf_type = a[["sf-type"]], supplement_detail = supplement_detail,
              ntop = res$pca$ntop,
              pc1_pct = sprintf("%.1f", res$pca$percent_var[1]), pc2_pct = sprintf("%.1f", res$pca$percent_var[2]),
              n_samples = res$n_samples)
  out
}

deseq2_qc_draft <- function(res, a, qc, templates_path, outdir) {
  path <- file.path(outdir, "draft", "methods_results.md")
  if (qc$blocking) {
    os_write_text(c("# deseq2-qc: draft withheld",
                    "",
                    sprintf("Blocker QC rule(s) %s were triggered; no Methods/Results text is written for this run.", paste(qc$blocking_ids, collapse = ", ")),
                    "Read qc/qc_results.csv and fix the input before reporting anything from this run."), path)
    return(invisible(path))
  }
  tp <- os_read_templates(templates_path)
  v <- dq_template_values(res, a)
  os_write_text(c("# deseq2-qc: Methods and Results draft", "",
                  "## Methods", "", os_fill_template(tp$methods, v), "",
                  "## Results", "", os_fill_template(tp$results, v), "",
                  "## Note on sample review", "",
                  os_fill_template(tp$outlier_note, v)), path)
  invisible(path)
}
