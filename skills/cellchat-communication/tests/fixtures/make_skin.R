make_skin <- function(suite) {
 library(Matrix)
 e<-new.env();load(file.path(suite,'acceptance','data','CellChat_data_humanSkin_CellChat.rda'),envir=e)
 d<-e$data_humanSkin;cells<-rownames(d$meta)[d$meta$condition=='LS'];x<-d$data[,cells];meta<-d$meta[cells,,drop=FALSE]
 if (!'samples' %in% names(meta)) meta$samples <- if ('patient.id' %in% names(meta)) meta$patient.id else 'sample1' # Use the tutorial's patient metadata when available.
 SingleCellExperiment::SingleCellExperiment(assays=list(logcounts=x),colData=meta)
}
