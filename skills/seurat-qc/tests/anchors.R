# Retained printed tutorial values plus direct Seurat reference, not engine replay.
a <- commandArgs(TRUE)
stopifnot(length(a) == 3L)
counts <- readRDS(a[1]); run <- a[2]; output <- a[3]
stopifnot(!file.exists(output))
audit <- read.csv(file.path(run, "tables/cell_qc.csv"), check.names = FALSE)
flow <- read.csv(file.path(run, "tables/filter_flow.csv"))
actual <- readRDS(file.path(run, "objects/seurat.rds"))
reference <- SeuratObject::CreateSeuratObject(counts = counts, assay = "RNA", project = "SeuratProject",
  min.cells = 3L, min.features = 200L, names.field = 1L, names.delim = "_", meta.data = NULL)
reference$percent.mt <- Seurat::PercentageFeatureSet(object = reference, pattern = "^MT-",
  features = NULL, col.name = NULL, assay = "RNA")
created_genes <- nrow(reference)
md <- reference[[]]
keep <- md$nFeature_RNA > 200 & md$nFeature_RNA < 2500 & md$nCount_RNA >= 0 &
        md$nCount_RNA < 1000000000 & md$percent.mt < 5
stopifnot(identical(as.character(audit$cell), colnames(reference)))
stopifnot(identical(as.logical(audit$pass), unname(keep)))
stopifnot(identical(colnames(actual), colnames(reference)[keep]), identical(rownames(actual), rownames(reference)))
stopifnot(sum(flow$retained) == ncol(actual), sum(flow$after_creation) == nrow(audit), sum(flow$input) == ncol(counts))
result <- list(input_cells = nrow(audit), created_genes = created_genes,
  first_cell_counts = audit$nCount_RNA[1], first_cell_features = audit$nFeature_RNA[1],
  first_cell_mito_percent = audit$percent.mt[1], strict_filter_cells_exact = TRUE,
  retained_feature_ids_exact = TRUE, flow_reconciles = TRUE)
jsonlite::write_json(result, output, auto_unbox = TRUE, pretty = TRUE, digits = 17)
