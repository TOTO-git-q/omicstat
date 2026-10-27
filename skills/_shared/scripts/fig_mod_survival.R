# Precomputed survival data only: builders never choose a cutpoint or fit a model.
os_km <- function(curves, risk, time_unit, logrank_p = NULL, journal = NULL,
                  evidence_refs = os_figure_evidence("survival"), analysis_label = NULL) {
  os_plot_columns(curves, c("time", "survival", "group"), c("time", "survival"))
  os_plot_probability(curves, "survival")
  os_plot_columns(risk, c("time", "n_risk", "group"), c("time", "n_risk"))
  if (!nzchar(time_unit) || any(curves$time < 0) || any(risk$time < 0) ||
      any(risk$n_risk < 0 | risk$n_risk != floor(risk$n_risk)) ||
      !setequal(curves$group, risk$group) || anyDuplicated(risk[c("time", "group")]))
    stop("OS_INVALID_INPUT: invalid risk table, groups or time unit", call. = FALSE)
  if (!requireNamespace("patchwork", quietly = TRUE)) stop("OS_MISSING_PACKAGE: patchwork", call. = FALSE)
  curves <- curves[order(curves$group, curves$time), , drop = FALSE]
  pal <- os_group_colours(unique(as.character(curves$group)))
  xr <- range(c(0, curves$time, risk$time)); br <- sort(unique(risk$time))
  p <- ggplot2::ggplot(curves, ggplot2::aes(time, survival, colour = group)) +
    ggplot2::geom_step(linewidth = os_lw(OS_FIG$lw_data))
  if (all(c("lower", "upper") %in% names(curves))) {
    os_plot_probability(curves, c("lower", "upper"))
    if (any(curves$lower > curves$survival | curves$upper < curves$survival))
      stop("OS_INVALID_INPUT: survival interval does not contain estimate", call. = FALSE)
    # Step interval boundaries preserve KM jumps; no interpolated ribbon.
    p <- p + ggplot2::geom_step(ggplot2::aes(y = lower), linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref)) +
      ggplot2::geom_step(ggplot2::aes(y = upper), linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref))
  }
  if ("n_censor" %in% names(curves)) {
    os_plot_columns(curves, "n_censor", "n_censor")
    if (any(curves$n_censor < 0)) stop("OS_INVALID_INPUT: negative censor count", call. = FALSE)
    p <- p + ggplot2::geom_point(data = curves[curves$n_censor > 0, , drop = FALSE], shape = OS_FIG_MODEL$censor_shape,
                                size = OS_FIG$pt_sample_mm)
  }
  lab <- if (is.null(logrank_p)) "No log-rank test supplied." else os_p_label(logrank_p, "Log-rank", adjusted = FALSE)
  if (!is.null(analysis_label)) lab <- paste(analysis_label, lab, sep = " | ")
  # Use the curve width for data, with one compact legend above and one shared
  # time axis below the risk table. Give each risk row a physical height rather
  # than reserving a quarter of the canvas for two rows of numbers.
  text_pt <- max(7.5, os_journal(journal)$min_pt)
  risk_row_mm <- 5.2
  p <- p + ggplot2::scale_colour_manual(values = pal) +
    ggplot2::scale_x_continuous(limits = xr, breaks = br, expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .25),
                              expand = ggplot2::expansion(mult = c(.015, .015))) +
    ggplot2::labs(x = NULL, y = "Survival probability", colour = NULL, subtitle = os_wrap(lab, width = 50)) +
    theme_omicstat(journal = journal, legend = "top") +
    ggplot2::guides(colour = ggplot2::guide_legend(nrow = if (length(pal) <= 3L) 1L else 2L, byrow = TRUE)) +
    ggplot2::theme(axis.text = ggplot2::element_text(size = text_pt),
      axis.title = ggplot2::element_text(size = text_pt + 1),
      axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(size = text_pt),
      legend.justification = "left", legend.key.height = grid::unit(3, "mm"),
      legend.key.width = grid::unit(6, "mm"), legend.box.spacing = grid::unit(1, "mm"),
      plot.subtitle = ggplot2::element_text(size = text_pt, margin = ggplot2::margin(b = 1, unit = "mm")),
      plot.margin = ggplot2::margin(2, 2, 1, 2, unit = "mm"))
  risk$group <- factor(risk$group, levels = rev(unique(as.character(curves$group))))
  r <- ggplot2::ggplot(risk, ggplot2::aes(time, group, label = n_risk, colour = group)) +
    ggplot2::geom_text(size = os_fs(text_pt), family = os_font_family()) + ggplot2::scale_colour_manual(values = pal) +
    ggplot2::scale_x_continuous(limits = xr, breaks = br, expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = .5)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(x = paste0("Time (", time_unit, ")"), y = NULL, title = "Number at risk") +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(axis.text = ggplot2::element_text(size = text_pt),
      axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 2, unit = "mm")),
      axis.title = ggplot2::element_text(size = text_pt + 1),
      axis.line.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(size = text_pt, hjust = 0, margin = ggplot2::margin(b = 1, unit = "mm")),
      plot.margin = ggplot2::margin(0, 2, 2, 2, unit = "mm"))
  risk_height_mm <- risk_row_mm * length(pal)
  out <- patchwork::wrap_plots(p, r, ncol = 1,
    heights = grid::unit(c(1, risk_height_mm), c("null", "mm")))
  out <- os_with_meta(out, figure_type = "kaplan_meier", default_height_mm = 100 + risk_row_mm * max(0, length(pal) - 2L), evidence_refs = evidence_refs,
    caption = paste("Kaplan-Meier survival with aligned numbers of subjects at risk. Censor marks shown when supplied.", lab,
                    if (all(c("lower", "upper") %in% names(curves))) "Dashed interval bounds are supplied estimates; the renderer performs no inference or cutpoint search." else "No confidence interval bounds were supplied to this figure; the renderer does not invent uncertainty or perform cutpoint search."),
    counts = list(n_risk_rows = nrow(risk), n_groups = length(pal)),
    notes = list(time_unit = time_unit, risk_times = br, layout = "compact_shared_time_axis_v2",
      risk_panel_height_mm = risk_height_mm, risk_row_height_mm = risk_row_mm,
      risk_label_margin_mm = 2,
      risk_text_clipping = "off",
      text_size_pt = text_pt, legend = "top", inference_unchanged = TRUE))
  if (!exists(".os_restyle_attach", mode="function")) return(out)
  .os_restyle_attach(out, "kaplan_meier", environment())
}

os_hr_forest <- function(d, ci_level, journal = NULL, evidence_refs = os_figure_evidence("hazard_ratio")) {
  os_plot_columns(d, c("term", "estimate", "ci_low", "ci_high"), c("estimate", "ci_low", "ci_high"))
  if (any(d$ci_low <= 0 | d$estimate < d$ci_low | d$estimate > d$ci_high) || ci_level <= 0 || ci_level >= 1)
    stop("OS_INVALID_INPUT: invalid hazard ratio or interval", call. = FALSE)
  p <- os_experiment_intervals(d, "Hazard ratio (log scale)", sprintf("Hazard ratios with supplied %g%% confidence intervals; null = 1.", ci_level * 100), journal, FALSE)
  p <- p + ggplot2::scale_x_log10(labels = os_axis_labels) + os_vline(1)
  os_with_meta(p, figure_type = "hazard_ratio_forest", evidence_refs = evidence_refs, thresholds = list(null = 1), notes = list(ci_level = ci_level))
}

os_time_roc <- function(d, time_unit, journal = NULL, evidence_refs = os_figure_evidence("time_dependent_roc")) {
  os_plot_columns(d, c("fpr", "tpr", "horizon"), c("fpr", "tpr")); os_plot_probability(d, c("fpr", "tpr"))
  if (!nzchar(time_unit)) stop("OS_INVALID_INPUT: time_unit is required", call. = FALSE)
  d$horizon <- as.character(d$horizon); d <- d[order(d$horizon, d$fpr), , drop = FALSE]
  p <- ggplot2::ggplot(d, ggplot2::aes(fpr, tpr, colour = horizon)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = OS_FIG$col_ref, linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data)) + ggplot2::scale_colour_manual(values = os_group_colours(unique(d$horizon))) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) + ggplot2::labs(x = "False-positive rate", y = "True-positive rate", colour = paste0("Horizon (", time_unit, ")")) + theme_omicstat(journal = journal)
  os_with_meta(p, figure_type = "time_dependent_roc", default_height_mm = 75, evidence_refs = evidence_refs,
    caption = "Supplied time-dependent ROC curves. Censoring estimator, cohort and frozen-model validation must be recorded by the analysis; no AUC is invented by the renderer.", notes = list(time_unit = time_unit))
}

os_lasso_path <- function(d, selected_lambda = NULL, journal = NULL, evidence_refs = os_figure_evidence("lasso_path"), selection_rule = NULL) {
  os_plot_columns(d, c("lambda", "coefficient", "feature"), c("lambda", "coefficient"))
  if (any(d$lambda <= 0) || (!is.null(selected_lambda) && (length(selected_lambda) != 1 || !is.finite(selected_lambda) || selected_lambda <= 0)))
    stop("OS_INVALID_INPUT: lambda must be positive", call. = FALSE)
  p <- ggplot2::ggplot(d, ggplot2::aes(lambda, coefficient, group = feature)) +
    ggplot2::geom_line(colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::scale_x_log10(labels = os_axis_labels) + ggplot2::labs(x = "Penalty lambda (log scale)", y = "Coefficient") + theme_omicstat(journal = journal, legend = "none")
  caption <- "Coefficient paths from the supplied penalized model. Each line is a feature; selection is performed upstream, never from this plot."
  if (!is.null(selected_lambda)) {
    # Name the penalty the dashed line marks and how many coefficients are non-zero there
    # (count read from the supplied path; not recomputed when the penalty is off the grid).
    on_grid <- abs(d$lambda / selected_lambda - 1) < 1e-9
    k <- if (any(on_grid)) sum(d$coefficient[on_grid] != 0) else NA_integer_
    rule <- if (is.null(selection_rule)) "selected penalty" else as.character(selection_rule)
    line_label <- paste0(rule, if (is.na(k)) "" else paste0("\n", k, " non-zero"))
    p <- p + os_vline(selected_lambda) +
      ggplot2::annotate("text", x = selected_lambda / 1.08, y = max(d$coefficient), label = line_label,
                        hjust = 1, vjust = 1, size = os_fs(OS_FIG$size_annot), lineheight = 0.95)
    caption <- paste0(caption, " Dashed vertical line: the penalty used for the risk score (", rule, ", lambda = ",
      signif(selected_lambda, 4), if (is.na(k)) "" else paste0("; ", k, " non-zero coefficient", if (k == 1) "" else "s", " at that penalty"),
      "). Risk groups come from ranking the linear predictor, so a score built from a few small coefficients can still separate groups in the training data; that separation is apparent, not validated.")
  }
  os_with_meta(p, figure_type = "lasso_path", default_height_mm = 65, evidence_refs = evidence_refs,
    caption = caption,
    thresholds = list(selected_lambda = selected_lambda), counts = list(n_features = length(unique(d$feature))))
}

os_calibration <- function(d, horizon, time_unit, journal = NULL, evidence_refs = os_figure_evidence("survival_calibration")) {
  os_plot_probability(d, c("predicted", "observed"))
  if (length(horizon) != 1 || !is.finite(horizon) || horizon <= 0 || !nzchar(time_unit)) stop("OS_INVALID_INPUT: calibration horizon and unit required", call. = FALSE)
  p <- ggplot2::ggplot(d, ggplot2::aes(predicted, observed)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = OS_FIG$col_ref, linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_point(colour = OS_FIG$col_ink, size = OS_FIG$pt_sample_mm) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) + ggplot2::labs(x = "Predicted event probability", y = "Observed event probability") + theme_omicstat(journal = journal, legend = "none")
  if (all(c("lower", "upper") %in% names(d))) {
    os_plot_probability(d, c("lower", "upper"))
    if (any(d$lower > d$observed | d$upper < d$observed)) stop("OS_INVALID_INPUT: invalid calibration interval", call. = FALSE)
    p <- p + ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0, linewidth = os_lw(OS_FIG$lw_data))
  }
  os_with_meta(p, figure_type = "survival_calibration", default_height_mm = 75, evidence_refs = evidence_refs,
    caption = sprintf("Calibration at %g %s. Points and any intervals are supplied estimates; no smoothing, binning or uncertainty is inferred by the renderer.", horizon, time_unit), notes = list(horizon = horizon, time_unit = time_unit))
}
