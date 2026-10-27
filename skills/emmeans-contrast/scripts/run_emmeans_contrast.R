# Development-only module; numerical validation and sealing remain pending.
options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module <- dirname(dirname(.this));.shared <- file.path(.module,"..","_shared","scripts")
for (f in c("args.R","engine_run.R","module_kit.R","effect_table.R","handoff.R")) source(file.path(.shared,f))
source(file.path(.shared,"candidate_model.R"))
source(file.path(dirname(.this),"emmeans_contrast_core.R"))
source(file.path(dirname(.this),"longitudinal_adapter.R"))
SPEC <- os_arg_spec(usage="Rscript run_emmeans_contrast.R --help",description="Unsealed development implementation of emmeans-contrast",flags=list(
 os_flag("from-run","path",required=TRUE,must_exist=TRUE,help="Verified lme4-lmm run"),
 os_flag("factor","string",required=TRUE,help="Categorical factor for pairwise contrasts"),
 os_flag("by","string",help="Optional single categorical conditioning factor"),
 os_flag("longitudinal","bool",help="Explicit categorical group-by-time post-fit mode; --factor is group and --by is time"),
 os_flag("dataset-name","string",help="Required in longitudinal mode: actual dataset label on every figure; label alone is not owner provenance"),
 os_flag("time-levels","string",help="Required in longitudinal mode: all fitted time labels in prespecified chronological order, comma-separated"),
 os_flag("weights","enum",required=TRUE,values=c("equal","proportional"),help="Marginal averaging population"),
 os_flag("df-method","enum",required=TRUE,values=c("kenward-roger","satterthwaite","asymptotic"),help="Explicit degrees-of-freedom method"),
 os_flag("adjust","enum",required=TRUE,values=c("none","tukey","bonferroni","sidak","holm"),help="Within-by multiplicity; longitudinal mode uses all timepoints jointly (Holm only in longitudinal mode)"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Actual validated study contract JSON"),
 os_flag("ci-level","num",required=TRUE,range=c(0.5,0.9999),help="Prespecified confidence level"),
 os_flag("development-mode","bool",help="Explicitly permit unsealed development execution"),
 os_flag("seed","int",required=TRUE,help="Recorded reproducibility seed"),
 os_flag("outdir","path",required=TRUE,help="New or empty output directory"),
 os_flag("spec","path",must_exist=TRUE,help="Replay resolved spec")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
if(!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: only --development-mode execution is available",call.=FALSE)
if (!is.null(a[["study-contract"]])) a[["study-contract-sha256"]] <- os_study_contract_read(a[["study-contract"]])$sha256
if(dir.exists(a$outdir) && length(list.files(a$outdir,all.files=TRUE,no..=TRUE))) ex_stop("output directory must be empty")
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);set.seed(a$seed)
elog <- os_engine_log_new(a$outdir)
source(file.path(.shared,"fig_all.R"))
up <- NULL
up <- read_handoff(a[["from-run"]],expect=list(model="development_lmerMod",metadata="development_model_metadata"),contract_hash=a[["study-contract-sha256"]])
os_handoff_assert_inference_ready(up)
res <- os_engine_capture(emmeans_contrast_compute(a,up),"compute",elog)
os_engine_capture(ex_write(res,a,"emmeans-contrast",basename(.this),SPEC,up),"render",elog)
