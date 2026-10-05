# requires: scran SingleCellExperiment jsonlite digest ggplot2
.this<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]));.module<-dirname(dirname(.this));suite<-dirname(dirname(.module))
source(file.path(suite,"skills/_shared/scripts/module_kit.R"));source(file.path(.module,"tests/fixtures/make_grun.R"))
work<-file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"scran-markers-smoke");dir.create(work,recursive=TRUE,showWarnings=FALSE)
check<-function(x,label){stopifnot(isTRUE(x));cat("PASS",label,"\n")}
sce<-make_grun(suite);check(identical(dim(sce),c(20148L,1728L)),"PACK C Grun dimensions")
# Execute the upstream QC/cluster smoke recipe on its actual anchor, without duplicating its finished module build.
up<-file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"scran-cluster-smoke/anchor")
if(!file.exists(file.path(up,"objects/handoff.json")))stop("OS_ACCEPTANCE_EVIDENCE_MISSING: run scran-cluster smoke first.")
out<-file.path(work,"anchor");log<-file.path(work,"anchor.log")
entry<-file.path(.module,"scripts/run_scran_markers.R")
st<-system2("Rscript",c(shQuote(entry),shQuote(c("--from-run",up,"--cluster-col","cluster","--rank-by","mean.AUC","--top-n","3","--outdir",out))),stdout=log,stderr=log)
if(st!=0)cat(readLines(log),sep="\n");check(st==0,"cluster->markers CLI from-run")
x<-readRDS(file.path(up,"objects/sce.rds"));native<-readRDS(file.path(out,"objects/markers.rds"));direct<-scran::scoreMarkers(x,groups=factor(x$cluster),lfc=0,assay.type="logcounts",BPPARAM=BiocParallel::SerialParam())
check(identical(native,direct),"official scoreMarkers direct replay")
tab<-read.csv(file.path(out,"tables/markers.csv"));check(nrow(tab)==nrow(x)*length(unique(x$cluster)) && "mean.AUC"%in%names(tab),"native full marker shape/columns")
check(!any(c("P.Value","FDR")%in%names(tab)),"effect summaries have no invented P values")
paths<-c("tables/markers.csv","tables/marker_plot_data.csv")
if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1")os_golden_write(.module,out,paths)
check(os_golden_check(.module,out)$status=="PASS","golden")

source(file.path(suite,"skills/_shared/scripts/sc_bioc_io.R"));source(file.path(.module,"scripts/scran_markers_core.R"))
x$sample <- "anchor"; x$condition <- "ctrl"; x$cell_label <- x$cluster
fixture <- file.path(work,"group_fixture.rds");saveRDS(x,fixture)
cli <- function(column,name,route="scoreMarkers",refused=FALSE,extra=character()) {
 target <- file.path(work,name); log <- file.path(work,paste0(name,".log"))
 st <- system2("Rscript",c(shQuote(entry),shQuote(c("--input",fixture,"--cluster-col",column,"--rank-by",if(route=="scoreMarkers")"mean.AUC" else "summary.logFC","--route",route,"--top-n","3","--outdir",target,extra))),stdout=log,stderr=log)
 text <- paste(readLines(log),collapse="\n")
 if(refused){check(st!=0 && grepl("OS_PSEUDOREPLICATION",text) && grepl("muscat-pseudobulk",text) && grepl("speckle-propeller",text),paste("sample-level refusal",column));cat(text,"\n")} else {if(st!=0)cat(text,"\n");check(st==0,paste("allowed",column,route))}
 target
}
cli("condition","refused",refused=TRUE)
cli("sample","refused_sample",refused=TRUE)
allowed <- cli("cell_label","allowed")
check(identical(readLines(file.path(out,"tables/markers.csv")),readLines(file.path(allowed,"tables/markers.csv"))),"second cell-level grouping byte-identical tables")
compat <- cli("cell_label","compatibility",route="findMarkers")
text <- paste(readLines(file.path(compat,"draft/methods_results.md")),collapse="\n")
check(grepl("P values are computed with cells as observations on clusters defined from the same data.",text,fixed=TRUE),"findMarkers Methods/Results caution")
check(!grepl("rows with.*< 0.05",text),"no significance count")
ct <- read.csv(file.path(compat,"tables/markers.csv"));check("summary.logFC"%in%names(ct),"compatibility native effect sizes retained")
direct <- scran::findMarkers(x,groups=factor(x$cluster),block=NULL,lfc=0,test.type="t",direction="any",pval.type="any",assay.type="logcounts",BPPARAM=BiocParallel::SerialParam())
check(identical(readRDS(file.path(compat,"objects/markers.rds")),direct),"compatibility P values unchanged in native replay")
a <- list(`cluster-col`="cell_label",`sample-col`="sample")
scran_markers_group_guard(x,a);check(TRUE,"one-sample varying grouping allowed")
x$sample <- NULL
scran_markers_group_guard(x,list(`cluster-col`="cluster"));check(TRUE,"no sample upstream cluster allowed")
check(inherits(tryCatch(scran_markers_group_guard(x,a),error=identity),"error"),"no sample alternate grouping refused")
# Sample blocking remains allowed; two interleaved samples both contain clusters.
x$sample <- rep(c("s1","s2"),length.out=ncol(x));saveRDS(x,fixture)
cli("cell_label","blocked",extra=c("--block-col","sample"))
