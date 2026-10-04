# Tutorial part 1 exact data preparation; mirrored archive hash checked.
make_female_liver <- function(suite, dir) {
  z <- file.path(suite, "acceptance", "data", "FemaleLiver-Data.zip")
  if (!file.exists(z)) return(NULL)
  stopifnot(digest::digest(file = z, algo = "sha256") == "bd4c9d182e7a47bba1bf2a6eb94f4c47c30eab64e3f002520b3a8aaf5cf57d17")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE); utils::unzip(z, exdir = dir)
  fem <- utils::read.csv(file.path(dir, "LiverFemale3600.csv"))
  stopifnot(identical(dim(fem), c(3600L, 143L)))
  x <- as.data.frame(t(fem[, -c(1:8)])); names(x) <- fem$substanceBXH; rownames(x) <- names(fem)[-c(1:8)]
  g <- WGCNA::goodSamplesGenes(x, verbose = 0); stopifnot(g$allOK)
  tree <- stats::hclust(stats::dist(x), method = "average")
  cl <- WGCNA::cutreeStatic(tree, cutHeight = 15, minSize = 10)
  x <- x[cl == 1, ]; stopifnot(nrow(x) == 134)
  tr <- utils::read.csv(file.path(dir, "ClinicalTraits.csv")); stopifnot(identical(dim(tr), c(361L, 38L)))
  all <- tr[, -c(31, 16)]; all <- all[, c(2, 11:36)]
  tt <- all[match(rownames(x), all$Mice), -1]; rownames(tt) <- rownames(x)
  mat <- t(as.matrix(x))
  utils::write.csv(data.frame(feature_id = rownames(mat), mat, check.names = FALSE), file.path(dir, "expression.csv"), row.names = FALSE)
  utils::write.csv(data.frame(sample = rownames(x), other_fat = tt$other_fat), file.path(dir, "samples.csv"), row.names = FALSE)
  list(input = file.path(dir, "expression.csv"), samples = file.path(dir, "samples.csv"), x = x, traits = tt)
}
