omicstat_groupcompare_render <- function(res, out, module) {
 if (identical(res$metadata$analysis_mode, "distribution-effects")) {
  d <- res$tables$effect_table; m <- res$metadata; states <- list()
  for (stat in c("mean_difference", "smd", "quantile_difference")) {
   rows <- d[d$statistic == stat, , drop = FALSE]
   pages <- split(seq_len(nrow(rows)), ceiling(seq_len(nrow(rows)) / 14))
   for (i in seq_along(pages)) {
    page <- rows[pages[[i]], , drop = FALSE]
    name <- sprintf("distribution_%s_%02d", stat, i)
    draw <- any(is.finite(page$estimate))
    states[[length(states) + 1L]] <- data.frame(figure = name, state = if (draw) "rendered" else "withheld_no_released_effect",
      dataset = m$dataset, statistic = stat, source_rows = nrow(page), released_effects = sum(is.finite(page$estimate)))
    if (!draw) next
    p <- os_distribution_effects(page, stat, m$dataset, unique(page$unit), m$min_cell_n,
      m$inference$method, if (isTRUE(m$bootstrap_configuration_active)) m$inference$replicates else NULL, journal = m$journal)
    os_finalize_figure(p, file.path(out, "figures", name), root = out)
   }
  }
  utils::write.csv(do.call(rbind, states), file.path(out, "tables", "distribution_figure_status.csv"), row.names = FALSE)
  return(invisible(NULL))
 }
 d <- res$tables$biological_units; m <- res$metadata
 t <- res$tables$tests; t <- t[!is.na(t$group1), , drop = FALSE]
 cp <- NULL
 if (nrow(t)) {
  span <- max(diff(range(d$value)), 1)
  cp <- data.frame(group1 = t$group1, group2 = t$group2, p = t$p_adjusted, y = max(d$value) + seq_len(nrow(t)) * span * .18)
 }
 p <- os_group_points(d, unit_col = "unit", ylab = m$response, display = m$display, comparisons = cp,
   paired = identical(m$design, "paired"),
   test = m$pairwise_test, adjustment = m$adjustment, family_size = m$family_size, adjusted = m$adjustment != "none", journal = m$journal)
 os_finalize_figure(p, file.path(out, "figures", "group_comparison"), root = out)
}
