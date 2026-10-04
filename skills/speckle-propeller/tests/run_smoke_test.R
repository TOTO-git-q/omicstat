# requires: speckle SingleCellExperiment limma
.this<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]));mdir<-dirname(dirname(.this));suite<-dirname(dirname(mdir))
.libPaths(c(file.path(suite,'.omicstat-acceptance'),.libPaths()))
for(f in c('module_kit.R','handoff.R','convert.R','sc_backend_io.R')) source(file.path(suite,'skills','_shared','scripts',f))
source(file.path(mdir,'tests','fixtures','make_cellbench.R'));sce<-make_cellbench(suite)
library(SingleCellExperiment)
v<-speckle::propeller(sce);print(v)
stopifnot(sprintf('%.8f',v['H1975','P.Value'])=='0.01841045',sprintf('%.8f',v['H1975','FDR'])=='0.05003357')
v_asin<-speckle::propeller(sce,transform='asin');stopifnot(sprintf('%.8f',v_asin['H1975','P.Value'])=='0.01578743')
os_backend_smoke(mdir,sce,c('--cluster-col','cluster','--counts-layer','counts','--sample-col','sample','--condition-col','group'),'tables/differential.csv',function(out) {
 x<-read.csv(file.path(out,'tables/differential.csv'));stopifnot(nrow(x)==3L,all(c('P.Value','FDR')%in%names(x)))
 stopifnot(sprintf('%.8f',x$P.Value[x$cluster=='H1975'])=='0.01841045')
})
