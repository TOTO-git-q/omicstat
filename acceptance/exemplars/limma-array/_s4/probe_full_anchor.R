# S4 limma-array F1: the full printed chain of User's Guide 17.4 and its engine
# replay, run with the SAME test functions as the smoke test
# (skills/limma-array/tests/guide_17_4.R), but with RnAgilentDesign028282.db
# 3.2.3 + org.Rn.eg.db 3.23.0 from the PRIVATE library of this GT103 run dir
# (.s4-annot-lib, installed by probe_annot.R) instead of the acceptance layer.
# Run from the suite root: bash bin/omicstat-r-route.sh Rscript acceptance/exemplars/limma-array/_s4/probe_full_anchor.R
suite <- normalizePath(".")
.libPaths(c(.libPaths(), file.path(suite, ".s4-annot-lib")))
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
source(file.path(suite, "skills", "limma-array", "tests", "guide_17_4.R"))
errors <- character()
check <- function(ok, msg) { if (isTRUE(ok)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); errors <<- c(errors, msg) } }
tmp <- file.path(suite, "_s4", "full_anchor"); unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
entry <- file.path(suite, "skills", "limma-array", "scripts", "run_limma_array.R")
run <- function(...) { o <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE)); list(status = attr(o, "status") %||% 0L, out = o) }
for (f in list.files(file.path(suite, ".s4-annot-src"), full.names = TRUE))
  cat("annotation tarball", basename(f), digest::digest(file = f, algo = "sha256"), "\n")
g <- gse33005_guide(file.path(tmp, "guide"), suite, annotate = TRUE)
print(g$annotation_versions)
g174_check_raw_printed(g, check)
g174_check_full_printed(g, check)
cat("guide x$genes[201:205,]:\n"); print(g$genes_x[201:205, ])
cat("guide dim(yfilt):", g$dim_yfilt, "\n"); print(g$head_yfilt)
cat("guide summary(decideTests(fit[,-1])):\n"); print(g$decide)
cat("guide topTable(fit,coef=4,n=20):\n"); print(g$top20, digits = 3)
g174_check_full_engine(g, tmp, run, check)
ds <- file.path(tmp, "full_route", "tables", "direction_summary.csv")
if (file.exists(ds)) { cat("engine direction_summary.csv:\n"); print(utils::read.csv(ds)) }
ft <- file.path(tmp, "full_route", "tables", "feature_table.csv")
if (file.exists(ft)) { cat("engine feature_table head:\n"); print(utils::head(utils::read.csv(ft), 5)) }
if (length(errors)) cat(length(errors), "checks FAILED\n") else cat("FULL ANCHOR PASSED\n")
