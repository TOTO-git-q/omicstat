# requires: scran scuttle scater bluster SingleCellExperiment BiocParallel jsonlite digest ggplot2
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this)); suite <- dirname(dirname(.module))
source(file.path(suite, "skills/_shared/scripts/module_kit.R"))
source(file.path(.module, "tests/fixtures/make_grun.R"))
work <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "scran-cluster-smoke"); dir.create(work, recursive = TRUE, showWarnings = FALSE)
check <- function(ok, label) { stopifnot(isTRUE(ok)); cat("PASS", label, "\n") }
sce <- make_grun(suite)
check(identical(dim(sce), c(20148L, 1728L)), "PACK C Grun shape 20148 x 1728")
# Real QC producer, permissive explicit choices on a deterministic 400-cell subset.
sce <- sce[, seq_len(400)]
path <- file.path(work, "input.rds"); saveRDS(sce, path)
mt <- file.path(work, "mito.txt"); writeLines(head(rownames(sce), 1), mt)
run <- function(module, argv, label) {
  entry <- file.path(suite, "skills", module, "scripts", paste0("run_", gsub("-", "_", module), ".R"))
  log <- file.path(work, paste0(label, ".log"))
  st <- system2("Rscript", c(shQuote(entry), shQuote(argv)), stdout = log, stderr = log)
  if (st != 0) cat(readLines(log), sep = "\n")
  check(st == 0, label)
}
qc <- file.path(work, "qc")
run("scater-qc", c("--input", path, "--mt-genes", mt, "--qc-mode", "fixed", "--min-counts", "1", "--min-features", "1", "--max-mito", "100", "--species", "human", "--id-type", "symbol", "--outdir", qc), "upstream_qc")
out <- file.path(work, "anchor")
run("scran-cluster", c("--from-run", qc, "--n-hvg", "1000", "--n-pcs", "15", "--graph-k", "10", "--umap-neighbors", "15", "--sample-col", "sample", "--batch-col", "batch", "--outdir", out), "anchor_cli_from_run")
x <- readRDS(file.path(out, "objects/sce.rds")); tab <- read.csv(file.path(out, "tables/cells.csv"))
check(nrow(tab) == sum(Matrix::colSums(SummarizedExperiment::assay(sce, "counts")) >= 1) && ncol(SingleCellExperiment::reducedDim(x, "PCA")) == 15 && all(is.finite(SingleCellExperiment::sizeFactors(x))), "native output dimensions and size factors")
check(length(unique(tab$cluster)) > 1 && all(is.finite(as.matrix(tab[, c("x", "y")]))), "clusters and UMAP finite")
write.csv(data.frame(anchor = c("anchor_genes", "anchor_cells", "smoke_cells", "hvg", "pcs", "clusters"), value = c(20148, 1728, ncol(x), nrow(read.csv(file.path(out, "tables/hvgs.csv"))), 15, length(unique(tab$cluster)))), file.path(work, "anchor_values.csv"), row.names = FALSE)
paths <- c("tables/cells.csv", "tables/variance.csv", "tables/hvgs.csv", "tables/pca_variance.csv")
if (Sys.getenv("OMICSTAT_WRITE_GOLDEN") == "1") os_golden_write(.module, out, paths)
check(os_golden_check(.module, out)$status == "PASS", "golden")
check(!file.exists("Rplots.pdf"), "no Rplots.pdf")

# Replay the full official printed size-factor path, independently of the golden subset.
check(system2("Rscript", shQuote(file.path(.module,"tests","run_printed_anchor.R"))) == 0L, "official size-factor median 0.753183")
