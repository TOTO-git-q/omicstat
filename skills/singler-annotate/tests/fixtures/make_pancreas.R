# PACK C exact fixture; source files registered in lane B F22-F24.
make_pancreas <- function(suite) {
  hashes <- c(EH2687_grun_pancreas = "237f99410659bb6614f2cbc2cd1fcb2a5d242230c97490c87f324a59bbac246d",
              EH2692_muraro_pancreas = "c78a0281d1c48021c37925d8aad052a2a9baf28ead94531c52d94b61cd034f60",
              EH2693_muraro_coldata = "813dd8b393a5090d68c5aa650438faffc2d5041073bffe065c9db1e3c94719d1")
  files <- file.path(suite, "acceptance", "data", c("EH2687_grun-pancreas_counts.rds", "EH2692_muraro-pancreas_counts.rds", "EH2693_muraro-pancreas_coldata.rds"))
  if (!all(file.exists(files))) return(NULL)
  for (i in seq_along(files)) if (!identical(digest::digest(file = files[i], algo = "sha256"), unname(hashes[i]))) stop("OS_ACCEPTANCE_DATA_MISMATCH: pancreas file hash differs.", call. = FALSE)
  g <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = readRDS(files[1])))
  m <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = readRDS(files[2])), colData = readRDS(files[3]))
  # scRNAseq 2.26.0 constructors split ERCC before normalization. The
  # registered EH files are raw counts, so reproduce that native constructor
  # step instead of treating spike-ins as endogenous RNA.
  g <- SingleCellExperiment::splitAltExps(g, ifelse(grepl("ERCC-[0-9]+", sub("__.*", "", rownames(g))), "ERCC", "endogenous"), ref="endogenous")
  m <- SingleCellExperiment::splitAltExps(m, ifelse(grepl("^ERCC-[0-9]+", sub("__.*", "", rownames(m))), "ERCC", "endogenous"), ref="endogenous")
  m <- m[, !is.na(m$label)]
  g <- g[, Matrix::colSums(SummarizedExperiment::assay(g, "counts")) > 0]
  # No substitute normalization is allowed for the hard printed anchor.
  if (!requireNamespace("scrapper", quietly = TRUE)) stop("OS_MISSING_DEPENDENCY: exact PACK C normalization requires scrapper, absent from locked image.", call. = FALSE)
  m <- scrapper::normalizeRnaCounts.se(m)
  g <- scrapper::normalizeRnaCounts.se(g)
  g$cluster <- rep("anchor", ncol(g))
  list(test = g, reference = m)
}
