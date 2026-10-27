# --input-provenance binds the unfiltered counts used as the ambient reference.
options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]));.shared<-file.path(dirname(dirname(.this)),"..","_shared","scripts")
for(f in c("args.R","engine_run.R","module_kit.R","effect_table.R","handoff.R","model_io.R","refdata_io.R","annotation_io.R","fig_all.R"))source(file.path(.shared,f))
for(f in c("dropletutils_emptydrops_core.R","dropletutils_emptydrops_report.R","dropletutils_emptydrops_qc.R"))source(file.path(dirname(.this),f))
SPEC<-os_arg_spec(usage="Rscript run_dropletutils_emptydrops.R --help",description="Annotation-only emptyDrops with explicit lower and FDR",flags=list(
 os_flag("input","path",required=TRUE, must_exist = TRUE,help="Unfiltered raw droplet count matrix"),
 os_flag("format","enum",required=TRUE, values = c("rds","csv"),help="Explicit rds matrix or csv format"),
 os_flag("input-state","enum",required=TRUE, values = c("unfiltered-raw"),help="Unfiltered raw UMI declaration"),
 os_flag("species","string",required=TRUE,help="Declared specimen species"),
 os_flag("refdata-id","string",required=TRUE,help="Registered ambient-input identity"),
 os_flag("refdata-registry","path",required=TRUE, must_exist = TRUE,help="Offline reference registry"),
 os_flag("input-provenance","path",required=TRUE, must_exist = TRUE,help="Raw payload SHA and unfiltered declaration"),
 os_flag("lower","int",required=TRUE, range = c(1,100000000),help="Ambient total-count maximum"),
 os_flag("fdr","num",required=TRUE, range = c(1e-9,.5),help="Nonempty BH FDR threshold"),
 os_flag("niters","int",required=TRUE, range = c(1000,100000),help="Monte Carlo simulations per tested barcode"),
 os_flag("retain","string",required=TRUE,help="Positive explicit total threshold or none; no automatic knee"),
 os_flag("alpha","string",required=TRUE,help="multinomial or estimate or positive DM concentration"),
 os_flag("ignore","int",required=TRUE, range = c(0,100000000),help="Ignore-total threshold"),
 os_flag("test-ambient","enum",required=TRUE, values = c("true","false"),help="Evaluate low-count diagnostic probabilities"),
 os_flag("journal","enum",required=TRUE, values = c("nature","cell","science","generic"),help="Figure preset"),
 os_flag("study-contract","path",must_exist = TRUE,help="Validated study contract"),
 os_flag("development-mode","bool",required=FALSE,help="Explicit candidate run"),
 os_flag("seed","int",required=TRUE, range = c(0,2147483646),help="Reproducible Monte Carlo seed"),
 os_flag("outdir","path",required=TRUE,help="Empty output directory"),
 os_flag("spec","path",required=FALSE, must_exist = TRUE,help="Resolved replay spec")))
a<-os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)));if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
if(!isTRUE(a[["development-mode"]]))stop("OS_MODULE_UNSEALED: candidate requires --development-mode",call.=FALSE)
if(dir.exists(a$outdir)&&length(list.files(a$outdir,all.files=TRUE,no..=TRUE)))stop("OS_OUTPUT_EXISTS: output must be empty",call.=FALSE)
set.seed(a$seed);options(omicstat.journal=a$journal);dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);elog<-os_engine_log_new(a$outdir)
res<-os_engine_capture(ed_compute(a),"compute",elog)
os_engine_capture(os_module_finish(res,a,"dropletutils-emptydrops",basename(.this),SPEC,qc_rows=ed_qc(res),figures_fn=ed_render,objects=list(sce=list(value=res$object,type="SingleCellExperiment"),metadata=list(value=res$metadata,type="development_model_metadata"))),"render",elog)
