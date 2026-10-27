# make_module_lock.R -- lock 6 of ENGINEERING_PLAN (3.6): write
# skills/<module>/module_lock.json at S5. ASCII only on purpose.
#   Rscript tools/make_module_lock.R <module> [--check]
# --check recomputes every hash and exits 1 when the committed lock differs
# (used by tools/run_tests.sh and the module smoke tests).
# Contents: module version (the <PREFIX>_MODULE_VERSION constant of the core
# script), sha256 of every script, the call registry, the PACK, the smoke test
# and the golden manifest; the versions of the registry's packages as
# installed; the environment signature of the tier that wrote the lock.
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript tools/make_module_lock.R <module> [--check]", call. = FALSE)
module <- args[1]; check_only <- "--check" %in% args
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
root <- dirname(here)
source(file.path(root, "skills", "_shared", "scripts", "module_kit.R"))
mdir <- file.path(root, "skills", module)
if (!dir.exists(mdir)) stop(sprintf("OS_INVALID_PARAMETER: no module directory %s", mdir), call. = FALSE)
sha <- function(p) digest::digest(file = p, algo = "sha256")
rel <- function(p) substring(normalizePath(p, winslash = "/"), nchar(normalizePath(root, winslash = "/")) + 2)
scripts <- sort(list.files(file.path(mdir, "scripts"), pattern = "[.]R$", full.names = TRUE), method = "radix")
core <- grep("_core[.]R$", scripts, value = TRUE)
ver <- NA_character_
for (f in core) {
  m <- regmatches(readLines(f), regexpr("^[A-Z0-9_]+_MODULE_VERSION <- \"[0-9.]+\"", readLines(f)))
  if (length(m)) ver <- sub(".*\"([0-9.]+)\"", "\\1", m[1])
}
# Modules created from module.json (no <PREFIX>_MODULE_VERSION constant) take the declared module version.
if (is.na(ver) && file.exists(file.path(mdir, "module.json"))) {
  mj <- jsonlite::fromJSON(file.path(mdir, "module.json"), simplifyVector = FALSE)$version
  if (is.character(mj) && length(mj) == 1L && grepl("^[0-9.]+$", mj)) ver <- mj
}
if (is.na(ver)) stop("OS_MISSING_PARAMETER: no <PREFIX>_MODULE_VERSION constant in the core script and no module.json version", call. = FALSE)
reg_path <- file.path(mdir, "scripts", "calls_registry.json")
reg <- jsonlite::fromJSON(reg_path, simplifyVector = FALSE)
pack <- file.path(root, "acceptance", "exemplars", module, "PACK.md")
files <- c(scripts, reg_path, file.path(mdir, "SKILL.md"), sort(list.files(file.path(mdir, "references"), recursive = TRUE, full.names = TRUE), method = "radix"),
           sort(list.files(file.path(mdir, "tests"), pattern="[.]R$", recursive=TRUE, full.names=TRUE), method="radix"), file.path(mdir, "tests", "golden_manifest.csv"), if (file.exists(pack)) pack)
lock <- list(schema = "omicstat.module_lock.v1", module = module, module_version = ver,
             files = stats::setNames(lapply(files, sha), vapply(files, rel, "")),
             packages = lapply(reg$package_versions, function(x) NULL),
             environment = c(os_env_signature()[c("tier", "r", "bioconductor", "platform", "image")], list(env_version = jsonlite::fromJSON(file.path(root, "env", "r-env.json"))$env_version)))
for (p in names(reg$package_versions)) lock$packages[[p]] <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
out <- file.path(mdir, "module_lock.json")
txt <- jsonlite::toJSON(lock, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
if (check_only) {
  if (!file.exists(out)) { cat("FAIL: no module_lock.json\n"); quit(status = 1) }
  old <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  diff <- names(lock$files)[vapply(names(lock$files), function(k) !identical(old$files[[k]], lock$files[[k]]), logical(1))]
  if (!identical(old$environment, lock$environment)) diff <- c(diff, "environment")
  if (!identical(old$packages, lock$packages)) diff <- c(diff, "packages")
  if (!identical(old$module_version, ver)) diff <- c(diff, "module_version")
  if (length(diff)) { cat("FAIL: module_lock.json is stale for:", paste(diff, collapse = ", "), "\n"); quit(status = 1) }
  cat(sprintf("module_lock %s %s: OK (%d files)\n", module, ver, length(lock$files)))
} else {
  os_write_text(txt, out)
  cat(sprintf("wrote %s (%s, %d files, tier %s)\n", rel(out), ver, length(lock$files), lock$environment$tier))
}
