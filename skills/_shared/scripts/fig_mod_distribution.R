# Display-only distribution-effect intervals. No data fitting, quantile
# estimation, bootstrap, hypothesis test or small-cell disclosure decision.
os_distribution_effects <- function(d, statistic, dataset, unit, min_cell_n,
                                    inference_method, bootstrap_replicates = NULL, journal = NULL) {
  .os_sem_string(dataset, "dataset label"); .os_sem_string(unit, "outcome unit")
  allowed <- c("mean_difference", "smd", "quantile_difference")
  if (length(statistic) != 1L || !statistic %in% allowed || !is.data.frame(d) || !nrow(d) ||
      !all(c("metric_id", "statistic", "estimate", "ci_low", "ci_high", "ci_status", "suppression", "unit", "display_label") %in% names(d)) ||
      anyNA(d$statistic) || any(d$statistic != statistic) || anyNA(d$unit) || any(d$unit != unit))
    stop("OS_INVALID_INPUT: one typed distribution-effect statistic with explicit source identities/units required", call. = FALSE)
  ids <- .os_sem_ids(d$metric_id, "distribution metric identities")
  .os_sem_scalar(min_cell_n, "minimum biological cell size", 10)
  if (min_cell_n != floor(min_cell_n) || !is.character(inference_method) || length(inference_method) != 1L || is.na(inference_method) || !inference_method %in% c("none", "iid_stratified_bootstrap"))
    stop("OS_INVALID_INPUT: invalid source disclosure/inference declaration", call. = FALSE)
  if (inference_method == "iid_stratified_bootstrap") {
    .os_sem_scalar(bootstrap_replicates, "attempted source bootstrap count", 200, 100000)
    if (bootstrap_replicates != floor(bootstrap_replicates)) stop("OS_INVALID_INPUT: source bootstrap count must be an integer", call. = FALSE)
  } else if (!is.null(bootstrap_replicates)) stop("OS_INVALID_INPUT: no sampling inference cannot claim bootstrap draws", call. = FALSE)
  if (!is.character(d$ci_status) || anyNA(d$ci_status) || !is.character(d$suppression) ||
      !is.character(d$display_label) || anyNA(d$display_label) || any(!nzchar(trimws(d$display_label))))
    stop("OS_INVALID_INPUT: explicit source status and readable labels are required", call. = FALSE)
  for (name in c("estimate", "ci_low", "ci_high")) if (!is.numeric(d[[name]]) || any(is.infinite(d[[name]])))
    stop("OS_INVALID_INPUT: effect values must be numeric, missing or finite; no infinite intervals", call. = FALSE)
  released <- is.finite(d$estimate)
  if (anyNA(d$suppression) || any(nzchar(d$suppression) & released))
    stop("OS_INVALID_INPUT: a source-withheld distribution effect cannot be released by the renderer", call. = FALSE)
  ci_ok <- is.finite(d$ci_low) & is.finite(d$ci_high) & released
  if (any(xor(is.finite(d$ci_low), is.finite(d$ci_high))) || any(ci_ok != (d$ci_status == "pointwise_percentile_95")) ||
      any(!released & (is.finite(d$ci_low) | is.finite(d$ci_high))))
    stop("OS_INVALID_INPUT: source interval status, endpoints and withheld estimates disagree", call. = FALSE)
  if (inference_method == "none" && any(ci_ok)) stop("OS_INVALID_INPUT: descriptive-only inference has no sampling intervals", call. = FALSE)
  if (!any(released)) stop("OS_INVALID_INPUT: no released effect to draw; preserve withheld rows in the table", call. = FALSE)
  ci <- if (any(ci_ok)) data.frame(source_id = ids[ci_ok], estimate = d$estimate[ci_ok], lower = d$ci_low[ci_ok], upper = d$ci_high[ci_ok]) else NULL
  u <- if (inference_method == "none") os_uncertainty(statistic, "none", "none", "not_applicable", "not_applicable", "not_applicable",
    reason = "Fixed-record descriptions; sampling inference not requested") else os_uncertainty(statistic, "CI",
      "iid bootstrap within fixed groups; percentile endpoints", "pointwise", "independent biological unit",
      if (all(ci_ok)) "available" else if (any(ci_ok)) "partial" else "unavailable", rows = ci, level = .95,
      reason = "Source small-cell, finite-draw or degenerate-resampling guards may withhold individual estimates/intervals",
      inner_draws = bootstrap_replicates, summary_coverage_required = FALSE)
  # Percentile bootstrap intervals need not enclose the original point estimate.
  # Preserve both values; never widen, clip or substitute another interval.
  states <- data.frame(source_id = ids, state = ifelse(released, "available", "nonestimable"),
    reason = ifelse(released, "source release guard passed", ifelse(nzchar(d$suppression), d$suppression, "source estimate unavailable")))
  layer <- os_semantic_layer("distribution_effects", d, "metric_id", "aggregate", statistic, unit,
    independent_unit = "biological unit", states = states, uncertainty = u, value_columns = "estimate",
    provenance = list(source_table = "tables/effect_table.csv", dataset = dataset, min_cell_n = min_cell_n,
      direction = "group_minus_reference", raw_rows_exported = FALSE))
  pop <- list(status = "unknown", rule = "Independent-unit records remain private; source disclosure guards determine release. Grid rows are not biological n.")
  definition <- os_figure_definition(statistic, "precomputed_aggregate_effect", "biological unit", unit,
    pop, pop, "Supplied source-core estimates only; renderer does not infer effects or uncertainty", list(layer),
    notes = list(dataset = dataset, no_multiplicity_adjustment = TRUE, real_owner_receipt = NULL))
  caption <- paste0("Dataset: ", dataset, ". Direction: group minus the fixed reference. ",
    if (statistic == "smd") "SMD divides the mean difference by the square root of the average two unbiased within-group variances. " else
      if (statistic == "quantile_difference") "Quantiles are inverse-ECDF values at the supplied fixed probability grid, not type-7 sample quantiles. " else "Points are differences of arithmetic biological-unit means. ",
    if (inference_method == "none") "No sampling confidence intervals were requested. " else
      "Lines show supplied 95% pointwise percentile bootstrap CIs; they may not enclose the original estimate. No simultaneous coverage or multiplicity adjustment. ",
    "Minimum cell size: ", min_cell_n, ". Withheld estimates/intervals remain explicit in the table; no individual records, raw ECDF or imputed intervals are drawn.")
  plot_data <- d
  plot_data$metric_id <- factor(plot_data$metric_id, levels = rev(ids))
  p <- ggplot2::ggplot(plot_data[released, , drop = FALSE], ggplot2::aes(x = estimate, y = metric_id)) +
    os_vline(0) + ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm, colour = OS_FIG$col_ink)
  if (any(ci_ok)) p <- p + ggplot2::geom_segment(data = plot_data[ci_ok, , drop = FALSE],
    ggplot2::aes(x = ci_low, xend = ci_high, yend = metric_id), linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_ink)
  title <- switch(statistic, mean_difference = "Mean difference", smd = "Standardized mean difference", quantile_difference = "Fixed-grid quantile difference")
  p <- p + ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_discrete(labels = stats::setNames(d$display_label, ids)) +
    ggplot2::labs(x = paste0(title, " (", unit, ")"), y = NULL, subtitle = os_wrap(paste("Dataset:", dataset), 65)) +
    theme_omicstat(journal = journal, legend = "none")
  binding <- os_validate_render_sources(definition, list(effects = d))
  os_with_meta(p, definition = definition, figure_type = "effect_intervals", caption = caption,
    evidence_refs = os_figure_evidence("effect_intervals"), notes = list(dataset = dataset, render_source_binding = binding,
      source_rows = nrow(d), released_effects = sum(released), no_individual_records_or_raw_draws = TRUE),
    default_height_mm = min(125, max(40, 28 + 5 * sum(released))))
}
