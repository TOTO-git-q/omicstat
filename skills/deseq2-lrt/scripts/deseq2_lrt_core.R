# deseq2_lrt_core.R -- core layer of module deseq2-lrt. ASCII only on purpose.
#
# Computation only: every DESeq2 call is registered in calls_registry.json with
# EVERY result-affecting argument written out, even where it equals the
# function default (lock 3). Values and their sources: references/parameters.md
# and PACK section D / S1 appendix.
#
# Unlike deseq2-wald (one two-level contrast, auto-assembled design from
# --condition/--target/--reference/--covariates), an LRT design is usually a
# multi-level factor, an interaction, or a time course, so this module takes
# the full and reduced design FORMULAS directly as text (S1 P-1: reduced has
# no default, never silently ~1). See build_worklog.md step 3 for the full
# CLI design rationale.

DL_MODULE <- "deseq2-lrt"
DL_MODULE_VERSION <- "1.1.0"
DL_DEFAULT_SEED <- 20260925L
DL_JOURNALS <- c("nature", "cell", "science", "generic")
# Replicate thresholds per design cell (same design class as deseq2-wald, PACK D
# "consistency with deseq2-wald"; ENGINEERING_PLAN 4.5)
DL_REPS_BLOCKER_BELOW <- 2L
DL_REPS_WARNING_BELOW <- 3L
DL_VST_NSUB <- 1000L

# DESeq2 vignette "Note on factor levels": "numbers, underscore and period are
# also allowed in design factor levels" (letters too); anything else (hyphen,
# space, ...) is not. This is the module's own gate, checked on every design
# variable's levels (not just the make.names-syntactic subset deseq2-wald
# uses for its condition/target/reference naming, because a canonical LRT
# design -- the fission time course -- has purely numeric levels like "15",
# "120" for `minute`, which make.names() would reject even though DESeq2
# accepts them).
DL_LEVEL_RE <- "^[A-Za-z0-9._]+$"

.dl_check_levels <- function(x, what) {
  bad <- x[!grepl(DL_LEVEL_RE, x)]
  if (length(bad)) {
    stop(sprintf(paste0("OS_INVALID_PARAMETER: %s value(s) %s contain characters other than letters, numbers, ",
                        "underscore and period; DESeq2 design factor levels are restricted to those (vignette, ",
                        "'Note on factor levels'). Rename them in the sample table."),
                 what, paste(sprintf("'%s'", utils::head(bad, 5)), collapse = ", ")), call. = FALSE)
  }
}

# Numeric-aware level ordering: a column of literal numbers (e.g. a time
# variable coded "0","15","30",...,"120") sorts by value, not lexically
# ("120" < "15" as strings); anything else sorts by radix. Order has no effect
# on the LRT statistic itself (which is invariant to which level is the
# reference), only on coefficient naming and figure legend order.
.dl_level_order <- function(x) {
  u <- unique(as.character(x))
  num <- suppressWarnings(as.numeric(u))
  if (!anyNA(num)) u[order(num)] else sort(u, method = "radix")
}

.dl_parse_formula <- function(txt, what) {
  if (is.null(txt) || !grepl("^\\s*~", txt)) {
    stop(sprintf("OS_INVALID_PARAMETER: --%s must be an R formula starting with '~' (got '%s').", what, txt %||% "NULL"), call. = FALSE)
  }
  f <- tryCatch(stats::as.formula(txt), error = function(e) {
    stop(sprintf("OS_INVALID_PARAMETER: --%s is not a valid R formula ('%s'): %s", what, txt, conditionMessage(e)), call. = FALSE)
  })
  if (length(f) != 2) stop(sprintf("OS_INVALID_PARAMETER: --%s must be a one-sided formula (got '%s').", what, txt), call. = FALSE)
  f
}

.dl_term_labels <- function(f) attr(stats::terms(f), "term.labels")

# Parameter-level checks BEFORE any data is touched: formula syntax, columns
# named in the formulas exist in the sample table, --adjust term labels (if
# given) are present in BOTH full and reduced (S1 P-1: "adjustment terms are
# kept in both"; not mechanically inferable from a raw formula pair without
# the user naming them -- see build_worklog.md 待裁决).
dl_check_design_args <- function(st, full_txt, reduced_txt, adjust) {
  full_f <- .dl_parse_formula(full_txt, "full")
  reduced_f <- .dl_parse_formula(reduced_txt, "reduced")
  vars_full <- all.vars(full_f)
  vars_reduced <- all.vars(reduced_f)
  miss <- setdiff(union(vars_full, vars_reduced), names(st))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: sample table has no column(s) %s named in --full/--reduced.", paste(miss, collapse = ", ")), call. = FALSE)
  terms_full <- .dl_term_labels(full_f)
  terms_reduced <- .dl_term_labels(reduced_f)
  if (length(adjust)) {
    for (tm in adjust) {
      here <- c(if (!tm %in% terms_full) "full", if (!tm %in% terms_reduced) "reduced")
      if (length(here)) {
        stop(sprintf("OS_INVALID_DESIGN: --adjust term '%s' is missing from the %s formula; adjustment terms must be kept in both --full and --reduced.",
                     tm, paste(here, collapse = " and ")), call. = FALSE)
      }
    }
  }
  list(full_f = full_f, reduced_f = reduced_f, vars_full = vars_full, vars_reduced = vars_reduced,
       terms_full = terms_full, terms_reduced = terms_reduced)
}

# The single design variable the user is most likely testing (used only to
# annotate figures -- the group_col never enters the fitted model beyond what
# --full/--reduced already specify). Explicit --group-col always wins.
dl_resolve_group_col <- function(st, group_col, vars_full, vars_reduced) {
  if (!is.null(group_col)) {
    if (!group_col %in% names(st)) stop(sprintf("OS_MISSING_COLUMN: --group-col '%s' is not a column of the sample table.", group_col), call. = FALSE)
    return(group_col)
  }
  cand <- setdiff(vars_full, vars_reduced)
  if (length(cand) == 1) return(cand)
  stop(sprintf(paste0("OS_MISSING_PARAMETER: --group-col was not given and cannot be inferred (candidates from --full ",
                      "not in --reduced: %s). Give --group-col explicitly to annotate figures."),
               if (length(cand)) paste(cand, collapse = ", ") else "none"), call. = FALSE)
}

# S1 follow-up (build_worklog.md step 3): an LRT design has no "two compared
# groups", so unlike deseq2-wald there is no automatic pre-filter rule at all
# -- --min-samples must always be given explicitly.
dl_check_prefilter_rule <- function(min_samples) {
  if (min_samples <= 0) {
    stop(paste0("OS_MISSING_PARAMETER: give the pre-filter rule explicitly with --min-samples <n> (features need a ",
               "count >= --min-count in at least n samples). An LRT design has no single pair of compared groups, so ",
               "this module has no automatic 'smallest group' rule (unlike deseq2-wald's two-group case)."), call. = FALSE)
  }
  invisible(TRUE)
}

dl_prefilter <- function(mat, min_count, min_samples) {
  keep <- rowSums(mat >= min_count) >= min_samples
  list(keep = keep, min_samples_used = as.integer(min_samples))
}

# Builds coldata (every design variable as a factor, DESeq2 vignette-style
# level check), checks full rank of both model matrices, a positive degrees-of-
# freedom difference, and that reduced is actually nested in full (its column
# space is reproducible from full's columns -- catches a reduced formula that
# names a term absent from full, or an unrelated formula pair).
dl_design <- function(st, full_txt, reduced_txt, adjust) {
  chk <- dl_check_design_args(st, full_txt, reduced_txt, adjust)
  cd <- data.frame(row.names = rownames(st))
  for (v in union(chk$vars_full, chk$vars_reduced)) {
    x <- st[[v]]
    if (anyNA(x)) stop(sprintf("OS_INVALID_DESIGN: design variable '%s' has missing values.", v), call. = FALSE)
    x <- as.character(x)
    .dl_check_levels(unique(x), sprintf("'%s'", v))
    cd[[v]] <- factor(x, levels = .dl_level_order(x))
  }
  mm_full <- stats::model.matrix(chk$full_f, data = cd)
  mm_reduced <- stats::model.matrix(chk$reduced_f, data = cd)
  if (qr(mm_full)$rank < ncol(mm_full)) stop(sprintf("OS_INVALID_DESIGN: --full %s is not full rank (a term is confounded or a level is empty).", full_txt), call. = FALSE)
  if (qr(mm_reduced)$rank < ncol(mm_reduced)) stop(sprintf("OS_INVALID_DESIGN: --reduced %s is not full rank (a term is confounded or a level is empty).", reduced_txt), call. = FALSE)
  df <- ncol(mm_full) - ncol(mm_reduced)
  if (df <= 0) {
    stop(sprintf("OS_INVALID_DESIGN: --full has %d parameter(s) and --reduced has %d; the difference must be > 0 (nothing is being tested).",
                 ncol(mm_full), ncol(mm_reduced)), call. = FALSE)
  }
  fit <- tryCatch(qr.solve(mm_full, mm_reduced), error = function(e) NULL)
  nested <- !is.null(fit)
  if (nested) {
    resid <- mm_reduced - mm_full %*% fit
    tol <- 1e-6 * max(1, max(abs(mm_reduced)))
    nested <- max(abs(resid)) <= tol
  }
  if (!nested) {
    stop(sprintf(paste0("OS_INVALID_DESIGN: --reduced %s is not nested in --full %s (its model matrix is not reproducible ",
                        "from the full model's columns). The reduced formula must remove term(s) of the full formula, ",
                        "not introduce a different one."), reduced_txt, full_txt), call. = FALSE)
  }
  tested_terms <- setdiff(chk$terms_full, chk$terms_reduced)
  list(coldata = cd, full_formula = full_txt, reduced_formula = reduced_txt, full_f = chk$full_f, reduced_f = chk$reduced_f,
       vars_full = chk$vars_full, vars_reduced = chk$vars_reduced, tested_terms = tested_terms, df = df)
}

deseq2_lrt_compute <- function(mat, st, a) {
  des <- dl_design(st, a$full, a$reduced, a$adjust)
  cd <- des$coldata
  pf <- dl_prefilter(mat, a[["min-count"]], a[["min-samples"]])
  if (sum(pf$keep) < 2) stop(sprintf("OS_DEGENERATE: only %d feature(s) pass the pre-filter (count >= %d in >= %d samples).", sum(pf$keep), a[["min-count"]], pf$min_samples_used), call. = FALSE)
  m <- mat[pf$keep, , drop = FALSE]
  storage.mode(m) <- "integer"
  dds <- DESeq2::DESeqDataSetFromMatrix(countData = m, colData = cd, design = des$full_f, tidy = FALSE, ignoreRank = FALSE)
  dds <- DESeq2::DESeq(dds, test = "LRT", fitType = a[["fit-type"]], sfType = a[["sf-type"]], betaPrior = FALSE,
                       full = des$full_f, reduced = des$reduced_f, minReplicatesForReplace = 7, minmu = 0.5,
                       quiet = TRUE, useT = FALSE, parallel = FALSE)
  rn <- DESeq2::resultsNames(dds)
  report_coef <- a[["report-coef"]]
  if (!is.null(report_coef) && !report_coef %in% rn) {
    stop(sprintf("OS_INVALID_PARAMETER: --report-coef '%s' is not one of resultsNames(dds): %s.", report_coef, paste(rn, collapse = ", ")), call. = FALSE)
  }
  # One results() call. `name` is always written out (lock 3, S4 F3): the
  # --report-coef value, else the last resultsNames() entry -- exactly what
  # results() itself substitutes for a missing `name` (DESeq2 1.52.0 body:
  # `if (missing(name)) name <- lastCoefName(object)`). With test = "LRT" the
  # `name` selects only the displayed log2FoldChange/lfcSE; stat, P and BH
  # adjusted P are the joint test's and do not depend on it (smoke test F3).
  used_coef <- report_coef %||% rn[length(rn)]
  res <- DESeq2::results(dds, name = used_coef, lfcThreshold = 0, altHypothesis = "greaterAbs", cooksCutoff = TRUE,
                         independentFiltering = TRUE, alpha = a$alpha, pAdjustMethod = "BH", format = "DataFrame",
                         test = "LRT", parallel = FALSE)
  # DESeq2's own printed header text (S4Vectors::mcols(res)$description), read
  # verbatim -- this is the exact source of the "log2 fold change (...)" /
  # "LRT p-value: '<full>' vs '<reduced>'" lines the vignette FAQ describes;
  # never reconstructed from memory.
  hdr <- stats::setNames(as.character(S4Vectors::mcols(res)$description), colnames(res))
  # Display-only transformation (heatmap). It never enters the LRT above; which
  # of the two calls ran is recorded for the Methods and the figure caption (S4 F2).
  n_vst_eligible <- sum(MatrixGenerics::rowMeans(DESeq2::counts(dds, normalized = TRUE)) > 5)
  vst_fallback <- n_vst_eligible < DL_VST_NSUB
  vs <- if (!vst_fallback) {
    DESeq2::vst(dds, blind = FALSE, nsub = DL_VST_NSUB, fitType = a[["fit-type"]])
  } else {
    DESeq2::varianceStabilizingTransformation(dds, blind = FALSE, fitType = a[["fit-type"]])
  }
  norm <- DESeq2::counts(dds, normalized = TRUE)
  maxcooks <- SummarizedExperiment::mcols(dds)$maxCooks
  beta_conv <- SummarizedExperiment::mcols(dds)$betaConv
  if (is.null(maxcooks)) maxcooks <- rep(NA_real_, nrow(dds))
  if (is.null(beta_conv)) beta_conv <- rep(NA, nrow(dds))
  list(dds = dds, res = res, design = des, sample_table = st, prefilter = pf, n_input = nrow(mat), used_coef = used_coef,
       header_log2fc = hdr[["log2FoldChange"]] %||% NA_character_, header_pvalue = hdr[["pvalue"]] %||% NA_character_,
       vst = SummarizedExperiment::assay(vs), vst_fallback = vst_fallback, n_vst_eligible = n_vst_eligible,
       norm = norm, size_factors = DESeq2::sizeFactors(dds),
       max_cooks = maxcooks, n_beta_nonconv = sum(!beta_conv, na.rm = TRUE))
}

# One row per tested feature. log2fc is the ONE coefficient DESeq2 prints
# (`used_coef`), never shrunk (no lfcShrink for a joint test, S1 P-3 +
# build_worklog.md 待裁决); stat is the LRT chi-squared statistic (difference
# in deviance), which is NON-NEGATIVE and carries no direction -- unlike
# deseq2-wald this module computes no n_up/n_down split and hands on no
# ranked_list (SUITE cross-module rule 2). n_group1/n_group2 are NA: an LRT is
# not, in general, a two-group comparison (safest honest encoding of
# FEATURE_TABLE_SCHEMA for a joint test).
dl_feature_table <- function(r, a, symbols = NULL) {
  res <- r$res
  reason <- ifelse(!is.na(res$padj), "",
                   ifelse(is.na(res$pvalue) & res$baseMean > 0, "outlier",
                          ifelse(res$baseMean == 0, "low_count", "independent_filtering")))
  ids <- rownames(res)
  df <- data.frame(feature_id = ids,
                   symbol = if (is.null(symbols)) "" else unname(ifelse(is.na(symbols[ids]), "", symbols[ids])),
                   contrast = sprintf("LRT: full %s vs reduced %s", r$design$full_formula, r$design$reduced_formula),
                   base_mean = res$baseMean, log2fc = res$log2FoldChange, log2fc_se = res$lfcSE, stat = res$stat,
                   pvalue = res$pvalue, padj = res$padj, method = "DESeq2 LRT", shrinkage = "none",
                   filtered_reason = reason, stringsAsFactors = FALSE)
  as_feature_table(df)
}

dl_full_table <- function(r, ft) {
  res <- r$res
  d <- data.frame(feature_id = rownames(res), base_mean = res$baseMean, log2fc = res$log2FoldChange,
                  log2fc_se = res$lfcSE, stat = res$stat, pvalue = res$pvalue, padj = res$padj,
                  max_cooks = r$max_cooks, stringsAsFactors = FALSE)
  d <- d[match(ft$feature_id, d$feature_id), , drop = FALSE]
  d$symbol <- ft$symbol
  d$filtered_reason <- ft$filtered_reason
  d[, c("feature_id", "symbol", setdiff(names(d), c("feature_id", "symbol")))]
}

dl_counts <- function(ft, alpha) {
  sig <- !is.na(ft$padj) & ft$padj < alpha
  list(n_tested = nrow(ft), n_sig = sum(sig), n_padj_na = sum(is.na(ft$padj)),
       n_outlier = sum(ft$filtered_reason == "outlier"), n_indep_filtered = sum(ft$filtered_reason == "independent_filtering"))
}
