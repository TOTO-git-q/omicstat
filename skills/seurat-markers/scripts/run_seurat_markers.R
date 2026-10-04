options(error=function() { cat(geterrmessage(),file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_seurat_io.R","fig_mod_sc_seurat.R")) source(file.path(.shared,f))
for(f in c("seurat_markers_core.R","seurat_markers_report.R","seurat_markers_qc.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(usage="Rscript run_seurat_markers.R --input <path> --outdir <dir> [options]", description="seurat-markers: explicit parameters and verified Seurat chain", flags=list(
os_flag("markers-mean-fxn","string",help="Native mean.fxn as package::function; omitted uses NULL"),
os_flag("features","string",help="JSON native marker control; omitted uses NULL"),
os_flag("group-by","string",help="JSON native marker control; omitted uses NULL"),
os_flag("node","string",help="JSON native marker control; omitted uses NULL"),
os_flag("slot","string",help="JSON native marker control; omitted uses 'data'"),
os_flag("fc-name","string",help="JSON native marker control; omitted uses NULL"),
os_flag("subset-ident","string",help="JSON native marker control; omitted uses NULL"),
os_flag("fc-slot","string",help="JSON native marker control; omitted uses 'data'"),
os_flag("pseudocount-use","string",help="JSON native marker control; omitted uses 1"),
os_flag("recorrect-umi","string",help="JSON native marker control; omitted uses TRUE"),
os_flag("contrast-densify","string",help="JSON value for densify; omitted uses locked default"),
os_flag("contrast-min-cells-group","string",help="JSON value for min.cells.group; omitted uses locked default"),
os_flag("contrast-min-cells-feature","string",help="JSON value for min.cells.feature; omitted uses locked default"),
os_flag("contrast-max-cells-per-ident","string",help="JSON value for max.cells.per.ident; omitted uses locked default"),
os_flag("contrast-min-diff-pct","string",help="JSON value for min.diff.pct; omitted uses locked default"),
os_flag("contrast-only-pos","string",help="JSON value for only.pos; omitted uses locked default"),
os_flag("contrast-latent-vars","string",help="JSON value for latent.vars; omitted uses locked default"),
os_flag("markers-densify","string",help="JSON value for densify; omitted uses locked default"),
os_flag("markers-base","string",help="JSON value for base; omitted uses locked default"),
os_flag("markers-min-cells-group","string",help="JSON value for min.cells.group; omitted uses locked default"),
os_flag("markers-min-cells-feature","string",help="JSON value for min.cells.feature; omitted uses locked default"),
os_flag("markers-latent-vars","string",help="JSON value for latent.vars; omitted uses locked default"),
os_flag("markers-max-cells-per-ident","string",help="JSON value for max.cells.per.ident; omitted uses locked default"),
os_flag("markers-only-pos","string",help="JSON value for only.pos; omitted uses locked default"),
os_flag("markers-min-diff-pct","string",help="JSON value for min.diff.pct; omitted uses locked default"),
os_flag("input", "path", help="Raw counts for QC; chain-state Seurat RDS for other modules", must_exist=TRUE),
os_flag("from-run", "path", help="Verified upstream Seurat run directory", must_exist=TRUE),
os_flag("outdir", "path", help="Run output directory", required=TRUE),
os_flag("spec", "path", help="Replay prior provenance/resolved_spec.json", must_exist=TRUE),
os_flag("seed", "int", help="Recorded RNG seed", default=20260925),
os_flag("journal", "enum", help="Figure preset", default="nature", values=c("nature","cell","science","generic")),
os_flag("mode", "enum", help="All cluster markers or specified identity contrast", default="all", values=c("all","contrast")),
os_flag("ident-1", "string", help="Identity numerator for contrast mode"),
os_flag("ident-2", "string", help="Identity denominator; absent compares all other cells"),
os_flag("min-pct", "num", help="Minimum expression fraction screening", default=0.01, range=c(0,1)),
os_flag("logfc-threshold", "num", help="Pretest screening threshold in log2 units; not a minimum effect test", default=0.1, range=c(0,100)),
os_flag("only-pos", "enum", help="Return positive markers only; official PBMC vignette TRUE", default="true", values=c("true","false")),
os_flag("test", "enum", help="Native marker statistical test", default="wilcox", values=c("wilcox","wilcox_limma","bimod","roc","t","negbinom","poisson","LR","MAST","DESeq2")),
os_flag("assay", "string", help="Optional marker assay override; absent uses upstream assay"),
os_flag("return-thresh", "num", help="FindAllMarkers raw P return threshold", default=0.01, range=c(0,1)),
os_flag("display-lfc-filter", "num", help="Separate display-only absolute log2FC filter", default=0, range=c(0,100)),
os_flag("top-n", "int", help="Genes in descriptive marker figures", default=10, range=c(1,50)),
os_flag("condition", "string", help="Condition inference request; refused as pseudoreplication")), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
if(is.null(a$input) && is.null(a[["from-run"]])) os_seurat_fail("OS_MISSING_PARAMETER","Supply --input or --from-run.")
if(!is.null(a$condition)) os_seurat_fail("OS_PSEUDOREPLICATION","Condition inference requires replicate-aware muscat-pseudobulk.")
canon <- os_canonical_argv(SPEC,a)
set.seed(a$seed)
options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
outdir <- normalizePath(a$outdir,winslash="/")
elog <- os_engine_log_new(outdir)
inp <- os_engine_capture(os_seurat_read(a$input,a[["from-run"]],"markers"),"input",elog)
r <- os_engine_capture(seurat_markers_compute(inp$object,a),"compute",elog)
paths <- os_engine_capture(seurat_markers_render(r,a,outdir),"render",elog)
qc <- os_engine_capture(seurat_markers_qc(r,a,elog),"qc",elog)
os_engine_capture({
 os_write_qc_results(qc,outdir)
 seurat_markers_report(r,a,outdir,"seurat-markers",.module_dir)
 os_seurat_save(r,a,outdir,"seurat-markers",inp$upstream,paths)
 input_paths <- list(input=inp$path)
 for(nm in c("metadata","gene-sets","pool")) if(!is.null(a[[nm]])) input_paths[[nm]] <- a[[nm]]
 # A 10x directory has separate canonical file hashes, never hash a directory.
 if(dir.exists(inp$path)) { input_paths <- as.list(list.files(inp$path,full.names=TRUE)); names(input_paths) <- basename(unlist(input_paths)) }
 outputs <- c(paste0("tables/",names(paths),".csv"),"qc/qc_results.csv","draft/methods_results.md","objects/seurat.rds","objects/handoff.json","results/results.json")
 os_write_provenance(outdir,"seurat-markers","1.0.0",canon,basename(.this),a$seed,inputs=input_paths,outputs=outputs,upstream=inp$upstream,extra=list(chain_state=r$state))
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
