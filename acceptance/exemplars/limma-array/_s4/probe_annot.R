# S4 limma-array F1 probe: trace RnAgilentDesign028282.db (User's Guide 17.4.4).
# Downloads source tarballs to /omicstat/.s4-annot-src and installs them ONLY
# into the private library /omicstat/.s4-annot-lib (run dir, never ~/omic-build*).
options(warn = 1)
suite <- normalizePath(".")
src <- file.path(suite, ".s4-annot-src"); lib <- file.path(suite, ".s4-annot-lib")
dir.create(src, showWarnings = FALSE); dir.create(lib, showWarnings = FALSE)
cat("R", as.character(getRversion()), "Bioc", as.character(BiocManager::version()), "\n")
repos <- BiocManager::repositories()
print(repos)
ann <- repos[["BioCann"]]
ap <- utils::available.packages(repos = ann, type = "source")
want <- c("RnAgilentDesign028282.db", "org.Rn.eg.db")
print(ap[intersect(want, rownames(ap)), c("Package", "Version", "Depends", "Imports", "License", "Repository"), drop = FALSE])
ip <- rownames(installed.packages())
cat("in image:", paste(sprintf("%s=%s", c("AnnotationDbi", "org.Rn.eg.db", "RnAgilentDesign028282.db"),
    c("AnnotationDbi", "org.Rn.eg.db", "RnAgilentDesign028282.db") %in% ip), collapse = " "), "\n")
if ("AnnotationDbi" %in% ip) cat("AnnotationDbi", as.character(packageVersion("AnnotationDbi")), "\n")
need <- intersect(want, rownames(ap))
need <- need[!need %in% ip]
got <- utils::download.packages(need, destdir = src, repos = ann, type = "source", available = ap, quiet = TRUE)
for (i in seq_len(nrow(got))) {
  f <- got[i, 2]
  cat(sprintf("TARBALL %s %s %s bytes=%d sha256=%s\n", got[i, 1], ap[got[i, 1], "Version"], basename(f),
              file.size(f), digest::digest(file = f, algo = "sha256")))
}
for (i in seq_len(nrow(got))) {
  tmpd <- tempfile(); untar(got[i, 2], exdir = tmpd)
  print(read.dcf(file.path(tmpd, got[i, 1], "DESCRIPTION"), fields = c("Package", "Version", "License", "Depends", "Imports", "Maintainer")))
}
ord <- c("org.Rn.eg.db", "RnAgilentDesign028282.db")
for (p in ord[ord %in% got[, 1]]) {
  st <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-test-load", "-l", shQuote(lib), shQuote(got[got[, 1] == p, 2])))
  cat("INSTALL", p, "status", st, "\n")
}
.libPaths(c(.libPaths(), lib))
suppressPackageStartupMessages(library(RnAgilentDesign028282.db))
cat("loaded RnAgilentDesign028282.db", as.character(packageVersion("RnAgilentDesign028282.db")), "\n")
print(RnAgilentDesign028282.db)
cat("PROBE DONE\n")
