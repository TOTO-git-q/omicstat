BI_MODULE <- "batchelor-integrate"
BI_MODULE_VERSION <- "1.0.0"
batchelor_integrate_compute <- function(sce, a) {
 batch <- factor(os_bioc_column(sce, a[["batch-col"]]))
 if(nlevels(batch)<2) stop("OS_INVALID_INPUT: at least two batches required.",call.=FALSE)
 batches <- lapply(levels(batch),function(b) sce[,batch==b]); names(batches)<-levels(batch)
 normed <- do.call(batchelor::multiBatchNorm,c(batches,os_bioc_native_args(a[["norm-args"]])))
 dec <- lapply(normed,function(x) os_bioc_call(scran::modelGeneVar,a[["variance-args"]],x=x,BPPARAM=BiocParallel::SerialParam()))
 combined <- do.call(scran::combineVar,c(dec,os_bioc_native_args(a[["combine-args"]])))
 hvg <- os_bioc_call(scran::getTopHVGs,a[["hvg-args"]],stats=combined,n=a[["n-hvg"]])
 normalized <- do.call(BiocGenerics::cbind,normed); normalized <- normalized[,colnames(sce)]
 # Preserve original logcounts for descriptive markers; normalization for correction is saved separately.
 native <- os_bioc_call(batchelor::fastMNN,a[["mnn-args"]],normalized,batch=batch,subset.row=hvg,
   d=a[["n-pcs"]],k=a[["mnn-k"]],cos.norm=a[["cos-norm"]],ndist=a$ndist,
   auto.merge=a[["auto-merge"]],BPPARAM=BiocParallel::SerialParam())
 corrected <- SingleCellExperiment::reducedDim(native,"corrected")
 corrected <- corrected[match(colnames(sce),colnames(native)),,drop=FALSE]
 sce <- os_bioc_call(scater::runPCA,a[["pca-args"]],x=sce,subset_row=hvg,ncomponents=a[["n-pcs"]],BPPARAM=BiocParallel::SerialParam())
 sce <- os_bioc_call(scater::runUMAP,a[["umap-args"]],x=sce,dimred="PCA",n_dimred=a[["n-pcs"]],n_neighbors=a[["umap-neighbors"]],min_dist=a[["umap-min-dist"]],n_threads=1,BPPARAM=BiocParallel::SerialParam())
 pre <- SingleCellExperiment::reducedDim(sce,"UMAP")
 SingleCellExperiment::reducedDim(sce,"corrected") <- corrected
 sce <- os_bioc_call(scater::runUMAP,a[["umap-args"]],x=sce,dimred="corrected",n_dimred=a[["umap-dims"]],n_neighbors=a[["umap-neighbors"]],min_dist=a[["umap-min-dist"]],n_threads=1,BPPARAM=BiocParallel::SerialParam())
 post <- SingleCellExperiment::reducedDim(sce,"UMAP")
 cells <- data.frame(cell=colnames(sce),batch=as.character(batch),x=post[,1],y=post[,2],pre_x=pre[,1],pre_y=pre[,2])
 if(!is.null(a[["label-col"]])) cells$label <- as.character(os_bioc_column(sce,a[["label-col"]]))
 mix <- bluster::neighborPurity(x=corrected,clusters=batch,k=a[["mixing-k"]])
 cells$batch_purity <- mix$purity
 list(sce=sce,native=native,normalized=normalized,cells=cells,hvgs=data.frame(gene=hvg),
 variance=data.frame(gene=rownames(combined),as.data.frame(combined)),
 batch_summary=aggregate(batch_purity~batch,cells,mean),
 state=list(integrated=TRUE,batch_corrected=TRUE,correction="fastMNN reduced dimensions only",marker_assay="logcounts",seed=a$seed))
}
