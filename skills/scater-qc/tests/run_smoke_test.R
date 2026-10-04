# requires: scuttle scater SingleCellExperiment BiocParallel digest jsonlite ggplot2
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this)); suite <- dirname(dirname(.module))
for(f in c("module_kit.R", "engine_run.R", "handoff.R", "convert.R", "args.R", "fig_all.R", "sc_bioc_io.R", "calls_check.R")) source(file.path(suite,"skills/_shared/scripts",f))
source(file.path(suite,"skills/_shared/scripts/fig_mod_sc_bioc.R"))
source(file.path(.module,"scripts/scater_qc_core.R"))
source(file.path(.module,"tests/fixtures/make_zeisel.R"))
work <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "scater-qc-smoke"); dir.create(work, recursive=TRUE,showWarnings=FALSE)
check <- function(ok, label) {if(!isTRUE(ok)) stop(paste("FAIL",label));cat("PASS",label,"\n")}
sce <- make_zeisel(suite)
if(is.null(sce)) {cat("SKIP: missing Zeisel anchor files\n");quit(status=0)}
check(identical(dim(sce),c(20006L,3005L)), "PRINTED scater overview: 20006 genes x 3005 cells, after splitAltExps")
check(identical(sort(SingleCellExperiment::altExpNames(sce)),c("ERCC","repeat")), "PRINTED alternative experiments")
mt <- grep("mt-",rownames(sce),value=TRUE); mtp<-file.path(work,"mt.txt");writeLines(mt,mtp)
a <- list("mt-genes"=mtp,"qc-mode"="mad",nmads=3,species="Mus musculus","id-type"="symbol")
r <- scater_qc_compute(sce,a)
# Replay the guide's metrics and the defining filter path independently.
ref <- scuttle::perCellQCMetrics(sce,subsets=list(Mito=grep("mt-",rownames(sce))))
f <- scuttle::perCellQCFilters(ref,sub.fields="subsets_Mito_percent",nmads=3)
check(isTRUE(all.equal(r$metrics$sum,ref$sum,tolerance=0)), "REPLAY exact vignette library sizes")
check(identical(r$metrics$discard,as.logical(f$discard)), "REPLAY exact filter decisions")
check(isTRUE(all.equal(r$metrics$subsets_Mito_percent,ref$subsets_Mito_percent,tolerance=0)), "REPLAY mitochondrial percent")
utils::write.csv(data.frame(anchor=c("input_genes","input_cells","retained_mad3"),value=c(nrow(sce),ncol(sce),ncol(r$sce))),file.path(work,"anchor_values.csv"),row.names=FALSE)
path <- file.path(work,"sce.rds");saveRDS(sce,path)
entry <- file.path(.module,"scripts/run_scater_qc.R")
base <- c("--input",path,"--mt-genes",mtp,"--qc-mode","mad","--nmads","3","--species","Mus_musculus","--id-type","symbol")
run <- function(argv,label,err=NULL) {
 log<-file.path(work,paste0(label,".log")); st<-system2("Rscript",c(shQuote(entry),shQuote(argv)),stdout=log,stderr=log)
 txt<-paste(readLines(log,warn=FALSE),collapse="\n")
 check(if(is.null(err)) st==0 else st!=0 && grepl(err,txt,fixed=TRUE),label);invisible(txt)
}
out<-file.path(work,"anchor");run(c(base,"--outdir",out),"anchor_cli")
run(c("--from-run",out,base[-c(1,2)],"--outdir",file.path(work,"from")),"from_run")
for (stem in c("detected", "subsets_Mito_percent", "qc_violin")) {
 p <- jsonlite::fromJSON(file.path(out,"figures",paste0(stem,".figure_spec.json")))
 check(file.exists(file.path(out,"figures",paste0(stem,".png"))),paste("figure",stem))
}
paths<-c("tables/metrics.csv","tables/thresholds.csv","tables/flow.csv","figures/detected.png","figures/subsets_Mito_percent.png","figures/qc_violin.png")
if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1") os_golden_write(.module,out,paths)
g <- os_golden_check(.module,out);check(g$status=="PASS",paste("golden",g$status))
check(!file.exists("Rplots.pdf"),"no Rplots.pdf")
