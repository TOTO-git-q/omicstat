# Actual Seurat CLI on a 100% invented 8-feature x 9-cell matrix.
a <- commandArgs(FALSE); here <- dirname(normalizePath(sub("^--file=", "", a[grepl("^--file=", a)][1])))
root <- normalizePath(file.path(here, "../../.."))
out <- Sys.getenv("OMICSTAT_QC_NATIVE_TEST_OUT", file.path(tempdir(), "seurat-qc-synthetic-stage")); dir.create(out, recursive = TRUE, showWarnings = FALSE)
mat <- matrix(c(1,0,3,4,1,1,0,0, 2,0,0,0,0,0,0,0, 0,1,2,3,1,0,0,0,
                0,0,0,0,0,0,1,0, 1,1,1,1,1,1,1,1, 0,0,2,2,2,0,0,0,
                9,0,1,0,0,0,0,0, 0,0,0,0,0,0,1,0, 0,0,0,0,0,0,0,1), nrow = 8,
              dimnames = list(c("MT-FAKE1", "MT-FAKE2", paste0("FAKE", 3:8)), paste0("invented_cell", 1:9)))
saveRDS(mat, file.path(out, "synthetic_counts.rds"))
md <- data.frame(cell = colnames(mat), sample = rep(c("invented_A", "invented_B", "invented_C"), c(4,3,2)))
utils::write.csv(md, file.path(out, "synthetic_metadata.csv"), row.names = FALSE)
args <- c(file.path(root, "skills/seurat-qc/scripts/run_seurat_qc.R"),
          "--input", file.path(out, "synthetic_counts.rds"), "--input-format", "rds", "--metadata", file.path(out, "synthetic_metadata.csv"),
          "--outdir", file.path(out, "result"), "--organism", "artificial_fixture", "--feature-type", "synthetic_symbol", "--mito-pattern", "^MT-",
          "--min-cells", "1", "--create-min-features", "2", "--min-features", "0", "--max-features", "100", "--min-counts", "0", "--max-counts", "1000", "--max-mito", "50")
rc <- system2("Rscript", shQuote(args), stdout = file.path(out,"native.log"), stderr = file.path(out,"native.log"))
if (rc != 0) stop(paste(readLines(file.path(out,"native.log")), collapse="\n"))
checks <- 0L
check <- function(ok,msg) { if (!isTRUE(ok)) stop(paste("FAIL",msg)); checks <<- checks + 1L; cat("PASS",msg,"\n") }
d <- read.csv(file.path(out, "result/tables/cell_qc.csv")); f <- read.csv(file.path(out, "result/tables/filter_flow.csv"))
p <- jsonlite::read_json(file.path(out,"result/figures/qc_metrics.figure_spec.json"), simplifyVector = TRUE)
y <- readRDS(file.path(out,"result/objects/seurat.rds"))
check(identical(d$cell, colnames(mat)[c(1,3,5,6,7)]), "exact after-creation identities; four removed cells are not reintroduced")
check(identical(colnames(y), colnames(mat)[c(1,3,5,6)]), "later mitochondrial threshold removes exactly the prespecified artificial cell")
check(identical(f$input, c(4L,3L,2L)) && identical(f$after_creation, c(2L,3L,0L)) && identical(f$creation_removed,c(2L,0L,2L)) && identical(f$retained,c(2L,2L,0L)), "independent stage-by-sample arithmetic including zero retained sample")
check(p$data$data_stage == "after_creation" && sum(p$counts$stage_flow$input) == 9 && sum(p$counts$stage_flow$displayed) == 5 && sum(p$counts$stage_flow$removed_before_stage) == 4, "actual CLI serialized plot denominator is after creation")
check(sum(unlist(p$counts$cells_per_sample)) == nrow(d) && grepl("4 removed before this stage",p$caption), "caption and count metadata reconcile to QC table")
check(p$definition$metrics$percent.mt$matched_feature_count == 2 && p$definition$metrics$percent.mt$retained_feature_count == 8 && p$definition$metrics$percent.mt$organism == "artificial_fixture", "actual numerator feature count, organism and feature universe are preserved")
expected <- 100 * colSums(mat[1:2,d$cell,drop=FALSE]) / colSums(mat[,d$cell,drop=FALSE])
check(max(abs(d$percent.mt - expected)) < 1e-12 && identical(d$nCount_RNA, as.integer(colSums(mat[,d$cell,drop=FALSE]))), "native QC values equal independent raw-count arithmetic")
check(all(c("fail_features","fail_counts","fail_mito","sequential_features","sequential_counts","sequential_mito","retained") %in% names(p$counts$filter_flow)), "overlapping failures, sequential removal and retained counts remain separate")
for (metric in c("percent.mt", "nFeature_RNA")) {
 q <- jsonlite::read_json(file.path(out,paste0("result/figures/qc_scatter_",metric,".figure_spec.json")), simplifyVector = TRUE)
 check(q$data$data_stage == "after_creation" && q$data$n_cells == 5 && sum(q$counts$stage_flow$removed_before_stage) == 4, paste("scatter stage and denominator",metric))
}
check(identical(readRDS(file.path(out,"synthetic_counts.rds")), mat), "input matrix remains unchanged")
cat(checks,"native synthetic Seurat stage checks PASS; Seurat",as.character(packageVersion("Seurat")),"\n")
