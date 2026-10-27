.bt_classify_all <- function(data, vars, factor_vars = character(0)) {
  out <- lapply(vars, function(v) {
    if (!v %in% names(data)) {
      stop(sprintf("MS_MISSING_COLUMNS: analysis variable '%s' is not a column of the input data.", v),
           call. = FALSE)
    }
    force_type <- if (v %in% factor_vars) "categorical" else NULL
    classify_variable(data[[v]], var_name = v, force_type = force_type)
  })
  names(out) <- vars
  out
}
