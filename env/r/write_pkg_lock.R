# Write the image package lock: one row per installed package with its version,
# source (base / recommended / CRAN / Bioconductor / github / other), the
# repository it came from, and the pinned commit for GitHub packages (for
# Bioconductor packages the git_last_commit recorded in their DESCRIPTION).
#   Rscript write_pkg_lock.R /opt/omicstat/pkg_lock.csv
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args) >= 1) args[[1]] else "/opt/omicstat/pkg_lock.csv"

fields <- c("Repository", "RemoteType", "RemoteUsername", "RemoteRepo", "RemoteRef",
            "RemoteSha", "biocViews", "git_last_commit")
ip <- installed.packages(fields = fields)
ip <- ip[!duplicated(ip[, "Package"]), , drop = FALSE]
val <- function(i, f) { v <- ip[i, f]; if (is.na(v)) "" else unname(v) }
cran_repo <- unname(getOption("repos")[["CRAN"]])
bioc_ver <- if (requireNamespace("BiocManager", quietly = TRUE)) as.character(BiocManager::version()) else ""

rows <- lapply(seq_len(nrow(ip)), function(i) {
  prio <- val(i, "Priority"); repo_f <- val(i, "Repository"); rtype <- val(i, "RemoteType")
  if (tolower(rtype) == "github") {
    src <- "github"
    repo <- sprintf("%s/%s@%s", val(i, "RemoteUsername"), val(i, "RemoteRepo"), val(i, "RemoteRef"))
    sha <- val(i, "RemoteSha")
  } else if (prio %in% c("base", "recommended") && repo_f == "") {
    src <- prio; repo <- ""; sha <- ""
  } else if (nzchar(val(i, "biocViews")) || grepl("Bioconductor", repo_f)) {
    src <- "Bioconductor"; repo <- paste("Bioconductor", bioc_ver); sha <- val(i, "git_last_commit")
  } else if (repo_f %in% c("CRAN", "RSPM")) {
    src <- "CRAN"; repo <- cran_repo; sha <- ""
  } else {
    src <- "other"; repo <- repo_f; sha <- val(i, "RemoteSha")
  }
  data.frame(package = val(i, "Package"), version = val(i, "Version"), source = src,
             repository = repo, remote_sha = sha, stringsAsFactors = FALSE)
})
lock <- do.call(rbind, rows)
lock <- lock[order(lock$package, method = "radix"), , drop = FALSE]
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
write.csv(lock, out, row.names = FALSE)
gh <- lock[lock$source == "github", , drop = FALSE]
stopifnot(all(grepl("^[0-9a-f]{40}$", gh$remote_sha)))
cat(sprintf("pkg_lock written: %s (%d packages; %d github)\n", out, nrow(lock), nrow(gh)))
