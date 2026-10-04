# GSE63310 file F4 (acceptance/data/ANCHOR_REGISTRY.md row 5), checksum pinned there.
# Registered source workflow: RNAseq123 (Law et al.), git.bioconductor.org/packages/RNAseq123
# RELEASE_3_23 @09a5145cc779e0e9772311c8420378df63241031, vignettes/limmaWorkflow.Rmd
# (source copy, LF-normalised, + rendered release text in acceptance/exemplars/limma-voom/_s4/rnaseq123/,
# MANIFEST.tsv holds URLs and sha256). Cited below as Rmd:<line> / rendered:<line>.
GSE63310_SHA256 <- "d2567b6753711e86820acbed4a4786ea1c57c59212503a8622b56982bcd53e44"
RNASEQ123_RMD_SHA256 <- "ce90daf5b8aab3b693944fd9fdbb7854c788fb1b5ec983e68f4c772192abef2a"  # LF-normalised copy
RNASEQ123_RENDERED_SHA256 <- "549f49f56596a00b6e359b283fba2e4fd2d7b4d96ef93d8c208a69c673bf3ad7"

rnaseq123_evidence <- function(suite) {
  d <- file.path(suite, "acceptance", "exemplars", "limma-voom", "_s4", "rnaseq123")
  rmd <- file.path(d, "limmaWorkflow.Rmd"); txt <- file.path(d, "limmaWorkflow.rendered.txt")
  if (digest::digest(file = rmd, algo = "sha256") != RNASEQ123_RMD_SHA256 ||
      digest::digest(file = txt, algo = "sha256") != RNASEQ123_RENDERED_SHA256)
    stop("OS_ANCHOR_HASH_MISMATCH: RNAseq123 workflow evidence")
  list(rmd = readLines(rmd, warn = FALSE), rendered = readLines(txt, warn = FALSE))
}

# The workflow's own data import (Rmd:73-75 file list, Rmd:94 readDGE, Rmd:109-116
# sample names, group and lane). Only difference: readDGE reads the .txt.gz members
# directly instead of R.utils::gunzip first (Rmd:77-78); the column content is identical.
# Returns the DGEList x exactly as at rendered:80-110 plus the engine input files:
# all 27179 genes x 9 samples (no gene subset) and the sample table (group, lane).
make_gse63310 <- function(dir, suite) {
  tarfile <- file.path(suite, "acceptance", "data", "GSE63310_RAW.tar")
  if (!file.exists(tarfile)) return(NULL)
  if (digest::digest(file = tarfile, algo = "sha256") != GSE63310_SHA256) stop("OS_ANCHOR_HASH_MISMATCH: GSE63310 F4")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  files <- c("GSM1545535_10_6_5_11.txt", "GSM1545536_9_6_5_11.txt",           # Rmd:83-87
             "GSM1545538_purep53.txt", "GSM1545539_JMS8-2.txt",
             "GSM1545540_JMS8-3.txt", "GSM1545541_JMS8-4.txt",
             "GSM1545542_JMS8-5.txt", "GSM1545544_JMS9-P7c.txt",
             "GSM1545545_JMS9-P8c.txt")
  utils::untar(tarfile, files = paste0(files, ".gz"), exdir = dir)
  x <- edgeR::readDGE(file.path(dir, paste0(files, ".gz")), columns = c(1, 3))  # Rmd:94
  colnames(x) <- sub("[.]txt$", "", basename(colnames(x)))
  samplenames <- substring(colnames(x), 12, nchar(colnames(x)))                 # Rmd:109
  colnames(x) <- samplenames                                                    # Rmd:111
  group <- as.factor(c("LP", "ML", "Basal", "Basal", "ML", "LP",                # Rmd:112-113
                       "Basal", "ML", "LP"))
  x$samples$group <- group                                                      # Rmd:114
  lane <- as.factor(rep(c("L004", "L006", "L008"), c(3, 4, 2)))                 # Rmd:115
  x$samples$lane <- lane                                                        # Rmd:116
  counts <- x$counts
  storage.mode(counts) <- "integer"
  utils::write.csv(data.frame(feature_id = rownames(counts), counts, check.names = FALSE),
                   file.path(dir, "counts.csv"), row.names = FALSE)
  utils::write.csv(data.frame(sample = samplenames, group = as.character(group), lane = as.character(lane)),
                   file.path(dir, "samples.csv"), row.names = FALSE)
  list(counts = file.path(dir, "counts.csv"), samples = file.path(dir, "samples.csv"),
       x = x, group = group, lane = lane, matrix = counts, source_files = files)
}
