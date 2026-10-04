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
