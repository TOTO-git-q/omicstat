# Reproduce the source RNG fixture, never a registered owner dataset.
args <- commandArgs(TRUE);out <- normalizePath(args[1],mustWork=TRUE)
here <- dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
source(file.path(here,"longitudinal_test_helpers.R"))
d <- lc_source_fixture()
utils::write.csv(d,file.path(out,"longitudinal.csv"),row.names=FALSE)
utils::write.csv(d[nrow(d):1,],file.path(out,"reordered.csv"),row.names=FALSE)
