MUSCAT_PSEUDOBULK_MODULE_VERSION <- "1.0.0"
muscat_pseudobulk_compute <- function(sce,a) {
  rep <- os_backend_replicates(sce,a[["sample-col"]],a[["condition-col"]],a$reference,a$target)
  sce <- sce[,rep$selected]
  sce[[a[["condition-col"]]]] <- factor(os_backend_column(sce,a[["condition-col"]]),levels=c(a$reference,a$target))
  o_prep <- os_backend_function_options(muscat::prepSCE,a,"prep",list(x=sce,kid=a[["cluster-col"]],sid=a[["sample-col"]],gid=a[["condition-col"]]))
  sce <- muscat::prepSCE(x=o_prep[["x"]], kid=o_prep[["kid"]], sid=o_prep[["sid"]], gid=o_prep[["gid"]], drop=o_prep[["drop"]])
  o_aggregate <- os_backend_function_options(muscat::aggregateData,a,"aggregate",list(x=sce,assay="counts",by=c("cluster_id","sample_id"),fun="sum",verbose=FALSE))
  pb <- muscat::aggregateData(x=o_aggregate[["x"]], assay=o_aggregate[["assay"]], by=o_aggregate[["by"]], fun=o_aggregate[["fun"]], scale=o_aggregate[["scale"]], verbose=o_aggregate[["verbose"]], BPPARAM=o_aggregate[["BPPARAM"]])
  o_ds <- os_backend_function_options(muscat::pbDS,a,"ds",list(pb=pb,verbose=FALSE))
  res <- muscat::pbDS(pb=o_ds[["pb"]], method=o_ds[["method"]], design=o_ds[["design"]], coef=o_ds[["coef"]], contrast=o_ds[["contrast"]], min_cells=o_ds[["min_cells"]], filter=o_ds[["filter"]], treat=o_ds[["treat"]], verbose=o_ds[["verbose"]], BPPARAM=o_ds[["BPPARAM"]])
  tables <- list()
  for(cmp in names(res$table)) for(cl in names(res$table[[cmp]])) tables[[paste(cmp,cl,sep="__")]] <- res$table[[cmp]][[cl]]
  full <- do.call(rbind,lapply(names(tables),function(nm) data.frame(comparison_cluster=nm,tables[[nm]],check.names=FALSE)))
  tables <- c(list(differential=full),tables)
  list(sce=sce,native=list(pseudobulk=pb,results=res),tables=tables,
    options=list(prep=o_prep[-1],aggregate=o_aggregate[-1],pbDS=o_ds[-1]),
    functions=c("prepSCE","aggregateData","pbDS"),versions=list(muscat=as.character(utils::packageVersion("muscat"))))

}
