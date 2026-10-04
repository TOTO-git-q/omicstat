# fig_mod_bulk.R -- figure builders added by the M1 bulk modules
# (MODULE_BUILD_BRIEF sec 4). ASCII only on purpose. Loaded last-but-one by
# fig_all.R, after fig_style.R / fig_heatmap.R / fig_bulk.R, so it may call
# any os_* builder defined there. Rules: FIGURE_STYLE tokens only (no colour,
# size, shape or position literals), automatic caption with thresholds and n,
# figure_spec, lint-clean under the nature and cell presets. One clearly
# headed block per module; document each builder in FIGURE_STYLE.md sec 19.x.

# ---- sva-batch ----
# Before/after PCA pair (PACK F row 1: "PC1 vs PC2 coloured by batch, shaped
# by group, two panels"; SUITE cross-module rule 7: "correction before/after
# plots can sit side by side"). One composed 2-panel figure built from the
# existing os_pca_scores() / os_pca_plot() (fig_bulk.R) + os_compose()
# (fig_compose.R): panel a is the input matrix, panel b is the display-only
# corrected matrix (ComBat / ComBat_seq output, or limma::removeBatchEffect
# with the estimated surrogate variables as covariates for sva/svaseq).
# colour_col / shape_col must already be categorical columns of `coldata`
# (module code buckets a continuous study variable before calling this, so
# no numeric-to-category invention happens inside the shared figure layer).
# Never used for a group comparison (SUITE rule 7; PACK S1 P-1): captions say
# "display only" on both panels.
# method_label names the correction in the caption, e.g. "ComBat correction
# for batch". colour_col / shape_col are shown verbatim as legend titles, so
# callers pass the user's own column names.
os_batch_pca_pair <- function(mat_before, mat_after, coldata, colour_col, shape_col = NULL, ntop = 500,
                              colour_registry = NULL, journal = NULL, method_label = "batch correction") {
  .os_require_cols(coldata, c("sample", colour_col), "os_batch_pca_pair")
  pca_before <- os_pca_scores(mat_before, ntop = ntop)
  pca_after <- os_pca_scores(mat_after, ntop = ntop)
  p_before <- os_pca_plot(pca_before, coldata, group_col = colour_col, shape_col = shape_col,
                          colour_registry = colour_registry, journal = journal) +
    ggplot2::labs(title = "Before correction (display only)")
  p_after <- os_pca_plot(pca_after, coldata, group_col = colour_col, shape_col = shape_col,
                         colour_registry = colour_registry, journal = journal) +
    ggplot2::labs(title = "After correction (display only)")
  comp <- os_compose(list(p_before, p_after), ncol = 2, journal = journal,
                     title = "Sample PCA before and after batch correction (display only)")
  m <- attr(comp, "os_meta")
  m$caption <- paste0("Sample principal component analysis before (a) and after (b) ", method_label,
                      "; the corrected matrix is shown for display only and is never used for group testing. ", m$caption)
  attr(comp, "os_meta") <- m
  comp
}

# ---- deseq2-lrt ----
# "Top-gene trajectories" (PACK acceptance/exemplars/deseq2-lrt/PACK.md sec F,
# row 2): normalized counts of the top LRT-significant features plotted
# against a time/ordering column, one small panel per feature, coloured by an
# optional grouping column, individual samples as points and the per-group
# mean as a line (rnaseqGene workflow "Time course experiments", fission
# plotCounts-style display; DESeq2::plotCounts itself defaults to a log10,
# +0.5-pseudocount y-axis, mirrored here). Only a display: the LRT itself
# tests the joint design (deseq2-lrt core.R), never this figure's grouping.
os_lrt_trajectory <- function(norm_mat, ft, coldata, time_col, group_col = NULL, n = 12,
                              reference = NULL, journal = NULL) {
  .os_require_cols(ft, c("feature_id", "padj"), "os_lrt_trajectory")
  if (!time_col %in% names(coldata)) stop(sprintf("OS_MISSING_COLUMNS: os_lrt_trajectory needs time column '%s' in coldata.", time_col), call. = FALSE)
  f <- ft[!is.na(ft$padj) & ft$feature_id %in% rownames(norm_mat), , drop = FALSE]
  f <- f[order(f$padj, f$feature_id, method = "radix"), , drop = FALSE]
  sel <- utils::head(f$feature_id, n)
  labs <- stats::setNames(.os_display_symbol(f[match(sel, f$feature_id), , drop = FALSE]), sel)
  cd <- coldata
  time_num <- suppressWarnings(as.numeric(as.character(cd[[time_col]])))
  use_numeric_time <- !anyNA(time_num)
  cd$.time <- if (use_numeric_time) time_num else as.character(cd[[time_col]])
  cd$.group <- if (!is.null(group_col)) as.character(cd[[group_col]]) else "all"
  long <- do.call(rbind, lapply(sel, function(fid) {
    data.frame(sample = rownames(cd), gene = labs[[fid]], value = unname(norm_mat[fid, rownames(cd)]) + 0.5,
              time = cd$.time, group = cd$.group, stringsAsFactors = FALSE)
  }))
  long$gene <- factor(long$gene, levels = unname(labs[sel]))
  map_aes <- if (is.null(group_col)) ggplot2::aes(x = time, y = value) else ggplot2::aes(x = time, y = value, colour = group, group = group)
  points <- if (is.null(group_col))
    ggplot2::geom_point(shape = 16, size = OS_FIG$pt_highlight_mm * 1.1, stroke = 0, alpha = 0.65, colour = OS_FIG$col_ink) else
    ggplot2::geom_point(shape = 16, size = OS_FIG$pt_highlight_mm * 1.1, stroke = 0, alpha = 0.65)
  means <- if (is.null(group_col))
    ggplot2::stat_summary(fun = mean, geom = "line", linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_ink) else
    ggplot2::stat_summary(fun = mean, geom = "line", linewidth = os_lw(OS_FIG$lw_data))
  p <- ggplot2::ggplot(long, map_aes) + points + means +
    ggplot2::facet_wrap(~gene, scales = "free_y", ncol = 2) +
    ggplot2::scale_y_log10(labels = os_axis_labels) +
    ggplot2::labs(x = time_col, y = "Normalized count + 0.5")
  if (!is.null(group_col)) {
    lv <- sort(unique(cd$.group), method = "radix")
    cols <- os_colours_for(lv, "group", reference = reference)
    p <- p + ggplot2::scale_colour_manual(values = cols$colours, guide = os_guide_legend(group_col))
  }
  p <- p + theme_omicstat(journal = journal, legend = if (is.null(group_col)) "none" else "right")
  os_with_meta(p, figure_type = "lrt_trajectory",
               default_height_mm = min(190, 40 + 30 * ceiling(length(sel) / 2)),
               caption = sprintf(paste0("Normalized counts (+0.5, log10 axis) of the %d features with the smallest ",
                                        "adjusted P values from the likelihood ratio test, plotted against %s%s. Points ",
                                        "are individual samples; lines are the mean at each value of %s%s."),
                                 length(sel), time_col, if (!is.null(group_col)) sprintf(", coloured by %s", group_col) else "",
                                 time_col, if (!is.null(group_col)) sprintf(" within each %s", group_col) else ""),
               data = list(feature_ids = as.list(sel)))
}

# ---- edger-qlf ----
# EdgeR MD plot: x is average log2 CPM already returned by topTags. Never
# log-transform it again; the y axis is the selected contrast's log2 FC.
os_md_edger <- function(ft, padj_threshold = 0.05, lfc_threshold = 0,
                        label_n = 10, contrast_label = NULL, method_label = NULL, journal = NULL) {
  .os_require_cols(ft, c("feature_id", "base_mean", "log2fc", "padj"), "os_md_edger")
  d <- ft[is.finite(ft$base_mean) & is.finite(ft$log2fc), , drop = FALSE]
  d$de_class <- os_de_class(d$log2fc, d$padj, padj_threshold, lfc_threshold)
  d$de_class[d$de_class == "na"] <- "ns"
  d$x <- d$base_mean
  d$y <- d$log2fc
  d <- d[order(d$de_class == "ns", -d$padj, d$feature_id, method = "radix", na.last = FALSE), , drop = FALSE]
  d$display <- .os_display_symbol(d)
  lab <- d[d$feature_id %in% os_pick_labels(d, label_n), , drop = FALSE]
  pal <- c(up = OS_FIG$col_up, down = OS_FIG$col_down, ns = OS_FIG$col_ns)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_point(ggplot2::aes(colour = de_class), shape = OS_FIG$shape_dense,
                        size = OS_FIG$pt_dense_mm, stroke = 0) +
    os_label_place(.os_label_rows(d, lab, lab$padj), ggplot2::aes(label = display), italic = TRUE, journal = journal) +
    ggplot2::scale_colour_manual(values = pal, guide = "none") +
    ggplot2::scale_x_continuous(labels = os_axis_labels) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = OS_AXIS$log2cpm, y = OS_AXIS$log2fc, title = contrast_label) +
    theme_omicstat(journal = journal, legend = "none")
  if (lfc_threshold > 0) p <- p + os_hline(c(-lfc_threshold, lfc_threshold))
  n_up <- sum(d$de_class == "up"); n_down <- sum(d$de_class == "down")
  os_with_meta(p, figure_type = "edger_md", default_height_mm = 75,
               caption = sprintf("edgeR MD plot for %s: average log2 counts per million versus log2 fold change (%s). BH adjusted P <= %s%s; up n = %d, down n = %d; %d labelled features.",
                                 contrast_label %||% "the contrast", method_label %||% "QLF", padj_threshold,
                                 if (lfc_threshold > 0) sprintf(" and |log2 fold change| >= %s", lfc_threshold) else "",
                                 n_up, n_down, nrow(lab)),
               encodings = list(colour = as.list(pal)),
               thresholds = list(padj = padj_threshold, abs_log2fc = lfc_threshold),
               counts = list(up = n_up, down = n_down, labelled = nrow(lab)),
               data = list(labelled_feature_ids = as.list(sort(lab$feature_id, method = "radix"))))
}

# ---- S4 shared bulk diagnostics (edger-qlf, limma-voom, limma-dupcor, sva-batch) ----
# Added in the S4 concentrated fix (docs/build/S4_REPORT.md). Every builder
# only DRAWS numbers that the module computed with the package's own function
# (limma::plotMDS(plot = FALSE), edgeR::glmQLFit, limma::voom(save.plot =
# TRUE), the ComBat empirical-Bayes estimates); nothing statistical is
# re-estimated here except a display kernel density (os_prior_density).

# Sample MDS (limma::plotMDS coordinates). coords: data.frame(sample, dim1,
# dim2); var_explained: proportions for the two dimensions (plotMDS
# $var.explained); distance_label: e.g. "leading log2 fold change" (plotMDS
# gene.selection = "pairwise") or "log2 fold change" ("common");
# input_label: the scale of the input matrix (e.g. "log2 CPM, prior count 2");
# top: the plotMDS top argument; n_features: rows of the input matrix.
os_sample_mds <- function(coords, var_explained, coldata, group_col, shape_col = NULL, reference = NULL,
                          distance_label = "leading log2 fold change", input_label = "log2 expression", top = 500,
                          n_features = NA_integer_, colour_registry = NULL, journal = NULL) {
  .os_require_cols(coords, c("sample", "dim1", "dim2"), "os_sample_mds")
  if (length(var_explained) < 2L) stop("OS_INVALID_INPUT: os_sample_mds needs the variance explained by two dimensions.", call. = FALSE)
  pca <- list(scores = data.frame(sample = coords$sample, PC1 = coords$dim1, PC2 = coords$dim2, stringsAsFactors = FALSE),
              percent_var = 100 * var_explained[1:2], ntop = top)
  p <- os_pca_plot(pca, coldata, group_col = group_col, shape_col = shape_col, reference = reference,
                   colour_registry = colour_registry, journal = journal)
  m <- attr(p, "os_meta")
  ttl <- paste0(toupper(substr(distance_label, 1, 1)), substring(distance_label, 2))
  p <- p + ggplot2::labs(x = sprintf("%s dim 1 (%.1f%%)", ttl, 100 * var_explained[1]),
                         y = sprintf("%s dim 2 (%.1f%%)", ttl, 100 * var_explained[2]))
  cap <- sprintf(paste0("Multidimensional scaling of %d samples (limma plotMDS): distances are the %s between each pair of samples, ",
                        "computed from the top %d features%s of the %s input. Each point is one sample, coloured by %s%s. ",
                        "Percentages give the proportion of variance explained by each dimension. %s"),
                 nrow(coords), distance_label, as.integer(top),
                 if (!is.na(n_features)) sprintf(" (of %d)", as.integer(n_features)) else "", input_label,
                 group_col, if (!is.null(shape_col)) paste0(" and shaped by ", shape_col) else "",
                 if (isTRUE(m$data$common_scale)) "Axes on a common scale." else "Axes NOT on a common scale because the two dimensions span very different ranges.")
  attr(p, "os_meta") <- m
  os_with_meta(p, figure_type = "mds", caption = cap,
               data = utils::modifyList(m$data, list(var_explained = as.list(round(var_explained[1:2], 6)), top = top,
                                                     distance = distance_label, input = input_label)))
}

# edgeR quasi-likelihood dispersion (the plotQLDisp display): x = AveLogCPM,
# y = quarter-root QL dispersion; raw (unshrunk) and squeezed (empirical Bayes
# posterior) as points, the fitted trend as a line. d: data.frame(ave_logcpm,
# raw, squeezed, trended) on the dispersion scale (not yet quarter-rooted).
os_ql_dispersion <- function(d, df_prior = NA_real_, robust = NA, n_outlier = NA_integer_, method_label = "glmQLFit",
                             journal = NULL) {
  .os_require_cols(d, c("ave_logcpm", "raw", "squeezed", "trended"), "os_ql_dispersion")
  d <- d[is.finite(d$ave_logcpm) & is.finite(d$raw) & is.finite(d$squeezed) & is.finite(d$trended), , drop = FALSE]
  pts <- rbind(data.frame(x = d$ave_logcpm, y = d$raw^0.25, kind = "Raw", stringsAsFactors = FALSE),
               data.frame(x = d$ave_logcpm, y = d$squeezed^0.25, kind = "Squeezed", stringsAsFactors = FALSE))
  tr <- d[order(d$ave_logcpm, method = "radix"), , drop = FALSE]
  tr <- data.frame(x = tr$ave_logcpm, y = tr$trended^0.25, kind = "Trended", stringsAsFactors = FALSE)
  pal <- c(Raw = OS_FIG$col_ns, Squeezed = OS_FIG$col_up, Trended = OS_FIG$col_down)
  pts$kind <- factor(pts$kind, levels = names(pal)); tr$kind <- factor(tr$kind, levels = names(pal))
  p <- ggplot2::ggplot(pts, ggplot2::aes(x = x, y = y, colour = kind)) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm, stroke = 0) +
    ggplot2::geom_line(data = tr, linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::scale_colour_manual(values = pal, breaks = names(pal), drop = FALSE, guide = os_guide_legend("QL dispersion")) +
    ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = OS_AXIS$log2cpm, y = "Quarter-root QL dispersion") +
    theme_omicstat(journal = journal, legend = "right") + ggplot2::theme(aspect.ratio = 0.75)
  os_with_meta(p, figure_type = "ql_dispersion", default_height_mm = 65,
               caption = sprintf(paste0("Quasi-likelihood dispersions from %s for %d features: raw (unshrunk) and squeezed ",
                                        "(empirical Bayes) quarter-root QL dispersions against average log2 CPM, with the fitted ",
                                        "trend as a line. Prior df = %s; robust = %s%s."),
                                 method_label, nrow(d), if (is.na(df_prior)) "NA" else format(signif(df_prior, 4)),
                                 if (is.na(robust)) "NA" else as.character(robust),
                                 if (!is.na(n_outlier)) sprintf("; %d features have a prior df below the typical value (robust outliers)", as.integer(n_outlier)) else ""),
               encodings = list(colour = as.list(pal)), counts = list(features = nrow(d)))
}

# voom mean-variance trend (limma::voom(save.plot = TRUE) or the equivalent
# voomLmFit output): xy = $voom.xy (x = log2 count size, y = sqrt residual
# standard deviation), line = $voom.line (lowess fit; the module records span).
os_voom_trend <- function(xy, line, span = NA_real_, n_samples = NA_integer_, title = NULL, journal = NULL) {
  pts <- data.frame(x = xy$x, y = xy$y)
  ln <- data.frame(x = line$x, y = line$y)
  ln <- ln[order(ln$x, method = "radix"), , drop = FALSE]
  p <- ggplot2::ggplot(pts, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm, stroke = 0, colour = OS_FIG$col_ns) +
    ggplot2::geom_line(data = ln, linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_down) +
    ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "log2(count size + 0.5)", y = "Sqrt(standard deviation)", title = title) +
    theme_omicstat(journal = journal, legend = "none") + ggplot2::theme(aspect.ratio = 0.75)
  os_with_meta(p, figure_type = "voom_trend", default_height_mm = 65,
               caption = sprintf(paste0("voom mean-variance trend: each point is one of %d features (square-root residual standard deviation ",
                                        "of the linear model fit against average log2 count size); the line is the lowess trend%s used to ",
                                        "compute the precision weights%s."),
                                 nrow(pts), if (!is.na(span)) sprintf(" (span = %s)", format(span)) else "",
                                 if (!is.na(n_samples)) sprintf(" for %d samples", as.integer(n_samples)) else ""),
               counts = list(features = nrow(pts)))
}

# ComBat empirical-Bayes prior diagnostic (the ComBat(prior.plots = TRUE)
# content drawn in the shared layer). emp: data.frame(batch, parameter in
# c("gamma", "delta"), value) holding the per-feature estimates gamma.hat /
# delta.hat; prior: data.frame(batch, parameter, x, density) holding the
# fitted parametric prior density (normal for gamma, inverse gamma for delta)
# evaluated by the module. The empirical curve is a display kernel density.
os_prior_density <- function(emp, prior, n_features, method_label = "ComBat (parametric prior)", journal = NULL) {
  .os_require_cols(emp, c("batch", "parameter", "value"), "os_prior_density")
  .os_require_cols(prior, c("batch", "parameter", "x", "density"), "os_prior_density")
  lab <- c(gamma = "additive (gamma hat)", delta = "multiplicative (delta hat)")
  bl <- sort(unique(as.character(emp$batch)), method = "radix")
  lv <- as.vector(t(outer(bl, lab[c("gamma", "delta")], function(b, l) paste0(b, ": ", l))))
  emp <- emp[is.finite(emp$value), , drop = FALSE]
  emp$panel <- factor(paste0(emp$batch, ": ", lab[emp$parameter]), levels = lv)
  prior$panel <- factor(paste0(prior$batch, ": ", lab[prior$parameter]), levels = lv)
  kinds <- c("Empirical (kernel density)", "Fitted prior")
  emp$kind <- factor(kinds[1], levels = kinds); prior$kind <- factor(kinds[2], levels = kinds)
  pal <- stats::setNames(c(OS_FIG$col_ink, OS_FIG$col_up), kinds)
  p <- ggplot2::ggplot() +
    ggplot2::geom_density(data = emp, ggplot2::aes(x = value, colour = kind), linewidth = os_lw(OS_FIG$lw_data), key_glyph = "path") +
    ggplot2::geom_line(data = prior, ggplot2::aes(x = x, y = density, colour = kind), linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::facet_wrap(~panel, scales = "free", ncol = 2) +
    ggplot2::scale_colour_manual(values = pal, breaks = kinds, drop = FALSE, guide = os_guide_legend(NULL)) +
    ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "Batch-effect estimate", y = "Density") +
    theme_omicstat(journal = journal, legend = "bottom")
  nb <- length(bl)
  os_with_meta(p, figure_type = "combat_prior", default_height_mm = 30 + 38 * nb,
               caption = sprintf(paste0("%s prior diagnostic for %d batches: kernel density of the per-feature batch-effect estimates ",
                                        "(black) against the fitted empirical-Bayes prior (red; normal for the additive effect, ",
                                        "inverse gamma for the multiplicative effect); %d features. Close agreement supports ",
                                        "the parametric prior; marked disagreement suggests par.prior = FALSE. Display only."),
                                 method_label, nb, as.integer(n_features)),
               encodings = list(colour = as.list(pal)), counts = list(batches = nb))
}
