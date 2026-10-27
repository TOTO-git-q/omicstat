omicstat_samplesize_render <- function(res, out, module) {
  d <- res$tables$scenarios; m <- res$metadata
  event_only <- m$design == "survival_logrank" && all(is.na(d$n_biological_total))
  y <- if (event_only) "required_events" else "n_biological_recruit_total"
  quantity <- if (event_only) "required_event_count" else "planned_biological_recruitment_count"
  unit <- if (event_only) "events" else m$biological_unit
  d$scenario_id <- paste0("power_", format(d$target_power, digits = 17, trim = TRUE))
  layer <- os_semantic_layer("planning_grid", d, "scenario_id", "model_grid", quantity, unit,
    independent_unit = "not_applicable", value_columns = y,
    uncertainty = os_uncertainty(quantity, "none", "deterministic planning under declared assumptions",
      "not_applicable", "not_applicable", "not_applicable", reason = "No estimated effect or sampling interval is computed."),
    provenance = list(engine = m$native_engine, source_table = "tables/scenarios.csv",
      dataset = "none: explicitly declared a priori design assumptions", planning_only = TRUE))
  population <- list(status = "not_applicable", rule = "Planning grid; no observed biological samples exist in this run.")
  definition <- os_figure_definition(quantity, "planning_scenario", "not_applicable", unit,
    population, population, "none", list(layer), notes = list(
      no_observed_sample_count = TRUE, technical_repeats_excluded = TRUE,
      paired_units_counted_once = m$design == "mean_paired"))
  caption <- paste0("A priori planning; ", m$native_engine, ". Alpha=", m$alpha,
    "; power is a design input. Points are computed scenarios, not observations; connectors only guide the eye. ",
    "No CI or error bars are estimated. Technical repeats do not count as biological n. ",
    if (event_only) "Event probability unspecified: required events are not a biological sample count." else
      paste0("Recruitment counts include the explicitly declared attrition fraction ", m$dropout, "."))
  p <- os_diag_xy(d, "target_power", y, kind = "line+points", xlab = "Target power (planning input)",
    ylab = if (event_only) "Required events (biological N unknown)" else paste0("Planned biological units to recruit (", unit, ")"),
    highlight = d$selected_plan, caption = caption, figure_type = "sample_size_power_curve",
    journal = m$journal, definition = definition)
  os_finalize_figure(p, file.path(out, "figures", "sample_size_power_curve"), root = out)
}
