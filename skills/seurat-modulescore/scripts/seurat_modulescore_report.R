seurat_modulescore_render <- function(r,a,outdir) {
 paths <- os_seurat_write_tables(r$tables,outdir)
 os_seurat_modulescore_figures(r,a,outdir)
 paths
}
