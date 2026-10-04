# deseq2_qc_core.R -- core layer of module deseq2-qc. ASCII only on purpose.
#
# Sample-level QA: DESeq2 vst/rlog transform (blind = TRUE by default, PACK
# S1 P-1), the plotPCA computation up to a whole-component sign (_shared os_pca_scores), the
# sample-to-sample Euclidean distance matrix and a PURELY DESCRIPTIVE
# per-sample table (PC coordinates and size factors). P-2 (an outlier statistic/threshold) is class C,
# pending the owner: this module NEVER turns any of these numbers into an
# outlier call, a QC warning keyed to a threshold, or an automatic removal.
# Every DESeq2 call is registered in calls_registry.json with every
# result-affecting argument written out, even where it equals the function
# default (lock 3). Values and their sources: references/parameters.md and
# PACK section D / "S1 审定附录".

DQ_MODULE <- "deseq2-qc"
DQ_MODULE_VERSION <- "1.1.0"
DQ_DEFAULT_SEED <- 20260925L
DQ_TRANSFORMS <- c("vst", "rlog")
DQ_JOURNALS <- c("nature", "cell", "science", "generic")
# vst() subsamples nsub genes with mean normalized count > 5 to fit the
# dispersion trend; below this the wrapper cannot subsample and falls back to
# varianceStabilizingTransformation() (PACK X; same fallback deseq2-wald uses).
DQ_VST_NSUB <- 1000L
# Below this many total samples, prcomp cannot produce two non-trivial
# principal components (rank = n - 1) for the fixed PCs 1:2 plot.
DQ_MIN_SAMPLES_FOR_PCA <- 3L

# ---------------------------------------------------------------------------
# Design (no contrast is fit here: no --reference/--target, no releveling).
# ---------------------------------------------------------------------------
dq_check_design_args <- function(st, condition, covariates) {
  if (!condition %in% names(st)) stop(sprintf("OS_MISSING_COLUMN: sample table has no condition column '%s'.", condition), call. = FALSE)
  miss <- setdiff(covariates, names(st))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: --covariates names column(s) not in the sample table: %s.", paste(miss, collapse = ", ")), call. = FALSE)
  invisible(sort(unique(st[[condition]]), method = "radix"))
}

dq_design <- function(st, condition, covariates, shape_col = NULL) {
  lv <- dq_check_design_args(st, condition, covariates)
  if (!is.null(shape_col) && !shape_col %in% names(st)) {
    stop(sprintf("OS_MISSING_COLUMN: --shape-col names column '%s', not in the sample table.", shape_col), call. = FALSE)
  }
  cd <- data.frame(row.names = rownames(st))
  for (cv in covariates) {
    v <- st[[cv]]
    if (anyNA(v)) stop(sprintf("OS_INVALID_DESIGN: covariate '%s' has missing values.", cv), call. = FALSE)
    cd[[cv]] <- factor(v, levels = sort(unique(v), method = "radix"))
  }
  cd[[condition]] <- factor(st[[condition]], levels = lv)
  ftxt <- paste("~", paste(c(covariates, condition), collapse = " + "))
  mm <- stats::model.matrix(stats::as.formula(ftxt), data = cd)
  if (qr(mm)$rank < ncol(mm)) {
    stop(sprintf(paste0("OS_INVALID_DESIGN: the design %s is not full rank (a covariate is confounded with %s, ",
                        "or a covariate level is empty). Remove the confounded covariate."), ftxt, condition), call. = FALSE)
  }
  # --shape-col rides along in coldata for display only (PCA point shape); it
  # is never part of the design formula and never affects the model matrix.
  if (!is.null(shape_col)) cd[[shape_col]] <- as.character(st[[shape_col]])
  list(coldata = cd, formula_text = ftxt, levels = lv)
}

# Pre-filter (DESeq2 vignette, "Pre-filtering"; same rule as deseq2-wald D-11):
# keep features with a count of at least min_count in at least min_samples
# samples. min_samples = 0 auto-resolves to the smallest --condition level
# ONLY for a simple design (no --covariates, exactly two condition levels);
# a complex design (covariates, or 3+ levels) needs an explicit --min-samples,
# per BUILDER_BRIEF sec 6 (mirrors deseq2-wald's P-3 pattern).
dq_prefilter <- function(mat, condition, covariates, min_count, min_samples) {
  lv <- sort(unique(condition), method = "radix")
  simple <- length(covariates) == 0 && length(lv) == 2
  if (min_samples <= 0 && !simple) {
    stop(paste0("OS_MISSING_PARAMETER: --min-samples must be given explicitly (design is not a simple ",
                "two-level, no-covariate case: ", length(lv), " condition level(s), ", length(covariates),
                " covariate(s)). Give the pre-filter sample count explicitly."), call. = FALSE)
  }
  smallest <- as.integer(min(table(condition)))
  k <- if (min_samples > 0) min_samples else smallest
  keep <- rowSums(mat >= min_count) >= k
  list(keep = keep, min_samples_used = as.integer(k), smallest_group = smallest, simple_design = simple)
}

# One call for either transform, with the vst-nsub fallback (PACK X).
dq_transform <- function(dds, transform, blind, fit_type) {
  if (identical(transform, "rlog")) {
    m <- DESeq2::rlog(dds, blind = blind, fitType = fit_type)
    return(list(assay = SummarizedExperiment::assay(m), fallback = FALSE, n_eligible = NA_integer_))
  }
  n_eligible <- sum(MatrixGenerics::rowMeans(DESeq2::counts(dds, normalized = TRUE)) > 5)
  if (n_eligible >= DQ_VST_NSUB) {
    m <- DESeq2::vst(dds, blind = blind, nsub = DQ_VST_NSUB, fitType = fit_type)
    list(assay = SummarizedExperiment::assay(m), fallback = FALSE, n_eligible = n_eligible)
  } else {
    m <- DESeq2::varianceStabilizingTransformation(dds, blind = blind, fitType = fit_type)
    list(assay = SummarizedExperiment::assay(m), fallback = TRUE, n_eligible = n_eligible)
  }
}

deseq2_qc_compute <- function(mat, st, a) {
  des <- dq_design(st, a$condition, a$covariates, shape_col = a[["shape-col"]])
  cd <- des$coldata
  pf <- dq_prefilter(mat, as.character(cd[[a$condition]]), a$covariates, a[["min-count"]], a[["min-samples"]])
  if (sum(pf$keep) < 2) stop(sprintf("OS_DEGENERATE: only %d feature(s) pass the pre-filter (count >= %d in >= %d samples).", sum(pf$keep), a[["min-count"]], pf$min_samples_used), call. = FALSE)
  m <- mat[pf$keep, , drop = FALSE]
  storage.mode(m) <- "integer"
  dds <- DESeq2::DESeqDataSetFromMatrix(countData = m, colData = cd, design = stats::as.formula(des$formula_text),
                                        tidy = FALSE, ignoreRank = FALSE)
  # geoMeans/controlGenes/normMatrix have missing-argument defaults in this
  # S4 method. Supplying NULL changes the estimator's missing() branches.
  dds <- DESeq2::estimateSizeFactors(dds, type = a[["sf-type"]], locfunc = stats::median,
                                     quiet = FALSE)
  tr <- dq_transform(dds, a$transform, blind = TRUE, fit_type = a[["fit-type"]])
  supp <- NULL
  if (isTRUE(a[["blind-false-supplement"]])) {
    supp <- dq_transform(dds, a$transform, blind = FALSE, fit_type = a[["fit-type"]])
  }
  pca <- os_pca_scores(tr$assay, ntop = a$ntop)
  pca_supp <- if (!is.null(supp)) os_pca_scores(supp$assay, ntop = a$ntop) else NULL
  list(dds = dds, transform = tr, supplement = supp, pca = pca, pca_supplement = pca_supp,
       design = des, prefilter = pf, n_input = nrow(mat), n_samples = ncol(mat),
       size_factors = DESeq2::sizeFactors(dds), levels = des$levels)
}

# Descriptive per-sample table (PACK T; P-2 SAFE INTERIM): sample, condition
# (+ shape-col if given), size factor and PC1/PC2 scores. The centroid-distance
# statistic remains undefined while the owner's P-2 decision is pending.
dq_sample_table <- function(res, a) {
  sc <- res$pca$scores[, c("sample", "PC1", "PC2")]
  cd <- res$design$coldata
  sc$condition <- as.character(cd[[a$condition]])[match(sc$sample, rownames(cd))]
  if (!is.null(a[["shape-col"]])) sc[[a[["shape-col"]]]] <- as.character(cd[[a[["shape-col"]]]])[match(sc$sample, rownames(cd))]
  sc$size_factor <- unname(res$size_factors[sc$sample])
  keep <- c("sample", "condition", a[["shape-col"]], "size_factor", "PC1", "PC2")
  sc <- sc[, keep[!vapply(keep, is.null, logical(1))], drop = FALSE]
  sc[order(sc$condition, sc$sample, method = "radix"), , drop = FALSE]
}
