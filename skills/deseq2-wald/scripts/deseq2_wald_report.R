# deseq2_wald_report.R -- report layer of module deseq2-wald. ASCII only on purpose.
#
# Tables, figures (ONLY through the _shared figure layer), the results JSON
# and the Methods/Results draft. The draft text comes from the ```template
# blocks of references/reporting-templates.md (os_read_templates), so the
# documentation and the engine share one text.

.dw_num <- function(x, digits = 10) ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "g"))

.dw_write_csv <- function(df, path, digits = 10) {
  out <- df
  for (k in names(out)) if (is.numeric(out[[k]])) out[[k]] <- .dw_num(out[[k]], digits = digits)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

.dw_matrix_csv <- function(m, path, id = "feature_id") {
  df <- data.frame(m, check.names = FALSE)
  df <- cbind(stats::setNames(data.frame(rownames(m), stringsAsFactors = FALSE), id), df)
  .dw_write_csv(df, path)
}

# Report-only ID/universe audit. Native estimates and P values are never changed.
dw_de_figure_source <- function(r, ft, a) {
  ids <- as.character(ft$feature_id)
  ix <- match(ids, rownames(r$res))
  display_effect <- if (is.null(r$shr)) r$res$log2FoldChange else r$shr$log2FoldChange
  if (anyNA(ix) || anyDuplicated(ids) || !setequal(ids, rownames(r$res)) ||
      !isTRUE(all.equal(ft$padj, r$res$padj[ix], check.attributes = FALSE, tolerance = 0)) ||
      !isTRUE(all.equal(ft$pvalue, r$res$pvalue[ix], check.attributes = FALSE, tolerance = 0)) ||
      !isTRUE(all.equal(ft$log2fc, display_effect[ix], check.attributes = FALSE, tolerance = 0)))
    stop("OS_INVALID_RESULT: plotted DESeq2 IDs and P/q values differ from the actual tested object.", call. = FALSE)
  md <- S4Vectors::metadata(r$res)
  if (length(md$lfcThreshold) != 1L || !identical(as.numeric(md$lfcThreshold), as.numeric(a[["lfc-threshold"]])))
    stop("OS_INVALID_RESULT: supplied DESeq2 test margin differs from native result metadata.", call. = FALSE)
  cutoff <- md$filterThreshold
  if (length(cutoff) != 1L || !is.finite(cutoff))
    stop("OS_INVALID_RESULT: the actual independent-filter threshold is unavailable.", call. = FALSE)
  eligible <- r$res$baseMean >= cutoff
  family <- rownames(r$res)[eligible & is.finite(r$res$pvalue)]
  if (!setequal(family, rownames(r$res)[is.finite(r$res$padj)]))
    stop("OS_INVALID_RESULT: DESeq2 finite adjusted-P IDs disagree with the native independent-filter family.", call. = FALSE)
  keep <- r$prefilter$keep
  if (!is.logical(keep) || anyNA(keep) || is.null(names(keep)) || anyDuplicated(names(keep)) ||
      length(keep) != r$n_input || !setequal(names(keep)[keep], ids))
    stop("OS_INVALID_RESULT: DESeq2 input/prefilter IDs are not fully reconcilable.", call. = FALSE)
  out <- ft; out$log2fc_mle <- r$res$log2FoldChange[ix]; out$prefilter_pass <- TRUE
  out$native_zero_null_coefficient_p <- if (is.null(r$native_zero_null_coefficient_p)) NA_real_ else r$native_zero_null_coefficient_p[ix]
  out$beta_convergence <- if (is.null(r$beta_convergence)) NA else r$beta_convergence[ix]
  excluded <- names(keep)[!keep]
  if (length(excluded)) {
    pad <- out[rep(NA_integer_, length(excluded)), , drop = FALSE]
    pad$feature_id <- excluded; pad$symbol <- ""; pad$filtered_reason <- "prefilter_count_rule"
    pad$prefilter_pass <- FALSE
    out <- rbind(out, pad)
  }
  out <- out[match(names(keep), out$feature_id), , drop = FALSE]; rownames(out) <- NULL
  list(table = out, family_ids = family, family_size = length(family),
    filter_threshold = unname(cutoff),
    family_rule = "finite native raw P after baseMean >= native filterThreshold; no display selection",
    universe = data.frame(feature_id = out$feature_id, prefilter_pass = out$prefilter_pass,
      native_family_member = out$feature_id %in% family, filtered_reason = out$filtered_reason,
      stringsAsFactors = FALSE))
}

deseq2_wald_render <- function(r, ft, a, outdir, colour_reg, disp = NULL) {
  tabs <- list(feature_table = file.path(outdir, "tables", "feature_table.csv"),
               full = file.path(outdir, "tables", "deseq2_results_full.csv"),
               norm = file.path(outdir, "tables", "normalized_counts.csv"),
               vst = file.path(outdir, "tables", "vst_matrix.csv"),
               sf = file.path(outdir, "tables", "size_factors.csv"))
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  write_feature_table(ft, tabs$feature_table)
  if (!is.null(disp)) {
    tabs$display_filtered <- file.path(outdir, "tables", "display_filtered.csv")
    .dw_write_csv(disp, tabs$display_filtered)
  }
  .dw_write_csv(dw_full_table(r, ft), tabs$full)
  .dw_matrix_csv(r$norm[ft$feature_id, , drop = FALSE], tabs$norm)
  .dw_matrix_csv(r$vst[ft$feature_id, , drop = FALSE], tabs$vst)
  .dw_write_csv(data.frame(sample = names(r$size_factors), size_factor = unname(r$size_factors),
                           condition = as.character(r$design$coldata[names(r$size_factors), a$condition]),
                           stringsAsFactors = FALSE), tabs$sf)

  contrast_label <- sprintf("%s vs %s", a$target, a$reference)
  method_label <- sprintf("DESeq2 Wald test%s", if (a$shrinkage == "none") "" else sprintf("; %s-shrunken log2 fold change", a$shrinkage))
  figs <- list()
  plot_source <- dw_de_figure_source(r, ft, a)
  plot_ft <- plot_source$table
  tabs$de_plot_source <- file.path(outdir, "tables", "de_plot_source.csv")
  tabs$de_universe <- file.path(outdir, "tables", "de_universe.csv")
  .dw_write_csv(plot_ft, tabs$de_plot_source, digits = 17)
  .dw_write_csv(plot_source$universe, tabs$de_universe)
  margin <- a[["lfc-threshold"]]
  hypothesis <- if (margin > 0) "minimum_effect" else "zero_effect"
  version <- as.character(utils::packageVersion("DESeq2"))
  test_id <- paste("DESeq2", r$coef, hypothesis, format(margin, digits = 17), sep = ":")
  test <- os_de_test_contract(hypothesis, margin, hypothesis, margin,
    p_value_source = "Current DESeq2 results: unshrunken Wald, altHypothesis=greaterAbs, declared lfcThreshold",
    test_id = test_id, prespecified = TRUE, test_method = "DESeq2 Wald",
    model_id = r$design$formula_text, software = "DESeq2", software_version = version,
    prior = "DESeq betaPrior=FALSE", shrinkage = "none for the test")
  effect <- list(plotted_estimator = if (a$shrinkage == "none") "MLE" else paste0(a$shrinkage, "-shrunken"),
    tested_estimator = "unshrunken MLE", tested_effect_col = "log2fc_mle", software = "DESeq2", software_version = version,
    shrinkage = a$shrinkage, prior = "backend-specific display prior; exact options retained in calls_registry",
    contrast = list(numerator = a$target, reference = a$reference, expanded_control = "unknown"),
    sample_counts = list(reference_samples = r$n_ref, target_samples = r$n_target), independent_unit = "declared biological sample")
  if (!is.null(a[["subject-col"]])) {
    cd_subject <- r$sample_metadata %||% r$design$coldata
    if (!a[["subject-col"]] %in% names(cd_subject)) stop("OS_MISSING_COLUMN: declared subject column is unavailable.", call. = FALSE)
    subject <- .os_replicate_strings(cd_subject[[a[["subject-col"]]]], "actual DESeq2 subject IDs")
    names(subject) <- rownames(cd_subject)
    effect$sample_counts <- c(effect$sample_counts, list(reference_subjects = length(unique(subject[r$samples_ref])),
      target_subjects = length(unique(subject[r$samples_target])), total_subjects = length(unique(subject[colnames(r$norm)]))))
    effect$independent_unit <- "declared biological subject; observations and subjects counted separately; model design unchanged"
  }
  display <- a[["display-lfc-filter"]] %||% 0
  p <- os_volcano(plot_ft, padj_threshold = a$alpha, lfc_threshold = display, label_n = a[["label-n"]],
    contrast_label = contrast_label, method_label = method_label, journal = a$journal,
    test_contract = test, effect_provenance = effect, statistic_method = "DESeq2 Wald", adjustment = "BH",
    family_id = test_id, family_size = plot_source$family_size,
    family_source_ids = plot_source$family_ids, display_operator = ">=")
  if (min(attr(p, "os_meta")$counts$up, attr(p, "os_meta")$counts$down) < a[["label-n"]])
    attr(p, "os_meta")$caption <- sub("The ([0-9]+) most significant features per direction", "Up to \\1 most significant features per direction", attr(p, "os_meta")$caption)
  tabs$de_selection <- file.path(outdir, "tables", "de_selection.csv")
  .dw_write_csv(attr(p, "os_meta")$data$decision_table, tabs$de_selection, digits = 17)
  p <- os_with_meta(p, notes = list(native_independent_filter_threshold = plot_source$filter_threshold,
    native_family_rule = plot_source$family_rule, native_input_feature_count = r$n_input))
  figs$volcano <- os_finalize_figure(p, file.path(outdir, "figures", "volcano"), journal = a$journal)
  p <- os_ma(plot_ft, padj_threshold = a$alpha, lfc_threshold = display, label_n = a[["label-n"]],
    contrast_label = contrast_label, method_label = method_label, journal = a$journal,
    test_contract = test, effect_provenance = effect, statistic_method = "DESeq2 Wald", adjustment = "BH",
    family_id = test_id, family_size = plot_source$family_size,
    family_source_ids = plot_source$family_ids, display_operator = ">=",
    mean_kind = "normalized_count_mean", mean_scale = "linear", mean_unit = "DESeq2 normalized counts")
  p <- os_with_meta(p, notes = list(native_independent_filter_threshold = plot_source$filter_threshold,
    native_family_rule = plot_source$family_rule, native_input_feature_count = r$n_input))
  figs$ma <- os_finalize_figure(p, file.path(outdir, "figures", "ma"), journal = a$journal)
  cd <- data.frame(sample = rownames(r$design$coldata), stringsAsFactors = FALSE)
  cd[[a$condition]] <- as.character(r$design$coldata[[a$condition]])
  sig <- ft[!is.na(ft$padj) & ft$padj < a$alpha, , drop = FALSE]
  if (nrow(sig) >= 2) {
    p <- os_top_heatmap(r$vst, sig, cd, a$condition, n = a[["top-n"]], reference = a$reference, journal = a$journal)
    hm <- attr(p, "os_meta")
    hm$caption <- paste0(hm$caption, sprintf(" Values: %s (blind = FALSE, fitType = \"%s\"%s) of the DESeq2 counts; significant features: BH adjusted P < %s (n = %d).",
                                             r$vst_path, a[["fit-type"]], if (identical(r$vst_path, "vst")) sprintf(", nsub = %d", DW_VST_NSUB) else "",
                                             format(a$alpha), nrow(sig)))
    attr(p, "os_meta") <- hm
    figs$top_heatmap <- os_finalize_figure(p, file.path(outdir, "figures", "top_heatmap"), journal = a$journal)
  }
  if (!is.null(a[["selected-features"]])) {
    selected <- trimws(strsplit(a[["selected-features"]], ",", fixed = TRUE)[[1]])
    .os_sem_ids(selected, "selected DESeq2 feature IDs")
    if (is.null(a[["selection-reason"]]) || !nzchar(trimws(a[["selection-reason"]])) || !all(selected %in% rownames(r$norm)))
      stop("OS_INVALID_INPUT: selected features require a rationale and actual retained normalized-count rows.", call. = FALSE)
    samples <- colnames(r$norm)
    sample_metadata <- r$sample_metadata %||% r$design$coldata
    if (!all(samples %in% rownames(sample_metadata))) stop("OS_INVALID_RESULT: normalized sample IDs do not match original sample metadata.", call. = FALSE)
    points <- expand.grid(feature_id = selected, sample = samples, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    points$value <- as.numeric(r$norm[cbind(match(points$feature_id, rownames(r$norm)), match(points$sample, samples))])
    points$group <- as.character(r$design$coldata[points$sample, a$condition])
    for (column in c(a[["subject-col"]], a[["pair-col"]])) {
      if (!column %in% names(sample_metadata)) stop("OS_MISSING_COLUMN: declared subject/pair column is absent from actual sample metadata.", call. = FALSE)
      points[[column]] <- as.character(sample_metadata[points$sample, column])
    }
    existing <- data.frame(feature_id = selected, value = ft$padj[match(selected, ft$feature_id)],
      statistic_kind = "adjusted_p", test_id = test_id, method = "DESeq2 Wald", family_id = test_id, stringsAsFactors = FALSE)
    p <- os_selected_feature_points(points, selected, a[["selection-reason"]],
      normalization = paste0("DESeq2 size factors (", a[["sf-type"]], ")"), unit = "DESeq2 normalized counts",
      reference = a$reference, subject_col = a[["subject-col"]], pair_col = a[["pair-col"]],
      group_order = c(a$reference, a$target), model_results = existing, colour_registry = colour_reg, journal = a$journal)
    tabs$selected_feature_values <- file.path(outdir, "tables", "selected_feature_values.csv")
    tabs$selected_feature_summary <- file.path(outdir, "tables", "selected_feature_summary.csv")
    .dw_write_csv(points, tabs$selected_feature_values, digits = 17)
    .dw_write_csv(attr(p, "os_meta")$data$group_summary, tabs$selected_feature_summary, digits = 17)
    colour_reg <- attr(p, "os_meta")$colour_registry
    figs$selected_features <- os_finalize_figure(p, file.path(outdir, "figures", "selected_features"), width = "double", journal = a$journal)
  }
  list(tables = tabs, figures = figs, colour_registry = colour_reg)
}

deseq2_wald_results_json <- function(r, ft, cnt, a, outdir, qc, disp = NULL) {
  sig <- ft[!is.na(ft$padj) & ft$padj < a$alpha, , drop = FALSE]
  top <- utils::head(sig[order(sig$padj, -abs(sig$stat), sig$feature_id, method = "radix"), c("feature_id", "symbol", "log2fc", "padj")], 10)
  out <- list(module = DW_MODULE, module_version = DW_MODULE_VERSION,
              contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference),
              design = r$design$formula_text, coefficient = r$coef,
              n_input_features = r$n_input, n_prefiltered_out = r$n_input - cnt$n_tested,
              prefilter_min_count = a[["min-count"]], prefilter_min_samples = r$prefilter$min_samples_used,
              n_tested = cnt$n_tested, alpha = a$alpha, lfc_threshold = a[["lfc-threshold"]],
              fc_criterion = list(
                null_test = if (a[["lfc-threshold"]] > 0) sprintf("|log2 fold change| <= %s", format(a[["lfc-threshold"]])) else "log2 fold change = 0",
                min_effect_lfc_threshold = a[["lfc-threshold"]],
                display_lfc_filter = a[["display-lfc-filter"]],
                display_lfc_type = if (a$shrinkage == "none") "MLE" else sprintf("%s-shrunken", a$shrinkage),
                n_display_filtered = if (is.null(disp)) NA_integer_ else nrow(disp)),
              n_significant = cnt$n_sig, n_up = cnt$n_up, n_down = cnt$n_down,
              n_padj_na = cnt$n_padj_na, n_cooks_outliers = cnt$n_outlier, n_independent_filtered = cnt$n_indep_filtered,
              shrinkage = a$shrinkage, n_reference = r$n_ref, n_target = r$n_target,
              size_factor_type = a[["sf-type"]], dispersion_fit_type = a[["fit-type"]],
              shrinkage_package_version = switch(a$shrinkage, apeglm = as.character(utils::packageVersion("apeglm")),
                                                 ashr = as.character(utils::packageVersion("ashr")), NA_character_),
              heatmap_transformation = list(path = r$vst_path, blind = FALSE, nsub = if (identical(r$vst_path, "vst")) DW_VST_NSUB else NA_integer_,
                                            n_eligible_mean_gt5 = r$n_vst_eligible),
              qc_triggered = qc$table$id[qc$table$triggered], draft_withheld = qc$blocking,
              top_features = lapply(seq_len(nrow(top)), function(i) as.list(top[i, ])))
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, file.path(outdir, "results", "deseq2_wald_results.json"), auto_unbox = TRUE, pretty = TRUE,
                       digits = I(10), na = "null", null = "null")
}

# Values for the template slots (references/reporting-templates.md lists each
# slot next to the field it comes from).
dw_template_values <- function(r, cnt, a) {
  shrink_sentence <- switch(a$shrinkage,
    apeglm = sprintf(paste0("Log2 fold changes were shrunk with apeglm (v%s; lfcShrink type = \"apeglm\", coef = %s, lfcThreshold = 0, ",
                            "apeAdapt = TRUE, apeMethod = \"nbinomCR\") for ranking and visualization; P values are those of the unshrunken Wald test."),
                     as.character(utils::packageVersion("apeglm")), r$coef),
    ashr = sprintf(paste0("Log2 fold changes were shrunk with ashr (v%s; lfcShrink type = \"ashr\", coef = %s, lfcThreshold = 0) for ranking and ",
                          "visualization; P values are those of the unshrunken Wald test."),
                   as.character(utils::packageVersion("ashr")), r$coef),
    normal = sprintf(paste0("Log2 fold changes were shrunk with the normal prior of DESeq2 (lfcShrink type = \"normal\", coef = %s) for ranking ",
                            "and visualization; P values are those of the unshrunken Wald test."), r$coef),
    none = "Log2 fold changes are maximum-likelihood estimates without shrinkage.")
  sf_sentence <- switch(a[["sf-type"]],
    ratio = "Size factors were estimated with the median-of-ratios method (DESeq sfType = \"ratio\").",
    poscounts = "Size factors were estimated with the modified geometric mean over positive counts (DESeq sfType = \"poscounts\").")
  disp_sentence <- switch(a[["fit-type"]],
    parametric = "Gene-wise dispersions were shrunk towards a parametric mean-dispersion trend (fitType = \"parametric\").",
    local = "Gene-wise dispersions were shrunk towards a local regression mean-dispersion trend (fitType = \"local\").",
    mean = "Gene-wise dispersions were shrunk towards the mean of the gene-wise dispersion estimates (fitType = \"mean\").")
  vst_sentence <- if (identical(r$vst_path, "vst")) {
    sprintf("For display (the vst matrix and the heatmap), counts were transformed with vst (blind = FALSE, nsub = %d, fitType = \"%s\"); the transformation is for display only.",
            DW_VST_NSUB, a[["fit-type"]])
  } else {
    sprintf(paste0("For display (the vst matrix and the heatmap), counts were transformed with varianceStabilizingTransformation (blind = FALSE, fitType = \"%s\") directly, ",
                   "because only %d features had a mean normalized count above 5 (vst subsamples %d such features); the transformation is for display only."),
            a[["fit-type"]], r$n_vst_eligible, DW_VST_NSUB)
  }
  lfc_sentence <- if (a[["lfc-threshold"]] > 0) sprintf("The null hypothesis was |log2 fold change| <= %s (lfcThreshold).", format(a[["lfc-threshold"]])) else
    "The null hypothesis was a log2 fold change of 0."
  list(deseq2_version = as.character(utils::packageVersion("DESeq2")),
       shrink_pkg_version = switch(a$shrinkage, apeglm = as.character(utils::packageVersion("apeglm")),
                                   ashr = as.character(utils::packageVersion("ashr")), "n/a"),
       r_version = as.character(getRversion()),
       n_input = format(r$n_input, big.mark = ","), n_tested = format(cnt$n_tested, big.mark = ","),
       min_count = a[["min-count"]], min_samples = r$prefilter$min_samples_used,
       design = r$design$formula_text, condition = a$condition, target = a$target, reference = a$reference,
       n_target = r$n_target, n_reference = r$n_ref,
       alpha = format(a$alpha), lfc_sentence = lfc_sentence, shrink_sentence = shrink_sentence,
       sf_sentence = sf_sentence, disp_sentence = disp_sentence, vst_sentence = vst_sentence,
       n_sig = format(cnt$n_sig, big.mark = ","), n_up = format(cnt$n_up, big.mark = ","), n_down = format(cnt$n_down, big.mark = ","),
       n_padj_na = format(cnt$n_padj_na, big.mark = ","), n_outlier = format(cnt$n_outlier, big.mark = ","),
       n_indep = format(cnt$n_indep_filtered, big.mark = ","))
}

deseq2_wald_draft <- function(r, cnt, a, qc, rend, templates_path, outdir, disp = NULL) {
  path <- file.path(outdir, "draft", "methods_results.md")
  if (qc$blocking) {
    os_write_text(c("# deseq2-wald: draft withheld",
                    "",
                    sprintf("Blocker QC rule(s) %s were triggered; no Methods/Results text is written for this run.", paste(qc$blocking_ids, collapse = ", ")),
                    "Read qc/qc_results.csv and fix the input before reporting anything from this run."), path)
    return(invisible(path))
  }
  tp <- os_read_templates(templates_path)
  v <- dw_template_values(r, cnt, a)
  if (!is.null(disp)) {
    v$display_lfc_filter <- format(a[["display-lfc-filter"]])
    v$display_lfc_type <- if (a$shrinkage == "none") "maximum-likelihood" else sprintf("%s-shrunken", a$shrinkage)
    v$n_display <- format(nrow(disp), big.mark = ",")
  }
  caps <- vapply(names(rend$figures), function(n) {
    sprintf("- **%s** (figures/%s.pdf): %s", n, n, rend$figures[[n]]$spec_obj$caption %||% "")
  }, "")
  os_write_text(c("# deseq2-wald: Methods and Results draft", "",
                  "## Methods", "", os_fill_template(tp$methods, v), "",
                  if (!is.null(disp)) c(os_fill_template(tp$methods_display, v), "") else NULL,
                  "## Results", "", os_fill_template(tp$results, v), "",
                  if (cnt$n_padj_na > 0) c(os_fill_template(tp$results_na, v), "") else NULL,
                  if (!is.null(disp)) c(os_fill_template(tp$results_display, v), "") else NULL,
                  "## Figure legends", "", caps), path)
  invisible(path)
}
