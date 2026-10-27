# Precomputed Aalen-Johansen probabilities only; no model, CI or cutpoint search.
os_cif <- function(curves, risk, time_unit, event_label, dataset_name, journal = NULL,
                   evidence_refs = os_figure_evidence("cumulative_incidence")) {
  os_plot_columns(curves, c("time", "cif", "group"), c("time", "cif"))
  os_plot_probability(curves, "cif")
  os_plot_columns(risk, c("time", "n_risk", "group"), c("time", "n_risk"))
  if (!nzchar(time_unit) || !nzchar(event_label) || !nzchar(dataset_name) ||
      any(curves$time < 0) || any(risk$time < 0) ||
      any(risk$n_risk < 0 | risk$n_risk != floor(risk$n_risk)) ||
      anyDuplicated(curves[c("group", "time")]) || anyDuplicated(risk[c("group", "time")]) ||
      any(!nzchar(as.character(curves$group))) || any(!nzchar(as.character(risk$group))) ||
      !setequal(curves$group, risk$group)) stop("OS_INVALID_INPUT: invalid CIF display identity or risk counts", call. = FALSE)
  groups <- unique(as.character(curves$group))
  curves$group <- factor(curves$group, levels = groups)
  curves <- curves[order(curves$group, curves$time), , drop = FALSE]
  if (any(vapply(groups, function(g) any(diff(curves$cif[curves$group == g]) < -1e-12), logical(1))))
    stop("OS_INVALID_RESULT: a cumulative incidence curve must not decrease", call. = FALSE)
  if (length(groups) > 6L) stop("OS_TOO_MANY_CATEGORIES: CIF panels support at most six directly interpretable groups", call. = FALSE)
  br <- sort(unique(risk$time))
  if (any(vapply(groups, function(g) {
    r <- risk[risk$group == g, , drop = FALSE]; r <- r[order(r$time), , drop = FALSE]
    !identical(r$time, br) || any(diff(r$n_risk) > 0) || max(br) > max(curves$time[curves$group == g])
  }, logical(1)))) stop("OS_INVALID_INPUT: CIF risk rows need one shared, bounded time grid and nonincreasing original-subject counts", call. = FALSE)
  if (!requireNamespace("patchwork", quietly = TRUE)) stop("OS_MISSING_PACKAGE: patchwork", call. = FALSE)
  pal <- os_group_colours(groups); xr <- range(c(0, curves$time, risk$time))
  pt <- max(7.5, os_journal(journal)$min_pt)
  p <- ggplot2::ggplot(curves, ggplot2::aes(time, cif, colour = group)) +
    ggplot2::geom_step(linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::scale_colour_manual(values = pal) +
    ggplot2::scale_x_continuous(limits = xr, breaks = br, expand = ggplot2::expansion(mult = .02)) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .25), expand = ggplot2::expansion(mult = c(.015, .015))) +
    ggplot2::labs(x = NULL, y = "Cumulative incidence", colour = NULL,
      subtitle = os_wrap(paste0(event_label, " | Aalen-Johansen point estimates; no CI"), 58)) +
    theme_omicstat(journal = journal, legend = "top") +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = pt), legend.text = ggplot2::element_text(size = pt),
      plot.subtitle = ggplot2::element_text(size = pt),
      plot.margin = ggplot2::margin(2, 2, 1, 2, unit = "mm"))
  risk$group <- factor(risk$group, levels = rev(groups))
  r <- ggplot2::ggplot(risk, ggplot2::aes(time, group, label = n_risk, colour = group)) +
    ggplot2::geom_text(size = os_fs(pt), family = os_font_family()) +
    ggplot2::scale_colour_manual(values = pal) +
    ggplot2::scale_x_continuous(limits = xr, breaks = br, expand = ggplot2::expansion(mult = .02)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = .5)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(x = paste0("Time (", time_unit, ")"), y = NULL, title = "Initial-state subjects at risk") +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(axis.text = ggplot2::element_text(size = pt), axis.line.y = ggplot2::element_blank(),
      axis.ticks.y = ggplot2::element_blank(), plot.title = ggplot2::element_text(size = pt),
      plot.margin = ggplot2::margin(0, 2, 2, 2, unit = "mm"))
  out <- patchwork::wrap_plots(p, r, ncol = 1, heights = grid::unit(c(1, 5.2 * length(groups)), c("null", "mm")))
  os_with_meta(out, figure_type = "cumulative_incidence", default_height_mm = 105,
    evidence_refs = evidence_refs,
    caption = paste0("Dataset: ", dataset_name, ". ", event_label,
      ". Unadjusted Aalen-Johansen cumulative incidence, not one minus Kaplan-Meier. ",
      "Point estimates only: no CIF confidence intervals, Gray test or adjusted association. ",
      "All observed group times are retained. At-risk counts are original subjects still in the initial state just before each time; every cause is an exit. The renderer does not fit or recalculate."),
    counts = list(n_groups = length(groups), n_curve_rows = nrow(curves), n_risk_rows = nrow(risk)),
    notes = list(estimator = "Aalen-Johansen", dataset_name = dataset_name, event_label = event_label,
      time_unit = time_unit, uncertainty = "none_source_point_only", risk_times = br,
      shared_time_limits = xr, source_tables_unchanged = TRUE, restyle_support = "not_implemented_for_this_new_type"))
}
