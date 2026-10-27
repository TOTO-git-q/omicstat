omicstat_groupcompare_compute <- function(a) {
 raw <- .os_read_delim(a$input)
 d <- os_basic_units(raw, a[["response-col"]], a[["group-col"]], a[["unit-col"]], a[["technical-policy"]], a[["technical-col"]])
 lv <- strsplit(a[["group-order"]], ",", fixed = TRUE)[[1]]
 d <- os_basic_design(d, a$design, lv)
 pair <- a[["pairwise-test"]]; omni <- a$omnibus; paired <- a$design == "paired"
 if (paired && (pair %in% c("welch", "student", "wilcoxon") || omni %in% c("anova", "welch-anova", "kruskal")))
  stop("OS_INVALID_DESIGN: independent test cannot analyze repeated units", call. = FALSE)
 if (!paired && (pair %in% c("paired-t", "paired-wilcoxon") || omni == "friedman"))
  stop("OS_INVALID_DESIGN: paired test requires paired design", call. = FALSE)
 is_rank <- pair %in% c("wilcoxon", "paired-wilcoxon")
 if ((is_rank && a[["rank-method"]] == "not-applicable") || (!is_rank && a[["rank-method"]] != "not-applicable"))
  stop("OS_CONFLICTING_PARAMETERS: rank-method must match the declared Wilcoxon test", call. = FALSE)
 cp <- data.frame(contrast = character(), group1 = character(), group2 = character())
 if (pair != "none") {
  if (is.null(a$comparisons)) stop("OS_MISSING_PARAMETER: pairwise test requires prespecified comparisons", call. = FALSE)
  cp <- .os_read_delim(a$comparisons); os_check_columns(cp, c("contrast", "group1", "group2"))
  if (anyNA(cp[c("contrast", "group1", "group2")]) || any(!nzchar(trimws(cp$contrast))) || anyDuplicated(cp$contrast) ||
      any(!cp$group1 %in% lv | !cp$group2 %in% lv | cp$group1 == cp$group2))
   stop("OS_INVALID_DESIGN: comparisons need unique labels and two distinct observed groups", call. = FALSE)
  keys <- vapply(seq_len(nrow(cp)), function(i) paste(sort(match(c(cp$group1[i], cp$group2[i]), lv)), collapse = "\r"), "")
  if (anyDuplicated(keys)) stop("OS_INVALID_DESIGN: duplicate or reversed duplicate comparison", call. = FALSE)
 } else if (!is.null(a$comparisons)) stop("OS_CONFLICTING_PARAMETERS: comparisons requires a pairwise test", call. = FALSE)
 ntests <- nrow(cp) + as.integer(omni != "none")
 if (!ntests || a[["family-size"]] < ntests) stop("OS_INVALID_DESIGN: family-size must cover every requested test", call. = FALSE)
 results <- list(); effects <- list()
 for (i in seq_len(nrow(cp))) {
  xx <- d[d$group == cp$group1[i], ]; yy <- d[d$group == cp$group2[i], ]
  if (paired) yy <- yy[match(xx$unit, yy$unit), ]
  x <- xx$value; y <- yy$value
  if (is_rank) {
   exact <- a[["rank-method"]] == "exact"
   if (exact && ((!paired && anyDuplicated(c(x, y))) || (paired && (any(x == y) || anyDuplicated(abs(x - y))))))
    stop("OS_INVALID_DESIGN: exact Wilcoxon unavailable with ties or zero differences; declare asymptotic explicitly", call. = FALSE)
   fit <- os_basic_test(stats::wilcox.test(x = x, y = y, alternative = "two.sided", mu = 0, paired = paired,
       exact = exact, correct = !exact, conf.int = FALSE, conf.level = a[["ci-level"]]))
  } else {
   fit <- os_basic_test(stats::t.test(x = x, y = y, alternative = "two.sided", mu = 0, paired = paired,
       var.equal = pair == "student", conf.level = a[["ci-level"]]))
   effects[[length(effects) + 1L]] <- data.frame(term = cp$contrast[i], group1 = cp$group1[i], group2 = cp$group2[i],
       estimate = mean(x) - mean(y), ci_low = fit$conf.int[1], ci_high = fit$conf.int[2],
       effect_scale = "mean_difference_group1_minus_group2", ci_level = a[["ci-level"]], ci_adjustment = "none_marginal", n1 = length(x), n2 = length(y))
  }
  results[[length(results) + 1L]] <- data.frame(contrast = cp$contrast[i], group1 = cp$group1[i], group2 = cp$group2[i],
   test = pair, statistic = unname(fit$statistic), df1 = if (length(fit$parameter)) unname(fit$parameter[1]) else NA_real_,
   df2 = NA_real_, p_value = fit$p.value, n_biological = if (paired) length(x) else length(x) + length(y))
 }
 if (omni != "none") {
  fit <- os_basic_test(if (omni %in% c("anova", "welch-anova")) stats::oneway.test(formula = value ~ group, data = d, var.equal = omni == "anova", na.action = stats::na.fail)
   else if (omni == "kruskal") stats::kruskal.test(x = split(d$value, d$group))
   else stats::friedman.test(y = matrix(d$value[order(d$group, d$unit)], nrow = length(unique(d$unit)), ncol = length(lv))))
  results[[length(results) + 1L]] <- data.frame(contrast = "omnibus", group1 = NA_character_, group2 = NA_character_, test = omni,
   statistic = unname(fit$statistic), df1 = unname(fit$parameter[1]), df2 = if (length(fit$parameter) > 1L) unname(fit$parameter[2]) else NA_real_,
   p_value = fit$p.value, n_biological = length(unique(d$unit)))
 }
 tests <- do.call(rbind, results)
 if (any(!is.finite(tests$p_value)) || any(tests$p_value < 0 | tests$p_value > 1)) stop("OS_INVALID_DESIGN: test undefined for supplied observations", call. = FALSE)
 tests$p_adjusted <- stats::p.adjust(p = tests$p_value, method = a$adjust, n = a[["family-size"]])
 tests$adjustment <- a$adjust; tests$family_size <- a[["family-size"]]
 summary <- do.call(rbind, lapply(lv, function(g) {x <- d$value[d$group == g]; data.frame(group = g, n_biological = length(x),
  mean = mean(x), sd = stats::sd(x), median = stats::median(x), min = min(x), max = max(x))}))
 tables <- list(tests = tests, summary = summary, biological_units = d)
 if (length(effects)) tables$effect_table <- do.call(rbind, effects)
 metadata <- list(design = a$design, biological_unit_column = a[["unit-col"]], technical_policy = a[["technical-policy"]],
  input_rows = nrow(raw), biological_observations = nrow(d), n_units = length(unique(d$unit)), group_order = lv,
  pairwise_test = pair, omnibus = omni, rank_method = a[["rank-method"]], adjustment = a$adjust, family_size = a[["family-size"]],
  ci_level = a[["ci-level"]], ci_adjustment = "none_marginal", response = a[["response-col"]], display = a$display, journal = a$journal)
 list(tables = tables, metadata = metadata, object = list(data = d, tests = tests), input_files = if (is.null(a$comparisons)) list() else list(comparisons = a$comparisons), handoff_type = "development_group_comparison",
  ready = FALSE, packages = c("stats"), method = paste("Prespecified", a$design, "biological-unit analysis; technical policy", a[["technical-policy"]],
    "; p-value family includes all declared tests; confidence intervals are marginal, not multiplicity-adjusted."))
}
