# make_bladderbatch.R -- anchor fixture of sva-batch (PACK section C). ASCII only.
# bladderbatch comes from the acceptance data layer (S1 M1-2; bladderbatch 1.50.0,
# Bioconductor 3.23, installed tarball); its own sha256 is verified inside
# os_acceptance_data()/os_acceptance_entry() against acceptance_lib_lock.csv before
# any R object is returned, so no separate raw-file hash check is needed here
# (unlike make_pasilla.R, which reads loose extdata text files directly).
# data(bladderdata) -> object bladderEset (data() name and object name differ,
# module_kit.R os_acceptance_data() falls back to the single bound object).
# Writes <dir>/exprs.tsv (feature_id + one column per sample) and
# <dir>/samples.csv (sample, batch, cancer, outcome); returns the two paths,
# or NULL if bladderbatch is not in the acceptance layer (caller must SKIP).
make_bladderbatch <- function(dir, suite) {
  bladderEset <- os_acceptance_data(suite, "bladderbatch", "bladderdata")
  if (is.null(bladderEset)) return(NULL)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  pheno <- Biobase::pData(bladderEset)
  edata <- Biobase::exprs(bladderEset)
  exprs_df <- data.frame(feature_id = rownames(edata), edata, check.names = FALSE)
  samples <- data.frame(sample = rownames(pheno), batch = as.character(pheno$batch),
                        cancer = as.character(pheno$cancer), outcome = as.character(pheno$outcome),
                        stringsAsFactors = FALSE)
  p <- list(exprs = file.path(dir, "exprs.tsv"), samples = file.path(dir, "samples.csv"))
  utils::write.table(exprs_df, p$exprs, sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.csv(samples, p$samples, row.names = FALSE)
  p
}
