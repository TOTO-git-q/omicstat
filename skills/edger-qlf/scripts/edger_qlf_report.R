# edgeR QLF report, tables and figures; wording comes from fenced templates.
.eq_num <- function(x) ifelse(is.na(x), "NA", formatC(x, digits = 10, format = "g"))
.eq_write_csv <- function(df, path) {
  out <- df
  for (k in names(out)) if (is.numeric(out[[k]])) out[[k]] <- .eq_num(out[[k]])
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}
.eq_matrix_csv <- function(m, path) .eq_write_csv(data.frame(feature_id = rownames(m), m, check.names = FALSE), path)
edger_qlf_render <- function(r, ft, a, outdir, colour_reg, disp = NULL) {
  tabs <- list(feature_table = file.path(outdir, "tables", "feature_table.csv"),
               full = file.path(outdir, "tables", "edger_qlf_results_full.csv"),
               logcpm = file.path(outdir, "tables", "logcpm_matrix.csv"),
               bcv = file.path(outdir, "tables", "bcv_diagnostic.csv"))
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  write_feature_table(ft, tabs$feature_table)
  .eq_write_csv(eq_full_table(r, ft), tabs$full)
  .eq_matrix_csv(r$logcpm[ft$feature_id, , drop = FALSE], tabs$logcpm)
  bcv <- data.frame(feature_id = rownames(r$bcv$counts), log2cpm = r$bcv$AveLogCPM,
                    tagwise_bcv = sqrt(r$bcv$tagwise.dispersion), stringsAsFactors = FALSE)
  .eq_write_csv(bcv, tabs$bcv)
  if (!is.null(disp)) {
    tabs$display_filtered <- file.path(outdir, "tables", "display_filtered.csv")
    .eq_write_csv(disp, tabs$display_filtered)
  }
  contrast <- sprintf("%s vs %s", a$target, a$reference)
  method <- if (r$used_treat) sprintf("edgeR glmTreat, FC > %s", format(a[["treat-fc"]])) else "edgeR quasi-likelihood F-test"
  lfc_thr <- if (r$used_treat) log2(a[["treat-fc"]]) else 0
  figs <- list()
  p <- os_volcano(ft, padj_threshold = a$alpha, lfc_threshold = lfc_thr, label_n = a[["label-n"]],
                  contrast_label = contrast, method_label = method, journal = a$journal)
  figs$volcano <- os_finalize_figure(p, file.path(outdir, "figures", "volcano"), journal = a$journal)
  p <- os_md_edger(ft, padj_threshold = a$alpha, lfc_threshold = lfc_thr, label_n = a[["label-n"]],
                   contrast_label = contrast, method_label = method, journal = a$journal)
  figs$md <- os_finalize_figure(p, file.path(outdir, "figures", "md"), journal = a$journal)
  p <- os_diag_xy(bcv, x = "log2cpm", y = "tagwise_bcv", kind = "points", hlines = sqrt(r$bcv$common.dispersion),
                  xlab = OS_AXIS$log2cpm, ylab = "Biological coefficient of variation",
                  caption = sprintf("edgeR BCV diagnostic for %d filtered genes: tagwise BCV versus average log2 CPM; horizontal line is the common BCV (%.3g). %s",
                                    nrow(bcv), sqrt(r$bcv$common.dispersion),
                                    if (isTRUE(a$legacy)) "estimateDisp supplied dispersions to the selected legacy QL fit." else "estimateDisp was used for this display only, not supplied to the new QL fit."),
                  figure_type = "edger_bcv", journal = a$journal)
  figs$bcv <- os_finalize_figure(p, file.path(outdir, "figures", "bcv"), journal = a$journal)
  # QL dispersion (PACK F; edgeR plotQLDisp content, drawn by the shared builder).
  ql <- r$ql
  .eq_write_csv(ql, tabs$ql_dispersion <- file.path(outdir, "tables", "ql_dispersion.csv"))
  robust_df <- max(ql$df_prior)
  n_out <- if (length(unique(ql$df_prior)) > 1L) sum(ql$df_prior < robust_df) else 0L
  legacy <- isTRUE(a$legacy)
  p <- os_ql_dispersion(ql[, c("ave_logcpm", "raw", "squeezed", "trended")], df_prior = robust_df, robust = TRUE, n_outlier = n_out,
                        method_label = sprintf("edgeR glmQLFit (%s QL method, winsor.tail.p = c(0.05, 0.1), abundance trend)", if (legacy) "legacy" else "new"),
                        journal = a$journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste0(meta$caption, sprintf(paste0(" Raw values are %s per gene, as in edgeR plotQLDisp; the prior df shown is the ",
                                                      "largest robust prior df; %d samples, design %s. The NB dispersion inside the QL fit is %s. ",
                                                      "Display only: no significance threshold applies."),
                                               if (legacy) "deviance / residual df (zero-fit corrected)" else "adjusted deviance / adjusted residual df",
                                               ncol(r$logcpm), r$design$formula_text,
                                               if (legacy) "the trended estimateDisp dispersion (legacy = TRUE)"
                                               else sprintf("one common value, %.3g, estimated by glmQLFit from the top %.3g of genes by average log2 CPM",
                                                            r$fit$dispersion[1], r$fit$top.proportion)))
  attr(p, "os_meta") <- meta
  figs$ql_dispersion <- os_finalize_figure(p, file.path(outdir, "figures", "ql_dispersion"), journal = a$journal)
  # Sample MDS (PACK F; User's Guide 4.4.5 plotMDS), coordinates from the core.
  mds <- data.frame(sample = colnames(r$logcpm), dim1 = r$mds$x, dim2 = r$mds$y, stringsAsFactors = FALSE)
  .eq_write_csv(mds, tabs$mds <- file.path(outdir, "tables", "mds_coordinates.csv"))
  cdm <- data.frame(sample = colnames(r$logcpm), stringsAsFactors = FALSE)
  cdm[[a$condition]] <- as.character(r$design$coldata$.eqgrp)
  p <- os_sample_mds(mds, r$mds$var.explained, cdm, a$condition, shape_col = NULL, reference = a$reference,
                     distance_label = "leading log2 fold change",
                     input_label = sprintf("log2 CPM (edgeR cpm, TMM-normalized library sizes, prior count %s)", format(EQ_CPM_PRIOR_COUNT)),
                     top = EQ_MDS_TOP, n_features = nrow(r$logcpm), colour_registry = colour_reg, journal = a$journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste0(meta$caption, sprintf(" Input: the %d genes kept by filterByExpr; all %d samples of the design. Display only.",
                                               nrow(r$logcpm), ncol(r$logcpm)))
  attr(p, "os_meta") <- meta
  figs$mds <- os_finalize_figure(p, file.path(outdir, "figures", "mds"), journal = a$journal)
  sig <- ft[!is.na(ft$padj) & ft$padj <= a$alpha, , drop = FALSE]
  if (nrow(sig) >= 2) {
    cd <- data.frame(sample = rownames(r$design$coldata), stringsAsFactors = FALSE)
    cd[[a$condition]] <- as.character(r$design$coldata$.eqgrp)
    p <- os_top_heatmap(r$logcpm, sig, cd, a$condition, n = a[["top-n"]], reference = a$reference, journal = a$journal)
    meta <- attr(p, "os_meta")
    meta$caption <- paste0(meta$caption, sprintf(" The source set contains %d genes with BH adjusted P <= %s in the %s versus %s contrast across %d samples.",
                                                 nrow(sig), format(a$alpha), a$target, a$reference, ncol(r$logcpm)))
    attr(p, "os_meta") <- meta
    figs$top_heatmap <- os_finalize_figure(p, file.path(outdir, "figures", "top_heatmap"), journal = a$journal)
  }
  list(tables = tabs, figures = figs)
}
edger_qlf_results_json <- function(r, ft, cnt, a, outdir, qc, disp = NULL) {
  out <- list(module = EQ_MODULE, module_version = EQ_MODULE_VERSION, edgeR_version = as.character(utils::packageVersion("edgeR")),
              contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference), design = r$design$formula_text,
              n_input_features = r$n_input, n_filtered_out = r$n_filtered, n_tested = cnt$n_tested,
              n_significant = cnt$n_sig, n_down = cnt$n_down, n_notsig = cnt$n_notsig, n_up = cnt$n_up,
              n_reference = r$design$n_reference, n_target = r$design$n_target, alpha = a$alpha,
              test = if (r$used_treat) "glmTreat" else "glmQLFTest", legacy = isTRUE(a$legacy),
              robust = TRUE, winsor_tail_p = as.list(c(0.05, 0.1)),
              fc_criterion = list(null_test = if (r$used_treat) sprintf("|log2FC| <= log2(%s)", format(a[["treat-fc"]])) else "log2FC = 0",
                                  min_effect_lfc_threshold = if (r$used_treat) log2(a[["treat-fc"]]) else 0,
                                  treat_fc_linear = if (r$used_treat) a[["treat-fc"]] else NULL,
                                  display_lfc_filter = a[["display-lfc-filter"]],
                                  n_display_filtered = if (is.null(disp)) NULL else nrow(disp)),
              qc_triggered = qc$table$id[qc$table$triggered], draft_withheld = qc$blocking)
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, file.path(outdir, "results", "edger_qlf_results.json"), auto_unbox = TRUE, pretty = TRUE,
                       digits = I(10), na = "null", null = "null")
}
edger_qlf_draft <- function(r, cnt, a, qc, rend, templates_path, outdir, disp = NULL) {
  path <- file.path(outdir, "draft", "methods_results.md")
  if (qc$blocking) {
    os_write_text(c("# edger-qlf: draft withheld", "", "Input blocker; read qc/qc_results.csv."), path)
    return(invisible(path))
  }
  tp <- os_read_templates(templates_path)
  v <- list(edger_version = as.character(utils::packageVersion("edgeR")), r_version = as.character(getRversion()),
            n_input = format(r$n_input, big.mark = ","), n_tested = format(cnt$n_tested, big.mark = ","),
            design = r$design$formula_text, condition = a$condition, target = a$target, reference = a$reference,
            n_target = r$design$n_target, n_reference = r$design$n_reference,
            alpha = format(a$alpha), legacy = if (isTRUE(a$legacy)) "TRUE" else "FALSE",
            dispersion_note = if (isTRUE(a$legacy)) "estimateDisp supplied the dispersion-bearing DGEList required by the legacy QL fit and the BCV diagnostic." else "estimateDisp supplied only the BCV diagnostic, not the new QL fit.",
            test_detail = if (r$used_treat) sprintf("glmTreat(lfc = log2(%s), null = \"interval\")", format(a[["treat-fc"]])) else "glmQLFTest(poisson.bound = TRUE)",
            n_sig = format(cnt$n_sig, big.mark = ","), n_down = format(cnt$n_down, big.mark = ","),
            n_notsig = format(cnt$n_notsig, big.mark = ","), n_up = format(cnt$n_up, big.mark = ","),
            min_count = a[["min-count"]], min_total_count = a[["min-total-count"]], large_n = a[["large-n"]], min_prop = a[["min-prop"]])
  caps <- vapply(names(rend$figures), function(n) sprintf("- **%s**: %s", n, rend$figures[[n]]$spec_obj$caption %||% ""), "")
  os_write_text(c("# edger-qlf: Methods and Results draft", "", "## Methods", "", os_fill_template(tp$methods, v), "",
                  if (!is.null(disp)) sprintf("A display-only filter selected %d significant rows with |log2FC| >= %s; the full BH table and P values were unchanged.", nrow(disp), format(a[["display-lfc-filter"]])) else NULL,
                  "## Results", "", os_fill_template(tp$results, v), "", "## Figure legends", "", caps), path)
  invisible(path)
}
