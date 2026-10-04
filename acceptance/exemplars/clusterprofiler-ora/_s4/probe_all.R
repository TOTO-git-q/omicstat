# S4 probe 2: DOSE fixture, GO ALL with pool FALSE and TRUE. Tabulates the
# per-ontology denominators and checks which BH family reproduces p.adjust.
suppressPackageStartupMessages({ library(clusterProfiler); library(org.Hs.eg.db) })
data(geneList, package = "DOSE")
selected <- names(geneList)[abs(geneList) > 2]; universe <- names(geneList)
for (pool in c(FALSE, TRUE)) {
  r <- as.data.frame(enrichGO(gene = selected, OrgDb = org.Hs.eg.db, keyType = "ENTREZID", ont = "ALL",
    pvalueCutoff = 1, pAdjustMethod = "BH", universe = universe, qvalueCutoff = 1,
    minGSSize = 10, maxGSSize = 500, readable = FALSE, pool = pool))
  cat("== pool", pool, "rows", nrow(r), "\n")
  den <- function(z) vapply(strsplit(z, "/", fixed = TRUE), `[`, "", 2)
  print(table(r$ONTOLOGY, paste(den(r$GeneRatio), den(r$BgRatio))))
  within <- unlist(lapply(split(seq_len(nrow(r)), r$ONTOLOGY), function(i) {
    stats::setNames(stats::p.adjust(r$pvalue[i], "BH"), r$ID[i]) }))
  across <- stats::setNames(stats::p.adjust(r$pvalue, "BH"), r$ID)
  cat("max |BH within ontology - p.adjust|:", max(abs(within[r$ID] - r$p.adjust)), "\n")
  cat("max |BH across all rows - p.adjust|:", max(abs(across[r$ID] - r$p.adjust)), "\n")
  cat("BH<0.05 by ontology:\n"); print(tapply(r$p.adjust < 0.05, r$ONTOLOGY, sum))
}
bp <- as.data.frame(enrichGO(gene = selected, OrgDb = org.Hs.eg.db, keyType = "ENTREZID", ont = "BP",
    pvalueCutoff = 1, pAdjustMethod = "BH", universe = universe, qvalueCutoff = 1,
    minGSSize = 10, maxGSSize = 500, readable = FALSE, pool = FALSE))
cat("BP-only rows", nrow(bp), "\n")
# gcSample (compare F2 preparation)
data(gcSample, package = "clusterProfiler")
k <- AnnotationDbi::keys(org.Hs.eg.db, keytype = "ENTREZID")
cat("== gcSample sizes\n"); print(lengths(gcSample))
cat("in OrgDb keys:\n"); print(vapply(gcSample, function(z) sum(z %in% k), 1L))
cat("duplicated within list:\n"); print(vapply(gcSample, anyDuplicated, 1L))
cat("in DOSE geneList:\n"); print(vapply(gcSample, function(z) sum(z %in% universe), 1L))
