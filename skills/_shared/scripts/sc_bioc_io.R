# sc_bioc_io.R -- lane-owned SCE input, state and output helpers.
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
os_bioc_input <- function(a, module, scoring = FALSE) {
  h <- if (is.null(a[["from-run"]])) NULL else read_handoff(a[["from-run"]], front_end_ecosystem = if (scoring) NULL else "bioconductor")
  entry <- a$input
  if (!is.null(h)) {
    nn <- names(h$objects)[vapply(h$objects, function(o) o$type %in% names(OS_SC_TYPES), logical(1))]
    if (length(nn) != 1L) stop("OS_HANDOFF_MISMATCH: expected exactly one single-cell object.", call. = FALSE)
    entry <- h$objects[[nn]]
  }
  if (is.null(entry)) stop("OS_MISSING_PARAMETER: give --input or --from-run.", call. = FALSE)
  src <- .os_sc_source(entry)
  embedded <- .os_sc_embedded_state(src)
  if (!scoring && src$type != "SingleCellExperiment") stop("OS_ECOSYSTEM_MIXED: Bioconductor front ends require an SCE.", call. = FALSE)
  step <- NULL
  if (scoring && src$type != "SingleCellExperiment") {
    if (is.null(a[["logcounts-layer"]]) || is.null(a[["counts-layer"]]) || is.null(a[["cluster-col"]]))
      stop("OS_MISSING_PARAMETER: conversion requires explicit counts/logcounts layers and cluster column.", call. = FALSE)
    cv <- os_sc_convert(entry, to = "SingleCellExperiment", consumer = "back_end",
                        layers = c(counts = a[["counts-layer"]], logcounts = a[["logcounts-layer"]]),
                        cluster_col = a[["cluster-col"]], source_assay = a[["source-assay"]])
    sce <- cv$object; step <- cv$step
  } else sce <- src$object
  .os_sc_check_ids(colnames(sce), rownames(sce))
  an <- SummarizedExperiment::assayNames(sce)
  if (!"counts" %in% an) stop("OS_INVALID_INPUT: SCE requires counts assay.", call. = FALSE)
  m <- SummarizedExperiment::assay(sce, "counts")
  if (any(!is.finite(m)) || any(m < 0)) stop("OS_INVALID_INPUT: counts must be finite nonnegative values.", call. = FALSE)
  if (ncol(sce) < 2 || nrow(sce) < 2) stop("OS_INVALID_INPUT: at least two cells and features required.", call. = FALSE)
  state <- embedded
  if (!is.null(h)) {
    for (k in intersect(names(state), names(h$state))) if (!identical(state[[k]], h$state[[k]]))
      stop(sprintf("OS_HANDOFF_MISMATCH: object and handoff disagree on state %s.", k), call. = FALSE)
    state <- utils::modifyList(state, h$state)
  }
  if (!scoring && isTRUE(state$batch_corrected_lineage)) stop("OS_BATCH_CORRECTED_INPUT: object descends from batch-corrected expression.", call. = FALSE)
  if (!scoring && !is.null(state$front_end_ecosystem) && state$front_end_ecosystem != "bioconductor")
    stop("OS_ECOSYSTEM_MIXED: object metadata records a different front-end ecosystem.", call. = FALSE)
  if (module != "scater-qc" && !scoring && !isTRUE(state$qc_complete)) stop("OS_HANDOFF_MISMATCH: run scater-qc first (qc_complete missing).", call. = FALSE)
  if ((module %in% c("batchelor-integrate", "scran-markers") || scoring) && !"logcounts" %in% an)
    stop("OS_INVALID_INPUT: normalized logcounts assay required.", call. = FALSE)
  list(sce = sce, upstream = h, state = state, path = src$path, conversion = step,
       colours = if (!is.null(h$objects$colour_registry)) os_colour_registry_read(h$objects$colour_registry$path) else NULL)
}
os_bioc_column <- function(sce, name) {
  if (is.null(name) || !name %in% colnames(SummarizedExperiment::colData(sce))) stop("OS_MISSING_COLUMN: required cell metadata column absent.", call. = FALSE)
  x <- SummarizedExperiment::colData(sce)[[name]]
  if (anyNA(x) || any(!nzchar(as.character(x)))) stop("OS_INVALID_INPUT: metadata labels must be nonmissing and nonempty.", call. = FALSE)
  x
}
os_bioc_write <- function(r, input, a, module, version, extra_objects = list()) {
  obj <- file.path(a$outdir, "objects"); dir.create(obj, recursive = TRUE, showWarnings = FALSE)
  state <- utils::modifyList(input$state, r$state)
  if (module != "aucell-score") state$front_end_ecosystem <- "bioconductor"
  if (!is.null(input$upstream)) state$front_end_ecosystem <- os_sc_chain_state(input$upstream)$front_end_ecosystem
  dir.create(file.path(a$outdir,"results"),recursive=TRUE,showWarnings=FALSE)
  jsonlite::write_json(list(n_cells=ncol(r$sce), n_features=nrow(r$sce), n_input_gene_sets=if(is.null(r$sets_table)) NULL else nrow(r$sets_table), n_gene_sets=if(is.null(r$auc)) NULL else nrow(AUCell::getAUC(r$auc)), state=state, parameters=a[setdiff(names(a),c("help","outdir","spec"))], native_args=os_bioc_resolved_native(a)),file.path(a$outdir,"results","analysis_summary.json"),auto_unbox=TRUE,pretty=TRUE,null="null",digits=NA)
  S4Vectors::metadata(r$sce)$omicstat <- state
  saveRDS(r$sce, file.path(obj, "sce.rds"), version = 3)
  os_colour_registry_write(r$colours %||% input$colours %||% os_colour_registry_new(), file.path(obj, "colour_registry.json"))
  write_handoff(a$outdir, run_id = basename(a$outdir), module = module, module_version = version,
                objects = c(list(sce = list(path = file.path(obj, "sce.rds"), type = "SingleCellExperiment"),
                                 colour_registry = list(path = file.path(obj, "colour_registry.json"), type = "colour_registry")), extra_objects),
                ecosystem = if (module == "aucell-score") "neutral" else "bioconductor", state = state,
                contract_hash = input$upstream$contract_hash %||% NA_character_,
                upstream_runs = input$upstream$upstream_runs %||% character(0))
}
# Supplementary native parameters: no custom statistical implementation.
os_bioc_native_args <- function(path) {
  if (is.null(path)) return(list())
  z <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  if (!is.list(z) || is.null(names(z))) stop("OS_INVALID_INPUT: native args must be a named JSON object.", call. = FALSE)
  z
}
os_bioc_call <- function(fun, path = NULL, ...) {
  primary <- list(...)
  extra <- os_bioc_native_args(path)
  overlap <- intersect(names(primary),names(extra))
  if (length(overlap)) stop(sprintf("OS_CONFLICTING_PARAMETERS: supplementary native arguments cannot replace protected inputs or explicit controls: %s.",paste(overlap,collapse=", ")),call.=FALSE)
  do.call(fun, c(primary, extra))
}
os_bioc_table <- function(d, outdir, name) {
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(d, file.path(outdir, "tables", paste0(name, ".csv")), row.names = FALSE)
}
os_bioc_resolved_native <- function(a) {
  nn <- grep("-args$", names(a), value = TRUE)
  stats::setNames(lapply(nn, function(k) os_bioc_native_args(a[[k]])), nn)
}
os_bioc_provenance_inputs <- function(i, a) {
  nn <- names(a)[vapply(a, function(x) is.character(x) && length(x) == 1 && file.exists(x) && !dir.exists(x), logical(1))]
  c(list(sce = i$path), a[nn])
}
os_bioc_methods <- function(a, module, packages, functions) {
  versions <- paste(vapply(packages, function(p) paste(p, utils::packageVersion(p)), ""), collapse = "; ")
  opt <- a[setdiff(names(a), c("help", "outdir", "spec"))]
  os_write_text(c(sprintf("Analysis used %s. Functions: %s.", versions, paste(functions, collapse = ", ")),
    "Actual resolved options:", jsonlite::toJSON(opt, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    "Supplementary native arguments (omitted entries use locked defaults):", jsonlite::toJSON(os_bioc_resolved_native(a), auto_unbox = TRUE, pretty = TRUE)),
    file.path(a$outdir, "draft", "methods_results.md"))
}
