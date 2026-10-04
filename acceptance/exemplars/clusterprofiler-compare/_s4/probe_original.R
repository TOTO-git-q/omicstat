# S4 probe (compare F2): the ORIGINAL example code of the clusterProfiler book,
# chapter comparecluster-analysis.qmd lines 31-42, commit 549613197f
# (sha256 e4c2ea01381c9370ed7074013917d523e66dcab4084e1cbf79966632101da6ab, see
# acceptance/exemplars/clusterprofiler-compare/L2/manifest.tsv), run verbatim
# on the unmodified gcSample lists, then compared with a direct call that makes
# the implicit default universe explicit.
suppressPackageStartupMessages({ library(clusterProfiler); library(org.Hs.eg.db); library(DOSE) })
# ---- verbatim book code (lines 31-32, 39-42) ----
data(gcSample)
str(gcSample)
ck <- compareCluster(geneCluster = gcSample, fun = enrichGO,
                    OrgDb = org.Hs.eg.db, ont="BP")
ck <- setReadable(ck, OrgDb = org.Hs.eg.db, keyType="ENTREZID")
head(ck)
# ---- end verbatim ----
o <- as.data.frame(ck)
cat("original rows", nrow(o), "\n"); print(table(o$Cluster))
u <- union(AnnotationDbi::keys(org.Hs.eg.db, keytype = "ENTREZID"), unlist(gcSample, use.names = FALSE))
cat("explicit candidate universe", length(u), "\n")
full <- as.data.frame(compareCluster(geneClusters = gcSample, fun = "enrichGO", data = "", source_from = NULL,
  OrgDb = org.Hs.eg.db, keyType = "ENTREZID", ont = "BP", pool = FALSE, universe = u,
  pvalueCutoff = 1, qvalueCutoff = 1, pAdjustMethod = "BH", minGSSize = 10, maxGSSize = 500, readable = FALSE))
cat("full rows", nrow(full), "\n")
key <- function(d) paste(d$Cluster, d$ID)
sel <- full$pvalue <= 0.05 & full$p.adjust <= 0.05 & full$qvalue <= 0.2
cat("filtered full rows", sum(sel), "same keys:", setequal(key(full[sel, ]), key(o)), "\n")
m <- match(key(o), key(full))
cat("max|dp|", max(abs(full$pvalue[m] - o$pvalue)), "max|dpadj|", max(abs(full$p.adjust[m] - o$p.adjust)),
    "max|dq|", max(abs(full$qvalue[m] - o$qvalue)), "GeneRatio identical", identical(full$GeneRatio[m], o$GeneRatio),
    "BgRatio identical", identical(full$BgRatio[m], o$BgRatio), "\n")
den <- function(z) vapply(strsplit(z, "/", fixed = TRUE), `[`, "", 2)
print(table(o$Cluster, den(o$GeneRatio))); print(unique(den(o$BgRatio)))
print(o[1:3, c("Cluster", "ID", "GeneRatio", "BgRatio", "pvalue", "p.adjust", "qvalue")], digits = 15)
