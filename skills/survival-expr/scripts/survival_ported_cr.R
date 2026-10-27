# Selected, independently maintained OmicStat port.
# ported_from: TOTO-git-q/medstat@12292d0:skills/competing-risks/scripts/cr_core.R
# Full immutable source identity and every adaptation are in references/PORT_SOURCE.json.
# This file is loaded into a module-private environment, never a MedStat environment.

.cr_stop <- function(code, msg) stop(sprintf("%s: %s", code, msg), call. = FALSE)

.cr_warn <- function(code, msg) warning(sprintf("%s: %s", code, msg), call. = FALSE)

cr_status <- function(status_raw, event_labels = NULL) {
  if (!is.numeric(status_raw)) {
    num <- suppressWarnings(as.numeric(as.character(status_raw)))
    if (any(is.na(num) & !is.na(status_raw))) {
      .cr_stop("OS_INVALID_INPUT",
        "the status column could not be coerced to numeric 0/1..k codes. Recode it to 0=censored, 1..k=event types before running this module (see references/troubleshooting.md).")
    }
    status_raw <- num
  }
  if (any(!is.na(status_raw) & (status_raw != round(status_raw) | status_raw < 0))) {
    .cr_stop("OS_INVALID_INPUT",
      "the status column has non-integer or negative values. It must be 0=censored, 1..k=event types.")
  }
  status_num <- as.integer(status_raw)
  codes <- sort(unique(status_num[status_num > 0 & !is.na(status_num)]))
  if (!length(codes)) {
    .cr_stop("OS_INVALID_INPUT", "no event codes (>0) found in the status column -- nothing to analyse.")
  }
  if (!identical(codes, seq_len(max(codes)))) {
    .cr_stop("OS_INVALID_INPUT", sprintf(
      "event codes must be consecutive 1..k with no gaps; found %s. Recode before running.",
      paste(codes, collapse = ",")))
  }
  k <- max(codes)
  status_fac <- factor(status_num, levels = c(0L, codes))  # preserve censoring state even when no rows are censored

  labels <- stats::setNames(sprintf("Event %d", codes), as.character(codes))
  if (!is.null(event_labels)) {
    hit <- intersect(names(event_labels), names(labels))
    labels[hit] <- event_labels[hit]
    unknown <- setdiff(names(event_labels), names(labels))
    if (length(unknown)) {
      .cr_warn("OS_INVALID_INPUT", sprintf(
        "--event-labels named code(s) not present in the data: %s (ignored).", paste(unknown, collapse = ",")))
    }
  }
  counts <- data.frame(
    code = c(0L, codes),
    label = c("Censored", unname(labels[as.character(codes)])),
    n = as.integer(table(factor(status_num, levels = c(0L, codes)))),
    stringsAsFactors = FALSE)

  list(status_num = status_num, status_fac = status_fac, codes = codes, k = k,
       labels = labels, counts = counts)
}

cr_triage <- function(cr, event_of_interest) {
  if (!event_of_interest %in% cr$codes) {
    .cr_stop("OS_INVALID_PARAMETER", sprintf(
      "--event-of-interest %s is not one of the event codes present (%s).",
      event_of_interest, paste(cr$codes, collapse = ",")))
  }
  n_total <- length(cr$status_num)
  n_event <- sum(cr$status_num == event_of_interest)
  n_compete <- sum(cr$status_num != event_of_interest & cr$status_num != 0)
  n_outcomes <- n_event + n_compete
  pct_compete <- if (n_outcomes > 0) 100 * n_compete / n_outcomes else NA_real_
  tier <- if (!is.finite(pct_compete)) "info" else if (pct_compete > 10) "high" else if (pct_compete >= 5) "warning" else "info"
  list(event_of_interest = event_of_interest, n_total = n_total, n_event = n_event,
       n_compete = n_compete, n_outcomes = n_outcomes, pct_compete = pct_compete, tier = tier)
}

one_minus_km <- function(time, status_num, event_code, times) {
  ev <- as.integer(status_num == event_code)
  sf <- survival::survfit(formula = survival::Surv(time, ev) ~ 1)
  s <- summary(sf, times = times, extend = TRUE)
  data.frame(time = times, one_minus_km = 1 - s$surv, stringsAsFactors = FALSE)
}

aalen_johansen <- function(time, status_fac, times) {
  sf <- survival::survfit(formula = survival::Surv(time, status_fac) ~ 1)
  s <- summary(sf, times = times, extend = TRUE)
  st <- colnames(s$pstate)
  ev_cols <- st[st != "(s0)"]
  out <- lapply(ev_cols, function(cl) data.frame(time = times, code = as.integer(cl), cif = s$pstate[, cl]))
  do.call(rbind, out)
}

km_vs_cif_table <- function(cr, data, time, times) {
  tvec <- data[[time]]
  aj <- aalen_johansen(tvec, cr$status_fac, times)
  out <- list()
  for (cd in cr$codes) {
    km1 <- one_minus_km(tvec, cr$status_num, cd, times)
    ajc <- aj[aj$code == cd, ]
    d <- merge(km1, ajc[, c("time", "cif")], by = "time")
    d$abs_diff <- d$one_minus_km - d$cif
    d$rel_excess_pct <- ifelse(d$cif > 0, 100 * d$abs_diff / d$cif, NA_real_)
    d$event_code <- cd
    d$event_label <- cr$labels[[as.character(cd)]]
    out[[as.character(cd)]] <- d
  }
  do.call(rbind, out)
}

km_sum_check <- function(cr, data, time, times) {
  tvec <- data[[time]]
  km_sum <- rep(0, length(times))
  for (cd in cr$codes) km_sum <- km_sum + one_minus_km(tvec, cr$status_num, cd, times)$one_minus_km
  any_ev <- as.integer(cr$status_num > 0)
  sf_any <- survival::survfit(formula = survival::Surv(tvec, any_ev) ~ 1)
  s_any <- summary(sf_any, times = times, extend = TRUE)
  cif_sum <- rep(0, length(times))
  aj <- aalen_johansen(tvec, cr$status_fac, times)
  for (cd in cr$codes) cif_sum <- cif_sum + aj$cif[aj$code == cd]
  d <- data.frame(time = times, km_sum = km_sum, cif_sum = cif_sum, any_event_1mS = 1 - s_any$surv,
                  stringsAsFactors = FALSE)
  over <- d$time[d$km_sum > 1]
  list(table = d, first_km_sum_over_1 = if (length(over)) min(over) else NA_real_)
}

guard_cif_estimator <- function(estimator_source, event_label, cr, data, time, event_code, at_time) {
  if (identical(estimator_source, "one_minus_km")) {
    km <- one_minus_km(data[[time]], cr$status_num, event_code, at_time)$one_minus_km
    aj <- aalen_johansen(data[[time]], cr$status_fac, at_time)
    cif <- aj$cif[aj$code == event_code]
    rel <- ifelse(cif > 0, 100 * (km - cif) / cif, NA_real_)
    .cr_stop("OS_INVALID_PARAMETER", sprintf(paste(
      "refusing to report a 1-KM ('1 minus Kaplan-Meier') number as the cumulative incidence of '%s'.",
      "In THIS dataset at t=%s: 1-KM = %.5f, Aalen-Johansen CIF = %.5f (relative over-estimate %.1f%%).",
      "Use the Aalen-Johansen CIF (tables/cif_timepoints.csv) instead -- references/method-basis.md."),
      event_label, at_time, km, cif, rel))
  }
  invisible(TRUE)
}
