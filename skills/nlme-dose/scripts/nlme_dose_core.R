# Three-parameter log-logistic: SSlogis on natural-log dose, lower limit zero.
nlme_dose_compute <- function(a) {
 if (is.null(a[["unit-col"]]) || !nzchar(trimws(a[["unit-col"]]))) sc_stop("MISSING_PARAMETER", "unit-col must declare biological subjects")
 if (!is.null(a$subject) && !identical(a$subject, a[["unit-col"]])) sc_stop("CONFLICTING_PARAMETERS", "subject assertion must equal unit-col")
 if (is.null(a[["technical-policy"]]) || a[["technical-policy"]] != "reject") sc_stop("INVALID_PARAMETER", "technical-policy must explicitly reject duplicate subject/dose rows")
 a$subject <- a[["unit-col"]]
 d <- sc_read(a$input, c(a$subject, a$dose, a$response))
 sc_ids(d, a$subject)
 dat <- data.frame(subject = factor(d[[a$subject]], levels = sort(unique(d[[a$subject]]))),
  dose = sc_num(d[[a$dose]], "dose"), response = sc_num(d[[a$response]], "response"))
 if (length(unique(c(a$subject, a$dose, a$response))) != 3L) sc_stop("INVALID_PARAMETER", "subject, dose and response columns must differ")
 if (!nzchar(trimws(a[["dose-unit"]]))) sc_stop("INVALID_PARAMETER", "dose unit must be nonempty")
 if (any(dat$dose <= 0)) sc_stop("INVALID_INPUT", "log-logistic repeated dose requires positive untransformed doses")
 if (anyDuplicated(dat[c("subject", "dose")])) sc_stop("INVALID_DESIGN", "duplicate subject/dose; curate technical replicates upstream, never relabel them biological")
 if (nlevels(dat$subject) < 5L) sc_stop("INVALID_DESIGN", "candidate scope requires >=5 biological subjects")
 counts <- table(dat$subject)
 if (any(counts < 5L) || length(unique(dat$dose)) < 6L) sc_stop("INVALID_DESIGN", "need >=5 distinct doses per subject and >=6 overall")
 dat <- dat[order(dat$subject, dat$dose), , drop = FALSE]; rownames(dat) <- NULL
 dat$logdose <- log(dat$dose)
 init <- tryCatch(stats::getInitial(response ~ stats::SSlogis(logdose, Asym, logED50, scal), data = dat),
  error = function(e) sc_stop("CONVERGENCE", paste("self-start failed:", conditionMessage(e))))
 if (init["Asym"] <= 0 || (a$direction == "increasing" && init["scal"] <= 0) || (a$direction == "decreasing" && init["scal"] >= 0)) sc_stop("INVALID_DESIGN", "response/direction incompatible with positive asymptote and zero lower limit")
 random <- if (a[["random-parameter"]] == "Asym") Asym ~ 1 else logED50 ~ 1
 warnings <- character(0)
 fit <- tryCatch(withCallingHandlers(nlme::nlme(response ~ stats::SSlogis(logdose, Asym, logED50, scal),
  data = dat, fixed = Asym + logED50 + scal ~ 1, random = random, groups = ~subject,
  start = init, method = a$method, na.action = stats::na.fail,
  control = nlme::nlmeControl(maxIter = a[["max-iter"]], pnlsMaxIter = 20L, msMaxIter = 100L, returnObject = FALSE)),
  warning = function(w) { warnings <<- c(warnings, conditionMessage(w)) }),
  error = function(e) sc_stop("CONVERGENCE", conditionMessage(e)))
 if (length(warnings)) sc_stop("CONVERGENCE", paste(warnings, collapse = "; "))
 p <- nlme::fixef(fit); v <- stats::vcov(fit)
 if (is.character(fit$apVar) || any(!is.finite(p)) || any(!is.finite(v)) || min(eigen(stats::cov2cor(v), symmetric = TRUE, only.values = TRUE)$values) < 1e-8) sc_stop("SINGULAR", "non-positive variance Hessian or degenerate fixed covariance")
 vc <- nlme::VarCorr(fit); random_sd <- as.numeric(vc[1, "StdDev"]); residual_sd <- fit$sigma
 scale <- if (a[["random-parameter"]] == "Asym") abs(p["Asym"]) else abs(p["scal"])
 if (!is.finite(random_sd) || random_sd / scale < a[["singular-tol"]] || residual_sd <= 0) sc_stop("SINGULAR", "random-effect SD is below declared relative tolerance")
 individual <- stats::coef(fit)
 if (any(individual$Asym <= 0) || any(individual$scal * p["scal"] <= 0) || p["Asym"] <= 0 || (a$direction == "increasing" && p["scal"] <= 0) || (a$direction == "decreasing" && p["scal"] >= 0)) sc_stop("DEGENERATE", "invalid asymptote or direction")
 interval <- nlme::intervals(fit, which = "fixed", level = a[["ci-level"]])$fixed
 ed <- exp(p["logED50"]); lo <- exp(interval["logED50", "lower"]); hi <- exp(interval["logED50", "upper"])
 if (any(!is.finite(c(ed, lo, hi))) || ed < min(dat$dose) || ed > max(dat$dose)) sc_stop("DEGENERATE", "population ED50 not finite or outside observed dose range")
 et <- add_effect_rows(term = "population ED50", analysis_id = "nlme-dose", effect_type = "other", estimate = unname(ed),
  ci_low = lo, ci_high = hi, ci_level = a[["ci-level"]], n_unweighted = nlevels(dat$subject),
  test_name = "nlme fixed logED50 t interval, exponentiated", notes = "Zero lower asymptote; one scalar normal random effect; biological n is subjects")
 grid <- data.frame(dose = exp(seq(log(min(dat$dose)), log(max(dat$dose)), length.out = 201L)))
 grid$logdose <- log(grid$dose)
 grid$predicted <- as.numeric(stats::predict(fit, newdata = grid, level = 0))
 subjgrid <- do.call(rbind, lapply(levels(dat$subject), function(id) {
  own <- dat$dose[dat$subject == id]
  dose <- exp(seq(log(min(own)), log(max(own)), length.out = 201L))
  z <- data.frame(subject = factor(id, levels = levels(dat$subject)), dose = dose, logdose = log(dose))
  z$predicted <- as.numeric(stats::predict(fit, newdata = z, level = 1)); z
 }))
 residual <- data.frame(subject = dat$subject, dose = dat$dose,
  fitted = as.numeric(stats::fitted(fit, level = 1)), residual = as.numeric(stats::residuals(fit, level = 1, type = "response")))
 response_summary <- stats::aggregate(dat["response"], dat["dose"], mean)
 names(response_summary)[2] <- "mean"
 response_summary$n_subjects <- stats::aggregate(dat["response"], dat["dose"], length)$response
 response_summary$sem <- stats::aggregate(dat["response"], dat["dose"], stats::sd)$response / sqrt(response_summary$n_subjects)
 unit_summary <- do.call(rbind, lapply(levels(dat$subject), function(id) {
  z <- dat[dat$subject == id, ]; data.frame(subject = id, n_observations = nrow(z), dose_min = min(z$dose), dose_max = max(z$dose))
 }))
 meta <- list(unit_column = a[["unit-col"]], technical_policy = a[["technical-policy"]],
  subject_prediction_scope = "Within each subject observed dose range; no implicit subject extrapolation",
  descriptive_sem_missing = sum(!is.finite(response_summary$sem)), model = "SSlogis(log(dose)); zero lower asymptote", method = a$method, direction = a$direction,
  random_parameter = a[["random-parameter"]], singular_tolerance = a[["singular-tol"]], residual = a$residual,
  n_subjects = nlevels(dat$subject), n_observations = nrow(dat), dose_unit = a[["dose-unit"]], ci_level = a[["ci-level"]],
  interval = "native fixed-effects t interval on logED50, exponentiated", population_interpretation = "Marginal half-maximum equals exp(fixed logED50) for the supported single symmetric location OR additive amplitude random effect; population prediction curve is level 0, not a marginalized curve for location random effects",
  study_contract_sha256 = a[["study-contract-sha256"]])
 list(object = fit, metadata = meta, packages = c("nlme", "jsonlite", "digest"), ready = TRUE,
  method = "nlme self-starting log-logistic nonlinear mixed model; zero lower asymptote, one normal random effect, conditionally independent homoscedastic Gaussian residuals. Native fixed logED50 t interval is exponentiated. No dose-wise independent-observation regression.",
  tables = list(effect_table = et, biological_units = unit_summary, parameters = data.frame(term = names(p), estimate = as.numeric(p)),
   variance_components = data.frame(component = c(a[["random-parameter"]], "residual"), variance = c(random_sd^2, residual_sd^2)),
   subject_parameters = data.frame(subject = rownames(individual), individual, row.names = NULL), observations = dat,
   curve_predictions = grid, subject_predictions = subjgrid, residuals = residual, response_summary = response_summary),
  qc = list(os_qc_rule("NLD-01", "ED50 interval range", lo < min(dat$dose) || hi > max(dat$dose), "blocker", "ED50 interval crosses tested dose range.", "Collect doses covering the interval."),
   os_qc_rule("NLD-02", "Model scope review", TRUE, "warning", "Zero lower asymptote and residual independence require scientific review.", "Check residuals and study contract.")))
}
