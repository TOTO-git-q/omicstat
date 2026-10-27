glmnet_coxsig_render_legacy <- function(res, out, module) {
 m <- res$metadata
 p <- os_time_roc(res$tables$time_roc, time_unit = m$time_unit, journal = m$journal)
 p <- p + ggplot2::labs(subtitle = if (m$mode == "train") "Apparent training ROC" else "External cohort, frozen signature")
 p <- os_with_meta(p, caption = paste(attr(p,"os_meta")$caption, m$performance_scope))
 os_finalize_figure(p, file.path(out,"figures","time_roc"), root = out)
 if (m$mode == "train") os_finalize_figure(os_lasso_path(res$tables$coefficient_path, selected_lambda = m$lambda, journal = m$journal, selection_rule = res$object$selection), file.path(out,"figures","lasso_path"), root = out)
 if (m$km_available) {
  curves <- res$tables$km_curves
  if (any(!is.finite(curves$lower) | !is.finite(curves$upper))) curves <- curves[setdiff(names(curves),c("lower","upper"))]
  p <- os_km(curves,res$tables$km_risk,time_unit=m$time_unit,journal=m$journal,analysis_label=if(m$mode=="train") "Training risk groups, descriptive" else "Frozen training cutoff, external cohort")
  p <- os_with_meta(p,caption=paste(attr(p,"os_meta")$caption,m$performance_scope,paste("Training risk cutoff:",signif(m$cutpoint,8))))
  os_finalize_figure(p,file.path(out,"figures","risk_km"),root=out)
 }
}

os_cxs_dataset_caption <- function(p, m, extra = "") {
 meta <- attr(p, "os_meta")
 meta$caption <- paste0("Dataset: ", m$dataset_name, ". Original biological subjects n=", m$n_biological,
  "; observed events=", m$n_events, ". ", meta$caption, " ", extra)
 meta$notes$dataset_name <- m$dataset_name
 attr(p, "os_meta") <- meta
 p
}
glmnet_coxsig_render <- function(res, out, module) {
 m <- res$metadata
 if (is.null(m$prediction_workup)) return(glmnet_coxsig_render_legacy(res, out, module))
 save <- function(p, name, extra = "") os_finalize_figure(os_cxs_dataset_caption(p, m, extra), file.path(out, "figures", name), root = out)
 p <- os_time_roc(res$tables$time_roc, time_unit = m$time_unit, journal = m$journal)
 p <- p + ggplot2::labs(subtitle = if (m$mode == "train") "Apparent training ROC" else "External cohort, frozen signature")
 save(p, "time_roc", m$performance_scope)
 if (m$mode == "train") save(os_lasso_path(res$tables$coefficient_path, selected_lambda = m$lambda, journal = m$journal, selection_rule = res$object$selection), "lasso_path", "Original penalized coefficients; no source unpenalized refit is substituted.")
 if (m$km_available) {
  curves <- res$tables$km_curves
  if (any(!is.finite(curves$lower) | !is.finite(curves$upper))) curves <- curves[setdiff(names(curves),c("lower","upper"))]
  p <- os_km(curves, res$tables$km_risk, time_unit = m$time_unit, journal = m$journal,
   analysis_label = if (m$mode == "train") "Training risk groups, descriptive" else "Frozen training cutoff, external cohort")
  save(p, "risk_km", paste(m$performance_scope, "Training risk cutoff:", signif(m$cutpoint, 8)))
 }
 d <- res$tables$calibration_binned; w <- m$cpm_workup; perf <- res$tables$calibration_performance
 if (nrow(d)) {
  d$lower <- d$ci_low; d$upper <- d$ci_high
  p <- os_calibration(d, w$horizon, m$time_unit, journal = m$journal)
  slope <- paste0("Calibration slope ", signif(perf$calibration_slope, 4), " (", 100 * m$ci_level,
    "% marginal Wald CI ", signif(perf$slope_ci_low, 4), " to ", signif(perf$slope_ci_high, 4), "); observed/expected risk ratio ", signif(perf$observed_expected_ratio, 4), ".")
  extra <- paste(w$calibration_scope, ".", slope, "Points are mean frozen predicted risk versus within-bin Kaplan-Meier risk; bars are source log-log KM intervals, not prediction intervals.",
    "Bins contain at least", w$min_bin, "original subjects;", w$n_bin_subjects_displayed, "subjects displayed and", w$n_bin_subjects_omitted,
    "omitted from this panel. Every bin and omitted reason is in calibration_bin_accounting.csv. Censoring is not recoded; unsupported horizons are not extended.",
    "Diagnostic slope estimation does not update prediction coefficients or the frozen training baseline.")
  p <- os_with_meta(p, counts = list(n_original = m$n_biological, n_events = m$n_events,
    n_bins = nrow(d), n_displayed_subjects = w$n_bin_subjects_displayed, n_omitted_subjects = w$n_bin_subjects_omitted),
    notes = list(calibration_scope = w$calibration_scope, calibration_slope = perf$calibration_slope,
     interval = "within-bin KM log-log interval", frozen_workup_sha256 = w$workup_sha256),
    data = list(calibration = "tables/calibration_binned.csv", accounting = "tables/calibration_bin_accounting.csv", performance = "tables/calibration_performance.csv"))
  save(p, "calibration", extra)
 }
 invisible(NULL)
}
