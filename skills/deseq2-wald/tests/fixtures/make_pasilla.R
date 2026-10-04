# make_pasilla.R -- anchor fixture of deseq2-wald (PACK section C). ASCII only.
# Rebuilds the DESeq2 vignette's pasilla input exactly as the vignette does
# ("Count matrix input"): counts from pasilla_gene_counts.tsv, sample
# annotation from pasilla_sample_annotation.csv, the "fb" suffix removed from
# the sample names, columns ordered like the annotation. Writes
# <dir>/counts.tsv and <dir>/samples.csv; returns the two paths.
# pasilla comes from the acceptance data layer (S1 M1-2; pasilla 1.40.0,
# Bioconductor 3.23, unpacked tarball -- it needs DEXSeq to install); the two
# input files are hash-checked against PASILLA_SHA256 before use.
PASILLA_SHA256 <- c(counts = "ea0dafbfcc600559644cfe7dd5cc8de809d631eb64ba3089aaa25c2fa0954dad",
                    anno = "1844f871ca5d750f41685c73b87bd7dda291ec0d52304c1afb46a17ae88db745")
make_pasilla <- function(dir, suite) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  pas_cts <- os_acceptance_file(suite, "pasilla", "extdata", "pasilla_gene_counts.tsv")
  pas_anno <- os_acceptance_file(suite, "pasilla", "extdata", "pasilla_sample_annotation.csv")
  if (!nzchar(pas_cts) || !nzchar(pas_anno)) stop("pasilla is not in the acceptance data layer (run acceptance/data/install_acceptance_lib.R)")
  got <- c(counts = digest::digest(file = pas_cts, algo = "sha256"), anno = digest::digest(file = pas_anno, algo = "sha256"))
  if (!identical(got, PASILLA_SHA256)) stop(sprintf("pasilla input files changed: sha256 %s", paste(got, collapse = " / ")))
  cts <- as.matrix(utils::read.csv(pas_cts, sep = "\t", row.names = "gene_id"))
  coldata <- utils::read.csv(pas_anno, row.names = 1)
  coldata <- coldata[, c("condition", "type")]
  rownames(coldata) <- sub("fb", "", rownames(coldata))
  cts <- cts[, rownames(coldata)]
  counts <- data.frame(feature_id = rownames(cts), cts, check.names = FALSE)
  samples <- data.frame(sample = rownames(coldata), condition = coldata$condition, type = gsub("-", "_", coldata$type))
  p <- list(counts = file.path(dir, "counts.tsv"), samples = file.path(dir, "samples.csv"))
  utils::write.table(counts, p$counts, sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.csv(samples, p$samples, row.names = FALSE)
  p
}
