# deseq2_wald_core.R -- core layer of module deseq2-wald. ASCII only on purpose.
#
# Computation only: every DESeq2 / apeglm / ashr call is registered in
# calls_registry.json with EVERY result-affecting argument written out, even
# where it equals the function default (lock 3). Values and their sources:
# references/parameters.md and PACK section D.

DW_MODULE <- "deseq2-wald"
DW_MODULE_VERSION <- "1.2.0"
DW_DEFAULT_SEED <- 20260925L
DW_SHRINKAGE <- c("apeglm", "ashr", "normal", "none")
DW_JOURNALS <- c("nature", "cell", "science", "generic")
# Replicate thresholds per group (PACK D-12; ENGINEERING_PLAN 4.5 design class)
DW_REPS_BLOCKER_BELOW <- 2L
DW_REPS_WARNING_BELOW <- 3L
# Size of the gene set below which vst() cannot subsample (DESeq2 vst nsub)
DW_VST_NSUB <- 1000L

# Syntactic R name check: DESeq2 builds coefficient names such as
# "condition_treated_vs_untreated" from the factor levels.
.dw_check_names <- function(x, what) {
  bad <- x[make.names(x) != x]
  if (length(bad)) {
    stop(sprintf(paste0("OS_INVALID_PARAMETER: %s value(s) %s are not syntactic R names (letters, digits, '.' and '_', ",
                        "not starting with a digit); DESeq2 cannot name its coefficients from them. Rename them in the sample table."),
                 what, paste(sprintf("'%s'", utils::head(bad, 5)), collapse = ", ")), call. = FALSE)
  }
}

# Build the design data frame: condition releveled to the reference (the
# coefficient then reads "<condition>_<target>_vs_<reference>"), covariates
# as factors. Returns list(coldata, formula_text, coef).
# Parameter-level checks of the design columns and levels; run on the input
# BEFORE the replicate rules, so a misspelled level is a parameter error and
# not "0 replicates".
dw_check_design_args <- function(st, condition, reference, target, covariates) {
  if (!condition %in% names(st)) stop(sprintf("OS_MISSING_COLUMN: sample table has no condition column '%s'.", condition), call. = FALSE)
  miss <- setdiff(covariates, names(st))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: --covariates names column(s) not in the sample table: %s.", paste(miss, collapse = ", ")), call. = FALSE)
  lv <- sort(unique(st[[condition]]), method = "radix")
  for (l in c(reference, target)) {
    if (!l %in% lv) stop(sprintf("OS_INVALID_PARAMETER: level '%s' is not a value of column '%s' (values: %s).", l, condition, paste(lv, collapse = ", ")), call. = FALSE)
  }
  if (identical(reference, target)) stop("OS_INVALID_PARAMETER: --reference and --target must differ.", call. = FALSE)
  invisible(lv)
}

# S1 P-3 (owner 2026-09-27): the automatic "smallest group" pre-filter is for
# a simple two-group design only. With covariates, or a condition column with
# more than two levels in the sample table, the user states the rule
# explicitly (--min-samples > 0); the module does not construct a "smallest
# group" for a complex design.
dw_check_prefilter_rule <- function(st, condition, covariates, min_samples) {
  n_levels <- length(unique(st[[condition]]))
  complex <- length(covariates) > 0 || n_levels > 2
  if (complex && min_samples == 0) {
    why <- c(if (length(covariates)) sprintf("covariates: %s", paste(covariates, collapse = ", ")),
             if (n_levels > 2) sprintf("%d levels in '%s'", n_levels, condition))
    stop(sprintf(paste0("OS_MISSING_PARAMETER: the design is not a simple two-group design (%s); give the pre-filter rule ",
                        "explicitly with --min-samples <n> (features need a count >= --min-count in at least n samples). ",
                        "The automatic smallest-group rule is only used for two-group designs (S1 P-3)."),
                 paste(why, collapse = "; ")), call. = FALSE)
  }
  invisible(complex)
}

# Display-only fold-change filter (S1 P-2, cross-module rule 1): features with
# padj < alpha AND |log2fc| >= the filter, where log2fc is the feature-table
# value (shrunken unless --shrinkage none). It never changes padj; the full
# table is always written; the filtered set keeps no FDR guarantee of its own.
dw_display_filter <- function(ft, alpha, lfc_filter) {
  if (!(lfc_filter > 0)) return(NULL)
  keep <- !is.na(ft$padj) & ft$padj < alpha & !is.na(ft$log2fc) & abs(ft$log2fc) >= lfc_filter
  ft[keep, , drop = FALSE]
}

dw_design <- function(st, condition, reference, target, covariates) {
  lv <- dw_check_design_args(st, condition, reference, target, covariates)
  .dw_check_names(c(condition, covariates), "column name")
  .dw_check_names(lv, sprintf("'%s'", condition))
  cd <- data.frame(row.names = rownames(st))
  for (cv in covariates) {
    v <- st[[cv]]
    if (anyNA(v)) stop(sprintf("OS_INVALID_DESIGN: covariate '%s' has missing values.", cv), call. = FALSE)
    .dw_check_names(sort(unique(v), method = "radix"), sprintf("'%s'", cv))
    cd[[cv]] <- factor(v, levels = sort(unique(v), method = "radix"))
  }
  cd[[condition]] <- stats::relevel(factor(st[[condition]], levels = lv), ref = reference)
  terms <- c(covariates, condition)
  ftxt <- paste("~", paste(terms, collapse = " + "))
  mm <- stats::model.matrix(stats::as.formula(ftxt), data = cd)
  if (qr(mm)$rank < ncol(mm)) {
    stop(sprintf(paste0("OS_INVALID_DESIGN: the design %s is not full rank (the condition is confounded with a covariate, ",
                        "or a covariate level is empty). Remove the confounded covariate or re-think the comparison."), ftxt), call. = FALSE)
  }
  list(coldata = cd, formula_text = ftxt, coef = paste0(condition, "_", target, "_vs_", reference))
}

# Pre-filter (DESeq2 vignette, "Pre-filtering"): keep features with a count of
# at least min_count in at least min_samples samples; min_samples = 0 means
# the smallest group size among the two compared groups. min_samples = 0 is
# only accepted for a simple two-group design (dw_check_prefilter_rule, S1 P-3).
dw_prefilter <- function(mat, group, reference, target, min_count, min_samples) {
  smallest <- min(sum(group == reference), sum(group == target))
  k <- if (min_samples > 0) min_samples else smallest
  keep <- rowSums(mat >= min_count) >= k
  list(keep = keep, min_samples_used = as.integer(k), smallest_group = as.integer(smallest))
}

deseq2_wald_compute <- function(mat, st, a) {
  des <- dw_design(st, a$condition, a$reference, a$target, a$covariates)
  cd <- des$coldata
  pf <- dw_prefilter(mat, as.character(cd[[a$condition]]), a$reference, a$target, a[["min-count"]], a[["min-samples"]])
  if (sum(pf$keep) < 2) stop(sprintf("OS_DEGENERATE: only %d feature(s) pass the pre-filter (count >= %d in >= %d samples).", sum(pf$keep), a[["min-count"]], pf$min_samples_used), call. = FALSE)
  m <- mat[pf$keep, , drop = FALSE]
  storage.mode(m) <- "integer"
  dds <- DESeq2::DESeqDataSetFromMatrix(countData = m, colData = cd, design = stats::as.formula(des$formula_text),
                                        tidy = FALSE, ignoreRank = FALSE)
  dds <- DESeq2::DESeq(dds, test = "Wald", fitType = a[["fit-type"]], sfType = a[["sf-type"]], betaPrior = FALSE,
                       minReplicatesForReplace = 7, useT = FALSE, minmu = 0.5, quiet = TRUE, parallel = FALSE)
  if (!des$coef %in% DESeq2::resultsNames(dds)) {
    stop(sprintf("OS_INVALID_PARAMETER: coefficient %s not estimated (have: %s).", des$coef, paste(DESeq2::resultsNames(dds), collapse = ", ")), call. = FALSE)
  }
  res <- DESeq2::results(dds, contrast = c(a$condition, a$target, a$reference), lfcThreshold = a[["lfc-threshold"]],
                         altHypothesis = "greaterAbs", cooksCutoff = TRUE, independentFiltering = TRUE,
                         alpha = a$alpha, pAdjustMethod = "BH", format = "DataFrame", test = "Wald", parallel = FALSE)
  # One lfcShrink call for every estimator: all arguments written out; apeAdapt
  # and apeMethod are read by type = "apeglm" only, svalue by apeglm/ashr only.
  shr <- NULL
  if (a$shrinkage != "none") {
    shr <- DESeq2::lfcShrink(dds, coef = des$coef, res = res, type = a$shrinkage, lfcThreshold = 0, svalue = FALSE,
                             apeAdapt = TRUE, apeMethod = "nbinomCR", format = "DataFrame", parallel = FALSE, quiet = TRUE)
  }
  norm <- DESeq2::counts(dds, normalized = TRUE)
  # vst() subsamples nsub rows among those with mean normalized count > 5
  # and stops (untyped) when fewer are eligible; DESeq2 recommends
  # varianceStabilizingTransformation() directly then. Choose the path from
  # the eligible rows, exactly as vst() tests them (S3 F1), and record it.
  n_vst_eligible <- sum(rowMeans(norm) > 5)
  vst_path <- if (nrow(dds) >= DW_VST_NSUB && n_vst_eligible >= DW_VST_NSUB) "vst" else "varianceStabilizingTransformation"
  vs <- if (identical(vst_path, "vst")) {
    DESeq2::vst(dds, blind = FALSE, nsub = DW_VST_NSUB, fitType = a[["fit-type"]])
  } else {
    DESeq2::varianceStabilizingTransformation(dds, blind = FALSE, fitType = a[["fit-type"]])
  }
  maxcooks <- SummarizedExperiment::mcols(dds)$maxCooks
  beta_conv <- SummarizedExperiment::mcols(dds)$betaConv
  native_p_column <- paste0("WaldPvalue_", des$coef)
  native_p <- if (native_p_column %in% names(SummarizedExperiment::mcols(dds)))
    SummarizedExperiment::mcols(dds)[[native_p_column]] else NULL
  list(dds = dds, res = res, shr = shr, vst = SummarizedExperiment::assay(vs), norm = norm, design = des, prefilter = pf,
       vst_path = vst_path, n_vst_eligible = n_vst_eligible,
       n_input = nrow(mat), sample_metadata = st, coef = des$coef, size_factors = DESeq2::sizeFactors(dds),
       max_cooks = maxcooks, beta_convergence = beta_conv, native_zero_null_coefficient_p = native_p,
       n_beta_nonconv = sum(!beta_conv, na.rm = TRUE),
       n_ref = sum(cd[[a$condition]] == a$reference), n_target = sum(cd[[a$condition]] == a$target),
       samples_ref = rownames(cd)[cd[[a$condition]] == a$reference],
       samples_target = rownames(cd)[cd[[a$condition]] == a$target])
}

# One row per tested feature (canonical feature table). log2fc is the shrunken
# estimate unless --shrinkage none (FEATURE_TABLE_SCHEMA); stat, pvalue and
# padj always come from the unshrunken Wald test.
# Missingness is attributed only when the native result/diagnostics support it.
# Unknown failures are not automatically labelled as Cook's outliers.
# The stored zero-null coefficient P is diagnostic only; the selected-threshold
# P and adjusted P still come exclusively from the original results() object.
dw_missing_reason <- function(pvalue, padj, base_mean, native_zero_null_coefficient_p = NULL, beta_convergence = NULL) {
  n <- length(pvalue)
  if (length(padj) != n || length(base_mean) != n ||
      (!is.null(native_zero_null_coefficient_p) && length(native_zero_null_coefficient_p) != n) ||
      (!is.null(beta_convergence) && length(beta_convergence) != n))
    stop("OS_INVALID_RESULT: native missing-result diagnostics are misaligned.", call. = FALSE)
  reason <- rep("", n); reason[is.na(padj)] <- "unknown"
  reason[is.na(padj) & is.finite(pvalue)] <- "independent_filtering"
  zero <- is.finite(base_mean) & base_mean == 0
  reason[is.na(pvalue) & zero] <- "low_count"
  if (!is.null(native_zero_null_coefficient_p))
    reason[is.na(pvalue) & !zero & is.finite(native_zero_null_coefficient_p)] <- "outlier"
  if (!is.null(beta_convergence))
    reason[is.na(pvalue) & !zero & beta_convergence %in% FALSE] <- "failed_model"
  reason
}

dw_feature_table <- function(r, a, symbols = NULL) {
  res <- r$res
  lfc <- if (is.null(r$shr)) res$log2FoldChange else r$shr$log2FoldChange
  se <- if (is.null(r$shr)) res$lfcSE else r$shr$lfcSE
  reason <- dw_missing_reason(res$pvalue, res$padj, res$baseMean, r$native_zero_null_coefficient_p, r$beta_convergence)
  ids <- rownames(res)
  df <- data.frame(feature_id = ids,
                   symbol = if (is.null(symbols)) "" else unname(ifelse(is.na(symbols[ids]), "", symbols[ids])),
                   contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference),
                   base_mean = res$baseMean, log2fc = lfc, log2fc_se = se, stat = res$stat,
                   pvalue = res$pvalue, padj = res$padj,
                   method = "DESeq2 Wald", shrinkage = a$shrinkage,
                   n_group1 = r$n_target, n_group2 = r$n_ref, filtered_reason = reason,
                   stringsAsFactors = FALSE)
  as_feature_table(df)
}

# Full results table (supplement): MLE and shrunken LFC side by side.
dw_full_table <- function(r, ft) {
  res <- r$res
  d <- data.frame(feature_id = rownames(res), base_mean = res$baseMean,
                  log2fc_mle = res$log2FoldChange, log2fc_se_mle = res$lfcSE,
                  log2fc_shrunken = if (is.null(r$shr)) NA_real_ else r$shr$log2FoldChange,
                  log2fc_se_shrunken = if (is.null(r$shr)) NA_real_ else r$shr$lfcSE,
                  stat = res$stat, pvalue = res$pvalue, padj = res$padj,
                  max_cooks = r$max_cooks, stringsAsFactors = FALSE)
  d <- d[match(ft$feature_id, d$feature_id), , drop = FALSE]
  d$symbol <- ft$symbol
  d$filtered_reason <- ft$filtered_reason
  d[, c("feature_id", "symbol", setdiff(names(d), c("feature_id", "symbol")))]
}

# Direction from the sign of the Wald statistic (= sign of the MLE LFC), as
# DESeq2's summary() counts it; shrinkage never changes the call.
dw_counts <- function(ft, alpha) {
  sig <- !is.na(ft$padj) & ft$padj < alpha
  list(n_tested = nrow(ft), n_sig = sum(sig), n_up = sum(sig & ft$stat > 0), n_down = sum(sig & ft$stat < 0),
       n_padj_na = sum(is.na(ft$padj)), n_outlier = sum(ft$filtered_reason == "outlier"),
       n_indep_filtered = sum(ft$filtered_reason == "independent_filtering"))
}
