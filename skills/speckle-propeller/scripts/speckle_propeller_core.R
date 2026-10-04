SPECKLE_PROPELLER_MODULE_VERSION <- "1.0.0"
speckle_propeller_compute <- function(sce,a) {
  sm <- os_backend_column(sce,a[["sample-col"]]); gr <- os_backend_column(sce,a[["condition-col"]]); cl <- os_backend_column(sce,a[["cluster-col"]])
  st <- unique(data.frame(sample=sm,group=gr))
  if(anyDuplicated(st$sample) || any(table(st$group)<2)) stop("OS_INVALID_DESIGN: need at least two independent sample replicates per group; cells are not replicates.",call.=FALSE)
  o_prop <- os_backend_function_options(speckle::propeller,a,"prop",list(x=NULL,clusters=cl,sample=sm,group=gr))
  res <- speckle::propeller(x=o_prop[["x"]], clusters=o_prop[["clusters"]], sample=o_prop[["sample"]], group=o_prop[["group"]], trend=o_prop[["trend"]], robust=o_prop[["robust"]], transform=o_prop[["transform"]])
  o_props <- os_backend_function_options(speckle::getTransformedProps,a,"props",list(clusters=cl,sample=sm,transform=o_prop$transform))
  props <- speckle::getTransformedProps(clusters=o_props[["clusters"]], sample=o_props[["sample"]], transform=o_props[["transform"]])
  proportions <- data.frame(cluster=rep(rownames(props$Proportions),ncol(props$Proportions)),sample=rep(colnames(props$Proportions),each=nrow(props$Proportions)),proportion=as.vector(props$Proportions))
  list(sce=sce,native=list(results=res,proportions=props),tables=list(differential=data.frame(cluster=rownames(res),res,check.names=FALSE),proportions=proportions),options=list(propeller=o_prop[c("trend","robust","transform")],proportions=o_props["transform"]),functions=c("propeller","getTransformedProps"),versions=list(speckle=as.character(utils::packageVersion("speckle"))))

}
