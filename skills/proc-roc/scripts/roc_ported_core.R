# Copied/adapted from TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa
# skills/diagnostic-accuracy/scripts/diagacc_core.R; independent OmicStat code.
# PORT_ADAPTATIONS.json records changes. Native numerical equivalence is not yet verified.
`%||%` <- function(a,b) if(is.null(a)||length(a)==0||(length(a)==1&&is.na(a))) b else a

.da_stop <- function(code, fmt, ...) stop(sprintf("%s: %s", code, sprintf(fmt, ...)), call. = FALSE)

cp_ci <- function(x, n, conf_level = 0.95) {
  n_len <- max(length(x), length(n))
  x <- rep_len(x, n_len); n <- rep_len(n, n_len)
  lo <- numeric(n_len); hi <- numeric(n_len)
  for (i in seq_len(n_len)) {
    xi <- x[i]; ni <- n[i]
    if (is.na(xi) || is.na(ni) || ni <= 0 || xi < 0 || xi > ni) { lo[i] <- NA_real_; hi[i] <- NA_real_; next }
    bt <- stats::binom.test(round(xi), round(ni), conf.level = conf_level)
    lo[i] <- bt$conf.int[1]; hi[i] <- bt$conf.int[2]
  }
  list(lo = lo, hi = hi)
}

wilson_ci <- function(x, n, conf_level = 0.95) {
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  n_len <- max(length(x), length(n))
  x <- rep_len(x, n_len); n <- rep_len(n, n_len)
  lo <- numeric(n_len); hi <- numeric(n_len)
  for (i in seq_len(n_len)) {
    xi <- x[i]; ni <- n[i]
    if (is.na(xi) || is.na(ni) || ni <= 0) { lo[i] <- NA_real_; hi[i] <- NA_real_; next }
    p <- xi / ni
    denom <- 1 + z^2 / ni
    center <- (p + z^2 / (2 * ni)) / denom
    half <- (z * sqrt((p * (1 - p) + z^2 / (4 * ni)) / ni)) / denom
    lo[i] <- max(0, center - half); hi[i] <- min(1, center + half)
  }
  list(lo = lo, hi = hi)
}

ci_engine <- function(ci_method) {
  if (identical(ci_method, "wilson")) wilson_ci else cp_ci
}

accuracy_from_counts <- function(tp, fn, fp, tn, conf_level = 0.95, ci_method = "exact") {
  n_pos <- tp + fn; n_neg <- fp + tn
  n_test_pos <- tp + fp; n_test_neg <- fn + tn
  n_analysed <- tp + fn + fp + tn
  ci_fn <- ci_engine(ci_method)
  se_ci  <- ci_fn(tp, n_pos, conf_level)
  sp_ci  <- ci_fn(tn, n_neg, conf_level)
  ppv_ci <- ci_fn(tp, n_test_pos, conf_level)
  npv_ci <- ci_fn(tn, n_test_neg, conf_level)
  acc_ci <- ci_fn(tp + tn, n_analysed, conf_level)
  sens <- ifelse(n_pos > 0, tp / n_pos, NA_real_)
  spec <- ifelse(n_neg > 0, tn / n_neg, NA_real_)
  list(
    tp = tp, fn = fn, fp = fp, tn = tn,
    n_positive = n_pos, n_negative = n_neg,
    n_test_pos = n_test_pos, n_test_neg = n_test_neg, n_analysed = n_analysed,
    sens = sens, sens_lo = se_ci$lo, sens_hi = se_ci$hi,
    spec = spec, spec_lo = sp_ci$lo, spec_hi = sp_ci$hi,
    ppv = ifelse(n_test_pos > 0, tp / n_test_pos, NA_real_), ppv_lo = ppv_ci$lo, ppv_hi = ppv_ci$hi,
    npv = ifelse(n_test_neg > 0, tn / n_test_neg, NA_real_), npv_lo = npv_ci$lo, npv_hi = npv_ci$hi,
    acc = ifelse(n_analysed > 0, (tp + tn) / n_analysed, NA_real_), acc_lo = acc_ci$lo, acc_hi = acc_ci$hi,
    # DA-M02: J is ALWAYS this formula, never coords(..., ret="youden").
    youden_j = sens + spec - 1,
    ci_method = ci_method, conf_level = conf_level
  )
}

simel_lr <- function(tp, fn, fp, tn, conf_level = 0.95) {
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  n_pos <- tp + fn; n_neg <- fp + tn
  sens <- tp / n_pos; spec <- tn / n_neg
  lr_pos <- if (fp == 0) { if (sens == 0) NaN else Inf } else sens / (1 - spec)
  lr_neg <- if (tn == 0) { if (sens == 1) NaN else 0 } else (1 - sens) / spec
  if (tp > 0 && fn > 0 && fp > 0 && tn > 0) {
    se_log_lrpos <- sqrt(1 / tp - 1 / n_pos + 1 / fp - 1 / n_neg)
    se_log_lrneg <- sqrt(1 / fn - 1 / n_pos + 1 / tn - 1 / n_neg)
    lrpos_lo <- exp(log(lr_pos) - z * se_log_lrpos); lrpos_hi <- exp(log(lr_pos) + z * se_log_lrpos)
    lrneg_lo <- exp(log(lr_neg) - z * se_log_lrneg); lrneg_hi <- exp(log(lr_neg) + z * se_log_lrneg)
  } else {
    lrpos_lo <- NA_real_; lrpos_hi <- NA_real_; lrneg_lo <- NA_real_; lrneg_hi <- NA_real_
  }
  dor <- lr_pos / lr_neg
  # DOR CI: the standard log-odds-ratio delta-method interval for a 2x2 table
  # (dor = tp*tn / (fp*fn); se(log dor) = sqrt(1/tp+1/fn+1/fp+1/tn)) -- this is
  # generic 2x2 methodology, not attributed to Simel 1991 (that paper covers
  # LR+/LR- only); kept alongside simel_lr() because the primary accuracy
  # table (spec section 14.5) reports a CI for DOR too, and NA-with-notes when
  # any cell is zero, same guard as the LR CIs above.
  if (tp > 0 && fn > 0 && fp > 0 && tn > 0) {
    se_log_dor <- sqrt(1 / tp + 1 / fn + 1 / fp + 1 / tn)
    dor_lo <- exp(log(dor) - z * se_log_dor); dor_hi <- exp(log(dor) + z * se_log_dor)
  } else {
    dor_lo <- NA_real_; dor_hi <- NA_real_
  }
  list(lr_pos = lr_pos, lr_pos_lo = lrpos_lo, lr_pos_hi = lrpos_hi,
       lr_neg = lr_neg, lr_neg_lo = lrneg_lo, lr_neg_hi = lrneg_hi,
       dor = dor, dor_lo = dor_lo, dor_hi = dor_hi,
       has_zero_cell = any(c(tp, fn, fp, tn) == 0))
}

simel_lr_cc <- function(tp, fn, fp, tn, conf_level = 0.95) {
  simel_lr(tp + 0.5, fn + 0.5, fp + 0.5, tn + 0.5, conf_level = conf_level)
}

project_pv <- function(sens, spec, prevalence) {
  ppv <- (sens * prevalence) / (sens * prevalence + (1 - spec) * (1 - prevalence))
  npv <- (spec * (1 - prevalence)) / (spec * (1 - prevalence) + (1 - sens) * prevalence)
  list(ppv = ppv, npv = npv)
}

prevalence_projection_table <- function(sens, spec, prevalence_grid, sample_prevalence) {
  grid <- sort(unique(c(prevalence_grid, sample_prevalence)))
  proj <- project_pv(sens, spec, grid)
  data.frame(
    prevalence = grid,
    is_sample_prevalence = abs(grid - sample_prevalence) < 1e-9,
    ppv = proj$ppv, npv = proj$npv,
    stringsAsFactors = FALSE
  )
}

build_roc <- function(response, predictor, levels, direction) {
  if (!direction %in% c("<", ">")) .da_stop("OS_INVALID_PARAMETER", "build_roc() direction must be '<' or '>', got '%s'.", direction)
  pROC::roc(response = response, predictor = predictor, levels = levels, direction = direction,
            quiet = TRUE, ci = FALSE)
}

fit_full_roc <- function(response, predictor, levels, direction, conf_level = 0.95) {
  r <- build_roc(response, predictor, levels, direction)
  est <- as.numeric(pROC::auc(r))
  ci <- as.numeric(pROC::ci.auc(r, method = "delong", conf.level = conf_level))
  list(roc = r, auc = est, ci_low = ci[1], ci_high = ci[3], method = "pROC::ci.auc(method='delong')")
}

fit_partial_roc <- function(response, predictor, levels, direction, pauc_range, pauc_focus,
                             boot_n = 2000, seed, conf_level = 0.95) {
  if (is.null(seed) || !is.finite(seed)) .da_stop("OS_MISSING_PARAMETER", "a partial-AUC bootstrap requires --seed.")
  if (!pauc_focus %in% c("specificity", "sensitivity")) {
    .da_stop("OS_INVALID_PARAMETER", "pauc_focus must be 'specificity' or 'sensitivity', got '%s'.", pauc_focus)
  }
  set.seed(seed)
  rp <- pROC::roc(response = response, predictor = predictor, levels = levels, direction = direction,
                   quiet = TRUE, ci = FALSE, partial.auc = pauc_range, partial.auc.focus = pauc_focus,
                   partial.auc.correct = FALSE)
  est <- as.numeric(rp$auc)
  ci <- as.numeric(pROC::ci.auc(rp, method = "bootstrap", boot.n = boot_n, conf.level = conf_level))
  list(roc = rp, auc = est, ci_low = ci[1], ci_high = ci[3], boot_n = boot_n, seed = seed,
       focus = pauc_focus, range = pauc_range, method = "pROC::ci.auc(method='bootstrap')")
}

direction_auto_check <- function(response, predictor, levels, declared_direction, declared_auc) {
  r_auto <- pROC::roc(response = response, predictor = predictor, levels = levels, direction = "auto", quiet = TRUE)
  auto_direction <- r_auto$direction
  auto_auc <- as.numeric(pROC::auc(r_auto))
  list(auto_direction = auto_direction, auto_auc = auto_auc,
       agrees = identical(auto_direction, declared_direction),
       declared_auc = declared_auc)
}

.round_counts <- function(df) {
  for (cn in c("tp", "fn", "fp", "tn")) if (cn %in% names(df)) df[[cn]] <- round(df[[cn]])
  df
}

roc_counts_at <- function(r, x) {
  out <- pROC::coords(r, x = x, input = "threshold", ret = c("threshold", "tp", "fn", "fp", "tn"), transpose = FALSE)
  .round_counts(as.data.frame(out))
}

roc_best_cutoff <- function(r, best_method = c("youden", "closest.topleft")) {
  best_method <- match.arg(best_method)
  out <- pROC::coords(r, x = "best", best.method = best_method,
                       ret = c("threshold", "tp", "fn", "fp", "tn"), transpose = FALSE)
  df <- as.data.frame(out)
  if (nrow(df) > 1) df <- df[1, , drop = FALSE]  # tie-break: pROC returns >1 row on an exact tie; keep the first, documented in notes upstream
  .round_counts(df)
}

assert_paired_sets <- function(idx_a, idx_b) {
  if (!identical(sort(idx_a), sort(idx_b))) {
    n1 <- length(idx_a); n2 <- length(idx_b)
    n_diff <- length(union(setdiff(idx_a, idx_b), setdiff(idx_b, idx_a)))
    .da_stop("OS_INVALID_DESIGN",
             "paired comparison requested but the two index tests have different analysis samples (n = %d vs %d; %d participant(s) differ). A paired DeLong test is not valid here.",
             n1, n2, n_diff)
  }
  invisible(TRUE)
}

paired_delong <- function(roc_a, roc_b, conf_level = 0.95) {
  rt <- pROC::roc.test(roc_a, roc_b, method = "delong", paired = TRUE, conf.level = conf_level)
  auc_a <- as.numeric(pROC::auc(roc_a)); auc_b <- as.numeric(pROC::auc(roc_b))
  list(auc_a = auc_a, auc_b = auc_b, auc_diff = auc_a - auc_b,
       ci_low = unname(rt$conf.int[1]), ci_high = unname(rt$conf.int[2]),
       statistic = unname(rt$statistic), p_value = rt$p.value,
       test_name = "pROC::roc.test(method='delong', paired=TRUE)")
}

cutoff_ci_coords <- function(r, best_method = c("youden", "closest.topleft"), boot_n = 2000, seed,
                              conf_level = 0.95) {
  best_method <- match.arg(best_method)
  if (is.null(seed) || !is.finite(seed)) .da_stop("OS_MISSING_PARAMETER", "a data-driven cut-off's bootstrap interval requires --seed.")
  set.seed(seed)
  cc <- pROC::ci.coords(r, x = "best", input = "threshold", best.method = best_method,
                         ret = c("threshold", "sensitivity", "specificity"),
                         boot.n = boot_n, conf.level = conf_level)
  list(threshold_lo = cc$threshold[1, 1], threshold_hi = cc$threshold[1, 3],
       sens_lo = cc$sensitivity[1, 1], sens_hi = cc$sensitivity[1, 3],
       spec_lo = cc$specificity[1, 1], spec_hi = cc$specificity[1, 3],
       boot_n = boot_n, seed = seed)
}

loo_cutoff_validation <- function(response, predictor, levels, direction, best_method = c("youden", "closest.topleft")) {
  best_method <- match.arg(best_method)
  n <- length(response)
  pred_pos <- rep(NA, n)
  for (i in seq_len(n)) {
    ri <- response[-i]; pi <- predictor[-i]
    rr <- tryCatch(build_roc(ri, pi, levels, direction), error = function(e) NULL)
    if (is.null(rr)) next
    cut_i <- tryCatch(pROC::coords(rr, x = "best", best.method = best_method, ret = "threshold"),
                       error = function(e) NULL)
    if (is.null(cut_i)) next
    cut_val <- if (is.data.frame(cut_i) || is.matrix(cut_i)) as.numeric(cut_i[1, 1]) else as.numeric(cut_i)[1]
    # Boundary convention matches roc_counts_at()/pROC's own coords() exactly
    # (verified directly: coords()'s tp/fn/fp/tn at a non-tied threshold agree
    # with a manual ">= cutoff" ("<" direction) / "<= cutoff" (">" direction)
    # classification bit-for-bit on aSAH; see the module's smoke test).
    pred_pos[i] <- if (direction == "<") (predictor[i] >= cut_val) else (predictor[i] <= cut_val)
  }
  actual_pos <- response == levels[2]
  ok <- !is.na(pred_pos)
  tp <- sum(pred_pos[ok] & actual_pos[ok]); fn <- sum(!pred_pos[ok] & actual_pos[ok])
  fp <- sum(pred_pos[ok] & !actual_pos[ok]); tn <- sum(!pred_pos[ok] & !actual_pos[ok])
  list(tp = tp, fn = fn, fp = fp, tn = tn, n_folds_ok = sum(ok), n_folds_failed = sum(!ok))
}

participant_flow <- function(n_input, n_excl_missing_index, n_excl_missing_reference,
                              n_excl_indeterminate_index, n_excl_indeterminate_reference,
                              n_excl_other, n_analysed, n_positive, n_negative, tp, fn, tn, fp) {
  total_excl <- n_excl_missing_index + n_excl_missing_reference + n_excl_indeterminate_index +
    n_excl_indeterminate_reference + n_excl_other
  id1 <- (n_input - total_excl) == n_analysed
  id2 <- (n_positive + n_negative) == n_analysed
  id3 <- (tp + fn) == n_positive
  id4 <- (tn + fp) == n_negative
  list(
    n_input = n_input, n_excl_missing_index = n_excl_missing_index,
    n_excl_missing_reference = n_excl_missing_reference,
    n_excl_indeterminate_index = n_excl_indeterminate_index,
    n_excl_indeterminate_reference = n_excl_indeterminate_reference,
    n_excl_other = n_excl_other, n_analysed = n_analysed,
    n_positive = n_positive, n_negative = n_negative,
    identities = list(
      flow_balances = id1, positive_negative_sum = id2,
      tp_fn_equals_positive = id3, tn_fp_equals_negative = id4
    ),
    ok = id1 && id2 && id3 && id4
  )
}
