# fission primary replay fixture; assay hash is locked to the acceptance layer.
FISSION_ASSAY_SHA256 <- "4bec9e6d01665301ced3de128eff4cfb1269aed9701146e794087e24f526fe30"
make_fission <- function(dir, suite) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  x <- os_acceptance_data(suite, "fission", "fission")
  if (is.null(x)) stop("OS_ACCEPTANCE_DATA_MISSING: install fission in the acceptance data layer.", call. = FALSE)
  m <- SummarizedExperiment::assay(x)
  got <- digest::digest(m, algo = "sha256")
  if (!identical(got, FISSION_ASSAY_SHA256)) stop(sprintf("OS_ANCHOR_MISMATCH: fission assay SHA256 %s differs from locked %s.", got, FISSION_ASSAY_SHA256), call. = FALSE)
  cd <- as.data.frame(SummarizedExperiment::colData(x))
  if (!all(c("strain", "minute") %in% names(cd))) stop("OS_ANCHOR_MISMATCH: fission lacks strain/minute columns.", call. = FALSE)
  p <- list(counts = file.path(dir, "counts.tsv"), samples = file.path(dir, "samples.csv"), assay_sha256 = got)
  utils::write.table(data.frame(feature_id = rownames(m), m, check.names = FALSE), p$counts, sep = "\t", row.names = FALSE, quote = FALSE)
  utils::write.csv(data.frame(sample = rownames(cd), strain = as.character(cd$strain), minute = as.character(cd$minute),
                              stringsAsFactors = FALSE), p$samples, row.names = FALSE)
  p
}
