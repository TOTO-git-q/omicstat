# setup_native.R -- create the omicstat R environment WITHOUT docker, as an
# isolated library inside the repository (default .omicstat-r/library).
# ASCII only on purpose. Needs R 4.6.x and internet access.
#   Rscript env/native/setup_native.R [<library>]
# Same Bioconductor release, same dated CRAN snapshot and same GitHub pins as
# the container, so package versions match env/pkg_lock.csv. Golden baselines
# are defined on the container; native runs are the "visual equivalence" tier
# (ENGINEERING_PLAN 3.5: byte checks SKIP when the environment signature
# differs).
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
env_dir <- dirname(here)
root <- dirname(env_dir)
args <- commandArgs(trailingOnly = TRUE)
if (!requireNamespace("jsonlite", quietly = TRUE)) install.packages("jsonlite", repos = "https://p3m.dev/cran/latest")
source(file.path(env_dir, "r", "layer_lib.R"))
cfg <- os_env_config(env_dir)
want <- package_version(cfg$r_version)
have <- getRversion()
if (have$major != want$major || have$minor != want$minor) {
  stop(sprintf("OS_ENV_R_VERSION: this R is %s; omicstat needs R %s.x (container pin %s).",
               have, paste(want$major, want$minor, sep = "."), cfg$r_version), call. = FALSE)
}
if (have != want) message(sprintf("NOTE: R %s differs from the container pin %s (patch level only).", have, want))
lib <- normalizePath(if (length(args)) args[1] else file.path(root, cfg$native_library), winslash = "/", mustWork = FALSE)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
# isolate this session exactly like Rprofile.omicstat does for engine runs
assign(".lib.loc", c(lib, .Library), envir = environment(.libPaths))
options(repos = c(CRAN = os_cran_repo(cfg)))
for (p in c("jsonlite", "BiocManager", "remotes")) if (!requireNamespace(p, quietly = TRUE)) install.packages(p, lib = lib)
BiocManager::install(version = cfg$bioconductor, lib = lib, ask = FALSE, update = FALSE)
for (layer in cfg$layers) os_install_layer(cfg, layer, lib = lib)
lock_out <- file.path(env_dir, sprintf("pkg_lock.native-%s.csv", .Platform$OS.type))
system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(env_dir, "r", "write_pkg_lock.R")), shQuote(lock_out)),
        env = c(paste0("OMICSTAT_R_LIBS=", lib), paste0("R_PROFILE_USER=", file.path(env_dir, "native", "Rprofile.omicstat"))))
cfg_out <- list(schema = "omicstat.native-env.v1", env_version = cfg$env_version, r_version = as.character(have),
                rscript = normalizePath(file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"), winslash = "/"),
                library = lib, rprofile = normalizePath(file.path(env_dir, "native", "Rprofile.omicstat"), winslash = "/"))
dir.create(file.path(root, ".omicstat-r"), showWarnings = FALSE)
writeLines(jsonlite::toJSON(cfg_out, auto_unbox = TRUE, pretty = TRUE), file.path(root, ".omicstat-r", "native-env.json"))
cat("omicstat native environment ready:", lib, "\nMCP: set OMICSTAT_ENGINE=native (paths are read from .omicstat-r/native-env.json)\n")
