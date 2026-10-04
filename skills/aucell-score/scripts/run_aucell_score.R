options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite,"skills/_shared/scripts")
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_bioc_io.R","fig_mod_sc_bioc.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"aucell_score_core.R"))
SPEC <- os_arg_spec(usage="aucell-score --help",description="Official community workflow wrapper",flags=list(
os_flag("input","path", must_exist=TRUE,help="local SCE RDS"),
os_flag("from-run","path", must_exist=TRUE,help="upstream single-cell run"),
os_flag("outdir","path",required=TRUE,help="output directory"),
os_flag("spec","path", must_exist=TRUE,help="resolved spec replay"),
os_flag("cluster-col","string",required=TRUE,help="group metadata for score distributions; scientific grouping choice"),
os_flag("assay","enum",values=c("counts","logcounts"),required=TRUE,help="expression assay counts or logcounts; rankings are monotonic-transform invariant except ties"),
os_flag("sets-file","path",required=TRUE,must_exist=TRUE,help="user-supplied offline GMT; gene identifiers must match"),
os_flag("sets-source","string",required=TRUE,help="gene-set source accession/version or user derivation"),
os_flag("sets-licence","string",required=TRUE,help="gene-set licence or user permission declaration"),
os_flag("accept-licence","enum",required=TRUE,values=c("user-permitted"),help="acknowledge permission for this offline gene-set file"),
os_flag("auc-max-rank","int",help="rank window; native default ceiling(0.05 * genes); check detected-gene distribution"),
os_flag("norm-auc","enum",values=c("TRUE","FALSE"),default="TRUE",help="native AUC normalization"),
os_flag("keep-zeroes-as-na","enum",values=c("TRUE","FALSE"),default="FALSE",help="native zero handling"),
os_flag("split-by-blocks","enum",values=c("TRUE","FALSE"),default="FALSE",help="native blocked ranking"),
os_flag("counts-layer","string",help="required counts source layer for conversion"),
os_flag("logcounts-layer","string",help="required normalized source layer for conversion"),
os_flag("source-assay","string",help="Seurat source assay for explicit conversion"),
os_flag("ranking-args","path", must_exist=TRUE,help="supplementary native ranking arguments"),
os_flag("auc-args","path", must_exist=TRUE,help="supplementary native AUC arguments"),
os_flag("seed","int",default=333,help="explicit random seed"),
os_flag("journal","enum",default="nature", values=c("nature","cell","science","generic"),help="figure preset")),exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
a[["norm-auc"]]<-identical(a[["norm-auc"]],"TRUE");a[["keep-zeroes-as-na"]]<-identical(a[["keep-zeroes-as-na"]],"TRUE");a[["split-by-blocks"]]<-identical(a[["split-by-blocks"]],"TRUE");set.seed(a$seed);options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);elog<-os_engine_log_new(a$outdir)
i<-os_engine_capture(os_bioc_input(a,"aucell-score",scoring=TRUE),"input",elog)
r<-os_engine_capture(aucell_score_compute(i$sce,a),"compute",elog)
for(k in c("scores","sets_table"))os_bioc_table(r[[k]],a$outdir,k)
os_bioc_table(r$long,a$outdir,"score_distributions")
dir.create(file.path(a$outdir,"objects"),recursive=TRUE,showWarnings=FALSE)
saveRDS(r$rankings,file.path(a$outdir,"objects/rankings.rds"));saveRDS(r$auc,file.path(a$outdir,"objects/aucell.rds"))
os_engine_capture({
 p<-os_bioc_auc_violin(r$long,r$maxrank,a$journal)
 os_finalize_figure(p,file.path(a$outdir,"figures/auc_distributions"),journal=a$journal,root=a$outdir)
 p<-os_bioc_auc_heatmap(r$means,ncol(r$sce),r$maxrank,a$journal)
 os_finalize_figure(p,file.path(a$outdir,"figures/auc_heatmap"),journal=a$journal,root=a$outdir)
},"figures",elog)
os_bioc_methods(a,"aucell-score",c("AUCell","GSEABase"),c("getGmt","AUCell_buildRankings","AUCell_calcAUC"))
r$colours<-os_colours_for(sort(unique(r$long$cluster)),family="cluster",registry=i$colours)$registry
os_bioc_write(r,i,a,"aucell-score","1.0.0")
os_write_provenance(a$outdir,"aucell-score","1.0.0",os_canonical_argv(SPEC,a),basename(.this),a$seed,inputs=os_bioc_provenance_inputs(i,a),outputs=c("objects/sce.rds"),upstream=i$upstream,extra=list(state=r$state,conversion=i$conversion,native_args=os_bioc_resolved_native(a),gene_sets=r$state$gene_sets))
cat("aucell-score complete; inspect tables and qc/engine_warnings.csv.\n")
