# Native independent OmicStat tests. Copied source fixture is synthetic only.
lc_load_native <- function(here) {
 root <- normalizePath(file.path(here,"..","..",".."))
 if(as.character(getRversion())!="4.6.1") stop("OS_ENV_R_VERSION: exact independent R4.6.1 lineage required")
 for(f in c("module_kit.R","candidate_model.R","effect_table.R")) source(file.path(root,"skills/_shared/scripts",f),local=.GlobalEnv)
 for(pkg in c("lme4","emmeans","pbkrtest","lmerTest","digest","jsonlite")) ex_require(pkg)
 source(file.path(root,"skills/lme4-lmm/scripts/lme4_lmm_core.R"),local=.GlobalEnv)
 for(f in c("emmeans_contrast_core.R","longitudinal_adapter.R")) source(file.path(dirname(here),"scripts",f),local=.GlobalEnv)
 root
}

lc_source_fixture <- function() {
 # Source run_verified.R seed, order, RNG calls, sample size and endpoint unchanged.
 source_seed <- 151L;set.seed(source_seed)
 ids <- 1:80;grp <- rep(c("A","B"),each=40)
 ri <- rep(seq(-1,1,length.out=40),2)
 d <- do.call(rbind,lapply(ids,function(i)data.frame(
  id=i,grp=grp[i],visit=1:3,
  y=10+ri[i]+(grp[i]=="B")*(2+0.4*(1:3))+0.3*(1:3)+stats::rnorm(3,sd=0.25))))
 # CSV character labels let the unchanged LMM entry preserve categorical time.
 d$visit <- paste0("visit",d$visit)
 d
}

lc_fixture_fit <- function(data,out,formula="y ~ grp * visit + (1 | id)") {
 dir.create(out,recursive=TRUE,showWarnings=FALSE)
 input <- file.path(out,"synthetic.csv");utils::write.csv(data,input,row.names=FALSE)
 hash <- paste(rep("0",64),collapse="")
 a <- list(input=input,response="y",subject="id",formula=formula,estimation="REML",
  `singular-tolerance`=.0001,`ci-level`=.95,`study-contract-sha256`=hash)
 got <- lme4_lmm_compute(a)
 stopifnot(got$ready)
 fm <- file.path(out,"model.rds");mm <- file.path(out,"metadata.rds")
 saveRDS(got$object,fm);saveRDS(got$metadata,mm)
 up <- list(module="lme4-lmm",state=list(model_ready=TRUE,development_only=TRUE),
  objects=list(model=list(path=fm),metadata=list(path=mm)))
 list(up=up,result=got,args=list(factor="grp",by="visit",longitudinal=TRUE,
  `time-levels`="visit1,visit2,visit3",`dataset-name`="SYNTHETIC LONG-balanced-cells contract only",
  weights="equal",`df-method`="kenward-roger",adjust="holm",`ci-level`=.95,`study-contract-sha256`=hash))
}

lc_max_error <- function(a,b) {
 stopifnot(identical(names(a),names(b)),nrow(a)==nrow(b))
 errors <- 0
 for(nm in names(a)) {
  if(is.numeric(a[[nm]])) {
   stopifnot(identical(is.na(a[[nm]]),is.na(b[[nm]])),identical(is.infinite(a[[nm]]),is.infinite(b[[nm]])))
   k <- is.finite(a[[nm]]) & is.finite(b[[nm]])
   if(any(k)) errors <- c(errors,abs(a[[nm]][k]-b[[nm]][k]))
  } else stopifnot(identical(as.character(a[[nm]]),as.character(b[[nm]])))
 }
 max(errors)
}

lc_original_environment <- function(here) {
 before <- new.env(parent=baseenv());before$add_effect_rows <- add_effect_rows;before$new_effect_table <- new_effect_table
 sys.source(file.path(here,"ported_source/longitudinal_selected_before.R"),envir=before)
 before
}

lc_before_native <- function(before,fit,prep,df,adjust) {
 old <- emmeans::emm_options()
 # Historical source mutates its global limits; isolate and restore in the test.
 tryCatch(before$lc_emm_and_tests(list(model=fit,engine="lmer",time_type="factor",emm_args=list(weights="equal")),
  prep,df,multiplicity=adjust,alpha=.05),finally=emmeans::emm_options(old))
}

lc_anchor_values <- function(here,out) {
 lc_load_native(here)
 d <- lc_source_fixture();fx <- lc_fixture_fit(d,file.path(out,"balanced-fit"))
 before <- lc_original_environment(here);fit <- fx$result$object
 prep <- os_longitudinal_frame(stats::model.frame(fit),"id","grp","visit","y","visit1,visit2,visit3")
 metrics <- list()
 for(method in c("kenward-roger","satterthwaite")) {
  a <- fx$args;a[["df-method"]] <- method
  old_options <- emmeans::emm_options();got <- emmeans_contrast_compute(a,fx$up)
  stopifnot(identical(old_options,emmeans::emm_options()))
  original <- lc_before_native(before,fit,prep,if(method=="kenward-roger")"Kenward-Roger" else "Satterthwaite","holm")
  for(pair in list(c("marginal_means","emm_df"),c("contrasts_unadjusted","contrast_raw"),
                  c("contrasts_adjusted","contrast_adjusted"),c("joint_tests_native","joint_tests"))) {
   id <- paste("longitudinal",method,pair[1],"source_error",sep="-")
   metrics[[id]] <- lc_max_error(got$tables[[pair[1]]],as.data.frame(original[[pair[2]]]))
  }
  for(nm in names(got$tables)) utils::write.csv(got$tables[[nm]],file.path(out,paste0(method,"_",nm,".csv")),row.names=FALSE)
  jsonlite::write_json(got$metadata,file.path(out,paste0(method,"_metadata.json")),auto_unbox=TRUE,pretty=TRUE,digits=NA)
  if(method=="kenward-roger") {
   reference <- mean(d$y[d$grp=="B" & d$visit=="visit3"])-mean(d$y[d$grp=="A" & d$visit=="visit3"])
   observed <- got$tables$effect_table$estimate[got$tables$effect_table$level=="visit3"]
   stopifnot(length(observed)==1L)
   metrics[["longitudinal-LONG-balanced-cells-visit3-error"]] <- abs(observed-reference)
   jsonlite::write_json(list(case="LONG-balanced-cells",observed=observed,independent_base_R=reference,
    tolerance=1e-5,synthetic_contract_only=TRUE),file.path(out,"SOURCE_ANCHOR.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
  }
 }
 metrics
}
