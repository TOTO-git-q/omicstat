local({
 files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
 source(file.path(dirname(normalizePath(tail(files[nzchar(files)], 1))), "model_io.R"), local = .GlobalEnv)
})
# Opt-in development support; no production module sources this file.
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
sc_stop <- function(code, text) stop(paste0("OS_", code, ": ", text), call. = FALSE)
sc_num <- function(x, name) {
 y <- suppressWarnings(as.numeric(x))
 if (anyNA(y) || any(!is.finite(y))) sc_stop("INVALID_INPUT", paste(name, "must be finite numbers"))
 y
}
sc_read <- function(path, cols) {
 d <- utils::read.csv(path, colClasses = "character", check.names = FALSE, na.strings = c("", "NA"))
 if (!nrow(d) || anyDuplicated(names(d)) || !all(cols %in% names(d))) sc_stop("INVALID_INPUT", "empty input, duplicate or missing columns")
 d
}
sc_ids <- function(d, cols) {
 for (k in cols) if (anyNA(d[[k]]) || any(!nzchar(trimws(d[[k]]))) || any(d[[k]] != trimws(d[[k]]))) sc_stop("INVALID_INPUT", paste(k, "requires nonempty, unpadded identities"))
}
sc_fit_drc <- function(d, model) {
 k <- if (model == "LL4") 4L else 5L
 if (length(unique(d$dose)) < k + 2L || nrow(d) <= k) sc_stop("INVALID_DESIGN", "need at least parameters + 2 distinct positive doses")
 fit <- tryCatch(drc::drm(response ~ dose, data = d,
  fct = if (model == "LL4") drc::LL.4() else drc::LL.5(), type = "continuous",
  na.action = stats::na.fail, logDose = NULL), error = function(e) sc_stop("CONVERGENCE", conditionMessage(e)))
 # drc 3.0-1 converts optim's code to a logical success flag.
 if (!isTRUE(fit$fit$convergence)) sc_stop("CONVERGENCE", "drc optimizer did not converge")
 p <- as.numeric(stats::coef(fit)); v <- stats::vcov(fit)
 if (any(!is.finite(p)) || any(!is.finite(v)) || p[3] <= p[2] || p[4] <= 0 || abs(p[1]) < 1e-6 || (k == 5L && p[5] <= 0)) sc_stop("DEGENERATE", "invalid log-logistic parameters/covariance")
 cor <- stats::cov2cor(v)
 if (min(eigen(cor, symmetric = TRUE, only.values = TRUE)$values) < 1e-8) sc_stop("SINGULAR", "curve parameters are not identifiable")
 fit
}
sc_ed <- function(fit, level, type, ci) {
 z <- tryCatch(drc::ED(fit, respLev = level, type = type, reference = "control", interval = "delta",
  level = ci, bound = TRUE, display = FALSE), error = function(e) sc_stop("DEGENERATE", conditionMessage(e)))
 if (nrow(z) != 1L || ncol(z) < 4L || any(!is.finite(z))) sc_stop("DEGENERATE", "nonfinite inverse prediction")
 as.numeric(z[1, ])
}
sc_inverse <- function(fit, response, type, ci, mean_se = 0) {
 p <- as.numeric(stats::coef(fit)); v <- stats::vcov(fit)
 inverse <- function(q, y) {
  f <- if (length(q) == 5L) q[5] else 1
  target <- if (type == "relative") q[2] + (q[3] - q[2]) / 2 else y
  q[4] * (((q[3] - q[2]) / (target - q[2]))^(1 / f) - 1)^(1 / q[1])
 }
 x <- inverse(p, response)
 # Include asymptote chain-rule terms omitted by old drc ED absolute SEs.
 jac <- vapply(seq_along(p), function(i) {
  h <- 1e-5 * max(abs(p[i]), 1); up <- down <- p
  up[i] <- up[i] + h; down[i] <- down[i] - h
  (inverse(up, response) - inverse(down, response)) / (2 * h)
 }, numeric(1))
 h <- 1e-5 * max(abs(response), 1)
 dy <- if (type == "relative") 0 else (inverse(p, response + h) - inverse(p, response - h)) / (2 * h)
 se <- sqrt(as.numeric(t(jac) %*% v %*% jac) + (dy * mean_se)^2)
 half <- stats::qt((1 + ci) / 2, df = fit$df.residual) * se
 ans <- c(x, se, x - half, x + half)
 if (any(!is.finite(ans))) sc_stop("DEGENERATE", "inverse delta is not finite")
 ans
}
sc_grid <- function(fit, doses) {
 g <- data.frame(dose = exp(seq(log(min(doses)), log(max(doses)), length.out = 201L)))
 g$predicted <- as.numeric(stats::predict(fit, newdata = g))
 g
}
sc_check_run <- function(a) {
 if (!isTRUE(a[["development-mode"]])) sc_stop("MODULE_UNSEALED", "explicit --development-mode is required")
 if (!is.null(a[["study-contract"]])) os_study_contract_read(a[["study-contract"]])
 if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE))) sc_stop("OUTPUT_EXISTS", "output directory must be new or empty")
 dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
 set.seed(a$seed)
}
sc_write <- function(res, a, module, entry, spec) {
 res$handoff_type <- paste0("development_", module)
 os_module_finish(res, a, module, entry, spec, figures_fn = os_scope_figures)
}
