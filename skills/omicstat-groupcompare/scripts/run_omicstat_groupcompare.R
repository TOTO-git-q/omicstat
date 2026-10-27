# Candidate endpoint comparisons; no accepted registration or seal.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "effect_table.R", "handoff.R", "model_io.R", "basic_stats_io.R", "fig_all.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "omicstat_groupcompare_core.R"))
source(file.path(dirname(.this), "gpc_distribution_adapter.R"))
source(file.path(dirname(.this), "omicstat_groupcompare_report.R"))
source(file.path(dirname(.this), "omicstat_groupcompare_qc.R"))
SPEC <- os_arg_spec(usage = "Rscript run_omicstat_groupcompare.R --help", description = "Prespecified biological-unit endpoint comparisons", flags = list(
 os_flag("input", "path", required = TRUE, must_exist = TRUE, help = "Long endpoint CSV"),
 os_flag("response-col", "string", required = TRUE, help = "Finite continuous endpoint column"),
 os_flag("group-col", "string", required = TRUE, help = "Group column"),
 os_flag("unit-col", "string", required = TRUE, help = "Biological unit or paired subject column"),
 os_flag("group-order", "string", required = TRUE, help = "Comma-separated complete group order"),
 os_flag("design", "enum", required = TRUE, values = c("independent", "paired"), help = "Declared unit design"),
 os_flag("technical-policy", "enum", required = TRUE, values = c("reject", "mean"), help = "Reject duplicates or mean declared technical repeats"),
 os_flag("technical-col", "string", help = "Technical identity within unit/group, required for mean policy"),
 os_flag("comparisons", "path", must_exist = TRUE, help = "Prespecified CSV: contrast,group1,group2"),
 os_flag("pairwise-test", "enum", required = TRUE, values = c("none", "welch", "student", "paired-t", "wilcoxon", "paired-wilcoxon"), help = "Explicit contrast test; no data-driven selection"),
 os_flag("omnibus", "enum", required = TRUE, values = c("none", "anova", "welch-anova", "kruskal", "friedman"), help = "Explicit omnibus test"),
 os_flag("rank-method", "enum", required = TRUE, values = c("not-applicable", "exact", "asymptotic"), help = "Wilcoxon exactness; exact refuses ties and zero paired differences"),
 os_flag("adjust", "enum", required = TRUE, values = c("none", "holm", "bonferroni", "BH", "BY"), help = "One family including requested omnibus and pairwise tests"),
 os_flag("family-size", "int", required = TRUE, range = c(1, Inf), help = "Prespecified total family size, at least observed test count"),
 os_flag("ci-level", "num", required = TRUE, range = c(0.5, 0.9999), help = "Two-sided marginal t confidence level"),
 os_flag("display", "enum", required = TRUE, values = c("box", "bar", "interval"), help = "Hypothesis mode: biological points with box/mean; distribution mode: aggregate interval"),
 os_flag("analysis-mode", "enum", default = "hypothesis-tests", values = c("hypothesis-tests", "distribution-effects"), help = "Explicit independent descriptive branch; existing tests remain prespecified"),
 os_flag("distribution-diagnostics", "enum", default = "off", values = c("off", "source-advisory"), help = "Optional copied heuristic advice; never changes the chosen test"),
 os_flag("reference-group", "string", help = "Distribution mode fixed reference; differences are group minus reference"),
 os_flag("quantile-grid", "string", help = "Distribution mode prespecified increasing probabilities inside (0,1), max 101"),
 os_flag("min-cell-n", "int", range = c(10, 1000000), help = "Distribution disclosure threshold; source minimum ten independent biological units"),
 os_flag("outcome-unit", "string", help = "Distribution mode explicit measurement unit"),
 os_flag("inference", "enum", values = c("none", "iid_stratified_bootstrap"), help = "Distribution inference; no automatic method choice"),
 os_flag("bootstrap-replicates", "int", range = c(200, 100000), help = "Explicit source bootstrap count; no hidden truncation"),
 os_flag("min-success-fraction", "num", range = c(.95, 1), help = "Explicit minimum finite bootstrap fraction, at least .95"),
 os_flag("dataset-name", "string", help = "Distribution figure dataset label; not an owner-registration receipt"),
 os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "Figure style preset"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Validated prespecified study declaration"),
 os_flag("development-mode", "bool", help = "Explicit candidate execution"),
 os_flag("seed", "int", required = TRUE, help = "Recorded seed"),
 os_flag("outdir", "path", required = TRUE, help = "New or empty output directory"),
 os_flag("spec", "path", must_exist = TRUE, help = "Resolved spec replay")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: candidate requires --development-mode", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE))) os_input_stop("output directory must be empty")
set.seed(a$seed); options(omicstat.journal = a$journal)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(omicstat_groupcompare_compute(a), "compute", elog)
os_engine_capture(os_module_finish(res, a, "omicstat-groupcompare", basename(.this), SPEC,
 qc_rows = omicstat_groupcompare_qc(res), figures_fn = omicstat_groupcompare_render), "render", elog)
