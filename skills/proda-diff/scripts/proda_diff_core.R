# Draft implementation. See PACK and acceptance_status.json; no release seal.
PD_MODULE <- "proda-diff"
PD_VERSION <- "0.1.0"
PD_PACKAGE_VERSION <- "1.26.0"

# Shared os_read_matrix rejects NA; this reader deliberately preserves dropout.
pd_read_matrix <- function(path) {
  x <- .os_read_delim(path)
  if (nrow(x) < 1L || ncol(x) < 3L) stop("OS_INVALID_INPUT: expected feature IDs and at least two samples.", call. = FALSE)
  ids <- as.character(x[[1]]); sn <- names(x)[-1]
  if (anyNA(ids) || any(!nzchar(trimws(ids))) || anyDuplicated(ids) || any(!nzchar(trimws(sn))) || anyDuplicated(sn))
    stop("OS_INVALID_INPUT: feature and sample IDs must be unique and nonempty.", call. = FALSE)
  vals <- lapply(x[-1], function(v) {
    z <- suppressWarnings(as.numeric(v))
    if (any(is.na(z) & !is.na(v)) || any(is.infinite(z))) stop("OS_INVALID_INPUT: matrix must contain finite numbers or NA.", call. = FALSE)
    z
  })
  matrix(unlist(vals, use.names = FALSE), nrow = nrow(x), dimnames = list(ids, sn))
}

pd_prepare <- function(mat, st, a) {
  if (anyDuplicated(names(st))) stop("OS_INVALID_DESIGN: duplicate sample-metadata column names.", call. = FALSE)
  cols <- c(a[["sample-col"]], a$condition, a[["bio-col"]])
  if (!all(cols %in% names(st))) stop("OS_MISSING_COLUMN: sample, condition or biological ID column absent.", call. = FALSE)
  st[cols] <- lapply(st[cols], as.character)
  if (any(vapply(st[cols], function(z) anyNA(z) || any(!nzchar(trimws(z))), logical(1))))
    stop("OS_INVALID_DESIGN: sample metadata has missing identifiers or groups.", call. = FALSE)
  if (anyDuplicated(st[[a[["sample-col"]]]]) || anyDuplicated(st[[a[["bio-col"]]]]))
    stop("OS_PSEUDOREPLICATION: initial proDA module requires one independent biological sample per column.", call. = FALSE)
  st <- os_align_samples(mat, st, a[["sample-col"]])
  if (identical(a$reference, a$target) || !setequal(unique(st[[a$condition]]), c(a$reference, a$target)))
    stop("OS_INVALID_DESIGN: exactly the declared reference and target groups are required.", call. = FALSE)
  nref <- sum(st[[a$condition]] == a$reference); ntar <- sum(st[[a$condition]] == a$target)
  if (min(nref, ntar) < 2L) stop("OS_PSEUDOREPLICATION: at least two biological replicates per group required.", call. = FALSE)
  if (a[["input-scale"]] == "log2" && a[["zero-policy"]] != "observed")
    stop("OS_INVALID_PARAMETER: zero is a valid log2 value; use zero-policy observed for log2 input.", call. = FALSE)
  if (a[["input-scale"]] == "linear") {
    if (any(mat < 0, na.rm = TRUE)) stop("OS_INVALID_INPUT: linear intensities cannot be negative.", call. = FALSE)
    if (a[["zero-policy"]] == "missing") mat[!is.na(mat) & mat == 0] <- NA_real_
    if (any(mat == 0, na.rm = TRUE)) stop("OS_INVALID_INPUT: observed linear zeros cannot be log2 transformed; resolve zero semantics upstream.", call. = FALSE)
    mat <- log2(mat)
  }
  if (any(colSums(!is.na(mat)) == 0L)) stop("OS_INVALID_INPUT: a sample has no observed protein intensities.", call. = FALSE)
  keep <- rowSums(!is.na(mat)) > 0L
  if (sum(keep) < 2L) stop("OS_INVALID_INPUT: fewer than two proteins contain observations.", call. = FALSE)
  design <- cbind(reference = as.integer(st[[a$condition]] == a$reference), target = as.integer(st[[a$condition]] == a$target))
  rownames(design) <- colnames(mat)
  # Keep all rows in the upstream likelihood/prior fit, as in the official
  # vignette. Removing all-missing rows changes the fitted moderation priors.
  list(matrix = mat, all_ids = rownames(mat), keep = keep, samples = st,
       design = design, n_target = ntar, n_reference = nref)
}

proda_diff_compute <- function(prep, a) {
  if (!requireNamespace("proDA", quietly = TRUE)) stop("OS_MISSING_PACKAGE: proDA is required in a rebuilt environment.", call. = FALSE)
  if (as.character(utils::packageVersion("proDA")) != PD_PACKAGE_VERSION)
    stop("OS_PACKAGE_VERSION: expected proDA 1.26.0; review calls and rerun acceptance for a new version.", call. = FALSE)
  set.seed(a$seed)
  mat <- prep$matrix
  if (a$normalization == "median") mat <- proDA::median_normalization(X = mat)
  # Upstream proDA converts exact zeros to missing when the entire matrix has
  # no NA, even for declared log2 data. Refuse rather than change zero semantics.
  if (!anyNA(mat) && any(mat == 0))
    stop("OS_ZERO_SEMANTICS: proDA would replace observed log2 zeros with NA in a complete matrix; this input is not supported without a reviewed upstream fix.", call. = FALSE)
  fit <- proDA::proDA(data = mat, design = prep$design, data_is_log_transformed = TRUE,
                       moderate_location = TRUE, moderate_variance = TRUE, location_prior_df = 3,
                       n_subsample = nrow(mat), max_iter = 20, epsilon = 0.001, verbose = FALSE)
  convergence <- proDA::convergence(object = fit)
  if (!is.list(convergence) || is.null(convergence$successful))
    stop("OS_API_MISMATCH: unknown proDA convergence contract.", call. = FALSE)
  tt <- as.data.frame(proDA::test_diff(fit = fit, contrast = "target - reference", alternative = "two.sided",
                                      pval_adjust_method = "BH", sort_by = NULL, n_max = Inf, verbose = FALSE))
  needed <- c("name", "pval", "adj_pval", "diff", "t_statistic", "se", "df", "avg_abundance", "n_approx", "n_obs")
  if (!all(needed %in% names(tt)) || anyDuplicated(tt$name) || !setequal(tt$name, rownames(mat)))
    stop("OS_API_MISMATCH: unexpected proDA result columns or feature identities.", call. = FALSE)
  ix <- match(prep$all_ids, tt$name)
  reason <- ifelse(!prep$keep, "all_missing", ifelse(is.na(tt$adj_pval[ix]), "not_estimable", ""))
  # All-missing proteins remain auditable in engine_full but carry no ordinary
  # effect/P value in the canonical table or downstream figures.
  ix[!prep$keep] <- NA_integer_
  ft <- as_feature_table(data.frame(feature_id = prep$all_ids, contrast = paste(a$target, "vs", a$reference),
      base_mean = tt$avg_abundance[ix], log2fc = tt$diff[ix], log2fc_se = tt$se[ix], stat = tt$t_statistic[ix],
      pvalue = tt$pval[ix], padj = tt$adj_pval[ix], method = "proDA Wald", shrinkage = "none",
      n_group1 = prep$n_target, n_group2 = prep$n_reference, filtered_reason = reason))
  list(ft = ft, full = tt, fit = fit, matrix = mat, samples = prep$samples,
       details = list(convergence = convergence, converged = isTRUE(convergence$successful), input_scale = a[["input-scale"]], zero_policy = a[["zero-policy"]], normalization = a$normalization,
           missing_handling = "probabilistic dropout; no imputation", base_mean_scale = "model-estimated mean log2 abundance",
           location_moderation = TRUE, variance_moderation = TRUE, n_all_missing = sum(!prep$keep),
           n_target = prep$n_target, n_reference = prep$n_reference))
}
