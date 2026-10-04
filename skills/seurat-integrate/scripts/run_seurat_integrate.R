options(error=function() { cat(geterrmessage(),file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_seurat_io.R","fig_mod_sc_seurat.R")) source(file.path(.shared,f))
for(f in c("seurat_integrate_core.R","seurat_integrate_report.R","seurat_integrate_qc.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(usage="Rscript run_seurat_integrate.R --input <path> --outdir <dir> [options]", description="seurat-integrate: explicit parameters and verified Seurat chain", flags=list(
os_flag("harmony-project-dim","enum",default="TRUE",values=c("TRUE","FALSE"),help="RunHarmony project.dim: project gene loadings onto corrected PCs"),
os_flag("umap-dens-var-shift","string",help="JSON value for dens.var.shift; omitted uses locked default"),
os_flag("umap-dens-frac","string",help="JSON value for dens.frac; omitted uses locked default"),
os_flag("umap-dens-lambda","string",help="JSON value for dens.lambda; omitted uses locked default"),
os_flag("umap-densmap","string",help="JSON value for densmap; omitted uses locked default"),
os_flag("umap-angular-rp-forest","string",help="JSON value for angular.rp.forest; omitted uses locked default"),
os_flag("umap-metric-kwds","string",help="JSON value for metric.kwds; omitted uses locked default"),
os_flag("umap-uwot-init","string",help="JSON value for uwot.init; omitted uses locked default"),
os_flag("umap-uwot-approx-pow","string",help="JSON value for uwot.approx_pow; omitted uses locked default"),
os_flag("umap-uwot-sgd","string",help="JSON value for uwot.sgd; omitted uses locked default"),
os_flag("umap-b","string",help="JSON value for b; omitted uses locked default"),
os_flag("umap-a","string",help="JSON value for a; omitted uses locked default"),
os_flag("umap-negative-sample-rate","string",help="JSON value for negative.sample.rate; omitted uses locked default"),
os_flag("umap-repulsion-strength","string",help="JSON value for repulsion.strength; omitted uses locked default"),
os_flag("umap-local-connectivity","string",help="JSON value for local.connectivity; omitted uses locked default"),
os_flag("umap-set-op-mix-ratio","string",help="JSON value for set.op.mix.ratio; omitted uses locked default"),
os_flag("umap-spread","string",help="JSON value for spread; omitted uses locked default"),
os_flag("umap-learning-rate","string",help="JSON value for learning.rate; omitted uses locked default"),
os_flag("umap-n-epochs","string",help="JSON value for n.epochs; omitted uses locked default"),
os_flag("umap-metric","string",help="JSON value for metric; omitted uses locked default"),
os_flag("umap-n-components","string",help="JSON value for n.components; omitted uses locked default"),
os_flag("umap-umap-method","string",help="JSON value for umap.method; omitted uses locked default"),
os_flag("cluster-group-singletons","string",help="JSON value for group.singletons; omitted uses locked default"),
os_flag("cluster-n-iter","string",help="JSON value for n.iter; omitted uses locked default"),
os_flag("cluster-n-start","string",help="JSON value for n.start; omitted uses locked default"),
os_flag("cluster-leiden-objective-function","string",help="JSON value for leiden_objective_function; omitted uses locked default"),
os_flag("cluster-leiden-method","string",help="JSON value for leiden_method; omitted uses locked default"),
os_flag("cluster-algorithm","string",help="JSON value for algorithm; omitted uses locked default"),
os_flag("cluster-modularity-fxn","string",help="JSON value for modularity.fxn; omitted uses locked default"),
os_flag("graph-l2-norm","string",help="JSON value for l2.norm; omitted uses locked default"),
os_flag("graph-nn-eps","string",help="JSON value for nn.eps; omitted uses locked default"),
os_flag("graph-annoy-metric","string",help="JSON value for annoy.metric; omitted uses locked default"),
os_flag("graph-n-trees","string",help="JSON value for n.trees; omitted uses locked default"),
os_flag("graph-nn-method","string",help="JSON value for nn.method; omitted uses locked default"),
os_flag("graph-prune-SNN","string",help="JSON value for prune.SNN; omitted uses locked default"),
os_flag("integrate-epsilon-harmony","string",help="JSON value for epsilon.harmony; omitted uses locked default"),
os_flag("integrate-epsilon-cluster","string",help="JSON value for epsilon.cluster; omitted uses locked default"),
os_flag("integrate-max-iter-cluster","string",help="JSON value for max.iter.cluster; omitted uses locked default"),
os_flag("integrate-block-size","string",help="JSON value for block.size; omitted uses locked default"),
os_flag("integrate-tau","string",help="JSON value for tau; omitted uses locked default"),
os_flag("integrate-nclust","string",help="JSON value for nclust; omitted uses locked default"),
os_flag("integrate-new-reduction","string",help="JSON value for new.reduction; omitted uses locked default"),
os_flag("harmony-ncores","string",help="JSON value for ncores; omitted uses locked default"),
os_flag("harmony-early-stop","string",help="JSON value for early_stop; omitted uses locked default"),
os_flag("harmony-nclust","string",help="JSON value for nclust; omitted uses locked default"),
os_flag("harmony-options-batch-prop-cutoff","string",help="JSON value for batch.prop.cutoff; omitted uses locked default"),
os_flag("harmony-options-epsilon-harmony","string",help="JSON value for epsilon.harmony; omitted uses locked default"),
os_flag("harmony-options-epsilon-cluster","string",help="JSON value for epsilon.cluster; omitted uses locked default"),
os_flag("harmony-options-max-iter-cluster","string",help="JSON value for max.iter.cluster; omitted uses locked default"),
os_flag("harmony-options-block-size","string",help="JSON value for block.size; omitted uses locked default"),
os_flag("harmony-options-tau","string",help="JSON value for tau; omitted uses locked default"),
os_flag("harmony-options-alpha","string",help="JSON value for alpha; omitted uses locked default"),
os_flag("input", "path", help="Raw counts for QC; chain-state Seurat RDS for other modules", must_exist=TRUE),
os_flag("from-run", "path", help="Verified upstream Seurat run directory", must_exist=TRUE),
os_flag("outdir", "path", help="Run output directory", required=TRUE),
os_flag("spec", "path", help="Replay prior provenance/resolved_spec.json", must_exist=TRUE),
os_flag("seed", "int", help="Recorded RNG seed", default=20260925),
os_flag("journal", "enum", help="Figure preset", default="nature", values=c("nature","cell","science","generic")),
os_flag("method", "enum", help="Explicit integration method", required=TRUE, values=c("RunHarmony","HarmonyIntegration")),
os_flag("batch-col", "string", help="Metadata batch covariate", required=TRUE),
os_flag("dims", "int", help="Prespecified number of input PCs", required=TRUE, range=c(2,1000)),
os_flag("neighbors", "int", help="Prespecified graph or UMAP neighbor count", required=TRUE, range=c(2,100000)),
os_flag("umap-neighbors", "int", help="Prespecified graph or UMAP neighbor count", required=TRUE, range=c(2,100000)),
os_flag("resolution", "num", help="Prespecified resolution on corrected reduction", required=TRUE, range=c(0.0001,100)),
os_flag("sigma", "num", help="Harmony soft clustering width", default=0.1, range=c(0.000001,100)),
os_flag("theta", "num", help="Optional Harmony diversity penalty; absent uses API NULL", range=c(0,100)),
os_flag("lambda", "num", help="Optional Harmony ridge penalty; absent uses API NULL", range=c(0.000001,100)),
os_flag("max-iter", "int", help="Harmony maximum integration iterations", default=10, range=c(1,1000)),
os_flag("min-dist", "num", help="UMAP minimum distance", default=0.3, range=c(0,1))), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC,os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
if(is.null(a$input) && is.null(a[["from-run"]])) os_seurat_fail("OS_MISSING_PARAMETER","Supply --input or --from-run.")
canon <- os_canonical_argv(SPEC,a)
set.seed(a$seed)
options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
outdir <- normalizePath(a$outdir,winslash="/")
elog <- os_engine_log_new(outdir)
inp <- os_engine_capture(os_seurat_read(a$input,a[["from-run"]],"integrate"),"input",elog)
r <- os_engine_capture(seurat_integrate_compute(inp$object,a),"compute",elog)
paths <- os_engine_capture(seurat_integrate_render(r,a,outdir),"render",elog)
qc <- os_engine_capture(seurat_integrate_qc(r,a,elog),"qc",elog)
os_engine_capture({
 os_write_qc_results(qc,outdir)
 os_seurat_report(r,a,outdir,"seurat-integrate",.module_dir)
 os_seurat_save(r,a,outdir,"seurat-integrate",inp$upstream,paths)
 input_paths <- list(input=inp$path)
 for(nm in c("metadata","gene-sets","pool")) if(!is.null(a[[nm]])) input_paths[[nm]] <- a[[nm]]
 # A 10x directory has separate canonical file hashes, never hash a directory.
 if(dir.exists(inp$path)) { input_paths <- as.list(list.files(inp$path,full.names=TRUE)); names(input_paths) <- basename(unlist(input_paths)) }
 outputs <- c(paste0("tables/",names(paths),".csv"),"qc/qc_results.csv","draft/methods_results.md","objects/seurat.rds","objects/handoff.json","results/results.json")
 os_write_provenance(outdir,"seurat-integrate","1.0.0",canon,basename(.this),a$seed,inputs=input_paths,outputs=outputs,upstream=inp$upstream,extra=list(chain_state=r$state))
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
