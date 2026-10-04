# check_calls.R -- CLI for lock 3 (ENGINEERING_PLAN 3.3). ASCII only.
# Usage: Rscript tools/check_calls.R skills/<module>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) { cat("usage: Rscript tools/check_calls.R skills/<module>\n"); quit(status = 2) }
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(here, "..", "skills", "_shared", "scripts", "calls_check.R"))
# Native supplementary-option wrappers pass the function as their first
# argument. Count these real call sites while retaining C1/C2/C3 unchanged.
source(file.path(here, "calls_wrapper_sites.R"))
mod <- normalizePath(args[1])
reg <- file.path(mod, "scripts", "calls_registry.json")
scripts <- list.files(file.path(mod, "scripts"), pattern = "\\.R$", full.names = TRUE)
cc <- check_calls(scripts, reg); dd <- check_default_drift(reg)
for (p in c(cc$problems, dd$problems)) cat("FAIL:", p, "\n")
cat(sprintf("%d call sites scanned; %d registry problems; %d default-drift problems\n", cc$n_sites, length(cc$problems), length(dd$problems)))
quit(status = if (cc$ok && dd$ok) 0 else 1)
