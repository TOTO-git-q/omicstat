# Candidate endpoint comparisons; no accepted registration or seal.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "effect_table.R", "handoff.R", "model_io.R", "survival_io.R", "fig_all.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "survival_expr_core.R"))
source(file.path(dirname(.this), "survival_port_adapter.R"))
source(file.path(.shared, "fig_mod_competing.R"))
source(file.path(dirname(.this), "survival_expr_report.R"))
source(file.path(dirname(.this), "survival_expr_qc.R"))
SPEC <- os_arg_spec(usage = "Rscript run_survival_expr.R --help", description = "Expression-handoff Cox/KM with optional copied non-PH and descriptive competing-risk extensions", flags = list(
 os_flag("from-run", "path", required = TRUE, must_exist = TRUE, help = "Verified upstream expression_matrix handoff"),
 os_flag("clinical", "path", required = TRUE, must_exist = TRUE, help = "Clinical CSV one row per biological subject"),
 os_flag("unit-col", "string", required = TRUE, help = "Biological subject identity"),
 os_flag("time-col", "string", required = TRUE, help = "Positive right-censored time"),
 os_flag("event-col", "string", required = TRUE, help = "Explicit zero censored one event"),
 os_flag("time-unit", "string", required = TRUE, help = "Declared follow-up units"),
 os_flag("genes", "string", required = TRUE, help = "Prespecified comma-separated exact gene IDs"),
 os_flag("covariates", "string", required = TRUE, help = "Numeric covariates comma-separated or none"),
 os_flag("expression-scale", "enum", required = TRUE, values = c("normalized-log2", "normalized-other"), help = "Declared normalized expression scale"),
 os_flag("scaling", "enum", required = TRUE, values = c("none", "zscore"), help = "Per-gene Cox units"),
 os_flag("ties", "enum", required = TRUE, values = c("efron", "breslow", "exact"), help = "Cox ties method"),
 os_flag("min-events", "int", required = TRUE, range = c(2, Inf), help = "Prespecified minimum observed events"),
 os_flag("max-iter", "int", required = TRUE, range = c(1, 10000), help = "Cox iteration limit"),
 os_flag("cox-eps", "num", required = TRUE, range = c(1e-12, 0.01), help = "Cox convergence tolerance"),
 os_flag("ph-transform", "enum", required = TRUE, values = c("km", "rank", "identity", "log"), help = "PH time transform"),
 os_flag("ph-alpha", "num", required = TRUE, range = c(0.000001, 0.5), help = "Diagnostic threshold never a gene filter"),
 os_flag("adjust", "enum", required = TRUE, values = c("none", "holm", "bonferroni", "BH", "BY"), help = "Cox gene-family p adjustment"),
 os_flag("family-size", "int", required = TRUE, range = c(1, Inf), help = "Planned Cox gene-family size"),
 os_flag("ci-level", "num", required = TRUE, range = c(0.5, 0.9999), help = "Marginal Wald and KM CI level"),
 os_flag("km-gene", "string", required = TRUE, help = "One prespecified displayed gene"),
 os_flag("cutoff", "enum", required = TRUE, values = c("median", "prespecified", "optimal"), help = "KM split rule"),
 os_flag("cutpoint", "num", help = "Prespecified supplied-expression threshold"),
 os_flag("exploratory", "bool", help = "Explicit optimal-cutoff exploration"),
 os_flag("min-group-fraction", "num", range = c(0.05, 0.49), help = "Exploratory search minimum fraction each group"),
 os_flag("risk-times", "string", required = TRUE, help = "Sorted comma-separated risk table times"),
 os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "Figure style"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Validated prespecified study declaration"),
 os_flag("development-mode", "bool", help = "Explicit candidate execution"),
 os_flag("seed", "int", required = TRUE, help = "Recorded seed"),
 os_flag("outdir", "path", required = TRUE, help = "New empty output directory"),
 os_flag("survival-extension", "enum", default = "none", values = c("none", "nonph", "competing-risks"), help = "Opt-in source port; none preserves the original Cox and KM path"),
 os_flag("dataset-name", "string", help = "Source dataset name printed on each extension figure"),
 os_flag("nonph-primary", "enum", values = c("cox", "piecewise"), help = "Prespecified non-PH primary summary; never selected by diagnostics"),
 os_flag("nonph-transforms", "string", help = "Unique comma-separated km rank identity log transforms including ph-transform"),
 os_flag("nonph-magnitude", "num", range = c(1e-06, Inf), help = "Positive engineering log-HR change threshold; source 0.20 is not a scientific recommendation"),
 os_flag("piecewise-cuts", "string", help = "Sorted unique positive cuts strictly inside follow-up; at most ten"),
 os_flag("piecewise-gene", "string", help = "One prespecified gene for the piecewise HR table"),
 os_flag("piecewise-fit", "enum", values = c("source-native"), help = "Acknowledge copied native Cox defaults distinct from continuous-model controls"),
 os_flag("piecewise-adjust", "enum", values = c("none", "holm", "bonferroni", "BH", "BY"), help = "Explicit period-test multiplicity policy"),
 os_flag("piecewise-family-size", "int", range = c(2, Inf), help = "Planned family includes every period even when not estimable"),
 os_flag("competing-status-col", "string", help = "Distinct column: zero censored and consecutive mutually exclusive event codes"),
 os_flag("event-of-interest", "int", range = c(1, 2147483647), help = "Nominated cause; existing binary event column must equal its indicator"),
 os_flag("cif-estimator", "enum", values = c("aalen-johansen"), help = "Explicit Aalen-Johansen estimator; one-minus-KM is refused"),
 os_flag("cif-interval", "enum", values = c("none"), help = "Acknowledge source point estimates only; no CI or Gray test"),
 os_flag("spec", "path", must_exist = TRUE, help = "Resolved spec replay")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: candidate requires --development-mode", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE))) os_input_stop("output directory must be empty")
set.seed(a$seed); options(omicstat.journal = a$journal)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(survival_expr_compute(a), "compute", elog)
os_engine_capture(os_module_finish(res, a, "survival-expr", basename(.this), SPEC,
 upstream = res$upstream, qc_rows = survival_expr_qc(res), figures_fn = survival_expr_render), "render", elog)
