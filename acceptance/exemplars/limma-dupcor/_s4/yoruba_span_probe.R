`%||%` <- function(a, b) if (is.null(a)) b else a
suite <- normalizePath(".")
source("skills/limma-dupcor/tests/fixtures/replay_yoruba.R")
f <- file.path(suite, "acceptance", "data", "limma_Yoruba.RData")
env <- new.env(); load(f, envir = env); print(ls(env)); y0 <- env$y
guide <- readLines("acceptance/exemplars/limma-dupcor/L1_bioc3.23/limma/vignettes/usersguide.rendered.txt", warn = FALSE)
rows <- grep("^[0-9]+ argonne ", guide, value = TRUE); tok <- strsplit(trimws(rows), " +")
targets <- data.frame(individual = vapply(tok, `[`, "", 5), concentration = factor(vapply(tok, `[`, "", 6)),
                      cellline = vapply(tok, `[`, "", 7), gender = vapply(tok, `[`, "", 8))
y <- y0[rowSums(y0$counts) > 50 & rowSums(is.na(y0$genes)) == 0, , keep.lib.sizes = FALSE]
cat("dim", dim(y), "\n")
y <- edgeR::calcNormFactors(y)
design <- stats::model.matrix(~ gender + concentration, data = targets)
load("acceptance/data/limma_GenderGenes.RData")
for (ad in c(TRUE, FALSE)) {
  v1 <- limma::voom(y, design, adaptive.span = ad)
  c1 <- limma::duplicateCorrelation(v1, design, block = targets$cellline)
  v <- limma::voom(y, design, block = targets$cellline, correlation = c1$consensus, adaptive.span = ad)
  c2 <- limma::duplicateCorrelation(v, design, block = targets$cellline)
  fit <- limma::eBayes(limma::lmFit(v, design, block = targets$cellline, correlation = c2$consensus))
  dt <- summary(limma::decideTests(fit))
  tt <- limma::topTable(fit, coef = "genderMale", n = Inf, sort = "p", p = 0.05)
  idx <- list(Y = v$genes$GeneID %in% msYgenes, X = v$genes$GeneID %in% XiEgenes)
  cam <- limma::camera(v, idx, design, 2)
  cat(sprintf("adaptive.span=%s span=%s: cor1=%.7f cor2=%.7f\n", ad, format(v$span %||% NA), c1$consensus, c2$consensus))
  print(dt[, "genderMale"]); print(head(tt[, c("Symbol", "logFC", "t", "P.Value")], 3)); print(cam)
}
cat("limma", as.character(packageVersion("limma")), "edgeR", as.character(packageVersion("edgeR")), "\n")
