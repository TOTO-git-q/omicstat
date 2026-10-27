local({
 files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
 source(file.path(dirname(normalizePath(tail(files[nzchar(files)], 1))), "model_io.R"), local = .GlobalEnv)
})
# Candidate adapters share one input/formula/output implementation.
ex_stop <- os_input_stop
ex_require <- os_require_pkg
ex_columns <- os_check_columns
ex_numeric <- os_as_finite
ex_formula <- os_safe_formula
ex_write <- function(res, a, module, entry, spec, upstream = NULL) {
 res$handoff_type <- paste0("development_", res$type)
 model <- if (is.null(upstream)) res$object else readRDS(upstream$objects$model$path)
 os_module_finish(res, a, module, entry, spec, upstream,
  figures_fn = function(res, out, module) os_model_figures(res, out, module,
   model = model, seed = a$seed, effect_plot = isTRUE(a[["effect-plot"]])))
}
