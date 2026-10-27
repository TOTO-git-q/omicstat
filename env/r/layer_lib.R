# layer_lib.R -- shared by the container build and the native setup of the
# omicstat R environment. ASCII only on purpose.
# Repositories come from env/r-env.json: Bioconductor = its "bioconductor"
# release, CRAN = the dated snapshot. Nothing floats to "latest".

options(Ncpus = max(1L, min(4L, parallel::detectCores(logical = FALSE))), timeout = 1200)

os_env_config <- function(env_dir) {
  cfg <- jsonlite::fromJSON(file.path(env_dir, "r-env.json"), simplifyVector = TRUE)
  cfg$env_dir <- normalizePath(env_dir, winslash = "/")
  cfg
}

os_cran_repo <- function(cfg) {
  if (identical(.Platform$OS.type, "unix") && file.exists("/etc/os-release") &&
      any(grepl("noble", readLines("/etc/os-release", warn = FALSE)))) cfg$cran_repo_linux else cfg$cran_repo_other
}

os_layer_packages <- function(cfg, layer) {
  f <- file.path(cfg$env_dir, "layers", paste0(layer, ".txt"))
  x <- trimws(sub("#.*$", "", readLines(f, warn = FALSE)))
  x[nzchar(x)]
}

os_github_pins <- function(cfg, layer = NULL) {
  f <- file.path(cfg$env_dir, "layers", "github_pins.txt")
  x <- trimws(sub("#.*$", "", readLines(f, warn = FALSE)))
  x <- x[nzchar(x)]
  if (!length(x)) return(data.frame(layer = character(0), package = character(0), repo = character(0), sha = character(0)))
  p <- do.call(rbind, lapply(strsplit(x, "[[:space:]]+"), function(v) data.frame(layer = v[1], package = v[2], repo = v[3], sha = v[4])))
  # Transitive GitHub dependencies ("DEP" rows, appended by pin_github.sh
  # --from-lock) are installed with L5, the first layer that needs GitHub.
  if (!is.null(layer)) {
    code <- sub("_.*$", "", layer)
    p <- p[p$layer == code | (code == "L5" & p$layer == "DEP"), , drop = FALSE]
    p <- p[order(p$layer != "DEP"), , drop = FALSE]
  }
  p
}

os_install_layer <- function(cfg, layer, lib = .libPaths()[1]) {
  pkgs <- os_layer_packages(cfg, layer)
  gh <- os_github_pins(cfg, layer)
  # fail fast, before any download, when a GitHub package is not pinned
  bad <- gh$package[!grepl("^[0-9a-f]{40}$", gh$sha)]
  if (length(bad)) {
    stop(sprintf("OS_ENV_UNPINNED: %s has no commit SHA in env/layers/github_pins.txt; run env/pin_github.sh first.",
                 paste(bad, collapse = ", ")), call. = FALSE)
  }
  options(repos = c(CRAN = os_cran_repo(cfg)))
  if (!requireNamespace("BiocManager", quietly = TRUE, lib.loc = lib)) install.packages("BiocManager", lib = lib)
  bioc_pkgs <- setdiff(pkgs, "BiocManager")
  if (length(bioc_pkgs)) {
    BiocManager::install(bioc_pkgs, lib = lib, version = cfg$bioconductor, ask = FALSE, update = FALSE)
  }
  for (i in seq_len(nrow(gh))) {
    old <- options(repos = BiocManager::repositories(version = cfg$bioconductor))
    remotes::install_github(gh$repo[i], ref = gh$sha[i], lib = lib, upgrade = "never", dependencies = TRUE)
    options(old)
  }
  want <- c(pkgs, gh$package)
  miss <- want[!vapply(want, function(p) requireNamespace(p, quietly = TRUE, lib.loc = c(lib, .libPaths())), logical(1))]
  if (length(miss)) stop(sprintf("OS_ENV_LAYER_FAILED: %s did not install: %s", layer, paste(miss, collapse = ", ")), call. = FALSE)
  cat(sprintf("%s: %d packages OK\n", layer, length(want)))
  invisible(want)
}
