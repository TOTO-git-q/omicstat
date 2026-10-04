# requires: CellChat SingleCellExperiment Matrix
.this<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]));mdir<-dirname(dirname(.this));suite<-dirname(dirname(mdir))
.libPaths(c(file.path(suite,'.omicstat-acceptance'),.libPaths()))
for(f in c('module_kit.R','handoff.R','convert.R','sc_backend_io.R')) source(file.path(suite,'skills','_shared','scripts',f))
source(file.path(mdir,'tests','fixtures','make_skin.R'));sce<-make_skin(suite)
stopifnot(identical(dim(sce),c(17328L,5011L)),length(unique(sce$labels))==12L)
cat('Human skin LS anchor shape:',dim(sce),'groups:',length(unique(sce$labels)),'\n')
direct <- os_backend_smoke(mdir,sce,c('--cluster-col','labels','--logcounts-layer','logcounts','--db-species','human','--db-subset','Secreted Signaling','--genes-do-fast','false'),'tables/communication.csv',function(out) {
 x<-read.csv(file.path(out,'tables/communication.csv'));stopifnot(nrow(x)>0,all(c('source','target','ligand','receptor','prob','pval','pathway_name')%in%names(x)))
 native<-readRDS(file.path(out,'objects/native.rds'));stopifnot(methods::is(native,'CellChat'),identical(dim(native@data),dim(sce)),length(levels(native@idents))==length(unique(sce$labels)),all(native@net$prob>=0))
},golden=FALSE)

# New default presto route, alongside the retained explicit Wilcoxon branch.
root <- dirname(direct); fast <- file.path(root,'fast')
entry <- file.path(mdir,'scripts','run_cellchat_communication.R')
args <- c('--input',file.path(root,'input.rds'),'--ecosystem','bioconductor','--cluster-col','labels','--logcounts-layer','logcounts','--db-species','human','--db-subset','Secreted Signaling','--outdir',fast)
log <- file.path(root,'fast.log'); rc <- system2('Rscript',c(shQuote(entry),vapply(args,shQuote,'')),stdout=log,stderr=log)
if(rc!=0L) stop(paste(readLines(log),collapse='\n'))
tab <- read.csv(file.path(fast,'tables','communication.csv'))
stopifnot(nrow(tab)>0,all(c('source','target','ligand','receptor','prob','pval','pathway_name') %in% names(tab)))
native <- readRDS(file.path(fast,'objects','native.rds'));stopifnot(methods::is(native,'CellChat'),all(native@net$prob>=0))
rel <- 'tables/communication_fast.csv';file.copy(file.path(fast,'tables','communication.csv'),file.path(direct,rel),overwrite=TRUE)
manifest <- file.path(mdir,'tests','golden_manifest.csv')
if(identical(Sys.getenv('OMICSTAT_WRITE_GOLDEN'),'1')) {
 lines<-readLines(manifest);rows<-read.csv(text=paste(lines[!startsWith(lines,'#')],collapse='\n'))
 if(!rel %in% rows$path) write.table(data.frame(path=rel,sha256=digest::digest(file=file.path(direct,rel),algo='sha256'),tier='container',exempt_fields=''),manifest,sep=',',row.names=FALSE,col.names=FALSE,append=TRUE,quote=TRUE)
}
g<-os_golden_check(mdir,direct);stopifnot(identical(g$status,'PASS'))
cat('PASS: default do.fast=TRUE human skin anchor and explicit Wilcoxon goldens; old golden retained\n')
