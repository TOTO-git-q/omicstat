# requires: glmnet survival ggplot2 jsonlite digest
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mod <- dirname(here); shared <- file.path(mod,"..","_shared","scripts")
for(f in c("module_kit.R","handoff.R","survival_io.R","model_io.R","fig_all.R","calls_check.R"))source(file.path(shared,f))
suppressPackageStartupMessages(library(survival))
source(file.path(mod,"scripts/glmnet_coxsig_core.R"));source(file.path(mod,"scripts/glmnet_coxsig_report.R"))
check<-function(ok,msg){if(!isTRUE(ok))stop(paste("FAIL:",msg));cat("PASS:",msg,"\n")}
refuse<-function(expr,code){z<-tryCatch({force(expr);"none"},error=conditionMessage);check(grepl(code,z,fixed=TRUE),paste("typed refusal",code,z))}
tmp<-tempfile("coxsig-smoke-");dir.create(tmp);fixture<-file.path(tmp,"fixtures")
check(system2("python3",c(shQuote(file.path(here,"prepare_acceptance.py")),shQuote(fixture)))==0,"actual limma-array producer")
v<-jsonlite::fromJSON(file.path(here,"acceptance.json"))$canonical$argv;v<-gsub("{fixtures}",fixture,v,fixed=TRUE);a<-list();i<-1L
while(i<=length(v)){k<-sub("^--","",v[i]);if(k=="development-mode"){a[[k]]<-TRUE;i<-i+1L}else{a[[k]]<-v[i+1L];i<-i+2L}}
for(k in c("min-events","nlambda","lambda-min-ratio","lambda","max-iter","thresh","ci-level","seed"))a[[k]]<-as.numeric(a[[k]])
x<-glmnet_coxsig_compute(a);check(inherits(x$object,"cox_signature") && x$metadata$n_biological==1000,"typed original-scale frozen signature")
check(nrow(x$tables$cross_validation)>10 && nrow(x$tables$coefficient_path)>300,"complete CV and coefficient path exported")
check(all(x$tables$auc$auc>=0 & x$tables$auc$auc<=1) && grepl("apparent",x$metadata$performance_scope),"training AUC explicitly apparent")
check(x$object$lambda==.05 && length(x$object$training_subject_sha256)==1000,"fixed penalty and training identity hashes")
train<-file.path(tmp,"training-signature");dir.create(file.path(train,"objects"),recursive=TRUE)
saveRDS(x$object,file.path(train,"objects/model.rds"),version=3)
write_handoff(train,"training-signature","glmnet-coxsig","0.1.0",list(model=list(path=file.path(train,"objects/model.rds"),type="cox_signature")),state=list(candidate=TRUE,development_only=TRUE))
# Independent synthetic expression cohort; this test fixture is not an accepted biological producer.
set.seed(9982);n<-140L;genes<-x$object$genes;E<-matrix(rnorm(length(genes)*n),nrow=length(genes),dimnames=list(genes,sprintf("validation_%04d",1:n)))
lp<-as.numeric(t(E)%*%x$object$coefficients);d<-data.frame(unit=colnames(E),time=rexp(n,rate=exp(lp)/2)+.01,event=rbinom(n,1,.8))
up<-file.path(tmp,"validation-expression");dir.create(file.path(up,"objects"),recursive=TRUE)
write.csv(data.frame(feature_id=rownames(E),E,check.names=FALSE),file.path(up,"objects/expression.csv"),row.names=FALSE)
write_handoff(up,"validation-expression","test-synthetic-expression","0.0.0",list(expression=list(path=file.path(up,"objects/expression.csv"),type="expression_matrix")))
write.csv(d,file.path(tmp,"validation.csv"),row.names=FALSE)
b<-a;b$mode<-"validate";b[["from-run"]]<-up;b[["signature-run"]]<-train;b$clinical<-file.path(tmp,"validation.csv")
for(k in c("folds","standardize","nlambda","lambda-min-ratio","selection","lambda","cv-measure","cv-grouped","max-iter","thresh","cox-ties","cutoff","cutpoint"))b[[k]]<-NULL
b[["risk-times"]]<-"0,1,2,3";y<-glmnet_coxsig_compute(b)
check(identical(y$object,x$object),"external validation never mutates coefficients, lambda or training cutoff")
check(max(abs(y$tables$scores$linear_predictor-lp))<1e-12,"external predictions use original-scale coefficients without recentering")
check(identical(y$tables$scores$group,factor(ifelse(lp<=x$object$cutpoint,"low","high"),levels=c("low","high"))),"external groups freeze training cutoff")
check(y$metadata$frozen && grepl("external",y$metadata$performance_scope) && !nrow(y$tables$cross_validation),"external mode never repeats CV")
# Full CLI validation against the actual serialized training handoff from this model.
cmd<-c("--mode","validate","--from-run",up,"--signature-run",train,"--clinical",b$clinical,"--unit-col","unit","--time-col","time","--event-col","event","--time-unit",b[["time-unit"]],"--genes",b$genes,"--covariates","none","--expression-scale",b[["expression-scale"]],"--min-events","10","--roc-times",b[["roc-times"]],"--risk-times",b[["risk-times"]],"--ci-level",".95","--journal","nature","--study-contract",a[["study-contract"]],"--development-mode","--seed","20261016","--outdir",file.path(tmp,"cli-validation"))
ret<-system2("Rscript",c(shQuote(file.path(mod,"scripts/run_glmnet_coxsig.R")),vapply(cmd,shQuote,"")),stdout=file.path(tmp,"cli.log"),stderr=file.path(tmp,"cli.log"));if(ret!=0)cat(readLines(file.path(tmp,"cli.log")),sep="\n")
check(ret==0,"real external-validation CLI and render")
check(identical(digest::digest(file=file.path(train,"objects/model.rds"),algo="sha256"),digest::digest(file=file.path(tmp,"cli-validation/objects/model.rds"),algo="sha256")),"serialized signature SHA unchanged through external CLI")
c<-b;c$lambda<-.1;refuse(glmnet_coxsig_compute(c),"OS_CONFLICTING_PARAMETERS")
c<-b;c[["expression-scale"]]<-"normalized-log2";refuse(glmnet_coxsig_compute(c),"OS_HANDOFF_MISMATCH")
c<-b;c[["signature-run"]]<-a[["from-run"]];refuse(glmnet_coxsig_compute(c),"OS_HANDOFF_MISMATCH")
c<-b;c$genes<-paste(rev(genes),collapse=",");refuse(glmnet_coxsig_compute(c),"OS_HANDOFF_MISMATCH")
c<-b;c[["from-run"]]<-a[["from-run"]];c$clinical<-a$clinical;refuse(glmnet_coxsig_compute(c),"OS_INVALID_DESIGN")
c<-a;c$selection<-"lambda.1se";c$lambda<-NULL;z<-glmnet_coxsig_compute(c);check(is.finite(z$object$lambda),"one-standard-error penalty selection executes")
c<-a;c$selection<-"lambda.min";c$lambda<-NULL;c[["cv-measure"]]<-"C";z<-glmnet_coxsig_compute(c);check(is.finite(z$object$lambda),"Harrell-C CV objective and lambda.min execute")
# No censoring: direct pairwise AUC identities are independent of this wrapper.
for(marker in list(8:1,1:8,rep(1,8))){rr<-timeROC::timeROC(T=1:8,delta=rep(1,8),marker=marker,cause=1,weighting="marginal",times=c(3.5,5.5),ROC=TRUE,iid=FALSE);expected<-if(length(unique(marker))==1).5 else if(marker[1]>marker[8])1 else 0;check(max(abs(rr$AUC-expected))<1e-12,paste("uncensored AUC identity",expected))}
# Frozen validation permits a constant input feature; it never refits or drops it.
E[1,]<-0;write.csv(data.frame(feature_id=rownames(E),E,check.names=FALSE),file.path(up,"objects/expression.csv"),row.names=FALSE)
write_handoff(up,"validation-expression","test-synthetic-expression","0.0.0",list(expression=list(path=file.path(up,"objects/expression.csv"),type="expression_matrix")))
z<-glmnet_coxsig_compute(b);check(max(abs(z$tables$scores$linear_predictor-as.numeric(t(E)%*%x$object$coefficients)))<1e-12,"constant validation feature retained with frozen coefficient")
bad<-x$object;bad$lambda<-"invalid";badroot<-file.path(tmp,"bad-signature");dir.create(file.path(badroot,"objects"),recursive=TRUE);saveRDS(bad,file.path(badroot,"objects/model.rds"))
write_handoff(badroot,"bad-signature","glmnet-coxsig","0.1.0",list(model=list(path=file.path(badroot,"objects/model.rds"),type="cox_signature")))
c<-b;c[["signature-run"]]<-badroot;refuse(glmnet_coxsig_compute(c),"OS_HANDOFF_MISMATCH")
check(check_calls(list.files(file.path(mod,"scripts"),pattern="\\.R$",full.names=TRUE),file.path(mod,"scripts/calls_registry.json"))$ok,"registered engine calls")
check(check_default_drift(file.path(mod,"scripts/calls_registry.json"))$ok,"native API defaults")
check(!file.exists("Rplots.pdf"),"no device leak")
cat("SMOKE PASSED: frozen expression Cox signature\n");unlink(tmp,recursive=TRUE)
