options(error = function() { cat(geterrmessage(), file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- file.path(dirname(.module_dir), "_shared", "scripts")
.libPaths(c(file.path(dirname(dirname(.module_dir)), ".omicstat-acceptance"), .libPaths()))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","sc_backend_io.R","fig_all.R","fig_mod_sc_backend.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"cellchat_communication_core.R"))
SPEC <- os_arg_spec(usage="Rscript run_cellchat_communication.R --input FILE|--from-run DIR [options]", description="Official cellchat-communication workflow", flags=c(os_backend_flags(1L),
os_backend_function_flags(CellChat::createCellChat,"create",c("object","meta","group.by")),
os_backend_function_flags(CellChat::subsetDB,"db",c("CellChatDB","search","key")),
os_backend_function_flags(CellChat::subsetData,"subset",c("object")),
os_backend_function_flags(CellChat::identifyOverExpressedGenes,"genes",c("object")),
os_backend_function_flags(CellChat::identifyOverExpressedInteractions,"interactions",c("object")),
os_backend_function_flags(CellChat::computeCommunProb,"prob",c("object")),
os_backend_function_flags(CellChat::filterCommunication,"filter",c("object")),
os_backend_function_flags(CellChat::computeCommunProbPathway,"pathway",c("object")),
os_backend_function_flags(CellChat::aggregateNet,"aggregate",c("object")),
os_backend_function_flags(CellChat::subsetCommunication,"communication",c("object")),
os_backend_function_flags(CellChat::netAnalysis_computeCentrality,"centrality",c("object")),
list(os_flag("db-species","enum",required=TRUE,values=c("human","mouse"),help="Scientific input; see options.md"),
os_flag("db-subset","string",required=TRUE,help="Secreted Signaling | ECM-Receptor | Cell-Cell Contact | Non-protein Signaling | all; explicit database choice"))), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
attr(a,"canonical") <- os_canonical_argv(SPEC,a)
set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_backend_input(a,need="logcounts"), "input", elog)
r <- os_engine_capture(cellchat_communication_compute(inp$sce,a), "compute", elog)
os_backend_finish(r,inp,a,"cellchat-communication",.this)
p <- os_backend_communication_heatmap(r$weight,ncol(r$sce),r$options$aggregateNet$thresh,a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","network_weight"),width="double",journal=a$journal)
p <- os_backend_communication_circle(r$weight,ncol(r$sce),r$options$aggregateNet$thresh,a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","network_circle"),width="double",journal=a$journal)
cat("Completed cellchat-communication; review qc and native objects.\n")
