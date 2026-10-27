# OmicStat laboratory adapter around the explicitly copied MedStat functions.
.os_ss_module <- local({
  f <- vapply(sys.frames(), function(x) if (is.null(x$ofile)) "" else x$ofile, "")
  dirname(dirname(normalizePath(tail(f[nzchar(f)], 1), mustWork = TRUE)))
})

os_samplesize_port <- function() {
  e <- new.env(parent = baseenv())
  # Original functions use qnorm only in excluded designs. Explicit imports keep
  # the copied selected engines independent of search-path attachment and MedStat.
  for (name in c("setNames")) e[[name]] <- get(name, envir = asNamespace("stats"))
  sys.source(file.path(.os_ss_module, "scripts", "samplesize_ported_engines.R"), envir = e)
  sys.source(file.path(.os_ss_module, "scripts", "samplesize_ported_qc.R"), envir = e)
  e
}

.os_ss_stop <- function(message, code = "OS_INVALID_PARAMETER")
  stop(paste0(code, ": ", message), call. = FALSE)

.os_ss_number <- function(x, name, lower = -Inf, upper = Inf, open = FALSE,
                          integer = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
      (open && (x <= lower || x >= upper)) ||
      (!open && (x < lower || x > upper)) ||
      (integer && x != floor(x))) .os_ss_stop(paste("invalid finite scalar --", name, sep = ""))
  invisible(x)
}

.os_ss_required <- function(a, names) {
  missing <- names[vapply(names, function(n) is.null(a[[n]]), logical(1))]
  if (length(missing)) .os_ss_stop(paste("design requires", paste0("--", missing, collapse = ", ")),
                                 "OS_MISSING_PARAMETER")
}

.os_ss_list <- function(x, name, numeric = FALSE) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x)))
    .os_ss_stop(paste("nonempty --", name, " required", sep = ""))
  values <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  if (grepl(",$", x) || any(!nzchar(values))) .os_ss_stop(paste("empty value in --", name, sep = ""))
  if (numeric) {
    values <- suppressWarnings(as.numeric(values))
    if (any(!is.finite(values))) .os_ss_stop(paste("finite numbers required for --", name, sep = ""))
  }
  values
}

os_samplesize_validate <- function(a) {
  designs <- c("mean_2sample", "mean_paired", "anova", "prop_2sample", "survival_logrank")
  if (is.null(a$design) || !a$design %in% designs) .os_ss_stop("unsupported laboratory design")
  .os_ss_required(a, c("alpha", "power", "sided", "direction", "ratio", "dropout",
                      "groups", "power-grid", "biological-unit", "unit-description",
                      "technical-replicates", "technical-policy", "planning-stage",
                      "effect-source", "effect-rationale", "outcome-unit"))
  .os_ss_number(a$alpha, "alpha", 0, 1, open = TRUE)
  .os_ss_number(a$power, "power", 0, 1, open = TRUE)
  .os_ss_number(a$ratio, "ratio", 0, Inf, open = TRUE)
  .os_ss_number(a$dropout, "dropout", 0, 1)
  if (a$dropout == 1) .os_ss_stop("dropout must be below 1")
  .os_ss_number(a[["technical-replicates"]], "technical-replicates", 1, 2147483647,
                integer = TRUE)
  if (!identical(a[["planning-stage"]], "a-priori") ||
      !a[["effect-source"]] %in% c("minimal-important-difference", "independent-pilot",
                                   "external-literature", "standardized-convention"))
    .os_ss_stop("only a priori assumptions are supported; completed-study observed power is excluded",
                "OS_INVALID_DESIGN")
  if (!identical(a[["technical-policy"]], "excluded-from-n"))
    .os_ss_stop("technical repeats cannot count as independent biological n", "OS_INVALID_DESIGN")
  if (!a[["biological-unit"]] %in% c("animal", "donor", "biological-sample", "independent-culture"))
    .os_ss_stop("declare an independent biological unit, not a well or cell", "OS_INVALID_DESIGN")
  for (n in c("unit-description", "effect-rationale", "outcome-unit"))
    if (!is.character(a[[n]]) || length(a[[n]]) != 1L || is.na(a[[n]]) || !nzchar(trimws(a[[n]])))
      .os_ss_stop(paste("nonempty --", n, " required", sep = ""))
  if (!a$sided %in% c("one", "two")) .os_ss_stop("sided must be one or two")
  groups <- .os_ss_list(a$groups, "groups")
  if (anyDuplicated(groups)) .os_ss_stop("group/condition labels must be unique")
  grid <- .os_ss_list(a[["power-grid"]], "power-grid", numeric = TRUE)
  if (any(grid <= 0 | grid >= 1) || anyDuplicated(grid) || is.unsorted(grid, strictly = TRUE) ||
      !a$power %in% grid) .os_ss_stop("power-grid must be strictly increasing, in (0,1), and contain power")
  applicable <- switch(a$design,
    mean_2sample = c("mean1", "mean2", "sd", "sd1", "sd2"),
    mean_paired = c("mean-diff", "sd-diff", "sd1", "sd2", "corr"),
    anova = c("k", "f", "means", "sd"), prop_2sample = c("p1", "p2"),
    survival_logrank = c("hr", "event-prob"))
  all_numeric <- c("mean1", "mean2", "sd", "sd1", "sd2", "mean-diff", "sd-diff",
                   "corr", "k", "f", "p1", "p2", "hr", "event-prob")
  supplied <- c(all_numeric, "means")[vapply(c(all_numeric, "means"), function(n) !is.null(a[[n]]), logical(1))]
  if (any(!supplied %in% applicable))
    .os_ss_stop(paste("unrelated design parameters:", paste(setdiff(supplied, applicable), collapse = ", ")),
                "OS_CONFLICTING_PARAMETERS")
  for (n in intersect(supplied, all_numeric)) .os_ss_number(a[[n]], n)
  for (n in intersect(supplied, c("sd", "sd1", "sd2", "sd-diff", "f", "hr")))
    .os_ss_number(a[[n]], n, 0, Inf, open = TRUE)
  if (a$design == "anova") {
    .os_ss_required(a, "k"); .os_ss_number(a$k, "k", 2, 2147483647, integer = TRUE)
    if (length(groups) != a$k) .os_ss_stop("ANOVA group labels must match k")
    if (a$sided != "two" || a$direction != "omnibus" || a$ratio != 1)
      .os_ss_stop("ANOVA is an omnibus equal-group design", "OS_INVALID_DESIGN")
    if (!is.null(a$f)) {
      if (!is.null(a$means) || !is.null(a$sd))
        .os_ss_stop("give f or means plus sd, not both", "OS_CONFLICTING_PARAMETERS")
    } else {
      .os_ss_required(a, c("means", "sd")); means <- .os_ss_list(a$means, "means", numeric = TRUE)
      if (length(means) != a$k || length(unique(means)) < 2L)
        .os_ss_stop("ANOVA means must match k and cannot all be equal")
    }
  } else {
    if (length(groups) != 2L) .os_ss_stop("two distinct group or paired-condition labels required")
    if ((a$sided == "two" && a$direction != "two-sided") ||
        (a$sided == "one" && !a$direction %in% c("group1-higher", "group1-lower")))
      .os_ss_stop("direction must explicitly match sided", "OS_INVALID_DESIGN")
  }
  signed <- NULL
  if (a$design == "mean_2sample") {
    .os_ss_required(a, c("mean1", "mean2"))
    if (!is.null(a$sd)) {
      if (!is.null(a$sd1) || !is.null(a$sd2))
        .os_ss_stop("give common sd or sd1 plus sd2, not both", "OS_CONFLICTING_PARAMETERS")
    } else .os_ss_required(a, c("sd1", "sd2"))
    signed <- a$mean1 - a$mean2
    if (signed == 0) .os_ss_stop("zero mean difference has no finite required N")
  }
  if (a$design == "mean_paired") {
    .os_ss_required(a, "mean-diff")
    if (a$ratio != 1) .os_ss_stop("paired observations share biological units; ratio must be 1", "OS_INVALID_DESIGN")
    if (!is.null(a[["sd-diff"]])) {
      if (any(vapply(c("sd1", "sd2", "corr"), function(n) !is.null(a[[n]]), logical(1))))
        .os_ss_stop("give sd-diff or sd1/sd2/corr, not both", "OS_CONFLICTING_PARAMETERS")
    } else {
      .os_ss_required(a, c("sd1", "sd2", "corr")); .os_ss_number(a$corr, "corr", -1, 1, open = TRUE)
    }
    signed <- a[["mean-diff"]]
    if (signed == 0) .os_ss_stop("zero paired difference has no finite required N")
  }
  if (a$design == "prop_2sample") {
    .os_ss_required(a, c("p1", "p2"))
    .os_ss_number(a$p1, "p1", 0, 1, open = TRUE); .os_ss_number(a$p2, "p2", 0, 1, open = TRUE)
    signed <- a$p1 - a$p2
    if (signed == 0) .os_ss_stop("equal proportions have no finite required N")
  }
  if (a$design == "survival_logrank") {
    .os_ss_required(a, "hr"); signed <- log(a$hr)
    if (a$hr == 1) .os_ss_stop("HR 1 has no finite required event count")
    if (!is.null(a[["event-prob"]])) {
      .os_ss_number(a[["event-prob"]], "event-prob", 0, 1)
      if (a[["event-prob"]] == 0) .os_ss_stop("event probability must be positive")
    }
  }
  if (!is.null(signed) && a$sided == "one" &&
      ((a$direction == "group1-higher" && signed <= 0) ||
       (a$direction == "group1-lower" && signed >= 0)))
    .os_ss_stop("one-sided direction contradicts the stated group1-minus-group2 effect/HR", "OS_INVALID_DESIGN")
  list(groups = groups, grid = grid)
}

os_samplesize_engine <- function(a, power, port) {
  # Dispatch is copied from MedStat's run_design, restricted to the five requested
  # laboratory designs. No base-R fallback, alternate estimator or package mock.
  switch(a$design,
    mean_2sample = port$ss_mean_2sample(mean1 = a$mean1, mean2 = a$mean2, sd = a$sd,
      sd1 = a$sd1, sd2 = a$sd2, alpha = a$alpha, power = power, sided = a$sided, ratio = a$ratio),
    mean_paired = port$ss_mean_paired(mean_diff = a[["mean-diff"]], sd_diff = a[["sd-diff"]],
      sd1 = a$sd1, sd2 = a$sd2, corr = a$corr, alpha = a$alpha, power = power, sided = a$sided),
    anova = port$ss_anova(k = a$k, f = a$f,
      means = if (is.null(a$means)) NULL else .os_ss_list(a$means, "means", numeric = TRUE),
      sd = a$sd, alpha = a$alpha, power = power),
    prop_2sample = port$ss_prop_2sample(p1 = a$p1, p2 = a$p2, alpha = a$alpha,
      power = power, sided = a$sided, ratio = a$ratio),
    survival_logrank = port$ss_survival_logrank(hr = a$hr, alpha = a$alpha,
      power = power, sided = a$sided, ratio = a$ratio, event_prob = a[["event-prob"]]))
}

os_samplesize_group_table <- function(result, a, groups) {
  n <- if (a$design == "anova") rep(result$n1, length(groups)) else c(result$n1, result$n2)
  event_only <- a$design == "survival_logrank" && is.null(a[["event-prob"]])
  if ((!event_only && anyNA(n)) ||
      any(!is.na(n) & (!is.finite(n) | n < 1 | n != floor(n) | n > 2^53 - 1)))
    .os_ss_stop("native engine did not produce valid whole biological counts", "OS_INVALID_RESULT")
  recruit <- ceiling(n / (1 - a$dropout))
  measurements <- recruit * a[["technical-replicates"]]
  if (any(!is.na(measurements) & (!is.finite(measurements) | measurements > 2^53 - 1)))
    .os_ss_stop("recruitment/technical counts exceed exact binary64 integers", "OS_INVALID_RESULT")
  data.frame(group = groups, n_biological_analyzable = n,
    n_biological_recruit = recruit, technical_replicates_per_unit = a[["technical-replicates"]],
    planned_technical_measurements = measurements,
    independent_unit = a[["biological-unit"]],
    shared_units_across_conditions = a$design == "mean_paired", stringsAsFactors = FALSE)
}

omicstat_samplesize_compute <- function(a) {
  checked <- os_samplesize_validate(a)
  contract <- if (!is.null(a[["study-contract"]])) os_study_contract_read(a[["study-contract"]]) else list(sha256 = NULL)
  port <- os_samplesize_port()
  native <- lapply(checked$grid, function(p) tryCatch(os_samplesize_engine(a, p, port),
    error = function(e) {
      if (grepl("^OS_", conditionMessage(e))) stop(e)
      .os_ss_stop(paste("native planning computation failed:", conditionMessage(e)), "OS_CONVERGENCE")
    }))
  for (z in native) {
    count <- if (a$design == "survival_logrank" && is.null(a[["event-prob"]])) z$events else z$n_total
    if (length(count) != 1L || !is.finite(count) || count < 1 || count != floor(count))
      .os_ss_stop("native count is undefined or overflows its integer result", "OS_INVALID_RESULT")
  }
  selected <- native[[match(a$power, checked$grid)]]
  groups <- os_samplesize_group_table(selected, a, checked$groups)
  scenarios <- do.call(rbind, lapply(seq_along(native), function(i) {
    z <- native[[i]]; g <- os_samplesize_group_table(z, a, checked$groups)
    total_recruit <- if (a$design == "mean_paired") g$n_biological_recruit[1] else sum(g$n_biological_recruit)
    data.frame(target_power = checked$grid[i], n1 = z$n1, n2 = z$n2,
      n_biological_total = z$n_total, n_biological_recruit_total = total_recruit,
      required_events = z$events, selected_plan = checked$grid[i] == a$power)
  }))
  # A planning effect is not an estimated effect or a confidence interval.
  # Continuous contrast orientation is the exact groupcompare convention.
  effect_scale <- switch(a$design, mean_2sample = "mean_difference_group1_minus_group2",
    mean_paired = "mean_difference_group1_minus_group2", anova = "cohens_f",
    prop_2sample = "risk_difference_group1_minus_group2", survival_logrank = "hazard_ratio_group1_over_group2")
  effect <- switch(a$design, mean_2sample = a$mean1 - a$mean2,
    mean_paired = a[["mean-diff"]], anova = selected$effect$value,
    prop_2sample = a$p1 - a$p2, survival_logrank = a$hr)
  effects <- data.frame(term = if (a$design == "anova") "omnibus" else "planned_contrast",
    group1 = checked$groups[1], group2 = if (a$design == "anova") NA_character_ else checked$groups[2],
    estimate = effect, ci_low = NA_real_, ci_high = NA_real_, effect_scale = effect_scale,
    value_role = "prespecified_planning_assumption_not_estimated_effect",
    outcome_unit = a[["outcome-unit"]], standardized_effect_name = selected$effect$name,
    standardized_effect_value = selected$effect$value, stringsAsFactors = FALSE)
  original_qc <- port$run_qc_ss(list(design = a$design, dropout = a$dropout,
    effect_from_convention = (a$design == "anova" && !is.null(a$f)) ||
      a[["effect-source"]] == "standardized-convention",
    power = a$power, event_prob = a[["event-prob"]], ratio = a$ratio, alpha = a$alpha))
  method <- paste0("A priori sample-size planning used ", selected$engine, "; alpha=", a$alpha,
    ", target power=", a$power, ", direction=", a$direction, ". Biological n denotes ",
    a[["biological-unit"]], " (", a[["unit-description"]], "). The ", a[["technical-replicates"]],
    " technical repeats per unit do not increase biological n. Assumption source: ",
    a[["effect-source"]], "; ", a[["effect-rationale"]], ". Attrition-adjusted recruitment is reported separately",
    " from analyzable n and event requirements. No observed/post-hoc power was computed.",
    if (a$design == "mean_2sample")
      " This is equal-variance Student planning: two supplied SDs use the copied RMS pooling rule, not a Welch power calculation." else "")
  list(tables = list(plan = scenarios[scenarios$selected_plan, , drop = FALSE],
    biological_groups = groups, scenarios = scenarios, planning_effect = effects),
    metadata = list(design = a$design, groups = checked$groups, biological_unit = a[["biological-unit"]],
      unit_description = a[["unit-description"]], technical_replicates = a[["technical-replicates"]],
      technical_replicates_count_as_n = FALSE, independent_total = selected$n_total,
      planned_counts_not_observed_sample_counts = TRUE, original_qc = original_qc,
      native_engine = selected$engine, alpha = a$alpha, target_power = a$power,
      sided = a$sided, direction = a$direction, ratio = a$ratio, dropout = a$dropout,
      effect_source = a[["effect-source"]], effect_rationale = a[["effect-rationale"]],
      outcome_unit = a[["outcome-unit"]], journal = a$journal,
      ported_from = "TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/sample-size/",
      original_assumptions = selected$assumptions, contract_sha256 = contract$sha256),
    object = list(native_plan = selected, scenarios = native, planning_only = TRUE),
    # model_io's generic input field is bound to the actual study declaration;
    # there is intentionally no participant/animal-level outcome data input.
    input_files = list(input = a[["study-contract"]]),
    handoff_type = "development_sample_size_plan", ready = FALSE,
    packages = c(if (a$design == "survival_logrank") "gsDesign" else "pwr"), method = method)
}
