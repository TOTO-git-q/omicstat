# Opt-in dose-family figures; existing house tokens and tested-dose labels.
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
os_scope_curve <- function(obs, grid, unit, caption, figure_type, samples = NULL, limits = NULL, width = "single", journal = NULL) {
 p <- ggplot2::ggplot(grid, ggplot2::aes(x = dose, y = predicted))
 if (!is.null(limits)) p <- p + ggplot2::geom_vline(xintercept = limits, colour = OS_FIG$col_ref,
  linetype = OS_FIG$ref_linetype, linewidth = os_lw(OS_FIG$lw_ref))
 p <- p + ggplot2::geom_line(colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
  ggplot2::geom_point(data = obs, ggplot2::aes(x = dose, y = response),
   colour = OS_FIG$col_reference_group, shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm)
 if (!is.null(samples) && nrow(samples)) p <- p + ggplot2::geom_point(data = samples,
  ggplot2::aes(x = well_concentration, y = response), inherit.aes = FALSE,
  colour = OS_PAL_GROUP[1], shape = OS_FIG$shape_sample_sequence[2], size = OS_FIG$pt_sample_mm)
 p <- p + ggplot2::scale_y_continuous(labels = os_axis_labels) +
  ggplot2::labs(x = paste0("Concentration (", unit, "; log scale)"), y = "Assay response") + theme_omicstat(journal = journal, legend = "none")
 ticks <- os_experiment_dose_ticks(p, sort(unique(obs$dose)), width, journal)
 p <- p + ggplot2::scale_x_log10(breaks = ticks$breaks, labels = ticks$labels)
 os_with_meta(p, evidence_refs = os_figure_evidence("dose_scope"), figure_type = figure_type, default_height_mm = 65, caption = caption,
  counts = list(n_technical_wells = nrow(obs), n_back_calculated_samples = if (is.null(samples)) 0L else nrow(samples)),
  thresholds = list(lloq_uloq = limits), notes = list(x_scale = "log10", x_ticks = ticks, interval = "no invented curve band"),
  data = list(observations = "tables/observations.csv", predictions = "tables/curve_predictions.csv", results = "tables/results.csv"))
}

os_scope_subjects <- function(obs, grid, unit, caption, width = "single", titer = FALSE) {
 p <- ggplot2::ggplot(grid, ggplot2::aes(x = dose, y = predicted, group = subject)) +
  ggplot2::geom_line(colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
  ggplot2::geom_point(data = obs, ggplot2::aes(x = dose, y = response, group = subject),
   colour = OS_FIG$col_reference_group, shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm) +
  ggplot2::facet_wrap(~subject, ncol = 2) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
  ggplot2::labs(x = if (titer) "Reciprocal dilution (log scale)" else paste0("Dose (", unit, "; log scale)"), y = "Response") +
  theme_omicstat(legend = "none") + ggplot2::theme(aspect.ratio = NULL)
 ticks <- os_experiment_dose_ticks(p, sort(unique(obs$dose)), width, NULL)
 # Facet panels have half the full width; retain a sparse deterministic subset.
 keep <- unique(as.integer(round(seq(1, length(ticks$breaks), length.out = min(4L, length(ticks$breaks))))))
 ticks$breaks <- ticks$breaks[keep]; ticks$labels <- ticks$labels[keep]
 ticks$omitted_doses <- setdiff(ticks$tested_doses, ticks$breaks)
 ticks$thinned <- length(ticks$breaks) < length(ticks$tested_doses)
 ticks$rule <- "Facets: at most four tested values; rounded evenly spaced indices, endpoints retained"
 p <- p + ggplot2::scale_x_log10(breaks = ticks$breaks, labels = ticks$labels)
 os_with_meta(p, evidence_refs = os_figure_evidence("dose_scope"), figure_type = if (titer) "titer_curves" else "repeated_subject_curves",
  default_height_mm = 30 + 35 * ceiling(length(unique(obs$subject)) / 2), caption = caption,
  counts = list(n_subjects = length(unique(obs$subject)), n_observations = nrow(obs)),
  notes = list(x_scale = "log10", x_ticks = ticks, interval = "none on subject curves"),
  data = list(observations = "tables/observations.csv", predictions = if (titer) "tables/curve_predictions.csv" else "tables/subject_predictions.csv"))
}

os_scope_population <- function(obs, typical, subjects, meta, width = "single") {
 p <- ggplot2::ggplot(subjects, ggplot2::aes(x = dose, y = predicted, group = subject)) +
  ggplot2::geom_line(colour = OS_FIG$col_ns, linewidth = os_lw(OS_FIG$lw_segment)) +
  ggplot2::geom_point(data = obs, ggplot2::aes(x = dose, y = response, group = subject),
   colour = OS_FIG$col_reference_group, shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm) +
  ggplot2::geom_line(data = typical, ggplot2::aes(x = dose, y = predicted, group = 1),
   colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
  ggplot2::scale_y_continuous(labels = os_axis_labels) +
  ggplot2::labs(x = paste0("Dose (", meta$dose_unit, "; log scale)"), y = "Response") + theme_omicstat(legend = "none")
 ticks <- os_experiment_dose_ticks(p, sort(unique(obs$dose)), width, NULL)
 p <- p + ggplot2::scale_x_log10(breaks = ticks$breaks, labels = ticks$labels)
 os_with_meta(p, evidence_refs = os_figure_evidence("dose_scope"), figure_type = "nonlinear_mixed_dose", default_height_mm = 65,
  caption = sprintf("%d biological subjects; %d repeated observations. Grey thin lines: conditional subject fits. Black line: fixed-effects (zero random effect) curve, not a marginal mean curve for location random effects. Points: observed biological subject/dose responses. Lower limit fixed at zero. ED50 intervals shown separately; no invented curve band.", meta$n_subjects, meta$n_observations),
  counts = list(n_subjects = meta$n_subjects, n_observations = meta$n_observations),
  notes = list(x_scale = "log10", x_ticks = ticks, interval = "no fitted-curve band"),
  data = list(observations = "tables/observations.csv", typical = "tables/curve_predictions.csv", subject_predictions = "tables/subject_predictions.csv"))
}

os_scope_response <- function(d, meta, width = "single") {
 p <- ggplot2::ggplot(d, ggplot2::aes(x = dose, y = mean)) +
  ggplot2::geom_errorbar(data = d[is.finite(d$sem) & d$n_subjects >= 2, , drop = FALSE], ggplot2::aes(ymin = mean - sem, ymax = mean + sem),
   width = 0, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
  ggplot2::geom_line(colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_data)) +
  ggplot2::geom_point(colour = OS_FIG$col_ink, size = OS_FIG$pt_highlight_mm, shape = OS_FIG$shape_dense) +
  ggplot2::labs(x = paste0("Dose (", meta$dose_unit, "; log scale)"), y = "Mean response (SEM)") + theme_omicstat(legend = "none")
 ticks <- os_experiment_dose_ticks(p, d$dose, width, NULL)
 p <- p + ggplot2::scale_x_log10(breaks = ticks$breaks, labels = ticks$labels)
 os_with_meta(p, evidence_refs = os_figure_evidence("dose_scope"), figure_type = "repeated_dose_descriptive", default_height_mm = 65,
  caption = sprintf("Descriptive means +/- SEM across biological subjects at each tested dose; %d subjects overall. Each subject contributes at most once per dose. Connected means are descriptive, not fitted model predictions or confidence intervals. With unequal grids subject composition can change by dose; per-dose n is exported. SEM is undefined and omitted when fewer than two subjects contribute; the mean point remains. Population ED50 inference remains in effect_table.csv.", meta$n_subjects),
  counts = list(n_subjects = meta$n_subjects, n_per_dose = d$n_subjects),
  notes = list(x_scale = "log10", x_ticks = ticks, error_type = "SEM; biological subjects"),
  data = list(summary = "tables/response_summary.csv"))
}

os_scope_figures <- function(res, out, module, width = "single") {
 save <- function(p, name) os_finalize_figure(p, file.path(out, "figures", name), width = width, root = out)
 m <- res$metadata; obs <- res$tables$observations; grid <- res$tables$curve_predictions
 if (module == "drc-calibrate" && m$mode == "calibration") {
  sample <- res$tables$results; sample <- sample[!sample$withheld, ]
  cap <- sprintf("Standards: %d technical wells, unweighted drc %s fit (black); triangles: %d in-range back-calculated unknown sample means, after dilution tracked separately. Blank policy %s; offset %g. Dashed lines: supplied LLOQ %g and ULOQ %g in well units. Out-of-range estimates withheld. No wells count as biological replicates. No curve band. Sample delta intervals are in results.csv, conditional on blank correction.",
   nrow(obs), m$model, nrow(sample), m$blank_policy, m$blank_offset, m$lloq, m$uloq)
  save(os_scope_curve(obs, grid, m$dose_unit, cap, "immunoassay_calibration", sample, c(m$lloq, m$uloq), width), "standard_curve")
 } else if (module == "drc-calibrate") {
  obs$subject <- obs$curve; grid$subject <- grid$curve
  ids <- unique(obs$subject)
  for (i in seq(1L, length(ids), by = 6L)) {
   use <- ids[i:min(i + 5L, length(ids))]
   save(os_scope_subjects(obs[obs$subject %in% use, ], grid[grid$subject %in% use, ], m$dose_unit,
    sprintf("Serial-dilution assay fits per sample, %s %s titer with pointwise delta intervals exported separately. Points are technical wells, not biological replicates; dilution denotes reciprocal dilution. Blank policy: %s. No fitted-curve bands.", m$model, m$titer_definition, m$blank_policy), width, TRUE), paste0("titer_curves_", sprintf("%02d", i)))
  }
 } else {
  save(os_scope_population(obs, grid, res$tables$subject_predictions, m, width), "population_curve")
  save(os_scope_response(res$tables$response_summary, m, width), "response_summary")
  ids <- unique(as.character(obs$subject))
  for (i in seq(1L, length(ids), by = 6L)) {
   use <- ids[i:min(i + 5L, length(ids))]; sg <- res$tables$subject_predictions
   save(os_scope_subjects(obs[obs$subject %in% use, ], sg[sg$subject %in% use, ], m$dose_unit,
    "Conditional nonlinear mixed-effects fits and measured responses, faceted by biological subject. Each panel follows the same subject over doses; technical replicates are curated upstream. No independent-dose inference or subject confidence bands.", width), paste0("subject_curves_", sprintf("%02d", i)))
  }
  save(os_experiment_residual(res$tables$residuals, "fitted", "residual", kind = "points", hlines = 0,
   xlab = "Conditional fitted response", ylab = "Residual", caption = "Conditional residuals from repeated biological subjects; residual independence remains a model assumption."), "residuals")
 }
 d <- res$tables$effect_table; d <- d[is.finite(d$estimate), ]
 if (nrow(d)) {
  cap <- if (module == "nlme-dose") paste(m$interval, "; biological n is subjects, not observations.") else
   "Pointwise assay delta intervals, not biological group inference; conditional on fixed blank correction. Concentrations are multiplied by declared dilution factors; titers are reciprocal dilutions. Withheld out-of-range results remain in the CSV."
  pages <- os_experiment_interval_pages(d, if (module == "nlme-dose") paste0("Population ED50 (", m$dose_unit, ")") else if (m$mode == "calibration") paste0("Original concentration (", m$dose_unit, ")") else "Reciprocal dilution titer", cap, include_zero = FALSE)
  for (i in seq_along(pages)) save(pages[[i]], paste0("estimates_", sprintf("%02d", i)))
 }
}

# Explicit quantitative range is not a confidence band. Refuse zero/negative
# standards rather than silently flooring them onto a logarithmic axis.
os_standard_curve <- function(obs, grid, unit, model, lloq, uloq, journal = NULL,
                               width = "single", evidence_refs = os_figure_evidence("assay_calibration")) {
  os_plot_columns(obs, c("dose", "response"), c("dose", "response"))
  os_plot_columns(grid, c("dose", "predicted"), c("dose", "predicted"))
  if (!model %in% c("4PL", "5PL") || !nzchar(unit) || any(obs$dose <= 0) || any(grid$dose <= 0) ||
      length(lloq) != 1 || length(uloq) != 1 || !is.finite(lloq) || !is.finite(uloq) || lloq <= 0 || uloq <= lloq)
    stop("OS_INVALID_INPUT: positive standards, 4PL/5PL and ordered positive quantification limits required", call. = FALSE)
  grid <- grid[order(grid$dose), , drop = FALSE]
  p <- os_scope_curve(obs, grid, unit,
    sprintf("%s standard curve; %d technical wells. Shaded range marks declared LLOQ to ULOQ, not confidence or prediction uncertainty. No biological replicate inference. Blank correction and fit performed upstream.", model, nrow(obs)),
    "assay_standard_curve", limits = c(lloq, uloq), width = width, journal = journal)
  band <- ggplot2::annotate("rect", xmin = lloq, xmax = uloq, ymin = -Inf, ymax = Inf,
                           fill = OS_FIG$col_ns, alpha = OS_FIG_MODEL$range_alpha)
  p$layers <- c(list(band), p$layers)
  p <- p + theme_omicstat(journal = journal, legend = "none")
  os_with_meta(p, evidence_refs = evidence_refs, notes = list(model = model, range_band = "quantification range, not uncertainty"))
}
