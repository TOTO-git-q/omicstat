AU_MODULE <- "aucell-score"
AU_MODULE_VERSION <- "1.0.0"
aucell_score_compute <- function(sce,a){
 path<-a[["sets-file"]]
 if(is.null(path)||!file.exists(path)) stop("OS_REFDATA_MISSING: required user-supplied offline --sets-file.",call.=FALSE)
 if(is.null(a[["sets-source"]])||is.null(a[["sets-licence"]])||!nzchar(trimws(a[["sets-source"]]))||!nzchar(trimws(a[["sets-licence"]]))||!identical(a[["accept-licence"]],"user-permitted")) stop("OS_LICENCE_REQUIRED: declare gene-set source/licence and acknowledge user permission.",call.=FALSE)
 # A GMT declared through the user-supplied provenance contract (CONVENTIONS
 # "User-supplied gene-set collections") is checked and recorded there; the
 # name gate below stays for an undeclared file.
 contract<-os_user_geneset_given(a)
 os_user_geneset_guard(a,contract,"a GMT declared through the user-supplied provenance contract",feature=TRUE)
 coll<-NULL
 if(contract){
  b<-a;b[["gene-sets"]]<-path
  if(!is.null(a[["gene-sets-source"]])&&!identical(a[["gene-sets-source"]],a[["sets-source"]])) stop("OS_CONFLICTING_PARAMETERS: --gene-sets-source differs from --sets-source; give the source once.",call.=FALSE)
  b[["gene-sets-source"]]<-a[["sets-source"]]
  coll<-os_user_genesets_check(os_user_genesets_resolve(b),a[["feature-id-type"]],rownames(sce),"the single-cell features","--feature-id-type")
  if(is.null(coll$record$terms)) coll$record$terms<-a[["sets-licence"]]
  coll$record$licence_declaration<-a[["sets-licence"]];coll$record$licence_acknowledgement<-a[["accept-licence"]]
 } else {
 headers <- vapply(strsplit(readLines(path,warn=FALSE),"\t",fixed=TRUE),function(z)paste(head(z,2),collapse=" "),"")
 if(any(grepl("KEGG|CADD|PanglaoDB|DepMap",c(path,a[["sets-source"]],a[["sets-licence"]],headers),ignore.case=TRUE))) stop(paste0("OS_REFDATA_MISSING: prohibited gene-set collection; no KEGG, CADD, PanglaoDB or DepMap content is bundled or accepted undeclared. ",
  "A file you obtained yourself is accepted with --gene-sets-provenance <json> (or --gene-sets-version and --gene-sets-id-type) and --feature-id-type; you are responsible for its terms."),call.=FALSE)
 }
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
 state=list(aucell_scored=TRUE,auc_max_rank=maxrank,aucell_assay=a$assay,gene_sets_sha256=digest::digest(file=path,algo="sha256"),gene_sets=c(list(path=path,sha256=digest::digest(file=path,algo="sha256"),source=a[["sets-source"]],licence=a[["sets-licence"]],acknowledgement=a[["accept-licence"]]),if(!is.null(coll)) list(origin=OS_USER_GENESETS_ORIGIN,version_or_release=coll$record$version_or_release,id_type=coll$record$id_type)),seed=a$seed),
 user_gene_sets=if(is.null(coll)) NULL else coll$record)
}
