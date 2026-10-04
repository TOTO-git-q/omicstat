# Figure builders for limma-voom, limma-array and limma-dupcor.
# All visual constants come from the shared figure style.

# ---- limma-voom / limma-array / limma-dupcor ----
os_limma_volcano <- function(ft, alpha, label_n, contrast, module, journal) {
  os_volcano(ft, padj_threshold = alpha, lfc_threshold = 0, label_n = label_n,
             contrast_label = contrast, method_label = module, italic_labels = FALSE, journal = journal)
}

os_limma_md <- function(ft, alpha, label_n, contrast, module, journal) {
  d <- ft[is.finite(ft$base_mean) & is.finite(ft$log2fc), , drop = FALSE]
  d$class <- ifelse(is.na(d$padj) | d$padj >= alpha, "ns",
                    ifelse(d$log2fc > 0, "up", "down"))
  d <- d[order(match(d$class, c("ns", "down", "up")), d$feature_id, method = "radix"), , drop = FALSE]
  pal <- c(ns = OS_FIG$col_ns, down = OS_FIG$col_down, up = OS_FIG$col_up)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = base_mean, y = log2fc, colour = class)) +
    os_hline(0) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm, stroke = 0) +
    ggplot2::scale_colour_manual(values = pal, guide = "none") +
    ggplot2::scale_x_continuous(labels = os_axis_labels) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "Average log2 expression", y = OS_AXIS$log2fc, title = contrast) +
    theme_omicstat(journal = journal, legend = "none")
  cap <- sprintf("Mean-difference plot (%s; %s). Each point is one of %s tested features; %s up and %s down have BH adjusted P < %s (red and blue). Grey points are not significant. X is average log2 expression, Y is log2 fold change. No post hoc fold-change gate is applied.",
                 contrast, module, os_num(nrow(d)), os_num(sum(d$class == "up")),
                 os_num(sum(d$class == "down")), alpha)
  os_with_meta(p, figure_type = "md", default_height_mm = 70, caption = cap,
               encodings = list(colour = as.list(pal)),
               thresholds = list(padj = alpha, abs_log2fc = 0),
               counts = list(up = sum(d$class == "up"), down = sum(d$class == "down"), ns = sum(d$class == "ns")))
}

os_limma_sa <- function(fit, platform, journal) {
  d <- data.frame(mean_log2 = fit[["Amean"]], sqrt_sigma = sqrt(fit[["sigma"]]))
  d <- d[is.finite(d$mean_log2) & is.finite(d$sqrt_sigma), , drop = FALSE]
  cap <- sprintf("Mean-variance diagnostic (plotSA-style) for normalized %s arrays. Each point is one of %s fitted probes; x is average log2 expression and y is square root of residual standard deviation. Inspect the trend before choosing eBayes trend/robust options.", platform, os_num(nrow(d)))
  os_diag_xy(d, x = "mean_log2", y = "sqrt_sigma", kind = "points",
             xlab = "Average log2 expression", ylab = "sqrt(residual SD)",
             caption = cap, figure_type = "sa_diagnostic", journal = journal)
}
