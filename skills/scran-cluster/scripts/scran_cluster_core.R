XC_MODULE <- "scran-cluster"
XC_MODULE_VERSION <- "1.0.0"
scran_cluster_compute <- function(sce, a) {
  qc <- os_bioc_call(scran::quickCluster, a[["quickcluster-args"]], x = sce,
    min.size = a[["quick-min-size"]], method = a[["quick-method"]],
    BPPARAM = BiocParallel::SerialParam(), block.BPPARAM = BiocParallel::SerialParam())
  sce <- os_bioc_call(scran::computeSumFactors, a[["pool-args"]], x = sce, clusters = qc,
    sizes = as.integer(strsplit(a[["pool-sizes"]], ",", fixed = TRUE)[[1]]), BPPARAM = BiocParallel::SerialParam())
  sce <- os_bioc_call(scuttle::logNormCounts, a[["lognorm-args"]], x = sce,
    pseudo.count = a[["pseudo-count"]], BPPARAM = BiocParallel::SerialParam())
  block <- if (is.null(a[["block-col"]])) NULL else os_bioc_column(sce, a[["block-col"]])
  dec <- os_bioc_call(scran::modelGeneVar, a[["variance-args"]], x = sce, block = block, BPPARAM = BiocParallel::SerialParam())
  hvg <- os_bioc_call(scran::getTopHVGs, a[["hvg-args"]], stats = dec, n = a[["n-hvg"]])
  sce <- os_bioc_call(scater::runPCA, a[["pca-args"]], x = sce, subset_row = hvg,
    ncomponents = a[["n-pcs"]], BPPARAM = BiocParallel::SerialParam())
  graph_args <- os_bioc_native_args(a[["graph-args"]])
  ca <- graph_args$cluster.args %||% list()
  if (!is.null(a$resolution)) ca$resolution <- a$resolution
  param <- os_bioc_call(bluster::NNGraphParam, a[["graph-args"]], k = a[["graph-k"]],
    cluster.fun = a[["cluster-method"]], cluster.args = ca, num.threads = 1)
  groups <- bluster::clusterRows(x = SingleCellExperiment::reducedDim(sce, "PCA"), BLUSPARAM = param, full = FALSE)
  SingleCellExperiment::colLabels(sce) <- factor(groups)
  sce$cluster <- factor(groups)
  sce <- os_bioc_call(scater::runUMAP, a[["umap-args"]], x = sce, dimred = "PCA", n_dimred = a[["n-pcs"]],
    n_neighbors = a[["umap-neighbors"]], min_dist = a[["umap-min-dist"]], n_threads = 1, BPPARAM = BiocParallel::SerialParam())
  emb <- SingleCellExperiment::reducedDim(sce, "UMAP")
  cells <- data.frame(cell = colnames(sce), cluster = as.character(groups),
    size_factor = SingleCellExperiment::sizeFactors(sce), quick_cluster = as.character(qc), x = emb[, 1], y = emb[, 2])
  if (!is.null(a[["sample-col"]])) cells$sample <- as.character(os_bioc_column(sce, a[["sample-col"]]))
  if (!is.null(a[["batch-col"]])) cells$batch <- as.character(os_bioc_column(sce, a[["batch-col"]]))
  v <- as.data.frame(dec); v$gene <- rownames(dec)
  pv <- attr(SingleCellExperiment::reducedDim(sce, "PCA"), "varExplained")
  list(sce = sce, cells = cells, variance = v, hvgs = data.frame(gene = hvg),
    pca_variance = data.frame(PC = seq_along(pv), variance = pv),
    state = list(qc_complete = TRUE, normalized = TRUE, normalization = "scran pooling + scuttle logNormCounts",
      clustered = TRUE, cluster_col = "cluster", n_pcs = a[["n-pcs"]], n_hvg = length(hvg), seed = a$seed))
}
