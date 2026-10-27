`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

.lc_stop <- function(code, msg) stop(sprintf("%s: %s", code, msg), call. = FALSE)

check_longitudinal <- function(data, subject) {
  tab <- table(data[[subject]])
  if (all(tab <= 1)) {
    .lc_stop("MS_NOT_LONGITUDINAL", sprintf(
      "every value of --subject '%s' appears at most once in the data (%d rows, %d unique ids). This looks like repeated CROSS-SECTIONS (a different set of people each time), which is trend-analysis's job, not repeated MEASURES on the same people. If this really is longitudinal data, check --subject points at the participant id column, not a row id.",
      subject, nrow(data), length(tab)))
  }
  invisible(TRUE)
}

scan_waves <- function(data, subject, time, time_levels = NULL) {
  time_levels <- time_levels %||% sort(unique(data[[time]]))
  idx <- match(data[[time]], time_levels)
  if (anyNA(idx)) {
    .lc_stop("MS_INVALID_PARAMETER", "scan_waves(): a --time value was not found in the inferred/declared time_levels; this should be unreachable.")
  }
  by_subj <- split(idx, data[[subject]])
  is_prefix <- function(v) {
    v <- sort(unique(v))
    identical(v, seq_len(length(v)))
  }
  monotone_flags <- vapply(by_subj, is_prefix, logical(1))
  list(time_levels = time_levels,
       time_index = idx,
       monotone = all(monotone_flags),
       n_non_monotone = sum(!monotone_flags),
       non_monotone_ids = names(by_subj)[!monotone_flags])
}

.lc_singular <- function(m) {
  sing <- tryCatch(lme4::isSingular(m, tol = 1e-4), error = function(e) NA)
  vc <- tryCatch(as.data.frame(lme4::VarCorr(m)), error = function(e) NULL)
  high_corr <- FALSE
  if (!is.null(vc) && "var2" %in% names(vc)) {
    corr_rows <- vc[!is.na(vc$var2), , drop = FALSE]
    if (nrow(corr_rows)) high_corr <- any(abs(corr_rows$sdcor) > 0.99, na.rm = TRUE)
  }
  conv_msgs <- tryCatch(m@optinfo$conv$lme4$messages, error = function(e) NULL)
  conv_bad <- length(conv_msgs) > 0
  list(degenerate = isTRUE(sing) || isTRUE(high_corr) || conv_bad,
       is_singular = isTRUE(sing), high_corr = isTRUE(high_corr),
       conv_messages = conv_msgs %||% character(0))
}

lc_emm_and_tests <- function(fit_result, prep, df_method_declared, multiplicity = "none", alpha = 0.05,
                             outcome_type = "continuous") {
  m <- fit_result$model
  n_rows <- nrow(prep$data)
  ci_level <- 1 - alpha
  emmeans::emm_options(pbkrtest.limit = max(n_rows, 3000), lmerTest.limit = max(n_rows, 3000))
  # Defect C10: for an lmer fit, emmeans picks its df method from lmer.df
  # (default Kenward-Roger), NOT from --df-method, so a run that declared
  # Satterthwaite silently computed Kenward-Roger. The declared method is now
  # passed to every emmeans()/joint_tests() call.
  lmer_df <- lc_lmer_df(fit_result, df_method_declared)
  emm_extra <- if (is.null(lmer_df)) list() else list(lmer.df = lmer_df)
  # WP-N6: an engine may carry extra emmeans arguments (the glmm engine's
  # offset = 0, i.e. rates per ONE unit of exposure). Absent for every other
  # engine, so their calls are unchanged.
  emm_extra <- c(emm_extra, fit_result$emm_args %||% list())

  # For a non-continuous outcome, emm_df (the TABLE/FIGURE of levels) is
  # reported on the response scale (a probability/rate emmeans derives via
  # type="response") -- comparing that against an observed proportion later
  # (the EMM-vs-observed sanity figure) on a common scale. Contrasts stay on
  # the LINK scale (the default) so the group difference is a log-OR/log-IRR
  # that this file's callers exponentiate into an OR/IRR; averaging on the
  # response scale first and differencing after would not be the same number.
  emm_type <- if (identical(outcome_type, "continuous")) "link" else "response"

  group_f <- prep$group
  # A model fit with time_type="continuous" (lmer cohort, writeup B) carries
  # the timepoint as ".lc_time_c", not `prep$time` itself -- the reference
  # grid must be requested on the model's own term name, evaluated AT the
  # actual observed timepoint values, or emmeans has no variable of that name
  # to build a grid over ("No variable named <time> in the reference grid").
  # data = prep$data is passed EXPLICITLY to every emmeans/joint_tests() call
  # below. Without it, emmeans's recover_data() tries to re-evaluate the
  # model's own stored data= argument expression in the model's formula
  # environment -- which fails ("We are unable to reconstruct the data")
  # whenever the model was fit inside a helper function (every engine
  # function in this file IS one), because that expression's home
  # environment is the helper's own call frame, not this function's.
  # Verified with a minimal repro before writing this comment: identical
  # failure whether the helper's data argument is named "data" or something
  # else entirely -- passing data= explicitly here is the actual fix, not a
  # naming workaround.
  uses_time_c <- identical(fit_result$time_type, "continuous") && identical(fit_result$engine, "lmer")
  if (uses_time_c) {
    time_form <- stats::as.formula(sprintf("~ %s | .lc_time_c", group_f))
    emm <- do.call(emmeans::emmeans, c(list(m, time_form, at = list(.lc_time_c = as.numeric(prep$time_levels)),
                                            data = prep$data), emm_extra))
  } else {
    time_form <- stats::as.formula(sprintf("~ %s | %s", group_f, prep$time))
    emm <- do.call(emmeans::emmeans, c(list(m, time_form, data = prep$data), emm_extra))
  }
  # `emm` itself stays on the LINK scale (contrast() below needs that for a
  # correct OR/IRR); emm_df (the table/figure of LEVELS) is a separate
  # summary() call with type= applied, so a binary/count outcome's EMM table
  # reports a probability/rate, not a raw log-odds/log-rate. level= wires
  # --alpha through to the actual interval width (not just its printed
  # label) -- ci_level = 1 - alpha, computed once above.
  emm_df <- as.data.frame(summary(emm, type = emm_type, level = ci_level))
  if (uses_time_c) names(emm_df)[names(emm_df) == ".lc_time_c"] <- prep$time

  jt <- tryCatch(do.call(emmeans::joint_tests, c(list(m, data = prep$data), emm_extra)),
                 error = function(e) NULL)

  ct <- emmeans::contrast(emm, "revpairwise")
  # adjust="none" is NOT the default for a "revpairwise" contrast object --
  # emmeans::summary()'s own default for a pairwise-family contrast is
  # adjust="tukey", applied within each `by` group (here, within each
  # timepoint). Leaving that implicit silently Tukey-adjusts the table this
  # module documents and drafts as "raw" (unadjusted) P and CI -- inert with
  # exactly 2 groups (a single contrast per timepoint has nothing to adjust
  # for), wrong as soon as a third arm exists. adjust="none" here is what
  # actually makes "raw" true.
  ct_raw <- as.data.frame(summary(ct, adjust = "none", infer = c(TRUE, TRUE), level = ci_level))
  ct_adj <- if (!identical(multiplicity, "none")) {
    as.data.frame(summary(ct, by = NULL, adjust = multiplicity, infer = c(TRUE, TRUE), level = ci_level))
  } else NULL
  if (uses_time_c) {
    names(ct_raw)[names(ct_raw) == ".lc_time_c"] <- prep$time
    if (!is.null(ct_adj)) names(ct_adj)[names(ct_adj) == ".lc_time_c"] <- prep$time
  }

  # Guard against a fully-degenerate contrast set reaching a draft as if it
  # were a real result (e.g. a survey design with fewer design df than model
  # parameters, or a corrupted cluster id): if EVERY contrast has both a
  # non-finite P value and a non-finite CI, this is not an estimable model,
  # regardless of engine. fit_survey() also stops proactively on the design-
  # df-vs-parameter-count version of this; this is the engine-agnostic
  # backstop for any other route into the same failure mode.
  p_finite <- is.finite(ct_raw$p.value)
  ct_lo <- ct_raw$lower.CL %||% ct_raw$asymp.LCL
  ct_hi <- ct_raw$upper.CL %||% ct_raw$asymp.UCL
  ci_finite <- is.finite(ct_lo) & is.finite(ct_hi)
  if (nrow(ct_raw) && !any(p_finite) && !any(ci_finite)) {
    .lc_stop("MS_NOT_ESTIMABLE", sprintf(
      "every one of the %d per-timepoint contrast(s) came back with a non-finite P value AND a non-finite confidence interval -- this is a degenerate fit (e.g. too few design/model degrees of freedom, or a corrupted subject/cluster id), not a real result. A draft built from these numbers would report every timepoint as 'not estimable', which is not a finding.",
      nrow(ct_raw)))
  }
  # Defense against the id-coercion failure mode directly: a contrast whose
  # standard error is exactly zero/NaN, or whose P value is exactly 0, is
  # not a legitimate Wald/t-based result (P == 0 exactly only happens when
  # the SE collapsed to 0, driving the test statistic to +/-Inf). This is
  # the specific signature a non-numeric --subject id silently breaking
  # geepack's cluster map leaves behind.
  se_col <- if ("SE" %in% names(ct_raw)) ct_raw$SE else rep(NA_real_, nrow(ct_raw))
  bad_se <- !is.na(se_col) & (se_col <= 0 | !is.finite(se_col))
  bad_p0 <- !is.na(ct_raw$p.value) & ct_raw$p.value <= 0
  if (any(bad_se) || any(bad_p0)) {
    .lc_stop("MS_DEGENERATE_CONTRAST", sprintf(
      "%d contrast(s) have a zero/non-finite standard error and/or a P value of exactly 0 -- not a legitimate result. This is the signature of a broken cluster/subject id map (e.g. a non-numeric --subject id silently corrupting geepack's id handling) or another degenerate fit. Check --subject '%s' identifies the same clusters the model was actually fit on before trusting any number from this run.",
      sum(bad_se | bad_p0), prep$subject))
  }

  # LC-08 consistency check: if a finite-sample df method was declared but
  # emmeans reports every df as (effectively) infinite, it silently switched
  # to the asymptotic approximation (P2 sec 7.5's n>3000 pbkrtest.limit/
  # lmerTest.limit ceiling) -- the pbkrtest.limit/lmerTest.limit set above
  # should prevent this outright; this is a belt-and-braces readback.
  df_col <- if ("df" %in% names(ct_raw)) ct_raw$df else NA_real_
  if (df_method_declared %in% c("Kenward-Roger", "Satterthwaite", "Between-Within", "Residual") &&
      length(df_col) && all(is.infinite(df_col) | is.na(df_col))) {
    .lc_stop("MS_DF_METHOD_MISMATCH", sprintf(
      "df_method='%s' was declared but emmeans returned Inf/NA degrees of freedom for every contrast -- it silently fell back to an asymptotic approximation. This should not happen given the pbkrtest.limit/lmerTest.limit set on this data (n=%d); if it does, the model object itself may not carry df information (check the engine).",
      df_method_declared, n_rows))
  }

  list(emm = emm, emm_df = emm_df, joint_tests = jt, contrast_raw = ct_raw,
       contrast_adjusted = ct_adj, df_actual = unique(df_col[is.finite(df_col)]),
       ci_level = ci_level)
}

lc_lmer_df <- function(fit_result, df_method_declared) {
  if (!identical(fit_result$engine, "lmer")) return(NULL)
  tok <- switch(df_method_declared %||% "",
                "Kenward-Roger" = "kenward-roger",
                "Satterthwaite" = "satterthwaite",
                NULL)
  if (is.null(tok)) {
    .lc_stop("MS_INVALID_PARAMETER", sprintf(
      "--df-method '%s' is not available for --engine lmer; use Kenward-Roger or Satterthwaite (Residual and Between-Within are mmrm-only).",
      df_method_declared))
  }
  tok
}

diff_effect_rows <- function(ct_raw, ct_adj, time, analysis_id, ratio, hash, effect_type = "mean_diff",
                             adjust_method = NA_character_, ci_level = 0.95,
                             prep = NULL, group = NULL) {
  est <- ct_raw$estimate
  ci_lo <- ct_raw$lower.CL %||% ct_raw$asymp.LCL
  ci_hi <- ct_raw$upper.CL %||% ct_raw$asymp.UCL
  if (ratio) { est <- exp(est); ci_lo <- exp(ci_lo); ci_hi <- exp(ci_hi) }
  p_adj <- rep(NA_real_, nrow(ct_raw))
  p_meth <- rep(NA_character_, nrow(ct_raw))
  if (!is.null(ct_adj)) {
    # Join on (contrast, timepoint), NOT timepoint alone -- with >2 groups,
    # more than one contrast row shares a timepoint, and matching by
    # timepoint only hands every contrast at that timepoint the FIRST
    # contrast's adjusted P (silently wrong for every row after the first).
    key_raw <- paste(ct_raw$contrast, ct_raw[[time]], sep = "\r")
    key_adj <- paste(ct_adj$contrast, ct_adj[[time]], sep = "\r")
    ord <- match(key_raw, key_adj)
    if (anyNA(ord)) {
      .lc_stop("MS_SCHEMA_INTERNAL", "diff_effect_rows(): could not match every raw contrast row to its multiplicity-adjusted counterpart by (contrast, timepoint) -- the adjusted-P join would be unsafe to use.")
    }
    p_adj <- ct_adj$p.value[ord]
    p_meth <- rep(adjust_method, nrow(ct_raw))
    # Sanity check: every documented multiplicity correction (bonferroni/
    # holm/sidak/...) can only ever inflate a P value, never shrink it -- if
    # the join above assigned a row the WRONG contrast's adjusted P, this is
    # a cheap, always-true invariant to catch it against (a strict rank-order
    # check was tried here first and rejected: capping at 1 legitimately
    # collapses several DIFFERENT raw P values to the SAME adjusted P, which
    # breaks strict order() agreement even in a correct implementation).
    ok_idx <- !is.na(ct_raw$p.value) & !is.na(p_adj)
    if (any(ok_idx) && any(p_adj[ok_idx] < ct_raw$p.value[ok_idx] - 1e-8)) {
      .lc_stop("MS_SCHEMA_INTERNAL", "diff_effect_rows(): a multiplicity-adjusted P value is SMALLER than its own raw P value after the (contrast, timepoint) join -- every documented correction can only inflate P, so this means the join assigned some row the wrong contrast's adjusted P.")
    }
  }
  # n_unweighted for a difference row: the timepoint's COMBINED two-group
  # cell count (P2-longitudinal-change.md sec 14.6 open_issue #1's settled
  # decision) -- the EMM table already fills this (emm_effect_rows()); the
  # difference table shipped it as NA/"--" on every row with no reference
  # documenting the gap, which is the actual defect (not that N is hard to
  # compute -- the same aggregate() emm_effect_rows() already uses answers
  # it directly).
  n_uw <- rep(NA_integer_, nrow(ct_raw))
  if (!is.null(prep) && !is.null(group)) {
    n_cell <- stats::aggregate(stats::as.formula(sprintf("%s ~ %s + %s", prep$outcome, group, time)),
                               data = prep$data, FUN = length)
    names(n_cell)[3] <- "n_cell"
    # emmeans's default "revpairwise" contrast label is "LevelB - LevelA"
    # (the two group levels being differenced, joined by " - "); recover
    # them to look up each level's cell count at this row's timepoint.
    get_n <- function(contrast_lbl, tp) {
      parts <- trimws(strsplit(as.character(contrast_lbl), " - ", fixed = TRUE)[[1]])
      if (length(parts) != 2) return(NA_integer_)
      rows <- n_cell[as.character(n_cell[[group]]) %in% parts & as.character(n_cell[[time]]) == as.character(tp), , drop = FALSE]
      if (!nrow(rows)) return(NA_integer_)
      as.integer(sum(rows$n_cell))
    }
    n_uw <- vapply(seq_len(nrow(ct_raw)), function(i) get_n(ct_raw$contrast[i], ct_raw[[time]][i]), integer(1))
  }
  # emmeans' default "revpairwise" contrast label always joins the two group
  # levels with " - " ("LevelB - LevelA"), which reads as a subtraction --
  # correct convention for a difference-scale contrast (mean_diff), but the
  # field's convention for a RATIO-scale contrast (OR/IRR) is "vs", not "-"
  # (nothing is actually subtracted on a ratio scale). Only the display
  # term is touched; ct_raw$contrast itself (used for the by-(contrast,
  # timepoint) join above) is untouched.
  term_disp <- if (ratio) gsub(" - ", " vs ", ct_raw$contrast, fixed = TRUE) else ct_raw$contrast
  add_effect_rows(
    term = term_disp, level = as.character(ct_raw[[time]]),
    analysis_id = analysis_id, effect_type = effect_type,
    estimate = est, ci_low = ci_lo, ci_high = ci_hi, ci_level = ci_level,
    p_value = ct_raw$p.value, p_adjusted = p_adj, p_adj_method = p_meth,
    n_unweighted = n_uw, design_df = if ("df" %in% names(ct_raw)) ct_raw$df else NA_real_,
    weighted = FALSE, model_spec_hash = hash, validate = FALSE)
}

interaction_effect_rows <- function(jt, analysis_id, hash) {
  if (is.null(jt) || !nrow(jt)) return(new_effect_table())
  jt <- as.data.frame(jt)
  out <- add_effect_rows(
    term = jt$`model term`, analysis_id = analysis_id, effect_type = "other",
    estimate = jt$F.ratio, p_value = jt$p.value,
    n_unweighted = NA_integer_, design_df = jt$df2, weighted = FALSE,
    model_spec_hash = hash,
    notes = sprintf("F(%s,%s)", jt$df1, jt$df2), validate = FALSE)
  # `df1` is a module-specific extension column, same rationale as `se` in
  # emm_effect_rows(): design_df already carries df2, so this is the
  # numerator df, kept as a real numeric column rather than only inside the
  # free-text `notes` string -- a reader-facing Table 3 needs df1/df2 as
  # actual columns, not text to parse back out.
  out$df1 <- jt$df1
  out
}
