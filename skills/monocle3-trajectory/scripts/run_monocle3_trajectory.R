options(error = function() { cat(geterrmessage(), file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- file.path(dirname(.module_dir), "_shared", "scripts")
.libPaths(c(file.path(dirname(dirname(.module_dir)), ".omicstat-acceptance"), .libPaths()))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","sc_backend_io.R","fig_all.R","fig_mod_sc_backend.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"monocle3_trajectory_core.R"))
SPEC <- os_arg_spec(usage="Rscript run_monocle3_trajectory.R --input FILE|--from-run DIR [options]", description="Official monocle3-trajectory workflow", flags=c(os_backend_flags(),
os_backend_function_flags(monocle3::new_cell_data_set,"cds",c("expression_data","cell_metadata","gene_metadata")),
os_backend_function_flags(monocle3::learn_graph,"learn",c("cds")),
os_backend_function_flags(monocle3::order_cells,"order",c("cds")),
os_backend_function_flags(monocle3::graph_test,"test",c("cds")),
list(os_flag("partition-col","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("root-time-col","string",help="Scientific input; see options.md"),
os_flag("root-time-value","string",help="Scientific input; see options.md"),
os_flag("root-rationale","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("graph-genes-file","path",help="Optional explicit gene IDs (one per line); all genes otherwise"))), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
attr(a,"canonical") <- os_canonical_argv(SPEC,a)
set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_backend_input(a,need="counts"), "input", elog)
r <- os_engine_capture(monocle3_trajectory_compute(inp$sce,a), "compute", elog)
os_backend_finish(r,inp,a,"monocle3-trajectory",.this)
p <- os_backend_trajectory(r$embedding,r$pseudotime,r$curves,"UMAP",a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","trajectory"),width="double",journal=a$journal)
cat("Completed monocle3-trajectory; review qc and native objects.\n")
