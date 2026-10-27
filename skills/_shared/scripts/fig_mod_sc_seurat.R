# Seurat lane figure builders: established style and finalizer only.
os_seurat_caption <- function(p,text) {
  # os_with_meta merges supplied metadata into existing figure metadata.
  os_with_meta(p, caption=paste(attr(p,"os_meta")$caption,text))
}
os_seurat_qc_figures <- function(r,a,outdir) {
  th <- list(nFeature_RNA=c(a[["min-features"]],a[["max-features"]]),nCount_RNA=c(a[["min-counts"]],a[["max-counts"]]),percent.mt=a[["max-mito"]])
  draw_th <- lapply(names(th),function(nm) th[[nm]][th[[nm]]>=min(r$tables$cell_qc[[nm]]) & th[[nm]]<=max(r$tables$cell_qc[[nm]])]); names(draw_th) <- names(th)
  flow <- r$tables$filter_flow
  stages <- data.frame(sample=flow$sample,input=flow$input,displayed=flow$after_creation,removed_before_stage=flow$creation_removed)
  p <- os_qc_violin(r$tables$cell_qc,metrics=names(th),thresholds=draw_th,metric_labels=c(nFeature_RNA="Detected genes",nCount_RNA="RNA count",percent.mt="Mitochondrial (%)"),journal=a$journal,
                   data_stage="after_creation",stage_counts=stages,metric_definitions=r$metric_definitions %||% list())
  p <- os_with_meta(p, thresholds=th, counts=list(filter_flow=flow))
  p <- os_seurat_caption(p,r$details)
  qc_width <- if (isTRUE(attr(p,"os_meta")$notes$single_sample_display)) "single" else "double"
  os_finalize_figure(p,file.path(outdir,"figures","qc_metrics"),width=qc_width,journal=a$journal,root=outdir)
  for(metric in c("percent.mt","nFeature_RNA")) {
    d <- r$tables$cell_qc
    p <- ggplot2::ggplot(d,ggplot2::aes(x=nCount_RNA,y=.data[[metric]])) + ggplot2::geom_point(colour=OS_FIG$col_ns,size=os_cell_point_mm(nrow(d)),shape=OS_FIG$shape_dense,stroke=0) + ggplot2::labs(x="UMI count",y=if(metric=="percent.mt") "Mitochondrial (%)" else "Detected genes") + theme_omicstat(journal=a$journal)
    if(length(draw_th[[metric]])) p <- p + os_hline(draw_th[[metric]])
    p <- os_with_meta(p,figure_type="qc_scatter",default_height_mm=70,caption=paste("Per-cell QC scatterplot;",r$details,"Limits outside the data range are recorded here and omitted from the axes."),thresholds=th,data=list(n_cells=nrow(d),data_stage="after_creation"),counts=list(stage_flow=stages,filter_flow=flow),definition=list(metrics=(r$metric_definitions %||% list())[intersect(c("nCount_RNA",metric),names(r$metric_definitions))]))
    os_finalize_figure(p,file.path(outdir,"figures",paste0("qc_scatter_",metric)),width="double",journal=a$journal,root=outdir)
  }
}
os_seurat_cluster_figures <- function(r,a,outdir) {
  xy <- SeuratObject::Embeddings(r$object[["umap"]])
  d <- data.frame(x=xy[,1],y=xy[,2],cluster=as.character(r$object$cluster))
  p <- os_embedding(d,"cluster",journal=a$journal)
  p <- os_seurat_caption(p,r$details)
  os_finalize_figure(p,file.path(outdir,"figures","clusters"),width="double",journal=a$journal,root=outdir)
  for(group in c("sample")) {
    d[[group]] <- as.character(r$object[[group]][,1])
    p <- os_embedding(d,group,label=FALSE,journal=a$journal) + ggplot2::theme(legend.justification="center")
    p <- os_seurat_caption(p,r$details)
    os_finalize_figure(p,file.path(outdir,"figures",paste0("umap_",group)),width="double",journal=a$journal,root=outdir)
  }
  s <- SeuratObject::Stdev(r$object[["pca"]])
  p <- ggplot2::ggplot(data.frame(pc=seq_along(s),sd=s),ggplot2::aes(x=pc,y=sd)) + ggplot2::geom_line(colour=OS_FIG$col_ink,linewidth=os_lw(OS_FIG$lw_segment)) + ggplot2::labs(x="Principal component",y="Standard deviation") + theme_omicstat(journal=a$journal)
  p <- os_with_meta(p,figure_type="pca_elbow",default_height_mm=70,caption=paste("PCA standard deviations;",r$details),data=list(n_cells=ncol(r$object)))
  os_finalize_figure(p,file.path(outdir,"figures","pca_elbow"),journal=a$journal,root=outdir)
}
os_seurat_integrate_figures <- function(r,a,outdir) {
  for(nm in c("before","after")) {
    xy <- r$embeddings[[nm]]
    d <- data.frame(x=xy[,1],y=xy[,2],batch=as.character(interaction(r$object[[]][strsplit(a[["batch-col"]],",",fixed=TRUE)[[1]]],drop=TRUE)))
    p <- os_embedding(d,"batch",label=FALSE,journal=a$journal) + ggplot2::theme(legend.justification="center")
    p <- os_seurat_caption(p,paste(nm,"integration.",r$details))
    os_finalize_figure(p,file.path(outdir,"figures",paste0("integration_",nm)),width="double",journal=a$journal,root=outdir)
  }
  xy <- r$embeddings$after
  for(group in c("cluster","sample")) {
    d <- data.frame(x=xy[,1],y=xy[,2],value=as.character(r$object[[group]][,1])); names(d)[3] <- group
    p <- os_embedding(d,group,label=group=="cluster",journal=a$journal) + ggplot2::theme(legend.justification="center")
    p <- os_seurat_caption(p,paste("Integrated UMAP;",r$details))
    os_finalize_figure(p,file.path(outdir,"figures",paste0("integration_",group)),width="double",journal=a$journal,root=outdir)
  }
}
# Keep native rank and the explicit display ranking as separate manifests.
.os_seurat_marker_selection <- function(r, a) {
  t <- r$tables$markers_display
  if (is.null(t)) stop("OS_INVALID_INPUT: marker rendering requires the core markers_display table.", call. = FALSE)
  if (!nrow(t)) return(list(genes = character(), table = t, effect = NULL))
  if (!all(c("gene") %in% names(t))) stop("OS_MISSING_COLUMN: marker display table needs gene IDs.", call. = FALSE)
  if (!"cluster" %in% names(t)) t$cluster <- "contrast"
  if (anyNA(t$gene) || anyNA(t$cluster) || any(!nzchar(t$gene)) || anyDuplicated(paste(t$cluster, t$gene, sep = "\r")))
    stop("OS_INVALID_INPUT: marker group/gene keys must be unique and nonmissing.", call. = FALSE)
  top <- a[["top-n"]]
  if (length(top) != 1L || !is.finite(top) || top < 1 || top != as.integer(top)) stop("OS_INVALID_INPUT: marker top-n must be a positive integer.", call. = FALSE)
  effect <- a[["fc-name"]] %||% if ("avg_log2FC" %in% names(t)) "avg_log2FC" else if ("avg_logFC" %in% names(t)) "avg_logFC" else NULL
  if (!is.null(effect) && !effect %in% names(t)) stop("OS_MISSING_COLUMN: resolved marker effect column is absent.", call. = FALSE)
  full <- r$tables$markers_full
  if (!"cluster" %in% names(full)) full$cluster <- "contrast"
  native_rank <- ave(seq_len(nrow(full)), full$cluster, FUN = seq_along)
  t$native_rank <- native_rank[match(paste(t$cluster, t$gene, sep = "\r"), paste(full$cluster, full$gene, sep = "\r"))]
  if (anyNA(t$native_rank)) stop("OS_INVALID_INPUT: display markers must retain native group/gene identities.", call. = FALSE)
  criterion <- if ("p_val_adj" %in% names(t)) "adjusted_P_ascending" else if ("my_power" %in% names(t)) "native_power_descending" else "native_rank"
  t$display_rank <- integer(nrow(t)); t$display_selected <- FALSE
  for (g in sort(unique(as.character(t$cluster)), method = "radix")) {
    ix <- which(t$cluster == g)
    primary <- switch(criterion, adjusted_P_ascending = t$p_val_adj[ix], native_power_descending = -t$my_power[ix], native_rank = t$native_rank[ix])
    secondary <- if (is.null(effect)) rep(0, length(ix)) else -abs(t[[effect]][ix])
    ranked <- ix[order(primary, secondary, t$gene[ix], method = "radix", na.last = TRUE)]
    t$display_rank[ranked] <- seq_along(ranked); t$display_selected[utils::head(ranked, top)] <- TRUE
  }
  selected <- t[t$display_selected, , drop = FALSE]
  selected <- selected[order(selected$cluster, selected$display_rank, selected$gene, method = "radix"), , drop = FALSE]
  list(genes = unique(as.character(selected$gene)), table = t, effect = effect, criterion = criterion,
       rule = "top-n within each native comparison group, then stable first-occurrence gene union; ties by absolute resolved effect then gene ID")
}

os_seurat_markers_figures <- function(r,a,outdir) {
  selection <- .os_seurat_marker_selection(r, a)
  genes <- selection$genes
  if (!length(genes)) return(invisible(NULL))
  mat <- SeuratObject::LayerData(r$object[[r$state$marker_assay]],layer="data")
  grouping <- r$grouping %||% "cluster"
  md <- r$object[[]]
  if (!grouping %in% names(md)) stop("OS_MISSING_COLUMN: core marker grouping is absent from cell metadata.", call. = FALSE)
  if (!setequal(.os_require_ids(rownames(md), "marker metadata cell IDs"), .os_require_ids(colnames(mat), "marker matrix cell IDs")) || !all(genes %in% rownames(mat)))
    stop("OS_INVALID_INPUT: marker plot feature/cell IDs must match native data.", call. = FALSE)
  groups <- as.character(md[match(colnames(mat), rownames(md)), grouping])
  if (anyNA(groups) || any(!nzchar(groups))) stop("OS_INVALID_INPUT: marker grouping labels must be nonmissing.", call. = FALSE)
  d <- do.call(rbind,lapply(sort(unique(groups),method="radix"),function(g) data.frame(gene=genes,cluster=g,avg_exp=log1p(Matrix::rowMeans(expm1(mat[genes,groups==g,drop=FALSE]))),pct_exp=100*Matrix::rowMeans(mat[genes,groups==g,drop=FALSE]>0))))
  d$avg_exp <- ave(d$avg_exp,d$gene,FUN=function(v) { z <- as.numeric(scale(v)); z[!is.finite(z)] <- 0; z })
  p <- os_marker_dotplot(d,scaled=TRUE,mean_definition="log1p_mean_expm1",cluster_n=table(groups),journal=a$journal)
  p <- p + ggplot2::labs(y = grouping)
  p <- os_seurat_caption(p,paste("Descriptive markers; grouping:", grouping, "; top-n per comparison group then union from markers_display;",r$details))
  p <- os_with_meta(p, data = list(marker_selection = selection$table, selected_gene_ids = as.list(genes),
      grouping = grouping, aggregation_cell_ids = as.list(colnames(mat)), selection_rule = selection$rule,
      display_criterion = selection$criterion, effect_column = selection$effect),
      counts = list(requested_per_group = a[["top-n"]], unique_genes_shown = length(genes),
                    selected_per_group = as.list(table(selection$table$cluster[selection$table$display_selected]))))
  os_finalize_figure(p,file.path(outdir,"figures","marker_dotplot"),width="double",journal=a$journal,root=outdir)
  scaled <- SeuratObject::LayerData(r$object[[r$state$marker_assay]],layer="scale.data")
  present <- intersect(genes,rownames(scaled))
  if(length(present)>1) {
    hm <- vapply(sort(unique(groups),method="radix"),function(g) Matrix::rowMeans(scaled[present,groups==g,drop=FALSE]),numeric(length(present)))
    rownames(hm) <- present
    p <- os_heatmap(hm,"Mean scaled expression",scale_type="expression",cluster_rows=FALSE,cluster_cols=FALSE,journal=a$journal)
    p <- os_seurat_caption(p,paste("Selected marker genes; core-group means of native scale.data;",r$details))
    os_finalize_figure(p,file.path(outdir,"figures","marker_heatmap"),width="double",journal=a$journal,root=outdir)
  }

}
os_seurat_modulescore_figures <- function(r,a,outdir) {
  d <- r$tables$scores
  for(nm in unique(d$set)) {
    sub <- d[d$set==nm,,drop=FALSE]
    p <- os_score_violin(sub,"cluster","score",paste(nm,"raw module score"),journal=a$journal)
    p <- os_seurat_caption(p,r$details)
    os_finalize_figure(p,file.path(outdir,"figures",paste0("score_",match(nm,unique(d$set)))),width="double",journal=a$journal,root=outdir)
    xy <- SeuratObject::Embeddings(r$object[["umap"]])[sub$cell,,drop=FALSE]
    emb <- data.frame(x=xy[,1],y=xy[,2],score=sub$score)
    lim <- max(abs(emb$score)); if(lim==0) lim <- 1
    p <- ggplot2::ggplot(emb,ggplot2::aes(x=x,y=y,colour=score)) + ggplot2::geom_point(shape=OS_FIG$shape_dense,size=os_cell_point_mm(nrow(emb)),stroke=0) + ggplot2::scale_colour_gradientn(colours=OS_PAL_DIVERGING,limits=c(-lim,lim),guide=os_guide_colourbar("Raw module score")) + ggplot2::coord_fixed() + ggplot2::labs(title=nm,x="UMAP 1",y="UMAP 2") + theme_omicstat(journal=a$journal)
    p <- os_with_meta(p,figure_type="score_embedding",default_height_mm=70,caption=paste("Raw module score on the unchanged upstream UMAP; no threshold;",r$details),data=list(n_cells=nrow(emb)),encodings=list(colour=list(scale="diverging",palette=as.list(OS_PAL_DIVERGING))))
    os_finalize_figure(p,file.path(outdir,"figures",paste0("score_umap_",match(nm,unique(d$set)))),width="double",journal=a$journal,root=outdir)

  }
}
