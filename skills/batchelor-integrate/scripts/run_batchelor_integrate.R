options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite,"skills/_shared/scripts")
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_bioc_io.R","fig_mod_sc_bioc.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"batchelor_integrate_core.R"))
SPEC <- os_arg_spec(usage="batchelor-integrate --help",description="Official community workflow wrapper",flags=list(
os_flag("input","path", must_exist=TRUE,help="local SCE RDS"),
os_flag("from-run","path", must_exist=TRUE,help="upstream single-cell run"),
os_flag("outdir","path",required=TRUE,help="output directory"),
os_flag("spec","path", must_exist=TRUE,help="resolved spec replay"),
os_flag("batch-col","string",required=TRUE,help="batch metadata column; scientific batch definition"),
os_flag("n-hvg","int",required=TRUE,help="HVG number; correction vignette example 5000"),
os_flag("n-pcs","int",required=TRUE,help="fastMNN rank; locked default 50, explicit study choice"),
os_flag("mnn-k","int",required=TRUE,help="MNN neighbours; locked default 20"),
os_flag("umap-dims","int",required=TRUE,help="corrected dimensions for UMAP"),
os_flag("umap-neighbors","int",required=TRUE,help="UMAP neighbours; locked default 15"),
os_flag("mixing-k","int",required=TRUE,help="neighbours for descriptive batch purity"),
os_flag("label-col","string",help="optional biological annotation"),
os_flag("cos-norm","enum",values=c("TRUE","FALSE"),default="TRUE",help="cosine normalization"),
os_flag("ndist","num",default=3,help="MNN distance cutoff"),
os_flag("auto-merge","enum",values=c("TRUE","FALSE"),default="FALSE",help="automatically select merge order"),
os_flag("umap-min-dist","num",default=0.01,help="uwot locked minimum distance"),
os_flag("norm-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("variance-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("combine-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("hvg-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("mnn-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("pca-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("umap-args","path", must_exist=TRUE,help="supplementary native named JSON options; omitted arguments retain locked defaults"),
os_flag("seed","int",default=101,help="explicit random seed"),
os_flag("journal","enum",default="nature", values=c("nature","cell","science","generic"),help="figure preset")),exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(TRUE)))
if(isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
a[["cos-norm"]]<-identical(a[["cos-norm"]],"TRUE");a[["auto-merge"]]<-identical(a[["auto-merge"]],"TRUE");set.seed(a$seed);options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE);elog<-os_engine_log_new(a$outdir)
i<-os_engine_capture(os_bioc_input(a,"batchelor-integrate",scoring=FALSE),"input",elog)
r<-os_engine_capture(batchelor_integrate_compute(i$sce,a),"compute",elog)
for(k in c("cells","hvgs","variance","batch_summary")) os_bioc_table(r[[k]],a$outdir,k)
dir.create(file.path(a$outdir,"objects"),recursive=TRUE,showWarnings=FALSE)
saveRDS(r$native,file.path(a$outdir,"objects/fastmnn.rds"));saveRDS(r$normalized,file.path(a$outdir,"objects/multibatch_normalized.rds"))
os_engine_capture({
 for(stage in c("before","after")) for(g in intersect(c("batch","label"),names(r$cells))){
  z<-r$cells;if(stage=="before"){z$x<-z$pre_x;z$y<-z$pre_y}
  p<-os_bioc_embedding(z,g,sprintf("%s fastMNN: %d cells; %d HVGs, d=%d, k=%d; UMAP dimensions=%d, neighbours=%d; seed=%d. No cell filtering or activity threshold.",stage,nrow(z),nrow(r$hvgs),a[["n-pcs"]],a[["mnn-k"]],if(stage=="before") a[["n-pcs"]] else a[["umap-dims"]],a[["umap-neighbors"]],a$seed),journal=a$journal)
  os_finalize_figure(p,file.path(a$outdir,"figures",paste(stage,g,sep="_")),journal=a$journal,root=a$outdir)
 }
},"figures",elog)
os_bioc_methods(a,"batchelor-integrate",c("batchelor","scran","scater","bluster"),c("multiBatchNorm","modelGeneVar","combineVar","getTopHVGs","fastMNN","runPCA","runUMAP","neighborPurity"))
r$colours<-os_colours_for(sort(unique(r$cells$batch)),family="batch",registry=i$colours)$registry
os_bioc_write(r,i,a,"batchelor-integrate","1.0.0")
os_write_provenance(a$outdir,"batchelor-integrate","1.0.0",os_canonical_argv(SPEC,a),basename(.this),a$seed,inputs=os_bioc_provenance_inputs(i,a),outputs=c("objects/sce.rds"),upstream=i$upstream,extra=list(state=r$state,conversion=i$conversion,native_args=os_bioc_resolved_native(a)))
cat("batchelor-integrate complete; inspect tables and qc/engine_warnings.csv.\n")
