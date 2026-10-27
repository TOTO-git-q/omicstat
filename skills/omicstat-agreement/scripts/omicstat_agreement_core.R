# OmicStat contracts around copied agreement estimators. No MedStat runtime.
.os_ag_module <- local({
  f <- vapply(sys.frames(), function(x) if (is.null(x$ofile)) "" else x$ofile, "")
  dirname(dirname(normalizePath(tail(f[nzchar(f)], 1), mustWork = TRUE)))
})
os_agreement_port <- function() {
  e <- new.env(parent = baseenv())
  sys.source(file.path(.os_ag_module, "scripts", "agreement_ported_core.R"), envir = e)
  sys.source(file.path(.os_ag_module, "scripts", "agreement_ported_qc.R"), envir = e)
  e
}
.os_ag_stop <- function(message, code = "OS_INVALID_PARAMETER")
  stop(paste0(code, ": ", message), call. = FALSE)
.os_ag_need <- function(a, keys) {
  missing <- keys[vapply(keys, function(k) is.null(a[[k]]), logical(1))]
  if (length(missing)) .os_ag_stop(paste("required:", paste0("--", missing, collapse = ", ")), "OS_MISSING_PARAMETER")
}
.os_ag_scalar <- function(x, key, lo = -Inf, hi = Inf) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lo || x > hi)
    .os_ag_stop(paste("finite scalar required for", key))
}
.os_ag_text <- function(x, key) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x)))
    .os_ag_stop(paste("nonblank string required for", key))
}
.os_ag_csv <- function(x, key) {
  .os_ag_text(x, key); z <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  if (grepl(",$", x) || any(!nzchar(z)) || anyDuplicated(z))
    .os_ag_stop(paste("distinct nonblank comma-separated values required for", key))
  z
}
.os_ag_ids <- function(d, key, port, ba = FALSE) {
  port$ag_need_cols(d, key, "independent-unit ID")
  ids <- as.character(d[[key]])
  if (anyNA(ids) || any(!nzchar(trimws(ids)))) .os_ag_stop("OAG-01: blank independent-unit ID", "OS_INVALID_INPUT")
  if (anyDuplicated(ids)) .os_ag_stop(if (ba) "OAG-12: repeated or clustered pairs are unsupported" else
    "OAG-02: one row per independent subject is required", "OS_INVALID_DESIGN")
  ids
}

os_agreement_validate <- function(a) {
  .os_ag_need(a, c("analysis", "input", "labels", "format", "confidence-level", "missing",
    "independent-unit", "unit-description", "repeated-measures", "outcome-unit", "dataset-name"))
  if (!a$analysis %in% c("kappa", "fleiss", "icc", "bland-altman")) .os_ag_stop("QBA and other unported routes are unsupported")
  .os_ag_scalar(a[["confidence-level"]], "confidence-level", 0, 1)
  if (a[["confidence-level"]] %in% c(0, 1)) .os_ag_stop("confidence-level must be strictly between 0 and 1")
  if (a$missing != "fail") .os_ag_stop("OAG-01: silent listwise deletion is refused", "OS_INVALID_DESIGN")
  if (a[["repeated-measures"]] != "false") .os_ag_stop("OAG-12: dependent/repeated measurements need a separately reviewed estimator", "OS_INVALID_DESIGN")
  for (k in c("unit-description", "outcome-unit", "dataset-name")) .os_ag_text(a[[k]], k)
  if (!a[["independent-unit"]] %in% c("animal", "donor", "biological-sample", "independent-culture", "physical-test-item", "aggregate-unit"))
    .os_ag_stop("declare the actual independent measurement unit", "OS_INVALID_DESIGN")
  if (!a$format %in% c("wide", "long", "counts")) .os_ag_stop("unknown input format")
  all_route <- c("id-col", "rater-cols", "rater-col", "rating-col", "count-col", "scale", "levels", "weights",
    "paradox-agreement", "paradox-kappa", "paradox-prevalence-index", "paradox-bias-index", "marginal-divergence",
    "ci-method", "bootstrap-reps", "interpretation", "icc-model", "icc-definition", "icc-unit", "rater-population",
    "same-raters", "icc-fixed-agreement-rationale", "adequacy-threshold", "adequacy-rationale",
    "method-a-col", "method-b-col", "difference", "acceptability-limit-lower", "acceptability-limit-upper", "acceptability-rationale")
  categorical <- c("id-col", "rater-cols", "rater-col", "rating-col", "count-col", "scale", "levels", "weights", "ci-method", "bootstrap-reps", "interpretation")
  warning_flags <- c("paradox-agreement", "paradox-kappa", "paradox-prevalence-index", "paradox-bias-index", "marginal-divergence")
  allowed <- switch(a$analysis, kappa = c(categorical, warning_flags), fleiss = categorical,
    icc = c("id-col", "rater-cols", "icc-model", "icc-definition", "icc-unit", "rater-population", "same-raters", "icc-fixed-agreement-rationale", "adequacy-threshold", "adequacy-rationale"),
    "bland-altman" = c("id-col", "method-a-col", "method-b-col", "difference", "acceptability-limit-lower", "acceptability-limit-upper", "acceptability-rationale"))
  unused <- setdiff(all_route[vapply(all_route, function(k) !is.null(a[[k]]), logical(1))], allowed)
  if (length(unused)) .os_ag_stop(paste("parameters do not belong to this route:", paste(unused, collapse = ", ")), "OS_CONFLICTING_PARAMETERS")
  if (a$format != "counts") .os_ag_need(a, "id-col")
  if (a$format == "counts" && a[["independent-unit"]] != "aggregate-unit")
    .os_ag_stop("counts input has no independently verifiable subject IDs; declare aggregate-unit", "OS_INVALID_DESIGN")
  if (a$format == "counts" && !is.null(a[["id-col"]]))
    .os_ag_stop("counts input does not bind a subject ID column", "OS_CONFLICTING_PARAMETERS")
  if (a$format != "counts" && a[["independent-unit"]] == "aggregate-unit")
    .os_ag_stop("row data require the actual independent unit, not aggregate-unit", "OS_INVALID_DESIGN")
  if (a$analysis %in% c("icc", "bland-altman") && a$format != "wide")
    .os_ag_stop("ICC and Bland-Altman currently require complete wide input", "OS_INVALID_DESIGN")
  port <- os_agreement_port()
  d <- port$ag_read_csv(a$input)
  if (anyDuplicated(names(d)) || any(!nzchar(names(d)))) .os_ag_stop("OAG-01: duplicate/blank input column names", "OS_INVALID_INPUT")
  labels <- port$ag_read_labels(a$labels)
  if (anyDuplicated(names(labels)) || anyNA(labels) || any(!nzchar(trimws(labels))))
    .os_ag_stop("OAG-03: label keys must be unique and values nonblank", "OS_INVALID_INPUT")
  label_keys <- c("population", "measurement")
  checked <- list(port = port, data = d, labels = labels)
  checked$thresholds <- port$AG_DEFAULTS
  thresholds <- c("paradox-agreement"="paradox_agreement", "paradox-kappa"="paradox_kappa",
    "paradox-prevalence-index"="paradox_prevalence_index", "paradox-bias-index"="paradox_bias_index",
    "marginal-divergence"="marginal_tv_distance")
  for (flag in names(thresholds)) if (!is.null(a[[flag]])) {
    .os_ag_scalar(a[[flag]], flag, 0, 1); checked$thresholds[[thresholds[[flag]]]] <- a[[flag]]
  }
  if (a$analysis %in% c("kappa", "fleiss")) {
    .os_ag_need(a, c("rater-cols", "scale", "weights", "ci-method", "bootstrap-reps", "interpretation"))
    raters <- .os_ag_csv(a[["rater-cols"]], "rater-cols")
    if (a$analysis == "kappa" && length(raters) != 2L) .os_ag_stop("Cohen kappa requires exactly two raters", "OS_INVALID_DESIGN")
    if (a$analysis == "fleiss" && (length(raters) < 3L || a$format == "counts"))
      .os_ag_stop("OAG-09: Fleiss requires at least three complete raters and subject-level rows", "OS_INVALID_DESIGN")
    if (!a$scale %in% c("nominal", "ordinal")) .os_ag_stop("unknown category scale")
    if (a$scale == "ordinal") .os_ag_need(a, "levels")
    if (a$analysis == "kappa" && ((a$scale == "nominal" && a$weights != "none") || (a$scale == "ordinal" && a$weights != "both")))
      .os_ag_stop("OAG-04: nominal uses none; ordinal explicitly retains linear primary plus quadratic sensitivity", "OS_INVALID_DESIGN")
    if (a$analysis == "fleiss" && (a$weights != "none" || a[["ci-method"]] != "bootstrap"))
      .os_ag_stop("OAG-09: Fleiss is unweighted with subject bootstrap, not weighted Cohen", "OS_INVALID_DESIGN")
    if (!a[["ci-method"]] %in% c("analytic", "bootstrap") || !a$interpretation %in% c("landis-koch", "mchugh", "none"))
      .os_ag_stop("unknown categorical interval or interpretation declaration")
    .os_ag_scalar(a[["bootstrap-reps"]], "bootstrap-reps", 100, .Machine$integer.max)
    if (a[["bootstrap-reps"]] != floor(a[["bootstrap-reps"]])) .os_ag_stop("bootstrap-reps must be integer")
    if (a$format == "long") {
      .os_ag_need(a, c("rater-col", "rating-col")); port$ag_need_cols(d, a[["rater-col"]], "rater ID")
      rr <- d[[a[["rater-col"]]]]
      if (anyNA(rr) || any(!nzchar(trimws(as.character(rr))))) .os_ag_stop("OAG-01: missing rater ID", "OS_INVALID_INPUT")
    }
    if (a$format == "counts") .os_ag_need(a, "count-col")
    if (a$format != "long" && (!is.null(a[["rater-col"]]) || !is.null(a[["rating-col"]])))
      .os_ag_stop("long-format flags supplied for another format", "OS_CONFLICTING_PARAMETERS")
    if (a$format != "counts" && !is.null(a[["count-col"]])) .os_ag_stop("count-col is only for counts", "OS_CONFLICTING_PARAMETERS")
    levels <- if (is.null(a$levels)) NULL else .os_ag_csv(a$levels, "levels")
    built <- port$ag_build_ratings(d, a$format, a[["id-col"]], raters, a[["rater-col"]], a[["rating-col"]], a[["count-col"]], levels)
    levels <- port$ag_resolve_levels(built$ratings, a$scale, levels)
    if (length(levels) < 2L) .os_ag_stop("OAG-05: fewer than two categories", "OS_INVALID_RESULT")
    # Explicit memory guard; no subsampling or silent switch of interval method.
    if (a[["ci-method"]] == "bootstrap" && sum(built$weights) > 1000000)
      .os_ag_stop("Bootstrap expansion exceeds 1000000 independent units; retain the full input and choose a reviewed larger-memory implementation or explicitly justify a different method.", "OS_RESOURCE_LIMIT")
    checked$built <- built; checked$levels <- levels; checked$raters <- raters
    label_keys <- c(label_keys, raters, levels)
  } else if (a$analysis == "icc") {
    .os_ag_need(a, c("rater-cols", "icc-model", "icc-definition", "icc-unit", "rater-population", "same-raters"))
    raters <- .os_ag_csv(a[["rater-cols"]], "rater-cols")
    if (length(raters) < 2L) .os_ag_stop("OAG-11: at least two raters required", "OS_INVALID_DESIGN")
    if (!a[["icc-model"]] %in% c("oneway", "twoway") || !a[["icc-definition"]] %in% c("agreement", "consistency") ||
        !a[["icc-unit"]] %in% c("single", "average") || !a[["rater-population"]] %in% c("random", "fixed"))
      .os_ag_stop("OAG-10: explicit permitted ICC model, definition and unit required", "OS_INVALID_DESIGN")
    same <- port$ag_as_bool(a[["same-raters"]], "same-raters")
    if (!is.null(a[["icc-fixed-agreement-rationale"]])) {
      .os_ag_text(a[["icc-fixed-agreement-rationale"]], "icc-fixed-agreement-rationale")
      if (a[["rater-population"]] != "fixed" || a[["icc-definition"]] != "agreement")
        .os_ag_stop("fixed agreement rationale supplied for another ICC form", "OS_CONFLICTING_PARAMETERS")
    }
    if (a[["icc-model"]] == "oneway" && a[["rater-population"]] != "random")
      .os_ag_stop("OAG-10: the copied one-way form is random-effects", "OS_INVALID_DESIGN")
    ids <- .os_ag_ids(d, a[["id-col"]], port)
    port$ag_need_cols(d, raters, "ICC raters")
    if (!all(vapply(d[raters], is.numeric, logical(1)))) .os_ag_stop("OAG-01: ICC requires numeric columns without coercion", "OS_INVALID_INPUT")
    checked$matrix <- as.matrix(d[raters]); rownames(checked$matrix) <- ids
    checked$design <- port$ag_icc_design(a[["icc-model"]], a[["icc-definition"]], a[["icc-unit"]], a[["rater-population"]], same, a[["icc-fixed-agreement-rationale"]])
    if (xor(is.null(a[["adequacy-threshold"]]), is.null(a[["adequacy-rationale"]])))
      .os_ag_stop("adequacy threshold and prespecified rationale must be supplied together")
    if (!is.null(a[["adequacy-threshold"]])) { .os_ag_scalar(a[["adequacy-threshold"]], "adequacy-threshold", 0, 1); .os_ag_text(a[["adequacy-rationale"]], "adequacy-rationale") }
    checked$raters <- raters; checked$ids <- ids; label_keys <- c(label_keys, raters)
  } else {
    .os_ag_need(a, c("method-a-col", "method-b-col", "difference"))
    cols <- c(a[["method-a-col"]], a[["method-b-col"]])
    if (anyDuplicated(cols) || !a$difference %in% c("a-minus-b", "b-minus-a")) .os_ag_stop("two distinct methods and explicit signed difference required")
    port$ag_need_cols(d, cols, "measurement methods")
    if (!all(vapply(d[cols], is.numeric, logical(1)))) .os_ag_stop("OAG-01: numeric method columns required without coercion", "OS_INVALID_INPUT")
    checked$ids <- .os_ag_ids(d, a[["id-col"]], port, ba = TRUE)
    lower <- a[["acceptability-limit-lower"]]; upper <- a[["acceptability-limit-upper"]]
    if (xor(is.null(lower), is.null(upper))) .os_ag_stop("OAG-12: both acceptability limits or neither required")
    if (!is.null(lower)) {
      .os_ag_scalar(lower, "acceptability-limit-lower"); .os_ag_scalar(upper, "acceptability-limit-upper")
      if (lower >= upper) .os_ag_stop("OAG-12: lower acceptability limit must be below upper")
      .os_ag_need(a, "acceptability-rationale"); .os_ag_text(a[["acceptability-rationale"]], "acceptability-rationale")
    } else if (!is.null(a[["acceptability-rationale"]])) .os_ag_stop("rationale supplied without paired limits", "OS_CONFLICTING_PARAMETERS")
    checked$cols <- cols; label_keys <- c(label_keys, cols)
  }
  port$ag_require_labels(labels, label_keys, "reader-facing variable or category")
  for (keys in list(checked$raters, checked$levels, checked$cols))
    if (length(keys) > 1L && anyDuplicated(unname(labels[keys])))
      .os_ag_stop("OAG-03: distinct raters, methods or categories need distinct reader-facing labels", "OS_INVALID_INPUT")
  if (a$format != "counts" && a[["id-col"]] %in% c(checked$raters, checked$cols))
    .os_ag_stop("independent-unit ID cannot also be a measurement/rater column", "OS_INVALID_DESIGN")
  checked
}

omicstat_agreement_compute <- function(a) {
  x <- os_agreement_validate(a); p <- x$port; conf <- a[["confidence-level"]]
  contract <- if (!is.null(a[["study-contract"]])) os_study_contract_read(a[["study-contract"]]) else list(sha256 = NULL)
  qc <- p$ag_qc_new(); tables <- list(); packages <- character(); native <- NULL
  label <- function(k) unname(x$labels[k])
  row <- function(term, estimate, low, high, method, status = "primary")
    data.frame(term = term, estimate = estimate, ci_low = low, ci_high = high, ci_level = conf,
      interval_method = method, status = status, stringsAsFactors = FALSE)
  if (a$analysis == "kappa") {
    native <- p$ag_kappa_route(x$built$ratings, x$built$weights, x$levels, a$scale, a$weights, conf,
      a[["ci-method"]], a[["bootstrap-reps"]], a$seed, a$interpretation, x$thresholds)
    tables$effect_table <- do.call(rbind, lapply(native$coefficients, function(z) {
      d <- row(paste0("kappa_", z$weights), z$estimate, z$ci_lower, z$ci_upper, z$ci_method, z$status)
      d$engine <- z$engine; d$engine_version <- z$engine_version
      d$bootstrap_reps <- z$bootstrap_reps; d$bootstrap_success <- z$bootstrap_success
      d$bootstrap_failures <- z$bootstrap_failures; d$bootstrap_seed <- z$bootstrap_seed; d
    }))
    tables$rater_marginals <- native$marginals; tables$rater_marginals$category <- label(tables$rater_marginals$category)
    tab <- native$contingency
    tables$contingency <- do.call(rbind, lapply(seq_along(x$levels), function(i)
      data.frame(row_category = label(x$levels[i]), col_category = label(x$levels), count = tab[i, ], row_total = sum(tab[i, ]),
        row_fraction = if (sum(tab[i, ]) == 0) NA_real_ else tab[i, ] / sum(tab[i, ]), stringsAsFactors = FALSE)))
    tables$agreement_summary <- data.frame(n_units = native$n, n_agree = native$n_agree,
      observed_agreement = native$observed_agreement, expected_agreement = native$expected_agreement)
    if (!is.null(native$binary)) {
      z <- native$binary
      tables$binary_companions <- data.frame(term = c("PABAK", "prevalence_index", "bias_index", paste0("specific_agreement_", label(x$levels))),
        estimate = c(z$pabak, z$prevalence_index, z$bias_index, z$specific_agreement_first, z$specific_agreement_second),
        ci_low = c(z$pabak_ci_lower, z$prevalence_index_ci[1], z$bias_index_ci[1], NA, NA),
        ci_high = c(z$pabak_ci_upper, z$prevalence_index_ci[2], z$bias_index_ci[2], NA, NA),
        status = "sensitivity_not_replacement", promoted_with_primary = native$paradox$triggered,
        engine = c(rep("epiR::epi.kappa", 3), rep("original declared-category count formula", 2)))
    }
    qc <- p$ag_qc_kappa(qc, "kappa", native, x$labels, x$thresholds)
    packages <- c("vcd", if (length(x$levels) == 2L) "epiR")
  } else if (a$analysis == "fleiss") {
    native <- p$ag_fleiss_route(x$built$ratings, x$levels, conf, a[["bootstrap-reps"]], a$seed, a$interpretation)
    tables$effect_table <- row("fleiss_kappa", native$estimate, native$ci_lower, native$ci_upper, native$ci_method)
    tables$effect_table$bootstrap_reps <- native$bootstrap_reps; tables$effect_table$bootstrap_success <- native$bootstrap_success
    tables$effect_table$bootstrap_failures <- native$bootstrap_failures; tables$effect_table$bootstrap_seed <- native$bootstrap_seed
    tables$category_distribution <- native$category_distribution; tables$category_distribution$category <- label(tables$category_distribution$category)
    if (native$bootstrap_failures > 0) qc <- p$ag_qc_add(qc, "OAG-06", "warning", "fleiss",
      "Some subject bootstrap replicates failed; failed count is retained.", paste(native$bootstrap_success, "successful of", native$bootstrap_reps),
      "Review sparse categories; no failed replicate is replaced or hidden.", "tables/effect_table.csv")
    packages <- "irr"
  } else if (a$analysis == "icc") {
    native <- p$ag_icc_route(x$matrix, x$design, conf)
    tables$effect_table <- row(native$notation, native$estimate, native$ci_lower, native$ci_upper, native$ci_method)
    tables$effect_table$model <- native$design$model_description; tables$effect_table$definition <- native$design$definition_description
    tables$effect_table$measurement_unit <- native$design$unit; tables$effect_table$n_units <- native$n_subjects
    tables$effect_table$n_raters <- native$n_raters; tables$effect_table$engine <- native$engine
    tables$effect_table$adequacy_threshold <- if (is.null(a[["adequacy-threshold"]])) NA_real_ else a[["adequacy-threshold"]]
    tables$effect_table$lower_bound_meets_threshold <- if (is.null(a[["adequacy-threshold"]])) NA else native$ci_lower >= a[["adequacy-threshold"]]
    packages <- "irr"
  } else {
    native <- p$ag_bland_altman(x$data[[x$cols[1]]], x$data[[x$cols[2]]], x$ids, a$difference, conf,
      a[["acceptability-limit-lower"]], a[["acceptability-limit-upper"]])
    tables$effect_table <- rbind(row("mean_difference", native$bias, native$bias_ci_lower, native$bias_ci_upper, native$ci_method),
      row("lower_95pct_LoA", native$loa_lower, native$loa_lower_ci_lower, native$loa_lower_ci_upper, native$ci_method),
      row("upper_95pct_LoA", native$loa_upper, native$loa_upper_ci_lower, native$loa_upper_ci_upper, native$ci_method))
    tables$effect_table$loa_population_coverage <- c(NA_real_, .95, .95)
    tables$pairs <- native$pairs
    tables$acceptability <- data.frame(lower = native$clinical_lower, upper = native$clinical_upper,
      prespecified_limits_supplied = native$clinical_limits_supplied, loa_and_ci_within_limits = native$compatible,
      automatic_substitutability_claim = FALSE)
    tables$diagnostics <- as.data.frame(native$diagnostics)
    qc <- p$ag_qc_ba(qc, "bland_altman", native, p$AG_DEFAULTS, a[["outcome-unit"]])
  }
  e <- tables$effect_table
  if (any(!is.finite(as.matrix(e[c("estimate", "ci_low", "ci_high")]))))
    .os_ag_stop("OAG-05: at least one required estimate or interval is non-estimable", "OS_INVALID_RESULT")
  if (any(e$ci_low > e$ci_high)) .os_ag_stop("OAG-18: reversed native interval", "OS_INVALID_RESULT")
  # Preserve bounds outside [-1,1]. The original release guard below still
  # refuses a point estimate outside its own interval, including bootstrap.
  # No clipping, replacement estimator, pair deletion or method selection occurs.
  units <- if (a$analysis %in% c("kappa", "fleiss")) sum(x$built$weights) else length(x$ids)
  estimand <- list(analysis = a$analysis, independent_unit = a[["independent-unit"]],
    unit_description = a[["unit-description"]], population = label("population"), measurement = label("measurement"),
    raters = if (is.null(x$raters)) NULL else label(x$raters), category_order = if (is.null(x$levels)) NULL else label(x$levels),
    scale = a$scale, weights = a$weights, ci_method = a[["ci-method"]], confidence_level = conf,
    icc_design = x$design, difference = a$difference, outcome_unit = a[["outcome-unit"]],
    acceptability_limits = c(a[["acceptability-limit-lower"]], a[["acceptability-limit-upper"]]),
    acceptability_rationale = a[["acceptability-rationale"]], adequacy_threshold = a[["adequacy-threshold"]], adequacy_rationale = a[["adequacy-rationale"]])
  estimand_hash <- digest::digest(estimand, algo = "sha256")
  tables$effect_table$model_spec_hash <- estimand_hash
  method <- paste("Independent candidate agreement analysis:", a$analysis, ";", units, "independent units.",
    "Agreement does not establish validity, diagnostic accuracy, or universal method interchangeability.",
    "No missing ratings were deleted and no repeated/clustered variance was approximated.",
    if (a$analysis == "bland-altman") paste("Difference:", a$difference, "in", a[["outcome-unit"]],
      ". Limits of agreement retain 95% population coverage (bias +/- 1.96 SD); the declared confidence level controls each limit's CI.",
      "Diagnostics are exploratory; no automatic transformation or proportional-bias correction.",
      if (native$clinical_limits_supplied) "Compatibility is checked against prespecified limits including LoA uncertainty, not inferred from correlation." else
        "No acceptability interval was supplied: the analysis is descriptive only.") else if (a$analysis == "icc")
      paste(native$notation, native$design$model_description, native$design$definition_description, native$design$unit_description,
        "using irr::icc only; no psych fallback. Reliability is population-dependent; descriptive bands are not adequacy thresholds.") else
      paste("Chance model:", if (a$analysis == "kappa") "Cohen" else "Fleiss", ";", p$AG_INTERPRETATION_CAVEAT,
        "The subject bootstrap resamples independent units, not rating cells. PABAK is a sensitivity companion, never a replacement for primary kappa."))
  result <- list(tables = tables, metadata = list(analysis = a$analysis, estimand = estimand, estimand_sha256 = estimand_hash,
    n_independent = units, ids_verified = a$format != "counts", dataset_name = a[["dataset-name"]],
    dataset_name_is_user_declaration_not_owner_receipt = TRUE, outcome_unit = a[["outcome-unit"]],
    independent_unit = a[["independent-unit"]], journal = a$journal, original_qc = qc,
    labels = x$labels, raters = x$raters, levels = x$levels, method_cols = x$cols,
    confidence_level = conf, original_thresholds = p$AG_DEFAULTS, used_thresholds = x$thresholds,
    ported_from = "TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/agreement/", contract_sha256 = contract$sha256),
    object = list(native = native, estimand = estimand, estimand_sha256 = estimand_hash),
    input_files = list(input = a$input, labels = a$labels, study_contract = a[["study-contract"]]),
    packages = packages, handoff_type = "development_agreement_model", ready = FALSE, method = method)
  os_agreement_release(result)
  result
}

# Retain the source AG-18 count, interval and estimand-identity guard. This is
# called before module_finish and again at the renderer boundary. Its failure
# cannot be "repaired" by clipping, deleting a pair or choosing a new method.
os_agreement_release <- function(res) {
  m <- res$metadata; n <- res$object$native; e <- res$tables$effect_table
  if (!is.data.frame(e) || !all(c("term", "estimate", "ci_low", "ci_high", "ci_level", "model_spec_hash") %in% names(e)))
    .os_ag_stop("OAG-18: effect table is missing a required numerical or estimand-binding column", "OS_INVALID_RESULT")
  checks <- list()
  chk <- function(ok, detail) checks[[length(checks) + 1L]] <<- list(ok = isTRUE(ok), detail = detail)
  chk(nrow(e) > 0 && all(is.finite(as.matrix(e[c("estimate", "ci_low", "ci_high")]))), "required numerical results are finite")
  chk(all(e$ci_low <= e$estimate + 1e-9 & e$estimate <= e$ci_high + 1e-9), "estimate lies inside its reported interval (original source release condition)")
  chk(identical(m$estimand, res$object$estimand), "metadata and model estimands agree")
  chk(identical(digest::digest(m$estimand, algo = "sha256"), m$estimand_sha256), "metadata estimand hash binds actual declaration")
  chk(identical(m$estimand_sha256, res$object$estimand_sha256) && all(e$model_spec_hash == m$estimand_sha256), "every effect row and model carry the same estimand hash")
  chk(all(e$ci_level == m$confidence_level), "all interval levels equal the declared confidence level")
  route_n <- switch(m$analysis, kappa = n$n, fleiss = n$n_subjects, icc = n$n_subjects, "bland-altman" = n$n)
  chk(is.finite(route_n) && abs(m$n_independent - route_n) < 1e-9, "published and route independent counts agree")
  compare <- function(est, lo, hi) {
    chk(isTRUE(all.equal(unname(e$estimate), unname(est), tolerance = 1e-12)), "effect estimates equal canonical native values")
    chk(isTRUE(all.equal(unname(e$ci_low), unname(lo), tolerance = 1e-12)), "lower intervals equal canonical native values")
    chk(isTRUE(all.equal(unname(e$ci_high), unname(hi), tolerance = 1e-12)), "upper intervals equal canonical native values")
  }
  if (m$analysis == "kappa") {
    chk(identical(e$term, vapply(n$coefficients, function(x) paste0("kappa_", x$weights), "")), "kappa row identities equal canonical weights")
    compare(vapply(n$coefficients, function(x) x$estimate, 0), vapply(n$coefficients, function(x) x$ci_lower, 0), vapply(n$coefficients, function(x) x$ci_upper, 0))
    chk(sum(n$contingency) == n$n && sum(diag(n$contingency)) == n$n_agree, "contingency total and diagonal equal analysed and agreed counts")
    chk(sum(res$tables$contingency$count) == m$n_independent, "written contingency retains every counted unit")
  } else if (m$analysis == "bland-altman") {
    chk(identical(e$term, c("mean_difference", "lower_95pct_LoA", "upper_95pct_LoA")), "Bland-Altman row identities retain bias and limits")
    compare(c(n$bias, n$loa_lower, n$loa_upper), c(n$bias_ci_lower, n$loa_lower_ci_lower, n$loa_upper_ci_lower), c(n$bias_ci_upper, n$loa_lower_ci_upper, n$loa_upper_ci_upper))
    chk(n$loa_lower < n$bias && n$bias < n$loa_upper, "bias lies between limits of agreement")
    chk(nrow(n$pairs) == m$n_independent && identical(res$tables$pairs, n$pairs), "pair table agrees with canonical input count and values")
  } else compare(n$estimate, n$ci_lower, n$ci_upper)
  p <- os_agreement_port(); q <- p$ag_qc_release(p$ag_qc_new(), m$analysis, checks)
  if (nrow(q)) .os_ag_stop(paste("OAG-18:", paste(q$evidence, collapse = "; ")), "OS_INVALID_RESULT")
  invisible(TRUE)
}
