# run_smoke_test.R -- module omicstat-selftest. ASCII only on purpose.
# Required checks (ENGINEERING_PLAN 7.2 S2): anchors, flag effectiveness,
# call-registry consistency, default drift, flag-doc coverage, determinism,
# cwd independence, no Rplots.pdf. For this self-test module the "anchors"
# are the output contract (every promised file, the QC dialect, the closing
# line) and the fixture's deterministic counts.
# Usage: Rscript skills/omicstat-selftest/tests/run_smoke_test.R
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
source(file.path(module_dir, "..", "_shared", "scripts", "calls_check.R"))
failures <- character(0)
check <- function(cond, msg) { if (isTRUE(cond)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }

rscript <- file.path(R.home("bin"), "Rscript")
entry <- file.path(module_dir, "scripts", "run_omicstat_selftest.R")
work <- tempfile("omicstat_selftest_smoke_")
dir.create(work)
# cwd independence: every run starts from an unrelated working directory.
old_wd <- setwd(work)
on.exit(setwd(old_wd), add = TRUE)
run <- function(..., env = character(0)) {
  out <- suppressWarnings(system2(rscript, c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE, env = env))
  list(status = attr(out, "status") %||% 0L, out = out)
}
sha <- function(p) digest::digest(file = p, algo = "sha256")

# ---- call registry (lock 3) --------------------------------------------------
scripts <- list.files(file.path(module_dir, "scripts"), pattern = "\\.R$", full.names = TRUE)
cc <- check_calls(scripts, file.path(module_dir, "scripts", "calls_registry.json"))
check(cc$ok, paste("call registry consistent", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(file.path(module_dir, "scripts", "calls_registry.json"))
check(dd$ok, paste("no default drift", paste(dd$problems, collapse = "; ")))

# ---- --help and flag-doc coverage --------------------------------------------
h <- run("--help")
flags <- sort(unique(unlist(regmatches(h$out, gregexpr("--[A-Za-z0-9][A-Za-z0-9-]*", h$out)))))
check(h$status == 0 && all(c("--outdir", "--strict", "--seed", "--journal", "--help") %in% flags), "--help lists every flag")
docs <- paste(c(readLines(file.path(module_dir, "SKILL.md"), warn = FALSE),
                unlist(lapply(list.files(file.path(module_dir, "references"), full.names = TRUE), readLines, warn = FALSE))),
              collapse = "\n")
common_docs <- paste(readLines(file.path(module_dir, "..", "_shared", "docs", "STUDY_CONTRACT.md"), warn = FALSE), collapse = "\n")
undocumented <- function(fs) Filter(function(f) !grepl(f, docs, fixed = TRUE) &&
  !(f %in% c("--study-contract", "--study-contract-sha256") && grepl(f, common_docs, fixed = TRUE)), setdiff(fs, "--help"))
undoc <- undocumented(flags)
check(!length(undoc), paste("every flag documented", paste(undoc, collapse = " ")))
check(identical(undocumented(c("--study-contract", "--study-contract-sha256", "--undocumented-audit-probe")),
                "--undocumented-audit-probe"), "shared documentation covers only the two declared common flags")
# Default consistency (--help vs calls_registry.json vs SKILL.md/references):
# tools/check_defaults.py. Needs python3; reported as SKIP without it.
py <- Sys.which("python3")
if (nzchar(py)) {
  cd <- suppressWarnings(system2(py, c(shQuote(file.path(module_dir, "..", "..", "tools", "check_defaults.py")), shQuote(module_dir)),
                                 stdout = TRUE, stderr = TRUE))
  check((attr(cd, "status") %||% 0L) == 0L, paste("defaults consistent across --help/registry/docs", paste(cd, collapse = " | ")))
  lr <- suppressWarnings(system2(py, c(shQuote(file.path(module_dir, "..", "..", "tools", "lint_r.py")), shQuote(file.path(module_dir, "scripts"))),
                                 stdout = TRUE, stderr = TRUE))
  check((attr(lr, "status") %||% 0L) == 0L, paste("engine hygiene lint", paste(lr, collapse = " | ")))
} else cat("SKIP: check_defaults.py / lint_r.py need python3\n")

# ---- typed refusals ------------------------------------------------------------
r <- run("--bogus", "x")
check(r$status != 0 && any(grepl("OS_UNKNOWN_FLAG", r$out)), "unknown flag -> OS_UNKNOWN_FLAG")
r <- run("--seed", "1")
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER", r$out)), "missing --outdir -> OS_MISSING_PARAMETER")
r <- run("--outdir", file.path(work, "bad_seed"), "--seed", "abc")
check(r$status != 0 && any(grepl("OS_INVALID_PARAMETER", r$out)), "non-integer --seed -> OS_INVALID_PARAMETER")
r <- run("--outdir", file.path(work, "bad_journal"), "--journal", "lancet")
check(r$status != 0 && any(grepl("OS_INVALID_PARAMETER", r$out)), "unknown --journal -> OS_INVALID_PARAMETER")
r <- run("--outdir", file.path(work, "twice"), "--seed", "1", "--seed", "2")
check(r$status != 0 && any(grepl("OS_CONFLICTING_PARAMETERS", r$out)), "flag given twice -> OS_CONFLICTING_PARAMETERS")

# ---- a default run: output contract --------------------------------------------
t0 <- proc.time()[["elapsed"]]
a <- run("--outdir", file.path(work, "a"))
elapsed <- proc.time()[["elapsed"]] - t0
check(a$status == 0, paste("default run exits 0", paste(tail(a$out, 3), collapse = " | ")))
check(elapsed < 20, sprintf("default run under 20 s (%.1f s)", elapsed))
check(any(grepl("^[0-9]+ of [0-9]+ rules triggered; read environment_report.md first$", a$out)), "closing line")
A <- file.path(work, "a")
promised <- c("tables/feature_table.csv", "figures/volcano.pdf", "figures/volcano.png", "figures/volcano.figure_spec.json",
              "draft/methods_results.md", "provenance/provenance.json", "objects/handoff.json",
              "objects/colour_registry.json", "qc/qc_results.csv", "environment_report.md", "results/selftest_summary.json",
              "qc/engine_warnings.csv")
check(all(file.exists(file.path(A, promised))), paste("all outputs written", paste(promised[!file.exists(file.path(A, promised))], collapse = " ")))
qc <- utils::read.csv(file.path(A, "qc", "qc_results.csv"), stringsAsFactors = FALSE, colClasses = "character")
ew <- utils::read.csv(file.path(A, "qc", "engine_warnings.csv"), stringsAsFactors = FALSE, colClasses = "character")
check(identical(names(ew), c("stage", "type", "message")) && all(ew$type %in% c("warning", "message", "error")),
      "qc/engine_warnings.csv has columns stage, type, message")
check(sum(ew$type == "warning") == sum(grepl("^OS_ENGINE_WARNING: ", a$out)), "every captured warning is echoed as OS_ENGINE_WARNING")
check(identical(qc$id, sprintf("ST-%02d", 1:8)), "qc table has rules ST-01..ST-08")
check(all(c("id", "severity", "triggered", "blocking", "message", "action") %in% names(qc)), "qc table uses the id/severity/triggered/blocking dialect")
check(all(qc$triggered %in% c("TRUE", "FALSE")) && all(qc$severity %in% c("blocker", "error", "warning", "info")), "qc values are well-formed")
res <- jsonlite::fromJSON(file.path(A, "results", "selftest_summary.json"))
check(res$n_rules == 8 && res$n_triggered == sum(qc$triggered == "TRUE"), "results JSON agrees with the qc table")
ft <- utils::read.csv(file.path(A, "tables", "feature_table.csv"), stringsAsFactors = FALSE)
check(nrow(ft) == 1000 && res$n_features == 1000, "fixture has 1000 features")
# Anchors: the default-seed fixture counts (shared fixture fx_feature_table(1000, seed = 20260925)).
check(res$n_up == 195 && res$n_down == 175 && res$n_padj_na == 43, sprintf("fixture anchors up/down/NA = 195/175/43 (got %d/%d/%d)", res$n_up, res$n_down, res$n_padj_na))
spec <- jsonlite::fromJSON(file.path(A, "figures", "volcano.figure_spec.json"))
check(spec$counts$up == res$n_up && spec$counts$down == res$n_down, "figure_spec counts agree with the table")
ho <- jsonlite::fromJSON(file.path(A, "objects", "handoff.json"), simplifyVector = FALSE)
check(identical(ho$module, "omicstat-selftest") && identical(ho$ecosystem, "neutral") &&
        setequal(vapply(ho$objects, `[[`, "", "name"), c("feature_table", "colour_registry")), "handoff.json objects")
draft <- readLines(file.path(A, "draft", "methods_results.md"))
check(any(grepl("self-test", draft)), "draft says it is a self-test")
prov <- jsonlite::fromJSON(file.path(A, "provenance", "provenance.json"))
check(all(c("command", "r_version", "lib_paths", "env_version", "seed", "packages") %in% names(prov)), "provenance fields")
failed <- any(qc$triggered == "TRUE" & qc$severity %in% c("blocker", "error"))

# ---- determinism ---------------------------------------------------------------
b <- run("--outdir", file.path(work, "b"))
B <- file.path(work, "b")
same <- c("tables/feature_table.csv", "qc/qc_results.csv", "figures/volcano.png", "draft/methods_results.md",
          "environment_report.md", "results/selftest_summary.json", "objects/colour_registry.json", "qc/engine_warnings.csv")
check(b$status == 0 && all(vapply(same, function(f) sha(file.path(A, f)) == sha(file.path(B, f)), logical(1))),
      "rerun is byte-identical (tables, qc, png, draft, report, results)")
check(jsonlite::fromJSON(file.path(A, "figures", "volcano.figure_spec.json"))$files$pdf$content_sha256 ==
        jsonlite::fromJSON(file.path(B, "figures", "volcano.figure_spec.json"))$files$pdf$content_sha256, "PDF content hash is stable")

# ---- flag effectiveness --------------------------------------------------------
s <- run("--outdir", file.path(work, "seed"), "--seed", "7")
check(s$status == 0 && sha(file.path(work, "seed", "tables", "feature_table.csv")) != sha(file.path(A, "tables", "feature_table.csv")), "--seed changes the fixture")
# (science, not cell: the shared volcano's 5.5 pt labels fail the Cell 6 pt lint minimum, see troubleshooting.md)
j <- run("--outdir", file.path(work, "science"), "--journal", "science")
check(j$status == 0 && identical(jsonlite::fromJSON(file.path(work, "science", "figures", "volcano.figure_spec.json"))$journal, "science"), "--journal reaches the figure spec")
st <- run("--outdir", file.path(work, "strict"), "--strict")
check(if (failed) st$status != 0 && any(grepl("OS_ENV_CHECK_FAILED", st$out)) else st$status == 0,
      sprintf("--strict exit status follows the verdict (verdict %s)", if (failed) "FAIL" else "PASS"))

# ---- ST-08: a native session whose search path is not isolated is a blocker ----
# OMICSTAT_R_LIBS names an empty library and no Rprofile.omicstat is loaded, so
# every entry of .libPaths() except .Library lies outside the omicstat library.
empty_lib <- file.path(work, "empty_lib"); dir.create(empty_lib)
k <- run("--outdir", file.path(work, "leak"),
         env = c("OMICSTAT_CONTAINER=", "R_PROFILE_USER=", paste0("OMICSTAT_R_LIBS=", empty_lib)))
kq <- utils::read.csv(file.path(work, "leak", "qc", "qc_results.csv"), stringsAsFactors = FALSE, colClasses = "character")
k8 <- kq[kq$id == "ST-08", ]
child_paths <- unlist(jsonlite::fromJSON(file.path(work, "leak", "provenance", "provenance.json"))$lib_paths)
leaks <- setdiff(child_paths, c(normalizePath(empty_lib, winslash = "/"), normalizePath(.Library, winslash = "/")))
check(k$status == 0 && identical(k8$triggered, if (length(leaks)) "TRUE" else "FALSE") &&
        identical(k8$blocking, k8$triggered) && kq$triggered[kq$id == "ST-07"] == "FALSE",
      sprintf("native mode: library leak -> ST-08 blocker (%d leaking path(s))", length(leaks)))

check(!file.exists(file.path(work, "Rplots.pdf")), "no Rplots.pdf device leak")
setwd(old_wd)
unlink(work, recursive = TRUE)
if (length(failures)) quit(status = 1) else cat("SMOKE PASSED\n")
