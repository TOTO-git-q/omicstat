# Independently maintained OmicStat source-copy port. No MedStat runtime dependency.
# ported_from: TOTO-git-q/medstat@12292d0:skills/cpm-pipeline/scripts/calibration_binned.R
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

cpm_calibration_binned <- function(p, y, time = NULL, horizon = NULL,
                                   min_n = 10L, max_bins = 10L, alpha = 0.05) {
  empty <- data.frame(bin = integer(), n = integer(), predicted = numeric(),
                      observed = numeric(), ci_low = numeric(), ci_high = numeric(),
                      ci_level = numeric(), n_at_risk = integer(), method = character())
  if (min_n < 10L || min_n != as.integer(min_n) || max_bins < 1L ||
      !is.finite(alpha) || alpha <= 0 || alpha >= 1) stop("OS_INVALID_PARAMETER: invalid calibration bin settings")
  if (length(p) != length(y) || (!is.null(time) && length(time) != length(p)))
    stop("OS_INVALID_PARAMETER: calibration vectors have unequal lengths")
  ok <- is.finite(p) & p >= 0 & p <= 1 & !is.na(y) & y %in% c(0, 1)
  if (!is.null(time)) {
    if (length(horizon) != 1L || !is.finite(horizon) || horizon <= 0)
      stop("OS_INVALID_PARAMETER: prognostic calibration needs a positive horizon")
    ok <- ok & is.finite(time) & time >= 0
  }
  p <- as.numeric(p[ok]); y <- as.numeric(y[ok]); if (!is.null(time)) time <- time[ok]
  n <- length(p); k <- min(as.integer(max_bins), n %/% min_n)
  if (!k) return(empty)
  ord <- order(p, seq_along(p)); p <- p[ord]; y <- y[ord]
  if (!is.null(time)) time <- time[ord]
  groups <- pmin(k, floor((seq_len(n) - 1L) * k / n) + 1L)
  rows <- list()
  for (g in seq_len(k)) {
    ii <- which(groups == g); nr <- NA_integer_
    if (is.null(time)) {
      obs <- mean(y[ii]); ci <- stats::binom.test(sum(y[ii]), length(ii), conf.level = 1 - alpha)$conf.int
      method <- "observed proportion; exact binomial CI"
    } else {
      # Never extend a KM estimate past observed follow-up. Early-censored
      # subjects are not recoded as non-events at the horizon.
      if (max(time[ii]) < horizon) next
      fit <- survival::survfit(survival::Surv(time[ii], y[ii]) ~ 1,
                              conf.int = 1 - alpha, conf.type = "log-log")
      su <- summary(fit, times = horizon, extend = FALSE)
      if (!length(su$surv)) next
      obs <- 1 - su$surv[1]; ci <- c(1 - su$upper[1], 1 - su$lower[1]); nr <- as.integer(su$n.risk[1])
      method <- "Kaplan-Meier event risk at declared horizon; log-log CI"
    }
    if (!all(is.finite(c(obs, ci)))) next
    rows[[length(rows) + 1L]] <- data.frame(bin = g, n = length(ii), predicted = mean(p[ii]),
      observed = obs, ci_low = ci[1], ci_high = ci[2], ci_level = 1 - alpha,
      n_at_risk = nr, method = method, stringsAsFactors = FALSE)
  }
  if (length(rows)) do.call(rbind, rows) else empty
}
