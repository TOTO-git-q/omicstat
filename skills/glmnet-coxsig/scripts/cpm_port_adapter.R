# P0-13 B4: source-derived workup around the existing penalized signature.
# No MedStat environment, model refit substitution, package installation or promotion.
.os_cxs_port <- local({
 files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
 here <- dirname(normalizePath(tail(files[nzchar(files)], 1), mustWork = TRUE))
 e <- new.env(parent = baseenv())
 e$offset <- stats::offset
 for (name in c("core", "binned", "qc")) sys.source(file.path(here, paste0("cpm_ported_", name, ".R")), envir = e)
 e
})

os_cxs_workup_flags <- function() c("dataset-name", "planning-source", "planning-parameters", "planning-cs-r2",
 "planning-shrinkage", "planning-rate", "planning-horizon", "planning-mean-followup", "bootstrap-B",
 "bootstrap-seed", "bootstrap-fit-policy", "baseline-estimator", "calibration-horizon", "calibration-min-bin",
 "calibration-max-bins", "calibration-slope-fit")
os_cxs_require <- function(a, names) {
 missing <- names[vapply(names, function(k) is.null(a[[k]]) || !length(a[[k]]), logical(1))]
 if (length(missing)) stop(paste("OS_MISSING_PARAMETER: explicitly declare", paste(paste0("--", missing), collapse = ", ")), call. = FALSE)
 invisible(TRUE)
}
os_cxs_scalar <- function(x, lower = -Inf, upper = Inf, integer = FALSE) {
 is.numeric(x) && length(x) == 1L && is.finite(x) && x >= lower && x <= upper && (!integer || x == floor(x))
}
os_cxs_workup_contract <- function(a) {
 os_cxs_require(a, "dataset-name")
 if (!is.character(a[["dataset-name"]]) || length(a[["dataset-name"]]) != 1L ||
     !nzchar(trimws(a[["dataset-name"]])) || nchar(a[["dataset-name"]]) > 160L || grepl("[\r\n]", a[["dataset-name"]]))
  stop("OS_INVALID_PARAMETER: one dataset label of at most160 characters is required", call. = FALSE)
 if (a$mode == "validate") {
  fields <- setdiff(os_cxs_workup_flags(), "dataset-name")
  if (any(vapply(fields, function(k) !is.null(a[[k]]), logical(1)))) stop("OS_CONFLICTING_PARAMETERS: external workup consumes frozen training planning/horizon/bin/baseline settings; no new training or calibration policy", call. = FALSE)
  return(invisible(TRUE))
 }
 os_cxs_require(a, os_cxs_workup_flags())
 if (!is.character(a[["planning-source"]]) || length(a[["planning-source"]]) != 1L || !nzchar(trimws(a[["planning-source"]])))
  stop("OS_INVALID_PARAMETER: planning assumptions need an explicit prior source; no derivation from the fitted cohort", call. = FALSE)
 if (!os_cxs_scalar(a[["planning-parameters"]], 1, integer = TRUE) ||
     !os_cxs_scalar(a[["planning-cs-r2"]], 0, 1) || a[["planning-cs-r2"]] <= 0 ||
     !os_cxs_scalar(a[["planning-shrinkage"]], 0, 1) || a[["planning-shrinkage"]] <= 0 || a[["planning-shrinkage"]] >= 1 ||
     a[["planning-cs-r2"]] >= a[["planning-shrinkage"]]) stop("OS_INVALID_PARAMETER: finite positive candidate parameter count and0<R2<shrinkage<1 required", call. = FALSE)
 for (k in c("planning-rate", "planning-horizon", "planning-mean-followup", "calibration-horizon"))
  if (!os_cxs_scalar(a[[k]], 0) || a[[k]] <= 0) stop("OS_INVALID_PARAMETER: positive finite rate and common-unit planning/calibration times required", call. = FALSE)
 if (!identical(as.numeric(a[["planning-horizon"]]), as.numeric(a[["calibration-horizon"]])))
  stop("OS_INVALID_PARAMETER: Riley planning horizon must be the declared primary calibration horizon in the same time units", call. = FALSE)
 if (!os_cxs_scalar(a[["bootstrap-B"]], 200, integer = TRUE)) stop("OS_INVALID_PARAMETER: preserve the source project floor of at least200 requested bootstrap replicates", call. = FALSE)
 if (a[["bootstrap-B"]] > 2000L) stop("OS_RESOURCE_LIMIT: this serial candidate supports at most2000 requested replicates; no silent reduction. Use a separately validated larger-budget workflow", call. = FALSE)
 if (!os_cxs_scalar(a[["bootstrap-seed"]], 0, .Machine$integer.max, integer = TRUE)) stop("OS_INVALID_PARAMETER: explicit reproducible bootstrap seed required", call. = FALSE)
 if (!identical(a[["bootstrap-fit-policy"]], "penalized-pipeline") ||
     !identical(a[["baseline-estimator"]], "frozen-offset-breslow") ||
     !identical(a[["calibration-slope-fit"]], "source-native")) stop("OS_INVALID_PARAMETER: acknowledge penalized pipeline refits, frozen offset-Breslow baseline and the separate source-native calibration-slope diagnostic", call. = FALSE)
 if (!os_cxs_scalar(a[["calibration-min-bin"]], 10, integer = TRUE) || !os_cxs_scalar(a[["calibration-max-bins"]], 1, 10, integer = TRUE))
  stop("OS_INVALID_PARAMETER: calibration bins require at least10 original subjects and one to ten requested bins", call. = FALSE)
 invisible(TRUE)
}
os_cxs_workup_packages <- function(training) {
 for (pkg in c("survival", "Hmisc", if (training) "pmsampsize"))
  if (!requireNamespace(pkg, quietly = TRUE)) stop(paste0("OS_MISSING_PACKAGE: ", pkg, " is required for this independent workup; retain the exact environment blocker, do not substitute or install here"), call. = FALSE)
 if (training && !identical(utils::packageDescription("pmsampsize")$Version, "1.1.3"))
  stop("OS_PACKAGE_VERSION: pmsampsize must match the independently verified source version1.1.3; no installation or substitution is attempted", call. = FALSE)
 invisible(TRUE)
}
os_cxs_stable_fit <- function(expr) {
 withCallingHandlers(expr, warning = function(w) {
  if (grepl("infinite|did not converge|failed to converge|convergence", conditionMessage(w), ignore.case = TRUE))
   stop(paste("OS_INVALID_RESULT: unstable native calibration/baseline fit:", conditionMessage(w)), call. = FALSE)
 })
}

# Training-only baseline at fixed supplied coefficients; no coefficient optimization.
os_cxs_fit_baseline <- function(d, lp) {
 dd <- data.frame(.time = d$time, .event = d$event, .lp = lp)
 fit <- os_cxs_stable_fit(survival::coxph(formula = survival::Surv(.time, .event) ~ offset(.lp), data = dd,
   ties = "breslow", x = TRUE, y = TRUE, model = TRUE, na.action = stats::na.fail))
 if (length(stats::coef(fit))) stop("OS_INVALID_RESULT: offset-only baseline must not estimate any prediction coefficient", call. = FALSE)
 sf <- survival::survfit(formula = fit, newdata = data.frame(.lp = 0), se.fit = FALSE, conf.type = "none", stype = 2, ctype = 1)
 time <- as.numeric(sf$time); hazard <- as.numeric(sf$cumhaz)
 if (!length(time) || length(hazard) != length(time) || any(!is.finite(time) | time <= 0) || any(!is.finite(hazard) | hazard < 0) ||
     any(diff(time) <= 0) || any(diff(hazard) < 0)) stop("OS_INVALID_RESULT: invalid training-only Breslow baseline", call. = FALSE)
 list(schema = "omicstat.cox-baseline.v1", estimator = "offset-only Breslow at linear predictor0",
  time = time, cumulative_hazard = hazard, max_followup = max(d$time), n_training = nrow(d), events_training = sum(d$event),
  ties = "breslow", coefficient_refitted = FALSE)
}
os_cxs_survival <- function(baseline, horizon, lp) {
 if (!os_cxs_scalar(horizon, 0) || horizon <= 0 || horizon > baseline$max_followup || any(!is.finite(lp)))
  stop("OS_INVALID_PARAMETER: fixed prediction horizon must be within training support and predictors finite", call. = FALSE)
 index <- findInterval(horizon, baseline$time)
 hazard <- if (index == 0L) 0 else baseline$cumulative_hazard[index]
 if (hazard == 0) return(rep(1, length(lp)))
 # Equivalent to exp(-H0*exp(lp)), evaluated without the zero-times-infinity case.
 value <- exp(-exp(log(hazard) + lp))
 if (any(!is.finite(value) | value < 0 | value > 1)) stop("OS_INVALID_RESULT: nonfinite frozen survival probability", call. = FALSE)
 value
}
os_cxs_workup_digest <- function(signature, workup) {
 workup$sha256 <- NULL
 frozen_signature <- signature
 frozen_signature$cpm_workup <- NULL
 # Bind all original fields, including training expression SHA, package version,
 # coefficient scale, ties and any future source fields, without recursive hashes.
 digest::digest(list(signature = frozen_signature, workup = workup), algo = "sha256")
}
os_cxs_validate_frozen_workup <- function(signature) {
 w <- signature$cpm_workup
 if (!is.list(w) || !identical(w$schema, "omicstat.cox-workup.v1") || !is.character(w$sha256) || length(w$sha256) != 1L ||
     !identical(w$sha256, os_cxs_workup_digest(signature, w))) stop("OS_HANDOFF_MISMATCH: exact frozen coefficient/baseline/workup binding is required", call. = FALSE)
 b <- w$baseline
 if (!is.list(b) || !identical(b$schema, "omicstat.cox-baseline.v1") || !identical(b$ties, "breslow") || !identical(b$coefficient_refitted, FALSE) ||
     !is.numeric(b$time) || !length(b$time) || !is.numeric(b$cumulative_hazard) || length(b$time) != length(b$cumulative_hazard) ||
     any(!is.finite(b$time) | b$time <= 0) || any(diff(b$time) <= 0) || any(!is.finite(b$cumulative_hazard) | b$cumulative_hazard < 0) ||
     any(diff(b$cumulative_hazard) < 0) || !os_cxs_scalar(b$max_followup, max(b$time)) ||
     !os_cxs_scalar(w$horizon, 0, b$max_followup) || w$horizon <= 0 ||
     !os_cxs_scalar(w$min_bin, 10, integer = TRUE) || !os_cxs_scalar(w$max_bins, 1, 10, integer = TRUE) ||
     !identical(w$prediction_model, "original penalized glmnet signature")) stop("OS_HANDOFF_MISMATCH: malformed frozen calibration settings or baseline", call. = FALSE)
 w
}

# This repeats the current model's training call, never the source rms refit.
# Original biological folds are inherited by every copy of one resampled subject.
os_cxs_boot_fit <- function(train, test, genes, a) {
 X <- as.matrix(train[genes]); Y <- as.matrix(test[genes]); folds <- train$.fold
 k <- max(test$.fold)
 unique_train <- train[!duplicated(train$.source_row), , drop = FALSE]
 if (!setequal(unique(folds), seq_len(k)) || k < 3L || k > 20L ||
     any(table(unique_train$.fold) < 5L) || any(tapply(unique_train$event, unique_train$.fold, sum) < 2L))
  stop("OS_INVALID_DESIGN: bootstrap holdout folds need the original biological-unit and event support; repeated draws do not create new independent subjects", call. = FALSE)
 if (any(!is.finite(X)) || any(vapply(seq_len(ncol(X)), function(i) stats::sd(X[, i]) <= 0, logical(1))))
  stop("OS_INVALID_DESIGN: bootstrap predictors must retain variance; no variable deletion or replacement replicate", call. = FALSE)
 cv <- glmnet::cv.glmnet(x = X, y = survival::Surv(train$time, train$event), family = "cox", alpha = 1,
  nfolds = k, foldid = folds, type.measure = a[["cv-measure"]], grouped = a[["cv-grouped"]] == "true",
  alignment = "lambda", keep = TRUE, parallel = FALSE, relax = FALSE, standardize = a$standardize == "true",
  nlambda = a$nlambda, lambda.min.ratio = a[["lambda-min-ratio"]], control = list(thresh = a$thresh, maxit = a[["max-iter"]]), cox.ties = "breslow")
 if (cv$glmnet.fit$jerr != 0L || any(!is.finite(cv$cvm))) stop("OS_INVALID_DESIGN: failed bootstrap glmnet path or CV", call. = FALSE)
 lambda <- if (a$selection == "fixed") a$lambda else cv[[a$selection]]
 if (!os_cxs_scalar(lambda, min(cv$lambda), max(cv$lambda))) stop("OS_INVALID_PARAMETER: bootstrap penalty outside its own fitted path; no extrapolation", call. = FALSE)
 beta <- as.numeric(stats::coef(cv$glmnet.fit, s = lambda)); names(beta) <- genes
 if (length(beta) != ncol(X) || any(!is.finite(beta))) stop("OS_INVALID_RESULT: invalid bootstrap penalized coefficients", call. = FALSE)
 lp_train <- as.numeric(X %*% beta); lp_test <- as.numeric(Y %*% beta)
 c_train <- .os_cxs_port$cpm_harrell_c("prognostic", lp_train, y_time = train$time, y_event = train$event)$C
 c_test <- .os_cxs_port$cpm_harrell_c("prognostic", lp_test, y_time = test$time, y_event = test$event)$C
 s_train <- os_cxs_stable_fit(.os_cxs_port$cpm_cal_slope("prognostic", lp_train, train, time_var = "time", event_var = "event"))
 s_test <- os_cxs_stable_fit(.os_cxs_port$cpm_cal_slope("prognostic", lp_test, test, time_var = "time", event_var = "event"))
 list(c_apparent = c_train, c_test = c_test, slope_apparent = s_train$slope, slope_test = s_test$slope,
  n_selected = sum(beta != 0), selected = genes[beta != 0], lambda = lambda)
}
os_cxs_bin_accounting <- function(p, d, horizon, min_n, max_bins, alpha) {
 if (length(p) != nrow(d) || any(!is.finite(p) | p < 0 | p > 1) || any(!is.finite(d$time) | d$time <= 0) ||
     anyNA(d$event) || !all(d$event %in% c(0, 1))) stop("OS_INVALID_INPUT: invalid calibration data cannot be silently filtered", call. = FALSE)
 shown <- .os_cxs_port$cpm_calibration_binned(p, d$event, time = d$time, horizon = horizon, min_n = min_n, max_bins = max_bins, alpha = alpha)
 n <- length(p); k <- min(as.integer(max_bins), n %/% min_n)
 accounting <- data.frame(bin = integer(), n = integer(), displayed = logical(), reason = character())
 if (k) {
  ord <- order(p, seq_along(p)); groups <- pmin(k, floor((seq_len(n) - 1L) * k / n) + 1L)
  accounting <- do.call(rbind, lapply(seq_len(k), function(g) {
   rows <- ord[groups == g]; show <- g %in% shown$bin
   data.frame(bin = g, n = length(rows), displayed = show, reason = if (show) "" else if (max(d$time[rows]) < horizon) "horizon beyond bin follow-up; no extrapolation" else "source KM estimate or interval not finite; no fabricated interval", stringsAsFactors = FALSE)
  }))
 }
 list(table = shown, accounting = accounting, n_input = n, n_displayed = sum(shown$n), n_omitted = n - sum(shown$n),
  no_bins_reason = if (!k) "fewer original subjects than the declared minimum bin size" else if (!nrow(shown)) "all bins have unsupported/nonfinite horizon estimates" else "")
}

os_cxs_workup_compute <- function(a) {
 mode <- if (is.null(a[["prediction-workup"]])) "none" else a[["prediction-workup"]]
 if (identical(mode, "none")) {
  if (any(vapply(os_cxs_workup_flags(), function(k) !is.null(a[[k]]), logical(1)))) stop("OS_INVALID_PARAMETER: workup flags require explicit prediction-workup=cpm", call. = FALSE)
  return(glmnet_coxsig_compute_legacy(a))
 }
 if (!identical(mode, "cpm")) stop("OS_INVALID_PARAMETER: unknown prediction workup", call. = FALSE)
 os_cxs_workup_contract(a); os_cxs_workup_packages(a$mode == "train")
 res <- glmnet_coxsig_compute_legacy(a)
 inp <- os_survival_input(a, allow_constant = a$mode == "validate"); d <- inp$clinical; genes <- res$object$genes
 .os_cxs_port$cpm_validate_outcome_support("prognostic", d, "event", "time")
 lp <- as.numeric(res$tables$scores$linear_predictor); signature <- res$object
 alpha <- 1 - a[["ci-level"]]
 if (a$mode == "train") {
  if (a[["planning-parameters"]] < length(genes)) stop("OS_INVALID_PARAMETER: Riley parameters must cover every prespecified candidate gene, never just the selected nonzero coefficients", call. = FALSE)
  horizon <- a[["calibration-horizon"]]
  if (horizon > max(d$time)) stop("OS_INVALID_PARAMETER: calibration horizon exceeds observed training follow-up", call. = FALSE)
  ss <- .os_cxs_port$cpm_sample_size("prognostic", a[["planning-parameters"]], a[["planning-source"]],
   shrinkage = a[["planning-shrinkage"]], rate = a[["planning-rate"]], timepoint = a[["planning-horizon"]],
   meanfup = a[["planning-mean-followup"]], csrsquared = a[["planning-cs-r2"]])
  if (!os_cxs_scalar(ss$sample_size, 1)) stop("OS_INVALID_RESULT: nonfinite Riley sample-size result", call. = FALSE)
  baseline <- os_cxs_fit_baseline(d, lp)
  foldtab <- utils::read.csv(a$folds, colClasses = "character", check.names = FALSE)
  bootdata <- data.frame(d, .source_row = seq_len(nrow(d)), .fold = as.integer(foldtab$fold[match(d$unit, foldtab$unit)]), check.names = FALSE)
  if (any(genes %in% c(names(d), ".source_row", ".fold"))) stop("OS_INVALID_DESIGN: gene IDs collide with internal validation columns; use an explicitly mapped feature naming scheme", call. = FALSE)
  for (gene in genes) bootdata[[gene]] <- as.numeric(inp$E[gene, ])
  c_app <- .os_cxs_port$cpm_harrell_c("prognostic", lp, y_time = d$time, y_event = d$event)
  slope_app <- os_cxs_stable_fit(.os_cxs_port$cpm_cal_slope("prognostic", lp, d, time_var = "time", event_var = "event"))
  if (any(!is.finite(c(c_app$C, c_app$se, slope_app$slope, slope_app$se)))) stop("OS_INVALID_RESULT: undefined apparent discrimination/calibration slope", call. = FALSE)
  bootstrap <- .os_cxs_port$.cpm_validate_custom(bootdata, genes, B = a[["bootstrap-B"]], seed = a[["bootstrap-seed"]],
   fit_and_eval = function(train, test) os_cxs_boot_fit(train, test, genes, a),
   apparent = list(c_apparent = c_app$C, slope_apparent = slope_app$slope), ci_alpha = alpha)
  criteria <- as.data.frame(ss$results_table, check.names = FALSE)
  res$tables$planning_criteria <- data.frame(criterion = rownames(criteria), criteria, row.names = NULL, check.names = FALSE)
  res$tables$planning_summary <- data.frame(n_original = nrow(d), events_original = sum(d$event), required_n = ss$sample_size,
   required_events = ss$events, final_shrinkage = ss$final_shrinkage,
   planned_parameters = a[["planning-parameters"]], candidate_genes = length(genes), selected_nonzero = sum(signature$coefficients != 0),
   anticipated_cs_r2 = a[["planning-cs-r2"]], target_shrinkage = a[["planning-shrinkage"]], prior_event_rate = a[["planning-rate"]],
   prediction_horizon = horizon, prior_mean_followup = a[["planning-mean-followup"]], source = a[["planning-source"]],
   assumptions_estimated_from_analysis = FALSE, stringsAsFactors = FALSE)
  res$tables$bootstrap_attempts <- bootstrap$attempts
  res$tables$bootstrap_inclusion <- data.frame(gene = names(bootstrap$inclusion_freq), inclusion_percent = as.numeric(bootstrap$inclusion_freq),
   successful_replicates = bootstrap$B_used, requested_replicates = bootstrap$B_requested)
  res$tables$internal_validation <- data.frame(metric = c("Harrell C", "calibration slope"),
   apparent = c(bootstrap$apparent_C, bootstrap$apparent_slope), optimism = c(bootstrap$optimism_C, bootstrap$optimism_slope),
   corrected = c(bootstrap$corrected_C, bootstrap$corrected_slope), lower = c(bootstrap$ci_low, bootstrap$slope_ci_low),
   upper = c(bootstrap$ci_high, bootstrap$slope_ci_high), interval_method = "source percentile of apparent minus replicate optimism; uncertainty validity not established for this penalized adaptation",
   successful_replicates = bootstrap$B_used, failed_replicates = bootstrap$B_failed, requested_replicates = bootstrap$B_requested,
   stringsAsFactors = FALSE)
  w <- list(schema = "omicstat.cox-workup.v1", prediction_model = "original penalized glmnet signature", baseline = baseline,
   horizon = horizon, min_bin = a[["calibration-min-bin"]], max_bins = a[["calibration-max-bins"]], planning = res$tables$planning_summary,
   bootstrap_B_requested = bootstrap$B_requested, bootstrap_B_used = bootstrap$B_used, bootstrap_B_failed = bootstrap$B_failed,
   calibration_slope_fit = "source-native Cox diagnostic; coefficients are not updated",
   source_native_package = list(survival = as.character(utils::packageVersion("survival")), Hmisc = as.character(utils::packageVersion("Hmisc")), pmsampsize = as.character(utils::packageVersion("pmsampsize"))),
   source_native_description_versions = list(survival = utils::packageDescription("survival")$Version,
    Hmisc = utils::packageDescription("Hmisc")$Version, pmsampsize = utils::packageDescription("pmsampsize")$Version),
   native_formals = list(coxph = paste(deparse(formals(survival::coxph)), collapse = "\n"),
    pmsampsize = paste(deparse(formals(pmsampsize::pmsampsize)), collapse = "\n"),
    rcorr_cens = paste(deparse(formals(Hmisc::rcorr.cens)), collapse = "\n")))
  w$sha256 <- os_cxs_workup_digest(signature, w); signature$cpm_workup <- w; res$object <- signature
  res$tables$baseline_hazard <- data.frame(time = baseline$time, cumulative_hazard_at_lp0 = baseline$cumulative_hazard)
 } else {
  w <- os_cxs_validate_frozen_workup(signature); horizon <- w$horizon
  if (horizon > max(d$time)) stop("OS_INVALID_PARAMETER: frozen calibration horizon exceeds external follow-up; do not refit or move it", call. = FALSE)
 }
 # Source external-evaluation helper is used on the declared evaluation cohort.
 # Diagnostic slope regression never writes back to the frozen prediction object.
 before <- digest::digest(signature, algo = "sha256")
 eval_data <- data.frame(d, check.names = FALSE)
 if (any(genes %in% names(d))) stop("OS_INVALID_DESIGN: feature identity collides with evaluation columns", call. = FALSE)
 for (gene in genes) eval_data[[gene]] <- as.numeric(inp$E[gene, ])
 evaluated <- os_cxs_stable_fit(.os_cxs_port$cpm_external_eval(signature, "prognostic", eval_data, time_var = "time", event_var = "event", horizon = horizon, ci_alpha = alpha,
  lp_predict = function(fit, newdata) as.numeric(as.matrix(newdata[fit$genes]) %*% fit$coefficients),
  surv_fn = function(time, score) os_cxs_survival(w$baseline, time, score)))
 if (!identical(before, digest::digest(signature, algo = "sha256")) || !identical(w$sha256, os_cxs_workup_digest(signature, w)))
  stop("OS_RESULT_INCONSISTENT: prediction coefficients or training baseline changed during evaluation", call. = FALSE)
 if (!isTRUE(all.equal(lp, evaluated$lp, tolerance = 0)) || any(!is.finite(c(evaluated$C$C, evaluated$slope, evaluated$slope_ci_low,
     evaluated$slope_ci_high, evaluated$citl$value, evaluated$risk)))) stop("OS_INVALID_RESULT: invalid or inconsistent frozen-cohort performance", call. = FALSE)
 bins <- os_cxs_bin_accounting(evaluated$risk, d, horizon, w$min_bin, w$max_bins, alpha)
 res$tables$calibration_binned <- bins$table; res$tables$calibration_bin_accounting <- bins$accounting
 res$tables$calibration_performance <- data.frame(evaluation = a$mode, n_original = nrow(d), events_original = sum(d$event),
  horizon = horizon, harrell_C = evaluated$C$C, calibration_slope = evaluated$slope,
  slope_ci_low = evaluated$slope_ci_low, slope_ci_high = evaluated$slope_ci_high, ci_level = a[["ci-level"]],
  observed_expected_ratio = evaluated$citl$value, observed_KM_risk = evaluated$citl$observed, mean_frozen_predicted_risk = evaluated$citl$expected,
  prediction_model_refitted = FALSE, stringsAsFactors = FALSE)
 res$metadata$prediction_workup <- "cpm"; res$metadata$dataset_name <- a[["dataset-name"]]
 res$metadata$cpm_workup <- list(horizon = horizon, workup_sha256 = w$sha256, planning_assumptions_frozen_from_training = TRUE,
  baseline_fitted_in_this_run = a$mode == "train", prediction_model_refitted_for_calibration = FALSE,
  baseline_estimator = w$baseline$estimator, n_original = nrow(d), n_displayed_bins = nrow(bins$table),
  n_bin_subjects_displayed = bins$n_displayed, n_bin_subjects_omitted = bins$n_omitted, no_bins_reason = bins$no_bins_reason,
  min_bin = w$min_bin, max_bins = w$max_bins, calibration_scope = if (a$mode == "train") "apparent training calibration; not the optimism-corrected curve" else "independent external cohort with frozen coefficients and baseline",
  calibration_slope_fit = w$calibration_slope_fit, bootstrap_B_requested = w$bootstrap_B_requested,
  bootstrap_B_used = w$bootstrap_B_used, bootstrap_B_failed = w$bootstrap_B_failed,
  original_source_model_equivalence = FALSE, native_validation_pending = TRUE)
 res$packages <- unique(c(res$packages, "Hmisc", if (a$mode == "train") "pmsampsize"))
 res$method <- c(res$method,
  "P0-13B4 source-copy adaptation keeps the original penalized glmnet prediction model. Source CPM instead selected variables then refitted without penalty; numeric equivalence is not claimed.",
  "Riley sample-size assumptions are explicitly supplied prior values and count all candidate genes, not selected coefficients. Missing exact environment dependencies remain blockers.",
  "Training internal validation repeats the declared penalty selection and fit in each bootstrap resample. Duplicates of one subject stay in the same original CV fold. All failed replicates are counted, never replaced; apparent slopes are measured, not fixed to1.",
  "The source optimism percentile construction is retained and labelled; it is not an independently validated uncertainty method for the penalized adaptation. Raw apparent, optimism and corrected quantities remain separate.",
  "Calibration uses a frozen training-only offset-Breslow baseline and fixed coefficients. External diagnostic slope estimation never updates the prediction model, preprocessing, lambda, cutoff, horizon or baseline.",
  "Binned observed risk is source censoring-aware Kaplan-Meier with log-log intervals. Every shown point aggregates at least10 original subjects. Unsupported or undefined bins remain in explicit accounting; no smoothing, early-censor-as-non-event recoding or extrapolation.")
 res
}
