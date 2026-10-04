CELLCHAT_COMMUNICATION_MODULE_VERSION <- "1.0.0"
cellchat_communication_compute <- function(sce,a) {
  meta <- as.data.frame(SummarizedExperiment::colData(sce));os_backend_column(sce,a[["cluster-col"]])
  o_create <- os_backend_function_options(CellChat::createCellChat,a,"create",list(object=SummarizedExperiment::assay(sce,"logcounts"),meta=meta,group.by=a[["cluster-col"]],datatype="RNA"))
  cc <- CellChat::createCellChat(object=o_create[["object"]], meta=o_create[["meta"]], group.by=o_create[["group.by"]], datatype=o_create[["datatype"]], coordinates=o_create[["coordinates"]], spatial.factors=o_create[["spatial.factors"]], assay=o_create[["assay"]], do.sparse=o_create[["do.sparse"]])
  db_env <- new.env(); db_name <- paste0("CellChatDB.",a[["db-species"]])
  utils::data(list=db_name,package="CellChat",envir=db_env); db <- db_env[[db_name]]
  if(a[["db-subset"]]!="all") {
  o_db <- os_backend_function_options(CellChat::subsetDB,a,"db",list(CellChatDB=db,search=a[["db-subset"]],key="annotation"))
  db <- CellChat::subsetDB(CellChatDB=o_db[["CellChatDB"]], search=o_db[["search"]], key=o_db[["key"]], non_protein=o_db[["non_protein"]])
  }
  cc@DB <- db
  o_subset <- os_backend_function_options(CellChat::subsetData,a,"subset",list(object=cc))
  cc <- CellChat::subsetData(object=o_subset[["object"]], features=o_subset[["features"]])
  o_genes <- os_backend_function_options(CellChat::identifyOverExpressedGenes,a,"genes",list(object=cc))
  cc <- CellChat::identifyOverExpressedGenes(object=o_genes[["object"]], data.use=o_genes[["data.use"]], group.by=o_genes[["group.by"]], idents.use=o_genes[["idents.use"]], invert=o_genes[["invert"]], group.dataset=o_genes[["group.dataset"]], pos.dataset=o_genes[["pos.dataset"]], group.DE.combined=o_genes[["group.DE.combined"]], features.name=o_genes[["features.name"]], only.pos=o_genes[["only.pos"]], features=o_genes[["features"]], return.object=o_genes[["return.object"]], thresh.pc=o_genes[["thresh.pc"]], thresh.fc=o_genes[["thresh.fc"]], thresh.p=o_genes[["thresh.p"]], do.DE=o_genes[["do.DE"]], do.fast=o_genes[["do.fast"]], min.cells=o_genes[["min.cells"]])
  o_interactions <- os_backend_function_options(CellChat::identifyOverExpressedInteractions,a,"interactions",list(object=cc))
  cc <- CellChat::identifyOverExpressedInteractions(object=o_interactions[["object"]], features.name=o_interactions[["features.name"]], variable.both=o_interactions[["variable.both"]], features=o_interactions[["features"]], return.object=o_interactions[["return.object"]])
  o_prob <- os_backend_function_options(CellChat::computeCommunProb,a,"prob",list(object=cc,type="triMean",seed.use=a$seed,raw.use=TRUE))
  if(!isTRUE(o_prob$raw.use)) stop("OS_MISSING_DEPENDENCY: pinned CellChat does not export projectData; use unprojected expression (--prob-raw-use true).",call.=FALSE)
  cc <- CellChat::computeCommunProb(object=o_prob[["object"]], type=o_prob[["type"]], trim=o_prob[["trim"]], LR.use=o_prob[["LR.use"]], raw.use=o_prob[["raw.use"]], population.size=o_prob[["population.size"]], distance.use=o_prob[["distance.use"]], interaction.range=o_prob[["interaction.range"]], scale.distance=o_prob[["scale.distance"]], k.min=o_prob[["k.min"]], contact.dependent=o_prob[["contact.dependent"]], contact.range=o_prob[["contact.range"]], contact.knn.k=o_prob[["contact.knn.k"]], contact.dependent.forced=o_prob[["contact.dependent.forced"]], do.symmetric=o_prob[["do.symmetric"]], nboot=o_prob[["nboot"]], seed.use=o_prob[["seed.use"]], Kh=o_prob[["Kh"]], n=o_prob[["n"]])
  o_filter <- os_backend_function_options(CellChat::filterCommunication,a,"filter",list(object=cc))
  cc <- CellChat::filterCommunication(object=o_filter[["object"]], min.cells=o_filter[["min.cells"]], min.samples=o_filter[["min.samples"]], rare.keep=o_filter[["rare.keep"]], nonFilter.keep=o_filter[["nonFilter.keep"]])
  o_pathway <- os_backend_function_options(CellChat::computeCommunProbPathway,a,"pathway",list(object=cc))
  if(!isTRUE(o_prob$raw.use)) stop("OS_MISSING_DEPENDENCY: pinned CellChat does not export projectData; use unprojected expression (--prob-raw-use true).",call.=FALSE)
  cc <- CellChat::computeCommunProbPathway(object=o_pathway[["object"]], net=o_pathway[["net"]], pairLR.use=o_pathway[["pairLR.use"]], thresh=o_pathway[["thresh"]])
  o_aggregate <- os_backend_function_options(CellChat::aggregateNet,a,"aggregate",list(object=cc))
  cc <- CellChat::aggregateNet(object=o_aggregate[["object"]], sources.use=o_aggregate[["sources.use"]], targets.use=o_aggregate[["targets.use"]], signaling=o_aggregate[["signaling"]], pairLR.use=o_aggregate[["pairLR.use"]], remove.isolate=o_aggregate[["remove.isolate"]], thresh=o_aggregate[["thresh"]], return.object=o_aggregate[["return.object"]])
  o_communication <- os_backend_function_options(CellChat::subsetCommunication,a,"communication",list(object=cc))
  tab <- CellChat::subsetCommunication(object=o_communication[["object"]], net=o_communication[["net"]], slot.name=o_communication[["slot.name"]], sources.use=o_communication[["sources.use"]], targets.use=o_communication[["targets.use"]], signaling=o_communication[["signaling"]], pairLR.use=o_communication[["pairLR.use"]], thresh=o_communication[["thresh"]], datasets=o_communication[["datasets"]], ligand.pvalues=o_communication[["ligand.pvalues"]], ligand.logFC=o_communication[["ligand.logFC"]], ligand.pct.1=o_communication[["ligand.pct.1"]], ligand.pct.2=o_communication[["ligand.pct.2"]], receptor.pvalues=o_communication[["receptor.pvalues"]], receptor.logFC=o_communication[["receptor.logFC"]], receptor.pct.1=o_communication[["receptor.pct.1"]], receptor.pct.2=o_communication[["receptor.pct.2"]])
  o_centrality <- os_backend_function_options(CellChat::netAnalysis_computeCentrality,a,"centrality",list(object=cc))
  cc <- CellChat::netAnalysis_computeCentrality(object=o_centrality[["object"]], slot.name=o_centrality[["slot.name"]], net=o_centrality[["net"]], net.name=o_centrality[["net.name"]], thresh=o_centrality[["thresh"]])
  weights <- as.data.frame(as.table(cc@net$weight));names(weights)<-c("source","target","weight")
  counts <- as.data.frame(as.table(cc@net$count));names(counts)<-c("source","target","count")
  all_lr <- as.data.frame(as.table(cc@net$prob));names(all_lr)<-c("source","target","interaction","prob")
  all_lr$pval <- as.vector(cc@net$pval)
  tables <- list(communication=tab,all_lr=all_lr,network_weight=weights,network_count=counts)
  for(pw in names(cc@netP$centr)) tables[[paste0("centrality_",pw)]] <- data.frame(cell_group=names(cc@netP$centr[[pw]][[1]]),as.data.frame(cc@netP$centr[[pw]]),check.names=FALSE)
  list(sce=sce,native=cc,tables=tables,weight=cc@net$weight,count=cc@net$count,
    options=list(database_species=a[["db-species"]],database_subset=a[["db-subset"]],database_sha256=digest::digest(db,algo="sha256"),identifyOverExpressedGenes=o_genes[-1],identifyOverExpressedInteractions=o_interactions[-1],computeCommunProb=o_prob[-1],filterCommunication=o_filter[-1],computeCommunProbPathway=o_pathway[-1],aggregateNet=o_aggregate[-1],subsetCommunication=o_communication[-1],centrality=o_centrality[-1]),
    functions=c("createCellChat","subsetDB","subsetData","identifyOverExpressedGenes","identifyOverExpressedInteractions","computeCommunProb","filterCommunication","computeCommunProbPathway","aggregateNet","subsetCommunication","netAnalysis_computeCentrality"),versions=list(CellChat=as.character(utils::packageVersion("CellChat"))),note="Inferred transcriptomic communication; not proof of physical signalling. Independent samples are needed for condition-level comparisons; this is a single-network analysis.")

}
