# Full registered PBMC3k input, retaining the existing Seurat tutorial recipe.
a <- commandArgs(TRUE)
stopifnot(length(a) == 2L)
destination <- a[1]; root <- a[2]
source(file.path(root, "skills/_shared/scripts/owner_qc_fixture.R"))
owner_qc_fresh(destination, c("pbmc3k_counts.rds", "pbmc3k_unpacked"))
verified <- owner_qc_sources(root, "seurat-qc", "pbmc3k")
archive <- verified$paths$archive
members <- utils::untar(archive, list = TRUE)
if (any(grepl("^/|^[A-Za-z]:|(^|/)\\.\\.(/|$)|\\\\", members)))
  stop("OS_ANCHOR_MISMATCH: unsafe archive member", call. = FALSE)
unpack <- file.path(destination, "pbmc3k_unpacked")
dir.create(unpack)
status <- utils::untar(archive, exdir = unpack)
stopifnot(identical(as.integer(status), 0L))
data_dir <- file.path(unpack, "filtered_gene_bc_matrices", "hg19")
counts <- Seurat::Read10X(data.dir = data_dir, gene.column = 2L, cell.column = 1L,
                        unique.features = TRUE, strip.suffix = FALSE)
stopifnot(inherits(counts, "Matrix"), ncol(counts) > 0L, nrow(counts) > 0L)
path <- file.path(destination, "pbmc3k_counts.rds")
saveRDS(counts, path)
owner_qc_receipt(destination, verified, list(path), list(
  rule = "All supplied cells/features; Read10X gene symbols and unique feature names; no QC or subsampling during preparation",
  n_cells = ncol(counts), n_genes = nrow(counts), biological_samples = 1L,
  independent_condition_inference = FALSE))
