# Candidate only: explicit development execution; no production registration.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this)); .shared <- file.path(.module, "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "effect_table.R", "handoff.R", "dose_scope_support.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "drc_calibrate_core.R"))
SPEC <- os_arg_spec(usage = "Rscript run_drc_calibrate.R --help", description = "Candidate drc-calibrate; development only", flags = list(
 os_flag("unit-col", "string", required = TRUE, help = "Biological identity column for unknown samples; standards/blanks are assay controls"),
 os_flag("mode", "enum", required = TRUE, values = c("calibration","titer"), help = "Assay analysis mode"),
 os_flag("model", "enum", required = TRUE, values = c("LL4","LL5"), help = "Prespecified standard or titer curve"),
 os_flag("blank-policy", "enum", required = TRUE, values = c("subtract-mean","none"), help = "Explicit blank correction"),
 os_flag("max-cv", "num", required = TRUE, range = c(0.001, 10000), help = "Maximum technical CV percent"),
 os_flag("lloq", "num", required = FALSE, help = "Validated lower quantification limit in well units"),
 os_flag("uloq", "num", required = FALSE, help = "Validated upper quantification limit in well units"),
 os_flag("titer-definition", "enum", required = FALSE, values = c("halfmax","endpoint"), help = "Titer threshold definition"),
 os_flag("endpoint-response", "num", required = FALSE, help = "Corrected response endpoint"),
 os_flag("input", "path", required = TRUE, must_exist = TRUE, help = "Input CSV"),
 os_flag("dose-unit", "string", required = TRUE, help = "Actual concentration unit or reciprocal dilution"),
 os_flag("ci-level", "num", required = TRUE, range = c(0.5, 0.9999), help = "Prespecified confidence level"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Actual validated study contract JSON"),
 os_flag("seed", "int", required = TRUE, help = "Recorded reproducibility seed"),
 os_flag("outdir", "path", required = TRUE, help = "New or empty output directory"),
 os_flag("development-mode", "bool", required = FALSE, help = "Explicit candidate execution"),
 os_flag("spec", "path", required = FALSE, must_exist = TRUE, help = "Replay resolved spec")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
sc_check_run(a)
if (!is.null(a[["study-contract"]])) a[["study-contract-sha256"]] <- os_study_contract_read(a[["study-contract"]])$sha256
elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(drc_calibrate_compute(a), "compute", elog)
source(file.path(.shared, "fig_all.R"))


os_engine_capture(sc_write(res, a, "drc-calibrate", basename(.this), SPEC), "render", elog)
