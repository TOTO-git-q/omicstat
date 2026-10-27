gpc_load_native <- function(here) {
  if (as.character(getRversion()) != "4.6.1") stop("OS_DEPENDENCY_MISSING: these source-port anchors require the independent OmicStat R4.6.1 lineage", call. = FALSE)
  root <- normalizePath(file.path(here, "..", "..", ".."), mustWork = TRUE)
  shared <- file.path(root, "skills/_shared/scripts")
  for (file in c("module_kit.R", "basic_stats_io.R", "calls_check.R")) source(file.path(shared, file), local = .GlobalEnv)
  for (file in c("omicstat_groupcompare_core.R", "gpc_distribution_adapter.R", "omicstat_groupcompare_qc.R"))
    source(file.path(dirname(here), "scripts", file), local = .GlobalEnv)
  invisible(root)
}

gpc_test_data <- function() data.frame(ID = sprintf("synthetic_%04d", 1:400),
  group = rep(c("A", "B"), each = 200), value = c(1:200, (1:200) + 2), stringsAsFactors = FALSE)

gpc_test_args <- function(input) list(input = input, `response-col` = "value", `group-col` = "group", `unit-col` = "ID",
  `group-order` = "A,B", design = "independent", `technical-policy` = "reject", `pairwise-test` = "none", omnibus = "none",
  `rank-method` = "not-applicable", adjust = "none", `family-size` = 1L, `ci-level` = .95, display = "interval", journal = "nature",
  `analysis-mode` = "distribution-effects", `distribution-diagnostics` = "off", `reference-group` = "A", `quantile-grid` = ".1,.5,.9",
  `min-cell-n` = 10L, `outcome-unit` = "synthetic measurement units", inference = "none", `dataset-name` = "SYNTHETIC source contract only", seed = 104729L)

gpc_source_spec <- function(bootstrap = FALSE) list(spec_version = "descdist.v1", analysis = "distribution_comparison",
  id = "ID", outcome = "value", group = "group", group_levels = c("A", "B"), reference_group = "A",
  quantile_grid = c(.1, .5, .9), make_figures = FALSE, unit = "synthetic measurement units",
  inference = if (bootstrap) list(method = "iid_stratified_bootstrap", replicates = 200L, seed = 104729L) else list(method = "none"))

gpc_anchor_values <- function(here, evidence_directory = NULL) {
  gpc_load_native(here)
  original <- new.env(parent = baseenv())
  sys.source(file.path(here, "ported_source/descdist_core.R"), envir = original)
  data <- gpc_test_data(); source_spec <- gpc_source_spec(TRUE)
  before <- original$dd_analyze(data, source_spec)
  after <- .os_gpc_port$distribution$dd_analyze(data, source_spec)
  numeric_names <- names(before$metrics)[vapply(before$metrics, is.numeric, logical(1))]
  stopifnot(identical(numeric_names, names(after$metrics)[vapply(after$metrics, is.numeric, logical(1))]))
  differences <- do.call(rbind, lapply(numeric_names, function(k) {
    x <- before$metrics[[k]]; y <- after$metrics[[k]]
    stopifnot(identical(is.na(x), is.na(y)))
    data.frame(metric_id = paste0("metric_", seq_along(x)), quantity = k,
      before = x, after = y, absolute_difference = abs(x - y), stringsAsFactors = FALSE)
  }))
  point <- .os_gpc_port$distribution$dd_analyze(data, gpc_source_spec())$metrics
  metric <- function(name) point$estimate[point$statistic == name & point$group == "B"]
  flip_spec <- gpc_source_spec(); flip_spec$reference_group <- "B"
  flip <- .os_gpc_port$distribution$dd_analyze(data, flip_spec)$metrics
  tied <- .os_gpc_port$distribution$dd_weighted(c(0, 0, 2, 2, 2, 9, 9, 10), rep(1, 8), c(.25, .5, .75))$quantile
  # Original BT-welch fixture and independent sum/variance calculation, copied
  # from baseline-table/tests/verified/run_verified.R. No source repository run.
  x <- 1:20; y <- 3:22
  va <- sum((x - mean(x))^2)/(length(x)-1); vb <- sum((y - mean(y))^2)/(length(y)-1)
  se2 <- va/length(x)+vb/length(y)
  df <- se2^2/((va/length(x))^2/(length(x)-1)+(vb/length(y))^2/(length(y)-1))
  expected <- 2*stats::pt(-abs((mean(x)-mean(y))/sqrt(se2)), df)
  obtained <- stats::t.test(x = x, y = y, var.equal = FALSE)$p.value
  values <- list(source_mean_difference = metric("mean_difference"), source_smd = metric("smd"),
    source_quantile_diff_min = min(metric("quantile_difference")), source_quantile_diff_max = max(metric("quantile_difference")),
    source_inverse_ties_first = tied[1], source_inverse_ties_middle = tied[2], source_inverse_ties_last = tied[3],
    source_reference_flip = flip$estimate[flip$statistic == "mean_difference" & flip$group == "A"],
    baseline_welch_moment_error = abs(obtained-expected), adapter_before_after_max_error = max(differences$absolute_difference, na.rm = TRUE))
  if (!is.null(evidence_directory)) {
    dir.create(evidence_directory, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(before$metrics, file.path(evidence_directory, "original_source_metrics.csv"), row.names = FALSE)
    utils::write.csv(after$metrics, file.path(evidence_directory, "ported_source_metrics.csv"), row.names = FALSE)
    utils::write.csv(differences, file.path(evidence_directory, "same_input_before_after.csv"), row.names = FALSE)
    jsonlite::write_json(list(R = as.character(getRversion()), statistics = values,
      same_input = "Synthetic source fixture only", original_source_code_runs_in = "Independent OmicStat process",
      scientific_pass_replaces_owner_review = FALSE), file.path(evidence_directory, "native_source_anchor_results.json"), auto_unbox = TRUE, digits = NA)
  }
  values
}
