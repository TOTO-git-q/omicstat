seurat_cluster_render <- function(r,a,outdir) {
 paths <- os_seurat_write_tables(r$tables,outdir)
 os_seurat_cluster_figures(r,a,outdir)
 paths
}
