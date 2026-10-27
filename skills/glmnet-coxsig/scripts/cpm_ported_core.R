# Independently maintained OmicStat source-copy port. No MedStat runtime dependency.
# ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/cpm_core.R
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

cpm_validate_outcome_support <- function(task, dat, event_var, time_var = NULL) {
  y <- dat[[event_var]]
  u <- sort(unique(y[!is.na(y)]))
  if (!all(u %in% c(0, 1)) || length(u) != 2L) {
    stop(sprintf(
      "OS_INVALID_INPUT: %s outcome '%s' must contain both binary classes 0 and 1 on complete-case analysis rows; observed values were %s.",
      task, event_var, if (length(u)) paste(u, collapse = ",") else "none"), call. = FALSE)
  }
  if (identical(task, "prognostic")) {
    tm <- suppressWarnings(as.numeric(dat[[time_var]]))
    if (any(!is.finite(tm) | tm <= 0)) {
      stop("OS_INVALID_INPUT: prognostic complete-case follow-up times must be finite and > 0 before model fitting.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

cpm_sample_size <- function(task, n_predictors, assumed_source,
                             assumed_cstatistic = NA, prevalence = NA, shrinkage = 0.9,
                             rate = NA, timepoint = NA, meanfup = NA, csrsquared = NA) {
  if (!nzchar(assumed_source %||% "")) {
    stop(paste("OS_MISSING_PARAMETER: --sample-size-source is required (TRIPOD+AI item 10 requires the",
              "assumed C-statistic/R-squared to be traceable to a source; P2 sec 3)."), call. = FALSE)
  }
  if (identical(task, "diagnostic")) {
    if (is.na(prevalence)) stop("OS_MISSING_PARAMETER: --sample-size-prevalence is required for task=diagnostic.", call. = FALSE)
    if (is.na(assumed_cstatistic)) stop("OS_MISSING_PARAMETER: --sample-size-cstatistic is required for task=diagnostic.", call. = FALSE)
    res <- pmsampsize::pmsampsize(type = "b", parameters = n_predictors, shrinkage = shrinkage,
                                  prevalence = prevalence, cstatistic = assumed_cstatistic)
  } else if (identical(task, "prognostic")) {
    if (any(is.na(c(rate, timepoint, meanfup)))) {
      stop(paste("OS_MISSING_PARAMETER: task=prognostic sample size requires --sample-size-rate,",
                "--sample-size-timepoint, --sample-size-meanfup (event rate/time unit, prediction",
                "horizon, mean follow-up, all in the same time unit as --time-unit)."), call. = FALSE)
    }
    if (is.na(csrsquared)) {
      stop("OS_MISSING_PARAMETER: --sample-size-csrsquared (assumed Cox-Snell R-squared) is required for task=prognostic.", call. = FALSE)
    }
    res <- pmsampsize::pmsampsize(type = "s", parameters = n_predictors, shrinkage = shrinkage,
                                  rate = rate, timepoint = timepoint, meanfup = meanfup, csrsquared = csrsquared)
  } else {
    stop(sprintf("OS_INVALID_PARAMETER: unknown task '%s'.", task), call. = FALSE)
  }
  list(result = res, assumed_source = assumed_source,
       sample_size = res$sample_size, events = res$events %||% NA_real_,
       final_shrinkage = res$final_shrinkage, results_table = res$results_table)
}

cpm_harrell_c <- function(task, score, y_time = NULL, y_event = NULL, y_binary = NULL) {
  if (identical(task, "prognostic")) {
    rc <- Hmisc::rcorr.cens(-score, survival::Surv(y_time, y_event))
  } else {
    rc <- Hmisc::rcorr.cens(score, y_binary)
  }
  list(C = unname(rc["C Index"]), se = unname(rc["S.D."]) / 2, n = unname(rc["n"]))
}

cpm_citl <- function(task, lp, y_binary = NULL, y_time = NULL, y_event = NULL, horizon = NULL, surv_fn = NULL) {
  if (identical(task, "diagnostic")) {
    m <- stats::glm(y_binary ~ offset(lp), family = stats::binomial())
    list(kind = "citl_logit_intercept", value = unname(stats::coef(m)[1]), se = unname(summary(m)$coefficients[1, 2]))
  } else {
    observed <- 1 - summary(survival::survfit(survival::Surv(y_time, y_event) ~ 1), times = horizon)$surv
    observed <- observed[1] %||% NA_real_
    expected <- mean(1 - surv_fn(horizon, lp), na.rm = TRUE)
    list(kind = "oe_ratio", value = observed / expected, observed = observed, expected = expected)
  }
}

cpm_cal_slope <- function(task, lp, dat, y_binary_col = NULL, time_var = NULL, event_var = NULL) {
  if (identical(task, "diagnostic")) {
    m <- stats::glm(dat[[y_binary_col]] ~ lp, family = stats::binomial())
    cf <- summary(m)$coefficients
    list(slope = unname(cf[2, 1]), se = unname(cf[2, 2]))
  } else {
    m <- survival::coxph(survival::Surv(dat[[time_var]], dat[[event_var]]) ~ lp)
    cf <- summary(m)$coefficients
    list(slope = unname(cf[1, 1]), se = unname(cf[1, "se(coef)"]))
  }
}

.cpm_validate_custom <- function(dat, predictors, B, seed, fit_and_eval, apparent, ci_alpha = 0.05) {
  set.seed(seed)
  n <- nrow(dat)

  # Explicit OmicStat adaptation: the caller refits the existing penalized pipeline,
  # rather than the source unpenalized rms refit. No apparent slope is assumed.
  .fit_and_eval <- fit_and_eval

  app <- apparent
  apparent_C <- app$c_apparent
  apparent_slope <- app$slope_apparent

  opt_c <- numeric(0); opt_slope <- numeric(0); n_sel <- integer(0); n_fail <- 0L
  # Per-predictor bootstrap inclusion count (Table 5's "bootstrap inclusion
  # frequency" column, build spec sec 12 -- previously computed nowhere):
  # tallied over the SAME successful resamples opt_c/opt_slope use, from the
  # selection step .fit_and_eval() already re-runs inside the loop.
  incl_count <- stats::setNames(integer(length(predictors)), predictors)
  attempts <- list()
  for (b in seq_len(B)) {
    idx <- sample.int(n, n, replace = TRUE)
    boot <- dat[idx, , drop = FALSE]
    failure <- NULL
    res <- tryCatch(.fit_and_eval(boot, dat), error = function(e) { failure <<- conditionMessage(e); NULL })
    measures <- if (is.null(res)) numeric() else c(res$c_apparent, res$c_test, res$slope_apparent, res$slope_test)
    valid <- length(measures) == 4L && all(is.finite(measures))
    attempts[[b]] <- data.frame(replicate = b, n_draws = n, n_unique_subjects = length(unique(idx)),
      success = valid, reason = if (!valid) if (is.null(failure)) "nonfinite performance" else failure else "",
      c_apparent = if (valid) res$c_apparent else NA_real_, c_test = if (valid) res$c_test else NA_real_,
      slope_apparent = if (valid) res$slope_apparent else NA_real_, slope_test = if (valid) res$slope_test else NA_real_, stringsAsFactors = FALSE)
    if (!valid) {
      message(sprintf("Bootstrap replicate %d/%d failed: %s", b, B, attempts[[b]]$reason))
      n_fail <- n_fail + 1L; next
    }
    opt_c <- c(opt_c, res$c_apparent - res$c_test)
    opt_slope <- c(opt_slope, res$slope_apparent - res$slope_test)
    n_sel <- c(n_sel, res$n_selected)
    incl_count[res$selected] <- incl_count[res$selected] + 1L
  }
  if (!length(opt_c)) stop("OS_INVALID_RESULT: every bootstrap resample failed to fit/evaluate; check predictor variance and B.", call. = FALSE)
  # Percentile CI for the corrected estimate: each replicate's own
  # apparent-minus-that-replicate's-optimism gives one draw from the
  # corrected-C distribution; a plain bootstrap-percentile interval over
  # those draws (not Harrell's own analytic CI, which this hand-rolled
  # engine does not reproduce) -- adequate for reporting, disclosed as such
  # in tables/performance.md's footnote. The SAME construction gives a
  # percentile CI for the corrected calibration slope (P2/acceptance
  # finding: this row had no CI at all before).
  corrected_c_reps <- apparent_C - opt_c
  ci <- stats::quantile(corrected_c_reps, c(ci_alpha / 2, 1 - ci_alpha / 2), na.rm = TRUE, names = FALSE)
  corrected_slope_reps <- apparent_slope - opt_slope
  slope_ci <- stats::quantile(corrected_slope_reps, c(ci_alpha / 2, 1 - ci_alpha / 2), na.rm = TRUE, names = FALSE)
  inclusion_freq <- 100 * incl_count / length(opt_c)
  list(apparent_C = apparent_C, optimism_C = mean(opt_c), corrected_C = apparent_C - mean(opt_c),
       ci_low = ci[1], ci_high = ci[2],
       apparent_slope = apparent_slope, optimism_slope = mean(opt_slope),
       corrected_slope = apparent_slope - mean(opt_slope),
       slope_ci_low = slope_ci[1], slope_ci_high = slope_ci[2],
       inclusion_freq = inclusion_freq,
       B_used = length(opt_c), B_failed = n_fail, mean_n_selected = mean(n_sel),
       B_requested = B, attempts = do.call(rbind, attempts),
       engine = "source-derived Harrell optimism loop; penalized glmnet selection-in-loop; source percentile construction, not an independently validated CI")
}

cpm_z_ci <- function(estimate, se, alpha = 0.05) {
  z <- stats::qnorm(1 - alpha / 2)
  c(low = unname(estimate - z * se), high = unname(estimate + z * se))
}

cpm_external_eval <- function(fit, task, ext_dat, time_var = NULL, event_var, horizon = NULL, ci_alpha = 0.05, lp_predict, surv_fn) {
  lp <- lp_predict(fit, ext_dat)
  if (identical(task, "prognostic")) {
    c_ext <- cpm_harrell_c(task, lp, y_time = ext_dat[[time_var]], y_event = ext_dat[[event_var]])
    slope_ext <- cpm_cal_slope(task, lp, ext_dat, time_var = time_var, event_var = event_var)
    sfn <- surv_fn
    p_ext <- 1 - sfn(horizon[1], lp)
    citl_ext <- cpm_citl(task, lp, y_time = ext_dat[[time_var]], y_event = ext_dat[[event_var]],
                         horizon = horizon[1], surv_fn = sfn)
  } else {
    c_ext <- cpm_harrell_c(task, lp, y_binary = ext_dat[[event_var]])
    slope_ext <- cpm_cal_slope(task, lp, ext_dat, y_binary_col = event_var)
    p_ext <- 1 / (1 + exp(-lp))
    citl_ext <- cpm_citl(task, lp, y_binary = ext_dat[[event_var]])
  }
  # Real CI on the external calibration slope, from the SAME refit's own SE
  # (cpm_cal_slope() now returns list(slope, se) for exactly this) -- P2/
  # acceptance finding: this row's ci_low/ci_high were NA in
  # tables/performance.csv even though build spec sec 12 Table 3 requires a
  # CI on every performance metric, and the SE was already computed and then
  # discarded by the OLD bare-numeric cpm_cal_slope().
  slope_ci <- cpm_z_ci(slope_ext$slope, slope_ext$se, alpha = ci_alpha)
  list(C = c_ext, slope = slope_ext$slope,
      slope_ci_low = unname(slope_ci["low"]), slope_ci_high = unname(slope_ci["high"]),
      citl = citl_ext, risk = p_ext, lp = lp,
      n = nrow(ext_dat), n_events = sum(ext_dat[[event_var]] == 1, na.rm = TRUE))
}
