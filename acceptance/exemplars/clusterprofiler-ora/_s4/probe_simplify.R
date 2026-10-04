# S4 probe 3: remaining sources (ALL labelling, simplify_ALL, setReadable,
# result filter), BH family per ontology, simplify timing and the
# merged -> representative reconstruction against the package's kept set.
suppressPackageStartupMessages({ library(clusterProfiler); library(org.Hs.eg.db) })
ns <- asNamespace("clusterProfiler"); en <- asNamespace("enrichit")
for (f in c("add_GO_Ontology", "simplify_ALL")) if (exists(f, ns)) { cat("== clusterProfiler", f, "\n"); print(get(f, ns)) }
for (f in c("setReadable", "EXTID2NAME", "get_enriched", "as.data.frame.enrichResult")) if (exists(f, en)) { cat("== enrichit", f, "\n"); print(get(f, en)) }
cat("== GOSemSim::godata formals\n"); print(formals(GOSemSim::godata))
data(geneList, package = "DOSE")
selected <- names(geneList)[abs(geneList) > 2]; universe <- names(geneList)
go <- function(ont, pool = FALSE) enrichGO(gene = selected, OrgDb = org.Hs.eg.db, keyType = "ENTREZID", ont = ont,
  pvalueCutoff = 1, pAdjustMethod = "BH", universe = universe, qvalueCutoff = 1,
  minGSSize = 10, maxGSSize = 500, readable = FALSE, pool = pool)
all_f <- go("ALL", FALSE); r <- as.data.frame(all_f)
cat("ALL pool FALSE object ontology slot:", all_f@ontology, "\n")
d <- 0
for (o in c("BP", "CC", "MF")) { i <- r$ONTOLOGY == o; d <- max(d, abs(stats::p.adjust(r$pvalue[i], "BH") - r$p.adjust[i])) }
cat("max |BH within each ontology - p.adjust| (pool FALSE):", d, "\n")
all_t <- go("ALL", TRUE); cat("ALL pool TRUE object ontology slot:", all_t@ontology, "\n")
for (o in c("CC", "BP")) {
  x <- go(o); t0 <- proc.time()[["elapsed"]]
  s <- simplify(x = x, cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL)
  cat("simplify", o, "terms", nrow(as.data.frame(x)), "->", nrow(as.data.frame(s)), "seconds", proc.time()[["elapsed"]] - t0, "\n")
  # reconstruction (same similarity call as clusterProfiler:::simplify_internal)
  res <- as.data.frame(x)
  sem <- GOSemSim::godata(ont = o)
  sim <- GOSemSim::mgoSim(res$ID, res$ID, semData = sem, measure = "Wang", combine = NULL)
  removed <- character()
  for (id in res$ID) {
    col <- sim[, id]; members <- sort(names(col)[!is.na(col) & col > 0.7])
    if (length(members) < 2) next
    pa <- res$p.adjust[match(members, res$ID)]
    rep <- members[pa == min(pa)]
    if (length(rep) > 1) { anc <- GOSemSim:::getAncestors(o); rep <- rep[which.max(vapply(rep, function(z) length(anc[[z]]), 1))] }
    removed <- unique(c(removed, setdiff(members, rep)))
  }
  kept <- res$ID[!res$ID %in% removed]
  cat("reconstructed kept identical to package:", identical(kept, as.data.frame(s)$ID), "\n")
}
t0 <- proc.time()[["elapsed"]]
sa <- tryCatch(simplify(x = all_f, cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL),
               error = function(e) e)
cat("simplify ALL pool FALSE:", if (inherits(sa, "error")) conditionMessage(sa) else nrow(as.data.frame(sa)), "seconds", proc.time()[["elapsed"]] - t0, "\n")
