seurat_markers_mean <- function(a) {
 if(is.null(a[["markers-mean-fxn"]])) return(NULL)
 parts <- strsplit(a[["markers-mean-fxn"]],"::",fixed=TRUE)[[1]]
 if(length(parts)!=2L) stop("Supply package::function for --markers-mean-fxn")
 getExportedValue(parts[1],parts[2])
}
seurat_markers_group_guard <- function(x,a) {
 column <- os_seurat_option(a,"group-by",NULL)
 if(is.null(column) || identical(column,"ident")) column <- "cluster"
 md <- x[[]]
 if(length(column)!=1L || !column %in% names(md)) os_seurat_fail("OS_MISSING_COLUMN","Marker grouping column is missing.")
 values <- as.character(md[[column]])
 if(anyNA(values) || any(!nzchar(values))) os_seurat_fail("OS_INVALID_INPUT","Marker grouping labels must be nonmissing and nonempty.")
 if(!"sample" %in% names(md)) {
   if(column!="cluster") os_seurat_fail("OS_PSEUDOREPLICATION",sprintf("Grouping column '%s' needs a sample column to verify that the grouping is cell-level; use muscat-pseudobulk for expression or speckle-propeller for proportions.",column))
 } else {
   sample <- as.character(md$sample)
   if(anyNA(sample) || any(!nzchar(sample))) os_seurat_fail("OS_INVALID_INPUT","Sample labels must be nonmissing and nonempty.")
   if(column=="sample" || all(vapply(split(values,sample),function(z) length(unique(z))==1L,logical(1)))) os_seurat_fail("OS_PSEUDOREPLICATION",sprintf("Grouping column '%s' is sample-level; use muscat-pseudobulk for expression or speckle-propeller for proportions, where samples are replicates.",column))
 }
 column
}
SM_MODULE_VERSION <- "1.0.0"
seurat_markers_compute <- function(x,a) {
 grouping <- seurat_markers_group_guard(x,a)
 assay <- x@misc$omicstat_state$assay
 if(!is.null(a$assay)) assay <- a$assay
 SeuratObject::Idents(x) <- x$cluster
 if(a$mode=="all") { markers <- Seurat::FindAllMarkers(assay=assay, features=os_seurat_option(a,"features",NULL), group.by=os_seurat_option(a,"group-by",NULL), logfc.threshold=a[["logfc-threshold"]], test.use=a$test, slot=os_seurat_option(a,"slot","data"), min.pct=a[["min-pct"]], min.diff.pct=os_seurat_option(a,"markers-min-diff-pct",-Inf), node=os_seurat_option(a,"node",NULL), verbose=FALSE, only.pos=os_seurat_option(a,"markers-only-pos",identical(a[["only-pos"]],"true")), max.cells.per.ident=os_seurat_option(a,"markers-max-cells-per-ident",Inf), random.seed=a$seed, latent.vars=os_seurat_option(a,"markers-latent-vars",NULL), min.cells.feature=os_seurat_option(a,"markers-min-cells-feature",3), min.cells.group=os_seurat_option(a,"markers-min-cells-group",3), mean.fxn=seurat_markers_mean(a), fc.name=os_seurat_option(a,"fc-name",NULL), base=os_seurat_option(a,"markers-base",2), return.thresh=a[["return-thresh"]], densify=os_seurat_option(a,"markers-densify",FALSE), object=x, fc.slot=os_seurat_option(a,"fc-slot","data"), pseudocount.use=os_seurat_option(a,"pseudocount-use",1), recorrect_umi=os_seurat_option(a,"recorrect-umi",TRUE)) } else {
   if(is.null(a[["ident-1"]])) os_seurat_fail("OS_MISSING_PARAMETER","Contrast mode requires --ident-1.")
   markers <- Seurat::FindMarkers(base=os_seurat_option(a,"markers-base",2), mean.fxn=seurat_markers_mean(a), ident.1=strsplit(a[["ident-1"]],",",fixed=TRUE)[[1]], ident.2=if(is.null(a[["ident-2"]])) NULL else strsplit(a[["ident-2"]],",",fixed=TRUE)[[1]], latent.vars=os_seurat_option(a,"contrast-latent-vars",NULL), group.by=os_seurat_option(a,"group-by",NULL), subset.ident=os_seurat_option(a,"subset-ident",NULL), assay=assay, reduction=NULL, object=x, test.use=a$test, logfc.threshold=a[["logfc-threshold"]], min.pct=a[["min-pct"]], only.pos=os_seurat_option(a,"contrast-only-pos",identical(a[["only-pos"]],"true")), random.seed=a$seed, verbose=FALSE, min.diff.pct=os_seurat_option(a,"contrast-min-diff-pct",-Inf), max.cells.per.ident=os_seurat_option(a,"contrast-max-cells-per-ident",Inf), min.cells.feature=os_seurat_option(a,"contrast-min-cells-feature",3), min.cells.group=os_seurat_option(a,"contrast-min-cells-group",3), densify=os_seurat_option(a,"contrast-densify",FALSE), features=os_seurat_option(a,"features",NULL), slot=os_seurat_option(a,"slot","data"), fc.name=os_seurat_option(a,"fc-name",NULL), fc.slot=os_seurat_option(a,"fc-slot","data"), pseudocount.use=os_seurat_option(a,"pseudocount-use",1), recorrect_umi=os_seurat_option(a,"recorrect-umi",TRUE))
 }
 if(a$mode=="contrast") {
   markers$gene <- rownames(markers)
 }
 display <- markers
 if("avg_log2FC" %in% names(display)) display <- display[abs(display$avg_log2FC)>=a[["display-lfc-filter"]],,drop=FALSE]
 st <- x@misc$omicstat_state; st$marker_assay <- assay; st$native_controls <- list(base=os_seurat_option(a,"markers-base",2),mean.fxn=a[["markers-mean-fxn"]],test.use=a$test,min.pct=a[["min-pct"]],logfc.threshold=a[["logfc-threshold"]])
 details <- sprintf("n=%d cells; assay=%s; native %s test, mode=%s, logfc.threshold=%g, min.pct=%g, only.pos=%s, return.thresh=%g; separate display |log2FC| filter=%g; descriptive cluster comparison, not condition inference.",ncol(x),assay,a$test,a$mode,a[["logfc-threshold"]],a[["min-pct"]],a[["only-pos"]],a[["return-thresh"]],a[["display-lfc-filter"]])
 details <- paste(details, sprintf("Fold-change base=%s; mean.fxn=%s. p_val_adj is a Bonferroni correction over all features in the dataset. %s",st$native_controls$base,a[["markers-mean-fxn"]] %||% "NULL",if(a$test=="wilcox" && requireNamespace("presto",quietly=TRUE)) "Seurat delegates the Wilcoxon test to presto (installed)." else ""))
 details <- paste(details,"P values are computed with cells as observations on clusters defined from the same data. They rank genes within this descriptive comparison and are not evidence of differential expression between biological groups.")
 details <- paste(details,"Resolved marker controls:",jsonlite::toJSON(st$native_controls,auto_unbox=TRUE,null="null"))
 list(object=x,state=st,grouping=grouping,tables=list(markers_full=markers,markers_display=display),details=details)
}
