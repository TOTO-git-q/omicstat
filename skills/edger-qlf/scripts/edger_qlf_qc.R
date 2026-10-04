# edgeR QLF input blockers and result diagnostics, each with a source.
eq_input_qc <- function(cs, reps) {
  list(
    os_qc_rule("EQ-01", "integer_counts", cs$n_non_integer > 0, "blocker",
               sprintf("%d count cell(s) are non-integer.", cs$n_non_integer),
               "Supply unnormalized integer RNA-seq counts.", "edgeR User's Guide 2.1; ENGINEERING_PLAN 4.5"),
    os_qc_rule("EQ-02", "negative_counts", cs$n_negative > 0, "blocker",
               sprintf("%d count cell(s) are negative.", cs$n_negative),
               "Supply nonnegative counts, not centered or transformed expression.", "edgeR User's Guide 2.1; ENGINEERING_PLAN 4.5"),
    os_qc_rule("EQ-03", "replicates_minimum", any(reps$status == "blocker"), "blocker",
               sprintf("Compared-group replicates: %s; each needs at least 2.", paste(sprintf("%s=%d", reps$condition, reps$n_replicates), collapse = ", ")),
               "Add biological replicates for the reference and target levels.", "ENGINEERING_PLAN 4.5 (design class); edgeR User's Guide 4.4.1"),
    os_qc_rule("EQ-04", "replicates_recommended", any(reps$status == "warning") && !any(reps$status == "blocker"), "warning",
               "A compared group has fewer than 3 biological replicates.",
               "Report group sizes and read this low-power warning.", "ENGINEERING_PLAN 4.5 (design class)"))
}
edger_qlf_qc <- function(input_rows, r, ft, cnt, a, elog, symbols_given, n_symbol_missing) {
  n_warn <- os_engine_counts(elog)[["warning"]] %||% 0L
  frac_sig <- if (cnt$n_tested) cnt$n_sig / cnt$n_tested else 0
  rows <- c(input_rows, list(
    os_qc_rule("EQ-05", "padj_all_na", all(is.na(ft$padj)), "error",
               "Every adjusted P value is missing.", "Check filtering, model rank and engine warnings.", "ENGINEERING_PLAN 4.5 (numeric degeneracy)"),
    os_qc_rule("EQ-06", "most_features_significant", frac_sig > 0.5, "warning",
               sprintf("%.1f%% of filtered genes pass BH FDR <= %s.", 100 * frac_sig, format(a$alpha)),
               "Inspect sample QC and the design for confounding or sample swaps.", "ENGINEERING_PLAN 4.5 (numeric degeneracy)"),
    os_qc_rule("EQ-07", "engine_warnings", n_warn > 0, "warning",
               sprintf("edgeR emitted %d engine warning(s).", n_warn), "Read qc/engine_warnings.csv.", "CONVENTIONS sec 15"),
    os_qc_rule("EQ-08", "symbol_mapping", symbols_given && cnt$n_tested > 0 && n_symbol_missing / cnt$n_tested > 0.05, "warning",
               sprintf("%d filtered genes (%.1f%%) have no symbol.", n_symbol_missing,
                       if (cnt$n_tested) 100 * n_symbol_missing / cnt$n_tested else 0),
               "Check feature IDs and annotation release.", "CONVENTIONS sec 8 (mapping loss >5%)"),
    os_qc_rule("EQ-09", "robust_ql_prior", TRUE, "info",
               "The QL prior used robust=TRUE and winsor.tail.p=c(0.05,0.1).",
               "State robust QL prior estimation in Methods.", "PACK S1 P-2; edgeR User's Guide 4.4.7"),
    os_qc_rule("EQ-10", "legacy_ql", isTRUE(a$legacy), "info",
               "The legacy QL method was explicitly requested.",
               "State edgeR version and legacy=TRUE; compare separately from the current method.", "PACK S1 P-1; glmQLFit.Rd"),
    os_qc_rule("EQ-11", "minimum_effect_test", r$used_treat, "info",
               sprintf("glmTreat tests a prespecified linear FC > %s (log2 threshold %.4g).", format(a[["treat-fc"]]),
                       if (r$used_treat) log2(a[["treat-fc"]]) else 0),
               "Describe this as a minimum-effect test, separate from display-only filtering.", "PACK S1 P-3; glmTreat.Rd")))
  os_qc_finalize(rows, read_first = "draft/methods_results.md")
}
