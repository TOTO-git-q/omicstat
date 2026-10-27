# omicstat_selftest_core.R -- core layer of module omicstat-selftest. ASCII only on purpose.
#
# This module is an ENVIRONMENT SELF-TEST, not an analysis. The core layer
# (1) reads the environment pins (env/r-env.json), (2) probes the
# running R session with base R only, so the probe works even when the figure
# packages are missing, and (3) builds the deterministic synthetic feature
# table that the report layer pushes through the shared table/figure/handoff
# code. No statistical engine is called anywhere in this module.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

ST_MODULE <- "omicstat-selftest"
ST_MODULE_VERSION <- "0.1.0"
ST_DEFAULT_SEED <- 20260925L
ST_JOURNALS <- c("nature", "cell", "science", "generic")   # figure presets of fig_style.R::os_journal()
ST_FIXTURE_N <- 1000L   # fx_feature_table() plants 500 DE features, so n must exceed 500
# Packages the shared figure/table/handoff layer needs at run time
# (fig_style.R, fig_bulk.R, fig_compose.R, handoff.R). svglite is only needed
# for svg output and is reported but not required.
ST_FIGURE_PACKAGES <- c("ggplot2", "ggrepel", "patchwork", "ragg", "systemfonts", "scales", "jsonlite", "digest")
ST_OPTIONAL_PACKAGES <- c("svglite")
ST_THREAD_VARS <- c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")
ST_FONT <- "Liberation Sans"

# Locate and read the environment pins. The checkout copy is authoritative;
# inside the container OMICSTAT_ENV_DIR points at the copy baked into the image.
st_read_env_config <- function(suite_root) {
  cands <- c(file.path(suite_root, "env", "r-env.json"))
  env_dir <- Sys.getenv("OMICSTAT_ENV_DIR")
  if (nzchar(env_dir)) cands <- c(cands, file.path(env_dir, "r-env.json"))
  for (p in cands) {
    if (file.exists(p) && requireNamespace("jsonlite", quietly = TRUE)) {
      cfg <- tryCatch(jsonlite::fromJSON(p, simplifyVector = TRUE), error = function(e) NULL)
      if (!is.null(cfg)) return(list(path = normalizePath(p, winslash = "/"), cfg = cfg))
    }
  }
  list(path = NA_character_, cfg = NULL)
}

.st_norm <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)

# Probe the running session. lc_ctype_start / utf8_start are captured by the
# entry script BEFORE the figure layer is sourced (fig_style.R switches
# LC_CTYPE to a UTF-8 locale on its own when one is available).
st_probe <- function(env, lc_ctype_start, utf8_start) {
  cfg <- env$cfg
  r_have <- getRversion()
  pkgs <- c(ST_FIGURE_PACKAGES, ST_OPTIONAL_PACKAGES)
  pkg_ok <- vapply(pkgs, function(p) requireNamespace(p, quietly = TRUE), logical(1))
  pkg_ver <- vapply(pkgs, function(p) if (pkg_ok[[p]]) as.character(utils::packageVersion(p)) else NA_character_, character(1))
  bioc_installed <- requireNamespace("BiocManager", quietly = TRUE)
  bioc_version <- NA_character_
  if (bioc_installed) {
    # Offline: never let BiocManager reach the network from a self-test.
    old <- options(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS = FALSE)
    on.exit(options(old), add = TRUE)
    bioc_version <- tryCatch(suppressWarnings(suppressMessages(as.character(BiocManager::version()))),
                             error = function(e) NA_character_)
  }
  families <- if (pkg_ok[["systemfonts"]]) tryCatch(unique(systemfonts::system_fonts()$family), error = function(e) character(0)) else character(0)
  in_container <- identical(Sys.getenv("OMICSTAT_CONTAINER"), "1")
  native_lib <- Sys.getenv("OMICSTAT_R_LIBS")
  mode <- if (in_container) "container" else if (nzchar(native_lib)) "native" else "unmanaged"
  lib_paths <- .st_norm(.libPaths())
  allowed <- unique(.st_norm(c(if (nzchar(native_lib)) native_lib, .Library)))
  list(
    env_config_path = env$path,
    env_version = cfg$env_version %||% NA_character_,
    r_version = as.character(r_have),
    r_version_string = R.version.string,
    r_pin = cfg$r_version %||% NA_character_,
    bioc_pin = cfg$bioconductor %||% NA_character_,
    bioc_installed = bioc_installed,
    bioc_version = bioc_version,
    lc_ctype_start = lc_ctype_start,
    utf8_start = isTRUE(utf8_start),
    lc_ctype_now = Sys.getlocale("LC_CTYPE"),
    utf8_now = isTRUE(l10n_info()[["UTF-8"]]),
    threads = vapply(ST_THREAD_VARS, Sys.getenv, character(1)),
    font_resolvable = ST_FONT %in% families,
    packages = data.frame(package = pkgs, required = pkgs %in% ST_FIGURE_PACKAGES,
                          loadable = unname(pkg_ok), version = unname(pkg_ver), stringsAsFactors = FALSE),
    mode = mode,
    native_library = if (nzchar(native_lib)) .st_norm(native_lib) else NA_character_,
    base_library = .st_norm(.Library),
    lib_paths = lib_paths,
    leaked_lib_paths = setdiff(lib_paths, allowed),
    platform = R.version$platform
  )
}

# The synthetic fixture: shared SHAPE fixture from _shared/tests/fixtures
# (right columns, realistic ranges; not biological data), put into the
# canonical feature-table column set and row order.
st_fixture <- function(shared_dir, seed) {
  fx <- new.env(parent = baseenv())
  sys.source(file.path(shared_dir, "tests", "fixtures", "fig_fixtures.R"), envir = fx)
  ft <- fx$fx_feature_table(ST_FIXTURE_N, seed = seed)
  as_feature_table(ft)
}

omicstat_selftest_compute <- function(env, lc_ctype_start, utf8_start, shared_dir, seed) {
  list(probe = st_probe(env, lc_ctype_start, utf8_start),
       feature_table = st_fixture(shared_dir, seed))
}
