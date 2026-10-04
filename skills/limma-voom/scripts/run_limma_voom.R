# 1 locate shared; 2 parse; 3 validate; 4 input; 5 compute; 6 result;
# 7 render; 8 QC; 9 provenance; 10 closing line.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module, "..", "_shared", "scripts"))
for (f in c("args.R", "engine_run.R", "module_kit.R", "feature_table.R", "handoff.R", "fig_all.R", "ranked_list.R", "limma_io.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "limma_voom_core.R"))
source(file.path(dirname(.this), "limma_voom_qc.R"))
source(file.path(dirname(.this), "limma_voom_report.R"))
SPEC <- os_arg_spec(
  usage = "Rscript run_limma_voom.R --counts <csv> --samples <csv> --reference <level> --target <level> --outdir <dir>",
  description = "Differential expression from raw RNA-seq counts using edgeR voomLmFit and limma moderation.",
  flags = list(
    os_flag("counts", "path", must_exist = TRUE, help = "raw integer count matrix"),
    os_flag("samples", "path", must_exist = TRUE, help = "sample table matching count columns"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream count_matrix and sample_table handoff"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "resolved spec replay"),
    os_flag("sample-col", "string", default = "sample", help = "sample identifier column"),
    os_flag("condition", "string", default = "condition", help = "compared group column"),
    os_flag("reference", "string", required = TRUE, help = "reference group"),
    os_flag("target", "string", required = TRUE, help = "target group"),
    os_flag("covariates", "string", help = "comma-separated fixed-effect factors"),
    os_flag("interface", "enum", default = "voomLmFit", values = c("voomLmFit", "legacy"), help = "fit interface; legacy reproduces voom plus lmFit"),
    os_flag("sample-weights", "bool", help = "explicitly estimate sample quality weights"),
    os_flag("min-count", "int", default = 10L, range = c(0, 100000L), help = "filterByExpr minimum count"),
    os_flag("alpha", "num", default = 0.05, range = c(0.000001, 0.5), help = "BH significance cutoff"),
    os_flag("min-effect-fc", "num", default = 1, range = c(1, 100), help = "pre-specified minimum effect as a linear fold change; 1 = zero-effect test"),
    os_flag("display-lfc-filter", "num", default = 0, range = c(0, 20), help = "display-only absolute log2 fold change filter; 0 = off"),
    os_flag("label-n", "int", default = 5L, range = c(0, 30), help = "feature labels per direction"),
    os_flag("seed", "int", default = 20260925L, help = "recorded random seed"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")),
  exclusive = list(c("counts", "from-run")))
args <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(args$help)) { os_print_help(SPEC); quit(status = 0) }
if (is.null(args$counts) && is.null(args[["from-run"]])) stop("OS_MISSING_PARAMETER: give --counts and --samples, or --from-run.", call. = FALSE)
if (!is.null(args$counts) && is.null(args$samples)) stop("OS_MISSING_PARAMETER: --counts needs --samples.", call. = FALSE)
argv <- os_canonical_argv(SPEC, args)
set.seed(args$seed)
options(omicstat.journal = args$journal)
outdir <- args$outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(outdir)
elog <- os_engine_log_new(outdir)
upstream <- if (is.null(args[["from-run"]])) NULL else read_handoff(args[["from-run"]], expect = list(count_matrix = "count_matrix", sample_table = "sample_table"))
counts_path <- if (is.null(upstream)) args$counts else upstream$objects$count_matrix$path
samples_path <- if (is.null(upstream)) args$samples else upstream$objects$sample_table$path
mat <- os_read_matrix(counts_path, "raw counts")
st <- os_align_samples(mat, os_read_sample_table(samples_path, args[["sample-col"]]), args[["sample-col"]])
# The compared pair is one coefficient of ~ covariates + condition; further condition
# levels stay in the model as their own groups (RNAseq123 design, S3 F1).
model <- os_limma_design(mat, st, args, allow_multilevel = TRUE)
res <- os_engine_capture(limma_voom_compute(mat, model, args), "compute", elog)
written <- os_engine_capture(os_limma_write(res, mat, model, args, LV_MODULE, LV_MODULE_VERSION, "LV", outdir, .module,
                                             argv, basename(.this), list(counts = counts_path, samples = samples_path), upstream), "render", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", written$qc$n_triggered, written$qc$n_rules, written$qc$read_first))
