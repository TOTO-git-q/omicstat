# Independent candidate laboratory planning, copied/adapted under P0-13.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "study_contract.R", "handoff.R", "model_io.R", "fig_all.R"))
  source(file.path(.shared, f))
source(file.path(dirname(.this), "omicstat_samplesize_core.R"))
source(file.path(dirname(.this), "omicstat_samplesize_qc.R"))
source(file.path(dirname(.this), "omicstat_samplesize_report.R"))
SPEC <- os_arg_spec(usage = "Rscript run_omicstat_samplesize.R --help",
  description = "A priori biological-unit planning; no observed power or inferred scientific defaults", flags = list(
  os_flag("design", "enum", required = TRUE, values = c("mean_2sample", "mean_paired", "anova", "prop_2sample", "survival_logrank"), help = "Prespecified laboratory design"),
  os_flag("alpha", "num", required = TRUE, help = "Prespecified per-test significance level in (0,1)"),
  os_flag("power", "num", required = TRUE, help = "Prespecified target power in (0,1)"),
  os_flag("ratio", "num", required = TRUE, help = "Planned group2/group1 allocation ratio; paired and ANOVA require 1"),
  os_flag("dropout", "num", required = TRUE, help = "Anticipated loss fraction in [0,1); zero is an explicit assumption"),
  os_flag("sided", "enum", required = TRUE, values = c("two", "one"), help = "Prespecified sidedness"),
  os_flag("direction", "enum", required = TRUE, values = c("two-sided", "group1-higher", "group1-lower", "omnibus"), help = "Signed effect orientation; not inferred from the supplied effect"),
  os_flag("groups", "string", required = TRUE, help = "Complete ordered comma-separated group or paired-condition names"),
  os_flag("power-grid", "string", required = TRUE, help = "Strictly increasing power values in (0,1), containing --power"),
  os_flag("biological-unit", "enum", required = TRUE, values = c("animal", "donor", "biological-sample", "independent-culture"), help = "Independent experimental unit; technical repeats never count as n"),
  os_flag("unit-description", "string", required = TRUE, help = "Explain independence, allocation and biological replication"),
  os_flag("technical-replicates", "int", required = TRUE, help = "Number of planned technical measurements per biological unit and condition"),
  os_flag("technical-policy", "enum", required = TRUE, values = c("excluded-from-n"), help = "Required exclusion of technical repeats from biological n"),
  os_flag("planning-stage", "enum", required = TRUE, values = c("a-priori"), help = "Only a priori planning; no completed-study observed power"),
  os_flag("effect-source", "enum", required = TRUE, values = c("minimal-important-difference", "independent-pilot", "external-literature", "standardized-convention"), help = "Provenance of the independently chosen planning effect"),
  os_flag("effect-rationale", "string", required = TRUE, help = "Concrete source, assumptions and rationale; no inferred recommendation"),
  os_flag("outcome-unit", "string", required = TRUE, help = "Raw outcome unit or explicitly dimensionless scale"),
  os_flag("mean1", "num", help = "Group1 planning mean"),
  os_flag("mean2", "num", help = "Group2 planning mean"),
  os_flag("sd", "num", help = "Positive common SD"),
  os_flag("sd1", "num", help = "Positive group1 or condition1 SD; pooled Student planning, not Welch"),
  os_flag("sd2", "num", help = "Positive group2 or condition2 SD; pooled Student planning, not Welch"),
  os_flag("mean-diff", "num", help = "Signed group1-minus-group2 paired difference"),
  os_flag("sd-diff", "num", help = "Positive SD of paired differences"),
  os_flag("corr", "num", help = "Paired correlation strictly between -1 and 1"),
  os_flag("k", "int", help = "Number of equal-sized ANOVA groups, integer at least 2"),
  os_flag("f", "num", help = "Positive omnibus Cohen f; cannot be combined with means/sd"),
  os_flag("means", "string", help = "Comma-separated ANOVA planning means in complete group order"),
  os_flag("p1", "num", help = "Group1 planning probability strictly between 0 and 1"),
  os_flag("p2", "num", help = "Group2 planning probability strictly between 0 and 1"),
  os_flag("hr", "num", help = "Positive group1/group2 hazard ratio, different from 1"),
  os_flag("event-prob", "num", help = "Optional pooled event probability in (0,1]; absent means events only, biological N unknown"),
  os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "OmicStat presentation preset; does not change planning values"),
  os_flag("study-contract", "path", must_exist = TRUE, help = "Validated a priori StudyContract; no participant-level input"),
  os_flag("development-mode", "bool", help = "Explicit execution of an unaccepted candidate"),
  os_flag("seed", "int", required = TRUE, help = "Recorded reproducibility seed; no stochastic estimator is substituted"),
  os_flag("outdir", "path", required = TRUE, help = "New or empty output directory"),
  os_flag("spec", "path", must_exist = TRUE, help = "Resolved-spec replay; all scientific assumptions remain explicit")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: candidate requires --development-mode", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE)))
  stop("OS_INVALID_INPUT: output directory must be empty", call. = FALSE)
set.seed(a$seed); options(omicstat.journal = a$journal)
# Reject design/contract errors before creating an output tree or loading a statistical package.
os_samplesize_validate(a)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(omicstat_samplesize_compute(a), "compute", elog)
os_engine_capture(os_module_finish(res, a, "omicstat-samplesize", basename(.this), SPEC,
  qc_rows = omicstat_samplesize_qc(res), figures_fn = omicstat_samplesize_render), "render", elog)
