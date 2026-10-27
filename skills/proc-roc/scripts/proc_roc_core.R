# Independent driver; estimators below call the pinned copied functions.
# Bootstrap internal validation retains the source's min(boot_n, 200) cap.
os_roc_bootstrap_validation <- function(p, response, predictor, levels_vec, direction, cutpoint_kind,
                                         boot_n, seed, conf_level) {
  set.seed(seed)
  n <- length(response); positive_class <- levels_vec[2]
  bs_se <- numeric(0); bs_sp <- numeric(0)
  for (b in seq_len(min(boot_n, 200))) {
    idx <- sample.int(n, n, replace = TRUE)
    oob <- setdiff(seq_len(n), unique(idx))
    if (!length(oob)) next
    rr <- tryCatch(p$build_roc(response[idx], predictor[idx], levels_vec, direction), error = function(e) NULL)
    if (is.null(rr)) next
    cut_b <- tryCatch(as.numeric(pROC::coords(rr, x = "best", best.method = cutpoint_kind, ret = "threshold"))[1], error = function(e) NA_real_)
    if (is.na(cut_b)) next
    pred_pos <- if (direction == "<") predictor[oob] >= cut_b else predictor[oob] <= cut_b
    act_pos <- response[oob] == positive_class
    if (sum(act_pos) == 0 || sum(!act_pos) == 0) next
    bs_se <- c(bs_se, sum(pred_pos & act_pos) / sum(act_pos))
    bs_sp <- c(bs_sp, sum(!pred_pos & !act_pos) / sum(!act_pos))
  }
  record <- list(requested_replicates = boot_n, attempted_replicates = min(boot_n, 200),
    successful_replicates = length(bs_se), failed_or_class_absent_replicates = min(boot_n, 200) - length(bs_se),
    cap_source = "Pinned MedStat run_diagacc.R internal-validation bootstrap min(boot_n,200); unchanged", seed = seed)
  if (length(bs_se) < 2L) return(list(accuracy = NULL, record = record))
  alpha_bs <- 1 - conf_level
  qs <- function(v) unname(stats::quantile(v, c(alpha_bs / 2, 1 - alpha_bs / 2), names = FALSE, type = 7))
  list(accuracy = list(sens = mean(bs_se), sens_lo = qs(bs_se)[1], sens_hi = qs(bs_se)[2],
    spec = mean(bs_sp), spec_lo = qs(bs_sp)[1], spec_hi = qs(bs_sp)[2], youden_j = mean(bs_se + bs_sp - 1)), record = record)
}
.os_roc_accuracy_rows <- function(acc, lr, cutpoint, role, ci_level, source, score, exploratory) {
  terms <- c("sensitivity", "specificity", "positive_predictive_value", "negative_predictive_value", "accuracy", "youden_j", "lr_positive", "lr_negative", "diagnostic_odds_ratio")
  data.frame(term = terms, marker = score, threshold = cutpoint, threshold_role = role, threshold_source = source,
    estimate = c(acc$sens, acc$spec, acc$ppv, acc$npv, acc$acc, acc$youden_j, lr$lr_pos, lr$lr_neg, lr$dor),
    ci_low = c(acc$sens_lo, acc$spec_lo, acc$ppv_lo, acc$npv_lo, acc$acc_lo, NA_real_, lr$lr_pos_lo, lr$lr_neg_lo, lr$dor_lo),
    ci_high = c(acc$sens_hi, acc$spec_hi, acc$ppv_hi, acc$npv_hi, acc$acc_hi, NA_real_, lr$lr_pos_hi, lr$lr_neg_hi, lr$dor_hi),
    ci_level = ci_level, numerator = c(acc$tp, acc$tn, acc$tp, acc$tn, acc$tp + acc$tn, rep(NA_real_, 4)),
    denominator = c(acc$n_positive, acc$n_negative, acc$n_test_pos, acc$n_test_neg, acc$n_analysed, rep(NA_real_, 4)),
    ci_method = c(rep(acc$ci_method, 5), "none", "Simel_log_normal", "Simel_log_normal", "log_odds_delta_method"),
    exploratory = exploratory, stringsAsFactors = FALSE)
}
proc_roc_compute <- function(a) {
  x <- os_proc_roc_validate(a); p <- x$port
  if (!requireNamespace("pROC", quietly = TRUE) || identical(Sys.getenv("OMICSTAT_ROC_SIMULATE_MISSING", ""), "pROC"))
    .os_roc_stop("exact independent pROC closure is required; no automatic install or fallback", "OS_MISSING_PACKAGE")
  conf <- a[["confidence-level"]]; boot_n <- a[["bootstrap-reps"]]; seed <- a$seed
  response <- x$response; predictor <- x$scores[[1]][x$idx]; n <- length(response)
  np <- sum(response == x$levels[2]); nn <- sum(response == x$levels[1])
  q <- list(); tables <- list(); fits <- list(); comparisons <- list(); native <- list()
  label <- function(k) unname(x$labels[k])
  for (k in x$markers) {
    fit <- p$fit_full_roc(response, x$scores[[k]][x$idx], x$levels, x$direction, conf)
    fits[[k]] <- fit
    ac <- p$direction_auto_check(response, x$scores[[k]][x$idx], x$levels, x$direction, fit$auc)
    ac$declared_direction_label <- a$direction
    q[[paste0(k, "_direction")]] <- p$qc_da06(ac); q[[paste0(k, "_auc_half")]] <- p$qc_da07(fit$auc)
    q[[paste0(k, "_auc_ci")]] <- p$qc_da14(fit$auc, fit$ci_low, fit$ci_high, label(k))
  }
  primary <- fits[[1]]
  tables$auc_summary <- do.call(rbind, lapply(x$markers, function(k) {
    z <- fits[[k]]; data.frame(term = "full_auc", marker = k, marker_label = label(k), estimate = z$auc,
      ci_low = z$ci_low, ci_high = z$ci_high, ci_level = conf, ci_method = z$method, direction = a$direction,
      n_positive = np, n_negative = nn, n_independent = n, stringsAsFactors = FALSE)
  }))
  if (length(x$markers) > 1L) {
    for (k in x$markers[-1]) comparisons[[k]] <- p$paired_delong(primary$roc, fits[[k]]$roc, conf)
    tables$auc_comparison <- do.call(rbind, lapply(names(comparisons), function(k) {
      z <- comparisons[[k]]; data.frame(primary = x$primary, comparator = k, primary_label = label(x$primary), comparator_label = label(k),
        estimate = z$auc_diff, ci_low = z$ci_low, ci_high = z$ci_high, ci_level = conf,
        statistic = z$statistic, p_raw = z$p_value, method = z$test_name, paired = TRUE,
        family = a[["comparison-family"]], family_size = length(comparisons), p_adjust_method = a[["p-adjust"]],
        ci_adjustment = "none; pairwise pointwise CI; multiplicity adjustment applies to p-values only", stringsAsFactors = FALSE)
    }))
    tables$auc_comparison$p_adjusted <- stats::p.adjust(tables$auc_comparison$p_raw, method = a[["p-adjust"]], n = length(comparisons))
    tables$auc_comparison$inference_status <- ifelse(is.finite(tables$auc_comparison$p_raw), "estimated", "undefined_native_degenerate_variance")
    q$multiplicity <- p$qc_da22(length(comparisons), TRUE)
  }
  threshold <- x$threshold; acc <- NULL; lr <- NULL; validation <- NULL; cutoff_ci <- NULL
  if (x$exploratory) {
    youden <- p$roc_best_cutoff(primary$roc, "youden"); closest <- p$roc_best_cutoff(primary$roc, "closest.topleft")
    q$criteria <- p$qc_da10(youden$threshold, closest$threshold)
    chosen <- if (x$cutpoint_kind == "youden") youden else closest; threshold <- chosen$threshold
    .os_roc_num(threshold, "selected cutoff; infinite no-call boundary cannot be reported as a biomarker cutoff")
    # Preserve pROC's original default tie failure: never substitute random/omit.
    cutoff_ci <- p$cutoff_ci_coords(primary$roc, x$cutpoint_kind, boot_n, seed, conf)
    if (any(!is.finite(unlist(cutoff_ci[c("threshold_lo", "threshold_hi", "sens_lo", "sens_hi", "spec_lo", "spec_hi")]))))
      .os_roc_stop("ROC-12: cutoff-selection bootstrap did not return all finite uncertainty companions", "OS_INVALID_RESULT")
    if (a[["internal-validation"]] == "loo") {
      cv <- p$loo_cutoff_validation(response, predictor, x$levels, x$direction, x$cutpoint_kind)
      if (cv$n_folds_failed > 0 || cv$n_folds_ok != n) .os_roc_stop("ROC-12: incomplete LOO predictions; do not silently report a reduced validation set", "OS_INVALID_RESULT")
      cv_acc <- p$accuracy_from_counts(cv$tp, cv$fn, cv$fp, cv$tn, conf, a[["ci-method"]])
      validation <- list(accuracy = cv_acc, record = list(method = "loo", requested_replicates = n, attempted_replicates = n,
        successful_replicates = cv$n_folds_ok, failed_or_class_absent_replicates = cv$n_folds_failed,
        uncertainty = "Original descriptive fixed-threshold binomial intervals of pooled LOO predictions; folds are dependent, not a full CV-performance confidence interval"))
    } else if (a[["internal-validation"]] == "bootstrap") {
      validation <- os_roc_bootstrap_validation(p, response, predictor, x$levels, x$direction, x$cutpoint_kind, boot_n, seed, conf)
      validation$record$method <- "out-of-bag bootstrap mean of resample estimates"
      validation$record$uncertainty <- "original percentile interval across successful out-of-bag resamples; not pooled pseudo-independent counts"
      if (is.null(validation$accuracy)) .os_roc_stop("ROC-12: fewer than two valid original out-of-bag bootstrap resamples", "OS_INVALID_RESULT")
    } else {
      q$missing_validation <- p$qc_da12("internal validation (explicit allow-optimistic-cutpoint was requested; result stays unvalidated)")
      validation <- list(accuracy = NULL, record = list(method = "none", requested_replicates = 0L, attempted_replicates = 0L,
        successful_replicates = 0L, failed_or_class_absent_replicates = 0L, explicit_override = TRUE))
    }
    q$cutoff_instability <- p$qc_da13(threshold, cutoff_ci$threshold_lo, cutoff_ci$threshold_hi, conf)
    tables$cutoff_selection <- data.frame(criterion = x$cutpoint_kind, estimate = threshold,
      ci_low = cutoff_ci$threshold_lo, ci_high = cutoff_ci$threshold_hi, ci_level = conf,
      method = "pROC ci.coords reselects cutoff each stratified bootstrap", requested_bootstrap = boot_n,
      point_tie_rule = "first pROC best threshold (original source)", bootstrap_tie_rule = "pROC original stop default; never omit or choose random", exploratory = TRUE,
      stringsAsFactors = FALSE)
    if (!is.null(validation$accuracy)) {
      v <- validation$accuracy
      tables$cutoff_validation <- data.frame(term = c("sensitivity", "specificity", "youden_j"),
        estimate = c(v$sens, v$spec, v$youden_j), ci_low = c(v$sens_lo, v$spec_lo, NA_real_), ci_high = c(v$sens_hi, v$spec_hi, NA_real_),
        ci_level = conf, method = validation$record$method, interval_interpretation = validation$record$uncertainty,
        exploratory = TRUE, stringsAsFactors = FALSE)
    }
    tables$validation_accounting <- as.data.frame(validation$record, stringsAsFactors = FALSE)
  }
  if (x$cutpoint_kind != "none") {
    row <- p$roc_counts_at(primary$roc, threshold)
    acc <- p$accuracy_from_counts(row$tp, row$fn, row$fp, row$tn, conf, a[["ci-method"]])
    lr <- p$simel_lr(row$tp, row$fn, row$fp, row$tn, conf)
    tables$accuracy_primary <- .os_roc_accuracy_rows(acc, lr, threshold, x$cutpoint_kind, conf,
      if (x$exploratory) "derived on this dataset; exploratory apparent performance" else a[["cutpoint-source"]], x$primary, x$exploratory)
    tables$contingency <- data.frame(index_result = rep(c("positive", "negative"), 2), reference_class = rep(x$levels, each = 2),
      count = c(acc$fp, acc$tn, acc$tp, acc$fn), stringsAsFactors = FALSE)
    q$zero <- p$qc_da08(acc$tp, acc$fn, acc$fp, acc$tn); q$j <- p$qc_da09(acc$youden_j)
    q$continuity <- p$qc_da11(lr$has_zero_cell); q$endpoint <- p$qc_da18(acc$sens, acc$sens_lo, acc$sens_hi, acc$spec, acc$spec_lo, acc$spec_hi)
    q$sens_ci <- p$qc_da14(acc$sens, acc$sens_lo, acc$sens_hi, "Sensitivity"); q$spec_ci <- p$qc_da14(acc$spec, acc$spec_lo, acc$spec_hi, "Specificity")
    if (lr$has_zero_cell) {
      cc <- p$simel_lr_cc(acc$tp, acc$fn, acc$fp, acc$tn, conf)
      tables$lr_continuity_corrected <- data.frame(term = c("lr_positive", "lr_negative", "diagnostic_odds_ratio"), estimate = c(cc$lr_pos, cc$lr_neg, cc$dor),
        ci_low = c(cc$lr_pos_lo, cc$lr_neg_lo, cc$dor_lo), ci_high = c(cc$lr_pos_hi, cc$lr_neg_hi, cc$dor_hi), ci_level = conf,
        correction = "0.5 added to all four cells; sensitivity companion only, primary uncorrected", stringsAsFactors = FALSE)
    }
    grid <- sort(unique(c(x$cutpoints, threshold)))
    tables$cutpoint_table <- do.call(rbind, lapply(grid, function(v) {
      z <- p$roc_counts_at(primary$roc, v); ac <- p$accuracy_from_counts(z$tp, z$fn, z$fp, z$tn, conf, a[["ci-method"]])
      data.frame(threshold = v, tp = z$tp, fn = z$fn, fp = z$fp, tn = z$tn, sensitivity = ac$sens, sensitivity_low = ac$sens_lo, sensitivity_high = ac$sens_hi,
        specificity = ac$spec, specificity_low = ac$spec_lo, specificity_high = ac$spec_hi, ppv = ac$ppv, npv = ac$npv, youden_j = ac$youden_j,
        primary = isTRUE(all.equal(v, threshold)), ci_level = conf, exploratory = x$exploratory, stringsAsFactors = FALSE)
    }))
    if (!is.null(x$prevalence)) {
      tables$pv_by_prevalence <- p$prevalence_projection_table(acc$sens, acc$spec, x$prevalence, np / n)
      tables$pv_by_prevalence$assumption <- "Observed sensitivity and specificity held constant; assumed prevalence not estimated; no projected Se/Sp or fabricated CI"
      q$pv_transfer <- p$qc_da20(np / n, x$prevalence)
    }
    if (any(x$indeterminate)) {
      outcomes <- list(); keep_base <- !is.na(x$scores[[1]]) & !x$reference_missing & !x$indeterminate
      base_r <- p$build_roc(factor(x$reference_raw[keep_base], levels = x$levels), x$scores[[1]][keep_base], x$levels, x$direction)
      base_counts <- p$roc_counts_at(base_r, threshold); ind_values <- x$scores[[1]][x$indeterminate & !is.na(x$scores[[1]])]
      pred <- if (x$direction == "<") ind_values >= threshold else ind_values <= threshold
      for (policy in c("exclude", "positive", "negative")) {
        z <- base_counts
        if (policy == "positive") {z$tp <- z$tp + sum(pred); z$fn <- z$fn + sum(!pred)}
        if (policy == "negative") {z$fp <- z$fp + sum(pred); z$tn <- z$tn + sum(!pred)}
        ac <- p$accuracy_from_counts(z$tp, z$fn, z$fp, z$tn, conf, a[["ci-method"]]); l <- p$simel_lr(z$tp, z$fn, z$fp, z$tn, conf)
        t <- .os_roc_accuracy_rows(ac, l, threshold, x$cutpoint_kind, conf, "same primary threshold; no re-optimization in scenario", x$primary, TRUE)
        t$scenario <- policy; outcomes[[policy]] <- t
      }
      tables$indeterminate_sensitivity <- do.call(rbind, outcomes)
      q$indet <- p$qc_da16(sum(x$indeterminate), a$indeterminate, "tables/indeterminate_sensitivity.csv",
        if (a$indeterminate == "positive") label(x$levels[2]) else label(x$levels[1]))
    }
  } else if (!is.null(x$cutpoints)) .os_roc_stop("multi-cutpoint accuracy requires an explicitly selected primary cutoff in this adapter", "OS_CONFLICTING_PARAMETERS")
  # Both full and partial objects are independently fitted; no estimate/CI reuse.
  partial <- NULL
  if (!is.null(x$pauc)) {
    partial <- p$fit_partial_roc(response, predictor, x$levels, x$direction, x$pauc, a[["pauc-focus"]], boot_n, seed, conf)
    tables$partial_auc <- data.frame(term = "uncorrected_partial_auc", estimate = partial$auc, ci_low = partial$ci_low, ci_high = partial$ci_high,
      ci_level = conf, focus = partial$focus, bound_low = min(partial$range), bound_high = max(partial$range), partial_auc_corrected = FALSE,
      method = partial$method, bootstrap_reps = boot_n, stringsAsFactors = FALSE)
    q$pauc <- p$qc_da19(partial$focus, min(partial$range), max(partial$range), boot_n, seed)
    q$pauc_ci <- p$qc_da14(partial$auc, partial$ci_low, partial$ci_high, "uncorrected partial AUC")
  }
  q$small <- p$qc_da17(n, np, nn)
  q$missing <- p$qc_da01(sum(is.na(x$scores[[1]]) | x$reference_missing), length(x$ids), c(x$primary, a[["reference-col"]]), n)
  flow <- p$participant_flow(length(x$ids), x$exclusions['index'], x$exclusions['reference'], 0L, x$exclusions['indeterminate'], 0L, n, np, nn,
    if (is.null(acc)) NA_real_ else acc$tp, if (is.null(acc)) NA_real_ else acc$fn, if (is.null(acc)) NA_real_ else acc$tn, if (is.null(acc)) NA_real_ else acc$fp)
  flow$cutoff_counts_available <- !is.null(acc)
  if (is.null(acc)) {
    # Two confusion-count identities are not applicable without a cutoff.
    # Never fabricate TP/FN/TN/FP merely to make a boolean gate pass.
    flow$ok <- isTRUE(flow$identities$flow_balances) && isTRUE(flow$identities$positive_negative_sum)
    flow$not_applicable_identities <- c("tp_fn_equals_positive", "tn_fp_equals_negative")
  }
  if (!isTRUE(flow$ok)) .os_roc_stop("ROC-02: participant flow does not balance", "OS_INVALID_RESULT")
  if (!is.null(acc)) q$flow <- p$qc_da02(flow)
  tables$participant_flow <- data.frame(stage = c("input", "excluded_missing_marker", "excluded_missing_reference", "excluded_indeterminate", "analysed", "positive", "negative"),
    count = c(length(x$ids), x$exclusions['index'], x$exclusions['reference'], x$exclusions['indeterminate'], n, np, nn),
    rule = paste("Disjoint priority: indeterminate exclusion, missing primary marker, missing reference.",
      if (is.null(acc)) "Two population identities checked; two cutoff-count identities not applicable." else "All four accounting identities checked."), stringsAsFactors = FALSE)
  skipped <- character(); sg <- list()
  for (sv in x$subgroups) {
    values <- as.character(x$sheet[[sv]][x$idx])
    if (anyNA(values) || any(!nzchar(trimws(values)))) skipped <- c(skipped, paste(sv, "missing subgroup values excluded only from subgroup summaries"))
    for (lev in unique(values[!is.na(values) & nzchar(trimws(values))])) {
      sel <- !is.na(values) & values == lev
      if (sum(sel) < 5 || length(unique(response[sel])) != 2L) {skipped <- c(skipped, paste(sv, lev, "fewer than five or single-class")); next}
      rr <- p$build_roc(response[sel], predictor[sel], x$levels, x$direction); z <- p$roc_counts_at(rr, threshold)
      ac <- p$accuracy_from_counts(z$tp, z$fn, z$fp, z$tn, conf, a[["ci-method"]])
      sg[[length(sg) + 1L]] <- data.frame(subgroup = sv, subgroup_label = label(sv), level = lev, n_independent = sum(sel),
        sensitivity = ac$sens, sensitivity_low = ac$sens_lo, sensitivity_high = ac$sens_hi, specificity = ac$spec, specificity_low = ac$spec_lo,
        specificity_high = ac$spec_hi, ci_level = conf, exploratory = TRUE, stringsAsFactors = FALSE)
    }
  }
  if (length(sg)) tables$subgroup_accuracy <- do.call(rbind, sg)
  if (length(skipped)) {tables$subgroup_skipped <- data.frame(reason = skipped); q$subgroups <- p$qc_da23_subgroup_skipped(skipped)}
  tables$roc_curve <- do.call(rbind, lapply(x$markers, function(k) {
    z <- as.data.frame(pROC::coords(fits[[k]]$roc, x = "all", ret = c("specificity", "sensitivity"), transpose = FALSE))
    z <- z[order(z$specificity, decreasing = TRUE), , drop = FALSE]
    data.frame(point_id = paste0(k, ":", seq_len(nrow(z))), marker = k, marker_label = label(k), fpr = 1 - z$specificity, tpr = z$sensitivity,
      sequence = seq_len(nrow(z)), stringsAsFactors = FALSE)
  }))
  # The original plot's ci.se grid and bootstrap are now calculated once upstream.
  set.seed(seed)
  band <- pROC::ci.se(primary$roc, specificities = seq(0, 1, by = 0.02), boot.n = boot_n, conf.level = conf)
  tables$roc_band <- data.frame(point_id = paste0("primary_band:", seq_len(nrow(band))), marker = x$primary,
    fpr = 1 - as.numeric(rownames(band)), lower = band[, 1], median = band[, 2], upper = band[, 3],
    ci_level = conf, scope = "pointwise at prespecified specificity grid; not simultaneous", method = "pROC::ci.se stratified percentile bootstrap", bootstrap_reps = boot_n,
    stringsAsFactors = FALSE)
  if (!is.null(acc)) tables$cutoff_marker <- data.frame(id = "primary_cutoff", fpr = 1 - acc$spec, tpr = acc$sens,
    threshold = threshold, selection = x$cutpoint_kind, exploratory = x$exploratory, stringsAsFactors = FALSE)
  choices <- a[setdiff(names(a), c("outdir", "spec", "help"))]
  input_files <- list(measurements = x$path, sample_sheet = a[["sample-sheet"]], labels = a$labels, study_contract = a[["study-contract"]])
  inputs_hash <- lapply(input_files, function(path) digest::digest(file = path, algo = "sha256"))
  estimand <- list(choices = choices, input_hashes = inputs_hash, marker_order = x$markers, positive_class = x$levels[2], negative_class = x$levels[1],
    direction = a$direction, comparison_family = if (length(x$markers) > 1L) a[["comparison-family"]] else NULL,
    p_adjust = a[["p-adjust"]], cutoff_kind = x$cutpoint_kind, cutoff = threshold, exploratory = x$exploratory,
    bootstrap_requested = boot_n, internal_validation = if (is.null(validation)) NULL else validation$record)
  hash <- digest::digest(estimand, algo = "sha256")
  for (k in names(tables)) tables[[k]]$model_spec_hash <- hash
  tables$effect_table <- tables$auc_summary[c("term", "marker", "marker_label", "estimate", "ci_low", "ci_high", "ci_level", "ci_method", "model_spec_hash")]
  native <- list(fits = fits, comparisons = comparisons, accuracy = acc, likelihood_ratios = lr, cutoff = threshold, cutoff_ci = cutoff_ci,
    validation = validation, partial = partial, flow = flow, estimand = estimand, estimand_sha256 = hash,
    table_hashes = lapply(tables, function(z) digest::digest(z, algo = "sha256")))
  method <- paste("ROC/AUC discrimination of independent biological/test units. Positive class and common marker direction were supplied, never auto-flipped.",
    "Full AUC uses copied pROC DeLong CI; a separate object supplies any uncorrected partial AUC and its bootstrap CI.",
    "Accuracy uses explicitly selected", a[["ci-method"]], "intervals. Youden J is sensitivity + specificity - 1.",
    if (length(comparisons)) paste("Paired primary-versus-rest DeLong family; raw P values plus", a[["p-adjust"]], "adjustment over", length(comparisons), "comparisons. Difference CIs remain unadjusted pointwise.") else "Single marker; no comparison family.",
    if (x$exploratory) paste("EXPLORATORY cutoff optimized on these data. Apparent accuracy is optimistic; selection bootstrap and declared internal validation are separate quantities.",
      "Original internal-bootstrap attempt cap min(requested,200) is retained and reported. No validation override implies adequacy or external validation.") else "No data-driven cutoff selected.",
    "Predictive value projections, if requested, condition on supplied prevalence and observed Se/Sp stability. Discrimination is not calibration, validity or clinical utility.")
  res <- list(tables = tables, metadata = list(estimand = estimand, estimand_sha256 = hash, dataset_name = a[["dataset-name"]],
    dataset_name_is_user_declaration_not_owner_receipt = TRUE, markers = x$markers, labels = x$labels, confidence_level = conf,
    direction = a$direction, n_independent = n, n_positive = np, n_negative = nn, independent_unit = a[["independent-unit"]],
    score_unit = a[["score-unit"]], journal = a$journal, original_qc = p$assemble_qc_report(q),
    ported_from = "TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/diagnostic-accuracy/"),
    object = native, input_files = input_files, packages = c("pROC"), handoff_type = "development_roc_model", ready = FALSE,
    state = list(display_only = TRUE, inference_allowed = FALSE), upstream = x$upstream, method = method)
  os_proc_roc_release(res); res
}
os_proc_roc_release <- function(res) {
  m <- res$metadata; n <- res$object
  if (!identical(m$estimand, n$estimand) || !identical(m$estimand_sha256, n$estimand_sha256) ||
      !identical(digest::digest(m$estimand, algo = "sha256"), m$estimand_sha256)) .os_roc_stop("ROC-24: estimand binding changed", "OS_INVALID_RESULT")
  if (!identical(names(n$table_hashes), names(res$tables))) .os_roc_stop("ROC-24: table inventory changed", "OS_INVALID_RESULT")
  for (k in names(res$tables)) {
    t <- res$tables[[k]]
    if (!identical(digest::digest(t, algo = "sha256"), n$table_hashes[[k]]) || any(t$model_spec_hash != m$estimand_sha256)) .os_roc_stop(paste("ROC-24: canonical table content/hash changed:", k), "OS_INVALID_RESULT")
  }
  auc <- res$tables$auc_summary
  if (any(!is.finite(as.matrix(auc[c("estimate", "ci_low", "ci_high")]))) || any(auc$estimate < 0 | auc$estimate > 1) ||
      any(auc$ci_low > auc$estimate + 1e-9 | auc$ci_high < auc$estimate - 1e-9) || any(auc$ci_level != m$confidence_level))
    .os_roc_stop("ROC-14: full AUC estimate/CI/level invalid", "OS_INVALID_RESULT")
  for (i in seq_len(nrow(auc))) {
    f <- n$fits[[auc$marker[i]]]
    if (!isTRUE(all.equal(c(auc$estimate[i], auc$ci_low[i], auc$ci_high[i]), c(f$auc, f$ci_low, f$ci_high), tolerance = 1e-12))) .os_roc_stop("ROC-24: AUC table differs from fitted native values", "OS_INVALID_RESULT")
  }
  if (!is.null(n$accuracy)) {
    z <- n$accuracy
    if (z$tp + z$fn != m$n_positive || z$fp + z$tn != m$n_negative || sum(res$tables$contingency$count) != m$n_independent ||
        any(res$tables$cutpoint_table$tp + res$tables$cutpoint_table$fn != m$n_positive) || any(res$tables$cutpoint_table$fp + res$tables$cutpoint_table$tn != m$n_negative))
      .os_roc_stop("ROC-02: accuracy or cutoff counts do not balance", "OS_INVALID_RESULT")
  }
  if (!isTRUE(n$flow$ok)) .os_roc_stop("ROC-02: original flow identities failed", "OS_INVALID_RESULT")
  b <- res$tables$roc_band
  if (any(!is.finite(as.matrix(b[c("fpr", "lower", "median", "upper")]))) || any(b$lower > b$upper) ||
      any(as.matrix(b[c("fpr", "lower", "median", "upper")]) < 0 | as.matrix(b[c("fpr", "lower", "median", "upper")]) > 1))
    .os_roc_stop("ROC-24: pointwise ROC interval invalid; do not replace it", "OS_INVALID_RESULT")
  invisible(TRUE)
}
