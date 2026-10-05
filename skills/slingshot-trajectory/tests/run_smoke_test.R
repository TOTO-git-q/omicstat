# requires: slingshot tradeSeq SingleCellExperiment Matrix mgcv
.this<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]));mdir<-dirname(dirname(.this));suite<-dirname(dirname(mdir))
.libPaths(c(file.path(suite,'.omicstat-acceptance'),.libPaths()))
for(f in c('module_kit.R','handoff.R','convert.R','sc_backend_io.R')) source(file.path(suite,'skills','_shared','scripts',f))
library(SingleCellExperiment);library(Matrix)
data('slingshotExample',package='slingshot')
rd<-slingshotExample$rd;cl<-as.character(slingshotExample$cl)
stopifnot(identical(dim(rd),c(140L,2L)),length(cl)==140L)
# The trajectory-only fixture has no expression data. A carrier assay is not used by Slingshot.
sce<-SingleCellExperiment(assays=list(counts=matrix(0L,1,140,dimnames=list('unused',rownames(rd)))),reducedDims=list(PCA=rd))
sce$cluster<-cl
os_backend_smoke(mdir,sce,c('--cluster-col','cluster','--counts-layer','counts','--reduced-dim','PCA','--start-cluster','auto','--fit-gam','false'),'tables/pseudotime.csv',function(out) {
 x<-read.csv(file.path(out,'tables/pseudotime.csv'));stopifnot(nrow(x)==140L,ncol(x)==4L)
 sds<-readRDS(file.path(out,'objects/native.rds'))$trajectory
 stopifnot(ncol(slingshot::slingPseudotime(sds))==2L)
},golden=FALSE)
# Exact seeded tradeSeq official fixture checks the optional gene-testing branch.
for(f in c('countMatrix','crv','celltype')) data(list=f,package='tradeSeq')
counts<-as.matrix(countMatrix);coords<-slingshot::slingReducedDim(crv)
colnames(counts)<-rownames(coords)<-paste0('cell',seq_len(ncol(counts)))
sce<-SingleCellExperiment(assays=list(counts=counts),reducedDims=list(PCA=coords));sce$cluster<-celltype
root<-file.path(Sys.getenv('OMICSTAT_TEST_TMP',tempdir()),'slingshot-trajectory-smoke')
fp<-file.path(root,'tradeseq_input.rds');cp<-file.path(root,'crv.rds');saveRDS(sce,fp);saveRDS(crv,cp)
entry<-file.path(mdir,'scripts/run_slingshot_trajectory.R');out<-file.path(root,'tradeseq')
av<-c('--input',fp,'--ecosystem','bioconductor','--cluster-col','cluster','--counts-layer','counts','--reduced-dim','PCA','--start-cluster','auto','--trajectory-rds',cp,'--seed','7','--outdir',out)
log<-file.path(root,'tradeseq.log');rc<-system2('Rscript',c(shQuote(entry),vapply(av,shQuote,'')),stdout=log,stderr=log)
if(rc!=0L)stop(paste(readLines(log),collapse='\n'))
native<-readRDS(file.path(out,'objects/native.rds'));converged<-sum(SummarizedExperiment::rowData(native$gam)$tradeSeq$converged)
cat('tradeSeq seeded vignette converged genes:',converged,'\n');stopifnot(converged==240L)
stopifnot(nrow(read.csv(file.path(out,'tables/association.csv')))==nrow(counts))
# The main golden is the Slingshot pseudotime table; retain the native association table too.
if(identical(Sys.getenv('OMICSTAT_WRITE_GOLDEN'),'1')) os_golden_write(mdir,out,c('tables/pseudotime.csv','tables/association.csv'))
stopifnot(identical(os_golden_check(mdir,out)$status,"PASS"))
# Reusing a trajectory must not assign its pseudotimes to reordered cells.
reordered <- file.path(root,'reordered_input.rds')
saveRDS(sce[,rev(seq_len(ncol(sce)))],reordered)
bad_av <- av; bad_av[match('--input',bad_av)+1L] <- reordered
bad_av[match('--outdir',bad_av)+1L] <- file.path(root,'reordered_refused')
bad_log <- file.path(root,'reordered_refused.log')
bad_rc <- system2('Rscript',c(shQuote(entry),vapply(c(bad_av,'--fit-gam','false'),shQuote,'')),stdout=bad_log,stderr=bad_log)
stopifnot(bad_rc!=0L,any(grepl('OS_INVALID_INPUT: reused trajectory embedding',readLines(bad_log),fixed=TRUE)))
cat('PASS: reused trajectory rejects reordered cells before pseudotime assignment or GAM fitting\n')
