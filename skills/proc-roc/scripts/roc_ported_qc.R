# Copied/adapted from TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa
# skills/diagnostic-accuracy/scripts/diagacc_qc.R; independent OmicStat code.
# PORT_ADAPTATIONS.json records changes. Native numerical equivalence is not yet verified.
`%||%` <- function(a,b) if(is.null(a)||length(a)==0||(length(a)==1&&is.na(a))) b else a

.qc_row <- function(code, severity, message) {
  data.frame(code = code, severity = severity, message = message, stringsAsFactors = FALSE)
}

qc_da01 <- function(n_miss, n_input, vars, n_analysed) {
  if (n_miss <= 0) return(NULL)
  pct <- round(100 * n_miss / n_input, 1)
  .qc_row("ROC-01", "M", sprintf(
    "Missing values were dropped before analysis: %d of %d records (%s%%). Variables affected: %s. Complete-case n = %d.",
    n_miss, n_input, format(pct), paste(vars, collapse = ", "), n_analysed))
}

qc_da02 <- function(flow) {
  ids <- flow$identities
  bad <- names(ids)[!vapply(ids, isTRUE, logical(1))]
  if (!length(bad)) return(NULL)
  rows <- lapply(bad, function(nm) {
    lhs_rhs <- switch(nm,
      flow_balances = sprintf("%d - %d != %d", flow$n_input,
        flow$n_excl_missing_index + flow$n_excl_missing_reference + flow$n_excl_indeterminate_index +
          flow$n_excl_indeterminate_reference + flow$n_excl_other, flow$n_analysed),
      positive_negative_sum = sprintf("%d + %d != %d", flow$n_positive, flow$n_negative, flow$n_analysed),
      tp_fn_equals_positive = "tp + fn != n_positive",
      tn_fp_equals_negative = "tn + fp != n_negative",
      "identity failed")
    parts <- strsplit(lhs_rhs, " != ")[[1]]
    .qc_row("ROC-02", "H", sprintf(
      "Participant-flow accounting does not balance: %s failed (%s != %s). Every downstream count is unreliable until this is resolved.",
      nm, parts[1], if (length(parts) > 1) parts[2] else "?"))
  })
  do.call(rbind, rows)
}

qc_da03 <- function(levels_found) {
  k <- length(levels_found)
  if (k == 2) return(NULL)
  .qc_row("ROC-03", "H", sprintf(
    "The reference standard must have exactly two levels; found %d: %s. Collapse or subset before running.",
    k, paste(levels_found, collapse = ", ")))
}

qc_da04 <- function(id_col) {
  if (is.null(id_col)) return(NULL)
  dup <- id_col[duplicated(id_col)]
  if (!length(dup)) return(NULL)
  .qc_row("ROC-04", "M", sprintf(
    "The analysis unit appears not to be one row per participant: %d duplicated id(s). Per-lesion clustering inflates precision; this module assumes per-subject data.",
    length(unique(dup))))
}

qc_da05_missing_labels <- function(missing_keys) {
  if (!length(missing_keys)) return(NULL)
  .qc_row("ROC-05", "H", sprintf(
    "Raw column name(s) %s appear in reader-facing output. Supply a --labels mapping; drafts are not generated without human-readable names.",
    paste(missing_keys, collapse = ", ")))
}

qc_da06 <- function(auto_check) {
  if (isTRUE(auto_check$agrees)) return(NULL)
  .qc_row("ROC-06", "H", sprintf(
    "Declared direction (%s) disagrees with the data-driven direction (%s). AUC is %.4f as declared and %.4f if reversed. Confirm which direction is clinically intended.",
    auto_check$declared_direction_label, auto_check$auto_direction, auto_check$declared_auc, auto_check$auto_auc))
}

qc_da07 <- function(auc) {
  if (is.na(auc) || auc >= 0.5) return(NULL)
  .qc_row("ROC-07", "M", sprintf(
    "AUC = %.4f is below 0.5, i.e. the index test ranks worse than chance in the declared direction. This is reported as observed and is not automatically mirrored.",
    auc))
}

qc_da08 <- function(tp, fn, fp, tn) {
  cells <- c(tp = tp, fn = fn, fp = fp, tn = tn)
  zeros <- names(cells)[cells == 0]
  if (!length(zeros)) return(NULL)
  .qc_row("ROC-08", "M", sprintf(
    "Zero cell(s) in the 2x2 table (%s). Likelihood ratios are infinite or zero; a 0.5 continuity-corrected sensitivity analysis is reported alongside in tables/lr_continuity_corrected.{csv,md}.",
    paste(zeros, collapse = ", ")))
}

qc_da09 <- function(j) {
  if (is.na(j) || (j >= 0 && j <= 1)) return(NULL)
  diagnosis <- if (j > 1) {
    "a value above 1 indicates the pROC 'youden' return (sensitivity + specificity) was used by mistake instead of sensitivity + specificity - 1"
  } else {
    "a value below 0 means sensitivity + specificity < 1 at this operating point -- check that the index test's direction and the chosen cut-off are the ones actually intended"
  }
  .qc_row("ROC-09", "H", sprintf(
    "Youden index J = %.4f is outside the source review range [0, 1] (negative J is mathematically possible). J is sensitivity + specificity - 1; %s.",
    j, diagnosis))
}

qc_da10 <- function(cut_youden, cut_topleft) {
  if (is.na(cut_youden) || is.na(cut_topleft) || isTRUE(all.equal(cut_youden, cut_topleft))) return(NULL)
  .qc_row("ROC-10", "M", sprintf(
    "The Youden criterion and the closest-to-(0,1) criterion select different cut-offs (%.4g vs %.4g). See Perkins and Schisterman 2006.",
    cut_youden, cut_topleft))
}

qc_da11 <- function(applied) {
  if (!isTRUE(applied)) return(NULL)
  .qc_row("ROC-11", "I",
    "A continuity correction of 0.5 was added to all four cells for the likelihood-ratio sensitivity analysis in tables/lr_continuity_corrected.{csv,md}; the primary estimates in tables/accuracy_primary are uncorrected.")
}

qc_da12 <- function(missing_part) {
  if (is.null(missing_part) || !nzchar(missing_part)) return(NULL)
  .qc_row("ROC-12", "H", sprintf(
    "A data-driven cut-off was used but %s is absent. Data-driven cut-off selection yields optimistically biased sensitivity and specificity (PMID 18258670); the bootstrap interval for the cut-off itself and an internal-validation estimate are mandatory.",
    missing_part))
}

qc_da13 <- function(cut, lo, hi, conf_level = 0.95) {
  if (any(is.na(c(cut, lo, hi))) || cut == 0) return(NULL)
  width <- hi - lo
  if (width <= abs(cut)) return(NULL)
  .qc_row("ROC-13", "M", sprintf(
    "The bootstrap %g%% interval for the selected cut-off (%.4g to %.4g) is wider than the cut-off itself (%.4g); the cut-off is not stable in these data.",
    100 * conf_level, lo, hi, cut))
}

qc_da14 <- function(est, lo, hi, term) {
  if (any(is.na(c(est, lo, hi)))) return(NULL)
  width <- hi - lo
  outside <- est < lo - 1e-9 || est > hi + 1e-9
  far_from_center <- width > 0 && abs(est - (lo + hi) / 2) > 0.5 * width + 1e-9
  if (!outside && !far_from_center) return(NULL)
  .qc_row("ROC-14", "H", sprintf(
    "Point estimate %.4g is inconsistent with its confidence interval [%.4g, %.4g] for %s. Check that the estimate and the interval come from the same roc object and the same AUC definition.",
    est, lo, hi, term))
}

qc_da15 <- function(n1, n2, n_diff) {
  if (n1 == n2 && n_diff == 0) return(NULL)
  .qc_row("ROC-15", "H", sprintf(
    "Paired comparison requested but the two index tests have different analysis samples (n = %d vs %d; %d participants differ). A paired DeLong test is not valid here.",
    n1, n2, n_diff))
}

qc_da16 <- function(n_indet, policy, file, substituted_class_label = NA_character_) {
  if (n_indet <= 0) return(NULL)
  handling_txt <- if (identical(policy, "exclude")) "excluded from the primary analysis"
    else sprintf("treated as target-condition '%s' in the primary analysis", substituted_class_label)
  .qc_row("ROC-16", "M", sprintf(
    "%d participant(s) had an indeterminate result and were %s (--indeterminate %s). A sensitivity analysis (excluded / treated as positive / treated as negative) is reported in %s.",
    n_indet, handling_txt, policy, file))
}

qc_da17 <- function(n, n_pos, n_neg) {
  if (n >= 50 && n_pos >= 20 && n_neg >= 20) return(NULL)
  .qc_row("ROC-17", "M", sprintf(
    "Sample size is small (n = %d; %d with and %d without the target condition). Exact intervals are wide and any data-driven cut-off is strongly optimistic at this size (PMID 18258670).",
    n, n_pos, n_neg))
}

qc_da18 <- function(sens, sens_lo, sens_hi, spec, spec_lo, spec_hi) {
  rows <- list()
  if (!is.na(sens) && (sens == 0 || sens == 1)) {
    rows <- c(rows, list(.qc_row("ROC-18", "M", sprintf(
      "Sensitivity is exactly %s; the exact interval is one-sided ([%.4g, %.4g]). Do not report this as a point value without its interval.",
      ifelse(sens == 1, "100%", "0%"), sens_lo, sens_hi))))
  }
  if (!is.na(spec) && (spec == 0 || spec == 1)) {
    rows <- c(rows, list(.qc_row("ROC-18", "M", sprintf(
      "Specificity is exactly %s; the exact interval is one-sided ([%.4g, %.4g]). Do not report this as a point value without its interval.",
      ifelse(spec == 1, "100%", "0%"), spec_lo, spec_hi))))
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

qc_da19 <- function(focus, lo, hi, boot_n, seed) {
  if (is.null(focus)) return(NULL)
  .qc_row("ROC-19", "I", sprintf(
    "Partial AUC over %s %.4g-%.4g was computed; inference uses %d stratified bootstrap replicates with seed %d because the DeLong method does not support partial areas.",
    focus, lo, hi, boot_n, seed))
}

qc_da20 <- function(p_study, p_grid) {
  p_grid <- p_grid[is.finite(p_grid) & p_grid > 0]
  if (!length(p_grid) || !is.finite(p_study) || p_study <= 0) return(NULL)
  ratio <- pmax(p_study / p_grid, p_grid / p_study)
  if (!any(ratio > 5)) return(NULL)
  .qc_row("ROC-20", "M", sprintf(
    "The study prevalence (%.1f%%) differs from the projected setting(s) by more than fivefold. Predictive values transfer across settings only under the assumption that sensitivity and specificity are stable, which is not generally true (PMID 23798453).",
    100 * p_study))
}

qc_da21 <- function(stray_files) {
  if (!length(stray_files)) return(NULL)
  .qc_row("ROC-21", "H", sprintf(
    "Stray file(s) in the working directory after the run: %s. Every figure must be written through an explicit device; see the pdf(NULL) guard pattern.",
    paste(stray_files, collapse = ", ")))
}

qc_da22 <- function(k_comparisons, p_adjust_used) {
  if (k_comparisons < 1 || isTRUE(p_adjust_used)) return(NULL)
  .qc_row("ROC-22", "M", sprintf(
    "%d pairwise AUC comparisons were performed. pROC implements pairwise comparison only and does not adjust for multiplicity; an explicit family and adjustment are required in this OmicStat port.",
    k_comparisons))
}

qc_da23_subgroup_skipped <- function(skipped) {
  if (!length(skipped)) return(NULL)
  .qc_row("ROC-23", "M", sprintf(
    "Subgroup accuracy analysis: %d level(s) were skipped and produced no row in subgroup_accuracy: %s.",
    length(skipped), paste(skipped, collapse = "; ")))
}

assemble_qc_report <- function(rows) {
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame(code = character(0), severity = character(0),
                                        message = character(0), stringsAsFactors = FALSE))
  out <- do.call(rbind, rows)
  sev_rank <- c(H = 1L, M = 2L, I = 3L)
  out <- out[order(sev_rank[out$severity], out$code), , drop = FALSE]
  rownames(out) <- NULL
  out
}
