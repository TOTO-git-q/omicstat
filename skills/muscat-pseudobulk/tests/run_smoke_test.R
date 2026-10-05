# requires: muscat SingleCellExperiment scuttle BiocParallel
.this <- normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]))
mdir<-dirname(dirname(.this));suite<-dirname(dirname(mdir))
.libPaths(c(file.path(suite,'.omicstat-acceptance'),.libPaths()))
for(f in c('module_kit.R','handoff.R','convert.R','sc_backend_io.R')) source(file.path(suite,'skills','_shared','scripts',f))
source(file.path(mdir,'tests','fixtures','make_kang.R'))
stopifnot(sprintf('%.5f',isg$logFC)=='5.47346',sprintf('%.1e',isg$p_val)=='3.0e-21')
os_backend_smoke(mdir,sce,c('--cluster-col','cluster_id','--counts-layer','counts','--sample-col','sample_id','--condition-col','group_id','--reference','ctrl','--target','stim'),'tables/differential.csv',function(out) {
  x<-read.csv(file.path(out,'tables/differential.csv'));stopifnot(nrow(x)>0,all(c('gene','logFC','p_val','p_adj.loc','p_adj.glb')%in%names(x)))
  row<-x[x$gene=='ISG15' & x$cluster_id=='B cells',]
  stopifnot(nrow(row)==1,sprintf('%.5f',row$logFC)=='5.47346',sprintf('%.1e',row$p_val)=='3.0e-21')
  native<-readRDS(file.path(out,'objects','native.rds'));stopifnot(length(SummarizedExperiment::assayNames(native$pseudobulk))==8L)
})

source(file.path(mdir,"scripts","muscat_pseudobulk_core.R"))
ids <- unlist(lapply(split(unique(as.character(sce$sample_id)),sub("[0-9].*","",unique(as.character(sce$sample_id)))),head,2),use.names=FALSE)
ii <- unlist(lapply(ids,function(id) head(which(sce$sample_id==id & sce$cluster_id=="B cells"),50)),use.names=FALSE)
tiny <- sce[,ii]
tiny <- tiny[order(Matrix::rowSums(SummarizedExperiment::assay(tiny,"counts")),decreasing=TRUE)[1:500],]
x <- SummarizedExperiment::assay(tiny,"counts")
x[,tiny$sample_id==ids[1]] <- 0
SummarizedExperiment::assay(tiny,"counts") <- x
args <- list(`sample-col`="sample_id",`condition-col`="group_id",`cluster-col`="cluster_id",reference="ctrl",target="stim",`ds-filter`='"none"',`ds-min-cells`="1")
err <- tryCatch({muscat_pseudobulk_compute(tiny,args);""},error=conditionMessage)
stopifnot(grepl("OS_PSEUDOREPLICATION",err,fixed=TRUE))
cat("PASS: post-filter fitted biological sample counts cannot bypass replicate guard\n")
