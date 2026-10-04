options(error=function() { cat(geterrmessage(),file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_seurat_io.R","fig_mod_sc_seurat.R")) source(file.path(.shared,f))
for(f in c("seurat_qc_core.R","seurat_qc_report.R","seurat_qc_qc.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(usage="Rscript run_seurat_qc.R --input <path> --outdir <dir> [options]", description="seurat-qc: explicit parameters and verified Seurat chain", flags=list(
os_flag("missing-mito","enum",help="Policy when input lacks mitochondrial genes; zero is explicit for preselected tutorial matrices",default="error",values=c("error","zero")),
os_flag("create-project","string",help="JSON value for project; omitted uses locked default"),
os_flag("create-names-delim","string",help="JSON value for names.delim; omitted uses locked default"),
os_flag("create-names-field","string",help="JSON value for names.field; omitted uses locked default"),
os_flag("input", "path", help="Raw counts for QC; chain-state Seurat RDS for other modules", must_exist=TRUE),
os_flag("outdir", "path", help="Run output directory", required=TRUE),
os_flag("spec", "path", help="Replay prior provenance/resolved_spec.json", must_exist=TRUE),
os_flag("seed", "int", help="Recorded RNG seed", default=20260925),
os_flag("journal", "enum", help="Figure preset", default="nature", values=c("nature","cell","science","generic")),
os_flag("input-format", "enum", help="Count input format", default="10x", values=c("10x","rds","csv")),
os_flag("metadata", "path", help="Optional cell metadata table with cell and sample columns", must_exist=TRUE),
os_flag("sample", "string", help="Sample name when no metadata is supplied", default="sample"),
os_flag("organism", "string", help="Declared organism", required=TRUE),
os_flag("feature-type", "string", help="Declared feature identifier type", required=TRUE),
os_flag("mito-pattern", "string", help="Regular expression matching mitochondrial genes", required=TRUE),
os_flag("min-cells", "int", help="Explicit count threshold; retention limits are strict except minimum UMI", required=TRUE, range=c(0,1e9)),
os_flag("create-min-features", "int", help="Explicit count threshold; retention limits are strict except minimum UMI", required=TRUE, range=c(0,1e9)),
os_flag("min-features", "int", help="Explicit count threshold; retention limits are strict except minimum UMI", required=TRUE, range=c(0,1e9)),
os_flag("max-features", "int", help="Explicit count threshold; retention limits are strict except minimum UMI", required=TRUE, range=c(0,1e9)),
os_flag("min-counts", "int", help="Explicit count threshold; retention limits are strict except minimum UMI", required=TRUE, range=c(0,1e9)),
os_flag("max-counts", "int", help="Explicit count threshold; retention limits are strict except minimum UMI", required=TRUE, range=c(0,1e9)),
os_flag("max-mito", "num", help="Explicit strict mitochondrial upper limit in percent", required=TRUE, range=c(0,100))))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
if(is.null(a$input)) os_seurat_fail("OS_MISSING_PARAMETER","Supply --input.")
canon <- os_canonical_argv(SPEC,a)
set.seed(a$seed)
options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
outdir <- normalizePath(a$outdir,winslash="/")
elog <- os_engine_log_new(outdir)
inp <- os_engine_capture(list(object=os_seurat_counts(a$input,a[["input-format"]]),upstream=NULL,path=a$input),"input",elog)
r <- os_engine_capture(seurat_qc_compute(inp$object,a),"compute",elog)
paths <- os_engine_capture(seurat_qc_render(r,a,outdir),"render",elog)
qc <- os_engine_capture(seurat_qc_qc(r,a,elog),"qc",elog)
os_engine_capture({
 os_write_qc_results(qc,outdir)
 os_seurat_report(r,a,outdir,"seurat-qc",.module_dir)
 os_seurat_save(r,a,outdir,"seurat-qc",inp$upstream,paths)
 input_paths <- list(input=inp$path)
 for(nm in c("metadata","gene-sets","pool")) if(!is.null(a[[nm]])) input_paths[[nm]] <- a[[nm]]
 # A 10x directory has separate canonical file hashes, never hash a directory.
 if(dir.exists(inp$path)) { input_paths <- as.list(list.files(inp$path,full.names=TRUE)); names(input_paths) <- basename(unlist(input_paths)) }
 outputs <- c(paste0("tables/",names(paths),".csv"),"qc/qc_results.csv","draft/methods_results.md","objects/seurat.rds","objects/handoff.json","results/results.json")
 os_write_provenance(outdir,"seurat-qc","1.0.0",canon,basename(.this),a$seed,inputs=input_paths,outputs=outputs,upstream=inp$upstream,extra=list(chain_state=r$state))
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
