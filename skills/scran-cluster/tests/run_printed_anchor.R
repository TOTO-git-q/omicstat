# requires: scran scrapper SingleCellExperiment digest
# Exact locked official scran vignette setup (seed 100; ERCC altExp split).
library(scran)
library(scrapper)
this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1]))
suite <- dirname(dirname(dirname(dirname(this))))
source(file.path(dirname(this),"fixtures","make_grun.R"))
sce <- make_grun(suite)
sce <- SingleCellExperiment::splitAltExps(sce, ifelse(grepl("ERCC-[0-9]+",sub("__.*","",rownames(sce))),"ERCC","endogenous"),ref="endogenous")
set.seed(100)
results <- analyze.se(sce, num.threads=2)
sce.ready <- results$x
clusters <- quickCluster(sce.ready)
sce.normed <- computeSumFactors(sce.ready, clusters=clusters)
print(summary(sizeFactors(sce.normed)))
observed <- median(sizeFactors(sce.normed))
cat('PRINTED MEDIAN:', format(observed,digits=15),'expected 0.753183\n')
stopifnot(round(observed,6)==0.753183)
