seurat_qc_render <- function(r,a,outdir) {
 paths <- os_seurat_write_tables(r$tables,outdir)
 os_seurat_qc_figures(r,a,outdir)
 paths
}
