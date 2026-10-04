# requires: Seurat SeuratObject sctransform Matrix jsonlite digest
source('skills/_shared/scripts/sc_seurat_io.R')
source('skills/seurat-cluster/scripts/seurat_cluster_core.R')
x <- readRDS(file.path(Sys.getenv('OMICSTAT_TEST_TMP','/scratch'),'cluster_qc/objects/seurat.rds'))[,1:200]
a <- list(normalization='LogNormalize',`n-hvg`=100,`n-pcs`=10,dims=5,neighbors=10,`umap-neighbors`=10,resolution=.5,seed=42,algorithm=4,`min-dist`=.3,`scale-factor`=10000,`cluster-initial-membership`=jsonlite::toJSON(rep(1L,ncol(x))),`cluster-node-sizes`=jsonlite::toJSON(rep(1,ncol(x))),`hvg-selection-method`='"mean.var.plot"',`hvg-mean-function`='FastExpMean',`hvg-dispersion-function`='FastLogVMR',`hvg-mean-cutoff`='[0,100]',`hvg-dispersion-cutoff`='[0,100]')
r <- seurat_cluster_compute(x,a)
y <- Seurat::NormalizeData(x,verbose=FALSE)
y <- Seurat::FindVariableFeatures(y,selection.method='mean.var.plot',mean.function=get("FastExpMean",asNamespace("Seurat")),dispersion.function=get("FastLogVMR",asNamespace("Seurat")),mean.cutoff=c(0,100),dispersion.cutoff=c(0,100),nfeatures=100,verbose=FALSE)
stopifnot(identical(SeuratObject::VariableFeatures(r$object),SeuratObject::VariableFeatures(y)))
z <- Seurat::FindClusters(r$object,graph.name='omic_snn',algorithm=4,initial.membership=rep(1L,ncol(x)),node.sizes=rep(1,ncol(x)),resolution=.5,random.seed=42,verbose=FALSE)
stopifnot(identical(as.character(r$object$cluster),as.character(SeuratObject::Idents(z))))
cat('PASS native supplied graph membership/node sizes and alternate HVG functions\n')
# Native reference model is the fitted sctransform vst result (not an SCTModel S4).
counts <- SeuratObject::GetAssayData(x,assay='RNA',layer='counts')
model <- sctransform::vst(counts,method='poisson',n_cells=200,verbosity=0)
saveRDS(model,file.path(Sys.getenv('OMICSTAT_TEST_TMP','/scratch'),'sct_reference.rds'))
features <- rownames(model$model_pars_fit)[1:100]
a$normalization <- 'SCTransform'; a[['sct-reference-model']] <- file.path(Sys.getenv('OMICSTAT_TEST_TMP','/scratch'),'sct_reference.rds'); a[['sct-residual-features']] <- jsonlite::toJSON(features)
r <- seurat_cluster_compute(x,a)
y <- Seurat::SCTransform(x,reference.SCT.model=model,residual.features=features,variable.features.n=100,seed.use=42,verbose=FALSE)
stopifnot(isTRUE(all.equal(SeuratObject::GetAssayData(r$object,assay='SCT',layer='scale.data'),SeuratObject::GetAssayData(y,assay='SCT',layer='scale.data'))))
stopifnot(identical(r$state$native_controls$residual.features,features))
cat('PASS native supplied SCT reference and residual features\n')
