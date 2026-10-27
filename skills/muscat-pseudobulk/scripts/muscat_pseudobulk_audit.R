# Report-only source audit plus guards against explicitly identifiable reuse.
# No aggregation, model, correction or new P value is computed here.
muscat_source_cells <- function(sce, a) {
  cell_ids <- colnames(sce)
  .os_sem_ids(cell_ids, "muscat original cell IDs")
  out <- data.frame(cell_id = cell_ids,
    sample = os_backend_column(sce, a[["sample-col"]]),
    subtype = os_backend_column(sce, a[["cluster-col"]]),
    condition = os_backend_column(sce, a[["condition-col"]]), stringsAsFactors = FALSE)
  for (k in names(out)) out[[k]] <- .os_replicate_strings(out[[k]], k)
  donor_col <- a[["donor-col"]]
  if (!is.null(donor_col)) out$donor <- .os_replicate_strings(os_backend_column(sce, donor_col), "donor")
  samples <- unique(out[, c("sample", "condition", if (!is.null(donor_col)) "donor"), drop = FALSE])
  if (anyDuplicated(samples$sample))
    stop("OS_PSEUDOREPLICATION: one sample label maps to multiple conditions or donors; mixed samples cannot be independent replicates.", call. = FALSE)
  if (!is.null(donor_col) && anyDuplicated(samples[, c("donor", "condition"), drop = FALSE]))
    stop("OS_PSEUDOREPLICATION: one donor-condition is split across sample labels; aggregate technical samples explicitly upstream before inference.", call. = FALSE)
  out
}

muscat_check_donor_design <- function(source_cells, pb, design) {
  if (!"donor" %in% names(source_cells)) return(invisible(TRUE))
  map <- unique(source_cells[, c("sample", "condition", "donor"), drop = FALSE])
  donor <- map$donor[match(colnames(pb), map$sample)]
  if (anyNA(donor)) stop("OS_INVALID_RESULT: pseudobulk sample has no declared donor mapping.", call. = FALSE)
  if (!anyDuplicated(donor)) return(invisible(TRUE))
  if (is.null(design))
    stop("OS_PSEUDOREPLICATION: repeated donors across conditions require an explicit native donor-adjusted design; pairing is never inferred by the display.", call. = FALSE)
  if (inherits(design, "formula")) design <- stats::model.matrix(design, as.data.frame(SummarizedExperiment::colData(pb)))
  if (!is.matrix(design) || !is.numeric(design) || is.null(rownames(design)) ||
      !identical(rownames(design), colnames(pb)) || any(!is.finite(design)))
    stop("OS_INVALID_DESIGN: donor-adjusted design needs exact pseudobulk sample row IDs and finite values.", call. = FALSE)
  donor_design <- stats::model.matrix(~ 0 + factor(donor))
  if (qr(cbind(design, donor_design))$rank != qr(design)$rank)
    stop("OS_PSEUDOREPLICATION: explicit design does not contain the declared donor effects.", call. = FALSE)
  invisible(TRUE)
}

muscat_pseudobulk_eligibility_table <- function(source_cells, prepared_cell_ids, pb, res,
    reference, target, min_cells) {
  .os_sem_rows(source_cells, "cell_id")
  .os_sem_ids(prepared_cell_ids, "prepared cell IDs")
  if (!all(prepared_cell_ids %in% source_cells$cell_id))
    stop("OS_INVALID_RESULT: preparation introduced unknown cell IDs.", call. = FALSE)
  sample_map <- unique(source_cells[, c("sample", "condition", if ("donor" %in% names(source_cells)) "donor"), drop = FALSE])
  if (anyDuplicated(sample_map$sample) || !all(sample_map$condition %in% c(reference, target)))
    stop("OS_INVALID_RESULT: source sample/condition/donor mapping is ambiguous.", call. = FALSE)
  samples <- sample_map$sample; subtypes <- sort(unique(source_cells$subtype), method = "radix")
  prepared <- source_cells[source_cells$cell_id %in% prepared_cell_ids, , drop = FALSE]
  source_n <- table(factor(source_cells$sample, levels = samples), factor(source_cells$subtype, levels = subtypes))
  prepared_n <- table(factor(prepared$sample, levels = samples), factor(prepared$subtype, levels = subtypes))
  grid <- expand.grid(sample = samples, subtype = subtypes, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid$condition <- sample_map$condition[match(grid$sample, samples)]
  if ("donor" %in% names(sample_map)) grid$donor <- sample_map$donor[match(grid$sample, samples)]
  ix <- cbind(match(grid$sample, samples), match(grid$subtype, subtypes))
  grid$input_n_cells <- as.numeric(source_n[ix]); grid$n_cells <- as.numeric(prepared_n[ix])
  grid$library_size <- grid$fitted_feature_library_size <- NA_real_
  grid$state <- "not_fitted"; grid$reason <- "native_backend_not_fitted_reason_unavailable"
  grid$reason[grid$n_cells < min_cells] <- "below_actual_min_cells"
  grid$state[grid$n_cells < min_cells] <- "below_min_cells"
  grid$reason[grid$n_cells == 0 & grid$input_n_cells > 0] <- "all_source_cells_removed_during_preparation"
  grid$state[grid$n_cells == 0 & grid$input_n_cells > 0] <- "prep_excluded"
  grid$reason[grid$input_n_cells == 0] <- "no_cells_in_original_selected_source"
  grid$state[grid$input_n_cells == 0] <- "zero_cell"
  pb_samples <- colnames(pb); .os_sem_ids(pb_samples, "native pseudobulk samples")
  if (!all(pb_samples %in% samples)) stop("OS_INVALID_RESULT: unknown sample in pseudobulk aggregate.", call. = FALSE)
  for (cl in SummarizedExperiment::assayNames(pb)) {
    if (!cl %in% subtypes) stop("OS_INVALID_RESULT: unknown subtype in pseudobulk aggregate.", call. = FALSE)
    mat <- SummarizedExperiment::assay(pb, cl)
    if (any(!is.finite(mat)) || any(mat < 0)) stop("OS_INVALID_RESULT: pseudobulk library values are not nonnegative finite counts.", call. = FALSE)
    rows <- which(grid$subtype == cl & grid$sample %in% pb_samples)
    lib <- as.numeric(Matrix::colSums(mat)); names(lib) <- colnames(mat)
    grid$library_size[rows] <- lib[grid$sample[rows]]
    zero <- rows[grid$n_cells[rows] >= min_cells & grid$library_size[rows] == 0 & grid$n_cells[rows] > 0]
    grid$state[zero] <- "zero_library"; grid$reason[zero] <- "zero_native_pseudobulk_library"
    native_data <- res$data[[cl]]
    if (is.null(native_data)) next
    fitted_samples <- colnames(native_data); fitted_features <- rownames(native_data)
    if (is.null(fitted_samples) && is.list(native_data) && !is.null(native_data$counts)) {
      fitted_samples <- colnames(native_data$counts); fitted_features <- rownames(native_data$counts)
    }
    .os_sem_ids(fitted_samples, "actual backend fitted sample IDs")
    if (!all(fitted_samples %in% pb_samples) || is.null(fitted_features) || !all(fitted_features %in% rownames(mat)))
      stop("OS_INVALID_RESULT: fitted-data source IDs cannot be joined to the native aggregate.", call. = FALSE)
    post_lib <- as.numeric(Matrix::colSums(mat[fitted_features, , drop = FALSE])); names(post_lib) <- colnames(mat)
    grid$fitted_feature_library_size[rows] <- post_lib[grid$sample[rows]]
    zero <- rows[grid$n_cells[rows] >= min_cells & grid$fitted_feature_library_size[rows] == 0 & grid$n_cells[rows] > 0]
    grid$state[zero] <- "zero_library"; grid$reason[zero] <- "zero_library_in_actual_fitted_feature_universe"
    fit <- rows[grid$sample[rows] %in% fitted_samples]
    if (any(grid$n_cells[fit] < min_cells) || any(grid$fitted_feature_library_size[fit] <= 0))
      stop("OS_INVALID_RESULT: fitted sample violates actual cell/library eligibility.", call. = FALSE)
    grid$state[fit] <- "fitted"; grid$reason[fit] <- "present_in_native_res_data"
    for (g in c(reference, target)) {
      z <- grid[fit, , drop = FALSE]; z <- z[z$condition == g, , drop = FALSE]
      n <- if ("donor" %in% names(z)) length(unique(z$donor)) else length(unique(z$sample))
      if (n < 2L) stop(sprintf("OS_PSEUDOREPLICATION: cluster %s retains fewer than two declared %s in condition %s; no inferential output is released.",
        cl, if ("donor" %in% names(z)) "donors" else "sample labels", g), call. = FALSE)
    }
  }
  if (!all(names(res$data) %in% subtypes)) stop("OS_INVALID_RESULT: fitted data contain an unknown subtype.", call. = FALSE)
  grid[order(grid$subtype, match(grid$condition, c(reference, target)), grid$sample, method = "radix"), , drop = FALSE]
}
