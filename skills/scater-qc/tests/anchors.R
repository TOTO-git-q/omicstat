# Existing guide metrics/filter path, independent of scater_qc_compute.
a <- commandArgs(TRUE)
stopifnot(length(a) == 3L)
sce <- readRDS(a[1]); run <- a[2]; output <- a[3]
stopifnot(!file.exists(output))
metrics <- scuttle::perCellQCMetrics(sce, subsets = list(Mito = grep("mt-", rownames(sce))),
  assay.type = "counts", BPPARAM = BiocParallel::SerialParam())
filters <- scuttle::perCellQCFilters(metrics, sum.field = "sum", detected.field = "detected",
  sub.fields = "subsets_Mito_percent", nmads = 3, batch = NULL)
audit <- read.csv(file.path(run, "tables/metrics.csv"), check.names = FALSE)
stopifnot(identical(as.character(audit$cell), colnames(sce)))
stopifnot(isTRUE(all.equal(audit$sum, as.numeric(metrics$sum), tolerance = 0)))
stopifnot(identical(as.logical(audit$discard), as.logical(filters$discard)))
# Compare the same CSV serialization exactly; never increase the native tolerance.
# The existing smoke test separately retains exact in-memory mitochondrial replay.
tmp <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(percent = as.numeric(metrics$subsets_Mito_percent)), tmp, row.names = FALSE)
roundtrip <- read.csv(tmp)$percent
stopifnot(isTRUE(all.equal(audit$subsets_Mito_percent, roundtrip, tolerance = 0)))
flow <- read.csv(file.path(run, "tables/flow.csv"))
stopifnot(sum(flow$input) == ncol(sce), sum(flow$retained) == sum(!filters$discard))
result <- list(input_genes = nrow(sce), input_cells = ncol(sce),
  alternative_experiments = as.list(sort(SingleCellExperiment::altExpNames(sce))),
  library_sizes_exact = TRUE, filter_decisions_exact = TRUE,
  mitochondrial_percent_csv_exact = TRUE, flow_reconciles = TRUE)
jsonlite::write_json(result, output, auto_unbox = TRUE, pretty = TRUE)
