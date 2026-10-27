here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(here, "distribution_test_helpers.R")); root <- gpc_load_native(here)
source(file.path(here, "ported_source/test_harness.R")); harness <- dd_test_harness(); check <- harness$check
scope <- new.env(parent = .os_gpc_port$distribution); scope$check <- check; scope$sd <- stats::sd
sys.source(file.path(here, "ported_distribution_checks.R"), envir = scope)
out <- Sys.getenv("OMICSTAT_GROUPCOMPARE_PORT_OUT", "")
if (!nzchar(out)) out <- if (dir.exists("/evidence")) file.path("/evidence", "groupcompare-source-native") else file.path(tempdir(), paste0("omicstat-gpc-", Sys.getpid()))
if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE))) stop("Fresh evidence directory required; preserve previous failures")
dir.create(out, recursive = TRUE)
write <- function(x, name) {p <- file.path(out, name); utils::write.csv(x, p, row.names = FALSE); p}
data <- gpc_test_data(); a <- gpc_test_args(write(data, "synthetic.csv"))
res <- omicstat_groupcompare_compute(a)
refuse <- function(expr, code) {
  caught <- tryCatch({force(expr); "NO_ERROR"}, error = conditionMessage)
  stopifnot(grepl(code, caught, fixed = TRUE))
}
check("source/ported point and bootstrap CI same-input values", {
  values <- gpc_anchor_values(here, out)
  definitions <- jsonlite::fromJSON(file.path(here, "anchors.json"), simplifyVector = FALSE)
  for (z in definitions) if (z$id %in% names(values)) stopifnot(abs(values[[z$id]] - z$expected) <= z$tolerance)
})
check("new adapter preserves source aggregates and difference direction", {
  source <- .os_gpc_port$distribution$dd_analyze(data, gpc_source_spec())
  stopifnot(isTRUE(all.equal(source$metrics, res$tables$distribution_metrics[names(source$metrics)], check.attributes = FALSE)),
    all(res$tables$effect_table$direction == "group_minus_reference"), res$metadata$family_size == 0L)
})
check("no input IDs, raw rows, draws or extrema in aggregate return", {
  stopifnot(!any(c("biological_units", "summary", "tests") %in% names(res$tables)),
    !any(c("data", "draws", "ids") %in% names(res$object)), !grepl("synthetic_0001", paste(capture.output(str(res)), collapse = " ")),
    !any(c("input_rows", "biological_observations", "n_units") %in% names(res$metadata)))
})
check("technical means retain source biological estimates without raw export", {
  b <- a; b$input <- write(rbind(transform(data, well = "w1", value = value - 1), transform(data, well = "w2", value = value + 1)), "technical.csv")
  b[["technical-policy"]] <- "mean"; b[["technical-col"]] <- "well"
  z <- omicstat_groupcompare_compute(b)
  stopifnot(identical(res$tables$distribution_metrics, z$tables$distribution_metrics), z$metadata$technical_aggregation_declared)
})
check("tiny group and associated effects remain withheld", {
  b <- a; b$input <- write(data[c(1:9, 201:400), ], "small.csv"); z <- omicstat_groupcompare_compute(b)
  stopifnot(all(is.na(z$tables$effect_table$estimate)), all(is.na(z$tables$effect_table$effective_n)),
    all(is.na(z$tables$distribution_metrics$n[z$tables$distribution_metrics$group == "A"])))
})
check("empty declared group retained", {
  b <- a; b$input <- write(data[1:200, ], "one_group.csv"); z <- omicstat_groupcompare_compute(b)
  stopifnot(all(is.na(z$tables$effect_table$estimate)), "B" %in% z$tables$distribution_metrics$group)
})
check("source and adapter RNG/row-order remain stable", {
  b <- a; b$inference <- "iid_stratified_bootstrap"; b[["bootstrap-replicates"]] <- 200L; b[["min-success-fraction"]] <- .95
  rng_seed <- 1701L; set.seed(rng_seed); previous <- .Random.seed; z <- omicstat_groupcompare_compute(b); stopifnot(identical(previous, .Random.seed))
  b$input <- write(data[400:1, ], "reordered.csv"); reversed <- omicstat_groupcompare_compute(b)
  stopifnot(identical(z$tables$distribution_metrics, reversed$tables$distribution_metrics))
})
check("distinct namespaces do not replace the suite null helper", {
  stopifnot(!identical(.os_gpc_port$distribution, .os_gpc_port$typing), identical(NA %||% "fallback", "fallback"),
    is.na(.os_gpc_port$distribution$`%||%`(NA, "fallback")))
})
for (key in c("reference-group", "quantile-grid", "min-cell-n", "outcome-unit", "inference", "dataset-name")) {
  check(paste("required distribution choice", key), { b <- a; b[[key]] <- NULL; refuse(omicstat_groupcompare_compute(b), "OS_MISSING_PARAMETER") })
}
for (mut in list(list(design = "paired"), list(`pairwise-test` = "welch"), list(omnibus = "kruskal"),
                list(adjust = "holm"), list(`family-size` = 2L), list(display = "box"), list(`distribution-diagnostics` = "source-advisory"))) {
  check(paste("cross-branch refusal", names(mut)), {b <- utils::modifyList(a, mut); refuse(omicstat_groupcompare_compute(b), "OS_CONFLICTING_PARAMETERS")})
}
check("no non95percent source interval or low minimum threshold", {
  b <- a; b[["ci-level"]] <- .9; refuse(omicstat_groupcompare_compute(b), "OS_INVALID_PARAMETER")
  b <- a; b[["min-cell-n"]] <- 9; refuse(omicstat_groupcompare_compute(b), "OS_GPC_INVALID_SPEC")
})
check("missing/nonfinite values never silently complete-case excluded", {
  b <- a; z <- data; z$value[1] <- NA; b$input <- write(z, "missing.csv"); refuse(omicstat_groupcompare_compute(b), "OS_INVALID_INPUT")
})
check("duplicate biological IDs and conflicting roles refuse", {
  b <- a; z <- data; z$ID[201] <- z$ID[1]; b$input <- write(z, "overlap.csv"); refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
  b <- a; b[["unit-col"]] <- "group"; refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
})
check("bootstrap controls are explicit and range checked", {
  b <- a; b$inference <- "iid_stratified_bootstrap"; refuse(omicstat_groupcompare_compute(b), "OS_MISSING_PARAMETER")
  b[["bootstrap-replicates"]] <- 199L; b[["min-success-fraction"]] <- .95; refuse(omicstat_groupcompare_compute(b), "OS_GPC_INVALID_SPEC")
  b[["bootstrap-replicates"]] <- 200L; b[["min-success-fraction"]] <- .94; refuse(omicstat_groupcompare_compute(b), "OS_GPC_INVALID_SPEC")
})
check("classification source before/after and explicit continuous adaptation", {
  original <- new.env(parent = baseenv()); sys.source(file.path(here, "ported_source/var_typing.R"), envir = original)
  for (v in list(1:10, 1:30, exp(seq(-2, 2, length.out = 40)), rep(1, 30), rep(c(0, 1), 15))) {
    stopifnot(identical(original$classify_variable(v), .os_gpc_port$typing$classify_variable(v)))
  }
  z <- .os_gpc_port$typing$.bt_classify_all(data.frame(value = rep(c(1, 2), 15)), "value", continuous_vars = "value")$value
  stopifnot(z$type == "continuous", original$classify_variable(rep(c(1, 2), 15))$type == "binary")
})
check("small n heuristic and reference tests remain distinct", {
  stopifnot(identical(.os_gpc_port$typing$classify_variable(1:19)$normal, FALSE),
    identical(.os_gpc_port$typing$classify_variable(1:20)$normal, TRUE))
  rng_seed <- 1702L; set.seed(rng_seed); old <- .Random.seed; .os_gpc_port$typing$shapiro_p_ref(seq_len(6000)); stopifnot(identical(old, .Random.seed))
})
check("prespecified numerical path byte-equivalent outputs and advice never switches tests", {
  original <- new.env(parent = .GlobalEnv); sys.source(file.path(here, "ported_source/omicstat_groupcompare_before.R"), envir = original)
  d <- datasets::sleep; input <- write(d, "sleep.csv")
  comparisons <- write(data.frame(contrast = "1-2", group1 = "1", group2 = "2"), "comparisons.csv")
  b <- list(input = input, `response-col` = "extra", `group-col` = "group", `unit-col` = "ID", `group-order` = "1,2", design = "paired",
    `technical-policy` = "reject", comparisons = comparisons, `pairwise-test` = "paired-t", omnibus = "none", `rank-method` = "not-applicable",
    adjust = "none", `family-size` = 1L, `ci-level` = .9, display = "box", journal = "nature")
  old <- original$omicstat_groupcompare_compute(b); current <- omicstat_groupcompare_compute(b)
  stopifnot(identical(old, current))
  b[["distribution-diagnostics"]] <- "source-advisory"; advised <- omicstat_groupcompare_compute(b)
  stopifnot(identical(old$tables$tests, advised$tables$tests), identical(old$tables$effect_table, advised$tables$effect_table),
    !advised$metadata$automatic_test_selection, advised$tables$distribution_advisory$diagnostic_scope == "paired_group1_minus_group2_differences",
    advised$tables$distribution_advisory$actual_prespecified_test == "paired-t",
    advised$tables$distribution_advisory$source_recommended_test == "wilcoxon_signed_rank")
})
check("QC finding identities unique and whole suppression remains blocking", {
  b <- a; b$input <- write(data[c(1:5, 201:205), ], "suppressed.csv"); z <- omicstat_groupcompare_compute(b)
  q <- do.call(rbind, omicstat_groupcompare_qc(z)); stopifnot(!anyDuplicated(q$id), any(q$id == "OS_GPC_NO_RELEASABLE_ESTIMATES" & q$blocking))
})
check("all native call sites remain registered and original defaults checked", {
  registry <- file.path(dirname(here), "scripts/calls_registry.json")
  result <- check_calls(list.files(file.path(dirname(here), "scripts"), pattern = "\\.R$", full.names = TRUE), registry)
  stopifnot(result$ok, check_default_drift(registry)$ok)
  registered <- jsonlite::fromJSON(registry, simplifyVector = FALSE)
  observed <- lapply(registered$calls, function(cl) {
    parts <- strsplit(cl$fn, "::", fixed = TRUE)[[1]]
    fn <- getExportedValue(parts[1], parts[2]); fm <- formals(fn)
    method <- cl$method %||% paste0(parts[2], ".default")
    mf <- tryCatch(formals(get(method, envir = asNamespace(parts[1]))), error = function(e) NULL)
    for (arg in names(cl$args)) if (!arg %in% names(fm) && !is.null(mf) && arg %in% names(mf)) fm <- c(fm, mf[arg])
    stopifnot(all(names(cl$args) %in% names(fm)))
    list(fn = cl$fn, package_version = as.character(utils::packageVersion(parts[1])),
      inspected_method = if (is.null(mf)) NULL else method,
      actual_formals = as.list(vapply(names(fm), function(arg) paste(deparse(fm[[arg]]), collapse = ""), "")))
  })
  jsonlite::write_json(list(R = as.character(getRversion()), installed_stats = as.character(utils::packageVersion("stats")),
    registry_historical_bytes_unchanged = TRUE, captured_in_this_native_run = TRUE, signatures = observed),
    file.path(out, "ACTUAL_INSTALLED_FORMALS.json"), auto_unbox = TRUE, pretty = TRUE)

})
check("native aggregate figure source hash, pointwise contract and typed refusal mutations", {
  source(file.path(root, "skills/_shared/scripts/fig_all.R"))
  b <- a; b$inference <- "iid_stratified_bootstrap"; b[["bootstrap-replicates"]] <- 200L; b[["min-success-fraction"]] <- .95
  z <- omicstat_groupcompare_compute(b)
  for (stat in c("mean_difference", "smd", "quantile_difference")) {
    d <- z$tables$effect_table[z$tables$effect_table$statistic == stat, , drop = FALSE]
    original <- d
    p <- os_distribution_effects(d, stat, z$metadata$dataset, unique(d$unit), 10L, "iid_stratified_bootstrap", 200L)
    meta <- attr(p, "os_meta"); layer <- meta$definition$layers[[1]]
    stopifnot(identical(d, original), layer$source_sha256 == os_semantic_table_sha256(d, d$metric_id),
      identical(meta$notes$render_source_binding$status, "exact_source_hash_and_keys"),
      identical(layer$uncertainty$summary_coverage_required, FALSE), layer$uncertainty$coverage_scope == "pointwise")
    ggplot2::ggplot_build(p)
  }
  d <- z$tables$effect_table[z$tables$effect_table$statistic == "mean_difference", , drop = FALSE]
  draw <- function(x, inf = "iid_stratified_bootstrap", reps = 200L) os_distribution_effects(x, "mean_difference", z$metadata$dataset, unique(x$unit), 10L, inf, reps)
  # Semantic mutation only: a percentile CI need not surround its estimate.
  outside <- d; outside$ci_low <- outside$estimate + 1; outside$ci_high <- outside$estimate + 2
  p <- draw(outside); stopifnot(isTRUE(all.equal(.os_sem_frame(attr(p, "os_meta")$definition$layers[[1]]$raw_source), outside, check.attributes = FALSE)))
  bad <- d; bad$ci_high[1] <- NA_real_; refuse(draw(bad), "OS_INVALID_INPUT")
  bad <- d; bad$ci_status[1] <- NA_character_; refuse(draw(bad), "OS_INVALID_INPUT")
  bad <- d; bad$ci_low[1] <- bad$ci_high[1] + 1; refuse(draw(bad), "OS_INVALID_INPUT")
  bad <- d; bad$suppression[1] <- "OS_GPC_GROUP_N_BELOW_MINIMUM"; refuse(draw(bad), "OS_INVALID_INPUT")
  bad <- d; bad$display_label[1] <- ""; refuse(draw(bad), "OS_INVALID_INPUT")
  refuse(draw(d, "none", NULL), "OS_INVALID_INPUT"); refuse(draw(d, reps = 199L), "OS_INVALID_INPUT")
  # Partial state stays in raw source; the renderer must not infer a new n.
  mixed <- rbind(d, d); mixed$metric_id <- c("available", "withheld"); mixed$display_label <- c("same label", "same label")
  mixed$estimate[2] <- mixed$ci_low[2] <- mixed$ci_high[2] <- NA_real_
  mixed$ci_status[2] <- "not_estimable"; mixed$suppression[2] <- "OS_GPC_GROUP_N_BELOW_MINIMUM"
  p <- draw(mixed); layer <- attr(p, "os_meta")$definition$layers[[1]]
  stopifnot(nrow(.os_sem_frame(layer$raw_source)) == 2L, is.null(layer$n_independent), layer$uncertainty$availability == "partial",
    identical(unlist(layer$states$state), c("available", "nonestimable")))
  all_missing <- mixed[2, , drop = FALSE]; refuse(draw(all_missing), "OS_INVALID_INPUT")
})
result <- harness$summary()
jsonlite::write_json(result, file.path(out, "NATIVE_CONTRACTS.json"), auto_unbox = TRUE, pretty = TRUE)
quit(status = result$exit_status, save = "no")
