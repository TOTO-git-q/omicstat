# requires: monocle3 SingleCellExperiment Matrix batchelor
.this<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]));mdir<-dirname(dirname(.this));suite<-dirname(dirname(mdir))
.libPaths(c(file.path(suite,'.omicstat-acceptance'),.libPaths()))
for(f in c('module_kit.R','handoff.R','convert.R','sc_backend_io.R')) source(file.path(suite,'skills','_shared','scripts',f))
source(file.path(mdir,'tests','fixtures','make_packer.R'));set.seed(20260925)
sce<-make_packer(suite)
# Smoke tests graph association on an explicit 20-gene subset; trajectory uses all cells and genes.
gene_file<-file.path(Sys.getenv('OMICSTAT_TEST_TMP',tempdir()),'monocle-smoke-genes.txt');writeLines(rownames(sce)[1:20],gene_file)
os_backend_smoke(mdir,sce,c('--cluster-col','cluster','--counts-layer','counts','--partition-col','partition','--root-time-col','embryo.time.bin','--root-time-value','130-170','--root-rationale','earliest developmental time bin from the official guide','--graph-genes-file',gene_file),'tables/pseudotime.csv',function(out) {
 x<-read.csv(file.path(out,'tables/pseudotime.csv'));stopifnot(nrow(x)==6188L,any(is.finite(x$pseudotime)),all(is.finite(x$pseudotime)|is.infinite(x$pseudotime)))
 native<-readRDS(file.path(out,'objects/native.rds'));stopifnot(identical(dim(native$cds),c(20222L,6188L)),length(native$cds@principal_graph_aux[['UMAP']]$root_pr_nodes)>0)
 stopifnot(nrow(read.csv(file.path(out,'tables/graph_test.csv')))==20L)
})
