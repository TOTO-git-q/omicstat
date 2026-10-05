# requires: batchelor scran scater bluster SingleCellExperiment jsonlite digest ggplot2
.this<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]));.module<-dirname(dirname(.this));suite<-dirname(dirname(.module))
source(file.path(suite,"skills/_shared/scripts/module_kit.R"));source(file.path(.module,"tests/fixtures/make_brain.R"))
work<-file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"batchelor-integrate-smoke");dir.create(work,recursive=TRUE,showWarnings=FALSE)
check<-function(x,label){stopifnot(isTRUE(x));cat("PASS",label,"\n")}
b<-make_brain(suite);check(ncol(b$z)==3005 && identical(dim(b$t),c(24150L,1809L)),"printed Zeisel/Tasic anchor dimensions")
# Real cluster producer from the previous module; append Tasic using same explicit upstream pipeline.
run<-function(m,args,label){entry<-file.path(suite,"skills",m,"scripts",paste0("run_",gsub("-","_",m),".R"));log<-file.path(work,paste0(label,".log"));st<-system2("Rscript",c(shQuote(entry),shQuote(args)),stdout=log,stderr=log);if(st!=0)cat(readLines(log),sep="\n");check(st==0,label)}
sce<-b$t[,seq_len(150)];colnames(sce)<-paste0("T_",colnames(sce));sce$batch<-"Tasic";sce$label<-as.character(sce$broad_type)
saveRDS(sce,file.path(work,"tasic.rds"));writeLines(grep("^mt_",rownames(sce),value=TRUE),file.path(work,"mito.txt"))
qc<-file.path(work,"qc")
run("scater-qc",c("--input",file.path(work,"tasic.rds"),"--mt-genes",file.path(work,"mito.txt"),"--qc-mode","fixed","--min-counts","1","--min-features","1","--max-mito","100","--species","mouse","--id-type","symbol","--outdir",qc),"tasic_qc")
cl<-file.path(work,"cluster")
run("scran-cluster",c("--from-run",qc,"--n-hvg","1000","--n-pcs","15","--graph-k","10","--umap-neighbors","15","--outdir",cl),"tasic_cluster")
# Join independently processed same-ecosystem samples, retaining state and original logcounts.
z<-b$z[,seq_len(150)];z<-scuttle::logNormCounts(z);z$batch<-"Zeisel";z$label<-as.character(z$level1class)
t<-readRDS(file.path(cl,"objects/sce.rds"));genes<-intersect(rownames(z),rownames(t))
z<-z[genes,];t<-t[genes,];colnames(z)<-paste0("Z_",colnames(z))
SummarizedExperiment::colData(z)<-S4Vectors::DataFrame(batch=z$batch,label=z$label,cluster=rep("Zeisel",ncol(z)),row.names=colnames(z))
SummarizedExperiment::colData(t)<-S4Vectors::DataFrame(batch=t$batch,label=t$label,cluster=t$cluster,row.names=colnames(t))
SingleCellExperiment::reducedDims(t)<-NULL;SingleCellExperiment::altExps(z)<-NULL
sce<-BiocGenerics::cbind(z,t);S4Vectors::metadata(sce)$omicstat<-S4Vectors::metadata(t)$omicstat
# Export joined object through a valid scran-cluster run handoff for integration.
source(file.path(suite,"skills/_shared/scripts/handoff.R"))
saveRDS(sce,file.path(cl,"objects/sce.rds"))
write_handoff(cl,run_id="joined_anchor",module="scran-cluster",module_version="1.0.0",objects=list(sce=list(path=file.path(cl,"objects/sce.rds"),type="SingleCellExperiment")),ecosystem="bioconductor",state=S4Vectors::metadata(sce)$omicstat)
out<-file.path(work,"anchor")
run("batchelor-integrate",c("--from-run",cl,"--batch-col","batch","--label-col","label","--n-hvg","1000","--n-pcs","15","--mnn-k","20","--umap-dims","15","--umap-neighbors","15","--mixing-k","10","--outdir",out),"integration_from_run")
x<-readRDS(file.path(out,"objects/sce.rds"));native<-readRDS(file.path(out,"objects/fastmnn.rds"));check(ncol(x)==ncol(sce)&&ncol(SingleCellExperiment::reducedDim(x,"corrected"))==15,"corrected shape")
check(identical(SummarizedExperiment::assay(x,"logcounts"),SummarizedExperiment::assay(sce,"logcounts")),"original logcounts preserved")
check(all(is.finite(SingleCellExperiment::reducedDim(x,"corrected"))),"finite corrected coordinates")
paths<-c("tables/cells.csv","tables/hvgs.csv","tables/variance.csv","tables/batch_summary.csv")
if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1")os_golden_write(.module,out,paths)
check(os_golden_check(.module,out)$status=="PASS","golden")
unequal<-file.path(work,"unequal_dims")
run("batchelor-integrate",c("--from-run",cl,"--batch-col","batch","--label-col","label","--n-hvg","1000","--n-pcs","15","--mnn-k","20","--umap-dims","10","--umap-neighbors","15","--mixing-k","10","--outdir",unequal),"unequal_umap_dimensions")
before<-jsonlite::read_json(file.path(unequal,"figures/before_batch.figure_spec.json"))$caption
after<-jsonlite::read_json(file.path(unequal,"figures/after_batch.figure_spec.json"))$caption
check(grepl("UMAP dimensions=15",before,fixed=TRUE) && grepl("UMAP dimensions=10",after,fixed=TRUE),"before and after captions use their actual unequal PCA dimensions")
