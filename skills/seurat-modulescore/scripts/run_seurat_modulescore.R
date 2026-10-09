options(error=function() { cat(geterrmessage(),file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_seurat_io.R","fig_mod_sc_seurat.R","user_genesets.R")) source(file.path(.shared,f))
for(f in c("seurat_modulescore_core.R","seurat_modulescore_report.R","seurat_modulescore_qc.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(usage="Rscript run_seurat_modulescore.R --input <path> --outdir <dir> [options]", description="seurat-modulescore: explicit parameters and verified Seurat chain", flags=c(list(
os_flag("assay","string",help="Assay; omitted uses the normalized upstream assay"),
os_flag("slot","enum",default="data",values=c("data","counts","scale.data"),help="Native expression slot for scoring"),
os_flag("name","string",default="Cluster",help="Native score column prefix; numeric suffixes follow GMT row order"),
os_flag("k","enum",default="false",values=c("false","true"),help="Use native DoKMeans feature clusters; true needs kmeans-object"),
os_flag("kmeans-object","path",must_exist=TRUE,help="Native DoKMeans RDS; used only with k true"),
os_flag("input", "path", help="Raw counts for QC; chain-state Seurat RDS for other modules", must_exist=TRUE),
os_flag("from-run", "path", help="Verified upstream Seurat run directory", must_exist=TRUE),
os_flag("outdir", "path", help="Run output directory", required=TRUE),
os_flag("spec", "path", help="Replay prior provenance/resolved_spec.json", must_exist=TRUE),
os_flag("seed", "int", help="Recorded RNG seed", default=20260925),
os_flag("journal", "enum", help="Figure preset", default="nature", values=c("nature","cell","science","generic")),
os_flag("gene-sets", "path", help="Offline GMT gene sets with name and source in first two columns", required=TRUE, must_exist=TRUE),
os_flag("set-organism", "string", help="Declared gene-set organism; must match chain", required=TRUE),
os_flag("nbin", "int", help="Expression bins for control pool", default=24, range=c(2,1000)),
os_flag("ctrl", "int", help="Controls per matched feature", default=100, range=c(1,100000)),
os_flag("pool", "path", help="Optional text file with one control-pool gene per line", must_exist=TRUE)),
os_user_geneset_flags(gmt=FALSE,feature_id_type=TRUE)), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
if(is.null(a$input) && is.null(a[["from-run"]])) os_seurat_fail("OS_MISSING_PARAMETER","Supply --input or --from-run.")
canon <- os_canonical_argv(SPEC,a)
set.seed(a$seed)
options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
outdir <- normalizePath(a$outdir,winslash="/")
elog <- os_engine_log_new(outdir)
inp <- os_engine_capture(os_seurat_read(a$input,a[["from-run"]],"modulescore"),"input",elog)
r <- os_engine_capture(seurat_modulescore_compute(inp$object,a),"compute",elog)
paths <- os_engine_capture(seurat_modulescore_render(r,a,outdir),"render",elog)
qc <- os_engine_capture(seurat_modulescore_qc(r,a,elog),"qc",elog)
os_engine_capture({
 os_write_qc_results(qc,outdir)
 os_seurat_report(r,a,outdir,"seurat-modulescore",.module_dir)
 if(!is.null(r$user_gene_sets)) os_user_genesets_draft(file.path(outdir,"draft","methods_results.md"),r$user_gene_sets)
 os_seurat_save(r,a,outdir,"seurat-modulescore",inp$upstream,paths)
 input_paths <- list(input=inp$path)
 for(nm in c("metadata","gene-sets","pool","kmeans-object","gene-sets-provenance")) if(!is.null(a[[nm]])) input_paths[[nm]] <- a[[nm]]
 # A 10x directory has separate canonical file hashes, never hash a directory.
 if(dir.exists(inp$path)) { input_paths <- as.list(list.files(inp$path,full.names=TRUE)); names(input_paths) <- basename(unlist(input_paths)) }
 outputs <- c(paste0("tables/",names(paths),".csv"),"qc/qc_results.csv","draft/methods_results.md","objects/seurat.rds","objects/handoff.json","results/results.json")
 os_write_provenance(outdir,"seurat-modulescore","1.0.0",canon,basename(.this),a$seed,inputs=input_paths,outputs=outputs,upstream=inp$upstream,extra=c(list(chain_state=r$state),if(!is.null(r$user_gene_sets)) list(user_gene_sets=r$user_gene_sets)))
 if(!is.null(r$user_gene_sets)) os_user_genesets_write(outdir,r$user_gene_sets)
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
