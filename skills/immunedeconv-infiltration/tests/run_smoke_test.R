# requires: immunedeconv, quantiseqr, jsonlite, digest, ggplot2
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
mod <- dirname(dirname(.this)); suite <- dirname(dirname(mod)); shared <- file.path(suite,"skills","_shared","scripts")
source(file.path(shared,"module_kit.R")); source(file.path(shared,"handoff.R"))
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"id-smoke"); dir.create(tmp,recursive=TRUE,showWarnings=FALSE)
n <- 0L; check <- function(ok,label) {n <<- n+1L; cat(if(isTRUE(ok)) 'PASS:' else 'FAIL:',label,'\n'); if(!isTRUE(ok)) stop(label)}
sha <- function(p) digest::digest(file=p,algo='sha256')
fixture <- file.path(suite,'acceptance','data','immunedeconv','dataset_racle.rda')
check(sha(fixture)=='7a3e69c89b16df3986e4d02f3dbba949be3c61321d2173a7356c1ac67ce2bef0','PACK C pinned fixture hash'); load(fixture)
mat <- dataset_racle$expr_mat; check(identical(dim(mat),c(32467L,4L)),'Racle four-sample structure')
p <- file.path(tmp,'expression.csv'); utils::write.csv(data.frame(gene_symbol=rownames(mat),mat,check.names=FALSE),p,row.names=FALSE)
entry <- file.path(mod,'scripts','run_immunedeconv_infiltration.R')
run <- function(...) {z<-system2('Rscript',c(shQuote(entry),unlist(list(...))),stdout=TRUE,stderr=TRUE); list(status=attr(z,'status') %||% 0,out=z)}
base <- c('--method','quantiseq','--input-scale','TPM'); out<-file.path(tmp,'anchor')
z<-run(base,'--input',shQuote(p),'--outdir',shQuote(out));check(z$status==0,paste('end to end',paste(tail(z$out,3),collapse=' | ')))
tab<-utils::read.csv(file.path(out,'tables','infiltration.csv'),check.names=FALSE)
ref<-as.data.frame(immunedeconv::deconvolute(gene_expression=mat,method='quantiseq',tumor=TRUE,arrays=FALSE,scale_mrna=TRUE))
check(isTRUE(all.equal(tab,ref,tolerance=1e-14,check.attributes=FALSE)),'full native official workflow replay')
check(nrow(tab)==11 && ncol(tab)==5 && all(abs(colSums(tab[-1])-1)<1e-12),'11 cell types,4 samples,fraction sums')
check(identical(round(as.numeric(tab[tab$cell_type=='B cell',-1]),2),c(.02,.43,.02,.49)),'provisional website B-cell two-decimal output (not locked numerical authority)')
out2<-file.path(tmp,'from-run'); z<-run(base,'--from-run',shQuote(out),'--outdir',shQuote(out2));check(z$status==0 && sha(file.path(out,'tables','infiltration.csv'))==sha(file.path(out2,'tables','infiltration.csv')),'from-run neutral expression replay equal')
check(read_handoff(out2)$ecosystem=='neutral','neutral ecosystem')
out3<-file.path(tmp,'spec'); z<-run('--spec',shQuote(file.path(out,'provenance','resolved_spec.json')),'--outdir',shQuote(out3));check(z$status==0 && sha(file.path(out,'tables','infiltration.csv'))==sha(file.path(out3,'tables','infiltration.csv')),'spec deterministic replay')
for(m in c('depmap','unknown')) {z<-run('--method',m,'--input-scale','TPM','--input',shQuote(p),'--outdir',shQuote(file.path(tmp,m)));check(z$status!=0 && any(grepl('OS_METHOD_UNAVAILABLE',z$out)),paste('typed refusal',m))}
for(m in c('epic','cibersort','cibersort_abs')) {
 z<-run('--method',m,'--input-scale','TPM','--input',shQuote(p),'--outdir',shQuote(file.path(tmp,paste0(m,'-licence'))))
 check(z$status!=0 && any(grepl('OS_LICENCE_REQUIRED',z$out)),paste('licence acknowledgement required',m))
}
z<-run('--method','cibersort','--accept-licence','cibersort','--input-scale','TPM','--input',shQuote(p),'--outdir',shQuote(file.path(tmp,'missing-cibersort')))
check(z$status!=0 && any(grepl('OS_REFDATA_MISSING',z$out)),'CIBERSORT source and LM22 never bundled')
new_paths <- character(0)
suppressPackageStartupMessages(library(EPIC)); suppressPackageStartupMessages(library(xCell))
for(m in c('mcp_counter','epic','xcell','timer','abis','consensus_tme','estimate')) {
 args<-c('--method',m,'--input-scale','TPM','--input',shQuote(p),'--outdir',shQuote(file.path(tmp,m)))
 if(m=='epic') args<-c(args,'--accept-licence','epic')
 if(m %in% c('timer','consensus_tme')) args<-c(args,'--indications','SKCM,SKCM,SKCM,SKCM')
 z<-run(args);check(z$status==0,paste('offline native method',m,paste(tail(z$out,2),collapse=' | ')))
 got<-utils::read.csv(file.path(tmp,m,'tables','infiltration.csv'),check.names=FALSE)
 extra<-list()
 if(m=='mcp_counter') extra<-list(genes=utils::read.table('/opt/omicstat/refdata/mcp_counter/genes.txt',sep='\t',header=TRUE,colClasses='character',check.names=FALSE),probesets=utils::read.table('/opt/omicstat/refdata/mcp_counter/probesets.txt',sep='\t',colClasses='character'),log_transform=TRUE,feature_types='HUGO_symbols')
 if(m=='xcell') extra<-list(parallel.sz=1,alpha=0.5,scale=TRUE)
 native<-as.data.frame(do.call(immunedeconv::deconvolute,c(list(gene_expression=mat,method=m,indications=if(m %in% c('timer','consensus_tme')) rep('SKCM',4) else NULL,tumor=TRUE,arrays=FALSE,scale_mrna=TRUE),extra)))
 check(isTRUE(all.equal(got,native,tolerance=1e-12,check.attributes=FALSE)),paste('full official wrapper parity',m))
 expected<-c(mcp_counter=11L,epic=8L,xcell=39L,timer=6L,abis=17L,consensus_tme=18L,estimate=4L)
 check(identical(dim(got),c(unname(expected[m]),5L)),paste('native output shape',m))
 if(m %in% c('epic')) check(all(abs(colSums(got[-1])-1)<1e-8),'EPIC native cell fraction sums')
 rel<-file.path('methods',m,'infiltration.csv');dest<-file.path(out,rel);dir.create(dirname(dest),recursive=TRUE,showWarnings=FALSE)
 file.copy(file.path(tmp,m,'tables','infiltration.csv'),dest,overwrite=TRUE);new_paths<-c(new_paths,rel)
}
# Keep the original quanTIseq row byte-for-byte; append only new method rows.
manifest<-file.path(mod,'tests','golden_manifest.csv')
if(identical(Sys.getenv('OMICSTAT_WRITE_GOLDEN'),'1')) {
 lines<-readLines(manifest); old<-utils::read.csv(text=paste(lines[!startsWith(lines,'#')],collapse='\n'),stringsAsFactors=FALSE)
 add<-setdiff(new_paths,old$path)
 if(length(add)) {
  rows<-data.frame(path=add,sha256=vapply(file.path(out,add),sha,''),tier='container',exempt_fields='')
  utils::write.table(rows,manifest,sep=',',row.names=FALSE,col.names=FALSE,append=TRUE,quote=TRUE)
 }
}
z<-run('--method','quantiseq','--input-scale','counts','--input',shQuote(p),'--outdir',shQuote(file.path(tmp,'badscale')));check(z$status!=0 && any(grepl('OS_INPUT_SCALE',z$out)),'counts scale refused')
for(tool in c('check_calls.R','lint_r.py','check_flag_docs.py')) {cmd<-if(endsWith(tool,'.R')) 'Rscript' else 'python3';check(system2(cmd,c(shQuote(file.path(suite,'tools',tool)),shQuote(mod)))==0,tool)}
gc<-os_golden_check(mod,out);check(gc$status=='PASS',paste('golden',gc$reason)); cat('SMOKE PASSED:',n,'checks\n')

# Synthetic user-authorized interface fixture, not licensed CIBERSORT code/signature.
stub <- file.path(tmp,"user_interface_stub.R");signature <- file.path(tmp,"user_signature.tsv")
writeLines(c('CIBERSORT <- function(sig_matrix,mixture_file,perm=0,QN=FALSE,absolute=FALSE,abs_method="sig.score",...) {', ' x <- read.delim(mixture_file,check.names=FALSE)', ' factor <- if(abs_method=="sig.score") 1 else 2', ' m <- matrix(0,nrow=ncol(x)-1,ncol=5,dimnames=list(names(x)[-1],c("B cells naive","T cells CD8","P-value","Correlation","RMSE")))', ' m[,1] <- factor*seq_len(nrow(m)); m[,2] <- perm+seq_len(nrow(m)); m', '}'),stub)
writeLines("synthetic interface fixture only",signature)
for(am in c("sig.score","no.sumto1")) {
 so <- file.path(tmp,paste0("stub-",am));ja <- file.path(tmp,paste0("stub-",am,".json"))
 jsonlite::write_json(list(abs_method=am,perm=7),ja,auto_unbox=TRUE)
 z <- run("--method","cibersort_abs","--input-scale","TPM","--input",shQuote(p),"--accept-licence","cibersort","--cibersort-source",shQuote(stub),"--cibersort-matrix",shQuote(signature),"--method-args",shQuote(ja),"--outdir",shQuote(so))
 check(z$status==0,paste("synthetic CIBERSORT interface",am,paste(tail(z$out,3),collapse=" | ")))
 immunedeconv::set_cibersort_binary(stub);immunedeconv::set_cibersort_mat(signature)
 nr <- as.data.frame(immunedeconv::deconvolute(mat,method="cibersort_abs",arrays=FALSE,abs_method=am,perm=7))
 got <- read.csv(file.path(so,"tables/infiltration.csv"),check.names=FALSE)
 check(isTRUE(all.equal(got,nr,check.attributes=FALSE)),paste("native interface forwarding",am))
 pv <- jsonlite::read_json(file.path(so,"provenance/provenance.json"))
 check(pv$resolved_native$arguments$abs_method==am&&pv$resolved_native$arguments$perm==7,paste("actual method provenance",am))
 check(any(grepl(am,readLines(file.path(so,"draft/methods_results.md")),fixed=TRUE)),paste("actual method Methods",am))
}
so <- file.path(tmp,"stub-dedicated")
z <- run("--method","cibersort_abs","--input-scale","TPM","--input",shQuote(p),"--accept-licence","cibersort","--cibersort-source",shQuote(stub),"--cibersort-matrix",shQuote(signature),"--cibersort-abs-method","no.sumto1","--outdir",shQuote(so))
check(z$status==0,"dedicated abs-method CLI binding")
pv <- jsonlite::read_json(file.path(so,"provenance/provenance.json"));check(pv$resolved_native$arguments$abs_method=="no.sumto1","dedicated abs-method resolved")
cat("PASS: synthetic interface only; no licensed CIBERSORT execution or signature redistribution\n")

check(identical(formals(immunedeconv::deconvolute_cibersort)$abs_method,"sig.score"),"locked CIBERSORT abs_method default")
# Scale and verified MCP-counter reference bindings cannot be replaced by JSON.
source(file.path(mod,'scripts/immunedeconv_infiltration_core.R'))
for(key in c('log_transform','feature_types','featuresType','genes','probesets')) {
 ja <- file.path(tmp,paste0('reserved-',key,'.json'))
 jsonlite::write_json(setNames(list(FALSE),key),ja,auto_unbox=TRUE)
 aa <- list(method='mcp_counter',`input-scale`='TPM',arrays='false',`method-args`=ja)
 err <- tryCatch({immunedeconv_infiltration_compute(aa,mat);''},error=conditionMessage)
 check(grepl('OS_CONFLICTING_PARAMETERS',err),paste('MCP-counter reserved native argument',key))
}
logp <- file.path(tmp,'log-expression.csv')
write.csv(data.frame(gene_symbol=rownames(mat),log2(mat+1),check.names=FALSE),logp,row.names=FALSE)
logo <- file.path(tmp,'log-input')
z <- run('--method','mcp_counter','--input-scale','log2TPM','--input',shQuote(logp),'--outdir',shQuote(logo))
check(z$status==0,'declared log2TPM MCP-counter route')
md <- paste(readLines(file.path(logo,'draft/methods_results.md')),collapse='\n')
check(grepl('Human log2(TPM+1) expression',md,fixed=TRUE)&&!grepl('Human non-log TPM',md,fixed=TRUE),'Methods reports the actual input scale')
md <- paste(readLines(file.path(tmp,'estimate/draft/methods_results.md')),collapse='\n')
check(grepl('score/purity result rows',md,fixed=TRUE)&&!grepl('Estimated 4 cell types',md,fixed=TRUE),'ESTIMATE result rows are not labelled cell types')
