# Replays limma User's Guide 18.1.3–18.1.10 from sha256-locked F10/F11.
# adaptive_span: TRUE = locked limma 3.68.5 voom default (suite route); FALSE = the span
# (0.5) in force when the static guide was printed (limma NEWS.txt:28-39, 3.66.0 changed the
# default; docs/build/S4_ANCHOR_TRACE.md). Written out explicitly either way.
make_yoruba <- function(outdir, suite, adaptive_span = TRUE) {
  data_dir <- file.path(suite, "acceptance", "data")
  yf <- file.path(data_dir, "limma_Yoruba.RData")
  gf <- file.path(data_dir, "limma_GenderGenes.RData")
  if (!file.exists(yf) || !file.exists(gf)) return(NULL)
  stopifnot(digest::digest(file = yf, algo = "sha256") == "62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b")
  stopifnot(digest::digest(file = gf, algo = "sha256") == "ad2e78f108281864be9a9fdc2b686068f24b785158bc8782ac03d510938ea493")
  guide <- file.path(suite, "acceptance", "exemplars", "limma-camera", "L1_bioc3.23", "limma", "vignettes", "usersguide.rendered.txt")
  x <- readLines(guide, warn = FALSE)
  lines <- grep("^[0-9]+ argonne ", x, value = TRUE)
  fields <- strsplit(trimws(lines), "[[:space:]]+")
  stopifnot(length(fields) == 86L, all(lengths(fields) == 8L))
  st <- data.frame(sample = vapply(fields, `[[`, "", 5L),
                   concentration = vapply(fields, `[[`, "", 6L),
                   cellline = vapply(fields, `[[`, "", 7L),
                   gender = vapply(fields, `[[`, "", 8L))
  # The rendered table has a printed row number, center, flow cell, lane,
  # individual, concentration, cellline, gender: eight fields per line.
  stopifnot(identical(seq_len(86L), as.integer(vapply(fields, `[[`, "", 1L))))
  env <- new.env(parent = emptyenv()); load(yf, envir = env)
  y <- env$y
  stopifnot(identical(as.character(st$sample), colnames(y$counts)))
  keep <- rowSums(y$counts) > 50 & rowSums(is.na(y$genes)) == 0
  y <- y[keep, , keep.lib.sizes = FALSE]
  stopifnot(nrow(y) == 16918L)
  y <- edgeR::calcNormFactors(y)
  st$gender <- factor(st$gender, levels = c("Female", "Male"))
  st$concentration <- factor(st$concentration)
  design <- stats::model.matrix(~ gender + concentration, data = st)
  v <- limma::voom(y, design = design, plot = FALSE, adaptive.span = adaptive_span)
  cor <- limma::duplicateCorrelation(v, design = design, block = st$cellline)
  v <- limma::voom(y, design = design, plot = FALSE, block = st$cellline, correlation = cor$consensus, adaptive.span = adaptive_span)
  cor <- limma::duplicateCorrelation(v, design = design, block = st$cellline)
  ids <- as.character(v$genes$GeneID)
  stopifnot(!anyDuplicated(ids))
  rownames(v$E) <- ids; rownames(v$weights) <- ids; colnames(v$weights) <- colnames(v$E)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  ep <- file.path(outdir, "expression.csv")
  wp <- file.path(outdir, "weights.csv")
  sp <- file.path(outdir, "samples.csv")
  utils::write.csv(data.frame(feature_id = ids, v$E, check.names = FALSE), ep, row.names = FALSE)
  utils::write.csv(data.frame(feature_id = ids, v$weights, check.names = FALSE), wp, row.names = FALSE)
  utils::write.csv(st[, c("sample", "gender", "concentration", "cellline")], sp, row.names = FALSE)
  # Raw counts of the same 16,918 filtered genes (GeneID rows) for REAL limma-voom / limma-dupcor
  # upstream runs in the S4 contract-b tests (not an anchor).
  cp <- file.path(outdir, "counts.csv")
  cnt <- y$counts; rownames(cnt) <- ids
  utils::write.csv(data.frame(feature_id = ids, cnt, check.names = FALSE), cp, row.names = FALSE)
  list(expression = ep, weights = wp, samples = sp, counts = cp, correlation = cor$consensus,
       design = design, v = v, st = st, gene_ids = ids, y = y, adaptive_span = adaptive_span)
}
