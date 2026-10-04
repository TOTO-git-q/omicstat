# fig_mod_sc_bioc.R -- lane-owned figures; presentation tokens stay shared.
os_bioc_scatter <- function(d, x, y, group, caption, registry = NULL, journal = NULL, thresholds = NULL) {
  lv <- sort(unique(as.character(d[[group]])), method = "radix")
  cr <- os_colours_for(lv, family = group, registry = registry)
  d$.x <- d[[x]]; d$.y <- d[[y]]; d$.g <- factor(d[[group]], levels = lv)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .x, y = .y, colour = .g)) +
    ggplot2::geom_point(size = os_cell_point_mm(nrow(d)), shape = OS_FIG$shape_dense, stroke = 0) +
    ggplot2::scale_colour_manual(values = cr$colours, name = group) +
    ggplot2::labs(x = switch(x, sum = "Total counts", mean = "Mean log2 expression", x),
                   y = switch(y, detected = "Detected genes", subsets_Mito_percent = "Mitochondrial counts (%)", total = "Total variance", y)) + theme_omicstat(journal = journal)
  if (!is.null(thresholds)) {
    if (x == "sum") p <- p + os_vline(unique(thresholds$lower[thresholds$metric == "low_lib_size" & is.finite(thresholds$lower)]))
    key <- if (y == "detected") "low_n_features" else if (y == "subsets_Mito_percent") "high_subsets_Mito_percent" else ""
    if (nzchar(key)) {
      val <- if (y == "detected") thresholds$lower else thresholds$higher
      p <- p + os_hline(unique(val[thresholds$metric == key & is.finite(val)]))
    }
  }
  os_with_meta(p, figure_type = "bioc_scatter", default_height_mm = 80,
               caption = caption, data = list(n_cells = nrow(d)), colour_registry = cr$registry,
               encodings = list(colour = as.list(cr$colours)))
}
os_bioc_embedding <- function(d, group, caption, registry = NULL, journal = NULL) {
  p <- os_embedding(d, group_col = group, label = FALSE, colour_registry = registry,
                    family = group, reduction = "UMAP", journal = journal)
  os_with_meta(p, caption = caption)
}
os_bioc_marker_heatmap <- function(expr, groups, journal) {
  os_stacked_violin(expr, groups, fill = "median", value_title = "log2 normalized expression",
                    italic = FALSE, journal = journal)
}
os_bioc_qc_violin <- function(d, bounds, caption, journal) {
  d$sample <- d$batch
  thresholds <- list(sum = unique(bounds$lower[bounds$metric == "low_lib_size"]),
    detected = unique(bounds$lower[bounds$metric == "low_n_features"]),
    subsets_Mito_percent = unique(bounds$higher[bounds$metric == "high_subsets_Mito_percent"]))
  p <- os_qc_violin(d, metrics = c("sum", "detected", "subsets_Mito_percent"),
    thresholds = thresholds, metric_labels = c(sum = "Total counts", detected = "Detected genes", subsets_Mito_percent = "Mitochondrial counts (%)"),
    log10_metrics = c("sum", "detected"), journal = journal)
  os_with_meta(p, caption = caption)
}
os_bioc_elbow <- function(d, pcs, n, journal) {
  p <- ggplot2::ggplot(d, ggplot2::aes(x = PC, y = variance)) +
    ggplot2::geom_line(colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::geom_point(colour = OS_FIG$col_ink, size = OS_FIG$pt_dense_mm) +
    ggplot2::labs(x = "Principal component", y = "Variance explained") + theme_omicstat(journal = journal)
  os_with_meta(p, figure_type = "pca_elbow", default_height_mm = 70,
    caption = sprintf("PCA variance for %d cells; %d PCs explicitly retained. No automatic elbow selection.", n, pcs), data = list(n_cells = n))
}
os_bioc_dot <- function(d, top, rank, n, journal) {
 p<-os_marker_dotplot(d,scaled=FALSE,mean_definition="log_mean",journal=journal)
 os_with_meta(p,caption=sprintf("Cluster markers in %d cells; top %d per cluster by %s; colour is mean log2 normalized expression, size is detected cells (%%). No significance cutoff. Descriptive cluster comparisons, not condition inference.",n,top,rank))
}
os_bioc_heatmap <- function(mat, top, rank, n, journal) {
 p<-os_heatmap(mat,value_title="Mean log2 expression",scale_type="expression",italic_rows=FALSE,journal=journal)
 os_with_meta(p,caption=sprintf("Mean original logcounts by cluster for %d cells; top %d markers per cluster by %s. No significance cutoff; descriptive cluster comparison.",n,top,rank))
}
os_bioc_auc_violin <- function(d, maxrank, journal) {
 p<-ggplot2::ggplot(d,ggplot2::aes(x=cluster,y=AUC))+
  ggplot2::geom_violin(fill=OS_FIG$col_ink,colour=OS_FIG$col_ink,linewidth=os_lw(OS_FIG$lw_segment))+
  ggplot2::facet_wrap(~gene_set,scales="free_y")+ggplot2::labs(x="Cluster",y="AUCell AUC")+theme_omicstat(journal=journal)
 os_with_meta(p,figure_type="aucell_distributions",default_height_mm=110,
 caption=sprintf("AUCell distributions for %d cells and %d gene sets; aucMaxRank=%d. No activity cutoff or significance test.",length(unique(d$cell)),length(unique(d$gene_set)),maxrank),data=list(n_cells=length(unique(d$cell))))
}
os_bioc_auc_heatmap <- function(mat,n,maxrank,journal){
 p<-os_heatmap(mat,value_title="Mean AUCell AUC",scale_type="sequential",italic_rows=FALSE,journal=journal)
 os_with_meta(p,caption=sprintf("Mean AUCell AUC by cluster for %d cells; aucMaxRank=%d; no activity threshold or significance test.",n,maxrank))
}
