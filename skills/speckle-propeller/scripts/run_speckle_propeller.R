options(error = function() { cat(geterrmessage(), file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- file.path(dirname(.module_dir), "_shared", "scripts")
.libPaths(c(file.path(dirname(dirname(.module_dir)), ".omicstat-acceptance"), .libPaths()))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","sc_backend_io.R","fig_all.R","fig_mod_sc_backend.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"speckle_propeller_core.R"))
SPEC <- os_arg_spec(usage="Rscript run_speckle_propeller.R --input FILE|--from-run DIR [options]", description="Official speckle-propeller workflow", flags=c(os_backend_flags(),
os_backend_function_flags(speckle::propeller,"prop",c("x","clusters","sample","group")),
os_backend_function_flags(speckle::getTransformedProps,"props",c("clusters","sample")),
list(os_flag("sample-col","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("condition-col","string",required=TRUE,help="Scientific input; see options.md"))), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
attr(a,"canonical") <- os_canonical_argv(SPEC,a)
set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_backend_input(a,need="counts"), "input", elog)
r <- os_engine_capture(speckle_propeller_compute(inp$sce,a), "compute", elog)
os_backend_finish(r,inp,a,"speckle-propeller",.this)
pd <- os_backend_proportions(r$sce,a[["cluster-col"]],a[["sample-col"]],a[["condition-col"]])
p <- os_proportion_bar(pd,journal=a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","proportions"),width="double",journal=a$journal)
cat("Completed speckle-propeller; review qc and native objects.\n")
