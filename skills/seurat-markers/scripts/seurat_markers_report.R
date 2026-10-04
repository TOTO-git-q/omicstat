seurat_markers_render <- function(r,a,outdir) {
 paths <- os_seurat_write_tables(r$tables,outdir)
 os_seurat_markers_figures(r,a,outdir)
 paths
}

seurat_markers_report <- function(r,a,outdir,module,module_dir) {
 dir.create(file.path(outdir,"results"),showWarnings=FALSE)
 tmpl <- os_read_templates(file.path(module_dir,"references","reporting-templates.md"))
 vals <- list(version=as.character(utils::packageVersion("Seurat")),n=ncol(r$object),features=nrow(r$object),parameters=paste(os_canonical_argv(SPEC,a),collapse=" "),details=r$details,significant=sum(r$tables$markers_full$p_val_adj < 0.05,na.rm=TRUE))
 os_write_text(c("# Methods",os_fill_template(tmpl$methods,vals),"","# Results",os_fill_template(tmpl$results,vals),"","Marker-table caption:",sprintf("Native marker table; %d rows with Bonferroni-adjusted P (p_val_adj) < 0.05.",vals$significant)),file.path(outdir,"draft","methods_results.md"))
 jsonlite::write_json(list(module=module,n_cells=ncol(r$object),n_features=nrow(r$object),state=r$state,details=r$details,parameters=a),file.path(outdir,"results","results.json"),auto_unbox=TRUE,pretty=TRUE,null="null",digits=I(10))
}
