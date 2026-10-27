# 1 locate; 2 parse; 3 validate; 4 input; 5 compute; 6-9 report; 10 summary.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module, "..", "_shared", "scripts"))
for (f in c("args.R", "engine_run.R", "module_kit.R", "feature_table.R", "handoff.R")) source(file.path(.shared, f))
for (f in c("proda_diff_core.R", "proda_diff_qc.R", "proda_diff_report.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(usage = "Rscript run_proda_diff.R [required flags] --outdir <new-directory>",
 description = "Experimental proDA two-group workflow; numerical acceptance pending.", flags = list(
  os_flag("study-contract", "path", must_exist = TRUE, help = "Actual validated study contract JSON"),
  os_flag("development-mode", "bool", help = "Explicit candidate-only execution"),
  os_flag("matrix", "path", required = TRUE, must_exist = TRUE, help = "protein-by-sample CSV/TSV, NA preserved"),
  os_flag("samples", "path", required = TRUE, must_exist = TRUE, help = "one row per biological sample"),
  os_flag("sample-col", "string", default = "sample", help = "sample identifier column"),
  os_flag("bio-col", "string", required = TRUE, help = "unique independent biological replicate ID column"),
  os_flag("condition", "string", default = "condition", help = "two-group column"),
  os_flag("input-scale", "enum", required = TRUE, values = c("linear", "log2"), help = "declared abundance scale, never inferred"),
  os_flag("zero-policy", "enum", required = TRUE, values = c("observed", "missing"), help = "linear missing zero or observed log2 zero"),
  os_flag("normalization", "enum", required = TRUE, values = c("none", "median"), help = "explicit median normalization choice"),

  os_flag("outdir", "path", required = TRUE, help = "new or empty output directory"),
  os_flag("spec", "path", must_exist = TRUE, help = "resolved specification replay"),
  os_flag("reference", "string", required = TRUE, help = "denominator condition"),
  os_flag("target", "string", required = TRUE, help = "numerator condition"),
  os_flag("feature-id-type", "string", required = TRUE, help = "declared protein identifier namespace"),
  os_flag("alpha", "num", default = 0.05, range = c(0.000001, 0.5), help = "BH display threshold; does not refit"),
  os_flag("label-n", "int", default = 5L, range = c(0, 30), help = "maximum feature labels per direction"),
  os_flag("seed", "int", default = 20261015L, help = "recorded random seed"),
  os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "shared figure style")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!isTRUE(a[["development-mode"]])) stop("OS_MODULE_UNSEALED: explicit development-mode is required", call. = FALSE)
if (!is.null(a[["study-contract"]])) a[["study-contract-sha256"]] <- os_study_contract_read(a[["study-contract"]])$sha256
if (!nzchar(trimws(a[["feature-id-type"]]))) stop("OS_INVALID_PARAMETER: feature-id-type cannot be empty.", call. = FALSE)
if (dir.exists(a$outdir) && length(list.files(a$outdir, all.files = TRUE, no.. = TRUE)))
  stop("OS_OUTPUT_EXISTS: use an empty output directory; stale results are not overwritten.", call. = FALSE)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(a$outdir); set.seed(a$seed); options(omicstat.journal = a$journal)
argv <- os_canonical_argv(SPEC, a); elog <- os_engine_log_new(outdir)
prep <- os_engine_capture({
  mat <- pd_read_matrix(a$matrix)
  st <- os_read_sample_table(a$samples, a[["sample-col"]])
  pd_prepare(mat, st, a)
}, "input", elog)
inputs <- list(matrix = a$matrix, samples = a$samples)
res <- os_engine_capture(proda_diff_compute(prep, a), "compute", elog)
source(file.path(.shared, "fig_all.R"))
qc <- os_engine_capture(proda_diff_report(res, a, outdir, argv, inputs, .module), "report", elog)
cat(sprintf("%d of %d rules triggered; read %s first; acceptance pending\n", qc$n_triggered, qc$n_rules, qc$read_first))
