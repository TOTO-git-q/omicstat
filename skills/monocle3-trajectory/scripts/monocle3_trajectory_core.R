MONOCLE3_TRAJECTORY_MODULE_VERSION <- "1.0.0"
monocle3_trajectory_compute <- function(sce,a) {
  if(!"UMAP"%in%SingleCellExperiment::reducedDimNames(sce)) stop("OS_MISSING_COLUMN: backend requires existing UMAP coordinates.",call.=FALSE)
  cl <- os_backend_column(sce,a[["cluster-col"]]); partitions <- os_backend_column(sce,a[["partition-col"]])
  cd <- as.data.frame(SummarizedExperiment::colData(sce)); gd <- as.data.frame(SummarizedExperiment::rowData(sce))
  if(!"gene_short_name"%in%names(gd)) gd$gene_short_name <- rownames(sce)
  o_cds <- os_backend_function_options(monocle3::new_cell_data_set,a,"cds",list(expression_data=SummarizedExperiment::assay(sce,"counts"),cell_metadata=cd,gene_metadata=gd))
  cds <- monocle3::new_cell_data_set(expression_data=o_cds[["expression_data"]], cell_metadata=o_cds[["cell_metadata"]], gene_metadata=o_cds[["gene_metadata"]], verbose=o_cds[["verbose"]])
  SingleCellExperiment::reducedDim(cds,"UMAP") <- SingleCellExperiment::reducedDim(sce,"UMAP")
  # Pinned CDS slot contract, as in the community as.cell_data_set conversion.
  # Preserve existing cluster/partition assignments; no clustering or embedding here.
  cds@clusters[["UMAP"]] <- list(clusters=stats::setNames(factor(cl),colnames(sce)),partitions=stats::setNames(factor(partitions),colnames(sce)),louvain_res=NULL)
  o_learn <- os_backend_function_options(monocle3::learn_graph,a,"learn",list(cds=cds))
  cds <- monocle3::learn_graph(cds=o_learn[["cds"]], use_partition=o_learn[["use_partition"]], close_loop=o_learn[["close_loop"]], learn_graph_control=o_learn[["learn_graph_control"]], verbose=o_learn[["verbose"]])
  roots <- NULL
  if(!is.null(a[["root-time-col"]])) {
    time <- os_backend_column(sce,a[["root-time-col"]]); early <- which(time==a[["root-time-value"]])
    if(!length(early)) stop("OS_INVALID_INPUT: no cells in requested earliest time bin.",call.=FALSE)
    closest <- as.matrix(cds@principal_graph_aux[["UMAP"]]$pr_graph_cell_proj_closest_vertex[colnames(cds),,drop=FALSE])
    roots <- igraph::V(monocle3::principal_graph(cds)[["UMAP"]])$name[as.numeric(names(which.max(table(closest[early,]))))]
  }
  if(is.null(roots) && is.null(a[["order-root-cells"]]) && is.null(a[["order-root-pr-nodes"]])) stop("OS_MISSING_PARAMETER: provide root cells/nodes or an explicit earliest time bin.",call.=FALSE)
  o_order <- os_backend_function_options(monocle3::order_cells,a,"order",list(cds=cds,root_pr_nodes=roots))
  cds <- monocle3::order_cells(cds=o_order[["cds"]], reduction_method=o_order[["reduction_method"]], root_pr_nodes=o_order[["root_pr_nodes"]], root_cells=o_order[["root_cells"]], verbose=o_order[["verbose"]])
  pt <- monocle3::pseudotime(cds,reduction_method="UMAP")
  test_cds <- cds
  if(!is.null(a[["graph-genes-file"]])) test_cds <- cds[readLines(a[["graph-genes-file"]]),]
  o_test <- os_backend_function_options(monocle3::graph_test,a,"test",list(cds=test_cds,neighbor_graph="principal_graph",cores=1))
  res <- monocle3::graph_test(cds=o_test[["cds"]], neighbor_graph=o_test[["neighbor_graph"]], reduction_method=o_test[["reduction_method"]], k=o_test[["k"]], method=o_test[["method"]], alternative=o_test[["alternative"]], expression_family=o_test[["expression_family"]], cores=o_test[["cores"]], verbose=o_test[["verbose"]], nn_control=o_test[["nn_control"]])
  graph <- monocle3::principal_graph(cds)[["UMAP"]]
  coords <- t(cds@principal_graph_aux[["UMAP"]]$dp_mst)
  edges <- igraph::as_edgelist(graph,names=TRUE)
  curves <- lapply(seq_len(nrow(edges)),function(i) coords[edges[i,],,drop=FALSE])
  list(sce=sce,native=list(cds=cds,graph_test=res),tables=list(pseudotime=data.frame(cell_id=names(pt),cluster=cl,partition=partitions,pseudotime=as.numeric(pt)),graph_test=data.frame(gene=rownames(res),res,check.names=FALSE)),embedding=SingleCellExperiment::reducedDim(cds,"UMAP"),pseudotime=matrix(pt,ncol=1),curves=curves,
    options=list(learn_graph=o_learn[-1],order_cells=o_order[-1],graph_test=o_test[-1],root_rationale=a[["root-rationale"]]),functions=c("new_cell_data_set","learn_graph","order_cells","graph_test"),versions=list(monocle3=as.character(utils::packageVersion("monocle3"))),note="Infinite pseudotime denotes cells unreachable from the requested root; retain these values. Graph association is exploratory, not causal direction.")

}
