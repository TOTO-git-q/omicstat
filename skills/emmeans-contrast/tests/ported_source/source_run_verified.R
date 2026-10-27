#!/usr/bin/env Rscript
# run_verified.R -- verified numerical case for `longitudinal-change`.
#
# Runs the module entry script on an embedded deterministic fixture.
# Reference values are computed separately in base R; see REFERENCE.md.
#
# Output: one line per check
#   VERIFIED <case_id> <quantity> ok|FAIL got=<x> expected=<y> tol=<t>
# Exit status is non-zero if any check fails. ASCII only on purpose.

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
ENGINE <- normalizePath(file.path(here, "..", "..", "scripts", "run_longitudinal.R"), winslash = "/", mustWork = TRUE)
RSCRIPT <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
WS <- file.path(tempdir(), sprintf("agreement_verified_%d", Sys.getpid()))
unlink(WS, recursive = TRUE); dir.create(WS, recursive = TRUE)
on.exit(unlink(WS, recursive = TRUE), add = TRUE)
p <- function(...) file.path(WS, ...)

N_FAIL <- 0L
fmt <- function(x) if (length(x) != 1 || is.na(x)) "NA" else formatC(x, digits = 7, format = "g")
check <- function(case, qty, got, expected, tol) {
  good <- length(got) == 1 && is.finite(got) && abs(got - expected) <= tol
  if (!good) N_FAIL <<- N_FAIL + 1L
  cat(sprintf("VERIFIED %s %s %s got=%s expected=%s tol=%s\n", case, qty,
              if (good) "ok" else "FAIL", fmt(got), fmt(expected), fmt(tol)))
}
run_engine <- function(case, args) {
  out <- suppressWarnings(system2(RSCRIPT, c(shQuote(ENGINE), vapply(args, shQuote, character(1))),
                                  stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status"); if (is.null(status)) status <- 0L
  if (status != 0L) {
    cat(paste(tail(out, 30), collapse = "\n"), "\n")
    check(case, "engine_exit_status", as.numeric(status), 0, 0)
  }
  status == 0L
}
eff <- function(dir, prefix) utils::read.csv(file.path(dir, "tables", paste0(prefix, "_effects.csv")),
                                             stringsAsFactors = FALSE, check.names = FALSE)


# Balanced repeated measures; fixed cell contrasts equal raw cell differences.
set.seed(151)
ids <- 1:80; grp <- rep(c("A", "B"), each = 40)
ri <- rep(seq(-1, 1, length.out = 40), 2)
d <- do.call(rbind, lapply(ids, function(i) data.frame(
  id = i, grp = grp[i], visit = 1:3,
  y = 10 + ri[i] + (grp[i] == "B") * (2 + 0.4 * (1:3)) + 0.3 * (1:3) +
    stats::rnorm(3, sd = 0.25))))
utils::write.csv(d, p("sample.csv"), row.names = FALSE)
case <- "LONG-balanced-cells"
if (run_engine(case, c("--data", p("sample.csv"), "--design", "cohort", "--outcome", "y",
                       "--subject", "id", "--time", "visit", "--group", "grp",
                       "--engine", "lmer", "--random-effects", "intercept", "--force",
                       "--outdir", p("out")))) {
  e <- utils::read.csv(p("out", "tables", "lc_differences_by_timepoint.csv"))
  ref <- mean(d$y[d$grp == "B" & d$visit == 3]) - mean(d$y[d$grp == "A" & d$visit == 3])
  check(case, "group_diff_visit3", e$estimate[e$level == 3][1], ref, 1e-5)
}

cat(sprintf("verified longitudinal-change: %d failure(s)\n", N_FAIL))
quit(status = if (N_FAIL > 0L) 1L else 0L, save = "no")
