SLINGSHOT_TRAJECTORY_MODULE_VERSION <- "1.0.0"
slingshot_trajectory_compute <- function(sce,a) {
  cl <- os_backend_column(sce,a[["cluster-col"]])
  if(!a[["reduced-dim"]]%in%SingleCellExperiment::reducedDimNames(sce)) stop("OS_MISSING_COLUMN: requested embedding absent.",call.=FALSE)
  rd <- SingleCellExperiment::reducedDim(sce,a[["reduced-dim"]])
  if(is.null(a[["trajectory-rds"]])) {
  o_sling <- os_backend_function_options(os_backend_s4_function("slingshot","slingshot",c("matrix","character")),a,"sling",list(data=rd,clusterLabels=cl,start.clus=if(a[["start-cluster"]]=="auto") NULL else a[["start-cluster"]]))
  sds <- slingshot::slingshot(data=o_sling[["data"]], clusterLabels=o_sling[["clusterLabels"]], reducedDim=o_sling[["reducedDim"]], start.clus=o_sling[["start.clus"]], end.clus=o_sling[["end.clus"]], dist.method=o_sling[["dist.method"]], use.median=o_sling[["use.median"]], omega=o_sling[["omega"]], omega_scale=o_sling[["omega_scale"]], times=o_sling[["times"]], shrink=o_sling[["shrink"]], extend=o_sling[["extend"]], reweight=o_sling[["reweight"]], reassign=o_sling[["reassign"]], thresh=o_sling[["thresh"]], maxit=o_sling[["maxit"]], stretch=o_sling[["stretch"]], approx_points=o_sling[["approx_points"]], smoother=o_sling[["smoother"]], shrink.method=o_sling[["shrink.method"]], allow.breaks=o_sling[["allow.breaks"]])
  } else { sds <- readRDS(a[["trajectory-rds"]]); o_sling <- list(reused=a[["trajectory-rds"]]) }
  pt <- slingshot::slingPseudotime(sds,na=TRUE)
  curves <- slingshot::slingCurves(sds)
  tab <- data.frame(cell_id=colnames(sce),cluster=cl,pt,check.names=FALSE)
  tables <- list(pseudotime=tab);gam <- NULL
  if(a[["fit-gam"]]=="true") {
  o_gam <- os_backend_function_options(os_backend_s4_function("tradeSeq","fitGAM","matrix"),a,"gam",list(counts=as.matrix(SummarizedExperiment::assay(sce,"counts")),sds=sds,verbose=FALSE,parallel=FALSE))
  gam <- tradeSeq::fitGAM(counts=o_gam[["counts"]], sds=o_gam[["sds"]], pseudotime=o_gam[["pseudotime"]], cellWeights=o_gam[["cellWeights"]], conditions=o_gam[["conditions"]], U=o_gam[["U"]], genes=o_gam[["genes"]], weights=o_gam[["weights"]], offset=o_gam[["offset"]], nknots=o_gam[["nknots"]], verbose=o_gam[["verbose"]], parallel=o_gam[["parallel"]], BPPARAM=o_gam[["BPPARAM"]], control=o_gam[["control"]], sce=o_gam[["sce"]], family=o_gam[["family"]], gcv=o_gam[["gcv"]])
  o_association <- os_backend_function_options(os_backend_s4_function("tradeSeq","associationTest","SingleCellExperiment"),a,"association",list(models=gam))
  assoc <- tradeSeq::associationTest(models=o_association[["models"]], global=o_association[["global"]], lineages=o_association[["lineages"]], l2fc=o_association[["l2fc"]], nPoints=o_association[["nPoints"]], contrastType=o_association[["contrastType"]], inverse=o_association[["inverse"]])
    tables$association <- data.frame(gene=rownames(assoc),assoc,check.names=FALSE)
  }
  list(sce=sce,native=list(trajectory=sds,gam=gam),tables=tables,embedding=rd,curves=curves,pseudotime=pt,
    options=list(slingshot=o_sling[-c(1,2)],fitGAM=if(!is.null(gam)) o_gam[setdiff(names(o_gam),c("counts","sds","pseudotime","cellWeights"))] else NULL,associationTest=if(!is.null(gam))o_association[-1] else NULL),
    functions=c("slingshot",if(!is.null(gam))c("fitGAM","associationTest")),versions=list(slingshot=as.character(utils::packageVersion("slingshot")),tradeSeq=as.character(utils::packageVersion("tradeSeq"))))

}
