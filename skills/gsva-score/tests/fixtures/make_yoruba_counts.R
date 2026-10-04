# Yoruba HapMap counts (sha256-locked acceptance file F10, limma User's Guide 18.1.3-18.1.5 filter) for the
# S4 contract-b test: a REAL limma-voom run whose hand-off gsva-score consumes. Not an anchor.
make_yoruba_counts <- function(outdir, suite) {
  yf <- file.path(suite, "acceptance", "data", "limma_Yoruba.RData")
  guide <- file.path(suite, "acceptance", "exemplars", "limma-camera", "L1_bioc3.23", "limma", "vignettes", "usersguide.rendered.txt")
  if (!file.exists(yf) || !file.exists(guide)) return(NULL)
  stopifnot(digest::digest(file = yf, algo = "sha256") == "62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b")
  fields <- strsplit(trimws(grep("^[0-9]+ argonne ", readLines(guide, warn = FALSE), value = TRUE)), "[[:space:]]+")
  stopifnot(length(fields) == 86L, all(lengths(fields) == 8L))
  st <- data.frame(sample = vapply(fields, `[[`, "", 5L), concentration = vapply(fields, `[[`, "", 6L),
                   cellline = vapply(fields, `[[`, "", 7L), gender = vapply(fields, `[[`, "", 8L))
  env <- new.env(parent = emptyenv()); load(yf, envir = env)
  y <- env$y
  stopifnot(identical(st$sample, colnames(y$counts)))
  keep <- rowSums(y$counts) > 50 & rowSums(is.na(y$genes)) == 0
  cnt <- y$counts[keep, , drop = FALSE]
  rownames(cnt) <- as.character(y$genes$GeneID[keep])
  stopifnot(nrow(cnt) == 16918L, !anyDuplicated(rownames(cnt)))
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  cp <- file.path(outdir, "counts.csv"); sp <- file.path(outdir, "samples.csv")
  utils::write.csv(data.frame(feature_id = rownames(cnt), cnt, check.names = FALSE), cp, row.names = FALSE)
  utils::write.csv(st, sp, row.names = FALSE)
  list(counts = cp, samples = sp)
}
