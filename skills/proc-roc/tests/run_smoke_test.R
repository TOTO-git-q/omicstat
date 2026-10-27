args <- commandArgs(FALSE); .here <- dirname(normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1])))
source(file.path(.here,"test_helpers.R")); roc_test_require_native()
out <- Sys.getenv("OMICSTAT_ROC_TEST_OUT","")
if(!nzchar(out))out <- file.path(tempdir(),paste0("omicstat-roc-",Sys.getpid()))
if(dir.exists(out)&&length(list.files(out,all.files=TRUE,no..=TRUE)))stop("Use a fresh evidence directory; preserve prior failures")
dir.create(out,recursive=TRUE);fixtures<-file.path(out,"fixtures")
status<-system2(Sys.getenv("OMICSTAT_PYTHON","python3"),shQuote(c(file.path(.here,"prepare_fixture.py"),"--outdir",fixtures)))
stopifnot(status==0)
a<-roc_test_args(fixtures);one<-roc_test_run(a,"canonical",out)
status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(.here,"run_anchors.R"),"--run",one,"--fixtures",fixtures,"--results",file.path(out,"anchors.obtained.json"))))
stopifnot(status==0)
# Reordered sheet and expression-matrix adapter preserve the same values.
b<-a;b[["sample-sheet"]]<-file.path(fixtures,"sheet_reordered.csv");reordered<-roc_test_run(b,"reordered",out)
b<-a;b[["input-kind"]]<-"expression_matrix";b$input<-file.path(fixtures,"expression.csv");matrix_run<-roc_test_run(b,"matrix",out)
for(run in c(reordered,matrix_run))stopifnot(isTRUE(all.equal(roc_test_table(one,"auc_summary")$estimate,roc_test_table(run,"auc_summary")$estimate,tolerance=1e-12)))
# Native defaults remain native, never alternate tie handling or a reduced CI.
b<-a;b$input<-file.path(fixtures,"perfect.csv");b$cutpoint<-"youden";b[["cutpoint-source"]]<-NULL;b[["cutpoint-rationale"]]<-NULL
b[["internal-validation"]]<-"loo";loo<-roc_test_run(b,"exploratory_loo",out)
b[["internal-validation"]]<-"bootstrap";b[["bootstrap-reps"]]<-"250";bs<-roc_test_run(b,"exploratory_bootstrap_cap",out)
v<-roc_test_table(bs,"validation_accounting");stopifnot(v$requested_replicates==250,v$attempted_replicates==200,v$successful_replicates+v$failed_or_class_absent_replicates==200)
stopifnot(all(roc_test_table(bs,"cutoff_selection")$exploratory))
b<-a;b$pauc<-"0.8,1";b[["pauc-focus"]]<-"specificity";pa<-roc_test_run(b,"pauc",out)
stopifnot(roc_test_table(pa,"partial_auc")$partial_auc_corrected==FALSE,roc_test_table(pa,"auc_summary")$term=="full_auc")
b<-a;b[["confidence-level"]]<-"0.9";level<-roc_test_run(b,"confidence90",out)
stopifnot(all(roc_test_table(level,"roc_band")$ci_level==.9),all(roc_test_table(level,"auc_summary")$ci_level==.9))
b<-a;b$input<-file.path(fixtures,"one_missing_marker.csv");b[["sample-sheet"]]<-file.path(fixtures,"sheet_missing_reference.csv");b$missing<-"complete-case"
missing<-roc_test_run(b,"overlapping_missingness",out);flow<-roc_test_table(missing,"participant_flow")
stopifnot(flow$count[flow$stage=="analysed"]==39,flow$count[flow$stage=="excluded_missing_marker"]==1,flow$count[flow$stage=="excluded_missing_reference"]==0)
b<-a;b[["sample-sheet"]]<-file.path(fixtures,"sheet_indeterminate.csv");b[["indeterminate-value"]]<-"unknown";b$indeterminate<-"positive"
indet<-roc_test_run(b,"indeterminate",out);stopifnot(setequal(roc_test_table(indet,"indeterminate_sensitivity")$scenario,c("exclude","positive","negative")))
b<-a;b$subgroups<-"stratum";sg<-roc_test_run(b,"subgroups",out);stopifnot(nrow(roc_test_table(sg,"subgroup_accuracy"))==2)
# Shared replay is an actual CLI process, not merely comparing serialized argv.
replay<-file.path(out,"replay");status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(roc_test_module,"scripts/run_proc_roc.R"),"--spec",file.path(one,"provenance/resolved_spec.json"),"--outdir",replay)),stdout=file.path(out,"replay.log"),stderr=file.path(out,"replay.log"));stopifnot(status==0)
stopifnot(identical(roc_test_table(one,"auc_summary"),roc_test_table(replay,"auc_summary")))
# Real typed handoff entry calls with synthetic private carriers. These are
# definitions until executed in the independent R4.6.1 lane.
source(file.path(roc_test_root,"skills/_shared/scripts/study_contract.R"))
source(file.path(roc_test_root,"skills/_shared/scripts/handoff.R"))
make_chain <- function(label, filename, type, state = list()) {
  root <- file.path(out,label);dir.create(file.path(root,"objects"),recursive=TRUE)
  carrier <- file.path(root,"objects",filename)
  stopifnot(file.copy(file.path(fixtures,filename),carrier))
  write_handoff(root,basename(root),"synthetic-upstream-contract-fixture","0.1.0",
    list(measurements=list(path=carrier,type=type)),
    contract_hash=digest::digest(file=file.path(fixtures,"study_contract.json"),algo="sha256"),state=state)
  root
}
chain_args <- function(root, kind="feature_table") {
  z <- a;z$input <- NULL;z[["from-run"]] <- root;z$object <- "measurements";z[["input-kind"]] <- kind;z
}
chain_refusal <- function(z,label,code) {
  z$outdir <- file.path(out,label);log <- file.path(out,paste0(label,".log"))
  status <- system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(roc_test_module,"scripts/run_proc_roc.R"),roc_test_argv(z))),stdout=log,stderr=log)
  if(status==0||!any(grepl(code,readLines(log,warn=FALSE),fixed=TRUE)))stop(paste("Handoff refusal did not match",label,code))
}
good_chain <- make_chain("upstream_features","measurements.csv","feature_table")
chained <- roc_test_run(chain_args(good_chain),"chained_features",out)
matrix_chain <- make_chain("upstream_matrix","expression.csv","expression_matrix")
chained_matrix <- roc_test_run(chain_args(matrix_chain,"expression_matrix"),"chained_matrix",out)
for(run in c(chained,chained_matrix))stopifnot(isTRUE(all.equal(roc_test_table(one,"auc_summary")$estimate,roc_test_table(run,"auc_summary")$estimate,tolerance=1e-12)))
chain_refusal(chain_args(make_chain("upstream_wrong_type","measurements.csv","sample_table")),"chain_wrong_type","OS_HANDOFF_MISMATCH")
chain_refusal(chain_args(make_chain("upstream_display","measurements.csv","feature_table",list(display_only=TRUE))),"chain_display","OS_DISPLAY_ONLY_INPUT")
chain_refusal(chain_args(make_chain("upstream_corrected","measurements.csv","feature_table",list(batch_corrected_lineage=TRUE))),"chain_corrected","OS_BATCH_CORRECTED_INPUT")
changed <- make_chain("upstream_tampered","measurements.csv","feature_table")
cat("tampered\n",file=file.path(changed,"objects/measurements.csv"),append=TRUE)
chain_refusal(chain_args(changed),"chain_hash","OS_HANDOFF_MISMATCH")
z <- chain_args(good_chain);z$object <- "not_registered_in_run"
chain_refusal(z,"chain_object","OS_HANDOFF_MISMATCH")
z <- chain_args(good_chain);z[["study-contract"]] <- file.path(out,"changed_contract.json")
stopifnot(file.copy(file.path(fixtures,"study_contract.json"),z[["study-contract"]]))
cat("\n",file=z[["study-contract"]],append=TRUE)
chain_refusal(z,"chain_contract","OS_CONTRACT_MISMATCH")
# Every declared refusal executes the real entry and checks its registered code.
refusals<-utils::read.csv(file.path(.here,"refusals.csv"),stringsAsFactors=FALSE)
for(i in seq_len(nrow(refusals))){
 av<-unlist(jsonlite::fromJSON(refusals$argv[i]));av<-gsub("{fixtures}",fixtures,av,fixed=TRUE);av<-gsub("{outdir}",file.path(out,paste0("refusal_",i)),av,fixed=TRUE)
 log<-file.path(out,paste0("refusal_",i,".log"));status<-system2(file.path(R.home("bin"),"Rscript"),shQuote(c(file.path(roc_test_module,"scripts/run_proc_roc.R"),av)),stdout=log,stderr=log)
 if(status==0||!any(grepl(refusals$expected_code[i],readLines(log,warn=FALSE),fixed=TRUE)))stop(paste("Refusal did not match",refusals$case[i]))
}
# Source release must catch mutated output, independent of the graphical layer.
for(f in c("args.R","module_kit.R","study_contract.R","handoff.R","model_io.R","fig_all.R"))source(file.path(roc_test_root,"skills/_shared/scripts",f))
for(f in c("proc_roc_input.R","proc_roc_core.R"))source(file.path(roc_test_module,"scripts",f))
res<-list(metadata=readRDS(file.path(one,"objects/metadata.rds")),object=readRDS(file.path(one,"objects/model.rds")),tables=list())
# Stored native table hashes bind R objects before CSV formatting; obtain a fresh
# independent compute for mutation checks rather than pretending CSV class coercion is byte-identical.
aa<-roc_test_args(fixtures);for(k in c("confidence-level","bootstrap-reps","seed"))aa[[k]]<-as.numeric(aa[[k]])
clean<-proc_roc_compute(aa);bad<-clean;bad$tables$auc_summary$estimate[1]<-.123
stopifnot(inherits(try(os_proc_roc_release(bad),silent=TRUE),"try-error"))
bad<-clean;bad$metadata$estimand$direction<-"lower-is-positive";stopifnot(inherits(try(os_proc_roc_release(bad),silent=TRUE),"try-error"))
cat(sprintf("Native ROC smoke complete; %d typed refusals; numerical/adapter/replay checks; owner real-data remains separate.\n",nrow(refusals)))
