# Validate a user-provided data resource before parsing it. Does not load RDS,
# pickle, execute code, fetch resources, or infer redistribution permission.
os_user_refdata <- function(path, provenance, refdata_id) {
  fail <- function(code,msg) stop(paste0(code,": ",msg),call.=FALSE)
  p <- tryCatch(jsonlite::fromJSON(provenance,simplifyVector=FALSE),error=function(e) fail("OS_REFDATA_MISSING","provenance JSON absent or invalid"))
  fields <- c("refdata_id","source_url","version","licence","sha256","permitted_use")
  if (any(vapply(fields,function(k) !is.character(p[[k]]) || length(p[[k]])!=1L || is.na(p[[k]]) || !nzchar(trimws(p[[k]])),logical(1)))) fail("OS_REFDATA_MISSING","explicit provenance fields required")
  if (!grepl("^https://[^/@[:space:]]+([/?#]|$)",p$source_url) || !grepl("^[0-9a-f]{64}$",p$sha256)) fail("OS_REFDATA_MISMATCH","provenance URL/SHA is invalid")
  if (!identical(p$refdata_id,refdata_id) || !file.exists(path) || dir.exists(path)) fail("OS_REFDATA_MISMATCH","payload ID/path differs")
  if (!identical(digest::digest(file=path,algo="sha256"),p$sha256)) fail("OS_REFDATA_MISMATCH","payload SHA256 differs")
  p
}
