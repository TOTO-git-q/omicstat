# Candidate endpoint comparisons; no accepted registration or seal.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.shared <- file.path(dirname(dirname(.this)), "..", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "effect_table.R", "handoff.R", "model_io.R", "basic_stats_io.R", "fig_all.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "omicstat_ddct_core.R"))
source(file.path(dirname(.this), "omicstat_ddct_report.R"))
source(file.path(dirname(.this), "omicstat_ddct_qc.R"))
SPEC <- os_arg_spec(usage = "Rscript run_omicstat_ddct.R --help", description = "Biological-unit delta-delta-Ct with explicit assay and replicate declarations", flags = list(
 os_flag("input", "path", required = TRUE, must_exist = TRUE, help = "Long Ct CSV"),
 os_flag("ct-col", "string", required = TRUE, help = "Finite detected Ct column"),
 os_flag("gene-col", "string", required = TRUE, help = "Assay gene column"),
 os_flag("group-col", "string", required = TRUE, help = "Condition column"),
 os_flag("unit-col", "string", required = TRUE, help = "Biological unit or repeated subject column"),
 os_flag("well-col", "string", required = TRUE, help = "Technical well identity within unit/group/gene"),
 os_flag("well-layout", "enum", required = TRUE, values = c("separate", "same"), help = "Separate assays or same-well multiplex matching"),
 os_flag("target-genes", "string", required = TRUE, help = "Prespecified comma-separated target genes"),
 os_flag("reference-gene", "string", required = TRUE, help = "Validated stable reference gene"),
 os_flag("reference-group", "string", required = TRUE, help = "Prespecified calibrator group"),
 os_flag("group-order", "string", required = TRUE, help = "Every observed group in declared order"),
 os_flag("design", "enum", required = TRUE, values = c("independent", "paired"), help = "Biological-unit design"),
 os_flag("inference", "enum", required = TRUE, values = c("descriptive", "welch", "paired-t"), help = "No biological inference, Welch or paired t on delta-Ct"),
 os_flag("ct-max", "num", required = TRUE, range = c(1, Inf), help = "Declared assay detection limit; missing/undetermined/over-limit Ct refused"),
 os_flag("assay-validation", "path", required = TRUE, must_exist = TRUE, help = "JSON declaration of equal near-two efficiency and stable reference"),
 os_flag("adjust", "enum", required = TRUE, values = c("none", "holm", "bonferroni", "BH", "BY"), help = "Family across all target versus calibrator comparisons"),
 os_flag("family-size", "int", required = TRUE, range = c(1, Inf), help = "Prespecified planned comparisons count"),
 os_flag("ci-level", "num", required = TRUE, range = c(0.5, 0.9999), help = "Marginal biological delta-Ct CI level; unused for descriptive mode"),
 os_flag("display", "enum", required = TRUE, values = c("box", "bar"), help = "Biological points with box or arithmetic mean"),
 os_flag("journal", "enum", required = TRUE, values = c("nature", "cell", "science", "generic"), help = "Figure style"),
 os_flag("study-contract", "path", must_exist = TRUE, help = "Validated prespecified scientific declaration"),
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
res <- os_engine_capture(omicstat_ddct_compute(a), "compute", elog)
os_engine_capture(os_module_finish(res, a, "omicstat-ddct", basename(.this), SPEC,
 qc_rows = omicstat_ddct_qc(res), figures_fn = omicstat_ddct_render), "render", elog)
