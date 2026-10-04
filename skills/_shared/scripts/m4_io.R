# m4_io.R -- neutral matrix hand-offs and common output plumbing.
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
os_m4_input <- function(a, allow_missing = FALSE) {
  u <- if (is.null(a[["from-run"]])) NULL else read_handoff(a[["from-run"]])
  path <- a$input
  if (!is.null(u)) {
    name <- a[["upstream-object"]] %||% "expression_matrix"
    if (is.null(u$objects[[name]])) stop("OS_HANDOFF_MISMATCH: expression object absent.", call. = FALSE)
    if (!u$objects[[name]]$type %in% c("expression_matrix", "batch_corrected_matrix")) stop("OS_HANDOFF_MISMATCH: expected expression_matrix.", call. = FALSE)
    if (u$objects[[name]]$type == "batch_corrected_matrix" || isTRUE(u$batch_corrected_lineage))
      stop("OS_BATCH_CORRECTED_INPUT: corrected expression is not supported for network or infiltration inference.", call. = FALSE)
    path <- u$objects[[name]]$path
    if (!is.null(u$state$input_scale) && !identical(a[["input-scale"]], u$state$input_scale))
      stop("OS_HANDOFF_MISMATCH: declared input scale differs from upstream.", call. = FALSE)
  }
  if (is.null(path)) stop("OS_MISSING_PARAMETER: give --input or --from-run.", call. = FALSE)
  if (allow_missing) {
    df <- .os_read_delim(path)
    if (ncol(df) < 2 || anyNA(df[[1]]) || any(!nzchar(df[[1]])) || anyDuplicated(df[[1]]))
      stop("OS_INVALID_INPUT: unique nonempty feature IDs required.", call. = FALSE)
    num <- lapply(df[-1], function(x) suppressWarnings(as.numeric(x)))
    for (j in seq_along(num)) if (any(is.na(num[[j]]) & !is.na(df[[j + 1]])))
      stop("OS_INVALID_INPUT: nonnumeric expression.", call. = FALSE)
    mat <- matrix(unlist(num), nrow = nrow(df), dimnames = list(df[[1]], names(df)[-1]))
  } else mat <- os_read_matrix(path)
  if (any(is.infinite(mat)) || anyDuplicated(colnames(mat)) || any(!nzchar(colnames(mat))))
    stop("OS_INVALID_INPUT: finite expression and unique sample IDs required.", call. = FALSE)
  list(mat = mat, path = path, upstream = u)
}
os_m4_write_tables <- function(tables, outdir) {
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  for (nm in names(tables)) utils::write.csv(tables[[nm]], file.path(outdir, "tables", paste0(nm, ".csv")), row.names = FALSE)
}
os_m4_draft <- function(module_dir, values, figures, outdir) {
  tm <- os_read_templates(file.path(module_dir, "references", "reporting-templates.md"))
  cap <- vapply(figures, function(f) jsonlite::fromJSON(f$spec)$caption, "")
  os_write_text(c("# Methods", os_fill_template(tm$methods, values), "", "# Results", os_fill_template(tm$results, values),
                  "", "## Figure legends", paste(names(cap), cap, sep = ": ")), file.path(outdir, "draft", "methods_results.md"))
}
