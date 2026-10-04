make_skin <- function(suite) {
 library(Matrix)
 e<-new.env();load(file.path(suite,'acceptance','data','CellChat_data_humanSkin_CellChat.rda'),envir=e)
 d<-e$data_humanSkin;cells<-rownames(d$meta)[d$meta$condition=='LS'];x<-d$data[,cells];meta<-d$meta[cells,,drop=FALSE]
 SingleCellExperiment::SingleCellExperiment(assays=list(logcounts=x),colData=meta)
}
