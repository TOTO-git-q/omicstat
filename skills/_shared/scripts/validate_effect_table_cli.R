# validate_effect_table_cli.R -- validate persisted CSV files with the canonical
# effect_table.R validator. ASCII only on purpose for Windows R locales.
#
# Usage:
#   Rscript validate_effect_table_cli.R path/to/table.csv [more.csv ...]
#
# stdout is one JSON document. Diagnostics and startup warnings stay on stderr.

args <- commandArgs(trailingOnly = TRUE)

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_arg)) stop("OS_MISSING_FILE: cannot locate this script", call. = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/", mustWork = TRUE))
source(file.path(here, "effect_table.R"))

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("OS_MISSING_PACKAGE: jsonlite is required by validate_effect_table_cli.R", call. = FALSE)
}

empty_to_na <- function(x) {
  x <- trimws(x)
  x[x %in% c("", "NA", "NaN", "null", "NULL")] <- NA_character_
  x
}

restore_column <- function(x, type, column) {
  raw <- empty_to_na(as.character(x))
  present <- !is.na(raw)
  if (identical(type, "character")) return(list(value = raw, errors = character(0)))
  if (type %in% c("numeric", "integer")) {
    value <- suppressWarnings(as.numeric(raw))
    bad <- present & is.na(value)
    errors <- if (any(bad)) sprintf(
      "OS_SCHEMA_INVALID: column '%s' has non-numeric persisted value(s) in row(s) %s",
      column, paste(which(bad), collapse = ",")) else character(0)
    return(list(value = value, errors = errors))
  }
  if (identical(type, "logical")) {
    low <- tolower(raw)
    value <- rep(NA, length(raw))
    value[present & low %in% c("true", "t", "1", "yes")] <- TRUE
    value[present & low %in% c("false", "f", "0", "no")] <- FALSE
    bad <- present & is.na(value)
    errors <- if (any(bad)) sprintf(
      "OS_SCHEMA_INVALID: column '%s' has non-logical persisted value(s) in row(s) %s",
      column, paste(which(bad), collapse = ",")) else character(0)
    return(list(value = value, errors = errors))
  }
  list(value = raw, errors = character(0))
}

read_persisted_effect_table <- function(path) {
  raw <- utils::read.csv(
    path, header = TRUE, check.names = FALSE, stringsAsFactors = FALSE,
    colClasses = "character", na.strings = character(0), fileEncoding = "UTF-8-BOM"
  )
  lexical_errors <- character(0)
  for (i in seq_len(nrow(EFFECT_TABLE_SCHEMA))) {
    column <- EFFECT_TABLE_SCHEMA$column[[i]]
    if (!column %in% names(raw)) next
    restored <- restore_column(raw[[column]], EFFECT_TABLE_SCHEMA$type[[i]], column)
    raw[[column]] <- restored$value
    lexical_errors <- c(lexical_errors, restored$errors)
  }
  list(table = raw, errors = lexical_errors)
}

validate_one <- function(path) {
  normalized <- tryCatch(
    normalizePath(path, winslash = "/", mustWork = TRUE),
    error = function(e) NA_character_
  )
  if (is.na(normalized) || !file.exists(normalized)) {
    return(list(
      path = as.character(path), ok = FALSE, row_count = 0L, columns = character(0),
      errors = I(sprintf("OS_MISSING_FILE: effect table does not exist: %s", path)),
      warnings = I(character(0))
    ))
  }
  tryCatch({
    restored <- read_persisted_effect_table(normalized)
    checked <- validate_effect_table(restored$table)
    errors <- c(restored$errors, checked$errors)
    list(
      path = normalized,
      ok = length(errors) == 0L && isTRUE(checked$ok),
      row_count = as.integer(nrow(restored$table)),
      columns = names(restored$table),
      errors = I(unname(errors)),
      warnings = I(unname(checked$warnings))
    )
  }, error = function(e) list(
    path = normalized, ok = FALSE, row_count = 0L, columns = character(0),
    errors = I(sprintf("OS_SCHEMA_INVALID: could not read persisted effect table: %s", conditionMessage(e))),
    warnings = I(character(0))
  ))
}

if (!length(args)) {
  payload <- list(
    schema_version = "omicstat.effect-table-validation.v1",
    ok = FALSE,
    files = list(),
    errors = I("OS_MISSING_FILE: pass at least one effect-table CSV path")
  )
} else {
  files <- lapply(args, validate_one)
  payload <- list(
    schema_version = "omicstat.effect-table-validation.v1",
    ok = all(vapply(files, function(x) isTRUE(x$ok), logical(1))),
    files = files,
    errors = I(character(0))
  )
}

cat(jsonlite::toJSON(
  payload, auto_unbox = TRUE, pretty = FALSE, null = "null", na = "null",
  dataframe = "rows"
))
cat("\n")
