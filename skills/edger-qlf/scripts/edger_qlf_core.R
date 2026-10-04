# edgeR QL F-test / optional glmTreat, with design-aware expression filtering.
EQ_MODULE <- "edger-qlf"
EQ_MODULE_VERSION <- "1.1.0"
EQ_DEFAULT_SEED <- 20260925L
EQ_JOURNALS <- c("nature", "cell", "science", "generic")
EQ_REPS_BLOCKER_BELOW <- 2L
EQ_REPS_WARNING_BELOW <- 3L
EQ_MDS_TOP <- 500L
EQ_CPM_PRIOR_COUNT <- 2

eq_check_design_args <- function(st, condition, reference, target, covariates) {
  miss <- setdiff(c(condition, covariates), names(st))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: sample table lacks %s.", paste(miss, collapse = ", ")), call. = FALSE)
  if (condition %in% covariates) stop("OS_CONFLICTING_PARAMETERS: --condition cannot also be a covariate.", call. = FALSE)
  if (identical(reference, target)) stop("OS_INVALID_PARAMETER: --reference and --target must differ.", call. = FALSE)
  lv <- sort(unique(as.character(st[[condition]])), method = "radix")
  if (!all(c(reference, target) %in% lv)) stop(sprintf("OS_INVALID_PARAMETER: reference/target must be present in %s (levels: %s).", condition, paste(lv, collapse = ", ")), call. = FALSE)
  invisible(lv)
}

eq_design <- function(st, a) {
  lv <- eq_check_design_args(st, a$condition, a$reference, a$target, a$covariates)
  cd <- data.frame(row.names = rownames(st))
  cd$.eqgrp <- factor(as.character(st[[a$condition]]), levels = lv)
  for (cv in a$covariates) {
    if (anyNA(st[[cv]])) stop(sprintf("OS_INVALID_DESIGN: covariate '%s' has missing values.", cv), call. = FALSE)
    cd[[cv]] <- factor(st[[cv]], levels = sort(unique(st[[cv]]), method = "radix"))
  }
  ftxt <- paste0("~ 0 + .eqgrp", if (length(a$covariates)) paste0(" + ", paste(a$covariates, collapse = " + ")) else "")
  mm <- stats::model.matrix(stats::as.formula(ftxt), data = cd)
  if (qr(mm)$rank < ncol(mm)) stop("OS_INVALID_DESIGN: the group/covariate model is not full rank; remove a confounded covariate.", call. = FALSE)
  ref_col <- paste0(".eqgrp", a$reference)
  tar_col <- paste0(".eqgrp", a$target)
  if (!all(c(ref_col, tar_col) %in% colnames(mm))) stop("OS_INVALID_DESIGN: contrast levels do not map to model columns.", call. = FALSE)
  contrast <- stats::setNames(rep(0, ncol(mm)), colnames(mm))
  contrast[tar_col] <- 1; contrast[ref_col] <- -1
  list(coldata = cd, matrix = mm, contrast = contrast, formula_text = ftxt, levels = lv,
       n_reference = sum(cd$.eqgrp == a$reference), n_target = sum(cd$.eqgrp == a$target))
}

edger_qlf_compute <- function(mat, st, a) {
  des <- eq_design(st, a)
  y <- edgeR::DGEList(counts = mat, lib.size = NULL, norm.factors = NULL, samples = NULL,
                       group = des$coldata$.eqgrp, genes = NULL, remove.zeros = FALSE)
  keep <- edgeR::filterByExpr(y, design = des$matrix, group = NULL, lib.size = NULL,
                              min.count = a[["min-count"]], min.total.count = a[["min-total-count"]],
                              large.n = a[["large-n"]], min.prop = a[["min-prop"]])
  if (sum(keep) < 2) stop(sprintf("OS_DEGENERATE: only %d gene(s) passed filterByExpr.", sum(keep)), call. = FALSE)
  y <- y[keep, , keep.lib.sizes = FALSE]
  y <- edgeR::normLibSizes(y, method = "TMM", refColumn = NULL, logratioTrim = 0.3,
                           sumTrim = 0.05, doWeighting = TRUE, Acutoff = -1e10, p = 0.75)
  # Only for the BCV diagnostic; this trended dispersion is not fed into glmQLFit.
  bcv <- edgeR::estimateDisp(y, design = des$matrix, prior.df = NULL, trend.method = "locfit",
                             tagwise = TRUE, span = NULL, legacy.span = FALSE, min.row.sum = 5,
                             grid.length = 21, grid.range = c(-10, 10), robust = TRUE,
                             winsor.tail.p = c(0.05, 0.1), tol = 1e-6)
  # The legacy branch needs the estimated dispersions stored on its DGEList.
  # The new branch fits directly from the TMM-normalized counts.
  fit_input <- if (isTRUE(a$legacy)) bcv else y
  fit <- edgeR::glmQLFit(fit_input, design = des$matrix, dispersion = NULL, abundance.trend = TRUE,
                         robust = TRUE, winsor.tail.p = c(0.05, 0.1), legacy = isTRUE(a$legacy),
                         top.proportion = NULL, keep.unit.mat = FALSE)
  test <- if (a[["treat-fc"]] > 0) {
    edgeR::glmTreat(fit, coef = NULL, contrast = des$contrast, lfc = log2(a[["treat-fc"]]), null = "interval")
  } else {
    edgeR::glmQLFTest(fit, coef = NULL, contrast = des$contrast, poisson.bound = TRUE)
  }
  tt <- edgeR::topTags(test, n = Inf, adjust.method = "BH", sort.by = "none", p.value = 1)$table
  logcpm <- edgeR::cpm(y, normalized.lib.sizes = TRUE, log = TRUE, prior.count = EQ_CPM_PRIOR_COUNT)
  # Sample MDS as in User's Guide 4.4.5 plotMDS(y): edgeR's plotMDS.DGEList
  # computes cpm(y, log = TRUE, prior.count = 2) and calls limma's plotMDS
  # with top = 500 and pairwise (leading log2 fold change) gene selection.
  mds <- limma::plotMDS(logcpm, top = EQ_MDS_TOP, labels = NULL, pch = NULL, cex = 1, dim.plot = c(1, 2),
                        gene.selection = "pairwise", xlab = NULL, ylab = NULL, plot = FALSE, var.explained = TRUE)
  list(design = des, y = y, bcv = bcv, fit = fit, test = test, table = tt, logcpm = logcpm,
       ql = eq_ql_disp_data(fit), mds = mds,
       n_input = nrow(mat), n_kept = sum(keep), n_filtered = sum(!keep),
       used_treat = a[["treat-fc"]] > 0)
}

# QL dispersion display quantities, read from the fitted DGEGLM exactly as
# edgeR 4.10.5 plotQLDisp() does (source printed by
# acceptance/exemplars/edger-qlf/_s4/probe_source.R): x = fit$AveLogCPM; raw =
# deviance.adj / df.residual.adj (new method) or deviance / df.residual.zeros
# (legacy), set to 0 where df < 1e-8; squeezed = s2.post; trend = s2.prior.
eq_ql_disp_data <- function(fit) {
  a <- fit$AveLogCPM
  if (is.null(a)) stop("OS_DEGENERATE: the QL fit carries no AveLogCPM for the QL dispersion display.", call. = FALSE)
  if (is.null(fit$df.residual.zeros)) {
    df <- fit$df.residual.adj; dev <- fit$deviance.adj
  } else {
    df <- fit$df.residual.zeros; dev <- fit$deviance
  }
  s2 <- dev / df
  s2[df < 1e-8] <- 0
  n <- length(a)
  data.frame(feature_id = rownames(fit$coefficients), ave_logcpm = a, raw = s2, squeezed = fit$s2.post,
             trended = rep_len(fit$s2.prior, n), df_prior = rep_len(fit$df.prior, n), stringsAsFactors = FALSE)
}

eq_feature_table <- function(r, a, symbols = NULL) {
  t <- r$table
  ids <- rownames(t)
  df <- data.frame(feature_id = ids,
                   symbol = if (is.null(symbols)) "" else unname(ifelse(is.na(symbols[ids]), "", symbols[ids])),
                   contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference),
                   base_mean = t$logCPM, log2fc = t$logFC,
                   log2fc_se = NA_real_, stat = if ("F" %in% names(t)) t$F else NA_real_,
                   pvalue = t$PValue, padj = t$FDR,
                   method = if (r$used_treat) "edgeR glmTreat" else "edgeR QLF",
                   shrinkage = "none", n_group1 = r$design$n_target,
                   n_group2 = r$design$n_reference, filtered_reason = "", stringsAsFactors = FALSE)
  as_feature_table(df)
}

eq_full_table <- function(r, ft) {
  t <- data.frame(feature_id = rownames(r$table), r$table, check.names = FALSE)
  t <- t[match(ft$feature_id, t$feature_id), , drop = FALSE]
  t$symbol <- ft$symbol
  t[, c("feature_id", "symbol", setdiff(names(t), c("feature_id", "symbol"))), drop = FALSE]
}

eq_counts <- function(ft, alpha) {
  sig <- !is.na(ft$padj) & ft$padj <= alpha
  list(n_tested = nrow(ft), n_sig = sum(sig), n_down = sum(sig & ft$log2fc < 0),
       n_up = sum(sig & ft$log2fc > 0), n_notsig = sum(!sig))
}

eq_display_filter <- function(ft, alpha, threshold) {
  if (threshold <= 0) return(NULL)
  ft[!is.na(ft$padj) & ft$padj <= alpha & abs(ft$log2fc) >= threshold, , drop = FALSE]
}
