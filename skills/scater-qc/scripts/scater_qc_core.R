XQ_MODULE <- "scater-qc"
XQ_MODULE_VERSION <- "1.0.0"
scater_qc_compute <- function(sce, a) {
  mt <- readLines(a[["mt-genes"]], warn = FALSE)
  if (!length(mt) || anyDuplicated(mt) || any(!mt %in% rownames(sce))) stop("OS_INVALID_INPUT: mitochondrial gene file must contain unique matching feature IDs.", call. = FALSE)
  batch <- if (is.null(a[["batch-col"]])) NULL else os_bioc_column(sce, a[["batch-col"]])
  metrics <- os_bioc_call(scuttle::perCellQCMetrics, a[["metrics-args"]], x = sce, subsets = list(Mito = mt),
    BPPARAM = BiocParallel::SerialParam(), assay.type = "counts")
  d <- as.data.frame(metrics)
  bounds <- list()
  if (a[["qc-mode"]] == "mad") {
    filt <- os_bioc_call(scuttle::perCellQCFilters, a[["filter-args"]], x = metrics, sum.field = "sum", detected.field = "detected",
      sub.fields = "subsets_Mito_percent", nmads = a$nmads, batch = batch)
    flags <- as.data.frame(filt)
    for (k in setdiff(names(filt), "discard")) {
      th <- attr(filt[[k]], "thresholds")
      if (!is.null(th) && is.null(dim(th))) th <- matrix(th, nrow = 2, dimnames = list(c("lower", "higher"), "all"))
      if (!is.null(th)) bounds[[k]] <- data.frame(metric = k, batch = colnames(th) %||% "all", lower = th[1, ], higher = th[2, ], row.names = NULL)
    }
  } else {
    flags <- data.frame(low_lib_size = d$sum < a[["min-counts"]], low_n_features = d$detected < a[["min-features"]],
                        high_subsets_Mito_percent = d$subsets_Mito_percent > a[["max-mito"]])
    flags$discard <- Reduce(`|`, flags)
    bounds <- list(data.frame(metric = c("low_lib_size", "low_n_features", "high_subsets_Mito_percent"),
      batch = "all", lower = c(a[["min-counts"]], a[["min-features"]], -Inf), higher = c(Inf, Inf, a[["max-mito"]])))
  }
  d$cell <- colnames(sce); d$batch <- if (is.null(batch)) "all" else as.character(batch)
  d <- cbind(d, flags); d$status <- ifelse(d$discard, "discarded", "retained")
  d$reason <- apply(flags[, setdiff(names(flags), "discard"), drop = FALSE], 1, function(x) paste(names(x)[x], collapse = ";"))
  if (!any(!d$discard)) stop("OS_QC_BLOCKER: QC removed all cells; revise explicit thresholds.", call. = FALSE)
  flow <- do.call(rbind, lapply(split(d, d$batch), function(z) data.frame(batch = z$batch[1], input = nrow(z), retained = sum(!z$discard), discarded = sum(z$discard))))
  list(sce = sce[, !d$discard], metrics = d, thresholds = do.call(rbind, bounds), flow = flow,
       state = list(qc_complete = TRUE, normalized = FALSE, species = a$species, id_type = a[["id-type"]],
                    qc_mode = a[["qc-mode"]], mitochondrial_ids_sha256 = digest::digest(file = a[["mt-genes"]], algo = "sha256")))
}
