# P0-13 B1: independent numerical source adaptation, not an automatic test selector.
.os_gpc_port <- local({
  files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
  here <- dirname(normalizePath(tail(files[nzchar(files)], 1), mustWork = TRUE))
  distribution <- new.env(parent = baseenv())
  typing <- new.env(parent = baseenv())
  sys.source(file.path(here, "gpc_ported_descdist_core.R"), envir = distribution)
  sys.source(file.path(here, "gpc_ported_var_typing.R"), envir = typing)
  sys.source(file.path(here, "gpc_ported_baseline_classify.R"), envir = typing)
  list(distribution = distribution, typing = typing)
})

os_gpc_mode <- function(a) {
  mode <- a[["analysis-mode"]] %||% "hypothesis-tests"
  if (length(mode) != 1L || !mode %in% c("hypothesis-tests", "distribution-effects"))
    stop("OS_INVALID_PARAMETER: unsupported group-comparison analysis mode", call. = FALSE)
  mode
}

os_gpc_distribution_spec <- function(a) {
  need <- c("reference-group", "quantile-grid", "min-cell-n", "outcome-unit", "inference", "dataset-name")
  for (key in need) if (is.null(a[[key]]) || !length(a[[key]]))
    stop(paste0("OS_MISSING_PARAMETER: distribution-effects requires --", key), call. = FALSE)
  if (a$design != "independent" || a[["pairwise-test"]] != "none" || a$omnibus != "none" ||
      a[["rank-method"]] != "not-applicable" || a$adjust != "none" || a[["family-size"]] != 1L || !is.null(a$comparisons))
    stop("OS_CONFLICTING_PARAMETERS: distribution-effects is an independent descriptive branch; no hypothesis tests or P-value family", call. = FALSE)
  if ((a[["distribution-diagnostics"]] %||% "off") != "off" || a$display != "interval")
    stop("OS_CONFLICTING_PARAMETERS: distribution-effects requires aggregate interval display and diagnostics off", call. = FALSE)
  if (!identical(as.numeric(a[["ci-level"]]), .95))
    stop("OS_INVALID_PARAMETER: the copied distribution core supports only pointwise 95% intervals", call. = FALSE)
  method <- a$inference
  if (!method %in% c("none", "iid_stratified_bootstrap"))
    stop("OS_INVALID_PARAMETER: unsupported distribution inference", call. = FALSE)
  if (method == "iid_stratified_bootstrap") {
    for (key in c("bootstrap-replicates", "min-success-fraction")) if (is.null(a[[key]]))
      stop(paste0("OS_MISSING_PARAMETER: bootstrap requires --", key), call. = FALSE)
  } else if (!is.null(a[["bootstrap-replicates"]]) || !is.null(a[["min-success-fraction"]]))
    stop("OS_CONFLICTING_PARAMETERS: bootstrap controls require iid_stratified_bootstrap", call. = FALSE)
  for (key in c("outcome-unit", "dataset-name")) if (!is.character(a[[key]]) || length(a[[key]]) != 1L || is.na(a[[key]]) || !nzchar(trimws(a[[key]])))
    stop("OS_INVALID_PARAMETER: outcome unit and dataset name must be explicit nonempty labels", call. = FALSE)
  grid <- suppressWarnings(as.numeric(strsplit(a[["quantile-grid"]], ",", fixed = TRUE)[[1L]]))
  inf <- list(method = method, seed = a$seed, confidence_level = a[["ci-level"]])
  if (method != "none") {
    inf$replicates <- a[["bootstrap-replicates"]]
    inf$min_success_fraction <- a[["min-success-fraction"]]
  }
  list(spec_version = "descdist.v1", analysis = "distribution_comparison", id = "unit", outcome = "value", group = "group",
    group_levels = strsplit(a[["group-order"]], ",", fixed = TRUE)[[1L]], reference_group = a[["reference-group"]],
    quantile_grid = grid, min_cell_n = a[["min-cell-n"]], unit = a[["outcome-unit"]], inference = inf, make_figures = FALSE)
}

os_gpc_distribution_compute <- function(a) {
  spec <- os_gpc_distribution_spec(a)
  # Keep the source validators before computation, then apply stronger OmicStat
  # complete-input / biological-unit guards. No source complete-case deletion.
  .os_gpc_port$distribution$dd_validate_spec(spec)
  roles <- c(a[["response-col"]], a[["group-col"]], a[["unit-col"]], a[["technical-col"]])
  if (anyDuplicated(roles)) stop("OS_INVALID_DESIGN: biological input column roles must be distinct", call. = FALSE)
  raw <- .os_read_delim(a$input)
  os_check_columns(raw, c(a[["response-col"]], a[["group-col"]], a[["unit-col"]]))
  # Preserve the copied core's prohibition on logical/censored/nonfinite
  # outcomes before the pre-existing biological-unit helper coerces numerics.
  .os_gpc_port$distribution$dd_num_column(raw[[a[["response-col"]]]], "outcome")
  d <- os_basic_units(raw, a[["response-col"]], a[["group-col"]], a[["unit-col"]], a[["technical-policy"]], a[["technical-col"]])
  if (anyDuplicated(d$unit)) stop("OS_INVALID_DESIGN: independent distribution groups need disjoint biological units", call. = FALSE)
  # Do not use os_basic_design's >=2 inference gate: declared empty/small source
  # groups must remain withheld rows, not silently disappear from the estimand.
  result <- .os_gpc_port$distribution$dd_analyze(d[c("unit", "group", "value")], spec)
  metrics <- result$metrics
  metrics$metric_id <- paste0("metric_", seq_len(nrow(metrics)))
  metrics$direction <- ifelse(nzchar(metrics$reference_group), "group_minus_reference", "group_description")
  metrics$ci_adjustment <- "none_pointwise"
  metrics$display_label <- paste0(metrics$group, ifelse(nzchar(metrics$reference_group), paste0(" minus ", metrics$reference_group), ""),
    ifelse(is.finite(metrics$grid), paste0("; quantile ", format(metrics$grid, digits = 17, trim = TRUE)), ""))
  effects <- metrics[metrics$statistic %in% c("mean_difference", "smd", "quantile_difference"), , drop = FALSE]
  effects$term <- effects$metric_id
  effects$ci_low <- effects$ci_lower; effects$ci_high <- effects$ci_upper; effects$ci_level <- .95
  findings <- result$guardrails$findings
  guard <- if (length(findings)) do.call(rbind, lapply(findings, function(z) data.frame(
    code = z$code, severity = z$severity, blocking = z$blocking, message = z$message,
    group = z$group, reference_group = z$reference_group,
    statistics = paste(unlist(z$statistics), collapse = ";"), grid = paste(unlist(z$grid), collapse = ";"), stringsAsFactors = FALSE))) else
    data.frame(code = character(), severity = character(), blocking = logical(), message = character(),
      group = character(), reference_group = character(), statistics = character(), grid = character())
  metadata <- list(analysis_mode = "distribution-effects", design = "independent", biological_unit_column = a[["unit-col"]],
    technical_policy = a[["technical-policy"]], technical_aggregation_declared = a[["technical-policy"]] == "mean",
    group_order = result$spec$group_levels, reference_group = a[["reference-group"]],
    dataset = a[["dataset-name"]], response = a[["response-col"]], outcome_unit = a[["outcome-unit"]],
    quantile_grid = result$spec$quantile_grid, min_cell_n = result$spec$min_cell_n,
    inference = result$spec$inference, bootstrap_configuration_active = a$inference != "none",
    ci_level = .95, ci_adjustment = "none_pointwise", family_size = 0L, adjustment = "not_applicable_no_hypothesis_tests",
    small_sample_policy = "withhold source estimates/associated effective n; no biological row export",
    quantile_definition = "left-continuous inverse weighted ECDF; equal independent-unit weights; ties retained",
    smd_definition = "(mean(group)-mean(reference))/sqrt((unbiased_var(group)+unbiased_var(reference))/2)",
    estimator_source = "TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/descriptive-distribution/scripts/descdist_core.R",
    estimand_direction = "group_minus_reference", guardrails = result$guardrails,
    display = "interval", journal = a$journal, rows_exported = FALSE)
  # Deliberately omit raw, d, IDs, unit counts below threshold, raw draws and
  # extrema from tables AND the serialized handoff object / scientific choices.
  list(tables = list(distribution_metrics = metrics, effect_table = effects, distribution_guardrails = guard),
    metadata = metadata, object = list(metrics = metrics, guardrails = result$guardrails, spec = result$spec),
    handoff_type = "development_group_comparison", ready = FALSE, packages = c("stats"),
    method = paste("Independent biological-unit descriptive distribution comparison; group minus fixed reference.",
      "Inverse-ECDF fixed-grid quantiles and average-within-group-variance SMD copied from the pinned source.",
      "Minimum cell/quantile-tail/increment guards retained. Bootstrap, if requested, is iid within fixed groups:",
      "only pointwise 95% percentile intervals, no P values, simultaneous bands or multiplicity correction.",
      "Caller choices and withheld estimates remain explicit; owner/native scientific review is pending."))
}

os_gpc_advisory <- function(res, a) {
  mode <- a[["distribution-diagnostics"]] %||% "off"
  if (mode == "off") return(res)
  if (mode != "source-advisory") stop("OS_INVALID_PARAMETER: unknown distribution diagnostics mode", call. = FALSE)
  d <- res$tables$biological_units; tests <- res$tables$tests
  rows <- lapply(seq_len(nrow(tests)), function(i) {
    pair <- !is.na(tests$group1[i]); paired <- a$design == "paired"
    if (pair && paired) {
      x <- d[d$group == tests$group1[i], ]; y <- d[d$group == tests$group2[i], ]; y <- y[match(x$unit, y$unit), ]
      values <- x$value - y$value; scope <- "paired_group1_minus_group2_differences"
    } else {
      selected <- if (pair) d$group %in% c(tests$group1[i], tests$group2[i]) else rep(TRUE, nrow(d))
      values <- d$value[selected]; scope <- if (paired) "pooled_repeated_values_not_model_residuals" else "pooled_endpoint_not_model_residuals"
    }
    profile <- .os_gpc_port$typing$.bt_classify_all(data.frame(endpoint = values), "endpoint", continuous_vars = "endpoint")$endpoint
    rec <- .os_gpc_port$typing$recommend_test(profile$type, n_groups = if (pair) 2L else length(res$metadata$group_order),
      paired = paired, normal = profile$normal, trend = FALSE, expected_min = NA_real_)
    data.frame(contrast = tests$contrast[i], diagnostic_scope = scope, source_type = profile$type,
      n = profile$n, normal_branch = profile$normal, skewness_g1 = profile$skewness, qq_correlation = profile$filliben_r,
      shapiro_reference_p = profile$shapiro_p, source_recommended_test = rec$test_name,
      source_recommended_call_text = rec$test_r_call, source_summary_statistic = rec$descriptive_stat,
      actual_prespecified_test = tests$test[i], automatic_selection = FALSE,
      notes = paste(c(profile$notes, rec$notes, "Source heuristic only; no validity proof and no replacement for a prespecified analysis."), collapse = " "), stringsAsFactors = FALSE)
  })
  res$tables$distribution_advisory <- do.call(rbind, rows)
  res$metadata$distribution_diagnostics <- "source-advisory"
  res$metadata$automatic_test_selection <- FALSE
  res$metadata$advisory_source <- "TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:baseline-table and _shared/scripts/var_typing.R"
  res$method <- paste(res$method, "Optional source classification uses n<20 conservative non-normal routing, otherwise |g1|<=1; Shapiro/QQ are reference only.",
    "Two-valued endpoints remain explicitly continuous; constants stay constant. Advice never reroutes the declared test, rank handling or multiplicity family.")
  res
}

os_gpc_validate_branch <- function(a) {
  mode <- os_gpc_mode(a)
  if (mode == "hypothesis-tests") {
    extras <- c("reference-group", "quantile-grid", "min-cell-n", "outcome-unit", "inference", "bootstrap-replicates", "min-success-fraction", "dataset-name")
    if (a$display == "interval" || any(vapply(extras, function(k) !is.null(a[[k]]), logical(1))))
      stop("OS_CONFLICTING_PARAMETERS: distribution-effect controls require the separate distribution-effects analysis mode", call. = FALSE)
  }
  invisible(mode)
}
