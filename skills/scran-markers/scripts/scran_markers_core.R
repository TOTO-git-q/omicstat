SM_MODULE <- "scran-markers"
SM_MODULE_VERSION <- "1.0.0"
scran_markers_compute <- function(sce,a){
 groups<-factor(os_bioc_column(sce,a[["cluster-col"]]));block<-if(is.null(a[["block-col"]]))NULL else os_bioc_column(sce,a[["block-col"]])
 if(nlevels(groups)<2)stop("OS_INVALID_INPUT: at least two clusters required.",call.=FALSE)
 if(a$route=="scoreMarkers") native<-os_bioc_call(scran::scoreMarkers,a[["marker-args"]],x=sce,groups=groups,block=block,lfc=a$lfc,assay.type="logcounts",BPPARAM=BiocParallel::SerialParam())
 else native<-os_bioc_call(scran::findMarkers,a[["marker-args"]],x=sce,groups=groups,block=block,lfc=a$lfc,test.type=a[["test-type"]],direction=a$direction,pval.type=a[["pval-type"]],assay.type="logcounts",BPPARAM=BiocParallel::SerialParam())
 tables<-lapply(names(native),function(g){v<-as.data.frame(native[[g]]);data.frame(cluster=g,gene=rownames(v),v,check.names=FALSE)});names(tables)<-names(native)
 top<-unique(unlist(lapply(tables,function(v){if(!a[["rank-by"]]%in%names(v))stop("OS_MISSING_COLUMN: --rank-by must name a native result column.",call.=FALSE);head(v$gene[order(v[[a[["rank-by"]]]],decreasing=a[["rank-decreasing"]],na.last=NA)],a[["top-n"]])})))
 mat<-as.matrix(SummarizedExperiment::assay(sce,"logcounts")[top,,drop=FALSE])
 dot<-do.call(rbind,lapply(levels(groups),function(g)data.frame(cluster=g,gene=top,avg_exp=rowMeans(mat[,groups==g,drop=FALSE]),pct_exp=100*rowMeans(mat[,groups==g,drop=FALSE]>0))))
 means<-sapply(levels(groups),function(g)rowMeans(mat[,groups==g,drop=FALSE]));rownames(means)<-top
 list(sce=sce,native=native,tables=tables,markers=do.call(rbind,tables),dot=dot,means=means,
 state=list(markers_complete=TRUE,marker_route=a$route,marker_assay="original logcounts",marker_group=a[["cluster-col"]],seed=a$seed))
}
