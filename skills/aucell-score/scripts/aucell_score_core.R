AU_MODULE <- "aucell-score"
AU_MODULE_VERSION <- "1.0.0"
aucell_score_compute <- function(sce,a){
 path<-a[["sets-file"]]
 if(is.null(path)||!file.exists(path)) stop("OS_REFDATA_MISSING: required user-supplied offline --sets-file.",call.=FALSE)
 if(is.null(a[["sets-source"]])||is.null(a[["sets-licence"]])||!nzchar(trimws(a[["sets-source"]]))||!nzchar(trimws(a[["sets-licence"]]))||!identical(a[["accept-licence"]],"user-permitted")) stop("OS_LICENCE_REQUIRED: declare gene-set source/licence and acknowledge user permission.",call.=FALSE)
 headers <- vapply(strsplit(readLines(path,warn=FALSE),"\t",fixed=TRUE),function(z)paste(head(z,2),collapse=" "),"")
 if(any(grepl("KEGG|CADD|PanglaoDB|DepMap",c(path,a[["sets-source"]],a[["sets-licence"]],headers),ignore.case=TRUE))) stop("OS_REFDATA_MISSING: prohibited gene-set collection; no KEGG, CADD, PanglaoDB or DepMap.",call.=FALSE)
 sets<-GSEABase::getGmt(con=path)
 mat<-SummarizedExperiment::assay(sce,a$assay)
 rankings<-os_bioc_call(function(exprMat,featureType,plotStats,splitByBlocks,keepZeroesAsNA,BPPARAM,verbose,...) AUCell::AUCell_buildRankings(exprMat=exprMat,featureType=featureType,plotStats=plotStats,splitByBlocks=splitByBlocks,keepZeroesAsNA=keepZeroesAsNA,BPPARAM=BPPARAM,verbose=verbose,...),a[["ranking-args"]],exprMat=mat,featureType="genes",plotStats=FALSE,splitByBlocks=a[["split-by-blocks"]],keepZeroesAsNA=a[["keep-zeroes-as-na"]],BPPARAM=BiocParallel::SerialParam(),verbose=FALSE)
 maxrank<-a[["auc-max-rank"]] %||% ceiling(0.05*nrow(rankings))
 auc<-os_bioc_call(function(geneSets,rankings,nCores,normAUC,aucMaxRank,verbose,...) AUCell::AUCell_calcAUC(geneSets=geneSets,rankings=rankings,nCores=nCores,normAUC=normAUC,aucMaxRank=aucMaxRank,verbose=verbose,...),a[["auc-args"]],geneSets=sets,rankings=rankings,nCores=1,normAUC=a[["norm-auc"]],aucMaxRank=maxrank,verbose=FALSE)
 scores<-AUCell::getAUC(auc)
 groups<-as.character(os_bioc_column(sce,a[["cluster-col"]]))
 tab<-data.frame(cell=colnames(scores),t(scores),check.names=FALSE)
 long<-data.frame(cell=rep(colnames(scores),each=nrow(scores)),gene_set=rep(rownames(scores),ncol(scores)),cluster=rep(groups,each=nrow(scores)),AUC=as.vector(scores))
 means<-sapply(sort(unique(groups)),function(g)rowMeans(scores[,groups==g,drop=FALSE]));rownames(means)<-rownames(scores)
 sets_table<-data.frame(gene_set=names(sets),size=vapply(GSEABase::geneIds(sets),length,integer(1)),matched=vapply(GSEABase::geneIds(sets),function(x)sum(x%in%rownames(sce)),integer(1)))
 list(sce=sce,rankings=rankings,auc=auc,scores=tab,long=long,means=means,sets_table=sets_table,maxrank=maxrank,
 state=list(aucell_scored=TRUE,auc_max_rank=maxrank,aucell_assay=a$assay,gene_sets_sha256=digest::digest(file=path,algo="sha256"),gene_sets=list(path=path,sha256=digest::digest(file=path,algo="sha256"),source=a[["sets-source"]],licence=a[["sets-licence"]],acknowledgement=a[["accept-licence"]]),seed=a$seed))
}
