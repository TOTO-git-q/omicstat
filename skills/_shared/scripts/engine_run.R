# engine_run.R -- capture every warning and message an engine stage raises.
# ASCII only on purpose. See docs/CONVENTIONS.md sec 15.
#
#   elog <- os_engine_log_new(outdir)                  # -> <outdir>/qc/engine_warnings.csv
#   res  <- os_engine_capture(compute(...), "compute", elog)
#   os_engine_capture(render(res, outdir), "render", elog)
#
# os_engine_capture(expr, stage, log) evaluates `expr` inside
# withCallingHandlers and records every condition with its stage:
#   warning  recorded, echoed to stderr as "OS_ENGINE_WARNING: [<stage>] <msg>"
#            (the MCP console scan picks up the OS_ prefix), then muffled so R
#            does not print it a second time. Under options(warn >= 2) the
#            warning is recorded but NOT muffled, so R still turns it into an
#            error as the caller asked.
#   message  recorded; left to print normally (never muffled).
#   error    recorded and the CSV flushed, then the error propagates
#            unchanged: errors are never muffled or converted.
# The CSV (columns stage, type, message) is rewritten after every stage and
# on error, so it exists even when the run dies; with no conditions it holds
# the header only. Options touched: `warning.length` is raised to its maximum
# for the stage (C-level engine warnings are otherwise truncated at 1000
# bytes) and `warn` is pinned; both are restored on exit, also when the stage
# changed them itself or failed.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

os_engine_log_new <- function(outdir = NULL) {
  log <- new.env(parent = emptyenv())
  log$rows <- list()
  log$path <- if (is.null(outdir)) NULL else file.path(outdir, "qc", "engine_warnings.csv")
  log$last_error <- NULL
  class(log) <- "os_engine_log"
  log
}

.os_engine_one_line <- function(x) gsub("[[:space:]]+", " ", trimws(paste(x, collapse = " ")))

.os_engine_add <- function(log, stage, type, msg) {
  log$rows[[length(log$rows) + 1L]] <- data.frame(stage = stage, type = type, message = .os_engine_one_line(msg),
                                                  stringsAsFactors = FALSE)
}

os_engine_table <- function(log) {
  if (!length(log$rows)) return(data.frame(stage = character(0), type = character(0), message = character(0), stringsAsFactors = FALSE))
  do.call(rbind, log$rows)
}

os_engine_counts <- function(log) {
  tab <- os_engine_table(log)
  vapply(c("warning", "message", "error"), function(t) sum(tab$type == t), integer(1))
}

os_engine_write <- function(log) {
  if (is.null(log$path)) return(invisible(NULL))
  dir.create(dirname(log$path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(os_engine_table(log), log$path, row.names = FALSE, fileEncoding = "UTF-8")
  invisible(log$path)
}

os_engine_capture <- function(expr, stage, log) {
  stopifnot(inherits(log, "os_engine_log"), is.character(stage), length(stage) == 1)
  old <- options(warning.length = 8170L, warn = getOption("warn", 0L))
  on.exit({ options(old); os_engine_write(log) }, add = TRUE)
  withCallingHandlers(
    expr,
    warning = function(w) {
      msg <- conditionMessage(w)
      .os_engine_add(log, stage, "warning", msg)
      cat(sprintf("OS_ENGINE_WARNING: [%s] %s\n", stage, .os_engine_one_line(msg)), file = stderr())
      if (getOption("warn", 0L) < 2L) invokeRestart("muffleWarning")
    },
    message = function(m) .os_engine_add(log, stage, "message", conditionMessage(m)),
    error = function(e) {
      # Nested captures see the same error object: record it once.
      if (!identical(log$last_error, e)) {
        log$last_error <- e
        .os_engine_add(log, stage, "error", conditionMessage(e))
        os_engine_write(log)
      }
    })
}
