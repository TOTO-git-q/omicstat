# Copied and adapted, not reimplemented: TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa
# skills/sample-size/scripts/samplesize_engines.R, blob fb444cad3727918bf3ec9a2adf7675a535786229.
# Original module declares MIT. Exact source and line ranges are bound in PORT_SOURCE.json.
# Included designs: independent means, paired means, two proportions, ANOVA, log-rank events.
# Native formula calls and rounding are preserved. The integer search now checks
# its lower endpoint and ensures both arms contain at least two units; see PORT_ADAPTATIONS.json.
# Changes here: map MS_* to registered OS_* codes; replace the install suggestion.
# This file is loaded in a private environment. No MedStat path/library/MCP is used.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

.load_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("OS_MISSING_PACKAGE: package '%s' is required for this design and unavailable in the independent OmicStat environment for '%s'; no substitute computation is run.", pkg, pkg), call. = FALSE)
  }
  invisible(TRUE)
}

.sided_alt <- function(sided) {
  sided <- tolower(sided %||% "two")
  if (sided %in% c("two", "two.sided", "2")) "two.sided"
  else if (sided %in% c("one", "one.sided", "1", "greater")) "greater"
  else stop(sprintf("OS_INVALID_PARAMETER: --sided must be 'two' or 'one', got '%s'.", sided), call. = FALSE)
}
.sided_n <- function(sided) if (identical(.sided_alt(sided), "two.sided")) 2 else 1

.ceil1 <- function(x) as.integer(ceiling(x))

# ---------------------------------------------------------------------------
# Shared input-domain guards, called at the top of every engine. Round-1 only
# guarded a handful of zero-effect degeneracies (p1==p2, p==p0, r==0,
# hr==1/hr<=0); everything else -- a negative --sd, an out-of-range
# proportion/correlation, --power >= 1 -- either shipped a nonsense answer at
# exit 0 or died deep inside uniroot/atanh/asin with a raw R traceback
# instead of this module's own OS_INVALID_PARAMETER convention. These are the
# single shared implementation every engine below calls, so a fix here fixes
# every design at once rather than needing 18 hand-written duplicates.
.check_alpha_power <- function(alpha, power) {
  if (!is.null(alpha) && !is.na(alpha) && (alpha <= 0 || alpha >= 1))
    stop(sprintf("OS_INVALID_PARAMETER: --alpha must be strictly between 0 and 1, got %s.", alpha), call. = FALSE)
  if (!is.null(power) && !is.na(power) && (power <= 0 || power >= 1))
    stop(sprintf("OS_INVALID_PARAMETER: --power must be strictly between 0 and 1 (a power of 1, or 100%%, implies an infinite sample size -- there is no finite N that guarantees certainty), got %s.", power), call. = FALSE)
}
.check_prop01 <- function(x, name) {
  if (is.null(x) || length(x) == 0 || any(is.na(x)) || any(x <= 0) || any(x >= 1))
    stop(sprintf("OS_INVALID_PARAMETER: --%s must be strictly between 0 and 1, got %s.",
                 name, if (is.null(x) || length(x) == 0) "NULL" else paste(x, collapse = ",")), call. = FALSE)
}
.check_corr <- function(x, name) {
  if (is.null(x) || is.na(x) || x <= -1 || x >= 1)
    stop(sprintf("OS_INVALID_PARAMETER: --%s must be strictly between -1 and 1, got %s.", name, if (is.null(x)) "NULL" else x), call. = FALSE)
}
.check_pos <- function(x, name) {
  if (is.null(x) || is.na(x) || x <= 0)
    stop(sprintf("OS_INVALID_PARAMETER: --%s must be a positive number, got %s.", name, if (is.null(x)) "NULL" else x), call. = FALSE)
}

# Binary-search n1 (group 1 size) so that a two-arm design with
# n2 = ratio * n1 reaches at least `target_power`, using an ALREADY-VALIDATED
# power(n1, n2, ...) function (never a new closed-form n formula). Monotone
# non-decreasing in n1 for every design pwr exposes an *2n.test for, so
# bisection is exact up to integer rounding.
.bisect_n1 <- function(power_at, target_power, lo = 2, hi = 200000) {
  if (!is.finite(lo) || lo > hi) {
    stop("OS_CONVERGENCE: allocation requires a lower search bound beyond n1=200000.", call. = FALSE)
  }
  if (power_at(lo) >= target_power) return(lo)
  if (power_at(hi) < target_power) {
    stop("OS_CONVERGENCE: target power is not reachable for n1 up to 200000 at this effect size/ratio -- check the effect size and allocation ratio.", call. = FALSE)
  }
  while (hi - lo > 1) {
    mid <- floor((lo + hi) / 2)
    if (power_at(mid) >= target_power) hi <- mid else lo <- mid
  }
  hi
}

ss_mean_2sample <- function(mean1, mean2, sd = NULL, sd1 = NULL, sd2 = NULL,
                             alpha = 0.05, power = 0.8, sided = "two", ratio = 1) {
  .load_pkg("pwr")
  .check_alpha_power(alpha, power)
  if (isTRUE(all.equal(mean1, mean2))) stop("OS_INVALID_PARAMETER: --mean1 and --mean2 are equal; the effect size is zero and no finite sample size reaches the requested power.", call. = FALSE)
  sd_pooled <- if (!is.null(sd)) sd else if (!is.null(sd1) && !is.null(sd2)) sqrt((sd1^2 + sd2^2) / 2) else
    stop("OS_INVALID_PARAMETER: mean_2sample needs --sd (common SD) or both --sd1 and --sd2.", call. = FALSE)
  if (!is.null(sd)) .check_pos(sd, "sd") else { .check_pos(sd1, "sd1"); .check_pos(sd2, "sd2") }
  d <- abs(mean1 - mean2) / sd_pooled
  alt <- .sided_alt(sided)
  if (abs(ratio - 1) < 1e-9) {
    r <- pwr::pwr.t.test(d = d, sig.level = alpha, power = power, type = "two.sample", alternative = alt)
    n1 <- .ceil1(r$n); n2 <- n1
  } else {
    power_at <- function(n1) pwr::pwr.t2n.test(n1 = n1, n2 = ceiling(n1 * ratio), d = d, sig.level = alpha, alternative = alt)$power
    n1 <- .bisect_n1(power_at, power, lo = max(2, floor(1 / ratio) + 1)); n2 <- .ceil1(n1 * ratio)
  }
  list(design = "mean_2sample", family = "Two independent means (t-test)",
       n1 = n1, n2 = n2, n_total = n1 + n2, events = NA_integer_,
       effect = list(name = "Cohen's d", value = d), alpha = alpha, power = power,
       sided = sided, ratio = ratio,
       assumptions = list(mean1 = mean1, mean2 = mean2, sd_pooled = sd_pooled),
       engine = if (abs(ratio - 1) < 1e-9) "pwr::pwr.t.test (type='two.sample')" else "pwr::pwr.t2n.test (integer allocation search)",
       citation = "Cohen J. Statistical Power Analysis for the Behavioral Sciences. 2nd ed. 1988.")
}

# ============================================================================
# 2. Paired means (paired t-test)
# ============================================================================
ss_mean_paired <- function(mean_diff, sd_diff = NULL, sd1 = NULL, sd2 = NULL, corr = NULL,
                            alpha = 0.05, power = 0.8, sided = "two") {
  .load_pkg("pwr")
  .check_alpha_power(alpha, power)
  if (isTRUE(all.equal(mean_diff, 0))) stop("OS_INVALID_PARAMETER: --mean-diff is 0; the effect size is zero and no finite sample size reaches the requested power.", call. = FALSE)
  if (!is.null(corr)) .check_corr(corr, "corr")
  sdd <- if (!is.null(sd_diff)) sd_diff else if (!is.null(sd1) && !is.null(sd2) && !is.null(corr))
    sqrt(sd1^2 + sd2^2 - 2 * corr * sd1 * sd2) else
    stop("OS_INVALID_PARAMETER: mean_paired needs --sd-diff, or all of --sd1/--sd2/--corr.", call. = FALSE)
  if (!is.null(sd_diff)) .check_pos(sd_diff, "sd-diff") else { .check_pos(sd1, "sd1"); .check_pos(sd2, "sd2") }
  if (is.na(sdd) || sdd <= 0) stop(sprintf("OS_INVALID_PARAMETER: the derived SD of the differences (sqrt(sd1^2+sd2^2-2*corr*sd1*sd2)) is not a positive number (got %s) -- check --sd1/--sd2/--corr are consistent.", sdd), call. = FALSE)
  d <- abs(mean_diff) / sdd
  alt <- .sided_alt(sided)
  r <- pwr::pwr.t.test(d = d, sig.level = alpha, power = power, type = "paired", alternative = alt)
  n <- .ceil1(r$n)
  list(design = "mean_paired", family = "Paired means (paired t-test)",
       n1 = n, n2 = n, n_total = n, events = NA_integer_,
       effect = list(name = "Cohen's d (paired)", value = d), alpha = alpha, power = power,
       sided = sided, ratio = 1,
       assumptions = list(mean_diff = mean_diff, sd_diff = sdd),
       engine = "pwr::pwr.t.test (type='paired')",
       citation = "Cohen J. Statistical Power Analysis for the Behavioral Sciences. 2nd ed. 1988.")
}

ss_prop_2sample <- function(p1, p2, alpha = 0.05, power = 0.8, sided = "two", ratio = 1) {
  .load_pkg("pwr")
  .check_alpha_power(alpha, power)
  .check_prop01(p1, "p1"); .check_prop01(p2, "p2")
  if (isTRUE(all.equal(p1, p2))) stop("OS_INVALID_PARAMETER: --p1 and --p2 are equal; the effect size is zero and no finite sample size reaches the requested power.", call. = FALSE)
  # abs() here, exactly as ss_mean_2sample() abs()'s Cohen's d: direction is
  # carried by alternative= (from --sided), not by the arbitrary sign that
  # falls out of which proportion was typed first as --p1 vs --p2. Feeding a
  # signed h into pwr::pwr.2p.test()/pwr.2p2n.test() with a one-sided
  # alternative crashes uniroot whenever the sign of h disagrees with the
  # alternative's direction (h<0 with alternative='greater'); it also matches
  # the reporting convention (Cohen's h is conventionally reported unsigned).
  h <- abs(pwr::ES.h(p1 = p1, p2 = p2))
  alt <- .sided_alt(sided)
  if (abs(ratio - 1) < 1e-9) {
    r <- pwr::pwr.2p.test(h = h, sig.level = alpha, power = power, alternative = alt)
    n1 <- .ceil1(r$n); n2 <- n1
  } else {
    power_at <- function(n1) pwr::pwr.2p2n.test(h = h, n1 = n1, n2 = ceiling(n1 * ratio), sig.level = alpha, alternative = alt)$power
    n1 <- .bisect_n1(power_at, power, lo = max(2, floor(1 / ratio) + 1)); n2 <- .ceil1(n1 * ratio)
  }
  list(design = "prop_2sample", family = "Two independent proportions",
       n1 = n1, n2 = n2, n_total = n1 + n2, events = NA_integer_,
       effect = list(name = "Cohen's h (arcsine)", value = h), alpha = alpha, power = power,
       sided = sided, ratio = ratio,
       assumptions = list(p1 = p1, p2 = p2),
       engine = "pwr::pwr.2p.test / pwr.2p2n.test (arcsine-transform h, Cohen 1988)",
       citation = "Cohen J. Statistical Power Analysis for the Behavioral Sciences. 2nd ed. 1988.")
}

ss_anova <- function(k, f = NULL, means = NULL, sd = NULL, alpha = 0.05, power = 0.8) {
  .load_pkg("pwr")
  .check_alpha_power(alpha, power)
  if (is.null(f)) {
    if (is.null(means) || is.null(sd)) stop("OS_INVALID_PARAMETER: anova needs --f directly, or --means (comma list) and --sd.", call. = FALSE)
    if (length(means) != k) stop(sprintf("OS_INVALID_PARAMETER: --means has %d values but --k=%d groups.", length(means), k), call. = FALSE)
    .check_pos(sd, "sd")
    grand <- mean(means)
    f <- sqrt(mean((means - grand)^2)) / sd
  }
  if (isTRUE(all.equal(f, 0))) stop("OS_INVALID_PARAMETER: Cohen's f is 0 (--f 0, or --means are all equal); the effect size is zero and no finite sample size reaches the requested power.", call. = FALSE)
  r <- pwr::pwr.anova.test(k = k, f = f, sig.level = alpha, power = power)
  n_per <- .ceil1(r$n)
  list(design = "anova", family = "One-way ANOVA (k groups)",
       n1 = n_per, n2 = NA_integer_, n_total = n_per * k, events = NA_integer_,
       effect = list(name = "Cohen's f", value = f), alpha = alpha, power = power,
       sided = "two", ratio = NA_real_,
       assumptions = list(k = k, means = means, sd = sd),
       engine = "pwr::pwr.anova.test",
       citation = "Cohen J. Statistical Power Analysis for the Behavioral Sciences. 2nd ed. 1988.")
}

ss_survival_logrank <- function(hr, alpha = 0.05, power = 0.8, sided = "two", ratio = 1,
                                 event_prob = NULL) {
  .load_pkg("gsDesign")
  .check_alpha_power(alpha, power)
  .check_pos(ratio, "ratio")
  if (is.null(hr) || is.na(hr) || hr <= 0) stop("OS_INVALID_PARAMETER: --hr must be a positive number.", call. = FALSE)
  if (isTRUE(all.equal(hr, 1))) stop("OS_INVALID_PARAMETER: --hr is 1 (no effect); no finite number of events reaches the requested power against a null of no difference.", call. = FALSE)
  events <- .ceil1(gsDesign::nEvents(hr = hr, alpha = alpha, sided = .sided_n(sided),
                                      beta = 1 - power, ratio = ratio))
  # Build the per-arm split the SAME way every other two-arm design does:
  # n1 first (the smaller/reference arm, from the raw pre-ceiling total),
  # then n2 = ceil(n1 * ratio) -- never n_total - n1. Building n2 as a
  # remainder made n1/n2 co-prime by construction whenever the raw total was
  # odd (e.g. 247 events, ratio=1 -> 124/123), so the allocation-ratio phrase
  # derived from them (samplesize_report.R's .ratio_phrase()) reduced to a
  # nonsensical "124:123" instead of the intended "1:1"/"1:2"/etc. n_total is
  # then DEFINED as n1+n2 (never computed independently), the same
  # ceil-the-components-then-sum discipline used everywhere else two related
  # totals are printed side by side (see run_samplesize.R's recruit_n and
  # ss_diagnostic_auc below) -- so the printed total can never disagree with
  # the printed arm sizes a few words later in the same sentence. This can
  # round n_total up by at most 1-2 participants versus events/event_prob
  # exactly; that is conservative (more, not fewer, participants than the
  # minimum), never a correctness problem.
  if (!is.null(event_prob) && (is.na(event_prob) || event_prob <= 0 || event_prob > 1))
    stop("OS_INVALID_PARAMETER: --event-prob must be in (0, 1].", call. = FALSE)
  n_total_target <- if (!is.null(event_prob)) events / event_prob else NA_real_
  n1 <- if (!is.na(n_total_target)) .ceil1(n_total_target / (1 + ratio)) else NA_integer_
  n2 <- if (!is.na(n_total_target)) .ceil1(n1 * ratio) else NA_integer_
  n_total <- if (!is.na(n_total_target)) n1 + n2 else NA_integer_
  list(design = "survival_logrank", family = "Two-group survival (log-rank test, Schoenfeld events)",
       n1 = n1, n2 = n2, n_total = n_total, events = events,
       effect = list(name = "hazard ratio", value = hr), alpha = alpha, power = power,
       sided = sided, ratio = ratio,
       assumptions = list(hr = hr, event_prob = event_prob),
       engine = "gsDesign::nEvents (Schoenfeld 1981)",
       citation = "Schoenfeld DA. The asymptotic properties of nonparametric tests for comparing survival distributions. Biometrika 1981;68(1):316-319.",
       # provenance_note: build-process/audit provenance, never a citation --
       # kept out of `citation` so it cannot leak into the paste-ready
       # Methods sentence; written instead under provenance/ by run_samplesize.R.
       provenance_note = "Original MedStat source states the following historical audit; not a new OmicStat validation: Cross-validated in this module's audit (research/phase2/audit3p-sample-size.md) against 3 independent third-party implementations that all omitted the allocation factor and under-estimated events ~4-fold.")
}
