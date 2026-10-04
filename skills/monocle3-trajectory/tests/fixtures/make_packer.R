make_packer <- function(suite) {
 library(Matrix)
 x<-readRDS(file.path(suite,'acceptance','data','monocle3_packer_embryo_expression.rds'))
 cd<-readRDS(file.path(suite,'acceptance','data','monocle3_packer_embryo_colData.rds'))
 gd<-readRDS(file.path(suite,'acceptance','data','monocle3_packer_embryo_rowData.rds'))
 stopifnot(identical(dim(x),c(20222L,6188L)),identical(rownames(cd),colnames(x)),identical(rownames(gd),rownames(x)))
 cds<-monocle3::new_cell_data_set(x,cell_metadata=cd,gene_metadata=gd)
 cds<-monocle3::preprocess_cds(cds,num_dim=50)
 cds<-monocle3::align_cds(cds,alignment_group='batch',residual_model_formula_str='~ bg.300.loading + bg.400.loading + bg.500.1.loading + bg.500.2.loading + bg.r17.loading + bg.b01.loading + bg.b02.loading')
 cds<-monocle3::reduce_dimension(cds,cores=1,umap.fast_sgd=FALSE)
 cds<-monocle3::cluster_cells(cds,random_seed=42)
 sce<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=x),colData=SummarizedExperiment::colData(cds),rowData=SummarizedExperiment::rowData(cds),reducedDims=SingleCellExperiment::reducedDims(cds))
 sce$cluster<-as.character(monocle3::clusters(cds));sce$partition<-as.character(monocle3::partitions(cds))
 sce
}
