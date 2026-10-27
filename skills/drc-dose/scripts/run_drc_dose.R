# Development-only module; numerical validation and sealing remain pending.
options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module <- dirname(dirname(.this));.shared <- file.path(.module,"..","_shared","scripts")
for (f in c("args.R","engine_run.R","module_kit.R","effect_table.R","handoff.R")) source(file.path(.shared,f))
source(file.path(.shared,"candidate_model.R"))
source(file.path(dirname(.this),"drc_dose_core.R"))
SPEC <- os_arg_spec(usage="Rscript run_drc_dose.R --help",description="Unsealed development implementation of drc-dose",flags=list(
 os_flag("input","path",required=TRUE,must_exist=TRUE,help="Independent-unit response CSV"),
 os_flag("response","string",required=TRUE,help="Continuous response column"),
 os_flag("dose","string",required=TRUE,help="Untransformed nonnegative dose column"),
 os_flag("unit","string",required=TRUE,help="Unique biological-unit column"),
 os_flag("dose-unit","string",required=TRUE,help="Dose measurement unit"),
 os_flag("model","enum",required=TRUE,values=c("LL3","LL4"),help="Prespecified log-logistic model"),
 os_flag("response-levels","string",required=TRUE,help="Comma-separated ED levels"),
 os_flag("response-type","enum",required=TRUE,values=c("relative","absolute"),help="Response level interpretation"),
 os_flag("reference","enum",required=TRUE,values=c("control","upper"),help="ED reference"),
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
res <- os_engine_capture(drc_dose_compute(a),"compute",elog)
os_engine_capture(ex_write(res,a,"drc-dose",basename(.this),SPEC,up),"render",elog)
