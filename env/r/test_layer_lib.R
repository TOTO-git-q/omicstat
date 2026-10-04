# test_layer_lib.R -- offline tests of the environment installer helpers.
# ASCII only. Run: Rscript env/r/test_layer_lib.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(here, "layer_lib.R"))
failures <- 0
check <- function(ok, msg) { cat(if (isTRUE(ok)) "PASS:" else "FAIL:", msg, "\n"); if (!isTRUE(ok)) failures <<- failures + 1 }
cfg <- os_env_config(dirname(here))
check(identical(cfg$bioconductor, "3.23") && identical(cfg$r_version, "4.6.1"), "config pins R 4.6.1 / Bioc 3.23")
l1 <- os_layer_packages(cfg, "L1_bulk")
check(all(c("DESeq2", "edgeR", "limma") %in% l1) && !any(grepl("#", l1)), "layer file parsed without comments")
gh5 <- os_github_pins(cfg, "L5_sc_downstream")
check(setequal(gh5$package[gh5$layer == "L5"], c("monocle3", "CellChat")), "L5 GitHub pins read")
check(identical(os_github_pins(cfg, "L6_network")$package, "immunedeconv"), "L6 GitHub pin read")
check(nrow(os_github_pins(cfg, "L1_bulk")) == 0, "no GitHub pins in L1")
if (any(!grepl("^[0-9a-f]{40}$", gh5$sha))) {
  e <- tryCatch(os_install_layer(cfg, "L5_sc_downstream", lib = tempdir()), error = function(e) conditionMessage(e))
  check(grepl("^OS_ENV_UNPINNED", e), "unpinned GitHub package refused before any download")
}
check(grepl("2026-09-15", os_cran_repo(cfg)), "CRAN repo is the dated snapshot")
if (failures) quit(status = 1) else cat("ALL LAYER LIB CHECKS PASSED\n")
