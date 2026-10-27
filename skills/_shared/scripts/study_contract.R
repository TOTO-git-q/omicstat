# Strict shared engine binding. Source this once per engine process.
.os_contract_file <- local({
  files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
  normalizePath(tail(files[nzchar(files)], 1), mustWork = TRUE)
})
.os_contract_root <- normalizePath(file.path(dirname(.os_contract_file), "../../.."), mustWork = TRUE)
.os_contract_context <- new.env(parent = emptyenv())
.os_contract_context$bound <- NULL
os_study_contract_read <- function(path, upstream = NULL, expected_sha256 = NULL) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !file.exists(path) || dir.exists(path) || nzchar(Sys.readlink(path)))
    stop("OS_CONTRACT_INVALID: study contract must be a regular non-symlink file", call. = FALSE)
  if (file.info(path)$size > 1024^2) stop("OS_CONTRACT_INVALID: contract exceeds 1 MiB", call. = FALSE)
  digest <- digest::digest(file = path, algo = "sha256")
  for (value in list(expected_sha256, upstream$contract_hash)) {
    if (!is.null(value) && !identical(value, NA_character_) && (!is.character(value) || length(value) != 1L || is.na(value) || !grepl("^[0-9a-f]{64}$", value) || !identical(value, digest)))
      stop("OS_CONTRACT_MISMATCH: contract bytes differ from declared/upstream hash", call. = FALSE)
  }
  python <- Sys.which("python3")
  if (!nzchar(python)) stop("OS_DEPENDENCY_MISSING: python3 required for StudyContract byte binding", call. = FALSE)
  stdout <- tempfile(); stderr <- tempfile(); on.exit(unlink(c(stdout, stderr)))
  status <- system2(python, c(shQuote(file.path(.os_contract_root, "tools/check_study_contract.py")), shQuote(normalizePath(path))), stdout = stdout, stderr = stderr)
  if (status != 0L) stop(paste(readLines(stderr, warn = FALSE), collapse = "\n"), call. = FALSE)
  verified <- jsonlite::fromJSON(stdout)
  if (!identical(verified$sha256, digest)) stop("OS_CONTRACT_MISMATCH: contract changed during validation", call. = FALSE)
  list(path = normalizePath(path), sha256 = digest, study_contract = jsonlite::fromJSON(path, simplifyVector = FALSE))
}
os_study_contract_bind <- function(a) {
  .os_contract_context$bound <- NULL
  path <- a[['study-contract']]; expected <- a[['study-contract-sha256']]
  if (!is.null(expected) && is.null(path)) stop("OS_MISSING_PARAMETER: --study-contract-sha256 requires --study-contract", call. = FALSE)
  if (is.null(path)) return(invisible(NULL))
  upstream <- NULL
  if (!is.null(a[['from-run']])) {
    hp <- file.path(a[['from-run']], "objects/handoff.json")
    if (!file.exists(hp)) stop("OS_HANDOFF_MISSING: cannot bind upstream StudyContract", call. = FALSE)
    upstream <- jsonlite::fromJSON(hp, simplifyVector = FALSE)
  }
  .os_contract_context$bound <- os_study_contract_read(path, upstream, expected)
  invisible(.os_contract_context$bound)
}
os_study_contract_bound_hash <- function(explicit = NULL) {
  ctx <- .os_contract_context$bound
  if (is.null(ctx)) return(explicit)
  got <- os_study_contract_read(ctx$path, expected_sha256 = ctx$sha256)$sha256
  if (!is.null(explicit) && !is.na(explicit) && !identical(explicit, got)) stop("OS_CONTRACT_MISMATCH: engine hash differs from validated contract", call. = FALSE)
  got
}
