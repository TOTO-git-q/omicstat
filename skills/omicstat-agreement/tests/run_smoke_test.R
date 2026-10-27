# requires: vcd irr epiR jsonlite digest ggplot2
# Synthetic contract tests; original anchors have a separate external-input gate.
a <- commandArgs(FALSE); .here <- dirname(normalizePath(sub("^--file=", "", a[grepl("^--file=", a)][1])))
source(file.path(.here,"test_helpers.R")); ag_test_require_native()
out <- Sys.getenv("OMICSTAT_AGREEMENT_TEST_OUT",tempfile("omicstat-agreement-native-"))
if(dir.exists(out)&&length(list.files(out,all.files=TRUE,no..=TRUE)))stop("Use a fresh native evidence directory; retain original failed outputs")
dir.create(out,recursive=TRUE,showWarnings=FALSE);fixtures <- file.path(out,"fixtures")
python <- Sys.getenv("OMICSTAT_PYTHON","python3")
status <- system2(python,shQuote(c(file.path(.here,"prepare_fixture.py"),"--outdir",fixtures)))
stopifnot(status==0)
checks <- 0L; failures <- character()
check <- function(ok,label) {checks <<- checks+1L;if(isTRUE(ok))cat("PASS:",label,"\n")else{cat("FAIL:",label,"\n");failures <<- c(failures,label)}}
ba <- ag_test_args("bland-altman",fixtures)
canonical <- ag_test_run(ba,"canonical",out); e <- ag_test_table(canonical,"effect_table")
d <- utils::read.csv(file.path(fixtures,"continuous.csv"))
check(max(abs(ag_ba_values(e)-ag_oracle_ba(d$method_a,d$method_b)))<1e-10,"synthetic Bland-Altman point and pointwise CI formulas")
check(is.na(e$loa_population_coverage[1])&&all(e$loa_population_coverage[2:3]==.95),"population LoA coverage is explicit and distinct from CI level")
replay <- ag_test_run(ba,"replay",out,argv=c("--spec",file.path(canonical$out,"provenance","resolved_spec.json"),"--outdir",file.path(out,"replay")))
for(file in list.files(file.path(canonical$out,"tables"))) {
  p1 <- file.path(canonical$out,"tables",file);p2 <- file.path(replay$out,"tables",file)
  check(identical(digest::digest(file=p1,algo="sha256"),digest::digest(file=p2,algo="sha256")),paste("same-input numerical table replay",file))
}
reverse <- ba;reverse$difference <- "b-minus-a"
ee <- ag_test_table(ag_test_run(reverse,"reverse_difference",out),"effect_table")
check(all(abs(ee$estimate+c(e$estimate[1],e$estimate[3],e$estimate[2]))<1e-10),"difference reversal changes sign and exchanges limits")
ninety <- ba;ninety[["confidence-level"]] <- "0.90"
ee <- ag_test_table(ag_test_run(ninety,"ninety_percent_ci",out),"effect_table")
check(identical(e$estimate,ee$estimate)&&all(ee$ci_high-ee$ci_low<e$ci_high-e$ci_low),"changing CI level never changes fixed 95 percent LoA estimand")
limits <- ba;limits[["acceptability-limit-lower"]] <- "-50";limits[["acceptability-limit-upper"]] <- "50";limits[["acceptability-rationale"]] <- "Prespecified broad synthetic test interval, not a real recommendation"
lr <- ag_test_run(limits,"prespecified_limits",out);accept <- ag_test_table(lr,"acceptability")
check(isTRUE(accept$prespecified_limits_supplied)&&isTRUE(accept$loa_and_ci_within_limits)&&!accept$automatic_substitutability_claim,"acceptability comparison includes uncertainty and never asserts automatic interchangeability")

kappa <- ag_test_args("kappa",fixtures);kr <- ag_test_run(kappa,"ordinal_kappa",out);ke <- ag_test_table(kr,"effect_table")
check(identical(ke$status,c("sensitivity","primary","sensitivity")),"ordinal primary is linear; unweighted and quadratic remain sensitivity rows")
kt <- ag_test_table(kr,"contingency")
check(sum(kt$count)==30&&all(abs(kt$row_fraction-kt$count/kt$row_total)<1e-12),"contingency counts and explicit row denominators reconcile")
kb <- kappa;kb[["ci-method"]] <- "bootstrap"
kb1 <- ag_test_run(kb,"kappa_bootstrap",out);kb2 <- ag_test_run(kb,"kappa_bootstrap_repeat",out)
check(identical(ag_test_table(kb1,"effect_table"),ag_test_table(kb2,"effect_table")),"subject bootstrap replays with recorded seed and successes")
check(all(ag_test_table(kb1,"effect_table")$bootstrap_success+ag_test_table(kb1,"effect_table")$bootstrap_failures==199),"no failed bootstrap replicate hidden or replaced")
binary <- kappa;binary$input <- file.path(fixtures,"binary.csv");binary$scale <- "nominal";binary$levels <- "0,1";binary$weights <- "none"
br <- ag_test_run(binary,"binary_kappa",out);be <- ag_test_table(br,"binary_companions")
check(all(be$status=="sensitivity_not_replacement")&&all(be$engine[1:3]=="epiR::epi.kappa"),"binary companions use actual epiR and remain sensitivity estimates")
fleiss <- ag_test_args("fleiss",fixtures);fr <- ag_test_run(fleiss,"fleiss",out);fe <- ag_test_table(fr,"effect_table")
check(fe$term=="fleiss_kappa"&&fe$bootstrap_success+fe$bootstrap_failures==199,"Fleiss retains its chance model and subject bootstrap accounting")
icc <- ag_test_args("icc",fixtures);ir <- ag_test_run(icc,"icc_single",out);ie <- ag_test_table(ir,"effect_table")
check(abs(ie$estimate-ag_oracle_icc(as.matrix(d[c("method_a","method_b","rater3","rater4")]))['icc21'])<1e-8,"synthetic independent ANOVA ICC2,1 oracle")
avg <- icc;avg[["icc-unit"]] <- "average";ar <- ag_test_run(avg,"icc_average",out)
check(ag_test_table(ar,"effect_table")$term=="ICC(2,k)"&&ag_test_metadata(ar)$estimand_sha256!=ag_test_metadata(ir)$estimand_sha256,"single and mean-rater ICC are distinct hash-bound estimands")
check(identical(readRDS(file.path(ir$out,"objects","model.rds"))$native$fallback_used,FALSE),"ICC has no psych estimator substitution")

# Independently mutate results to exercise original count/hash/interval release checks.
source(file.path(ag_test_module,"scripts","omicstat_agreement_core.R"))
rebuild <- function(run) list(metadata=ag_test_metadata(run),object=readRDS(file.path(run$out,"objects","model.rds")),
  tables=stats::setNames(lapply(list.files(file.path(run$out,"tables"),pattern="[.]csv$"),function(x)utils::read.csv(file.path(run$out,"tables",x),check.names=FALSE)),
    sub("[.]csv$","",list.files(file.path(run$out,"tables"),pattern="[.]csv$"))))
# CSV round-trip can legitimately change integer/double storage. Mutate a copied
# canonical in-memory object to test the release boundary without coercion noise.
source(file.path(ag_test_root,"skills","_shared","scripts","study_contract.R"))
typed <- ba;for(k in c("confidence-level","seed"))typed[[k]] <- as.numeric(typed[[k]])
original <- omicstat_agreement_compute(typed)
refused <- function(x) tryCatch({os_agreement_release(x);FALSE},error=function(e)grepl("^OS_INVALID_RESULT: OAG-18",conditionMessage(e)))
x <- original;x$metadata$n_independent <- x$metadata$n_independent+1;check(refused(x),"OAG18 catches published count drift")
x <- original;x$tables$effect_table$estimate[1] <- x$tables$effect_table$ci_high[1]+1;check(refused(x),"OAG18 retains original estimate-inside-interval guard")
x <- original;x$tables$effect_table$model_spec_hash[1] <- strrep("0",64);check(refused(x),"OAG18 catches effect-row estimand hash drift")
x <- original;x$tables$effect_table$model_spec_hash <- NULL;check(refused(x),"OAG18 refuses a removed estimand binding column")
x <- original;x$object$estimand$difference <- "b-minus-a";check(refused(x),"OAG18 catches model versus metadata design drift")
x <- original;x$tables$pairs$difference[1] <- x$tables$pairs$difference[1]+1;check(refused(x),"OAG18 catches raw pair-table drift")

rows <- utils::read.csv(file.path(.here,"refusals.csv"),stringsAsFactors=FALSE,check.names=FALSE);obtained <- list()
for(i in seq_len(nrow(rows))) {
  folder <- file.path(out,"refusals",rows$case[i]);args <- unlist(jsonlite::fromJSON(rows$argv[i]),use.names=FALSE)
  args <- gsub("{fixtures}",fixtures,args,fixed=TRUE);args <- gsub("{outdir}",folder,args,fixed=TRUE)
  rr <- ag_test_run(ba,rows$case[i],file.path(out,"refusal_logs"),expect_ok=FALSE,argv=args)
  log <- paste(readLines(rr$log,warn=FALSE),collapse="\n")
  ok <- rr$status!=0&&grepl(rows$expected_code[i],log,fixed=TRUE)&&!dir.exists(file.path(folder,"tables"))
  check(ok,paste("typed refusal",rows$case[i]));obtained[[i]] <- list(case=rows$case[i],expected_code=rows$expected_code[i],status=rr$status,pass=ok)
}
for(pkg in c("vcd","irr","epiR")) {
  args <- switch(pkg,vcd=kappa,irr=icc,epiR=binary)
  rr <- tryCatch({Sys.setenv(OMICSTAT_AGREEMENT_SIMULATE_MISSING=pkg);ag_test_run(args,paste0("missing_",pkg),out,expect_ok=FALSE)},finally=Sys.unsetenv("OMICSTAT_AGREEMENT_SIMULATE_MISSING"))
  check(rr$status!=0&&any(grepl("OS_MISSING_PACKAGE",readLines(rr$log,warn=FALSE),fixed=TRUE)),paste("no alternative package on missing",pkg))
}
specs <- list.files(file.path(canonical$out,"figures"),pattern="figure_spec.*json$",recursive=TRUE,full.names=TRUE)
check(length(specs)>0,"native shared renderer emits actual figure specifications")
for(file in specs){s <- paste(readLines(file,warn=FALSE),collapse="\n");check(grepl("pointwise",s,fixed=TRUE)&&grepl("Project-invented",s,fixed=TRUE),"each BA figure retains dataset and pointwise uncertainty semantics")}
versions <- stats::setNames(vapply(c("vcd","irr","epiR","jsonlite","digest","ggplot2"),function(p)as.character(utils::packageVersion(p)),""),c("vcd","irr","epiR","jsonlite","digest","ggplot2"))
jsonlite::write_json(obtained,file.path(out,"refusals.obtained.json"),auto_unbox=TRUE,pretty=TRUE)
jsonlite::write_json(list(R=as.character(getRversion()),packages=as.list(versions),checks=checks,failures=as.list(failures),
  scope="Invented native contract tests only. Original anchors, exact authorized package provenance, owner real-data sheet and visual review are separate gates.",
  golden_written=FALSE,seal_written=FALSE),file.path(out,"native_test_summary.json"),auto_unbox=TRUE,pretty=TRUE)
cat(sprintf("%d native checks; %d failures.\n",checks,length(failures)))
if(length(failures))quit(status=1)
