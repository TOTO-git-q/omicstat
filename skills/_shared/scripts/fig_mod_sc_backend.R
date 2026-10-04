# fig_mod_sc_backend.R -- neutral backend builders; source after fig_all.R.
# ---- singler-annotate ----
os_singler_score_heatmap <- function(scores, labels, nmads, journal, min.diff.med = -Inf, min.diff.next = 0) {
  # Per-cell [0,1] relative-score display; native renderer comparison pending.
  m <- t(scores)
  lo <- apply(m, 2L, min); hi <- apply(m, 2L, max)
  span <- hi - lo; span[span == 0] <- 1
  m <- sweep(sweep(m, 2L, lo, "-"), 2L, span, "/")
  ord <- order(labels, colnames(m), method = "radix")
  p <- os_heatmap(m[, ord, drop = FALSE], value_title = "Relative score", scale_type = "sequential",
                  cluster_rows = FALSE, cluster_cols = FALSE, show_col_labels = FALSE,
                  italic_rows = FALSE, limits = c(0, 1), journal = journal)
  os_with_meta(p, figure_type = "singler_scores", caption = sprintf("SingleR relative scores for %d cells/units and %d reference labels. Per-unit scores rescaled to [0,1]; columns ordered by assigned label, then ID. Pruning: nmads = %s, min.diff.med = %s, min.diff.next = %s. No score display cutoff.", ncol(m), nrow(m), nmads, min.diff.med, min.diff.next),
               thresholds = list(min.diff.med=min.diff.med,min.diff.next=min.diff.next,nmads = nmads, score_cutoff = "none"), counts = list(units = ncol(m), labels = nrow(m)))
}
os_singler_crosstab <- function(tab, n_cells, nmads, journal, min.diff.med = -Inf, min.diff.next = 0) {
  p <- os_heatmap(tab, value_title = "Cells", scale_type = "sequential", cluster_rows = FALSE,
                  cluster_cols = FALSE, italic_rows = FALSE, journal = journal)
  os_with_meta(p, figure_type = "singler_crosstab", caption = sprintf("Cross-tabulation of %d source cells by cluster and pruned SingleR label; unassigned includes labels removed with nmads = %s, min.diff.med = %s, min.diff.next = %s. Counts, without a display cutoff.", n_cells, nmads, min.diff.med, min.diff.next), thresholds = list(min.diff.med=min.diff.med,min.diff.next=min.diff.next,nmads = nmads), counts = list(cells = n_cells))
}
# ---- muscat-pseudobulk ----
os_muscat_volcano <- function(tab, fdr, lfc, contrast, journal) {
  ft <- data.frame(feature_id=tab$gene,log2fc=tab$logFC,padj=tab$p_adj.loc)
  p <- os_volcano(ft,padj_threshold=fdr,lfc_threshold=lfc,label_n=5,
    contrast_label=contrast,method_label='muscat pseudobulk; within-cluster FDR',journal=journal)
  os_with_meta(p,caption=paste0(attr(p,'omicstat_meta')$caption %||% '',
    sprintf(' %d gene tests; within-cluster adjusted P display cutoff = %s; absolute logFC display cutoff = %s. Display only.',nrow(ft),fdr,lfc)),
    counts=list(genes=nrow(ft)),thresholds=list(fdr=fdr,logFC=lfc))
}
# ---- slingshot-trajectory / monocle3-trajectory ----
os_backend_trajectory <- function(rd, pt, curves=NULL, reduction='UMAP', journal=NULL) {
  finite <- is.finite(pt[,1]); d <- data.frame(x=rd[,1],y=rd[,2],pseudotime=pt[,1])
  d$pseudotime[!finite] <- NA_real_
  p <- ggplot2::ggplot(d,ggplot2::aes(x=x,y=y,colour=pseudotime)) +
    ggplot2::geom_point(size=os_cell_point_mm(nrow(d)),shape=OS_FIG$shape_dense,stroke=0) +
    ggplot2::scale_colour_gradientn(colours=OS_PAL_EXPRESSION,na.value=OS_FIG$col_ns) +
    ggplot2::labs(x=paste(reduction,'1'),y=paste(reduction,'2'),colour='Pseudotime') + theme_omicstat(journal=journal)
  if(!is.null(curves)) for(cv in curves) {
    xy <- if(is.list(cv)) cv$s[cv$ord,,drop=FALSE] else cv
    p <- p + ggplot2::geom_path(data=data.frame(x=xy[,1],y=xy[,2]),ggplot2::aes(x=x,y=y),inherit.aes=FALSE,colour=OS_FIG$col_ink,linewidth=os_lw(OS_FIG$lw_segment))
  }
  os_with_meta(p,figure_type='trajectory',default_height_mm=90,
    caption=sprintf('%d cells on existing %s coordinates with inferred trajectory. Colour shows lineage 1 pseudotime; %d cells have finite lineage 1 values, %d missing/unreachable cells are grey. All lineage values are retained in the table. No display cutoff.',nrow(d),reduction,sum(finite),sum(!finite)),
    counts=list(cells=nrow(d),finite=sum(finite)),thresholds=list(display_cutoff='none'))
}
# ---- cellchat-communication ----
os_backend_communication_heatmap <- function(weight,n_cells,threshold,journal) {
  p<-os_heatmap(weight,value_title='Summed probability',scale_type='sequential',cluster_rows=FALSE,cluster_cols=FALSE,italic_rows=FALSE,journal=journal)
  os_with_meta(p,figure_type='communication_heatmap',caption=sprintf('Inferred communication across %d cell groups, %d cells. Rows are senders and columns receivers; colour is summed LR probability. Network aggregation P cutoff = %s. Transcriptomic inference, not physical signalling.',nrow(weight),n_cells,threshold),counts=list(cells=n_cells,groups=nrow(weight)),thresholds=list(p=threshold))
}
os_backend_communication_circle <- function(weight,n_cells,threshold,journal) {
  lv<-rownames(weight);theta<-seq(0,2*pi,length.out=length(lv)+1)[-1]
  nodes<-data.frame(group=lv,x=cos(theta),y=sin(theta))
  edges<-as.data.frame(as.table(weight));names(edges)<-c('source','target','weight')
  edges<-edges[edges$weight>0,]
  edges$x<-nodes$x[match(edges$source,lv)];edges$y<-nodes$y[match(edges$source,lv)]
  edges$xend<-nodes$x[match(edges$target,lv)];edges$yend<-nodes$y[match(edges$target,lv)]
  between<-edges[edges$source!=edges$target,]
  # Leave node-radius clearance so directed arrowheads are visible.
  dx<-between$xend-between$x;dy<-between$yend-between$y;len<-sqrt(dx^2+dy^2)
  between$x<-between$x+0.08*dx/len;between$y<-between$y+0.08*dy/len
  between$xend<-between$xend-0.08*dx/len;between$yend<-between$yend-0.08*dy/len
  p<-ggplot2::ggplot() + ggplot2::geom_curve(data=between,ggplot2::aes(x=x,y=y,xend=xend,yend=yend,linewidth=weight),curvature=0.15,colour=OS_FIG$col_ns,arrow=grid::arrow(length=grid::unit(1.5,'mm'),type='closed')) +
    ggplot2::scale_linewidth_continuous(range=c(os_lw(OS_FIG$lw_segment),os_lw(OS_FIG$lw_axis)*3),name='Summed probability') +
    ggplot2::geom_point(data=nodes,ggplot2::aes(x=x,y=y),size=3,colour=OS_FIG$col_ink) +
    ggplot2::geom_text(data=nodes,ggplot2::aes(x=1.2*x,y=1.2*y,label=group),family=os_font_family(),size=os_fs(OS_FIG$size_annot)) +
    ggplot2::coord_fixed(xlim=c(-1.7,1.7),ylim=c(-1.4,1.4),clip='off') +theme_omicstat(journal=journal,axes='none')
  os_with_meta(p,figure_type='communication_circle',default_height_mm=110,caption=sprintf('Directed inferred between-group communication network for %d cells and %d groups. Arrow is sender to receiver; line width is summed LR probability at aggregation P < %s. Autocrine self-edges (%d) remain in the accompanying heatmap and native tables. Equal node size; no cell abundance encoding.',n_cells,nrow(weight),threshold,sum(edges$source==edges$target)),counts=list(cells=n_cells,groups=nrow(weight)),thresholds=list(p=threshold))
}
