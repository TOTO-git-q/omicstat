here<-dirname(normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])));mod<-dirname(here);shared<-file.path(mod,'..','_shared','scripts')
for(f in c('module_kit.R','refdata_io.R','annotation_io.R','calls_check.R'))source(file.path(shared,f));source(file.path(mod,'scripts/reactomepa_ora_core.R'))
check<-function(ok,msg){if(!isTRUE(ok))stop(paste('FAIL',msg));cat('PASS',msg,'\n')};refuse<-function(expr,code){msg<-tryCatch({force(expr);'NO_ERROR'},error=conditionMessage);check(grepl(code,msg,fixed=TRUE),paste('refusal',code))}
tmp<-tempfile();dir.create(tmp)
write<-function(ids,name){p<-file.path(tmp,name);write.csv(data.frame(gene_id=ids),p,row.names=FALSE);p}
a<-list(input=write(c('3','1'),'q.csv'),universe=write(as.character(1:5),'u.csv'),`id-column`='gene_id',`min-size`=1L,`max-size`=10L,`universe-policy`='annotated-intersection')
x<-rpa_input(a);check(identical(x$query,c('1','3')),'stable lexical Entrez order')
for(ids in list(c('1','1'),c('001','3'),c('1','NA'),c('1',' 3'))){b<-a;b$input<-write(ids,paste0('bad',sample.int(100000,1),'.csv'));refuse(rpa_input(b),'OS_INVALID_INPUT')}
b<-a;b$input<-write(c('1','9'),'absent.csv');refuse(rpa_input(b),'OS_INVALID_UNIVERSE');b<-a;b$input<-a$universe;refuse(rpa_input(b),'OS_INVALID_UNIVERSE');b<-a;b[['min-size']]<-11;refuse(rpa_input(b),'OS_INVALID_PARAMETER')
ref<-list(pairs=data.frame(term_id=c('A','A','B','B'),gene_id=c('1','2','2','3')))
e<-rpa_effective(x,ref,a);check(length(e$universe)==3&&length(e$query)==2,'annotation intersection explicit');check(e$loss_u==.4&&e$loss_q==0,'selected and universe loss separated');check(nrow(e$report)==5&&sum(!e$report$annotated)==2,'all unannotated IDs preserved in report')
b<-a;b[['universe-policy']]<-'strict';refuse(rpa_effective(x,ref,b),'OS_INVALID_UNIVERSE');refuse(rpa_effective(list(query='5',universe=as.character(1:5)),ref,a),'OS_INVALID_UNIVERSE')
check(identical(os_reactome_species('human'),c('Homo sapiens','org.Hs.eg.db')),'species OrgDb binding');refuse(os_reactome_species('unknown'),'OS_INVALID_PARAMETER')
reg<-list(schema='omicstat.refdata.v2',entries=list(list(id='r',kind='geneset',consumers=list('reactomepa-ora'),redistribution='user_supplied')));p<-file.path(tmp,'registry.json');jsonlite::write_json(reg,p,auto_unbox=TRUE)
check(os_annotation_registry(p,'r','reactomepa-ora','geneset')$id=='r','registry consumer and kind gate');refuse(os_annotation_registry(p,'r','other','geneset'),'OS_REFDATA_MISMATCH');refuse(os_annotation_registry(p,'absent','reactomepa-ora','geneset'),'OS_REFDATA_MISSING')
f<-file.path(tmp,'payload.json');writeLines('{}',f);prov<-list(refdata_id='r',source_url='https://bioconductor.org/packages/ReactomePA/',version='test',licence='private synthetic test only',sha256=digest::digest(file=f,algo='sha256'),permitted_use='test');pp<-file.path(tmp,'prov.json');jsonlite::write_json(prov,pp,auto_unbox=TRUE)
check(os_user_refdata(f,pp,'r')$version=='test','payload SHA and provenance gate');writeLines('{"changed":true}',f);refuse(os_user_refdata(f,pp,'r'),'OS_REFDATA_MISMATCH')
check(check_calls(list.files(file.path(mod,'scripts'),pattern='\\.R$',full.names=TRUE),file.path(mod,'scripts/calls_registry.json'))$ok,'declared call-site coverage')
unlink(tmp,recursive=TRUE);cat('CONTRACT TESTS PASSED; no Reactome engine execution is implied\n')
