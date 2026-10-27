# Read-only registered input verification for canonical QC acceptance adapters.
# No downloads, package installs, scientific threshold defaults or model calls.
owner_qc_sources <- function(root, module, dataset_id) {
  registry <- jsonlite::fromJSON(file.path(root, "acceptance/data/owner_review_datasets.json"), simplifyVector = FALSE)
  stopifnot(identical(registry$schema, "omicstat.owner-review-datasets.v1"))
  for (path in names(registry$registration_files_sha256)) {
    full <- file.path(root, path)
    if (!file.exists(full) || !identical(digest::digest(file = full, algo = "sha256"), registry$registration_files_sha256[[path]]))
      stop(paste("OS_ANCHOR_MISMATCH: registration source changed", path), call. = FALSE)
  }
  matches <- Filter(function(x) identical(x$id, dataset_id), registry$datasets)
  stopifnot(length(matches) == 1L)
  data <- matches[[1]]
  stopifnot(identical(data$kind, "registered_real"), module %in% unlist(data$modules))
  paths <- list()
  for (item in data$sources) {
    stopifnot(identical(basename(item$filename), item$filename))
    path <- file.path(root, "acceptance/data", item$filename)
    if (!file.exists(path) || isTRUE(file.info(path)$isdir))
      stop(paste("OS_ACCEPTANCE_DATA_MISSING: registered offline input absent", item$filename), call. = FALSE)
    if (!identical(digest::digest(file = path, algo = "sha256"), item$sha256))
      stop(paste("OS_ANCHOR_MISMATCH: registered input SHA256 differs", item$filename), call. = FALSE)
    paths[[item$key]] <- path
  }
  list(dataset = data, paths = paths)
}

owner_qc_fresh <- function(destination, expected_files) {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  if (any(file.exists(file.path(destination, c(expected_files, "owner_dataset.json")))))
    stop("OS_ACCEPTANCE_DATA: fresh canonical fixture required; preserve earlier evidence", call. = FALSE)
}

owner_qc_receipt <- function(destination, verified, prepared, preparation) {
  prepared <- unlist(prepared, use.names = FALSE)
  stopifnot(is.character(prepared))
  stopifnot(length(prepared) > 0L, !anyDuplicated(basename(prepared)), all(file.exists(prepared)))
  receipt <- list(schema = "omicstat.owner-dataset-receipt.v1",
    dataset_id = verified$dataset$id, kind = "registered_real",
    source_files = lapply(verified$dataset$sources, function(s) list(key = s$key, sha256 = s$sha256)),
    prepared_inputs = unname(lapply(prepared, function(path) list(path = basename(path),
      sha256 = digest::digest(file = path, algo = "sha256"), bytes = unname(file.info(path)$size)))),
    preparation = preparation)
  jsonlite::write_json(receipt, file.path(destination, "owner_dataset.json"), auto_unbox = TRUE, pretty = TRUE)
  invisible(receipt)
}
