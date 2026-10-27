glmnet_coxsig_compute_legacy <- function(a) {
 inp <- os_survival_input(a, allow_constant = a$mode == "validate"); X <- t(inp$E); d <- inp$clinical
 if (length(inp$covariates)) stop("OS_INVALID_DESIGN: gene-only penalized signature; clinical covariates are outside this module", call. = FALSE)
 train_flags <- c("folds", "standardize", "nlambda", "lambda-min-ratio", "selection", "cv-measure", "cv-grouped", "max-iter", "thresh", "cox-ties", "cutoff")
 cvtab <- paths <- data.frame(); cv <- NULL; sigup <- NULL; files <- inp$input_files
 hash_ids <- function(ids) vapply(ids, function(z) digest::digest(z, algo = "sha256", serialize = FALSE), "")
 if (a$mode == "train") {
  if (utils::packageVersion("glmnet") < "5.0") stop("OS_PACKAGE_VERSION: training requires production-compatible glmnet >=5.0 control API", call. = FALSE)
  missing <- train_flags[vapply(train_flags, function(k) is.null(a[[k]]), logical(1))]
  if (length(missing)) stop(paste("OS_MISSING_PARAMETER: training requires", paste(missing, collapse = ",")), call. = FALSE)
  if (!is.null(a[["signature-run"]])) stop("OS_CONFLICTING_PARAMETERS: train cannot consume a frozen signature", call. = FALSE)
  if ((a$selection == "fixed") != !is.null(a[["lambda"]])) stop("OS_CONFLICTING_PARAMETERS: fixed selection alone requires lambda", call. = FALSE)
  if ((a$cutoff == "prespecified") != !is.null(a$cutpoint)) stop("OS_CONFLICTING_PARAMETERS: prespecified cutoff alone requires cutpoint", call. = FALSE)
  f <- utils::read.csv(a$folds, colClasses = "character", check.names = FALSE); os_check_columns(f, c("unit", "fold"))
  if (anyNA(f$unit) || anyDuplicated(f$unit) || !setequal(f$unit, d$unit)) stop("OS_INVALID_DESIGN: supplied folds must cover each biological subject exactly once", call. = FALSE)
  folds <- os_as_finite(f$fold[match(d$unit, f$unit)], "fold")
  if (any(folds != floor(folds)) || !setequal(unique(folds), seq_len(max(folds))) || max(folds) < 3L || max(folds) > 20L ||
      any(table(folds) < 5L) || any(tapply(d$event, folds, sum) < 2L)) stop("OS_INVALID_DESIGN: 3-20 contiguous folds, at least five subjects and two events in every holdout required", call. = FALSE)
  if (ncol(X) < 2L) stop("OS_INVALID_DESIGN: glmnet signature requires at least two prespecified genes", call. = FALSE)
  # Pin Breslow explicitly instead of accepting a version-dependent default.
  if (a[["cox-ties"]] != "breslow") stop("OS_INVALID_PARAMETER: this signature contract requires Breslow ties across glmnet versions", call. = FALSE)
  cv <- glmnet::cv.glmnet(x = X, y = survival::Surv(d$time, d$event), family = "cox", alpha = 1,
   nfolds = max(folds), foldid = folds, type.measure = a[["cv-measure"]], grouped = a[["cv-grouped"]] == "true",
   alignment = "lambda", keep = TRUE, parallel = FALSE, relax = FALSE, standardize = a$standardize == "true",
   nlambda = a$nlambda, lambda.min.ratio = a[["lambda-min-ratio"]], control = list(thresh = a$thresh, maxit = a[["max-iter"]]), cox.ties = "breslow")
  if (cv$glmnet.fit$jerr != 0L || any(!is.finite(cv$cvm))) stop("OS_INVALID_DESIGN: glmnet nonconvergence or undefined cross-validation; no partial path accepted", call. = FALSE)
  lambda <- if (a$selection == "fixed") a[["lambda"]] else cv[[a$selection]]
  if (lambda < min(cv$lambda) || lambda > max(cv$lambda)) stop("OS_INVALID_PARAMETER: selected lambda outside fitted path; no extrapolation", call. = FALSE)
  beta <- as.numeric(stats::coef(cv$glmnet.fit, s = lambda)); names(beta) <- colnames(X)
  risk <- as.numeric(X %*% beta)
  cutpoint <- if (a$cutoff == "median") stats::median(risk) else a$cutpoint
  signature <- structure(list(schema = "omicstat.cox-signature.v1", candidate = TRUE, development_only = TRUE,
   genes = colnames(X), coefficients = beta, coefficient_scale = "original input expression; glmnet standardization is undone in returned coefficients",
   expression_scale = a[["expression-scale"]], time_unit = a[["time-unit"]], lambda = lambda, selection = a$selection,
   alpha = 1, ties = "breslow", standardize = a$standardize, cutoff_rule = a$cutoff, cutpoint = cutpoint,
   training_subject_sha256 = hash_ids(d$unit), training_expression_sha256 = inp$upstream$objects[[names(Filter(function(o) o$type == "expression_matrix", inp$upstream$objects))[1]]]$sha256,
   training_n = nrow(X), training_events = sum(d$event), glmnet_version = as.character(utils::packageVersion("glmnet"))), class = "cox_signature")
  cvtab <- data.frame(lambda = cv$lambda, mean = cv$cvm, se = cv$cvsd, lower = cv$cvlo, upper = cv$cvup, n_nonzero = cv$nzero)
  B <- as.matrix(cv$glmnet.fit$beta); paths <- data.frame(lambda = rep(cv$glmnet.fit$lambda, each = nrow(B)), feature = rep(rownames(B), ncol(B)), coefficient = as.numeric(B))
  files$folds <- a$folds
 } else {
  if (is.null(a[["signature-run"]])) stop("OS_MISSING_PARAMETER: external validation requires signature-run", call. = FALSE)
  if (any(vapply(c(train_flags, "lambda", "cutpoint"), function(k) !is.null(a[[k]]), logical(1)))) stop("OS_CONFLICTING_PARAMETERS: validation cannot refit, restandardize, retune lambda or recut the frozen signature", call. = FALSE)
  sigup <- read_handoff(a[["signature-run"]]); hits <- names(Filter(function(o) o$type == "cox_signature", sigup$objects))
  if (length(hits) != 1L) stop("OS_HANDOFF_MISMATCH: exactly one cox_signature required", call. = FALSE)
  os_handoff_assert_uncorrected(sigup, hits)
  signature <- readRDS(sigup$objects[[hits]]$path)
  required <- c("schema","genes","coefficients","expression_scale","time_unit","lambda","cutpoint","training_subject_sha256")
  if (!inherits(signature, "cox_signature") || !all(required %in% names(signature)) || !identical(signature$schema,"omicstat.cox-signature.v1") ||
      !identical(signature$genes, colnames(X)) || !identical(names(signature$coefficients), colnames(X)) || any(!is.finite(signature$coefficients)) ||
      length(signature$coefficients) != ncol(X) || !is.numeric(signature$coefficients) ||
      !is.numeric(signature$cutpoint) || length(signature$cutpoint) != 1L || !is.finite(signature$cutpoint) ||
      !is.numeric(signature$lambda) || length(signature$lambda) != 1L || !is.finite(signature$lambda) || signature$lambda <= 0 ||
      !is.character(signature$training_subject_sha256) || anyNA(signature$training_subject_sha256) ||
      any(!grepl("^[0-9a-f]{64}$", signature$training_subject_sha256)))
   stop("OS_HANDOFF_MISMATCH: malformed or mismatched frozen gene coefficients", call. = FALSE)
  if (!identical(signature$expression_scale, a[["expression-scale"]]) || !identical(signature$time_unit, a[["time-unit"]])) stop("OS_HANDOFF_MISMATCH: validation preprocessing scale and follow-up units must match training", call. = FALSE)
  if (any(hash_ids(d$unit) %in% signature$training_subject_sha256)) stop("OS_INVALID_DESIGN: validation contains training subject identities; not external validation", call. = FALSE)
  risk <- as.numeric(X %*% signature$coefficients)
  inp$upstream$upstream_runs <- unique(c(sigup$upstream_runs, inp$upstream$upstream_runs))
  files$signature_handoff <- file.path(a[["signature-run"]], "objects", "handoff.json"); files$signature <- sigup$objects[[hits]]$path
 }
 if (any(!is.finite(risk))) stop("OS_INVALID_DESIGN: nonfinite frozen linear predictor", call. = FALSE)
 times <- suppressWarnings(as.numeric(strsplit(a[["roc-times"]], ",", fixed = TRUE)[[1]]))
 if (!length(times) || any(!is.finite(times) | times <= 0 | times >= max(d$time)) || anyDuplicated(times) || is.unsorted(times, strictly = TRUE) || length(times) > 10L)
  stop("OS_INVALID_PARAMETER: 1-10 sorted positive ROC horizons inside observed follow-up required", call. = FALSE)
 for (tt in times) if (sum(d$event == 1 & d$time < tt) < 2L || sum(d$time > tt) < 2L) stop("OS_INVALID_DESIGN: each ROC horizon needs at least two observed cases before and two controls beyond it", call. = FALSE)
 roc <- timeROC::timeROC(T = d$time, delta = d$event, marker = risk, cause = 1, weighting = "marginal", times = times, ROC = TRUE, iid = FALSE)
 ix <- match(times, roc$times)
 if (anyNA(ix) || any(!is.finite(roc$AUC[ix])) || any(!is.finite(roc$TP[, ix])) || any(!is.finite(roc$FP[, ix]))) stop("OS_INVALID_DESIGN: undefined IPCW ROC; inspect censoring support", call. = FALSE)
 roctab <- do.call(rbind, lapply(seq_along(times), function(i) data.frame(horizon = times[i], fpr = roc$FP[, ix[i]], tpr = roc$TP[, ix[i]])))
 performance <- if (a$mode == "train") "apparent training discrimination; cross-validation selects penalty, not external validation" else "external cohort: coefficients, preprocessing scale, lambda and risk cutoff frozen; no refitting"
 auc <- data.frame(horizon = times, auc = as.numeric(roc$AUC[ix]), evaluation = a$mode, interpretation = performance)
 groups <- factor(ifelse(risk <= signature$cutpoint, "low", "high"), levels = c("low", "high"))
 km <- list(curves = data.frame(), risk = data.frame()); informative <- all(table(groups) >= 2L)
 if (informative) {
  dat <- transform(d, group = groups)
  sf <- survival::survfit(formula = survival::Surv(time, event) ~ group, data = dat, conf.int = a[["ci-level"]], conf.type = "log-log", se.fit = TRUE)
  gv <- rep(sub("^group=", "", names(sf$strata)), sf$strata)
  km$curves <- rbind(data.frame(time = 0, survival = 1, lower = 1, upper = 1, n_censor = 0, group = levels(groups)),
   data.frame(time = sf$time, survival = sf$surv, lower = sf$lower, upper = sf$upper, n_censor = sf$n.censor, group = gv))
 }
 tt <- suppressWarnings(as.numeric(strsplit(a[["risk-times"]], ",", fixed = TRUE)[[1]]))
 if (any(!is.finite(tt) | tt < 0 | tt > max(d$time)) || anyDuplicated(tt) || is.unsorted(tt, strictly = TRUE)) stop("OS_INVALID_PARAMETER: sorted observed-range risk times required", call. = FALSE)
 if (informative) km$risk <- do.call(rbind, lapply(levels(groups), function(g) data.frame(time = tt, group = g, n_risk = vapply(tt, function(z) sum(d$time[groups == g] >= z), 0L))))
 list(tables = list(coefficients = data.frame(gene = signature$genes, coefficient = signature$coefficients, row.names = NULL),
  scores = data.frame(unit = d$unit, linear_predictor = risk, group = groups), cross_validation = cvtab, coefficient_path = paths,
  time_roc = roctab, auc = auc, km_curves = km$curves, km_risk = km$risk), object = signature, handoff_type = "cox_signature",
  upstream = inp$upstream, input_files = files, ready = TRUE, packages = c("glmnet","survival","timeROC"),
  metadata = list(mode = a$mode, performance_scope = performance, frozen = a$mode == "validate", n_biological = nrow(X), n_events = sum(d$event),
   lambda = signature$lambda, cutoff_rule = signature$cutoff_rule, cutpoint = signature$cutpoint, expression_scale = a[["expression-scale"]], time_unit = a[["time-unit"]],
   genes = signature$genes, journal = a$journal, ci_level = a[["ci-level"]], km_available = informative, roc_weighting = "marginal Kaplan-Meier IPCW", roc_iid = FALSE),
  method = c("LASSO Cox (alpha=1), supplied biological folds, explicit penalty-selection rule and Breslow ties. Returned coefficients are on original expression scale.",performance,
   "Time-dependent ROC uses marginal Kaplan-Meier IPCW; no AUC confidence interval or post-selection coefficient p-value is invented. Risk KM is descriptive without logrank test."))
}

# Exact old compute body retained above; opt-in workup does not change defaults.
glmnet_coxsig_compute <- function(a) {
 mode <- if (is.null(a[["prediction-workup"]])) "none" else a[["prediction-workup"]]
 if (identical(mode, "none")) {
  extra <- c("dataset-name", "planning-source", "planning-parameters", "planning-cs-r2", "planning-shrinkage", "planning-rate", "planning-horizon", "planning-mean-followup", "bootstrap-B", "bootstrap-seed", "bootstrap-fit-policy", "baseline-estimator", "calibration-horizon", "calibration-min-bin", "calibration-max-bins", "calibration-slope-fit")
  if (any(vapply(extra, function(k) !is.null(a[[k]]), logical(1)))) stop("OS_INVALID_PARAMETER: workup flags require explicit prediction-workup=cpm", call. = FALSE)
  return(glmnet_coxsig_compute_legacy(a))
 }
 if (identical(mode, "cpm")) return(os_cxs_workup_compute(a))
 stop("OS_INVALID_PARAMETER: unknown prediction workup", call. = FALSE)
}
