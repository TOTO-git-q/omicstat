# make_zfgenes.R -- anchor fixture of sva-batch (PACK section C, svaseq). ASCII only.
# zebrafishRNASeq comes from the acceptance data layer (zebrafishRNASeq 1.32.0,
# Bioconductor 3.23, installed tarball, sha256-verified inside
# os_acceptance_data()/os_acceptance_entry()). Filtering follows the sva
# vignette sec 13 exactly ("First we set up the data by filtering low count
# genes..."): keep rows with more than 5 reads in at least 2 samples; group is
# the vignette's own rep(c("Ctl","Trt"), each = 3). Writes <dir>/counts.tsv and
# <dir>/samples.csv; returns the two paths, or NULL if the package is absent
# (caller must SKIP).
make_zfgenes <- function(dir, suite) {
  zfGenes <- os_acceptance_data(suite, "zebrafishRNASeq", "zfGenes")
  if (is.null(zfGenes)) return(NULL)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  keep <- apply(zfGenes, 1, function(x) length(x[x > 5]) >= 2)
  filtered <- as.matrix(zfGenes[keep, , drop = FALSE])
  counts_df <- data.frame(feature_id = rownames(filtered), filtered, check.names = FALSE)
  samples <- data.frame(sample = colnames(filtered), group = rep(c("Ctl", "Trt"), each = 3), stringsAsFactors = FALSE)
  p <- list(counts = file.path(dir, "counts.tsv"), samples = file.path(dir, "samples.csv"))
  utils::write.table(counts_df, p$counts, sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.csv(samples, p$samples, row.names = FALSE)
  p
}
