seurat_integrate_render <- function(r,a,outdir) {
 paths <- os_seurat_write_tables(r$tables,outdir)
 os_seurat_integrate_figures(r,a,outdir)
 paths
}
