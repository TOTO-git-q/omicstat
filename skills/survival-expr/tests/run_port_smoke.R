# requires: survival jsonlite
# Native tests only. Inputs below are invented software contracts, never patient data.
if (as.character(getRversion()) != "4.6.1") stop("Native port acceptance requires locked R4.6.1; no alternate-R pass", call. = FALSE)
if (!requireNamespace("survival", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) stop("Native port dependencies are missing; do not install or substitute here", call. = FALSE)
if (utils::packageDescription("survival")$Version != "3.8-9") stop("Native port acceptance requires locked survival3.8-9", call. = FALSE)
this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
here <- dirname(this); mod <- dirname(here)
source(file.path(mod, "scripts/survival_port_adapter.R"))
shared <- file.path(mod, "..", "_shared", "scripts")
source(file.path(shared, "calls_check.R"))
check <- function(x, message) {
 if (!isTRUE(x)) stop(paste("FAIL:", message), call. = FALSE)
 cat("PASS:", message, "\n")
}
refuse <- function(expr, code) {
 err <- tryCatch({force(expr); "NO_ERROR"}, error = conditionMessage)
 check(grepl(code, err, fixed = TRUE), paste("refusal", code))
}
load_old <- function(kind) {
 e <- new.env(parent = baseenv()); e$Surv <- survival::Surv; e$strata <- survival::strata; e$tail <- utils::tail
 sys.source(file.path(here, "ported_source", paste0(kind, "_selected_before.R.txt")), envir = e)
 e
}
np <- .os_survival_ports$nonph; cr <- .os_survival_ports$cr
old_np <- load_old("nonph"); old_cr <- load_old("cr")

# Real source guard parity on invented fitted data, including ties and covariates.
contract_seed <- 62211L; set.seed(contract_seed)
n <- 240L; x <- stats::rnorm(n); z <- stats::rnorm(n)
event_time <- stats::rexp(n, rate = exp(.2 * x + .1 * z) / 12)
censor_time <- stats::runif(n, 8, 35)
d <- data.frame(time = pmax(.1, round(pmin(event_time, censor_time), 1)),
 event = as.integer(event_time <= censor_time), expression = x, c1 = z)
fit <- survival::coxph(survival::Surv(time, event) ~ expression + c1, data = d, x = TRUE, y = TRUE, model = TRUE)
diag_old <- old_np$zph_diagnostics(fit); diag_new <- np$zph_diagnostics(fit)
check(isTRUE(all.equal(diag_old, diag_new, tolerance = 0)), "copied four-transform diagnostics preserve exact same-input native values")
check(nrow(diag_new) == 12L && sum(diag_new$is_global) == 4L, "all term/global rows retained for four transforms")
check(isTRUE(all.equal(old_np$zph_classify(diag_old, "expression"), np$zph_classify(diag_new, "expression"), tolerance = 0)), "copied severity result unchanged")
ds_old <- old_np$piecewise_split(d, "time", "event", c(5, 10))
ds_new <- np$piecewise_split(d, "time", "event", c(5, 10))
check(identical(ds_old, ds_new), "same split rows, original subject IDs, periods and attributes")
before <- old_np$piecewise_hr(ds_old, "expression", "c1", alpha = .1)
after <- np$piecewise_hr(ds_new, "expression", "c1", alpha = .1)
check(isTRUE(all.equal(before, after, tolerance = 0)), "same-input source-native piecewise HR and90percent intervals unchanged")
check(sum(after$n_events) == sum(d$event), "split does not duplicate events")
check(all(after$n_unweighted == n), "biological denominator counts independent original subjects")
check(attr(ds_new, "n_zero_time") == 0, "positive public input uses no source zero-time nudge")
refuse(np$piecewise_hr(ds_new, "expression", design = list()), "OS_INVALID_DESIGN")
refuse(np$piecewise_split(transform(d, nonph_id = seq_len(n)), "time", "event", 5), "OS_INVALID_PARAMETER")
bad <- fit; class(bad) <- c("svycoxph", class(bad))
refuse(np$zph_diagnostics(bad), "OS_INVALID_DESIGN")

# Source severity has a fixed P0.05 rule and explicit engineering magnitude.
toy <- data.frame(transform = c("km", "km"), term = c("expression", "GLOBAL"),
 is_global = c(FALSE, TRUE), p = c(.02, .02), delta_loghr = c(.1, NA), multi_df = FALSE)
check(np$zph_classify(toy, "expression", magnitude_threshold = .2)$severity == "low", "magnitude prevents P-only high severity")
toy$delta_loghr[1] <- .2
check(np$zph_classify(toy, "expression", magnitude_threshold = .2)$severity == "high", "declared engineering magnitude boundary retained")
toy$multi_df[1] <- TRUE
check(np$zph_classify(toy, "expression")$severity == "unassessed", "multi-df slope is not manufactured")
toy$multi_df[1] <- FALSE; toy$p <- c(.05, .05)
check(np$zph_classify(toy, "expression")$severity == "none", "source P=0.05 inclusive boundary retained")
refuse(np$zph_classify(toy, "absent"), "OS_INVALID_PARAMETER")
fake_zph <- list(table = matrix(1, 1, 1, dimnames = list("expression", "df")),
 x = c(-Inf, 0, 1), y = matrix(c(100, 0, 1), ncol = 1, dimnames = list(NULL, "expression")))
check(np$.zph_slope_row(fake_zph, "expression", 0)$n_nonfinite_x == 1L, "nonfinite residual transform is counted, never silently fitted")

# Independent product-integral oracle uses base risk-set arithmetic only.
oracle <- function(time, status, at, code) {
 s <- 1; f <- 0
 for (tt in sort(unique(time[time <= at]))) {
  y <- sum(time >= tt)
  f <- f + s * sum(time == tt & status == code) / y
  s <- s * (1 - sum(time == tt & status > 0) / y)
 }
 f
}
t <- 1:6; st <- c(2, 1, 0, 2, 1, 0); times <- 0:6
status <- cr$cr_status(st)
aj <- cr$aalen_johansen(t, status$status_fac, times)
old <- old_cr$aalen_johansen(t, old_cr$cr_status(st)$status_fac, times)
check(isTRUE(all.equal(aj, old, tolerance = 0)), "unchanged AJ native values on source-valid censor coding")
for (code in 1:2) {
 expected <- vapply(times, function(at) oracle(t, st, at, code), 0)
 check(max(abs(aj$cif[aj$code == code] - expected)) < 1e-12, paste("independent invented AJ oracle cause", code))
}
check(abs(aj$cif[aj$time == 5 & aj$code == 1] - 7/18) < 1e-12, "closed-form invented cause1 CIF7/18")
check(abs(cr$one_minus_km(t, st, 1, 5)$one_minus_km - 3/5) < 1e-12, "forbidden KM comparison differs:3/5 is not CIF")
refuse(cr$guard_cif_estimator("one_minus_km", "Invented event", status, data.frame(time = t), "time", 1, 5), "OS_INVALID_PARAMETER")
tri <- cr$cr_triage(cr$cr_status(c(rep(0, 500), rep(1, 10), rep(2, 40))), 1)
check(tri$pct_compete == 80 && tri$n_total == 550 && tri$n_outcomes == 50, "competing share denominator excludes censoring")
refuse(cr$cr_status(c(0, 1, 3)), "OS_INVALID_INPUT")
refuse(cr$cr_status(c(0, 1, 1.5)), "OS_INVALID_INPUT")
refuse(cr$cr_status(c(0, 0)), "OS_INVALID_INPUT")
refuse(cr$cr_triage(status, 3), "OS_INVALID_PARAMETER")

# Explicit encoding correction, not an equality claim for the defective source case.
uncensored <- c(1, 2, 1, 2)
check(!"0" %in% levels(old_cr$cr_status(uncensored)$status_fac), "before source omits unobserved censor level")
fixed <- cr$cr_status(uncensored)
check(identical(levels(fixed$status_fac), c("0", "1", "2")), "after retains zero censor state with no censored records")
fixed_aj <- cr$aalen_johansen(1:4, fixed$status_fac, 0:4)
for (code in 1:2) check(max(abs(fixed_aj$cif[fixed_aj$code == code] - vapply(0:4, function(at) oracle(1:4, uncensored, at, code), 0))) < 1e-12, "no-censor AJ agrees with independent first-event arithmetic")

# Public conditional guards execute without guessing missing scientific choices.
a <- list(`dataset-name` = "Invented native contract", `nonph-primary` = "cox", `nonph-transforms` = "km,rank,identity,log", `nonph-magnitude` = .2, `ph-transform` = "km")
check(os_srv_extension_contract(a, "nonph"), "complete declared non-PH contract")
b <- a; b[["nonph-magnitude"]] <- NULL; refuse(os_srv_extension_contract(b, "nonph"), "OS_MISSING_PARAMETER")
b <- a; b[["nonph-primary"]] <- "automatic"; refuse(os_srv_extension_contract(b, "nonph"), "OS_INVALID_PARAMETER")
b <- a; b[["nonph-transforms"]] <- "rank,rank"; refuse(os_srv_extension_contract(b, "nonph"), "OS_INVALID_PARAMETER")
b <- a; b[["piecewise-cuts"]] <- "1,2"; refuse(os_srv_extension_contract(b, "nonph"), "OS_INVALID_PARAMETER")
refuse(os_srv_numbers("2,1", "cuts"), "OS_INVALID_PARAMETER")
refuse(os_srv_numbers("1,1", "cuts"), "OS_INVALID_PARAMETER")
refuse(os_srv_numbers("0,Inf", "times"), "OS_INVALID_PARAMETER")
check(check_calls(list.files(file.path(mod, "scripts"), pattern = "\\.R$", full.names = TRUE), file.path(mod, "scripts/calls_registry.json"))$ok, "native parse and site-specific call registry")
cat("Native contract/source-copy tests complete; real anchor, full CLI, CI/Gray and owner review are separate.\n")
