# install_layer.R -- install one layer of the omicstat R environment.
# ASCII only on purpose.
#   Rscript env/r/install_layer.R <env_dir> <layer> [<library>]
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: install_layer.R <env_dir> <layer> [<library>]", call. = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(here, "layer_lib.R"))
cfg <- os_env_config(args[1])
lib <- if (length(args) >= 3) args[3] else .libPaths()[1]
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
os_install_layer(cfg, args[2], lib = normalizePath(lib, winslash = "/"))
