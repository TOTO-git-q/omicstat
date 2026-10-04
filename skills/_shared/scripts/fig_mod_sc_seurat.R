# Seurat lane figure builders: established style and finalizer only.
os_seurat_caption <- function(p,text) {
  m <- attr(p,"omicstat_meta"); if(is.null(m)) m <- attr(p,"os_meta")
  # os_with_meta merges supplied metadata into existing figure metadata.
  os_with_meta(p, caption=paste(attr(p,"os_meta")$caption,text))
}
os_seurat_qc_figures <- function(r,a,outdir) {
  th <- list(nFeature_RNA=c(a[["min-features"]],a[["max-features"]]),nCount_RNA=c(a[["min-counts"]],a[["max-counts"]]),percent.mt=a[["max-mito"]])
  draw_th <- lapply(names(th),function(nm) th[[nm]][th[[nm]]>=min(r$tables$cell_qc[[nm]]) & th[[nm]]<=max(r$tables$cell_qc[[nm]])]); names(draw_th) <- names(th)
  p <- os_qc_violin(r$tables$cell_qc,metrics=names(th),thresholds=draw_th,metric_labels=c(nFeature_RNA="Detected genes",nCount_RNA="UMI count",percent.mt="Mitochondrial (%)"),journal=a$journal)
  p <- os_seurat_caption(p,r$details)
  os_finalize_figure(p,file.path(outdir,"figures","qc_metrics"),width="double",journal=a$journal,root=outdir)
  for(metric in c("percent.mt","nFeature_RNA")) {
    d <- r$tables$cell_qc
    p <- ggplot2::ggplot(d,ggplot2::aes(x=nCount_RNA,y=.data[[metric]])) + ggplot2::geom_point(colour=OS_FIG$col_ns,size=os_cell_point_mm(nrow(d)),shape=OS_FIG$shape_dense,stroke=0) + ggplot2::labs(x="UMI count",y=if(metric=="percent.mt") "Mitochondrial (%)" else "Detected genes") + theme_omicstat(journal=a$journal)
    if(length(draw_th[[metric]])) p <- p + os_hline(draw_th[[metric]])
    p <- os_with_meta(p,figure_type="qc_scatter",default_height_mm=70,caption=paste("Per-cell QC scatterplot;",r$details,"Limits outside the data range are recorded here and omitted from the axes."),thresholds=th,data=list(n_cells=nrow(d)))
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
os_seurat_markers_figures <- function(r,a,outdir) {
  if(!nrow(r$tables$markers_full)) return(invisible(NULL))
  t <- r$tables$markers_full
  effect <- grep("^avg_",names(t),value=TRUE)[1]
  ord <- if("p_val_adj" %in% names(t) && !is.na(effect)) order(t$p_val_adj,-abs(t[[effect]]),method="radix") else if("my_power" %in% names(t)) order(-t$my_power,method="radix") else seq_len(nrow(t))
  genes <- unique(utils::head(t$gene[ord],a[["top-n"]]))
  mat <- SeuratObject::LayerData(r$object[[r$state$marker_assay]],layer="data")
  groups <- as.character(r$object$cluster)
  d <- do.call(rbind,lapply(sort(unique(groups),method="radix"),function(g) data.frame(gene=genes,cluster=g,avg_exp=log1p(Matrix::rowMeans(expm1(mat[genes,groups==g,drop=FALSE]))),pct_exp=100*Matrix::rowMeans(mat[genes,groups==g,drop=FALSE]>0))))
  d$avg_exp <- ave(d$avg_exp,d$gene,FUN=function(v) { z <- as.numeric(scale(v)); z[!is.finite(z)] <- 0; z })
  p <- os_marker_dotplot(d,scaled=TRUE,mean_definition="log1p_mean_expm1",cluster_n=table(groups),journal=a$journal)
  p <- os_seurat_caption(p,paste("Descriptive cluster markers;",r$details))
  os_finalize_figure(p,file.path(outdir,"figures","marker_dotplot"),width="double",journal=a$journal,root=outdir)
  scaled <- SeuratObject::LayerData(r$object[[r$state$marker_assay]],layer="scale.data")
  present <- intersect(genes,rownames(scaled))
  if(length(present)>1) {
    hm <- vapply(sort(unique(groups),method="radix"),function(g) Matrix::rowMeans(scaled[present,groups==g,drop=FALSE]),numeric(length(present)))
    rownames(hm) <- present
    p <- os_heatmap(hm,"Mean scaled expression",scale_type="expression",cluster_rows=FALSE,cluster_cols=FALSE,journal=a$journal)
    p <- os_seurat_caption(p,paste("Selected marker genes; cluster means of native scale.data;",r$details))
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
