# deseq2_wald_qc.R -- qc layer of module deseq2-wald. ASCII only on purpose.
#
# Rules DW-01..DW-12 (references/qc-rules.md: criterion, severity, source).
# Input-state rules are decided BEFORE the model is fitted (dw_input_qc):
# a triggered blocker there stops the run after writing qc/qc_results.csv.
# Result rules are decided after the fit (deseq2_wald_qc).

dw_input_qc <- function(cs, reps) {
  rows <- list(
    os_qc_rule("DW-01", "integer_counts", cs$n_non_integer > 0, "blocker",
               sprintf("%d count cell(s) are not whole numbers; DESeq2 models raw counts, not normalized or transformed values.", cs$n_non_integer),
               "Supply the un-normalized integer count matrix (e.g. featureCounts / tximport counts); never TPM, FPKM, CPM or batch-corrected values.",
               "DESeq2 vignette, 'Why un-normalized counts?'"),
    os_qc_rule("DW-02", "negative_counts", cs$n_negative > 0, "blocker",
               sprintf("%d count cell(s) are negative.", cs$n_negative),
               "Counts cannot be negative: the matrix is not a count matrix (check for log-transformed or centred data).",
               "DESeq2 vignette, 'Why un-normalized counts?'"),
    os_qc_rule("DW-03", "replicates_minimum", any(reps$status == "blocker"), "blocker",
               sprintf("Biological replicates per compared group: %s; each group needs at least %d.",
                       paste(sprintf("%s = %d", reps$condition, reps$n_replicates), collapse = ", "), DW_REPS_BLOCKER_BELOW),
               "Without replicates the dispersion cannot be estimated from the data; add biological replicates.",
               "ENGINEERING_PLAN 4.5 (design class); DESeq2 vignette, 'Can I use DESeq2 to analyze a dataset without replicates?'"),
    os_qc_rule("DW-04", "replicates_recommended", any(reps$status == "warning") && !any(reps$status == "blocker"), "warning",
               sprintf("A compared group has fewer than %d biological replicates (%s).", DW_REPS_WARNING_BELOW,
                       paste(sprintf("%s = %d", reps$condition, reps$n_replicates), collapse = ", ")),
               "Report the replicate numbers next to every result; power to detect moderate changes is low.",
               "ENGINEERING_PLAN 4.5 (design class)"))
  rows
}

deseq2_wald_qc <- function(input_rows, r, ft, cnt, a, elog, symbols_given, n_symbol_missing) {
  n_warn <- os_engine_counts(elog)[["warning"]] %||% 0L
  et <- os_engine_table(elog)
  disp_fallback <- any(et$type == "message" & grepl("local regression fit was automatically substituted", et$message, fixed = TRUE))
  frac_sig <- if (cnt$n_tested) cnt$n_sig / cnt$n_tested else 0
  rows <- c(input_rows, list(
    os_qc_rule("DW-05", "padj_all_na", all(is.na(ft$padj)), "error",
               "Every adjusted P value is NA: no feature could be tested.",
               "Check the pre-filter (--min-count, --min-samples), the replicate numbers and qc/engine_warnings.csv.",
               "ENGINEERING_PLAN 4.5 (numeric degeneracy)"),
    os_qc_rule("DW-06", "most_features_significant", frac_sig > 0.5, "warning",
               sprintf("%.1f%% of tested features are significant at adjusted P < %s.", 100 * frac_sig, format(a$alpha)),
               "Such a large share usually means a confounded design, a sample swap or a normalization problem; inspect the PCA from deseq2-qc before reporting.",
               "ENGINEERING_PLAN 4.5 (numeric degeneracy: 'all features significant')"),
    os_qc_rule("DW-07", "cooks_outliers", cnt$n_outlier > 0, "info",
               sprintf("%d feature(s) have padj = NA because one sample's Cook's distance exceeds the cutoff.", cnt$n_outlier),
               "They are listed with filtered_reason = outlier; inspect their counts before discarding them.",
               "DESeq2 vignette, 'Approach to count outliers'; ?results (cooksCutoff)"),
    os_qc_rule("DW-08", "independent_filtering", cnt$n_indep_filtered > 0, "info",
               sprintf("%d feature(s) with low mean counts were removed by independent filtering (padj = NA).", cnt$n_indep_filtered),
               "Report the number of features tested, not the number supplied; filtered features keep filtered_reason = independent_filtering.",
               "DESeq2 vignette, 'Independent filtering of results'"),
    os_qc_rule("DW-09", "engine_warnings", n_warn > 0, "warning",
               sprintf("DESeq2/apeglm raised %d warning(s) during the run.", n_warn),
               "Read qc/engine_warnings.csv; a failed parametric dispersion fit or non-converged rows change how results should be read.",
               "_shared engine contract (CONVENTIONS sec 15)"),
    os_qc_rule("DW-10", "symbol_mapping", symbols_given && cnt$n_tested > 0 && n_symbol_missing / cnt$n_tested > 0.05, "warning",
               sprintf("%d of %d tested features (%.1f%%) have no symbol in --gene-annotation.", n_symbol_missing, cnt$n_tested,
                       if (cnt$n_tested) 100 * n_symbol_missing / cnt$n_tested else 0),
               "Check that the annotation uses the same ID space and release as the count matrix; unmapped features show their ID.",
               "CONVENTIONS sec 8 (mapping loss > 5% is a QC warning)"),
    os_qc_rule("DW-11", "dispersion_fit_fallback", disp_fallback, "warning",
               "The parametric dispersion trend did not fit; DESeq2 substituted a local regression fit.",
               "State the local fit in the Methods, or rerun with --fit-type local so the choice is explicit.",
               "?estimateDispersions (fitType); DESeq2 vignette 'Local or mean dispersion fit'"),
    os_qc_rule("DW-12", "beta_convergence", r$n_beta_nonconv > 0, "info",
               sprintf("%d feature(s) did not converge in the GLM fit (mcols(dds)$betaConv = FALSE).", r$n_beta_nonconv),
               "Usually features with extreme counts; check them in tables/deseq2_results_full.csv before reporting them.",
               "?nbinomWaldTest (maxit, betaConv)")))
  os_qc_finalize(rows, read_first = "draft/methods_results.md")
}
