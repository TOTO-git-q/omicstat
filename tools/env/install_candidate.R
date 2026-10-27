# Offline, additive-only image installer. Never upgrades inherited packages.
candidate_built_platform_ok <- function(built_platform, runtime_platform, needs_compilation, members) {
  if (identical(built_platform, runtime_platform)) return(TRUE)
  native_members <- grepl("^[^/]+/libs(/|$)|[.](so([.][0-9]+)*|dll|dylib|a|o)$", members, ignore.case=TRUE)
  identical(built_platform, "") && identical(needs_compilation, "no") && !any(native_members)
}

root <- Sys.getenv("OMICSTAT_CANDIDATE_DIR", "/candidate")
fail <- function(s) stop(s, call. = FALSE)
m <- jsonlite::fromJSON(file.path(root, "manifest.json"), simplifyVector = FALSE)
x <- jsonlite::fromJSON(file.path(root, "sources.lock.json"), simplifyVector = FALSE)
rows <- if (is.null(x$sources)) x else x$sources
wanted <- as.character(unlist(m$new_packages))
if (!length(wanted) || !setequal(wanted, vapply(rows, `[[`, "", "package"))) fail("source lock differs from additive declaration")
if (length(m$system_requirements) && !isTRUE(m$system_requirements_verified)) fail("native prerequisites unresolved")
before <- installed.packages(fields = c("Repository", "RemoteSha"))
before <- before[!duplicated(before[,"Package"]),,drop=FALSE]
if (any(wanted %in% before[,"Package"])) fail("refusing to replace an inherited package")
order <- as.character(unlist(m$install_order))
if (!setequal(order, wanted) || anyDuplicated(order)) fail("explicit dependency install order required")
byname <- setNames(rows, vapply(rows, `[[`, "", "package"))
if (length(rows) != length(wanted) || anyDuplicated(vapply(rows, `[[`, "", "package"))) fail("duplicate archive package")
# Explicit archive kind is a lock property, never inferred from the filename.
kinds <- vapply(rows, function(row) if (is.character(row$kind) && length(row$kind)==1L) row$kind else "", "")
if (any(!kinds %in% c("source", "ppm_binary"))) fail("R archive kind must be source or ppm_binary")
policy <- m$r_artifact_policy
snapshot <- "https://p3m.dev/cran/__linux__/noble/2026-09-15"
if (any(kinds == "ppm_binary")) {
  if (is.null(policy) || !identical(policy$schema, "omicstat.r-artifact-policy.v1") ||
      !identical(policy$parent_image_id, m$base_image_id) ||
      !identical(policy$ppm_snapshot_url, snapshot) ||
      !identical(policy$platform, "linux/amd64") || !identical(policy$distribution, "noble")) fail("invalid PPM parent policy")
  release <- readLines("/etc/os-release", warn=FALSE)
  codename <- gsub('"', '', sub("^VERSION_CODENAME=", "", release[grepl("^VERSION_CODENAME=", release)]), fixed=TRUE)
  if (!identical(codename, "noble") || !identical(Sys.info()[["sysname"]], "Linux") ||
      !identical(Sys.info()[["machine"]], "x86_64") ||
      !identical(unname(getOption("repos")[["CRAN"]]), snapshot) ||
      !identical(as.character(getRversion()), policy$r_version)) fail("actual runtime does not match locked PPM parent platform/snapshot/R")
}
metadata <- list()
# Preflight every archive before the first installation.
for (name in order) {
  row <- byname[[name]]; filename <- row$filename
  if (!is.character(filename) || length(filename)!=1L || basename(filename)!=filename || grepl("\\\\",filename)) fail("unsafe source filename")
  path <- file.path(root,"sources",filename)
  if (!file.exists(path) || !identical(digest::digest(file=path,algo="sha256"),row$sha256)) fail("source SHA mismatch")
  # Parse metadata without unpacking package files outside the build temp dir.
  listed <- utils::untar(path,list=TRUE)
  if (any(grepl("^/|(^|/)\\.\\.(/|$)|\\\\",listed)) || anyDuplicated(listed)) fail("unsafe archive member")
  dfile <- listed[grepl("^[^/]+/DESCRIPTION$",listed)]
  if (length(dfile)!=1L) fail("archive lacks unique DESCRIPTION")
  temp <- tempfile("candidate-desc-");dir.create(temp)
  utils::untar(path,files=dfile,exdir=temp)
  desc <- read.dcf(file.path(temp,dfile));unlink(temp,recursive=TRUE)
  if (!identical(unname(desc[1,"Package"]),name) || !identical(unname(desc[1,"Version"]),row$version)) fail("archive package/version mismatch")
  binary <- any(grepl("^[^/]+/Meta/package[.]rds$",listed)) || "Built" %in% colnames(desc)
  if (identical(row$kind,"source") && binary) fail("installed binary package is not a source archive")
  if (identical(row$kind,"ppm_binary")) {
    if (!identical(row$ppm_snapshot_url,snapshot) || !identical(row$platform,policy$platform) ||
        !identical(row$url,paste0(snapshot,"/src/contrib/",filename))) fail("binary URL/platform outside locked PPM snapshot")
    if (!binary || !"Built" %in% colnames(desc) || !any(grepl("^[^/]+/Meta/package[.]rds$",listed))) fail("PPM binary metadata missing")
    built <- trimws(strsplit(desc[1,"Built"],";",fixed=TRUE)[[1]])
    minor <- paste(strsplit(as.character(getRversion()),".",fixed=TRUE)[[1]][1:2],collapse=".")
    needs_compilation <- if ("NeedsCompilation" %in% colnames(desc)) unname(desc[1,"NeedsCompilation"]) else NULL
    if (length(built)<4L || !grepl("^R [0-9]+[.][0-9]+[.][0-9]+$",built[1]) ||
        !startsWith(built[1],paste0("R ",minor,".")) ||
        utils::compareVersion(sub("^R ","",built[1]),as.character(getRversion()))>0L ||
        !candidate_built_platform_ok(built[2],R.version$platform,needs_compilation,listed) ||
        !identical(built[4],"unix")) fail("PPM binary Built metadata differs from actual R platform")
  }
  if (grepl("^https://([^/]+[.])?bioconductor[.]org/",row$url) && !identical(row$kind,"source")) fail("Bioconductor archives must remain source")
  metadata[[name]] <- desc
}
for (name in order) {
  row <- byname[[name]]; path <- file.path(root,"sources",row$filename); desc <- metadata[[name]]
  if (!identical(digest::digest(file=path,algo="sha256"),row$sha256)) fail("archive changed after preflight")
  deps <- unlist(strsplit(paste(desc[1,intersect(c("Depends","Imports","LinkingTo"),colnames(desc))],collapse=","),","))
  deps <- unique(trimws(sub("[[:space:]]*[(].*$","",deps)));deps <- setdiff(deps,c("","R"))
  if (!all(deps %in% rownames(installed.packages()))) fail(paste("missing dependency before",name))
  if (identical(row$kind,"ppm_binary")) {
    # R CMD INSTALL explicitly supports its Linux installed-package tarballs.
    # No repository lookup, dependency resolution or source recompilation.
    status <- system2(file.path(R.home("bin"),"R"),c("CMD","INSTALL",shQuote(path)))
    if (status!=0L) fail(paste("binary installation failed",name))
  } else utils::install.packages(path,repos=NULL,type="source",dependencies=FALSE)
  # Preserve the exact installed DESCRIPTION spelling (e.g. drc 3.0-1),
  # rather than package_version's normalized representation (3.0.1).
  if (!requireNamespace(name,quietly=TRUE) ||
      !identical(unname(utils::packageDescription(name,fields="Version")),row$version)) fail(paste("installation failed",name))
}
after <- installed.packages(fields=c("Repository","RemoteSha"))
if (!all(rownames(before) %in% rownames(after)) || !identical(unname(before[,c("Version","Repository","RemoteSha"),drop=FALSE]),unname(after[rownames(before),c("Version","Repository","RemoteSha"),drop=FALSE]))) fail("inherited package metadata changed")
# Export using the same canonical inventory writer as the parent image.
writer <- file.path(root,"write_pkg_lock.R")
status <- system2(file.path(R.home("bin"),"Rscript"),c(shQuote(writer),shQuote(Sys.getenv("OMICSTAT_CANDIDATE_INVENTORY","/opt/omicstat/pkg_lock.csv"))))
if (status!=0) fail("inventory export failed")
