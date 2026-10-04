# S4 probe: GO ALL pool TRUE denominators for the adapted fixture lists X1, X2.
suppressPackageStartupMessages({ library(clusterProfiler); library(org.Hs.eg.db) })
data(gcSample, package = "clusterProfiler"); data(geneList, package = "DOSE")
bg <- names(geneList); l <- lapply(gcSample[1:2], intersect, bg)
d <- as.data.frame(compareCluster(geneClusters = l, fun = "enrichGO", data = "", source_from = NULL,
  OrgDb = org.Hs.eg.db, keyType = "ENTREZID", ont = "ALL", pool = TRUE, universe = bg,
  pvalueCutoff = 1, qvalueCutoff = 1, pAdjustMethod = "BH", minGSSize = 10, maxGSSize = 500, readable = FALSE))
den <- function(z) vapply(strsplit(z, "/", fixed = TRUE), `[`, "", 2)
print(table(d$Cluster, paste(den(d$GeneRatio), den(d$BgRatio))))
