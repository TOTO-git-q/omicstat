# omicstat_selftest_report.R -- report layer of module omicstat-selftest. ASCII only on purpose.
# Figures: call the _shared builders (os_volcano) and os_finalize_figure();
# never set colours, sizes or positions here. Every file is written with LF
# line endings and without timestamps so reruns are byte-identical.

ST_PADJ <- 0.05
ST_LFC <- 1

.st_write_text <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
  invisible(path)
}

.st_md_cell <- function(x) gsub("|", "\\|", as.character(x), fixed = TRUE)

# Counts the draft and results JSON quote; same classification as the volcano
# (padj < ST_PADJ and |log2fc| > ST_LFC; padj = NA rows counted separately).
st_counts <- function(ft) {
  na <- is.na(ft$padj)
  sig <- !na & ft$padj < ST_PADJ & abs(ft$log2fc) > ST_LFC
  list(n_features = nrow(ft), n_up = sum(sig & ft$log2fc > 0), n_down = sum(sig & ft$log2fc < 0),
       n_ns = sum(!na & !sig), n_padj_na = sum(na))
}

omicstat_selftest_render <- function(res, outdir, journal, figure_ok) {
  out <- list(feature_table = file.path(outdir, "tables", "feature_table.csv"), figure = NULL)
  dir.create(dirname(out$feature_table), recursive = TRUE, showWarnings = FALSE)
  write_feature_table(res$feature_table, out$feature_table)
  if (figure_ok) {
    p <- os_volcano(res$feature_table, padj_threshold = ST_PADJ, lfc_threshold = ST_LFC,
                    contrast_label = "Synthetic fixture: treated vs control",
                    method_label = "self-test fixture, not an analysis", journal = journal)
    fig <- os_finalize_figure(p, file.path(outdir, "figures", "volcano"), width = "single", journal = journal, root = outdir)
    out$figure <- list(spec = fig$spec, counts = fig$spec_obj$counts, font_family = fig$spec_obj$font_family)
  }
  out
}

omicstat_selftest_draft <- function(res, qc, counts, outdir, seed, journal, figure) {
  pr <- res$probe
  trig <- qc$table[qc$table$triggered, , drop = FALSE]
  lines <- c(
    "# omicstat-selftest: environment self-test (not an analysis)",
    "",
    "This run checked the omicstat R environment. Its table and figure come from a synthetic",
    "shape fixture and must never be reported as findings.",
    "",
    "## Methods",
    "",
    sprintf(paste("The omicstat environment self-test (module %s %s) compared the running R session with the",
                  "environment pins in env/r-env.json (env_version %s: R %s, Bioconductor %s) using %d",
                  "rules (ST-01 to ST-%02d). A deterministic synthetic feature table (%s features, seed %d) was",
                  "written with the shared feature-table writer and drawn as a volcano plot with the shared",
                  "figure layer (journal preset %s; adjusted P < %s and |log2 fold change| > %s)."),
            ST_MODULE, ST_MODULE_VERSION, pr$env_version %||% "unknown", pr$r_pin %||% "unknown",
            pr$bioc_pin %||% "unknown", qc$n_rules, qc$n_rules, format(counts$n_features, big.mark = ","),
            seed, journal, ST_PADJ, ST_LFC),
    "",
    "## Results",
    "",
    sprintf("Execution environment: %s; %s.", pr$mode, pr$r_version_string),
    sprintf("%d of %d environment rules were triggered%s.", qc$n_triggered, qc$n_rules,
            if (nrow(trig)) paste0(" (", paste(sprintf("%s %s", trig$id, trig$severity), collapse = ", "), ")") else ""),
    if (qc$failed) sprintf("The environment check FAILED on: %s. See environment_report.md.", paste(qc$failed_ids, collapse = ", "))
    else "No blocker or error rule was triggered: the environment check passed.",
    sprintf(paste("The synthetic table held %s features: %d up and %d down (adjusted P < %s and |log2 fold",
                  "change| > %s), %d not significant, %d with adjusted P = NA after independent filtering."),
            format(counts$n_features, big.mark = ","), counts$n_up, counts$n_down, ST_PADJ, ST_LFC,
            counts$n_ns, counts$n_padj_na),
    if (is.null(figure)) "The volcano figure was NOT drawn because a required figure package is missing (ST-06)."
    else sprintf("The volcano figure was drawn in %s (figures/volcano.pdf, .png, .figure_spec.json).", figure$font_family)
  )
  .st_write_text(lines, file.path(outdir, "draft", "methods_results.md"))
}

omicstat_selftest_environment_report <- function(res, qc, outdir, figure) {
  pr <- res$probe
  tab <- qc$table
  status <- ifelse(!tab$triggered, "pass", ifelse(tab$severity %in% ST_FAIL_SEVERITIES, "FAIL", "warn"))
  pk <- pr$packages
  lines <- c(
    "# omicstat environment report",
    "",
    sprintf("Verdict: **%s** -- %d of %d rules triggered%s.",
            if (qc$failed) "FAIL" else "PASS", qc$n_triggered, qc$n_rules,
            if (qc$failed) paste0("; failing: ", paste(qc$failed_ids, collapse = ", ")) else ""),
    "",
    "| Rule | Check | Severity | Status | Message | Action |",
    "|---|---|---|---|---|---|",
    sprintf("| %s | %s | %s | %s | %s | %s |", tab$id, tab$check, tab$severity, status,
            .st_md_cell(tab$message), .st_md_cell(tab$action)),
    "",
    "## Session",
    "",
    sprintf("- Execution environment: %s", pr$mode),
    sprintf("- R: %s (pin %s)", pr$r_version_string, pr$r_pin %||% "unknown"),
    sprintf("- Bioconductor: %s (pin %s)", if (is.na(pr$bioc_version)) "not installed" else pr$bioc_version, pr$bioc_pin %||% "unknown"),
    sprintf("- Platform: %s", pr$platform),
    sprintf("- Environment pins: %s (env_version %s)", pr$env_config_path %||% "not found", pr$env_version %||% "unknown"),
    sprintf("- LC_CTYPE at start: %s; now: %s", pr$lc_ctype_start, pr$lc_ctype_now),
    sprintf("- %s = '%s'", names(pr$threads), unname(pr$threads)),
    sprintf("- Figure font: %s", if (is.null(figure)) "not drawn" else figure$font_family),
    "",
    "## Library search path",
    "",
    sprintf("- `%s`%s", pr$lib_paths, ifelse(pr$lib_paths %in% pr$leaked_lib_paths & pr$mode == "native", "  <- outside the omicstat library", "")),
    "",
    "## Figure-layer packages",
    "",
    "| Package | Required | Loadable | Version |",
    "|---|---|---|---|",
    sprintf("| %s | %s | %s | %s |", pk$package, ifelse(pk$required, "yes", "no"), ifelse(pk$loadable, "yes", "NO"),
            ifelse(is.na(pk$version), "-", pk$version))
  )
  .st_write_text(lines, file.path(outdir, "environment_report.md"))
}

omicstat_selftest_results_json <- function(res, qc, counts, outdir) {
  pr <- res$probe
  doc <- list(module = ST_MODULE, module_version = ST_MODULE_VERSION, execution_mode = pr$mode,
              env_version = pr$env_version %||% NA, r_version = pr$r_version, r_pin = pr$r_pin %||% NA,
              environment_ok = !qc$failed, n_rules = qc$n_rules, n_triggered = qc$n_triggered,
              failed_rules = as.list(qc$failed_ids), n_features = counts$n_features, n_up = counts$n_up,
              n_down = counts$n_down, n_ns = counts$n_ns, n_padj_na = counts$n_padj_na)
  path <- file.path(outdir, "results", "selftest_summary.json")
  .st_write_text(jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null"), path)
}
