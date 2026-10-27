# Printed anchors are recomputed, never copied from historical obtained values.
args <- commandArgs(TRUE); module <- args[1]; output <- args[2]
source('skills/_shared/scripts/module_kit.R')
source('skills/_shared/scripts/effect_table.R')
source('skills/_shared/scripts/feature_table.R')
source('skills/_shared/scripts/candidate_model.R')
source('skills/_shared/scripts/dose_scope_support.R')
source(file.path('skills',module,'scripts',paste0(gsub('-','_',module),'_core.R')))
rows <- list(); hash <- paste(rep('0',64),collapse='')
check <- function(module,metric,expected,obtained,tolerance,source,scope='module') {
 rows[[metric]] <<- as.numeric(obtained)
}
if(module == 'drc-dose') {
hash<-paste(rep('0',64),collapse='')
f<-tempfile(fileext='.csv');write.csv(transform(drc::ryegrass,unit=seq_len(nrow(drc::ryegrass))),f,row.names=FALSE)
a<-list(input=f,response='rootl',dose='conc',unit='unit',`dose-unit`='mM',model='LL3',`response-levels`='50',`response-type`='relative',reference='control',`ci-level`=.95,`study-contract-sha256`=hash)
r<-drc_dose_compute(a);print(r$tables)
# Ritz et al PLOS ONE 2015 supplementary S1 Example 2: variable is
# misleadingly called ryegrass.LL.4 but the actual call is LL.3().
check('drc-dose','ryegrass slope',2.47033,coef(r$object)[1],.00005,'https://doi.org/10.1371/journal.pone.0146021')
check('drc-dose','ryegrass ED50',3.26336,r$tables$effect_table$estimate,.00005,'https://doi.org/10.1371/journal.pone.0146021')

}

if(module == 'lme4-lmm') {
f<-tempfile(fileext='.csv');write.csv(lme4::sleepstudy,f,row.names=FALSE)
a<-list(input=f,response='Reaction',subject='Subject',formula='Reaction ~ Days + (Days | Subject)',estimation='REML',`singular-tolerance`=1e-4,`ci-level`=.95,`study-contract-sha256`=hash)
r<-lme4_lmm_compute(a)
for(i in 1:2) check('lme4-lmm',c('sleepstudy intercept','sleepstudy Days')[i],c(251.405,10.467)[i],r$tables$effect_table$estimate[i],.001,'https://lme4.github.io/lme4/reference/lmer.html')
for(i in 1:3) check('lme4-lmm',c('intercept variance','slope variance','residual variance')[i],c(612.10,35.07,654.94)[i],r$tables$variance_components$vcov[c(1,2,4)][i],.02,'https://lme4.github.io/lme4/reference/lmer.html')

}

if(module == 'emmeans-contrast') {
source('skills/lme4-lmm/scripts/lme4_lmm_core.R')
a<-list(estimation='REML',`singular-tolerance`=1e-4,`ci-level`=.95,`study-contract-sha256`=hash)
# Official feedlot example has one herd grouping and lies within adapter scope.
d<-transform(emmeans::feedlot,adj.ewt=ewt-predict(lm(ewt~herd,data=emmeans::feedlot)))
f<-tempfile(fileext='.csv');write.csv(d,f,row.names=FALSE)
a$input<-f;a$response<-'swt';a$subject<-'herd';a$formula<-'swt ~ adj.ewt + diet + (1 | herd)'
r<-lme4_lmm_compute(a);fm<-tempfile();mm<-tempfile();saveRDS(r$object,fm);saveRDS(r$metadata,mm)
up<-list(module='lme4-lmm',state=list(development_only=TRUE,model_ready=r$ready),objects=list(model=list(path=fm),metadata=list(path=mm)))
a<-list(factor='diet',by=NULL,weights='equal',`df-method`='kenward-roger',adjust='tukey',`ci-level`=.95,`study-contract-sha256`=hash)
r<-emmeans_contrast_compute(a,up);print(r$tables$marginal_means)
for(i in 1:3) check('emmeans-contrast',paste('feedlot EMM',r$tables$marginal_means$diet[i]),c(Low=1029,Medium=998,High=1031)[as.character(r$tables$marginal_means$diet[i])],r$tables$marginal_means$emmean[i],.5,'https://rvlenth.github.io/emmeans/articles/predictions.html')

}

if(module == 'proda-diff') {
# Exact vignette setup (seed=1); retain its entire matrix for published engine anchor.
set.seed(1);syn<-proDA::generate_synthetic_data(n_proteins=100,n_conditions=2)
fit<-proDA::proDA(syn$Y,design=syn$groups,verbose=FALSE)
tt<-proDA::test_diff(fit,`Condition_1`-`Condition_2`,sort_by='pval',n_max=5,verbose=FALSE)
print(tt)
for(i in 1:5) {
 check('proda-diff',paste(tt$name[i],'diff'),c(-6.71,-2.33,4.74,-1.69,.933)[i],tt$diff[i],.01,'L1/proDA/vignettes/Introduction.rendered.txt','official engine example (100 proteins, all-missing retained)')
 check('proda-diff',paste(tt$name[i],'pval'),c(.0000518,.000125,.00195,.00415,.00674)[i],tt$pval[i],.00001,'L1/proDA/vignettes/Introduction.rendered.txt','official engine example (100 proteins, all-missing retained)')
}
# Compare the supported two-group adapter to those independent printed numbers.
st<-data.frame(sample=colnames(syn$Y),biological_id=colnames(syn$Y),condition=syn$groups)
a<-list(seed=1L,`sample-col`='sample',`bio-col`='biological_id',condition='condition',reference='Condition_2',target='Condition_1',`input-scale`='log2',`zero-policy`='observed',normalization='none')
pr<-proda_diff_compute(pd_prepare(syn$Y,st,a),a)$full
for(i in 1:5) check('proda-diff',paste(tt$name[i],'adapter diff'),c(-6.71,-2.33,4.74,-1.69,.933)[i],pr$diff[match(tt$name[i],pr$name)],.01,'L1/proDA/vignettes/Introduction.rendered.txt','module; all rows retained in upstream fit, all-missing canonical results withheld')

}

if(module == 'msstats-diff') {
# Published MSstats workflow is a technical-replicate spike-in standard (one
# biological unit/group), outside inference adapter scope. Reproduce upstream
# numbers without inventing biological replication, separately test refusal.
x<-MSstatsConvert::PDtoMSstatsFormat(data.table::fread(system.file('tinytest/raw_data/PD/pd_input.csv',package='MSstatsConvert')),data.table::fread(system.file('tinytest/raw_data/PD/annot_pd.csv',package='MSstatsConvert')),use_log_file=FALSE)
p<-MSstats::dataProcess(x,logTrans=2,normalization='equalizeMedians',featureSubset='all',n_top_feature=3,summaryMethod='TMP',equalFeatureVar=TRUE,censoredInt='NA',MBimpute=TRUE,use_log_file=FALSE,verbose=FALSE)
m<-MSstats::groupComparison(contrast.matrix='pairwise',data=p,use_log_file=FALSE,verbose=FALSE)
t<-as.data.frame(m$ComparisonResult);t<-t[t$Protein=='P0A8F4',];print(t)
for(i in 1:6) check('msstats-diff',paste('P0A8F4',t$Label[i]),c(-.36836494,-.433896,-1.12564427,-1.15790197,-.06553106,-.75727933)[i],t$log2FC[i],.00001,'L1/MSstats/vignettes/MSstatsWorkflow.rendered.txt','official engine spike-in example; adapter refuses insufficient biology')

}

if(module == 'drc-calibrate') {
fit <- drc::drm(rootl ~ conc, data=drc::ryegrass, fct=drc::LL.4())
means <- stats::aggregate(rootl ~ conc, drc::ryegrass, mean)
# Printed package backfit example; outside-asymptote last point intentionally NaN.
expected <- c(.5500692,.7743783,1.8744292,3.7830500,7.0811832,10.1667582)
for(i in 1:6) {
 z <- sc_inverse(fit,means$rootl[i],'absolute',.95)
 check(module,paste0('backfit dose ',means$conc[i]),expected[i],z[1],1e-6,
  'https://doseresponse.github.io/drc/reference/backfit.html','installed documented-data inverse helper; printed reference')
 native <- sc_ed(fit,means$rootl[i],'absolute',.95)
 stopifnot(abs(native[1]-z[1])<1e-9)
}

}

if(module == 'nlme-dose') {
ref <- nlme::nlme(circumference~stats::SSlogis(age,Asym,xmid,scal),data=Orange,
 fixed=Asym+xmid+scal~1,random=Asym~1,start=c(190,730,350),method='ML')
src <- 'https://svn.r-project.org/R-packages/trunk/nlme/tests/extras/scripts.Rout.save (fm2Oran.nlme)'
check(module,'Orange AIC',273,stats::AIC(ref),.5,src,'upstream published package regression output')
check(module,'Orange BIC',281,stats::BIC(ref),.5,src,'upstream published package regression output')
check(module,'Orange logLik',-132,as.numeric(stats::logLik(ref)),.5,src,'upstream published package regression output')

}

if(module == 'emmeans-contrast') {
 here <- normalizePath('skills/emmeans-contrast/tests')
 source(file.path(here,'longitudinal_test_helpers.R'))
 out <- paste0(output,'.longitudinal')
 if(dir.exists(out) && length(list.files(out,all.files=TRUE,no..=TRUE))) stop('Fresh longitudinal anchor evidence required')
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 metrics <- lc_anchor_values(here,out)
 definitions <- jsonlite::fromJSON(file.path(here,'anchors.json'),simplifyVector=FALSE)
 for(definition in definitions) if(definition$id %in% names(metrics)) rows[[definition$metric]] <- metrics[[definition$id]]
}

defs <- jsonlite::fromJSON(file.path('skills',module,'tests/anchors.json'),simplifyVector=FALSE)
stopifnot(setequal(names(rows),vapply(defs,`[[`,'','metric')))
values <- setNames(lapply(defs,function(d) rows[[d$metric]]),vapply(defs,`[[`,'','id'))
jsonlite::write_json(values,output,auto_unbox=TRUE,pretty=TRUE,na='null',digits=NA)
