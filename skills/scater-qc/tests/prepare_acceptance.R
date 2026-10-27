# Reuse the registered offline accessor reconstruction, without changing cells.
a <- commandArgs(TRUE)
stopifnot(length(a) == 2L)
destination <- a[1]; root <- a[2]
source(file.path(root, "skills/_shared/scripts/owner_qc_fixture.R"))
owner_qc_fresh(destination, c("zeisel.rds", "mt.txt"))
verified <- owner_qc_sources(root, "scater-qc", "zeisel")
source(file.path(root, "skills/scater-qc/tests/fixtures/make_zeisel.R"))
sce <- make_zeisel(root)
stopifnot(!is.null(sce), ncol(sce) > 0L, nrow(sce) > 0L)
mt <- grep("mt-", rownames(sce), value = TRUE)
stopifnot(length(mt) > 0L, !anyDuplicated(mt))
input <- file.path(destination, "zeisel.rds"); genes <- file.path(destination, "mt.txt")
saveRDS(sce, input); writeLines(mt, genes)
owner_qc_receipt(destination, verified, list(input, genes), list(
  rule = "Unchanged make_zeisel offline accessor: mitochondrial feature type endogenous; controls split into altExps; no QC or subsampling during preparation",
  n_cells = ncol(sce), n_genes = nrow(sce), alternative_experiments = as.list(SingleCellExperiment::altExpNames(sce)),
  independent_condition_inference = FALSE))
