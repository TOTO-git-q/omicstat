# install_acceptance_lib.R -- the acceptance data layer (S1 M1-2, owner 2026-09-27):
# a separate, hash-locked R library holding ONLY the Bioconductor experiment-data
# packages that module anchors need and that are not in the omicstat-r image.
# Run INSIDE the locked image (network needed once), from the suite root:
#   bash bin/omicstat-r-route.sh Rscript acceptance/data/install_acceptance_lib.R
# Result: .omicstat-acceptance/library (git-ignored) and
#         acceptance/data/acceptance_lib_lock.csv (committed: package, version,
#         source tarball, its sha256, repository).
# With the lock present, the script installs exactly the locked tarballs and
# stops on any sha256 mismatch. Packages are installed with dependencies =
# FALSE: the layer must never shadow a package of the image (checked below).
# S4 (2026-09-29): annotation packages needed by printed anchors (limma-array:
# RnAgilentDesign028282.db, which depends on org.Rn.eg.db) come from the
# Bioconductor annotation repository; packages are installed in dependency
# order and a dependency may also be a package already installed in the
# layer; a package already installed at the locked version is not reinstalled.
# Every tarball is also unpacked unchanged to .omicstat-acceptance/extracted/<pkg>;
# a package whose Depends/Imports are not all in the image (pasilla needs
# DEXSeq) is NOT installed and is used only through its unpacked files
# (mode "extracted" in the lock) -- the package is never edited.
# Smoke tests reach the layer through os_acceptance_lib() / os_acceptance_file()
# (skills/_shared/scripts/module_kit.R); the engines never load it.
options(warn = 1)
suite <- normalizePath(".")
lib <- file.path(suite, ".omicstat-acceptance", "library")
dl <- file.path(suite, ".omicstat-acceptance", "src")
lock_path <- file.path(suite, "acceptance", "data", "acceptance_lib_lock.csv")
pkgs <- c("pasilla", "airway", "fission", "bladderbatch", "zebrafishRNASeq", "GSVAdata", "org.Rn.eg.db", "RnAgilentDesign028282.db")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
dir.create(dl, recursive = TRUE, showWarnings = FALSE)
repo <- BiocManager::repositories()[c("BioCexp", "BioCann")]
image_pkgs <- rownames(installed.packages(lib.loc = .libPaths()))
clash <- intersect(pkgs, image_pkgs)
if (length(clash)) stop("already in the image, not an acceptance-layer package: ", paste(clash, collapse = ", "))
sha <- function(p) digest::digest(file = p, algo = "sha256")
if (file.exists(lock_path)) {
  lk <- utils::read.csv(lock_path, stringsAsFactors = FALSE)
  for (i in seq_len(nrow(lk))) {
    f <- file.path(dl, lk$tarball[i])
    if (!file.exists(f)) utils::download.file(paste0(lk$repository[i], "/", lk$tarball[i]), f, mode = "wb", quiet = TRUE)
    if (!identical(sha(f), lk$sha256[i])) stop("sha256 mismatch for ", lk$tarball[i])
  }
  files <- file.path(dl, lk$tarball)
} else {
  ap <- utils::available.packages(repos = repo, type = "source")
  miss <- setdiff(pkgs, rownames(ap))
  if (length(miss)) stop("not in ", repo, ": ", paste(miss, collapse = ", "))
  got <- utils::download.packages(pkgs, destdir = dl, repos = repo, type = "source", available = ap, quiet = TRUE)
  files <- got[, 2]
  lk <- data.frame(package = got[, 1], version = ap[got[, 1], "Version"], tarball = basename(files),
                   sha256 = vapply(files, sha, ""), repository = sub("/src/contrib/?$", "/src/contrib", ap[got[, 1], "Repository"]),
                   bioconductor = as.character(BiocManager::version()), stringsAsFactors = FALSE)
  lk <- lk[order(lk$package, method = "radix"), ]
  con <- file(lock_path, open = "wb")
  utils::write.csv(lk, con, row.names = FALSE, eol = "\n")
  close(con)
}
files <- file.path(dl, lk$tarball)
ext <- file.path(suite, ".omicstat-acceptance", "extracted")
dir.create(ext, recursive = TRUE, showWarnings = FALSE)
deps_ok <- function(desc) {
  d <- read.dcf(desc, fields = c("Depends", "Imports"))
  req <- unlist(strsplit(paste(stats::na.omit(as.vector(d)), collapse = ","), ","))
  req <- trimws(sub("[(].*$", "", trimws(req)))
  req <- setdiff(req[nzchar(req)], c("R", rownames(installed.packages(priority = "base"))))
  miss <- setdiff(req, c(image_pkgs, names(mode)[mode == "installed"]))
  if (length(miss)) message(basename(dirname(desc)), ": not installable from the image alone (missing ", paste(miss, collapse = ", "), ")")
  !length(miss)
}
mode <- character(0)
have <- rownames(installed.packages(lib.loc = lib))
todo <- seq_along(files)
for (i in todo) { unlink(file.path(ext, lk$package[i]), recursive = TRUE); utils::untar(files[i], exdir = ext) }
# dependency order: repeat passes until no package can be added
repeat {
  progress <- FALSE
  for (i in todo) {
    pkg <- lk$package[i]
    if (!is.na(mode[pkg])) next
    if (deps_ok(file.path(ext, pkg, "DESCRIPTION"))) {
      if (!(pkg %in% have && identical(as.character(utils::packageVersion(pkg, lib.loc = lib)), lk$version[i]))) {
        st <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-test-load", "-l", shQuote(lib), shQuote(files[i])))
        if (st != 0) stop("R CMD INSTALL failed for ", files[i])
      }
      mode[pkg] <- "installed"; progress <- TRUE
    }
  }
  if (!progress) break
}
for (pkg in lk$package) if (is.na(mode[pkg])) mode[pkg] <- "extracted"
lk$mode <- unname(mode[lk$package])
con <- file(lock_path, open = "wb")
utils::write.csv(lk[, c("package", "version", "tarball", "sha256", "repository", "bioconductor", "mode")], con, row.names = FALSE, eol = "\n")
close(con)
.libPaths(c(.libPaths(), lib))
for (p in lk$package[lk$mode == "installed"]) {
  stopifnot(requireNamespace(p, quietly = TRUE), as.character(utils::packageVersion(p, lib.loc = lib)) == lk$version[lk$package == p])
}
cat("acceptance layer ready:", lib, "and", ext, "\n")
print(lk[, c("package", "version", "mode", "sha256")], row.names = FALSE)
