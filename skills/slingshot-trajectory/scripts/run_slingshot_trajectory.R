options(error = function() { cat(geterrmessage(), file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- file.path(dirname(.module_dir), "_shared", "scripts")
.libPaths(c(file.path(dirname(dirname(.module_dir)), ".omicstat-acceptance"), .libPaths()))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","sc_backend_io.R","fig_all.R","fig_mod_sc_backend.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"slingshot_trajectory_core.R"))
SPEC <- os_arg_spec(usage="Rscript run_slingshot_trajectory.R --input FILE|--from-run DIR [options]", description="Official slingshot-trajectory workflow", flags=c(os_backend_flags(7L),
os_backend_function_flags(os_backend_s4_function("slingshot","slingshot",c("matrix","character")),"sling",c("data","clusterLabels","reducedDim","start.clus")),
os_backend_function_flags(os_backend_s4_function("tradeSeq","fitGAM","matrix"),"gam",c("counts","sds","pseudotime","cellWeights")),
os_backend_function_flags(os_backend_s4_function("tradeSeq","associationTest","SingleCellExperiment"),"association",c("models")),
list(os_flag("trajectory-rds","path",must_exist=TRUE,help="Optional native SlingshotDataSet/PseudotimeOrdering; reuse the official upstream curves"),os_flag("rng-version","string",default="3.5.0",help="tradeSeq vignette RNGversion"),os_flag("reduced-dim","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("start-cluster","string",required=TRUE,help="Observed starting cluster; auto requests the documented unsupervised NULL default"),
os_flag("fit-gam","enum",default="true",values=c("true","false"),help="Scientific input; see options.md"))), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
attr(a,"canonical") <- os_canonical_argv(SPEC,a)
RNGversion(a[["rng-version"]]); set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_backend_input(a,need="counts"), "input", elog)
r <- os_engine_capture(slingshot_trajectory_compute(inp$sce,a), "compute", elog)
os_backend_finish(r,inp,a,"slingshot-trajectory",.this)
p <- os_backend_trajectory(r$embedding,r$pseudotime,r$curves,a[["reduced-dim"]],a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","trajectory"),width="double",journal=a$journal)
cat("Completed slingshot-trajectory; review qc and native objects.\n")
