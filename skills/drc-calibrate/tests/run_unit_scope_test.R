here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mod <- dirname(here); root <- normalizePath(file.path(mod,"../..")); shared <- file.path(mod,"..","_shared","scripts")
for(f in c("module_kit.R","effect_table.R","dose_scope_support.R"))source(file.path(shared,f))
source(file.path(mod,"scripts/drc_calibrate_core.R"))
check<-function(ok,msg){if(!isTRUE(ok))stop(paste("FAIL",msg));cat("PASS:",msg,"\n")}
refuse<-function(expr,code){msg<-tryCatch({force(expr);"NO_ERROR"},error=conditionMessage);check(grepl(code,msg,fixed=TRUE),paste("typed refusal",code))}
run<-function(){
 tmp<-tempfile();dir.create(tmp);on.exit(unlink(tmp,recursive=TRUE))
 status<-system2(file.path(R.home('bin'),'Rscript'),c(shQuote(file.path(root,'tests/candidate-models/make_scope_inputs.R')),shQuote(tmp)))
 stopifnot(status==0)
 a<-list(input=file.path(tmp,'plate.csv'),`unit-col`='sample_id',mode='calibration',model='LL4',`blank-policy`='subtract-mean',`max-cv`=20,lloq=.05,uloq=50,`dose-unit`='ng/mL',`ci-level`=.95,`study-contract-sha256`=paste(rep('0',64),collapse=''))
 x<-drc_calibrate_compute(a);z<-x$tables$results
 check(x$metadata$n_biological_units==12 && x$metadata$n_samples==12,'unknown assay and biological counts explicit')
 check(all(is.na(z$concentration[z$withheld])) && all(is.na(z$ci_low[z$withheld])) && all(is.na(z$well_se[z$withheld])),'outside-range quantities and uncertainty withheld')
 keep<-!z$withheld;check(all(abs(z$concentration[keep]/z$well_concentration[keep]-z$dilution[keep])<1e-10),'dilution applied to original concentrations')
 d<-read.csv(a$input,colClasses='character');d$biological_unit<-ifelse(d$role=='unknown',d$sample_id,'')
 d$biological_unit[d$sample_id=='Donor02']<-'shared01';d$biological_unit[d$sample_id=='Donor03']<-'shared01'
 d$biological_unit[d$sample_id=='Donor04']<-'01';d$biological_unit[d$sample_id=='Donor05']<-'1'
 path<-file.path(tmp,'units.csv');write.csv(d,path,row.names=FALSE,na='');b<-a;b$input<-path;b[['unit-col']]<-'biological_unit'
 y<-drc_calibrate_compute(b)
 check(y$metadata$n_biological_units==11 && y$metadata$n_samples==12,'aliquots do not inflate biological n')
 check(all(c('01','1') %in% y$tables$biological_units$biological_unit),'leading-zero biological IDs remain distinct')
 check(isTRUE(all.equal(x$tables$results$concentration,y$tables$results$concentration)),'identity mapping does not change fitted concentrations')
 ii<-which(d$role=='unknown');d$biological_unit[ii[1]]<-'different';write.csv(d,path,row.names=FALSE,na='');refuse(drc_calibrate_compute(b),'OS_INVALID_DESIGN')
 b<-a;b[['unit-col']]<-NULL;refuse(drc_calibrate_compute(b),'OS_MISSING_PARAMETER')
 b<-a;b$lloq<-.001;refuse(drc_calibrate_compute(b),'OS_INVALID_PARAMETER')
 b<-a;b$input<-file.path(tmp,'plate5.csv');b$model<-'LL5';y<-drc_calibrate_compute(b)
 check(length(coef(y$object$standard_curve))==5 && any(!y$tables$results$withheld),'actual asymmetric LL5 calibration executes')
 b<-a;b$input<-file.path(tmp,'titer.csv');b$mode<-'titer';b$lloq<-b$uloq<-NULL;b[['titer-definition']]<-'halfmax'
 y<-drc_calibrate_compute(b);check(nrow(y$tables$results)==3 && all(abs(y$tables$results$titer/c(200,400,600)-1)<.05),'halfmax titer recovers declared synthetic curves')
 b[['titer-definition']]<-'endpoint';b[['endpoint-response']]<-1.2;y<-drc_calibrate_compute(b)
 check(all(abs(y$tables$results$titer/c(200,400,600)-1)<.05),'endpoint titer on corrected response scale')
 check(all(y$tables$effect_table$n_unweighted==1),'titer wells never become biological n')
 check(!file.exists('Rplots.pdf'),'no device leak')
}
run()
