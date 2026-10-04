make_cellbench <- function(suite) {
 e<-new.env();load(file.path(suite,'acceptance','data','CellBench_single_cell_data.RData'),envir=e)
 sc_data<-as.list(e)
 stopifnot(!is.null(sc_data))
 common<-rownames(sc_data$sc_dropseq)[rownames(sc_data$sc_dropseq)%in%rownames(sc_data$sc_celseq)]
 common<-common[common%in%rownames(sc_data$sc_10x)]
 xs<-list(sc_data$sc_10x[common,],sc_data$sc_celseq[common,],sc_data$sc_dropseq[common,])
 set.seed(10);boots<-lapply(xs,function(x)sample(seq_len(ncol(x)),replace=TRUE))
 all<-list(xs[[1]],xs[[1]][,boots[[1]]],xs[[2]],xs[[2]][,boots[[2]]],xs[[3]],xs[[3]][,boots[[3]]])
 # Expression is irrelevant for the proportion test; retain native anchor counts.
 counts<-do.call(cbind,lapply(all,function(x)SummarizedExperiment::assay(x,'counts')))
 colnames(counts)<-paste0('cell',seq_len(ncol(counts)))
 sce<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=counts))
 sce$sample<-rep(paste0('S',1:6),vapply(all,ncol,1L));sce$group<-rep(c('10x','celseq','dropseq'),2*vapply(xs,ncol,1L))
 sce$cluster<-unlist(lapply(all,function(x)as.character(x$cell_line)))
 sce
}
