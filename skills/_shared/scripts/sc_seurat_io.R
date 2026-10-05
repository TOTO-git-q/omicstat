# Seurat lane I/O and chain helpers; no scientific defaults are resolved here.
os_seurat_fail <- function(code, text) stop(paste0(code, ": ", text), call. = FALSE)
os_seurat_read <- function(path, from_run = NULL, stage = NULL) {
  h <- if (is.null(from_run)) NULL else read_handoff(from_run, expect = list(seurat = "Seurat"), front_end_ecosystem = "seurat")
  if (!is.null(h)) path <- h$objects$seurat$path
  x <- tryCatch(readRDS(path), error = function(e) os_seurat_fail("OS_INVALID_INPUT", conditionMessage(e)))
  if (!inherits(x, "Seurat")) {
    if (inherits(x, "SingleCellExperiment")) os_seurat_fail("OS_ECOSYSTEM_MIXED", "Seurat front ends cannot continue a Bioconductor chain.")
    os_seurat_fail("OS_INVALID_INPUT", "Expected a Seurat RDS object.")
  }
  st <- x@misc$omicstat_state
  if (isTRUE(st$batch_corrected_lineage)) os_seurat_fail("OS_BATCH_CORRECTED_INPUT", "Object descends from batch-corrected expression.")
  if (is.null(st) || !identical(st$front_end_ecosystem, "seurat")) os_seurat_fail("OS_CHAIN_STATE", "Missing Seurat chain state; start with seurat-qc.")
  if (!is.null(h) && !identical(jsonlite::toJSON(st, auto_unbox=TRUE, null="null"), jsonlite::toJSON(h$state$seurat, auto_unbox=TRUE, null="null"))) os_seurat_fail("OS_CHAIN_STATE", "Object and handoff chain states differ.")
  if (!isTRUE(st$qc_done)) os_seurat_fail("OS_CHAIN_STATE", "QC must precede downstream processing.")
  if (stage == "cluster" && isTRUE(st$clustered)) os_seurat_fail("OS_CHAIN_STATE", "Already clustered; start a new chain for a different clustering analysis.")
  if (stage != "cluster" && (!isTRUE(st$clustered) || !isTRUE(st$normalized))) os_seurat_fail("OS_CHAIN_STATE", "A normalized, clustered upstream object is required.")
  if (isTRUE(st$normalized) && (!st$assay %in% names(x@assays) || !"data" %in% SeuratObject::Layers(x[[st$assay]]))) os_seurat_fail("OS_CHAIN_STATE", "Declared normalized assay is missing.")
  if (isTRUE(st$clustered) && (!"cluster" %in% names(x[[]]) || !st$reduction %in% names(x@reductions) || !"umap" %in% names(x@reductions))) os_seurat_fail("OS_CHAIN_STATE", "Declared clusters or reductions are missing.")
  if (stage == "integrate" && isTRUE(st$integrated)) os_seurat_fail("OS_CHAIN_STATE", "Already integrated.")
  list(object=x, upstream=h, path=path, state=st)
}
os_seurat_counts <- function(path, input_format) {
  if (input_format == "10x") {
    x <- Seurat::Read10X(data.dir=path, gene.column=2, cell.column=1, unique.features=TRUE, strip.suffix=FALSE)
    if (is.list(x)) os_seurat_fail("OS_INVALID_INPUT", "Multimodal 10x input requires selecting RNA before this module.")
  } else if (input_format == "rds") x <- readRDS(path) else x <- os_read_matrix(path, "raw single-cell counts")
  if (!is.matrix(x) && !inherits(x, "Matrix")) os_seurat_fail("OS_INVALID_INPUT", "Expected a raw count matrix.")
  v <- if (inherits(x, "sparseMatrix")) x@x else as.vector(x)
  if (any(!is.finite(v)) || any(v < 0) || any(v != round(v))) os_seurat_fail("OS_INVALID_COUNTS", "Counts must be finite nonnegative integers.")
  if (is.null(rownames(x)) || is.null(colnames(x)) || anyDuplicated(rownames(x)) || anyDuplicated(colnames(x)) || any(!nzchar(rownames(x))) || any(!nzchar(colnames(x)))) os_seurat_fail("OS_INVALID_INPUT", "Feature and cell IDs must be unique and nonempty.")
  if (any(Matrix::colSums(x) == 0)) os_seurat_fail("OS_INVALID_COUNTS", "All-zero cells are not supported.")
  x
}
os_seurat_save <- function(r, a, outdir, module, upstream, tables) {
  obj <- file.path(outdir, "objects"); dir.create(obj, showWarnings=FALSE)
  r$object@misc$omicstat_state <- r$state
  saveRDS(r$object, file.path(obj,"seurat.rds"), version=3)
  md <- data.frame(cell=colnames(r$object),r$object[[]], check.names=FALSE)
  utils::write.csv(md, file.path(obj,"cell_metadata.csv"), row.names=FALSE)
  cr <- if (!is.null(upstream$objects$colour_registry)) os_colour_registry_read(upstream$objects$colour_registry$path) else os_colour_registry_new()
  cr <- os_colours_for(sort(unique(as.character(md$sample)),method="radix"), family="sample", registry=cr)$registry
  if ("cluster" %in% names(md)) cr <- os_colours_for(sort(unique(as.character(md$cluster)),method="radix"), family="cluster", registry=cr)$registry
  os_colour_registry_write(cr,file.path(obj,"colour_registry.json"))
  objects <- list(seurat=list(path=file.path(obj,"seurat.rds"),type="Seurat"),cell_metadata=list(path=file.path(obj,"cell_metadata.csv"),type="cell_metadata"),colour_registry=list(path=file.path(obj,"colour_registry.json"),type="colour_registry"))
  for (nm in names(tables)) objects[[nm]] <- list(path=tables[[nm]],type=if(nm=="feature_table") "feature_table" else "cell_metadata")
  write_handoff(outdir,basename(outdir),module,"1.0.0",objects,contract_hash=upstream$contract_hash %||% NA_character_,ecosystem="seurat",state=list(front_end_ecosystem="seurat",seurat=r$state,batch_corrected_lineage=isTRUE(upstream$state$batch_corrected_lineage)),upstream_runs=upstream$upstream_runs %||% character(0))
}
# Conversion is exclusively delegated to the established conversion contract.
os_seurat_convert <- function(x, to, layers, cluster_col, file=NULL, x_role=NULL) {
  os_sc_convert(x=x,to=to,consumer="back_end",layers=layers,cluster_col=cluster_col,source_assay=x@misc$omicstat_state$assay,target_assay=NULL,file=file,x_role=x_role)
}
os_seurat_write_tables <- function(tables,outdir) {
  d <- file.path(outdir,"tables"); dir.create(d,showWarnings=FALSE)
  paths <- list()
  for(nm in names(tables)) { paths[[nm]] <- file.path(d,paste0(nm,".csv")); utils::write.csv(tables[[nm]],paths[[nm]],row.names=FALSE,na="") }
  paths
}
os_seurat_report <- function(r,a,outdir,module,module_dir) {
  dir.create(file.path(outdir,"results"),showWarnings=FALSE)
  tmpl <- os_read_templates(file.path(module_dir,"references","reporting-templates.md"))
  vals <- list(version=as.character(utils::packageVersion("Seurat")), n=ncol(r$object), features=nrow(r$object), parameters=paste(os_canonical_argv(SPEC,a),collapse=" "), details=r$details)
  os_write_text(c("# Methods",os_fill_template(tmpl$methods,vals),"","# Results",os_fill_template(tmpl$results,vals)),file.path(outdir,"draft","methods_results.md"))
  jsonlite::write_json(list(module=module,n_cells=ncol(r$object),n_features=nrow(r$object),state=r$state,details=r$details,parameters=a),file.path(outdir,"results","results.json"),auto_unbox=TRUE,pretty=TRUE,null="null",digits=I(10))
}
# Advanced CLI options are JSON values, never evaluated R code.
os_seurat_option <- function(a, name, default) {
 if(is.null(a[[name]])) return(default)
 v <- jsonlite::fromJSON(a[[name]])
 if(is.character(v) && length(v)==1L && v %in% c("Inf","-Inf")) return(as.numeric(v))
 v
}
