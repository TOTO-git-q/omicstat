# GSVAdata 1.48.1 package vignette fixture in the sha256-locked acceptance layer.
make_gbm <- function(outdir, suite) {
  x <- os_acceptance_data(suite, "GSVAdata", "gbm_VerhaakEtAl")
  if (is.null(x)) return(NULL)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  m <- Biobase::exprs(x)
  st <- Biobase::pData(x)
  ep <- file.path(outdir, "expression.csv")
  sp <- file.path(outdir, "samples.csv")
  utils::write.csv(data.frame(feature_id = rownames(m), m, check.names = FALSE), ep, row.names = FALSE)
  utils::write.csv(data.frame(sample = rownames(st), subtype = st$subtype), sp, row.names = FALSE)
  list(expression = ep, samples = sp)
}
