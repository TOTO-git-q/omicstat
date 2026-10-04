# S4 probe 1 (read only): locked-container source and versions that decide
# the GO ALL denominators and multiple-testing scope. Output: stdout log.
suppressPackageStartupMessages({
  library(clusterProfiler); library(org.Hs.eg.db); library(GO.db)
})
cat("== versions\n")
for (p in c("clusterProfiler", "enrichit", "DOSE", "GO.db", "org.Hs.eg.db", "AnnotationDbi",
            "GOSemSim", "enrichplot", "qvalue"))
  cat(p, if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "absent", "\n")
cat("== GO.db metadata\n"); print(AnnotationDbi::metadata(GO.db::GO.db))
cat("== org.Hs.eg.db metadata\n"); print(AnnotationDbi::metadata(org.Hs.eg.db::org.Hs.eg.db))
cat("== enrichGO\n"); print(clusterProfiler::enrichGO)
cat("== get_GO_data\n"); print(clusterProfiler:::get_GO_data)
ns <- asNamespace("clusterProfiler")
for (f in c("enricher_internal", "compareCluster")) if (exists(f, ns)) { cat("== clusterProfiler", f, "\n"); print(get(f, ns)) }
if (requireNamespace("enrichit", quietly = TRUE)) {
  en <- asNamespace("enrichit")
  cat("== enrichit exports\n"); print(ls(en))
  for (f in c("ora_gson", "ora", "ora_internal", "ora_core")) if (exists(f, en)) { cat("== enrichit", f, "\n"); print(get(f, en)) }
}
dn <- asNamespace("DOSE")
for (f in c("enricher_internal")) if (exists(f, dn)) { cat("== DOSE", f, "\n"); print(get(f, dn)) }
cat("== simplify methods\n"); print(showMethods("simplify", where = ns))
print(getMethod("simplify", "enrichResult"))
for (f in c("simplify_internal")) if (exists(f, ns)) { cat("== clusterProfiler", f, "\n"); print(get(f, ns)) }
cat("== setReadable\n"); print(DOSE::setReadable)
