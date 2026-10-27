# A failure belongs to one test; the rest of the suite must still run.
dd_test_harness <- function(quiet = FALSE) {
  state <- new.env(parent = emptyenv())
  state$passed <- 0L; state$failures <- list(); state$skipped <- character()
  check <- function(name, expr) {
    force(name)
    error <- tryCatch({ force(expr); NULL }, error = function(e) e)
    if (is.null(error)) {
      state$passed <- state$passed + 1L
      if (!quiet) cat("PASS", name, "\n")
      return(invisible(TRUE))
    }
    state$failures[[length(state$failures) + 1L]] <- list(name = name, message = conditionMessage(error))
    if (!quiet) cat("FAIL", name, ":", conditionMessage(error), "\n")
    invisible(FALSE)
  }
  skip <- function(reason) { state$skipped <- c(state$skipped, reason); invisible(NULL) }
  summary <- function(print = TRUE) {
    failed <- length(state$failures)
    status <- if (failed) 1L else if (length(state$skipped)) 2L else 0L
    result <- list(total = state$passed + failed, passed = state$passed, failed = failed,
      skipped_groups = state$skipped, failures = state$failures, exit_status = status)
    if (print) {
      cat("SYNTHETIC TEST SUMMARY: total=", result$total, " passed=", result$passed,
        " failed=", result$failed, " skipped_groups=", length(state$skipped), "\n", sep = "")
      for (f in state$failures) cat("FAILURE:", f$name, ":", f$message, "\n")
      for (s in state$skipped) cat("NOT RUN:", s, "\n")
    }
    result
  }
  list(check = check, skip = skip, summary = summary)
}
