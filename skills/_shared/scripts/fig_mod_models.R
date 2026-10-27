# Opt-in experimental model figures. Existing shared tokens and save/lint only.
# No existing shared figure source, token, seal or golden is changed.
# Use one significant-digit precision, increasing it only to distinguish doses.
# Prefer plain numbers; use scientific notation only when a long label shortens.
os_experiment_dose_labels <- function(doses) {
  for (digits in 6:15) {
    labels <- vapply(signif(doses, digits), function(x) format(x, digits = digits, trim = TRUE, scientific = FALSE), character(1))
    if (!anyDuplicated(labels)) break
  }
  scientific <- vapply(signif(doses, digits), function(x) format(x, digits = digits, trim = TRUE, scientific = TRUE), character(1))
  long <- nchar(labels) > 12L & nchar(scientific) < nchar(labels)
  labels[long] <- scientific[long]
  labels
}

# Reserve the y-axis furniture and compare text widths at the house tick size.
# Evenly spaced sorted-dose indices preserve both endpoints on every iteration.
os_experiment_dose_ticks <- function(p, doses, width, journal) {
  labels <- os_experiment_dose_labels(doses)
  panel <- ggplot2::ggplot_build(p + ggplot2::scale_x_log10())$layout$panel_params[[1]]
  text_mm <- function(x) systemfonts::string_width(x, family = os_font_family(), size = OS_FIG$size_axis_text, res = 2540) / 100
  y_reserve <- max(20, max(text_mm(panel$y$get_labels()), na.rm = TRUE) +
    OS_FIG$size_axis_title * 25.4 / 72 + OS_FIG$tick_len_mm + 4.3)
  panel_mm <- max(1, os_width_mm(width, journal) - sum(OS_FIG$plot_margin_mm[c(2, 4)]) - y_reserve)
  positions <- (log10(doses) - panel$x.range[1]) / diff(panel$x.range) * panel_mm
  label_mm <- text_mm(labels)
  k <- min(10L, length(doses))
  repeat {
    keep <- unique(as.integer(round(seq(1, length(doses), length.out = k))))
    overlaps <- any(diff(positions[keep]) < (label_mm[head(keep, -1)] + label_mm[tail(keep, -1)]) / 2 + 1)
    if (!overlaps || k <= 2L) break
    k <- k - 1L
  }
  list(tested_doses = doses, breaks = doses[keep], labels = labels[keep],
    thinned = length(keep) < length(doses), omitted_doses = doses[-keep],
    rule = "At most 10; reduce count until labels have a 1-mm gap; rounded evenly spaced sorted-dose indices, retaining first and last",
    width_mm = os_width_mm(width, journal), estimated_panel_mm = panel_mm,
    endpoint_overlap = overlaps)
}

os_experiment_curve <- function(observations, predictions, dose_unit, ed, journal = NULL, width = "single") {
  positive <- observations$dose > 0
  d <- observations[positive, , drop = FALSE]
  grid <- predictions[predictions$dose > 0, , drop = FALSE]
  n_zero <- sum(!positive)
  tested <- sort(unique(d$dose))
  p <- ggplot2::ggplot(grid, ggplot2::aes(x = dose, y = predicted)) +
    ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_ink) +
    ggplot2::geom_point(data = d, ggplot2::aes(x = dose, y = response),
      shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm, colour = OS_FIG$col_ink) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = paste0("Dose (", dose_unit, "; log scale)"), y = "Response") +
    theme_omicstat(journal = journal, legend = "none")
  ticks <- os_experiment_dose_ticks(p, tested, width, journal)
  ticks$unit <- dose_unit
  p <- p + ggplot2::scale_x_log10(breaks = ticks$breaks, labels = ticks$labels)
  cap <- sprintf(paste0("Observed independent biological units (n = %d) and fitted log-logistic response on a log10 dose axis. ",
    "%d zero-dose units are displayed separately in zero_dose_controls; no zero is placed on the log axis. ",
    "Points are observations, not means. The curve has no confidence band; effective-dose delta intervals are in effective_doses and effect_table.csv. Unsealed development result."), nrow(d), n_zero)
  os_with_meta(p, figure_type = "dose_response", default_height_mm = 65, caption = cap,
    counts = list(n_units = nrow(observations), n_positive = nrow(d), n_zero = n_zero),
    data = list(observations = "tables/observations.csv", predictions = "tables/curve_predictions.csv", effects = "tables/effect_table.csv"),
    notes = list(x_scale = "log10", x_ticks = ticks, zero_dose = "separate figure", interval = "none on fitted curve"))
}

os_experiment_zero_dose <- function(observations, journal = NULL) {
  d <- observations[observations$dose == 0, , drop = FALSE]
  d$control <- "Zero dose"
  p <- ggplot2::ggplot(d, ggplot2::aes(x = control, y = response)) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm, colour = OS_FIG$col_ink) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) + ggplot2::labs(x = "Control", y = "Response") +
    theme_omicstat(journal = journal, legend = "none")
  os_with_meta(p, figure_type = "zero_dose_controls", default_height_mm = 65,
    caption = sprintf("Zero-dose observations, n = %d independent units; coincident points can overlap. Shown separately because zero has no finite logarithm. No error bars or inference added.", nrow(d)),
    counts = list(n_units = nrow(d)), data = list(observations = "tables/observations.csv"))
}

os_experiment_intervals <- function(d, xlab, caption, journal = NULL, include_zero = TRUE) {
  d$label <- if ("stratum" %in% names(d)) ifelse(is.na(d$stratum) | !nzchar(d$stratum), d$term, paste(d$stratum, d$term, sep = ": ")) else d$term
  d$label <- make.unique(d$label)
  d$label <- factor(d$label, levels = rev(d$label))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = estimate, y = label))
  if (include_zero) p <- p + os_vline(0)
  p <- p + ggplot2::geom_segment(ggplot2::aes(x = ci_low, xend = ci_high, yend = label),
      linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_ink) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm, colour = OS_FIG$col_ink) +
    ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::labs(x = xlab, y = NULL) +
    theme_omicstat(journal = journal, legend = "none")
  os_with_meta(p, figure_type = "effect_intervals", default_height_mm = min(125, max(32, 22 + 5 * nrow(d))),
    caption = caption, counts = list(n_terms = nrow(d)), thresholds = if (include_zero) list(null = 0) else list(),
    data = list(effects = "tables/effect_table.csv"), notes = list(ci_level = unique(d$ci_level)))
}

os_experiment_subject_profile <- function(d, xlab, ylab, n_obs, journal = NULL, group_name = NULL) {
  grouped <- !is.null(group_name) && "group" %in% names(d)
  if (!grouped) d$group <- "Subjects"
  pal <- if (grouped) os_group_colours(unique(as.character(d$group))) else c(Subjects = OS_FIG$col_ns)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = response, group = subject)) +
    ggplot2::geom_line(ggplot2::aes(colour = group), linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::geom_point(ggplot2::aes(colour = group), shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) + ggplot2::labs(x = xlab, y = ylab, colour = group_name) +
    ggplot2::scale_colour_manual(values = pal) +
    theme_omicstat(journal = journal, legend = if (grouped) "bottom" else "none")
  if (is.numeric(d$x)) p <- p + ggplot2::scale_x_continuous(labels = os_axis_labels)
  os_with_meta(p, figure_type = "subject_profile", default_height_mm = 65,
    caption = sprintf(paste0("Descriptive subject profiles: %d subjects, %d observations. Points are within-subject means at each %s value; ",
      "lines connect the same subject and are not fitted population effects. Other covariates are not adjusted. No SE/CI or p-values are inferred from these descriptive paths. Fixed-effect Wald intervals are shown separately."),
      length(unique(d$subject)), n_obs, xlab),
    notes = list(grouping_factor = group_name, profile_colour = if (grouped) "fitted grouping factor; house palette" else "neutral"),
    counts = list(n_subjects = length(unique(d$subject)), n_observations = n_obs, n_subject_x_means = nrow(d)),
    data = list(profile = "tables/subject_profile.csv"))
}

# Descriptive intervals use subjects as the units, regardless of replicate counts.
os_experiment_response_summary <- function(d) {
  if (!"group" %in% names(d)) d$group <- "Subjects"
  subjects <- stats::aggregate(response ~ group + x + subject, data = d, FUN = mean)
  keys <- subjects[c("group", "x")]
  out <- stats::aggregate(subjects["response"], keys, mean)
  out$n_subjects <- stats::aggregate(subjects["response"], keys, length)$response
  se <- stats::aggregate(subjects["response"], keys, stats::sd)$response / sqrt(out$n_subjects)
  half <- rep(NA_real_, nrow(out))
  ok <- out$n_subjects > 1L
  half[ok] <- stats::qt(.975, df = out$n_subjects[ok] - 1L) * se[ok]
  names(out)[names(out) == "response"] <- "mean"
  out$ci_low <- out$mean - half
  out$ci_high <- out$mean + half
  out <- out[order(match(out$group, unique(d$group)), out$x), c("group", "x", "n_subjects", "mean", "ci_low", "ci_high")]
  rownames(out) <- NULL
  out
}

os_experiment_response_profile <- function(d, xlab, ylab, journal = NULL, group_name = NULL) {
  grouped <- !is.null(group_name)
  pal <- if (grouped) os_group_colours(unique(as.character(d$group))) else c(Subjects = OS_FIG$col_ns)
  groups <- unique(as.character(d$group))
  d$.profile_group <- factor(d$group, levels = groups)
  spacing <- if (is.numeric(d$x) && length(unique(d$x)) > 1L) min(diff(sort(unique(d$x)))) else 1
  offsets_mm <- (seq_along(groups) - (length(groups) + 1) / 2) * 1.75
  # Only the drawing viewport knows the actual panel width (including axes/legend).
  # Convert the physical displacement to data units there, after scale training.
  make_content <- function(x) {
    panel_mm <- grid::convertWidth(grid::unit(1, "npc"), "mm", valueOnly = TRUE)
    shift <- x$offsets_mm[x$data$group] * diff(x$panel_params$x.range) / panel_mm
    data <- x$data
    for (nm in intersect(c("x", "xmin", "xmax"), names(data))) data[[nm]] <- data[[nm]] + shift
    child <- do.call(x$geom$draw_panel, c(list(data, x$panel_params, x$coord), x$draw_params))
    grid::setChildren(x, grid::gList(child))
  }
  registerS3method("makeContent", "os_response_dodge", make_content, envir = asNamespace("grid"))
  physical_geom <- function(geom) {
    ggplot2::ggproto(NULL, geom,
      draw_panel = function(data, panel_params, coord, ...) {
        grid::gTree(data = data, panel_params = panel_params, coord = coord,
          offsets_mm = offsets_mm, geom = geom, draw_params = list(...), cl = "os_response_dodge")
      })
  }
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = mean, group = .profile_group, colour = group)) +
    ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data), alpha = 1) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = ci_low, ymax = ci_high),
      width = 0.08 * spacing, linewidth = os_lw(OS_FIG$lw_data), alpha = 1, na.rm = TRUE) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = 1.2 * OS_FIG$pt_highlight_mm) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::scale_colour_manual(values = pal) + ggplot2::labs(x = xlab, y = ylab, colour = group_name) +
    theme_omicstat(journal = journal, legend = if (grouped) "bottom" else "none")
  for (i in seq_along(p$layers)) p$layers[[i]]$geom <- physical_geom(p$layers[[i]]$geom)
  if (is.numeric(d$x)) p <- p + ggplot2::scale_x_continuous(labels = os_axis_labels)
  os_with_meta(p, figure_type = "response_profile", default_height_mm = 65,
    caption = paste0("Group response profile: mean of subject means \u00b1 95% CI across subjects; descriptive, not model-adjusted. ",
      "First average observations within subject/group/x, then give each contributing subject equal weight. ",
      "Intervals use Student t with n_subjects - 1 degrees of freedom at each group/x; no interval for n_subjects < 2. ",
      "Lines join observed levels/values; other covariates are not adjusted."),
    counts = list(n_group_x_cells = nrow(d), n_subject_contributions = sum(d$n_subjects)),
    notes = list(grouping_factor = group_name, ci_level = .95, ci_method = "Student t across subject means",
      unit = "subject", singleton_ci = "not estimable; exported as NA", x_scale = if (is.numeric(d$x)) "linear" else "categorical"),
    data = list(profile = "tables/response_profile.csv"))
}

os_experiment_marginal_means <- function(d, factor_name, by_name, ci_level, settings, n_subject, n_obs, journal = NULL, observations = NULL, seed = 20261015L) {
  p <- ggplot2::ggplot(d, ggplot2::aes(x = level, y = estimate))
  if (!is.null(observations)) {
    p <- p + ggplot2::geom_point(data = observations, ggplot2::aes(x = level, y = response),
      position = ggplot2::position_jitter(width = 0.12, height = 0, seed = seed),
      shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm, colour = OS_FIG$col_ns, alpha = 0.45)
  }
  p <- p + ggplot2::geom_linerange(ggplot2::aes(ymin = ci_low, ymax = ci_high),
      linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_ink) +
    ggplot2::geom_point(shape = OS_FIG$shape_dense, size = OS_FIG$pt_highlight_mm, colour = OS_FIG$col_ink) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = factor_name, y = "Estimated marginal mean") +
    theme_omicstat(journal = journal, legend = "none")
  if (!is.null(by_name)) p <- p + ggplot2::facet_wrap(~stratum)
  point_cap <- if (is.null(observations)) "" else paste0("Light jittered points are unadjusted within-subject means for each factor/by cell, exported in marginal_observations.csv; repeated observations are averaged, not treated as independent. Horizontal jitter is seeded; vertical values are unchanged. ")
  cap <- paste0(point_cap, sprintf(paste0("Estimated marginal means and pointwise %g%% confidence intervals on the fitted Gaussian response scale. ",
    "%d subjects and %d observations. Averaging weights: %s; df method: %s. Pairwise contrasts are reported separately with %s adjustment within each by stratum. ",
    "Intervals here describe means, not observations or repeated-unit variability. Unsealed development result."),
    100 * ci_level, n_subject, n_obs, settings$weights, settings$df_method, settings$adjust))
  os_with_meta(p, figure_type = "estimated_marginal_means", default_height_mm = 65, caption = cap,
    counts = list(n_means = nrow(d), n_subjects = n_subject, n_observations = n_obs), data = list(means = "tables/marginal_means.csv", observations = if (!is.null(observations)) "tables/marginal_observations.csv" else NULL),
    notes = list(ci_level = ci_level, weights = settings$weights, df_method = settings$df_method, contrast_adjustment = settings$adjust, jitter_seed = seed, point_unit = "subject/factor/by mean"))
}

# Keep all computed terms visible without exceeding the house maximum height.
# Pagination changes display only; each original row appears exactly once.
os_experiment_interval_pages <- function(d, xlab, caption, include_zero = TRUE) {
  batches <- split(seq_len(nrow(d)), ceiling(seq_len(nrow(d)) / 20L))
  lapply(seq_along(batches), function(i) {
    rows <- batches[[i]]
    p <- os_experiment_intervals(d[rows, , drop = FALSE], xlab,
      paste(caption, sprintf("Display page %d of %d; all %d terms retained across pages.", i, length(batches), nrow(d))),
      include_zero = include_zero)
    os_with_meta(p, data = list(effects = "tables/effect_table.csv", rows = rows),
      notes = list(page = i, n_pages = length(batches), total_terms = nrow(d)))
  })
}

# Experimental residual panels fill the selected canvas; shared diagnostics stay unchanged.
os_experiment_residual <- function(...) {
  p <- os_diag_xy(...)
  p + ggplot2::theme(aspect.ratio = NULL)
}

# Candidate experimental figures: opt-in shared builders; plotted tables exported.
os_model_figures <- function(res, out, module, model = res$object, seed = 20261015L, width = "single", effect_plot = FALSE) {
 dir.create(file.path(out, "figures"), showWarnings = FALSE)
 save <- function(p, nm) os_finalize_figure(p, file.path(out, "figures", nm), width = width, root = out)
 save_intervals <- function(d, xlab, caption, nm = "effect_intervals", include_zero = TRUE) {
  pages <- os_experiment_interval_pages(d, xlab, caption, include_zero)
  for (i in seq_along(pages)) save(pages[[i]], if (i == 1L) nm else paste0(nm, "_", sprintf("%02d", i)))
 }
 if (module == "emmeans-contrast" && isTRUE(res$metadata$emmeans$longitudinal)) {
  settings <- res$metadata$emmeans
  tab <- res$tables$marginal_means
  d <- data.frame(time = factor(as.character(tab[[settings$by]]), levels = settings$time_order),
   group = factor(tab[[settings$factor]], levels = levels(tab[[settings$factor]])),
   estimate = tab$emmean, ci_low = tab$lower.CL, ci_high = tab$upper.CL)
  d <- d[order(d$group,d$time),,drop=FALSE]
  utils::write.csv(d,file.path(out,"tables","longitudinal_emm_draw_data.csv"),row.names=FALSE)
  save(os_experiment_longitudinal_emm(d,settings,res$metadata),"longitudinal_emm")
  effects <- res$tables$effect_table
  batches <- split(seq_len(nrow(effects)),ceiling(seq_len(nrow(effects))/20L))
  for(i in seq_along(batches)) {
   page <- effects[batches[[i]],,drop=FALSE]
   caption <- sprintf("Dataset: %s. Per-time source-direction group differences and pointwise %g%% raw confidence intervals from one unchanged model; %s df and %s weights. %s P correction is over all contrasts and timepoints jointly, not the displayed raw CI. Native adjusted CI and messages are retained separately. Display page %d of %d; all %d terms retained.",settings$dataset_name,100*settings$ci_level,settings$df_method,settings$weights,settings$adjust,i,length(batches),nrow(effects))
   plot <- os_experiment_intervals(page,"Per-time group difference (pointwise CI)",caption)
   semantic <- os_longitudinal_figure_semantics(page,c("stratum","term"),settings,"per-time group mean difference","tables/effect_table.csv")
   plot <- os_with_meta(plot,definition=semantic$definition,
    notes=list(dataset_name=settings$dataset_name,render_source_binding=semantic$binding,page=i,n_pages=length(batches),source_rows=batches[[i]]))
   save(plot,if(i==1L)"longitudinal_differences" else paste0("longitudinal_differences_",sprintf("%02d",i)))
  }
  return(invisible(NULL))
 }
 if (module == "drc-dose") {
  obs <- res$tables$observations
  positive <- obs$dose[obs$dose > 0]
  grid <- data.frame(dose = exp(seq(log(min(positive)), log(max(positive)), length.out = 201L)))
  grid$predicted <- as.numeric(stats::predict(res$object, newdata = grid))
  utils::write.csv(grid, file.path(out, "tables", "curve_predictions.csv"), row.names = FALSE)
  save(os_experiment_curve(obs, grid, res$metadata$dose_unit, res$tables$effect_table, width = width), "dose_response")
  if (any(obs$dose == 0)) save(os_experiment_zero_dose(obs), "zero_dose_controls")
  d <- res$tables$effect_table
  save_intervals(d, paste0("Effective dose (", res$metadata$dose_unit, ")"),
   sprintf("Effective-dose estimates and %g%% delta confidence intervals. Response type: %s; reference: %s; %d independent biological units. These are intervals for effective doses, not a fitted-curve confidence band.",
    100 * d$ci_level[1], res$metadata$response_type, res$metadata$reference, res$metadata$n_units), nm = "effective_doses", include_zero = FALSE)
  residual <- data.frame(fitted = as.numeric(stats::fitted(res$object)), residual = as.numeric(stats::residuals(res$object)))
  utils::write.csv(residual, file.path(out, "tables", "curve_residuals.csv"), row.names = FALSE)
  save(os_experiment_residual(residual, "fitted", "residual", kind = "points", hlines = 0,
   xlab = "Fitted response", ylab = "Residual", caption = "Observed-minus-fitted residuals for the log-logistic model; no diagnostic reference distribution is asserted.",
   figure_type = "dose_response_residuals"), "residuals")
 } else if (module == "lme4-lmm") {
  save(os_experiment_residual(res$tables$residuals, "fitted", "residual", kind = "points", hlines = 0,
   xlab = "Fitted response", ylab = "Residual", caption = "Conditional residuals; observations are repeated within subjects."), "residuals")
  # Preserve the canonical effect table and export native SEs for text/tables.
  fixed <- res$tables$effect_table
  se <- sqrt(diag(as.matrix(stats::vcov(res$object))))
  utils::write.csv(data.frame(term = fixed$term, estimate = fixed$estimate,
   SE = unname(se[fixed$term]), ci_low = fixed$ci_low, ci_high = fixed$ci_high,
   ci_level = fixed$ci_level, df = NA_real_, method = "Wald (normal approximation)"),
   file.path(out, "tables", "fixed_effects.csv"), row.names = FALSE, na = "")
  mf <- stats::model.frame(res$object)
  predictors <- setdiff(all.vars(lme4::nobars(stats::formula(res$object))), res$metadata$response)
  predictors <- setdiff(predictors, res$metadata$subject)
  if (length(predictors)) {
   xname <- predictors[1]
   d <- data.frame(x = mf[[xname]], subject = mf[[res$metadata$subject]], response = mf[[res$metadata$response]])
   group_names <- setdiff(predictors[vapply(mf[predictors], is.factor, logical(1))], xname)
   group_name <- if (length(group_names)) group_names[1] else NULL
   if (!is.null(group_name)) d$group <- mf[[group_name]]
   d <- if (is.null(group_name)) stats::aggregate(response ~ x + subject, data = d, FUN = mean) else
    stats::aggregate(response ~ x + subject + group, data = d, FUN = mean)
   d <- d[order(d$subject, d$x), , drop = FALSE]
   utils::write.csv(d, file.path(out, "tables", "subject_profile.csv"), row.names = FALSE)
   save(os_experiment_subject_profile(d, xname, res$metadata$response, res$metadata$n_obs, group_name = group_name), "subject_profile")
   response <- os_experiment_response_summary(d)
   utils::write.csv(response, file.path(out, "tables", "response_profile.csv"), row.names = FALSE, na = "")
   save(os_experiment_response_profile(response, xname, res$metadata$response, group_name = group_name), "response_profile")
  }
 }
 if (module == "emmeans-contrast" || (module == "lme4-lmm" && isTRUE(effect_plot))) {
  d <- res$tables$effect_table
  caption <- if (module == "lme4-lmm") sprintf("Fixed effects and %g%% Wald confidence intervals; %d subjects and %d observations. Dashed line marks zero; no coefficient p-values were calculated.",
    100 * d$ci_level[1], res$metadata$n_subject, res$metadata$n_obs) else sprintf("Pairwise differences and %g%% confidence intervals; %s adjustment within each by stratum; df method %s; weights %s. Dashed line marks zero. No significance brackets or unadjusted-p annotations added.",
    100 * d$ci_level[1], res$metadata$emmeans$adjust, res$metadata$emmeans$df_method, res$metadata$emmeans$weights)
  save_intervals(d, if (module == "lme4-lmm") "Fixed effect (Wald CI)" else "Pairwise difference (CI)", caption)
 }
 if (module == "emmeans-contrast") {
  tab <- res$tables$marginal_means
  lo <- if ("lower.CL" %in% names(tab)) "lower.CL" else "asymp.LCL"
  hi <- if ("upper.CL" %in% names(tab)) "upper.CL" else "asymp.UCL"
  settings <- res$metadata$emmeans
  d <- data.frame(level = tab[[settings$factor]], estimate = tab$emmean, ci_low = tab[[lo]], ci_high = tab[[hi]])
  if (!is.null(settings$by)) d$stratum <- tab[[settings$by]]
  mf <- stats::model.frame(model)
  raw <- data.frame(subject = mf[[res$metadata$subject]], level = mf[[settings$factor]], response = mf[[res$metadata$response]])
  if (!is.null(settings$by)) raw$stratum <- mf[[settings$by]]
  keys <- c("subject", "level", if (!is.null(settings$by)) "stratum")
  points <- stats::aggregate(raw["response"], raw[keys], mean)
  points$n_observations <- stats::aggregate(raw["response"], raw[keys], length)$response
  utils::write.csv(points, file.path(out, "tables", "marginal_observations.csv"), row.names = FALSE)
  save(os_experiment_marginal_means(d, settings$factor, settings$by, settings$ci_level, settings, n_subject = res$metadata$n_subject, n_obs = res$metadata$n_obs, observations = points, seed = seed), "marginal_means")
 }
}

# Pure display of the exported model EMMs; no raw means, refit or CI construction.
os_experiment_longitudinal_emm <- function(d,settings,metadata,journal=NULL) {
 semantic <- os_longitudinal_figure_semantics(d,c("time","group"),settings,"estimated marginal mean","tables/longitudinal_emm_draw_data.csv")
 pal <- os_group_colours(levels(d$group))
 p <- ggplot2::ggplot(d,ggplot2::aes(x=time,y=estimate,group=group,colour=group)) +
  ggplot2::geom_line(linewidth=os_lw(OS_FIG$lw_data)) +
  ggplot2::geom_linerange(ggplot2::aes(ymin=ci_low,ymax=ci_high),linewidth=os_lw(OS_FIG$lw_data)) +
  ggplot2::geom_point(shape=OS_FIG$shape_dense,size=OS_FIG$pt_highlight_mm) +
  ggplot2::scale_colour_manual(values=pal) + ggplot2::scale_y_continuous(labels=os_axis_labels) +
  ggplot2::labs(x=settings$by,y="Estimated marginal mean",colour=settings$factor) +
  theme_omicstat(journal=journal,legend="bottom")
 os_with_meta(p,definition=semantic$definition,figure_type="longitudinal_emm",default_height_mm=70,
  caption=sprintf("Dataset: %s. Estimated marginal means and pointwise %g%% confidence intervals from one unchanged Gaussian mixed model; %d biological units and %d observations. Weights %s; %s df. Lines connect the prespecified categorical time order and are not a continuous-time fit. These are model EMMs, not raw observed means. Contrasts and joint interaction tests are reported separately.",
   settings$dataset_name,100*settings$ci_level,metadata$n_subject,metadata$n_obs,settings$weights,settings$df_method),
  counts=list(n_subjects=metadata$n_subject,n_observations=metadata$n_obs,n_means=nrow(d)),
  data=list(means="tables/marginal_means.csv",draw_data="tables/longitudinal_emm_draw_data.csv"),
  notes=list(dataset_name=settings$dataset_name,model_sha256=settings$model_sha256,df_method=settings$df_method,ci_level=settings$ci_level,
   render_source_binding=semantic$binding,
   interval="pointwise model EMM CI; not observation or simultaneous contrast intervals",time_order=settings$time_order,
   computation="display only; no refit, interpolation, raw averaging or error-bar calculation"))
}

# Typed P0-12 source identity and interval semantics; no model recomputation.
os_longitudinal_figure_semantics <- function(d,keys,settings,quantity,source_table) {
 .os_sem_string(settings$dataset_name,"dataset label")
 if(!is.character(settings$model_sha256) || length(settings$model_sha256)!=1L ||
    !grepl("^[0-9a-f]{64}$",settings$model_sha256) ||
    !settings$df_method %in% c("kenward-roger","satterthwaite"))
  stop("OS_INVALID_INPUT: exact fitted model identity and finite df method required for longitudinal figures",call.=FALSE)
 ids <- .os_sem_rows(d,keys)
 if(!all(c("estimate","ci_low","ci_high") %in% names(d)))
  stop("OS_INVALID_INPUT: native estimates and pointwise interval endpoints required",call.=FALSE)
 intervals <- data.frame(source_id=ids,estimate=d$estimate,lower=d$ci_low,upper=d$ci_high)
 uncertainty <- os_uncertainty(quantity,"CI",paste("native emmeans",settings$df_method),
  "pointwise","not_applicable","available",rows=intervals,level=settings$ci_level,
  conditioned_on="prespecified Gaussian mixed model and averaging weights; no refit or resampling")
 layer <- os_semantic_layer("longitudinal_model_values",d,keys,"model_grid",quantity,"original Gaussian response scale",
  independent_unit="biological unit",uncertainty=uncertainty,value_columns="estimate",
  provenance=list(source_table=source_table,dataset=settings$dataset_name,model_sha256=settings$model_sha256,
   df_method=settings$df_method,weights=settings$weights,refit_performed=FALSE))
 population <- list(status="unknown",rule="Model reference-grid rows are not independent biological units; model n is reported separately without invented row-to-unit identities")
 definition <- os_figure_definition(quantity,"precomputed_model_grid","biological unit","original Gaussian response scale",
  population,population,"Native model estimates and pointwise intervals; display only",list(layer),
  notes=list(dataset=settings$dataset_name,model_sha256=settings$model_sha256,not_simultaneous=TRUE))
 list(definition=definition,binding=os_validate_render_sources(definition,list(model_values=d)))
}
