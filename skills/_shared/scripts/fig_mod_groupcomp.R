# One supplied row per biological unit and group. Technical wells must first
# be collapsed by the scientific module using the declared study design.
os_group_points <- function(d, unit_col, ylab, display = c("box", "bar"), comparisons = NULL,
                            test = NULL, adjustment = NULL, family_size = NULL, adjusted = FALSE,
                            journal = NULL, evidence_refs = os_figure_evidence("group_comparison"), paired = FALSE) {
  display <- match.arg(display)
  os_plot_columns(d, c("group", "value", unit_col), "value")
  if (!nzchar(unit_col) || anyDuplicated(d[c("group", unit_col)]))
    stop("OS_INVALID_INPUT: one row per biological unit/group required; aggregate technical replicates upstream", call. = FALSE)
  lv <- if (is.factor(d$group)) intersect(levels(d$group),unique(as.character(d$group))) else unique(as.character(d$group))
  d$group <- factor(d$group, levels = lv)
  if (!is.logical(paired) || length(paired) != 1L || is.na(paired))
    stop("OS_INVALID_INPUT: paired display must be one declared logical value", call. = FALSE)
  if (".os_pair_id" %in% names(d))
    stop("OS_INVALID_INPUT: .os_pair_id is reserved for the paired display payload", call. = FALSE)
  if (paired) {
    units <- as.character(d[[unit_col]])
    if (length(lv) < 2L || anyNA(units) || any(!nzchar(units)) ||
        any(table(units, d$group) != 1L))
      stop("OS_INVALID_INPUT: paired display needs exactly one observation per unit in every declared group", call. = FALSE)
    d$.os_pair_id <- units
  }
  pal <- os_group_colours(lv)
  p <- ggplot2::ggplot(d, ggplot2::aes(group, value))
  summary_table <- NULL
  if (display == "box") p <- p + ggplot2::geom_boxplot(outlier.shape = NA, fill = NA, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data))
  else {
    # Descriptive spread across the supplied biological units, not inferred
    # treatment uncertainty. A singleton has no estimable sample SD.
    summary_table <- do.call(rbind, lapply(lv, function(g) {
      values <- d$value[d$group == g]; n <- length(values); estimate <- mean(values)
      spread <- if (n >= 2L) stats::sd(values) else NA_real_
      data.frame(group = g, n_units = n, mean = estimate, sd = spread,
        lower = estimate - spread, upper = estimate + spread,
        interval_state = if (n >= 2L) "estimable" else "not_estimable_n_lt_2",
        stringsAsFactors = FALSE)
    }))
    summary_table$group <- factor(summary_table$group, levels = lv)
    m <- summary_table; m$value <- m$mean
    p <- p + ggplot2::geom_col(data = m, fill = OS_FIG$col_ns, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
      ggplot2::geom_errorbar(data = m[m$n_units >= 2L, , drop = FALSE],
        ggplot2::aes(ymin = lower, ymax = upper), width = .18, colour = OS_FIG$col_ink,
        linewidth = os_lw(OS_FIG$lw_data))
  }
  if (paired) p <- p + ggplot2::geom_line(ggplot2::aes(group = .os_pair_id),
    colour = OS_FIG$col_ref, alpha = .55, linewidth = os_lw(OS_FIG$lw_segment))
  p <- p + ggplot2::geom_point(ggplot2::aes(colour = group),
    position = if (paired) ggplot2::position_identity() else ggplot2::position_jitter(width = OS_FIG_MODEL$jitter_width, height = 0, seed = 1), size = OS_FIG$pt_sample_mm) +
    ggplot2::scale_colour_manual(values = pal) + ggplot2::labs(x = "Group", y = ylab) + theme_omicstat(journal = journal, legend = "none")
  # The bar caption must not claim an SD that is not drawn: SD needs n >= 2.
  n_by_group <- as.integer(table(factor(d$group, levels = lv)))
  n_text <- paste(strwrap(paste0("n per group: ", paste(paste(lv, n_by_group), collapse = ", ")), 62), collapse = "\n")
  bar_subtitle <- paste0(
    if (all(n_by_group >= 2L)) "Bars: mean +/- SD; points: biological units"
    else if (all(n_by_group == 1L)) "Bars: value of the single biological unit (no error bar);\npoints: biological units"
    else "Bars: mean; +/- SD error bar only where n >= 2 (n = 1: unit value);\npoints: biological units",
    "\n", n_text)
  if (display == "bar") p <- p + ggplot2::labs(subtitle = bar_subtitle) +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(size = OS_FIG$size_axis_text))
  labels <- character()
  if (!is.null(comparisons) && nrow(comparisons)) {
    comparisons <- os_comparison_labels(comparisons, lv, test, adjustment, family_size, adjusted)
    os_plot_columns(comparisons, c("group1", "group2", "y"), "y")
    comparisons$x1 <- match(comparisons$group1, lv); comparisons$x2 <- match(comparisons$group2, lv)
    if (anyNA(comparisons[c("x1", "x2")])) stop("OS_INVALID_INPUT: unknown bracket group", call. = FALSE)
    labels <- comparisons$caption
    comparisons$label <- comparisons$short_label
    span <- diff(range(d$value))
    if (max(comparisons$y)-min(d$value) > 3*max(span, .Machine$double.eps))
      warning("OS_FIG_BRACKET_BUDGET: comparison annotations exceed twice the observed vertical range; use a comparison table or separate panel, retaining all source rows.",call.=FALSE)
    comparisons$ym <- comparisons$y - max(diff(range(c(d$value, comparisons$y))), 1) * OS_FIG_MODEL$bracket_tip_fraction
    p <- p + ggplot2::geom_segment(data = comparisons, ggplot2::aes(x = x1, xend = x2, y = y, yend = y), inherit.aes = FALSE, linewidth = os_lw(OS_FIG$lw_ref)) +
      ggplot2::geom_segment(data = comparisons, ggplot2::aes(x = x1, xend = x1, y = y, yend = ym), inherit.aes = FALSE, linewidth = os_lw(OS_FIG$lw_ref)) +
      ggplot2::geom_segment(data = comparisons, ggplot2::aes(x = x2, xend = x2, y = y, yend = ym), inherit.aes = FALSE, linewidth = os_lw(OS_FIG$lw_ref)) +
      ggplot2::geom_text(data = transform(comparisons, label = os_p_label_plotmath(short_label)), ggplot2::aes(x = (x1 + x2)/2, y = y, label = label), inherit.aes = FALSE, parse = TRUE, size = os_fs(OS_FIG$size_annot), vjust = -0.5) +
      # headroom so the superscripted label above the top bracket is not clipped
      ggplot2::expand_limits(y = max(comparisons$y) + 0.09 * diff(range(c(d$value, comparisons$y))))
  }
  out <- os_with_meta(p, figure_type = "group_comparison", default_height_mm = 75, evidence_refs = evidence_refs,
    caption = paste(if (paired) "Points joined by a grey trajectory are the same paired biological unit in the declared group order. Paired points have no jitter; neither trajectories nor overlaps imply independent units." else
      "Points are biological units; deterministic horizontal jitter does not change values.",
      if (display == "box") "Box: median, quartiles and 1.5-IQR whiskers; all observations remain visible." else
        paste0(if (any(n_by_group < 2L)) "In a group with a single biological unit the bar is that unit value and no error bar (no SD) is drawn. " else "", "Bars: arithmetic means. Error bars: mean +/- sample standard deviation (SD; denominator n-1) across the supplied biological units within each group, not confidence intervals or standard errors. SD is undefined and the error bar omitted for n < 2; the bar and all unit points remain. No distributional support clipping is applied."),
      paste(names(table(d$group)), as.integer(table(d$group)), "biological units", collapse = "; "), paste(labels, collapse = "; ")),
    counts = list(n_units = length(unique(d[[unit_col]])), per_group = as.list(table(d$group))),
    data = list(summary_table = summary_table),
    notes = list(numeric_precision="binary64_roundtrip",unit_col = unit_col, display = display,
       summary_statistic = if (display == "bar") "arithmetic_mean" else "median_and_quartiles",
       error_type = if (display == "bar") "sample_standard_deviation" else "Tukey_1.5_IQR_whiskers",
       error_formula = if (display == "bar") "sqrt(sum((value - mean(value))^2) / (n_units - 1))" else "boxplot.stats",
       comparisons = comparisons,
       inference_scope="Only supplied comparison results are annotated; separate significance/interval overlap does not establish an interaction or equivalence."))
  if (paired) out <- os_with_meta(out, counts = list(n_paired_units = length(unique(d$.os_pair_id))),
    notes = list(paired = TRUE, paired_unit_column = unit_col, pairing_display = "connected_same_unit_no_jitter",
      pairing_inference_recomputed = FALSE))
  if (!exists(".os_restyle_attach", mode="function")) return(out)
  built <- ggplot2::ggplot_build(p)
  point_i <- (if (display == "box") 2L else 3L) + as.integer(paired)
  points <- d; points$.x <- as.numeric(built$data[[point_i]]$x)
  box <- if (display == "box") built$data[[1L]][c("x","ymin","lower","middle","upper","ymax","group")] else NULL
  if (!is.null(box)) { box$x <- as.numeric(box$x); box$width <- as.numeric(built$data[[1L]]$xmax-built$data[[1L]]$xmin) }
  colour_bars <- FALSE
  .os_restyle_attach(out, "group_comparison", environment())
}
