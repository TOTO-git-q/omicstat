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

# Both native routes and an RDS-valued override must respect the inference boundary.
rds_group <- file.path(root,"group.rds");saveRDS("condition",rds_group)
for (override in list(c("--genes-group-dataset",'"condition"'),c("--genes-group-by",'"condition"'),c("--genes-group-by",jsonlite::toJSON(list(rds=rds_group),auto_unbox=TRUE)),c("--genes-group-dataset",'"condition"',"--genes-do-de","1"),c("--genes-group-by",'"condition"',"--genes-do-de",'"TRUE"'))) {
  refused_args <- c(args,override);refused_args[match("--outdir",refused_args)+1L] <- file.path(root,"refuse-condition")
  log <- file.path(root,"condition-refusal.log")
  rc <- system2("Rscript",c(shQuote(entry),vapply(refused_args,shQuote,'')),stdout=log,stderr=log)
  stopifnot(rc != 0L,any(grepl("OS_PSEUDOREPLICATION",readLines(log),fixed=TRUE)))
}
cat("PASS: dataset, alternate-group and RDS argument condition comparisons refused\n")

# Grouping guard uses sample information or the verified chain's own label column.
source(file.path(mdir,"scripts/cellchat_communication_core.R"))
guard_args <- list(`cluster-col`="labels", `sample-col`="samples")
probe <- sce; probe$condition <- "LS"; probe$labels_copy <- probe$labels
refused <- function(x, a, state=list(), message) {
 e <- tryCatch({cellchat_communication_group_guard(x,a,state); NULL},error=function(e)conditionMessage(e))
 stopifnot(!is.null(e),grepl("OS_PSEUDOREPLICATION",e,fixed=TRUE),grepl(message,e,fixed=TRUE),grepl("CellChat compares communication between cell groups, not conditions.",e,fixed=TRUE))
}
for (column in c("condition","samples")) {
 a <- guard_args; a[["cluster-col"]] <- column
 refused(probe,a,message="is sample-level")
}
no_sample <- probe; no_sample$samples <- NULL
refused(no_sample,guard_args,message="needs a sample column to verify that the grouping is cell-level")
stopifnot(isTRUE(cellchat_communication_group_guard(no_sample,guard_args,list(cluster_col="labels"))))
S4Vectors::metadata(no_sample)$omicstat <- list(cluster_col="labels")
stopifnot(isTRUE(cellchat_communication_group_guard(no_sample,guard_args)))
a <- guard_args; a[["cluster-col"]] <- "labels_copy"
refused(no_sample,a,list(cluster_col="labels"),message="needs a sample column")
stopifnot(isTRUE(cellchat_communication_group_guard(probe,a)))
cat("PASS: sample-level condition, sample identity and unverified grouping refused; verified chain/embedded labels and cell-level alternative allowed\n")
# Verify the same refusals at the CLI input boundary.
for (case in c("condition", "samples", "no-samples")) {
 x <- if (case == "no-samples") no_sample else probe
 if (case == "no-samples") S4Vectors::metadata(x)$omicstat <- NULL
 input <- file.path(root,paste0("guard-",case,".rds")); saveRDS(x,input)
 av <- args; av[match("--input",av)+1L] <- input
 av[match("--cluster-col",av)+1L] <- if (case == "no-samples") "labels" else case
 av[match("--outdir",av)+1L] <- file.path(root,paste0("guard-",case))
 log <- file.path(root,paste0("guard-",case,".log"))
 rc <- system2("Rscript",c(shQuote(entry),vapply(av,shQuote,'')),stdout=log,stderr=log)
 stopifnot(rc != 0L,any(grepl("OS_PSEUDOREPLICATION",readLines(log),fixed=TRUE)))
}
cat("PASS: three grouping refusals also enforced through CLI\n")
# Exercise the second cell-level label through the production CLI as well.
alt_input <- file.path(root,"alternate-label.rds"); saveRDS(probe,alt_input)
alt_args <- args; alt_args[match("--input",alt_args)+1L] <- alt_input
alt_args[match("--cluster-col",alt_args)+1L] <- "labels_copy"
alt_args[match("--outdir",alt_args)+1L] <- file.path(root,"alternate-label")
alt_log <- file.path(root,"alternate-label.log")
stopifnot(system2("Rscript",c(shQuote(entry),vapply(alt_args,shQuote,'')),stdout=alt_log,stderr=alt_log)==0L)
stopifnot(identical(digest::digest(file=file.path(fast,"tables/communication.csv"),algo="sha256"),digest::digest(file=file.path(root,"alternate-label/tables/communication.csv"),algo="sha256")))
cat("PASS: alternate cell-level label CLI communication byte-identical to default presto anchor\n")
