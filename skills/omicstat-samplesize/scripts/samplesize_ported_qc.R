# Copied applicable SS-01..SS-06 guard conditions from medstat@12292d0 samplesize_qc.R lines29-67.
run_qc_ss <- function(ctx) {
  rows <- list()
  add <- function(id, triggered, message) {
    rows[[length(rows) + 1]] <<- data.frame(id = id, severity = "advisory",
                                             triggered = isTRUE(triggered), message = message,
                                             stringsAsFactors = FALSE)
  }

  add("SS-01", is.null(ctx$dropout) || is.na(ctx$dropout) || ctx$dropout <= 0,
      if (is.null(ctx$dropout) || is.na(ctx$dropout) || ctx$dropout <= 0)
        "[TRIGGERED] No positive attrition fraction was declared. The N above is the number of ANALYSABLE biological units/events, not the number to recruit; inflate by the anticipated loss-to-follow-up/non-response rate (n_recruit = n / (1 - dropout)) before writing a laboratory protocol or resource budget, or re-run with --dropout." else
        "[pass] SS-01: --dropout was supplied. n_total (and n1/n2) remain the analysable (pre-dropout) count; the recruitment target that reflects --dropout is the separate n_total_recruit (and n1_recruit/n2_recruit) column.")

  add("SS-02", isTRUE(ctx$effect_from_convention),
      if (isTRUE(ctx$effect_from_convention))
        "[TRIGGERED] The effect size was entered directly as a standardised-effect number (Cohen's d/f/h/w) rather than derived from a minimal important difference or a shrunk pilot/literature estimate. Cohen's small/medium/large conventions are a last resort (Lakens 2022, Sample Size Justification) -- state explicitly in the write-up which convention was used and why a literature- or MID-based estimate was not available." else
        "[pass] SS-02: the effect size was derived from stated raw-scale assumptions (means/proportions/rates), not a bare Cohen's-convention number.")

  add("SS-03", !is.null(ctx$power) && !is.na(ctx$power) && ctx$power < 0.8,
      if (!is.null(ctx$power) && !is.na(ctx$power) && ctx$power < 0.8)
        sprintf("[TRIGGERED] --power %.2f is below the conventional 0.80 floor. A target power below 80%% is an unusual, harder-to-defend choice for a primary analysis -- state the rationale explicitly if intentional.", ctx$power) else
        "[pass] SS-03: target power is at or above the conventional 0.80 floor (or not applicable to this design).")

  surv_design <- ctx$design %in% c("survival_logrank", "survival_ni")
  add("SS-04", surv_design && (is.null(ctx$event_prob) || is.na(ctx$event_prob)),
      if (surv_design && (is.null(ctx$event_prob) || is.na(ctx$event_prob)))
        "[TRIGGERED] --event-prob was not given, so only the number of EVENTS is reported, not a total sample size. Supply --event-prob (the anticipated pooled probability that an allocated biological unit experiences the primary event during follow-up, from prior literature/pilot data) to convert events into a recruitment target." else
        "[pass] SS-04: not a survival design, or --event-prob was supplied.")

  add("SS-05", !is.null(ctx$ratio) && !is.na(ctx$ratio) && (ctx$ratio > 3 || ctx$ratio < 1 / 3),
      if (!is.null(ctx$ratio) && !is.na(ctx$ratio) && (ctx$ratio > 3 || ctx$ratio < 1 / 3))
        sprintf("[TRIGGERED] --ratio %.2f is a highly unequal allocation. Unequal allocation costs statistical efficiency relative to 1:1 (the total N needed keeps rising as the ratio moves away from 1) -- confirm this ratio is required by the design (e.g. limited independent biological material in one group) and not just a convenience choice.", ctx$ratio) else
        "[pass] SS-05: allocation ratio is within a conventional range of 1:1 (or not applicable to this design).")

  add("SS-06", !is.null(ctx$alpha) && !is.na(ctx$alpha) && !(ctx$alpha %in% c(0.05, 0.025, 0.01)),
      if (!is.null(ctx$alpha) && !is.na(ctx$alpha) && !(ctx$alpha %in% c(0.05, 0.025, 0.01)))
        sprintf("[TRIGGERED] --alpha %.4g is not one of the conventional 0.05 (two-sided)/0.025 (one-sided)/0.01 values. State the rationale for a non-standard significance level explicitly (e.g. a pre-specified multiplicity correction).", ctx$alpha) else
        "[pass] SS-06: significance level is a conventional value (or not applicable to this design).")


  do.call(rbind, rows)
}
