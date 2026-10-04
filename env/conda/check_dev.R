# check_dev.R -- self-check of the omicstat DEV tier (env/conda). ASCII only.
# Rscript env/conda/check_dev.R   -> exit 1 when a required package is missing.
# Prints every package with its version, the source dates of the annotation
# data, and the reference-data caches (msigdbr, celldex/gypsum). Caches and the
# items listed as not installed never count as a failure.
required <- c(
  # figure layer + engine contract
  "ggplot2", "ggrepel", "patchwork", "ragg", "svglite", "ggrastr", "jsonlite", "digest", "MASS", "gt", "systemfonts",
  # M1 bulk
  "DESeq2", "apeglm", "edgeR", "limma", "sva", "airway", "pasilla",
  # M2 enrichment
  "clusterProfiler", "enrichplot", "DOSE", "GO.db", "HDO.db", "fgsea", "GSVA", "GSEABase", "msigdbr",
  "org.Hs.eg.db", "org.Mm.eg.db",
  # M3a Seurat line
  "Seurat", "SeuratObject", "harmony", "sctransform", "leidenbase",
  # M3a Bioconductor line
  "SingleCellExperiment", "scater", "scuttle", "scran", "bluster", "batchelor", "AUCell",
  # M3b back end
  "SingleR", "celldex", "muscat", "speckle", "CellChat", "monocle3", "slingshot", "tradeSeq",
  # M4
  "WGCNA", "maftools", "immunedeconv")
ver <- vapply(required, function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_), "")
cat(sprintf("%-22s %s\n", names(ver), ifelse(is.na(ver), "MISSING", ver)), sep = "")
cat(sprintf("\nR %s | Bioconductor %s\n", getRversion(),
            tryCatch(as.character(BiocManager::version()), error = function(e) "unknown")))
# annotation data: official Bioconductor 3.22 packages (the 2016 GO.db
# stand-in of the blocked-network build is retired and must not come back)
standin <- !is.na(ver[["GO.db"]]) && package_version(ver[["GO.db"]]) < "3.22.0"
if (standin) { cat("\nGO.db", ver[["GO.db"]], "is the retired stand-in: rerun env/conda/setup_dev.sh step 5\n"); ver[["GO.db"]] <- NA }
src <- function(pkg, fun, keys) tryCatch({
  m <- getExportedValue(pkg, fun)(); paste(m$value[match(keys, m$name)], collapse = " / ")
}, error = function(e) "unavailable")
cat("\nAnnotation source dates:\n",
    "  GO.db        GO ", src("GO.db", "GO_dbInfo", "GOSOURCEDATE"), "\n",
    "  org.Hs.eg.db NCBI Gene / Ensembl / GO ", src("org.Hs.eg.db", "org.Hs.eg_dbInfo", c("EGSOURCEDATE", "ENSOURCEDATE", "GOSOURCEDATE")), "\n",
    "  org.Mm.eg.db NCBI Gene / GO ", src("org.Mm.eg.db", "org.Mm.eg_dbInfo", c("EGSOURCEDATE", "GOSOURCEDATE")), "\n", sep = "")
# reference-data caches (per user; filled by setup_dev.sh step 6; see env/refdata_registry.json)
msig <- file.path(tools::R_user_dir("msigdbr", "cache"), "msigdb.2026.1.summary.rds")
gyp <- file.path(tryCatch(gypsum::cacheDirectory(), error = function(e) ""), "bucket", "celldex",
                 c("hpca", "blueprint_encode", "monaco_immune", "mouse_rnaseq", "immgen"), "2024-02-26", "OBJECT")
cat("\nReference-data caches (not required; tests that need them SKIP when absent):\n",
    "  msigdbr MSigDB 2026.1   ", if (file.exists(msig)) "cached" else "NOT CACHED", "\n",
    "  celldex (gypsum 2024-02-26) ", sum(file.exists(gyp)), "/", length(gyp), " references cached\n", sep = "")
cat("\nNot installed in this tier (available as bioconda Bioconductor 3.22 builds; their data\n",
    "  come from ExperimentHub on first use): scRNAseq, muscData, TENxPBMCData\n", sep = "")
if (anyNA(ver)) { cat("\nMISSING:", names(ver)[is.na(ver)], "\n"); quit(status = 1) }
cat("\nDEV TIER OK\n")
