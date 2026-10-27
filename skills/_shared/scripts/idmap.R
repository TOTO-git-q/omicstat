# Offline ID and ortholog mapping. Registry mapping exports, not package
# tarball checksums, identify the bytes actually queried by both lanes.
.os_id_stop <- function(code, message) stop(paste0(code, ": ", message), call. = FALSE)
.os_id_snapshot <- function(refdata_id, species, registry, root) {
  if (!file.exists(registry)) .os_id_stop("OS_REFDATA_MISSING", "registry is missing")
  entries <- tryCatch(jsonlite::fromJSON(registry, simplifyVector = FALSE)$entries, error=function(e) .os_id_stop("OS_REFDATA_MISSING", "registry is not valid JSON"))
  found <- Filter(function(e) identical(e$id, refdata_id), entries)
  if (length(found) != 1L) .os_id_stop("OS_REFDATA_MISSING", "reference ID must resolve exactly once")
  e <- found[[1]]
  if (!identical(as.character(unlist(e$species)), as.character(species))) .os_id_stop("OS_REFDATA_MISMATCH", "reference species differs")
  x <- e$mapping
  if (is.null(x$format) || !x$format %in% c("orgdb","ensdb","parquet","tsv","csv")) .os_id_stop("OS_REFDATA_MISSING", "mapping format is missing or unsupported")
  if (is.null(x$path) || grepl("^([A-Za-z]:)?[/\\\\]", x$path) || any(strsplit(x$path,"[/\\\\]")[[1]] == "..") ||
      is.null(x$sha256) || !grepl("^[0-9a-f]{64}$", x$sha256)) .os_id_stop("OS_REFDATA_MISSING", "reference lacks a safe SHA-bound mapping export")
  if (is.null(root)) root <- Sys.getenv("OMICSTAT_REFDATA_ROOT", dirname(registry))
  root <- normalizePath(root, mustWork = TRUE); path <- file.path(root, x$path)
  if (!file.exists(path)) .os_id_stop("OS_REFDATA_MISSING", "mapping export is missing")
  path <- normalizePath(path, mustWork = TRUE)
  if (!startsWith(path, paste0(root, "/"))) .os_id_stop("OS_REFDATA_MISMATCH", "mapping escapes reference root")
  if (!identical(digest::digest(file = path, algo = "sha256"), x$sha256)) .os_id_stop("OS_REFDATA_MISMATCH", "mapping SHA256 mismatch")
  list(entry = e, export = x, path = path)
}

os_idmap <- function(ids, from, to, species, refdata_id, policy,
                     registry = Sys.getenv("OMICSTAT_REFDATA_REGISTRY", "env/refdata_registry.json"), root = NULL, outdir = NULL) {
  if (missing(policy) || length(policy) != 1 || !policy %in% c("first","drop","expand")) .os_id_stop("OS_INVALID_PARAMETER", "explicit first/drop/expand policy required")
  if (any(vapply(list(from,to,refdata_id),function(v) !is.character(v) || length(v)!=1 || is.na(v) || !nzchar(v),logical(1))) || !is.character(species) || !length(species) || anyNA(species) || any(!nzchar(species))) .os_id_stop("OS_INVALID_PARAMETER", "explicit identifier columns, species and reference ID required")
  if (!is.character(ids) || !length(ids) || anyNA(ids) || any(!nzchar(trimws(ids)))) .os_id_stop("OS_INVALID_INPUT", "nonempty character IDs required")
  x <- .os_id_snapshot(refdata_id, species, registry, root); fmt <- x$export$format
  if (fmt %in% c("orgdb", "ensdb")) {
    if (!requireNamespace("AnnotationDbi", quietly = TRUE)) .os_id_stop("OS_MISSING_PACKAGE", "AnnotationDbi required")
    if (fmt == "ensdb") {
      if (!requireNamespace("ensembldb", quietly = TRUE)) .os_id_stop("OS_MISSING_PACKAGE", "ensembldb required")
      db <- ensembldb::EnsDb(x$path)
    } else db <- AnnotationDbi::loadDb(x$path)
    if (!from %in% AnnotationDbi::keytypes(db) || !to %in% AnnotationDbi::columns(db)) .os_id_stop("OS_MISSING_COLUMN", "unsupported identifier column")
    present <- intersect(unique(ids), AnnotationDbi::keys(db, keytype = from))
    d <- if (length(present)) AnnotationDbi::select(db, keys = present, columns = to, keytype = from) else stats::setNames(data.frame(character(),character()), c(from,to))
  } else if (fmt == "parquet") {
    if (!requireNamespace("arrow", quietly = TRUE)) .os_id_stop("OS_MISSING_PACKAGE", "arrow required for parquet snapshot")
    d <- as.data.frame(arrow::read_parquet(x$path))
  } else if (fmt %in% c("tsv","csv")) {
    d <- utils::read.table(x$path, header = TRUE, sep = if (fmt == "tsv") "\t" else ",", quote = "\"", comment.char = "", colClasses = "character", check.names = FALSE, stringsAsFactors = FALSE)
  } else .os_id_stop("OS_INVALID_INPUT", "unsupported mapping snapshot format")
  if (!all(c(from,to) %in% names(d))) .os_id_stop("OS_MISSING_COLUMN", "requested columns absent")
  valid <- !is.na(d[[from]]) & !is.na(d[[to]]) & nzchar(trimws(d[[from]])) & nzchar(trimws(d[[to]]))
  lookup <- split(as.character(d[[to]][valid]), as.character(d[[from]][valid]))
  mappings <- list(); report <- list(); lost <- character()
  for (i in seq_along(ids)) {
    source <- ids[i]; targets <- sort(unique(as.character(lookup[[source]])), method = "radix"); n <- length(targets)
    kept <- if (policy == "expand") targets else utils::head(targets,1)
    if (policy == "drop" && n > 1) kept <- character()
    status <- if (!n) "unmapped" else if (!length(kept)) "ambiguous_dropped" else if (n > 1 && policy == "first") "ambiguous_first" else if (n > 1) "expanded" else "mapped"
    if (!length(kept)) lost <- c(lost,source)
    if (length(kept)) mappings[[length(mappings)+1L]] <- data.frame(query_index = i, source_id = source, target_id = kept, stringsAsFactors = FALSE)
    report[[i]] <- data.frame(query_index = i, source_id = source, n_targets = n, n_retained = length(kept), status = status, policy = policy, refdata_id = refdata_id, stringsAsFactors = FALSE)
  }
  mappings <- if (length(mappings)) do.call(rbind,mappings) else data.frame(query_index = integer(),source_id = character(),target_id = character())
  report <- do.call(rbind,report); loss <- length(unique(lost))/length(unique(ids))
  qc <- list(code = "OS_IDMAP_LOSS", triggered = loss > 0.05, loss_fraction = loss, n_unique_input = length(unique(ids)), n_unique_lost = length(unique(lost)), threshold = 0.05)
  if (qc$triggered) warning(sprintf("OS_IDMAP_LOSS: %.2f%% of unique input IDs were lost",100*loss), call. = FALSE)
  if (!is.null(outdir)) { dir.create(file.path(outdir,"tables"),recursive=TRUE,showWarnings=FALSE); utils::write.csv(report,file.path(outdir,"tables/idmap_report.csv"),row.names=FALSE) }
  list(mappings = mappings, report = report, qc = qc, provenance = list(refdata_id = refdata_id, version = x$entry$version, sha256 = x$export$sha256, species = species, policy = policy))
}

os_ortholog <- function(ids, from_species, to_species, policy,
                       registry = Sys.getenv("OMICSTAT_REFDATA_REGISTRY", "env/refdata_registry.json"), root = NULL, outdir = NULL, from = "source_id", to = "target_id") {
  if (any(!grepl("^[A-Za-z][A-Za-z0-9_]*$", c(from_species,to_species)))) .os_id_stop("OS_INVALID_PARAMETER", "ortholog species must use registry tokens")
  x <- os_idmap(ids,from,to,c(from_species,to_species),paste0("ortholog_",from_species,"_",to_species),policy,registry,root,outdir)
  x$provenance$mapping_kind <- "ortholog"; x
}
