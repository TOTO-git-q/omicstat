make_grun <- function(suite) {
  p <- file.path(suite, "acceptance/data/EH2687_grun-pancreas_counts.rds")
  if (!file.exists(p)) stop("OS_ACCEPTANCE_EVIDENCE_MISSING: offline Grun anchor absent.")
  stopifnot(digest::digest(file = p, algo = "sha256") == "237f99410659bb6614f2cbc2cd1fcb2a5d242230c97490c87f324a59bbac246d")
  x <- readRDS(p)
  sce <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = x))
  sce$sample <- sub("_.*", "", colnames(sce))
  sce$batch <- sce$sample
  sce
}
