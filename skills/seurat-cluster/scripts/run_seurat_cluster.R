options(error=function() { cat(geterrmessage(),file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir,"..","_shared","scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","fig_all.R","sc_seurat_io.R","fig_mod_sc_seurat.R")) source(file.path(.shared,f))
for(f in c("seurat_cluster_core.R","seurat_cluster_report.R","seurat_cluster_qc.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(usage="Rscript run_seurat_cluster.R --input <path> --outdir <dir> [options]", description="seurat-cluster: explicit parameters and verified Seurat chain", flags=list(
os_flag("cluster-initial-membership","string",help="Native initial.membership; JSON value, omitted uses NULL"),
os_flag("cluster-node-sizes","string",help="Native node.sizes; JSON value, omitted uses NULL"),
os_flag("hvg-mean-function","string",help="Native mean.function; named native function, omitted uses FastExpMean"),
os_flag("hvg-dispersion-function","string",help="Native dispersion.function; named native function, omitted uses FastLogVMR"),
os_flag("sct-reference-model","path",help="Native reference.SCT.model; RDS model, omitted uses NULL",must_exist=TRUE),
os_flag("sct-residual-features","string",help="Native residual.features; JSON value, omitted uses NULL"),
os_flag("hvg-batch-col","string",help="Optional metadata column for the harmony vignette union of per-batch HVGs"),
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
os_flag("cluster-modularity-fxn","string",help="JSON value for modularity.fxn; omitted uses locked default"),
os_flag("graph-l2-norm","string",help="JSON value for l2.norm; omitted uses locked default"),
os_flag("graph-nn-eps","string",help="JSON value for nn.eps; omitted uses locked default"),
os_flag("graph-annoy-metric","string",help="JSON value for annoy.metric; omitted uses locked default"),
os_flag("graph-n-trees","string",help="JSON value for n.trees; omitted uses locked default"),
os_flag("graph-nn-method","string",help="JSON value for nn.method; omitted uses locked default"),
os_flag("graph-prune-SNN","string",help="JSON value for prune.SNN; omitted uses locked default"),
os_flag("pca-approx","string",help="JSON value for approx; omitted uses locked default"),
os_flag("pca-weight-by-var","string",help="JSON value for weight.by.var; omitted uses locked default"),
os_flag("pca-rev-pca","string",help="JSON value for rev.pca; omitted uses locked default"),
os_flag("sct-return-only-var-genes","string",help="JSON value for return.only.var.genes; omitted uses locked default"),
os_flag("sct-conserve-memory","string",help="JSON value for conserve.memory; omitted uses locked default"),
os_flag("sct-vst-flavor","string",help="JSON value for vst.flavor; omitted uses locked default"),
os_flag("sct-clip-range","string",help="JSON value for clip.range; omitted uses locked default"),
os_flag("sct-do-center","string",help="JSON value for do.center; omitted uses locked default"),
os_flag("sct-do-scale","string",help="JSON value for do.scale; omitted uses locked default"),
os_flag("sct-vars-to-regress","string",help="JSON value for vars.to.regress; omitted uses locked default"),
os_flag("sct-variable-features-rv-th","string",help="JSON value for variable.features.rv.th; omitted uses locked default"),
os_flag("sct-ncells","string",help="JSON value for ncells; omitted uses locked default"),
os_flag("sct-do-correct-umi","string",help="JSON value for do.correct.umi; omitted uses locked default"),
os_flag("scale-min-cells-to-block","string",help="JSON value for min.cells.to.block; omitted uses locked default"),
os_flag("scale-block-size","string",help="JSON value for block.size; omitted uses locked default"),
os_flag("scale-scale-max","string",help="JSON value for scale.max; omitted uses locked default"),
os_flag("scale-do-center","string",help="JSON value for do.center; omitted uses locked default"),
os_flag("scale-do-scale","string",help="JSON value for do.scale; omitted uses locked default"),
os_flag("scale-use-umi","string",help="JSON value for use.umi; omitted uses locked default"),
os_flag("scale-model-use","string",help="JSON value for model.use; omitted uses locked default"),
os_flag("scale-split-by","string",help="JSON value for split.by; omitted uses locked default"),
os_flag("scale-vars-to-regress","string",help="JSON value for vars.to.regress; omitted uses locked default"),
os_flag("hvg-dispersion-cutoff","string",help="JSON value for dispersion.cutoff; omitted uses locked default"),
os_flag("hvg-mean-cutoff","string",help="JSON value for mean.cutoff; omitted uses locked default"),
os_flag("hvg-binning-method","string",help="JSON value for binning.method; omitted uses locked default"),
os_flag("hvg-num-bin","string",help="JSON value for num.bin; omitted uses locked default"),
os_flag("hvg-clip-max","string",help="JSON value for clip.max; omitted uses locked default"),
os_flag("hvg-loess-span","string",help="JSON value for loess.span; omitted uses locked default"),
os_flag("hvg-selection-method","string",help="JSON value for selection.method; omitted uses locked default"),
os_flag("normalize-margin","string",help="JSON value for margin; omitted uses locked default"),
os_flag("normalize-normalization-method","string",help="JSON value for normalization.method; omitted uses locked default"),
os_flag("input", "path", help="Raw counts for QC; chain-state Seurat RDS for other modules", must_exist=TRUE),
os_flag("from-run", "path", help="Verified upstream Seurat run directory", must_exist=TRUE),
os_flag("outdir", "path", help="Run output directory", required=TRUE),
os_flag("spec", "path", help="Replay prior provenance/resolved_spec.json", must_exist=TRUE),
os_flag("seed", "int", help="Recorded RNG seed", default=20260925),
os_flag("journal", "enum", help="Figure preset", default="nature", values=c("nature","cell","science","generic")),
os_flag("normalization", "enum", help="Required normalization route", required=TRUE, values=c("LogNormalize","SCTransform")),
os_flag("n-hvg", "int", help="Prespecified feature or dimension or neighbor count", required=TRUE, range=c(2,100000)),
os_flag("n-pcs", "int", help="Prespecified feature or dimension or neighbor count", required=TRUE, range=c(2,100000)),
os_flag("dims", "int", help="Prespecified feature or dimension or neighbor count", required=TRUE, range=c(2,100000)),
os_flag("neighbors", "int", help="Prespecified feature or dimension or neighbor count", required=TRUE, range=c(2,100000)),
os_flag("umap-neighbors", "int", help="Prespecified feature or dimension or neighbor count", required=TRUE, range=c(2,100000)),
os_flag("resolution", "num", help="Prespecified clustering resolution", required=TRUE, range=c(0.0001,100)),
os_flag("scale-factor", "num", help="LogNormalize library scale factor", default=10000, range=c(1,1e9)),
os_flag("algorithm", "int", help="Clustering algorithm: Louvain 1, refined 2, SLM 3, Leiden 4", default=1, range=c(1,4)),
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
inp <- os_engine_capture(os_seurat_read(a$input,a[["from-run"]],"cluster"),"input",elog)
r <- os_engine_capture(seurat_cluster_compute(inp$object,a),"compute",elog)
paths <- os_engine_capture(seurat_cluster_render(r,a,outdir),"render",elog)
qc <- os_engine_capture(seurat_cluster_qc(r,a,elog),"qc",elog)
os_engine_capture({
 os_write_qc_results(qc,outdir)
 os_seurat_report(r,a,outdir,"seurat-cluster",.module_dir)
 os_seurat_save(r,a,outdir,"seurat-cluster",inp$upstream,paths)
 input_paths <- list(input=inp$path)
 for(nm in c("metadata","gene-sets","pool","sct-reference-model")) if(!is.null(a[[nm]])) input_paths[[nm]] <- a[[nm]]
 # A 10x directory has separate canonical file hashes, never hash a directory.
 if(dir.exists(inp$path)) { input_paths <- as.list(list.files(inp$path,full.names=TRUE)); names(input_paths) <- basename(unlist(input_paths)) }
 outputs <- c(paste0("tables/",names(paths),".csv"),"qc/qc_results.csv","draft/methods_results.md","objects/seurat.rds","objects/handoff.json","results/results.json")
 os_write_provenance(outdir,"seurat-cluster","1.0.0",canon,basename(.this),a$seed,inputs=input_paths,outputs=outputs,upstream=inp$upstream,extra=list(chain_state=r$state))
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
