omicstat_ddct_render <- function(res, out, module) {
 m <- res$metadata
 for (i in seq_along(m$targets)) {
  gene <- m$targets[i]; d <- res$tables$biological_units; d <- d[d$target == gene, ]; d$group <- factor(d$group, levels = m$group_order)
  for (scale in c("delta_ct", "fold_change")) {
   d$value <- d[[scale]]
   p <- os_group_points(d, unit_col = "unit", ylab = paste(gene, if (scale == "delta_ct") "Delta Ct (cycles)" else "Relative expression (fold)"), display = m$display, journal = m$journal)
   os_finalize_figure(p, file.path(out, "figures", sprintf("target_%02d_%s", i, scale)), root = out)
  }
 }
}
