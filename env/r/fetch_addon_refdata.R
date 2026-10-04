# Build-time only downloads, with immutable URLs and SHA-256 verification.
registry <- jsonlite::fromJSON('/opt/omicstat/env/refdata_registry.json', simplifyVector = FALSE)
for (entry in registry$entries) {
  if (!identical(entry$build_layer, 'L8_addons')) next
  dir.create(dirname(entry$cache), recursive = TRUE, showWarnings = FALSE)
  download.file(entry$url, entry$cache, mode = 'wb', quiet = FALSE)
  if (!identical(digest::digest(file = entry$cache, algo = 'sha256'), entry$sha256))
    stop(paste('OS_REFDATA_MISMATCH:', entry$id))
  Sys.chmod(entry$cache, '0644')
}
