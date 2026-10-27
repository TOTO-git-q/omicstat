here<-dirname(normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])));root<-normalizePath(file.path(here,'../../..'));for(f in c('module_kit.R','refdata_io.R','annotation_io.R'))source(file.path(root,'skills/_shared/scripts',f));source(file.path(here,'../scripts/dropletutils_emptydrops_core.R'))
check<-function(ok,msg){if(!isTRUE(ok))stop(paste('FAIL',msg));cat('PASS',msg,'\n')};refuse<-function(expr,code){msg<-tryCatch({force(expr);'NO_ERROR'},error=conditionMessage);check(grepl(code,msg,fixed=TRUE),paste('refusal',code))}
check(is.infinite(ed_number('none',allow_none=TRUE)),'explicit no retention');check(is.infinite(ed_number('multinomial',allow_estimate=TRUE)),'explicit multinomial');check(is.null(ed_number('estimate',allow_estimate=TRUE)),'explicit DM estimation');check(ed_number('50')==50,'positive numeric choice');refuse(ed_number('multinomial',allow_none=TRUE),'OS_INVALID_PARAMETER');refuse(ed_number('-1'),'OS_INVALID_PARAMETER')
p<-c(.8,.03,.08,.001,.5);totals<-c(1000,500,400,50,0);got<-ed_adjusted_p(p,totals,100,1000);check(isTRUE(all.equal(got[1:3],c(0,.045,.08))),'BH includes retain equality as zero and excludes ambient');check(all(is.na(got[4:5])),'ambient excluded even when diagnostic P is present');check(identical(p,c(.8,.03,.08,.001,.5)),'raw Monte Carlo P unchanged')
x<-matrix(c(1,2,0,2,3,0),3,dimnames=list(c('a','b','z'),c('c1','c2')));q<-ed_ambient_profile(c(b=.4,a=.6),x);check(identical(unname(q),c(.6,.4,0)),'align profile identities and reconstruct global-zero gene');refuse(ed_ambient_profile(c(a=.4,c=.6),x),'OS_INVALID_RESULT');refuse(ed_ambient_profile(c(.4,.5),x),'OS_INVALID_RESULT')
fx<-tempfile();dir.create(fx);status<-system2('python3',c(shQuote(file.path(here,'prepare_acceptance.py')),shQuote(fx)));check(status==0,'real fixture preparation')
a<-list(input=file.path(fx,'counts.rds'),format='rds',species='human',`refdata-id`='emptydrops_unfiltered_input',`refdata-registry`=file.path(fx,'registry.json'),`input-provenance`=file.path(fx,'counts.rds.json'),lower=100,fdr=.01,niters=1000,retain='none',alpha='multinomial',ignore=0,`test-ambient`='false')
y<-ed_input(a);check(nrow(y$counts)==51&&ncol(y$counts)==250,'all raw dimensions retained');check(sum(y$totals)==30000&&sum(y$totals==0)==10,'integer totals and zero barcodes retained');check(sum(y$ambient)==200&&y$n_sim==40,'explicit ambient and simulation family')
for(kind in c('fractional','negative','nonfinite','duplicate','filtered','no-ambient','too-large')){b<-a;b$input<-file.path(fx,paste0(kind,'.rds'));b[['input-provenance']]<-paste0(b$input,'.json');refuse(ed_input(b),if(kind=='no-ambient')'OS_INVALID_DESIGN'else'OS_INVALID_INPUT')}
b<-a;b$ignore<-1000;b$retain<-'1000';refuse(ed_input(b),'OS_INVALID_PARAMETER');b<-a;b[['test-ambient']]<-'true';b$niters<-100000;refuse(ed_input(b),'OS_INVALID_INPUT')
unlink(fx,recursive=TRUE)

md<-list(lower=100,niters=1000,retain=Inf,alpha=10);ar<-list(lower=100,niters=1000,retain="none",alpha="estimate");inp<-list(retain=Inf,alpha=NULL)
rp<-ed_resolved_parameters(md,ar,inp);check(identical(rp$resolved,c("100","1000","Inf","10")),"actual resolved metadata kept including estimated alpha")
bad<-md;bad$alpha<-NULL;refuse(ed_resolved_parameters(bad,ar,inp),"OS_INVALID_RESULT")
bad<-md;bad$lower<-101;refuse(ed_resolved_parameters(bad,ar,inp),"OS_INVALID_RESULT")
bad<-md;bad$alpha<-NaN;refuse(ed_resolved_parameters(bad,ar,inp),"OS_INVALID_RESULT")
fixed<-inp;fixed$alpha<-20;refuse(ed_resolved_parameters(md,ar,fixed),"OS_INVALID_RESULT")
cat('CONTRACTS PASSED; adapter and provenance validation only, native inference tested separately\n')
