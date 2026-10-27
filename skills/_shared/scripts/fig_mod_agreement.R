# Shared display-only Bland-Altman builder. CI and LoA values are inputs.
# No fit, estimator, interval construction, subject exclusion or transformation.
os_bland_altman <- function(pairs, summaries, method_labels, difference, unit,
                            independent_unit, confidence_level, ci_method, dataset,
                            acceptability_limits = NULL, acceptability_rationale = NULL,
                            journal = NULL) {
  .os_sem_string(dataset, "dataset label"); .os_sem_string(unit, "outcome unit")
  .os_sem_string(independent_unit, "independent unit")
  os_plot_columns(pairs, c("subject_id", "pair_mean", "difference"), c("pair_mean", "difference"))
  .os_sem_ids(pairs$subject_id, "independent paired IDs")
  os_plot_columns(summaries, c("term", "estimate", "ci_low", "ci_high", "ci_level"), c("estimate", "ci_low", "ci_high", "ci_level"))
  if (!identical(summaries$term, c("mean_difference", "lower_95pct_LoA", "upper_95pct_LoA")))
    stop("OS_INVALID_INPUT: Bland-Altman summaries must contain the declared bias and two 95% limits in order", call. = FALSE)
  if (length(method_labels) != 2 || anyNA(method_labels) || any(!nzchar(method_labels)) || !difference %in% c("a-minus-b", "b-minus-a"))
    stop("OS_INVALID_INPUT: two method labels and explicit difference direction required", call. = FALSE)
  .os_sem_scalar(confidence_level, "confidence level", .Machine$double.eps, 1-.Machine$double.eps)
  if (any(summaries$ci_level != confidence_level)) stop("OS_INVALID_INPUT: summary CI levels disagree", call. = FALSE)
  if (!"loa_population_coverage" %in% names(summaries) ||
      !is.na(summaries$loa_population_coverage[1]) || anyNA(summaries$loa_population_coverage[2:3]) ||
      any(summaries$loa_population_coverage[2:3] != .95))
    stop("OS_INVALID_INPUT: the two LoA rows must explicitly retain 95% population coverage", call. = FALSE)
  if (!is.null(acceptability_limits)) {
    if (!is.numeric(acceptability_limits) || length(acceptability_limits) != 2 || any(!is.finite(acceptability_limits)) || acceptability_limits[1] >= acceptability_limits[2])
      stop("OS_INVALID_INPUT: ordered prespecified acceptability bounds required", call. = FALSE)
    .os_sem_string(acceptability_rationale, "acceptability rationale")
  }
  effects <- summaries
  population <- list(status = "known", ids = as.list(pairs$subject_id),
    rule = "Every complete independent input pair; no silent deletion, repeated pair or resampling.")
  raw <- os_semantic_layer("pairs", pairs, "subject_id", "observed", "signed_method_difference", unit,
    independent_ids = pairs$subject_id, independent_unit = independent_unit, population_id = "measurement_pairs",
    value_columns = c("pair_mean", "difference"), provenance = list(source_table = "tables/pairs.csv", dataset = dataset))
  ci <- data.frame(source_id = effects$term, estimate = effects$estimate, lower = effects$ci_low, upper = effects$ci_high)
  limits <- os_semantic_layer("bias_and_limits", effects, "term", "aggregate", "bias_and_95pct_population_limits", unit,
    independent_unit = independent_unit, value_columns = "estimate",
    uncertainty = os_uncertainty("bias_and_95pct_population_limits", "CI", ci_method, "pointwise",
      "not_applicable", "available", rows = ci, level = confidence_level),
    provenance = list(source_table = "tables/effect_table.csv", dataset = dataset,
      limits_population_coverage = .95, confidence_level = confidence_level))
  definition <- os_figure_definition("signed_method_difference", "one_complete_pair", independent_unit, unit,
    population, population, "bias=mean(difference); LoA=bias +/- 1.96 SD; each line has its own pointwise CI",
    list(raw, limits), notes = list(no_automatic_transformation = TRUE, no_interchangeability_inference = TRUE,
      dataset = dataset, registered_owner_receipt = NULL))
  direction <- difference
  labs <- unname(method_labels)
  direction_text <- if (direction == "a-minus-b") paste(labs[1], "minus", labs[2]) else paste(labs[2], "minus", labs[1])
  caption <- paste0("Dataset: ", dataset, ". ", nrow(pairs), " independent paired ", independent_unit,
    " units. Mean difference and 95% population limits of agreement are separate lines. Shading: ",
    format(100 * confidence_level), "% pointwise CI for each line, not a prediction interval or simultaneous band. ",
    if (!is.null(acceptability_limits)) "Dotted acceptability bounds were supplied before analysis; uncertainty is included in the table's compatibility check." else
      "No prespecified acceptability bounds: descriptive only. No substitution claim follows from the plot.")
  # Start with the suite diagnostic builder, then attach the fully bound extra
  # layer. The limits source is independently hash-checked against effect_table.
  points_definition <- os_figure_definition("signed_method_difference", "one_complete_pair", independent_unit,
    unit, population, population, "none", list(raw))
  p <- os_diag_xy(pairs, "pair_mean", "difference", kind = "points", xlab = paste0("Mean of paired methods (", unit, ")"),
    ylab = paste0(direction_text, " (", unit, ")"), hlines = 0,
    figure_type = "bland_altman", caption = caption, journal = journal, definition = points_definition)
  bands <- ggplot2::geom_rect(data = effects, ggplot2::aes(ymin = ci_low, ymax = ci_high),
    xmin = -Inf, xmax = Inf, inherit.aes = FALSE, fill = OS_FIG$col_ink, alpha = .08, colour = NA)
  p$layers <- c(list(bands), p$layers)
  p <- p + ggplot2::geom_hline(data = effects, ggplot2::aes(yintercept = estimate, linetype = term),
    colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::scale_linetype_manual(values = c(mean_difference = "solid", lower_95pct_LoA = "dashed", upper_95pct_LoA = "dotdash"),
      breaks = effects$term, labels = c("Mean difference", "Lower 95% LoA", "Upper 95% LoA"),
      guide = os_guide_legend("Computed summaries")) + theme_omicstat(journal = journal, legend = "bottom")
  if (!is.null(acceptability_limits)) {
    bounds <- data.frame(id = c("lower_acceptability", "upper_acceptability"), value = c(acceptability_limits[1], acceptability_limits[2]))
    threshold_layer <- os_semantic_layer("acceptability", bounds, "id", "reference", "prespecified_acceptable_difference", unit,
      independent_unit = "not_applicable", value_columns = "value", provenance = list(source_table = "tables/acceptability.csv", rationale = acceptability_rationale))
    definition$layers <- c(definition$layers, list(threshold_layer))
    p <- p + ggplot2::geom_hline(data = bounds, ggplot2::aes(yintercept = value), linetype = "dotted", colour = OS_FIG$col_up,
      linewidth = os_lw(OS_FIG$lw_ref))
  } else bounds <- NULL
  binding <- os_validate_render_sources(definition, list(pairs = pairs, effects = effects, bounds = bounds))
  p <- os_with_meta(p, definition = definition, caption = caption,
    evidence_refs = os_figure_evidence("bland_altman"), notes = list(render_source_binding = binding, dataset = dataset))
  p
}
