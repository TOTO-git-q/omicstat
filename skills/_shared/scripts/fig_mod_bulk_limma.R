# Figure builders for limma-voom, limma-array and limma-dupcor.
# All visual constants come from the shared figure style.

# ---- limma-voom / limma-array / limma-dupcor ----
os_limma_volcano <- function(ft, alpha, label_n, contrast, module, journal, figure_context = NULL) {
  os_volcano(ft, padj_threshold = alpha, lfc_threshold = figure_context$display_threshold %||% 0, label_n = label_n,
             contrast_label = contrast, method_label = module, italic_labels = FALSE, journal = journal,
             test_contract = figure_context$test, effect_provenance = figure_context$effect,
             statistic_method = figure_context$test$test_method %||% "unknown", adjustment = "BH",
             family_id = figure_context$family_id %||% "unknown", family_size = figure_context$family_size,
             family_source_ids = figure_context$family_source_ids,
             display_operator = ">=")
}

os_limma_md <- function(ft, alpha, label_n, contrast, module, journal, figure_context = NULL) {
  p <- os_ma(ft, padj_threshold = alpha, lfc_threshold = figure_context$display_threshold %||% 0, label_n = label_n,
             contrast_label = contrast, method_label = module, italic_labels = FALSE, journal = journal,
             test_contract = figure_context$test, effect_provenance = figure_context$effect,
             statistic_method = figure_context$test$test_method %||% "unknown", adjustment = "BH",
             family_id = figure_context$family_id %||% "unknown", family_size = figure_context$family_size,
             family_source_ids = figure_context$family_source_ids,
             display_operator = ">=", mean_kind = "mean_log_abundance", mean_scale = "log2",
             mean_transform = "identity", mean_unit = figure_context$abundance_unit %||% "unknown")
  os_with_meta(p, figure_type = "md", caption = paste0("Mean-difference view of supplied average log2 abundance. ", attr(p, "os_meta")$caption))
}

os_limma_sa <- function(fit, platform, journal) {
  d <- data.frame(mean_log2 = fit[["Amean"]], sqrt_sigma = sqrt(fit[["sigma"]]))
  d <- d[is.finite(d$mean_log2) & is.finite(d$sqrt_sigma), , drop = FALSE]
  cap <- sprintf("Mean-variance diagnostic (plotSA-style) for normalized %s arrays. Each point is one of %s fitted probes; x is average log2 expression and y is square root of residual standard deviation. Inspect the trend before choosing eBayes trend/robust options.", platform, os_num(nrow(d)))
  os_diag_xy(d, x = "mean_log2", y = "sqrt_sigma", kind = "points",
             xlab = "Average log2 expression", ylab = "sqrt(residual SD)",
             caption = cap, figure_type = "sa_diagnostic", journal = journal)
}
