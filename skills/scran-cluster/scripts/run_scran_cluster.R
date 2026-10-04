options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite, "skills/_shared/scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "handoff.R", "convert.R", "fig_all.R", "sc_bioc_io.R", "fig_mod_sc_bioc.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "scran_cluster_core.R"))
SPEC <- os_arg_spec(usage = "Rscript run_scran_cluster.R --from-run <qc_run> --n-hvg <n> --n-pcs <n> --graph-k <n> --umap-neighbors <n> --outdir <dir>",
 description = "Official scran pooling, variance/HVG selection, PCA, bluster graph and UMAP workflow.", flags = list(
 os_flag("input", "path", must_exist = TRUE, help = "QC-complete SCE RDS"),
 os_flag("from-run", "path", must_exist = TRUE, help = "scater-qc handoff directory"),
 os_flag("outdir", "path", required = TRUE, help = "output directory"),
 os_flag("spec", "path", must_exist = TRUE, help = "replay resolved spec"),
 os_flag("n-hvg", "int", required = TRUE, range = c(2, 1000000), help = "explicit number of biological HVGs; OSCA examples use 2000"),
 os_flag("n-pcs", "int", required = TRUE, range = c(2, 1000), help = "explicit PCA rank; inspect elbow/variance before selecting"),
 os_flag("graph-k", "int", required = TRUE, range = c(2, 100000), help = "graph neighbours; locked NNGraphParam example/default 10"),
 os_flag("cluster-method", "enum", default = "walktrap", values = c("walktrap", "louvain", "leiden", "infomap", "fast_greedy", "leading_eigen"), help = "bluster graph clustering algorithm"),
 os_flag("resolution", "num", range = c(0, 10000), help = "required explicit resolution for Leiden/Louvain unless supplied in graph-args cluster.args"),
 os_flag("quick-method", "enum", default = "igraph", values = c("igraph", "hclust"), help = "quickCluster preliminary clustering method"),
 os_flag("quick-min-size", "int", default = 100L, range = c(2, 100000), help = "quickCluster minimum cluster size"),
 os_flag("pool-sizes", "string", default = "21,26,31,36,41,46,51,56,61,66,71,76,81,86,91,96,101", help = "comma-separated deconvolution pool sizes"),
 os_flag("pseudo-count", "num", default = 1, range = c(0, 100000), help = "logNormCounts pseudocount"),
 os_flag("block-col", "string", help = "optional variance-model blocking column"),
 os_flag("sample-col", "string", help = "sample annotation for UMAP"),
 os_flag("batch-col", "string", help = "batch annotation for UMAP"),
 os_flag("umap-neighbors", "int", required = TRUE, range = c(2, 100000), help = "UMAP neighbours; locked default/example 15"),
 os_flag("umap-min-dist", "num", default = 0.01, range = c(0, 10), help = "locked uwot minimum distance"),
 os_flag("quickcluster-args", "path", must_exist = TRUE, help = "supplementary quickCluster arguments in named JSON"),
 os_flag("pool-args", "path", must_exist = TRUE, help = "supplementary computeSumFactors arguments in named JSON"),
 os_flag("lognorm-args", "path", must_exist = TRUE, help = "supplementary logNormCounts arguments in named JSON"),
 os_flag("variance-args", "path", must_exist = TRUE, help = "supplementary modelGeneVar arguments in named JSON"),
 os_flag("hvg-args", "path", must_exist = TRUE, help = "supplementary getTopHVGs arguments in named JSON"),
 os_flag("pca-args", "path", must_exist = TRUE, help = "supplementary runPCA arguments in named JSON"),
 os_flag("graph-args", "path", must_exist = TRUE, help = "supplementary NNGraphParam including cluster.args e.g. resolution in named JSON"),
 os_flag("umap-args", "path", must_exist = TRUE, help = "supplementary runUMAP/uwot arguments in named JSON"),
 os_flag("seed", "int", default = 100L, help = "scran vignette explicit seed"),
 os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")), exclusive = list(c("input", "from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (a[["cluster-method"]] %in% c("leiden", "louvain") && is.null(a$resolution) && is.null(os_bioc_native_args(a[["graph-args"]])$cluster.args$resolution)) stop("OS_MISSING_PARAMETER: specify --resolution or graph-args cluster.args.resolution.", call. = FALSE)
set.seed(a$seed); options(omicstat.journal = a$journal)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
i <- os_engine_capture(os_bioc_input(a, XC_MODULE), "input", elog)
r <- os_engine_capture(scran_cluster_compute(i$sce, a), "compute", elog)
for (k in c("cells", "variance", "hvgs", "pca_variance")) os_bioc_table(r[[k]], a$outdir, k)
r$colours <- os_colours_for(sort(unique(r$cells$cluster)), family = "cluster", registry = i$colours)$registry
os_engine_capture({
 for (g in intersect(c("cluster", "sample", "batch"), names(r$cells))) {
  p <- os_bioc_embedding(r$cells, g, sprintf("UMAP of %d cells; n_hvg=%d, n_pcs=%d, graph_k=%d, UMAP neighbours=%d, min_dist=%s, seed=%d; no thresholding.", nrow(r$cells), nrow(r$hvgs), a[["n-pcs"]], a[["graph-k"]], a[["umap-neighbors"]], a[["umap-min-dist"]], a$seed), registry = r$colours, journal = a$journal)
  os_finalize_figure(p, file.path(a$outdir, "figures", paste0("umap_", g)), journal = a$journal, root = a$outdir)
 }
 p <- os_bioc_elbow(r$pca_variance, a[["n-pcs"]], ncol(r$sce), a$journal)
 os_finalize_figure(p, file.path(a$outdir, "figures", "pca_elbow"), journal = a$journal, root = a$outdir)
 r$variance$hvg <- ifelse(r$variance$gene %in% r$hvgs$gene, "selected", "other")
 p <- os_bioc_scatter(r$variance, "mean", "total", "hvg", sprintf("Mean-variance relationship for %d genes in %d cells; top %d HVGs selected; no plotted significance cutoff.", nrow(r$variance), ncol(r$sce), nrow(r$hvgs)), journal = a$journal)
 os_finalize_figure(p, file.path(a$outdir, "figures", "mean_variance"), journal = a$journal, root = a$outdir)
}, "figures", elog)
os_bioc_methods(a, XC_MODULE, c("scran", "scuttle", "scater", "bluster"),
 c("quickCluster", "computeSumFactors", "logNormCounts", "modelGeneVar", "getTopHVGs", "runPCA", "NNGraphParam", "clusterRows", "runUMAP"))
os_bioc_write(r, i, a, XC_MODULE, XC_MODULE_VERSION)
os_write_provenance(a$outdir, XC_MODULE, XC_MODULE_VERSION, os_canonical_argv(SPEC, a), basename(.this), a$seed,
 inputs = os_bioc_provenance_inputs(i, a), outputs = c("tables/cells.csv", "tables/variance.csv", "objects/sce.rds"), upstream = i$upstream,
 extra = list(state = r$state, native_args = os_bioc_resolved_native(a)))
cat("scran-cluster complete; read tables/cells.csv and qc/engine_warnings.csv.\n")
