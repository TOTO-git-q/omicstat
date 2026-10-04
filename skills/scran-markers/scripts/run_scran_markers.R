options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite,"skills/_shared/scripts")
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_bioc_io.R","fig_mod_sc_bioc.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"scran_markers_core.R"))
SPEC <- os_arg_spec(usage="scran-markers --help",description="Official community workflow wrapper",flags=list(
os_flag("input","path", must_exist=TRUE,help="local SCE RDS"),
os_flag("from-run","path", must_exist=TRUE,help="upstream single-cell run"),
os_flag("outdir","path",required=TRUE,help="output directory"),
os_flag("spec","path", must_exist=TRUE,help="resolved spec replay"),
os_flag("cluster-col","string",required=TRUE,help="cluster metadata; example colLabels in locked Rd"),
os_flag("route","enum",default="scoreMarkers",values=c("scoreMarkers","findMarkers"),help="scoreMarkers effect summaries or compatibility findMarkers"),
os_flag("lfc","num",default=0,help="native effect threshold; no display-only filtering"),
os_flag("block-col","string",help="optional blocking column"),
os_flag("rank-by","string",required=TRUE,help="native ranking column; example mean.AUC for scoreMarkers, FDR for findMarkers"),
os_flag("rank-decreasing","enum",values=c("TRUE","FALSE"),default="TRUE",help="descending effect ranking; set false for P-value/FDR ranking"),
os_flag("top-n","int",required=TRUE,help="display genes per cluster; S0 examples 10 or 100"),
os_flag("test-type","enum",default="t",values=c("t","wilcox","binom"),help="compatibility test t/wilcox/binom"),
os_flag("direction","enum",default="any",values=c("any","up","down"),help="compatibility direction any/up/down"),
os_flag("pval-type","enum",default="any",values=c("any","some","all"),help="compatibility p-value any/some/all"),
os_flag("marker-args","path", must_exist=TRUE,help="supplementary native options including subset.row, pairings and summaries"),
os_flag("seed","int",default=100,help="explicit random seed"),
os_flag("journal","enum",default="nature", values=c("nature","cell","science","generic"),help="figure preset")),exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
a[["rank-decreasing"]]<-identical(a[["rank-decreasing"]],"TRUE");set.seed(a$seed);options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);elog<-os_engine_log_new(a$outdir)
i<-os_engine_capture(os_bioc_input(a,"scran-markers",scoring=FALSE),"input",elog)
r<-os_engine_capture(scran_markers_compute(i$sce,a),"compute",elog)
os_bioc_table(r$markers,a$outdir,"markers");os_bioc_table(r$dot,a$outdir,"marker_plot_data")
dir.create(file.path(a$outdir,"objects"),recursive=TRUE,showWarnings=FALSE);saveRDS(r$native,file.path(a$outdir,"objects/markers.rds"))
for(g in names(r$tables))os_bioc_table(r$tables[[g]],a$outdir,paste0("markers_",make.names(g)))
os_engine_capture({
 p<-os_bioc_dot(r$dot,a[["top-n"]],a[["rank-by"]],ncol(r$sce),a$journal)
 os_finalize_figure(p,file.path(a$outdir,"figures/marker_dotplot"),journal=a$journal,root=a$outdir)
 p<-os_bioc_heatmap(r$means,a[["top-n"]],a[["rank-by"]],ncol(r$sce),a$journal)
 os_finalize_figure(p,file.path(a$outdir,"figures/marker_heatmap"),journal=a$journal,root=a$outdir)
},"figures",elog)
os_bioc_methods(a,"scran-markers",c("scran"),c("scoreMarkers","findMarkers"))
r$colours<-os_colours_for(sort(unique(r$markers$cluster)),family="cluster",registry=i$colours)$registry
os_bioc_write(r,i,a,"scran-markers","1.0.0")
os_write_provenance(a$outdir,"scran-markers","1.0.0",os_canonical_argv(SPEC,a),basename(.this),a$seed,inputs=os_bioc_provenance_inputs(i,a),outputs=c("objects/sce.rds"),upstream=i$upstream,extra=list(state=r$state,conversion=i$conversion,native_args=os_bioc_resolved_native(a)))
cat("scran-markers complete; inspect tables and qc/engine_warnings.csv.\n")
