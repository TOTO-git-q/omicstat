# Suite preset fixture (adapted, NOT the original example): DOSE geneList
# (package data) as an explicit common eligible universe, with the
# clusterProfiler gcSample lists intersected to that population.
cx_make_gcsample <- function(outdir) {
  dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
  e <- new.env(parent=emptyenv())
  utils::data("gcSample",package="clusterProfiler",envir=e)
  utils::data("geneList",package="DOSE",envir=e)
  bg <- names(e$geneList)
  utils::write.csv(data.frame(feature_id=bg),file.path(outdir,"eligible.csv"),row.names=FALSE)
  groups <- names(e$gcSample)
  for (g in groups) utils::write.csv(data.frame(feature_id=intersect(e$gcSample[[g]],bg)),
                                     file.path(outdir,paste0(g,".csv")),row.names=FALSE)
  m <- data.frame(group=groups,genes=paste0(groups,".csv"),universe="eligible.csv",
    population="DOSE geneList ranked universe (fixture only)",study_unit="gene ID",
    model="clusterProfiler gcSample package example (no model supplied)",
    contrast="none: named package example list",direction="unsigned selected set",
    threshold="gcSample membership within DOSE geneList",top_n="none",
    selection_rule="gcSample membership restricted to DOSE geneList eligible IDs")
  utils::write.csv(m,file.path(outdir,"manifest.csv"),row.names=FALSE)
  invisible(list(lists=lapply(e$gcSample,intersect,bg),universe=bg,manifest=file.path(outdir,"manifest.csv")))
}

# Original-example replay fixture (S4 compare F2): the UNMODIFIED gcSample
# lists of the clusterProfiler book example (comparecluster-analysis.qmd
# lines 31-42, commit 549613197f, sha256 in
# acceptance/exemplars/clusterprofiler-compare/L2/manifest.tsv). The book
# call gives no universe, so enrichGO uses its implicit default: every gene
# annotated in the GO collection. To pass that through the module's
# mandatory explicit-universe gate the candidate file is all org.Hs.eg.db
# ENTREZID keys plus the few gcSample IDs absent from OrgDb (so no list is
# altered); enrichGO intersects it with the GO-annotated genes, which is
# exactly the implicit default. This is a tracing device for the original
# example, not a claim about any experiment's selectable population.
cx_make_gcsample_original <- function(outdir) {
  dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
  e <- new.env(parent=emptyenv())
  utils::data("gcSample",package="clusterProfiler",envir=e)
  u <- union(AnnotationDbi::keys(org.Hs.eg.db::org.Hs.eg.db,keytype="ENTREZID"),unlist(e$gcSample,use.names=FALSE))
  utils::write.csv(data.frame(feature_id=u),file.path(outdir,"book_default_universe.csv"),row.names=FALSE)
  groups <- names(e$gcSample)
  for (g in groups) utils::write.csv(data.frame(feature_id=e$gcSample[[g]]),file.path(outdir,paste0(g,".csv")),row.names=FALSE)
  m <- data.frame(group=groups,genes=paste0(groups,".csv"),universe="book_default_universe.csv",
    population="book example implicit enrichGO default: all GO-annotated org.Hs.eg.db genes (tracing only)",
    study_unit="gene ID",model="clusterProfiler gcSample package example (no model supplied)",
    contrast="none: named package example list",direction="unsigned selected set",
    threshold="gcSample membership, unmodified",top_n="none",
    selection_rule="unmodified gcSample list; universe = enrichGO implicit default made explicit")
  utils::write.csv(m,file.path(outdir,"manifest.csv"),row.names=FALSE)
  invisible(list(lists=e$gcSample,universe=u,manifest=file.path(outdir,"manifest.csv")))
}
