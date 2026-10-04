make_aucell_brain <- function(suite) {
 path<-file.path(suite,"acceptance/data/GSE60361_C1-3005-Expression.txt.gz")
 stopifnot(digest::digest(file=path,algo="sha256")=="dd09532c73822b632b1914356bfca8e186aff2300b30299e066a6105205e5c4c")
 x<-data.table::fread(path,sep="\t")
 genes<-unname(unlist(x[,1,with=FALSE]));x<-as.matrix(x[,-1,with=FALSE]);rownames(x)<-genes
 x[unique(rownames(x)),,drop=FALSE]
}
