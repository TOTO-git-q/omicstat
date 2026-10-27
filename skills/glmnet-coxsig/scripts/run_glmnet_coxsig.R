# Candidate endpoint comparisons; no accepted registration or seal.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "effect_table.R", "handoff.R", "model_io.R", "survival_io.R", "fig_all.R")) source(file.path(.shared, f))
suppressPackageStartupMessages(library(survival)) # timeROC/pec marginal formula resolves Surv on the search path
source(file.path(dirname(.this), "glmnet_coxsig_core.R"))
source(file.path(dirname(.this), "cpm_port_adapter.R"))
source(file.path(dirname(.this), "glmnet_coxsig_report.R"))
source(file.path(dirname(.this), "glmnet_coxsig_qc.R"))
SPEC <- os_arg_spec(usage = "Rscript run_glmnet_coxsig.R --help", description = "LASSO-Cox signature with frozen external validation and time-dependent ROC", flags = list(
 os_flag("mode", "enum", required = TRUE, values = c("train", "validate"), help = "Train or externally validate frozen coefficients"),
 os_flag("from-run", "path", required = TRUE, must_exist = TRUE, help = "Verified expression handoff"),
 os_flag("signature-run", "path", must_exist = TRUE, help = "Frozen cox_signature run for validation"),
 os_flag("clinical", "path", required = TRUE, must_exist = TRUE, help = "Clinical table"),
 os_flag("unit-col", "string", required = TRUE, help = "Unique biological subject identity"),
 os_flag("time-col", "string", required = TRUE, help = "Positive right-censored follow-up"),
 os_flag("event-col", "string", required = TRUE, help = "Explicit zero censored one event"),
 os_flag("time-unit", "string", required = TRUE, help = "Declared units, frozen across cohorts"),
 os_flag("genes", "string", required = TRUE, help = "Ordered prespecified gene IDs"),
 os_flag("covariates", "enum", required = TRUE, values = c("none"), help = "Gene-only signature boundary"),
 os_flag("expression-scale", "enum", required = TRUE, values = c("normalized-log2", "normalized-other"), help = "Declared identical preprocessing scale"),
 os_flag("min-events", "int", required = TRUE, range = c(2, Inf), help = "Minimum observed event count"),
 os_flag("folds", "path", must_exist = TRUE, help = "Training CSV unit,fold; exact biological matching"),
 os_flag("standardize", "enum", values = c("true", "false"), help = "Training glmnet standardization"),
 os_flag("nlambda", "int", range = c(10, 500), help = "Training path grid size"),
 os_flag("lambda-min-ratio", "num", range = c(1e-6, .5), help = "Training path extent"),
 os_flag("selection", "enum", values = c("lambda.min", "lambda.1se", "fixed"), help = "Penalty selection rule"),
 os_flag("lambda", "num", range = c(1e-12, Inf), help = "Fixed penalty value within fitted path"),
 os_flag("cv-measure", "enum", values = c("deviance", "C"), help = "Cross-validation objective"),
 os_flag("cv-grouped", "enum", values = c("true", "false"), help = "Cox CV risk-set evaluation"),
 os_flag("max-iter", "int", range = c(100, 1e7), help = "Training optimizer maximum passes"),
 os_flag("thresh", "num", range = c(1e-12,.001), help = "Training convergence threshold"),
 os_flag("cox-ties", "enum", values = c("breslow"), help = "Explicit version-stable Breslow ties"),
 os_flag("cutoff", "enum", values = c("median", "prespecified"), help = "Training risk split to freeze"),
 os_flag("cutpoint", "num", help = "Prespecified training risk cutoff"),
 os_flag("roc-times", "string", required = TRUE, help = "Sorted IPCW ROC horizons"),
 os_flag("risk-times", "string", required = TRUE, help = "Sorted KM risk times"),
 os_flag("ci-level", "num", required = TRUE, range = c(.5,.9999), help = "KM marginal CI"),
 os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "Figure style"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Prespecified validated contract"),
 os_flag("development-mode", "bool", help = "Explicit candidate execution"),
 os_flag("seed", "int", required = TRUE, help = "Recorded seed; folds never silently regenerated"),
 os_flag("outdir", "path", required = TRUE, help = "New empty output directory"),
 os_flag("prediction-workup", "enum", default = "none", values = c("none", "cpm"), help = "Optional source-copy prediction workup; none preserves original behavior"),
 os_flag("dataset-name", "string", help = "Dataset name for every workup figure; no identifying subject details"),
 os_flag("planning-source", "string", help = "Citation for external prior Riley planning assumptions; never derived from this fitted cohort"),
 os_flag("planning-parameters", "int", range = c(1, Inf), help = "All prespecified candidate parameters, at least every candidate gene"),
 os_flag("planning-cs-r2", "num", range = c(0, 1), help = "Prior anticipated Cox-Snell R-squared, strictly between zero and target shrinkage"),
 os_flag("planning-shrinkage", "num", range = c(0, 1), help = "Prespecified target shrinkage strictly below one; no automatic recommendation"),
 os_flag("planning-rate", "num", range = c(0, Inf), help = "Prior event rate per declared time unit, strictly positive"),
 os_flag("planning-horizon", "num", range = c(0, Inf), help = "Positive planning horizon equal to the primary calibration horizon"),
 os_flag("planning-mean-followup", "num", range = c(0, Inf), help = "Positive prior mean follow-up in the same declared time unit"),
 os_flag("bootstrap-B", "int", range = c(200, Inf), help = "Requested bootstrap budget; source floor200, explicit serial technical cap2000"),
 os_flag("bootstrap-seed", "int", range = c(0, 2147483647), help = "Explicit reproducible bootstrap seed, no inferred seed"),
 os_flag("bootstrap-fit-policy", "enum", values = c("penalized-pipeline"), help = "Acknowledge repeating original penalized CV/fit with original biological folds"),
 os_flag("baseline-estimator", "enum", values = c("frozen-offset-breslow"), help = "Acknowledge training-only baseline at frozen original coefficients, no unpenalized model replacement"),
 os_flag("calibration-horizon", "num", range = c(0, Inf), help = "Primary positive event-risk horizon inside training support, frozen externally"),
 os_flag("calibration-min-bin", "int", range = c(10, Inf), help = "Minimum original subjects per aggregate KM calibration bin"),
 os_flag("calibration-max-bins", "int", range = c(1, 10), help = "Requested maximum bins; no smoothing or invented bin values"),
 os_flag("calibration-slope-fit", "enum", values = c("source-native"), help = "Acknowledge source-native Cox slope diagnostic, distinct from prediction coefficients"),
 os_flag("spec", "path", must_exist = TRUE, help = "Resolved spec replay")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: candidate requires --development-mode", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE))) os_input_stop("output directory must be empty")
set.seed(a$seed); options(omicstat.journal = a$journal)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(glmnet_coxsig_compute(a), "compute", elog)
os_engine_capture(os_module_finish(res, a, "glmnet-coxsig", basename(.this), SPEC,
 upstream = res$upstream, qc_rows = glmnet_coxsig_qc(res), figures_fn = glmnet_coxsig_render), "render", elog)
