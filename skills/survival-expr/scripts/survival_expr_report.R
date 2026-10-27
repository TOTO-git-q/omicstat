survival_expr_render_legacy <- function(res, out, module) {
 m <- res$metadata; curves <- res$tables$km_curves
 # The shared renderer requires finite CI bounds. Missing endpoint bounds remain in the table;
 # omitting both interval columns avoids implying a made-up endpoint CI.
 if (any(!is.finite(curves$lower) | !is.finite(curves$upper))) curves <- curves[setdiff(names(curves), c("lower", "upper"))]
 p <- os_km(curves, res$tables$km_risk, time_unit = m$time_unit,
  logrank_p = if (is.finite(m$logrank_p)) m$logrank_p else NULL, journal = m$journal,
  analysis_label = if (m$exploratory_cutpoint) "Exploratory optimized split: p withheld" else paste("Prespecified", m$cutoff_rule, "split"))
 meta <- attr(p, "os_meta"); meta$caption <- paste(meta$caption, paste0("Gene: ", m$km_gene, "; cutoff rule: ", m$cutoff_rule, "; cutpoint: ", signif(m$cutpoint, 8), "."), m$logrank_scope)
 meta$notes$cutoff_rule <- m$cutoff_rule; meta$notes$cutpoint <- m$cutpoint; attr(p, "os_meta") <- meta
 os_finalize_figure(p, file.path(out, "figures", "km"), root = out)
 p <- os_hr_forest(res$tables$effect_table, ci_level = m$ci_level, journal = m$journal)
 os_finalize_figure(p, file.path(out, "figures", "cox_hr"), root = out)
}

os_srv_dataset_caption <- function(p, dataset, extra = "") {
 meta <- attr(p, "os_meta")
 meta$caption <- paste0(if (startsWith(meta$caption, paste0("Dataset: ", dataset, "."))) "" else paste0("Dataset: ", dataset, ". "), meta$caption, " ", extra)
 meta$notes$dataset_name <- dataset
 attr(p, "os_meta") <- meta
 p
}
survival_expr_render <- function(res, out, module) {
 m <- res$metadata
 if (is.null(m$survival_extension)) return(survival_expr_render_legacy(res, out, module))
 if (identical(m$survival_extension, "competing-risks")) {
  d <- res$tables$cif_curves
  d <- d[d$code == m$event_of_interest, , drop = FALSE]
  p <- os_cif(d, res$tables$cif_risk, m$time_unit, paste("Event", m$event_of_interest), m$dataset_name, journal = m$journal)
  p <- os_srv_dataset_caption(p, m$dataset_name, paste0("Display gene: ", m$km_gene, "; cutoff: ", m$cutoff_rule, " at ", signif(m$cutpoint, 8), ". Original cohort n=", m$n_biological, "; nominated events=", m$n_events, "; competing events=", m$n_competing, "."))
  os_finalize_figure(p, file.path(out, "figures", "cif"), root = out)
  return(invisible(NULL))
 }
 curves <- res$tables$km_curves
 if (any(!is.finite(curves$lower) | !is.finite(curves$upper))) curves <- curves[setdiff(names(curves), c("lower", "upper"))]
 p <- os_km(curves, res$tables$km_risk, m$time_unit,
   logrank_p = if (is.finite(m$logrank_p)) m$logrank_p else NULL, journal = m$journal,
   analysis_label = if (m$exploratory_cutpoint) "Exploratory optimized split: p withheld" else paste("Prespecified", m$cutoff_rule, "split"))
 p <- os_srv_dataset_caption(p, m$dataset_name, paste0("Gene: ", m$km_gene, "; cutpoint: ", signif(m$cutpoint, 8), ". ", m$logrank_scope, ". Original n=", m$n_biological, "; events=", m$n_events, "."))
 os_finalize_figure(p, file.path(out, "figures", "km"), root = out)
 p <- os_hr_forest(res$tables$effect_table, m$ci_level, journal = m$journal)
 p <- os_srv_dataset_caption(p, m$dataset_name, "Original continuous Cox fits; non-PH diagnostics do not choose or filter genes.")
 os_finalize_figure(p, file.path(out, "figures", "cox_hr"), root = out)
 if (!is.null(res$tables$piecewise_hr)) {
  periods <- res$tables$piecewise_hr
  good <- is.finite(periods$hr) & is.finite(periods$ci_low) & is.finite(periods$ci_high) & periods$ci_low > 0
  if (any(good)) {
   d <- periods[good, , drop = FALSE]; d$term <- paste0(d$gene, " ", d$period); d$estimate <- d$hr
   p <- os_hr_forest(d, m$ci_level, journal = m$journal)
   p <- os_srv_dataset_caption(p, m$dataset_name, paste0("Prespecified piecewise model with source-native Cox defaults. Counting-process intervals (start,stop]; an event at a cut belongs to the earlier period. ", sum(good), " of ", nrow(periods), " periods have finite intervals. Unavailable periods: ", if (all(good)) "none" else paste(periods$period[!good], collapse = ", "), ". Every period and its at-risk/event counts remain in tables/piecewise_hr.csv; no failed estimate is drawn at zero."))
   os_finalize_figure(p, file.path(out, "figures", "piecewise_hr"), root = out)
  }
 }
 invisible(NULL)
}
