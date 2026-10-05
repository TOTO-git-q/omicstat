seurat_markers_render <- function(r,a,outdir) {
 paths <- os_seurat_write_tables(r$tables,outdir)
 os_seurat_markers_figures(r,a,outdir)
 paths
}

seurat_markers_report <- function(r,a,outdir,module,module_dir) {
 dir.create(file.path(outdir,"results"),showWarnings=FALSE)
 tmpl <- os_read_templates(file.path(module_dir,"references","reporting-templates.md"))
 markers <- r$tables$markers_full
 groups <- if("cluster" %in% names(markers)) as.character(markers$cluster) else rep(paste(a[["ident-1"]],"vs",a[["ident-2"]] %||% "rest"),nrow(markers))
 effect <- intersect(c("avg_log2FC","avg_logFC","avg_log10FC","avg_diff","myAUC"),names(markers))[1]
 if(!is.null(a[["fc-name"]])) effect <- os_seurat_option(a,"fc-name",NULL)
 top <- if(nrow(markers)>0 && !is.na(effect) && effect %in% names(markers)) paste(vapply(split(seq_len(nrow(markers)),groups),function(ii) {
   # Seurat PBMC3k tutorial selection: keep the native row order (FindMarkers orders by P value,
   # used here only to rank) and take the first rows with avg_log2FC > 1; ranking by fold change
   # alone would promote genes detected in a handful of cells.
   cut <- if(identical(effect,"avg_log2FC")) 1 else 0
   keep <- ii[!is.na(markers[[effect]][ii]) & markers[[effect]][ii] > cut]
   if(!length(keep)) keep <- ii[!is.na(markers[[effect]][ii]) & markers[[effect]][ii] > 0]
   jj <- head(keep,3)
   paste0("Cluster ",groups[ii[1]],": ",paste(sprintf("%s (%s=%.4g, pct.1=%.3g, pct.2=%.3g)",markers$gene[jj],effect,markers[[effect]][jj],markers$pct.1[jj],markers$pct.2[jj]),collapse="; "))
 },character(1)),collapse=". ") else "No effect-ranked markers available."
 vals <- list(version=as.character(utils::packageVersion("Seurat")),n=ncol(r$object),features=nrow(r$object),parameters=paste(os_canonical_argv(SPEC,a),collapse=" "),details=r$details,rows=nrow(markers),clusters=length(unique(groups)),top_markers=top)
 os_write_text(c("# Methods",os_fill_template(tmpl$methods,vals),"","# Results",os_fill_template(tmpl$results,vals),"","Marker-table caption:",sprintf("Native descriptive marker table; %d rows across %d clusters. Top 3 markers per cluster (native order among rows with %s > %s, as in the Seurat tutorial) with pct.1/pct.2: %s",vals$rows,vals$clusters,effect,if(identical(effect,"avg_log2FC")) "1" else "0",top)),file.path(outdir,"draft","methods_results.md"))
 jsonlite::write_json(list(module=module,n_cells=ncol(r$object),n_features=nrow(r$object),state=r$state,details=r$details,parameters=a),file.path(outdir,"results","results.json"),auto_unbox=TRUE,pretty=TRUE,null="null",digits=I(10))
}
