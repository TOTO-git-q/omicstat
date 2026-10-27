# --refdata-input and --refdata-provenance are mandatory user-supplied resource contracts.
options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]));.shared<-file.path(dirname(dirname(.this)),"..","_shared","scripts")
for(f in c("args.R","engine_run.R","module_kit.R","effect_table.R","handoff.R","model_io.R","refdata_io.R","annotation_io.R","fig_all.R"))source(file.path(.shared,f))
for(f in c("reactomepa_ora_core.R","reactomepa_ora_report.R","reactomepa_ora_qc.R"))source(file.path(dirname(.this),f))
SPEC<-os_arg_spec(usage="Rscript run_reactomepa_ora.R --help",description="Offline SHA-bound Reactome ORA with explicit universe",flags=list(
 os_flag("input", "path", required = TRUE, must_exist = TRUE, help = "Selected Entrez CSV"),
 os_flag("universe", "path", required = TRUE, must_exist = TRUE, help = "Explicit eligible background CSV"),
 os_flag("id-column", "string", required = TRUE, help = "Entrez identifier column"),
 os_flag("selection-rule", "string", required = TRUE, help = "Prespecified selection and assay eligibility"),
 os_flag("organism", "enum", required = TRUE, values = c("human","mouse","rat","celegans","yeast","zebrafish","fly"), help = "Declared resource species"),
 os_flag("universe-policy", "enum", required = TRUE, values = c("strict","annotated-intersection"), help = "Refuse loss or explicitly intersect annotated IDs"),
 os_flag("min-size", "int", required = TRUE, range = c(1,60000), help = "Minimum background-intersected set size"),
 os_flag("max-size", "int", required = TRUE, range = c(1,60000), help = "Maximum background-intersected set size"),
 os_flag("alpha", "num", required = TRUE, range = c(.000000001,1), help = "BH reporting threshold"),
 os_flag("top-n", "int", required = TRUE, range = c(1,50), help = "Display-only number of significant pathways"),
 os_flag("refdata-id", "string", required = TRUE, help = "Registry reference ID"),
 os_flag("refdata-registry", "path", required = TRUE, must_exist = TRUE, help = "Offline registry v2"),
 os_flag("refdata-input", "path", required = TRUE, must_exist = TRUE, help = "Installed-resource snapshot manifest"),
 os_flag("refdata-provenance", "path", required = TRUE, must_exist = TRUE, help = "Caller-supplied licence use and SHA declaration"),
 os_flag("journal", "enum", required = TRUE, values = c("nature","cell","science","generic"), help = "Shared figure journal preset"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Validated prespecified study contract"),
 os_flag("development-mode", "bool", required = FALSE, help = "Explicit candidate run"),
 os_flag("seed", "int", required = TRUE, help = "Recorded deterministic seed"),
 os_flag("outdir", "path", required = TRUE, help = "Empty output directory"),
 os_flag("spec", "path", required = FALSE, must_exist = TRUE, help = "Resolved replay spec")))
a<-os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
if(!isTRUE(a[["development-mode"]]))stop("OS_MODULE_UNSEALED: candidate requires --development-mode",call.=FALSE)
if(dir.exists(a$outdir)&&length(list.files(a$outdir,all.files=TRUE,no..=TRUE)))os_input_stop("output directory must be empty")
set.seed(a$seed);options(omicstat.journal=a$journal);dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);elog<-os_engine_log_new(a$outdir)
res<-os_engine_capture(rpa_compute(a),"compute",elog)
os_engine_capture(os_module_finish(res,a,"reactomepa-ora",basename(.this),SPEC,qc_rows=rpa_qc(res),figures_fn=rpa_render),"render",elog)
