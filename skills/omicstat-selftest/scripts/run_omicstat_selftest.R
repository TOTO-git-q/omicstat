# run_omicstat_selftest.R -- entry point of module omicstat-selftest (omicstat).
# ASCII only on purpose. Structure follows ENGINEERING_PLAN lock 2 (3.2):
# 1 locate _shared | 2 parse_args | 3 validate params | 4 validate input |
# 5 compute (registered calls only) | 6 result object | 7 render | 8 QC |
# 9 provenance | 10 closing line "N of M rules triggered; read X first".
# This module is an ENVIRONMENT SELF-TEST: "input" is the running R session.

options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
# Captured before anything is sourced: fig_style.R switches LC_CTYPE to UTF-8.
.lc_ctype_start <- Sys.getlocale("LC_CTYPE")
.utf8_start <- isTRUE(l10n_info()[["UTF-8"]])

# ---- 1. locate _shared ------------------------------------------------------
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir, "..", "_shared"))
.suite <- normalizePath(file.path(.module_dir, "..", ".."))
source(file.path(.shared, "scripts", "args.R"))
source(file.path(.shared, "scripts", "engine_run.R"))
source(file.path(.shared, "scripts", "feature_table.R"))
source(file.path(dirname(.this), "omicstat_selftest_core.R"))
source(file.path(dirname(.this), "omicstat_selftest_report.R"))
source(file.path(dirname(.this), "omicstat_selftest_qc.R"))

# ---- 2-3. parse_args + typed validation: ONE spec (_shared/scripts/args.R) ---
# The spec drives parsing, the typed OS_* errors and --help (whose lines
# tools/check_defaults.py and the MCP flag whitelist read).
SPEC <- os_arg_spec(
  usage = "Rscript run_omicstat_selftest.R --outdir <dir> [options]",
  description = "Environment self-test of the omicstat R environment (not an analysis).",
  flags = list(
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("strict", "bool", help = "bare switch: exit non-zero when any blocker or error rule is triggered"),
    os_flag("seed", "int", default = ST_DEFAULT_SEED, help = "seed of the synthetic fixture"),
    os_flag("journal", "enum", default = "nature", values = ST_JOURNALS, help = "figure preset of the volcano plot")))
args <- os_parse_args(SPEC, commandArgs(trailingOnly = TRUE))
if (isTRUE(args$help)) {
  os_print_help(SPEC)
  quit(status = 0)
}
seed <- args$seed
journal <- args$journal
strict <- args$strict

# ---- 4. input validation: the environment itself ----------------------------
# The figure layer is sourced only when its packages load, so a broken
# environment still gets a QC table and a report instead of a bare crash.
.figure_ok <- all(vapply(ST_FIGURE_PACKAGES, requireNamespace, logical(1), quietly = TRUE))
if (.figure_ok) {
  source(file.path(.shared, "scripts", "fig_all.R"))
  source(file.path(.shared, "scripts", "handoff.R"))
  os_journal(journal)   # the figure layer agrees with ST_JOURNALS
  options(omicstat.journal = journal)
}
outdir <- args$outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(outdir)) stop(sprintf("OS_INVALID_PARAMETER: cannot create --outdir %s", outdir), call. = FALSE)
outdir <- normalizePath(outdir, winslash = "/")
env <- st_read_env_config(.suite)
# Every warning/message of the stages below goes to qc/engine_warnings.csv
# (stage, type, message) and each warning is echoed to stderr as
# "OS_ENGINE_WARNING: [stage] ..." for the MCP console scan.
elog <- os_engine_log_new(outdir)

# ---- 5-6. compute -> one result object -------------------------------------
res <- os_engine_capture(omicstat_selftest_compute(env, .lc_ctype_start, .utf8_start, .shared, seed), "compute", elog)

# ---- 8 (first). QC: rules are decided from the probe, before rendering ------
qc <- os_engine_capture({
  qc <- omicstat_selftest_qc(res)
  write_qc_results(qc, outdir)
  qc
}, "qc", elog)
counts <- st_counts(res$feature_table)

# ---- 7. render: tables, figures (ONLY via _shared fig_* functions), draft ---
rend <- os_engine_capture({
  if (!.figure_ok) {
    omicstat_selftest_environment_report(res, qc, outdir, NULL)
    stop(sprintf("OS_MISSING_PACKAGE: figure-layer package(s) not loadable (%s); see %s",
                 paste(res$probe$packages$package[res$probe$packages$required & !res$probe$packages$loadable], collapse = ", "),
                 file.path(outdir, "environment_report.md")), call. = FALSE)
  }
  rend <- omicstat_selftest_render(res, outdir, journal, .figure_ok)
  omicstat_selftest_draft(res, qc, counts, outdir, seed, journal, rend$figure)
  omicstat_selftest_environment_report(res, qc, outdir, rend$figure)
  omicstat_selftest_results_json(res, qc, counts, outdir)
  rend
}, "render", elog)

# ---- 9. provenance + handoff --------------------------------------------------
os_engine_capture({
  dir.create(file.path(outdir, "objects"), showWarnings = FALSE)
  colour_reg <- os_colours_for(c("control", "treated"), family = "group", reference = "control")$registry
  os_colour_registry_write(colour_reg, file.path(outdir, "objects", "colour_registry.json"))
  write_handoff(outdir, run_id = basename(outdir), module = ST_MODULE, module_version = ST_MODULE_VERSION,
                objects = list(feature_table = list(path = rend$feature_table, type = "feature_table"),
                               colour_registry = list(path = file.path(outdir, "objects", "colour_registry.json"), type = "colour_registry")),
                ecosystem = "neutral", state = list(selftest = TRUE))
  pkgs <- sort(loadedNamespaces(), method = "radix")
  prov <- list(
    schema = "omicstat.provenance.v1", module = ST_MODULE, module_version = ST_MODULE_VERSION,
    command = paste(c("Rscript", basename(.this), commandArgs(trailingOnly = TRUE)), collapse = " "),
    command_argv = as.list(c("Rscript", basename(.this), commandArgs(trailingOnly = TRUE))),
    r_version = res$probe$r_version_string, platform = res$probe$platform,
    execution_mode = res$probe$mode, env_version = res$probe$env_version %||% NA,
    env_config = res$probe$env_config_path %||% NA, lib_paths = as.list(res$probe$lib_paths),
    seed = seed, journal = journal, strict = strict,
    fixture = list(source = "skills/_shared/tests/fixtures/fig_fixtures.R::fx_feature_table", n = ST_FIXTURE_N, seed = seed),
    figure_style_version = OS_FIG_STYLE_VERSION,
    packages = stats::setNames(lapply(pkgs, function(p) as.character(utils::packageVersion(p))), pkgs),
    outputs = lapply(stats::setNames(nm = c("tables/feature_table.csv", "qc/qc_results.csv", "figures/volcano.png")),
                     function(f) digest::digest(file = file.path(outdir, f), algo = "sha256"))
  )
  dir.create(file.path(outdir, "provenance"), showWarnings = FALSE)
  .st_write_text(jsonlite::toJSON(prov, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null"),
                 file.path(outdir, "provenance", "provenance.json"))
}, "provenance", elog)

# ---- 10. closing line -------------------------------------------------------
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
if (strict && qc$failed) {
  stop(sprintf("OS_ENV_CHECK_FAILED: --strict and rule(s) %s triggered; see %s",
               paste(qc$failed_ids, collapse = ", "), file.path(outdir, "environment_report.md")), call. = FALSE)
}
