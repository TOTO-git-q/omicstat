# Static biomarker ROC display. Inputs are precomputed native aggregates only.
os_roc_curve <- function(curves, auc, dataset, independent_unit, n_positive, n_negative,
                         confidence_level, direction, band = NULL, cutoff = NULL,
                         comparisons = NULL, partial = NULL, journal = NULL) {
  .os_sem_string(dataset, "dataset label"); .os_sem_string(independent_unit, "independent unit")
  .os_sem_scalar(confidence_level, "confidence level", .Machine$double.eps, 1 - .Machine$double.eps)
  for (n in c(n_positive, n_negative)) if (length(n) != 1 || !is.finite(n) || n < 2 || n != floor(n)) stop("OS_INVALID_INPUT: positive and negative independent counts required", call. = FALSE)
  if (!direction %in% c("higher-is-positive", "lower-is-positive")) stop("OS_INVALID_INPUT: ROC direction must be explicit", call. = FALSE)
  os_plot_columns(curves, c("point_id", "marker", "marker_label", "sequence", "fpr", "tpr"), c("sequence", "fpr", "tpr")); os_plot_probability(curves, c("fpr", "tpr"))
  os_plot_columns(auc, c("marker", "marker_label", "estimate", "ci_low", "ci_high", "ci_level"), c("estimate", "ci_low", "ci_high", "ci_level"))
  if (anyDuplicated(auc$marker) || !setequal(auc$marker, curves$marker) || any(auc$ci_level != confidence_level)) stop("OS_INVALID_INPUT: ROC AUC summaries and plotted marker set/CI level disagree", call. = FALSE)
  curves <- curves[order(match(curves$marker, auc$marker), curves$sequence), , drop = FALSE]
  for (k in auc$marker) if (any(diff(curves$fpr[curves$marker == k]) < 0) || anyDuplicated(curves$sequence[curves$marker == k])) stop("OS_INVALID_INPUT: native ROC point order is not monotone/unique", call. = FALSE)
  pop <- list(status = "unknown", rule = "Input subject IDs remain in the private fitted object; these tables contain only precomputed aggregate ROC coordinates. Counts are separately declared, never grid-row counts.")
  layers <- list(os_semantic_layer("roc_coordinates", curves, "point_id", "aggregate", "sensitivity_by_false_positive_rate", "probability",
    independent_unit = independent_unit, value_columns = c("fpr", "tpr"), provenance = list(source_table = "tables/roc_curve.csv", dataset = dataset, n_positive = n_positive, n_negative = n_negative)))
  auc_ci <- data.frame(source_id = auc$marker, estimate = auc$estimate, lower = auc$ci_low, upper = auc$ci_high)
  layers <- c(layers, list(os_semantic_layer("auc_summaries", auc, "marker", "aggregate", "full_auc", "probability", independent_unit = independent_unit,
    value_columns = "estimate", uncertainty = os_uncertainty("full_auc", "CI", "pROC DeLong", "pointwise", "not_applicable", "available", rows = auc_ci, level = confidence_level),
    provenance = list(source_table = "tables/auc_summary.csv", dataset = dataset))))
  statistics <- list()
  if (!is.null(comparisons)) {
    # Each primary-versus-rest test is keyed by its comparator marker, which is a retained auc_summaries source row.
    ids <- as.character(comparisons$comparator)
    for (kind in c("raw_p", "adjusted_p")) statistics[[kind]] <- os_statistic_contract(paste0("paired_delong_", kind),
      if (kind == "raw_p") comparisons$p_raw else comparisons$p_adjusted, ids, kind,
      method = "paired DeLong", adjustment = if (kind == "raw_p") "none" else unique(comparisons$p_adjust_method),
      family_id = unique(comparisons$family), family_size = unique(comparisons$family_size),
      null = "primary full AUC minus comparator full AUC equals zero", alternative = "two.sided")
  }
  if (!is.null(band)) {
    os_plot_columns(band, c("point_id", "fpr", "lower", "median", "upper", "ci_level"), c("fpr", "lower", "median", "upper", "ci_level"))
    os_plot_probability(band, c("fpr", "lower", "median", "upper"))
    if (any(band$lower > band$upper) || any(band$ci_level != confidence_level)) stop("OS_INVALID_INPUT: supplied pointwise ROC intervals invalid", call. = FALSE)
    ci <- data.frame(source_id = band$point_id, estimate = band$median, lower = band$lower, upper = band$upper)
    layers <- c(layers, list(os_semantic_layer("roc_pointwise_band", band, "point_id", "aggregate", "sensitivity_at_fixed_specificity", "probability",
      independent_unit = independent_unit, value_columns = "median", uncertainty = os_uncertainty("sensitivity_at_fixed_specificity", "CI", "pROC::ci.se stratified percentile bootstrap",
        "pointwise", independent_unit, "available", rows = ci, level = confidence_level, inner_draws = unique(band$bootstrap_reps), estimate_column = "median"),
      provenance = list(source_table = "tables/roc_band.csv", dataset = dataset, median_is_bootstrap_summary_not_empirical_curve = TRUE))))
  }
  if (!is.null(cutoff)) layers <- c(layers, list(os_semantic_layer("primary_cutoff", cutoff, "id", "aggregate", "supplied_operating_point", "probability",
    independent_unit = independent_unit, value_columns = c("fpr", "tpr"), provenance = list(source_table = "tables/cutoff_marker.csv", dataset = dataset))))
  if (!is.null(partial)) {
    partial$id <- "partial_region"
    layers <- c(layers, list(os_semantic_layer("partial_auc_region", partial, "id", "aggregate", "uncorrected_partial_auc", "dimensionless ROC area",
      independent_unit = independent_unit, value_columns = c("estimate", "bound_low", "bound_high"), provenance = list(source_table = "tables/partial_auc.csv", dataset = dataset))))
  }
  definition <- os_figure_definition("sensitivity_by_false_positive_rate", "precomputed_threshold_coordinate", independent_unit, "probability",
    pop, pop, "Native empirical ROC coordinates; renderer does not compute AUC, optimize cutoff or resample", layers,
    statistics = statistics, notes = list(dataset = dataset, n_positive = n_positive, n_negative = n_negative, direction = direction,
      x_denominator = "negative independent units", y_denominator = "positive independent units", real_owner_receipt = NULL))
  pal <- os_group_colours(auc$marker)
  legend_labels <- stats::setNames(sprintf("%s; AUC %.3f (%.0f%% CI %.3f to %.3f)", auc$marker_label, auc$estimate, confidence_level * 100, auc$ci_low, auc$ci_high), auc$marker)
  caption <- paste0("Dataset: ", dataset, ". Positive n = ", n_positive, "; negative n = ", n_negative, " independent ", independent_unit, " units. Direction: ", direction, ". ",
    if (!is.null(band)) paste0("Shading: ", 100 * confidence_level, "% pointwise stratified bootstrap CI for sensitivity at fixed specificities; not simultaneous and not an AUC CI. ") else "",
    if (!is.null(cutoff)) paste0("Marked cutoff: ", cutoff$threshold, " (", cutoff$selection, "). ", if (isTRUE(cutoff$exploratory)) "EXPLORATORY data-selected cutoff; apparent performance is optimistic. " else "Prespecified source recorded in methods. ") else "No cutoff marker. ",
    if (!is.null(partial)) "Outlined range is the requested partial-AUC region; its separate bootstrap estimate/CI is tabulated. " else "",
    "The plot does not establish calibration, external validity or clinical utility.")
  if (!is.null(comparisons)) {
    bits <- vapply(seq_len(nrow(comparisons)), function(i) paste0(comparisons$primary_label[i], " vs ", comparisons$comparator_label[i], ": ",
      if (!is.finite(comparisons$p_raw[i])) "native test undefined (degenerate variance)" else paste0(os_p_label(comparisons$p_raw[i], "DeLong", adjusted = FALSE), "; ",
        os_p_label(comparisons$p_adjusted[i], "paired DeLong", adjustment = comparisons$p_adjust_method[i],
          family_size = comparisons$family_size[i], adjusted = TRUE))), "")
    caption <- paste(c(caption, bits, "Paired primary-versus-rest family; adjustment applies to P values, not the pointwise difference CIs."), collapse = " ")
  }
  p <- ggplot2::ggplot()
  if (!is.null(band)) p <- p + ggplot2::geom_ribbon(data = band[order(band$fpr), , drop = FALSE], ggplot2::aes(x = fpr, ymin = lower, ymax = upper),
    fill = pal[1], alpha = .15, colour = NA)
  if (!is.null(partial)) {
    if (partial$focus == "specificity") p <- p + ggplot2::annotate("rect", xmin = 1 - partial$bound_high, xmax = 1 - partial$bound_low, ymin = 0, ymax = 1,
      fill = NA, colour = OS_FIG$col_ref, linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref)) else
      p <- p + ggplot2::annotate("rect", xmin = 0, xmax = 1, ymin = partial$bound_low, ymax = partial$bound_high,
        fill = NA, colour = OS_FIG$col_ref, linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref))
  }
  p <- p + ggplot2::geom_abline(slope = 1, intercept = 0, colour = OS_FIG$col_ref, linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_path(data = curves, ggplot2::aes(x = fpr, y = tpr, colour = marker, group = marker), linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::scale_colour_manual(values = pal, breaks = auc$marker, labels = legend_labels, guide = os_guide_legend("Full AUC and DeLong CI")) +
    ggplot2::scale_x_continuous(breaks = seq(0, 1, .25), expand = ggplot2::expansion(mult = .015)) +
    ggplot2::scale_y_continuous(breaks = seq(0, 1, .25), expand = ggplot2::expansion(mult = .015)) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    ggplot2::labs(x = "False-positive rate (1 - specificity)", y = "Sensitivity", subtitle = os_wrap(paste("Dataset:", dataset), 65)) + theme_omicstat(journal = journal, legend = "bottom")
  if (!is.null(cutoff)) p <- p + ggplot2::geom_point(data = cutoff, ggplot2::aes(x = fpr, y = tpr), shape = 21, fill = OS_FIG$col_bg,
    colour = OS_FIG$col_ink, size = OS_FIG$pt_sample_mm * 1.5, stroke = os_lw(OS_FIG$lw_data))
  binding <- os_validate_render_sources(definition, list(curves = curves, auc = auc, band = band, cutoff = cutoff, partial = partial))
  os_with_meta(p, definition = definition, figure_type = "biomarker_roc", caption = caption,
    evidence_refs = os_figure_evidence("biomarker_roc"), notes = list(dataset = dataset, render_source_binding = binding,
      no_subject_rows_or_IDs_in_figure_source = TRUE, all_numbers_supplied = TRUE), default_height_mm = 110)
}
