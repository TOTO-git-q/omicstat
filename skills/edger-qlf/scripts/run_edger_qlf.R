# edgeR quasi-likelihood differential expression: S2 entry.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir, "..", "_shared"))
for (f in c("args.R", "engine_run.R", "design_check.R", "module_kit.R", "fig_all.R", "feature_table.R", "handoff.R")) source(file.path(.shared, "scripts", f))
for (f in c("edger_qlf_core.R", "edger_qlf_report.R", "edger_qlf_qc.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(
  usage = "Rscript run_edger_qlf.R --counts <file> --samples <file> --reference <level> --target <level> --outdir <dir> [options]",
  description = "edgeR robust quasi-likelihood F-test for one RNA-seq group contrast, with optional prespecified minimum-effect test.",
  flags = list(
    os_flag("counts", "path", must_exist = TRUE, help = "raw integer count matrix"),
    os_flag("samples", "path", must_exist = TRUE, requires = "counts", help = "sample table"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream deseq2-qc run"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay resolved spec"),
    os_flag("sample-col", "string", default = "sample", help = "sample ID column"),
    os_flag("condition", "string", default = "condition", help = "comparison group column"),
    os_flag("reference", "string", required = TRUE, help = "reference (denominator) group"),
    os_flag("target", "string", required = TRUE, help = "target (numerator) group"),
    os_flag("covariates", "string", help = "comma-separated design covariates"),
    os_flag("min-count", "int", default = 10L, range = c(0, 1e9), help = "filterByExpr min.count"),
    os_flag("min-total-count", "int", default = 15L, range = c(0, 1e9), help = "filterByExpr min.total.count"),
    os_flag("large-n", "int", default = 10L, range = c(1, 1e6), help = "filterByExpr large.n"),
    os_flag("min-prop", "num", default = 0.7, range = c(0, 1), help = "filterByExpr min.prop"),
    os_flag("alpha", "num", default = 0.05, range = c(1e-6, 0.5), help = "BH FDR threshold"),
    os_flag("treat-fc", "num", default = 0, range = c(0, 1000), help = "prespecified LINEAR fold-change threshold >1 for glmTreat; 0 = QLF F-test"),
    os_flag("display-lfc-filter", "num", default = 0, range = c(0, 20), help = "display-only minimum absolute log2FC; 0 = off"),
    os_flag("legacy", "bool", help = "use legacy edgeR QL method for reproducibility"),
    os_flag("gene-annotation", "path", must_exist = TRUE, help = "feature_id,symbol annotation table"),
    os_flag("top-n", "int", default = 50L, range = c(2, 500), help = "top heatmap gene count"),
    os_flag("label-n", "int", default = 10L, range = c(0, 50), help = "gene labels on volcano and MD plots"),
    os_flag("seed", "int", default = EQ_DEFAULT_SEED, help = "recorded random seed"),
    os_flag("journal", "enum", default = "nature", values = EQ_JOURNALS, help = "figure preset")),
  exclusive = list(c("counts", "from-run")))
argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
a <- os_parse_args(SPEC, argv)
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (is.null(a$counts) && is.null(a[["from-run"]])) stop("OS_MISSING_PARAMETER: give --counts with --samples, or --from-run.", call. = FALSE)
if (!is.null(a$counts) && is.null(a$samples)) stop("OS_MISSING_PARAMETER: --counts needs --samples.", call. = FALSE)
if (a[["treat-fc"]] > 0 && a[["treat-fc"]] <= 1) stop("OS_INVALID_PARAMETER: --treat-fc must be a linear fold change > 1, or 0 to disable glmTreat.", call. = FALSE)
canon_argv <- os_canonical_argv(SPEC, a)
a$covariates <- if (is.null(a$covariates)) character(0) else trimws(strsplit(a$covariates, ",", fixed = TRUE)[[1]])
set.seed(a$seed)
options(omicstat.journal = a$journal)
outdir <- a$outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(outdir, winslash = "/")
elog <- os_engine_log_new(outdir)
upstream <- NULL
if (!is.null(a[["from-run"]])) {
  upstream <- read_handoff(a[["from-run"]], expect = list(count_matrix = "count_matrix", sample_table = "sample_table"))
  counts_path <- upstream$objects$count_matrix$path
  samples_path <- upstream$objects$sample_table$path
} else { counts_path <- a$counts; samples_path <- a$samples }
colour_reg <- if (!is.null(upstream$objects$colour_registry)) os_colour_registry_read(upstream$objects$colour_registry$path) else os_colour_registry_new()
mat <- os_read_matrix(counts_path, "count matrix")
st <- os_align_samples(mat, os_read_sample_table(samples_path, a[["sample-col"]]), a[["sample-col"]])
eq_check_design_args(st, a$condition, a$reference, a$target, a$covariates)
os_check_sample_condition(st, a[["sample-col"]], a$condition)
symbols <- NULL
if (!is.null(a[["gene-annotation"]])) {
  ga <- os_read_sample_table(a[["gene-annotation"]], "feature_id")
  if (!"symbol" %in% names(ga)) stop("OS_MISSING_COLUMN: --gene-annotation needs feature_id and symbol.", call. = FALSE)
  symbols <- stats::setNames(ga$symbol, ga$feature_id)
}
cs <- os_count_state(mat)
sub_st <- st[st[[a$condition]] %in% c(a$reference, a$target), , drop = FALSE]
reps <- os_classify_replicates(os_replicate_counts(sub_st, a$condition, a[["sample-col"]]),
                               blocker_below = EQ_REPS_BLOCKER_BELOW, warning_below = EQ_REPS_WARNING_BELOW)
input_rows <- eq_input_qc(cs, reps)
if (any(vapply(input_rows, function(x) x$blocking, logical(1)))) {
  qc <- os_qc_finalize(input_rows, read_first = "qc/qc_results.csv")
  os_write_qc_results(qc, outdir)
  os_write_text(c("# edger-qlf: draft withheld", "", "Input blocker; nothing was fitted. Read qc/qc_results.csv."), file.path(outdir, "draft", "methods_results.md"))
  cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
  stop(sprintf("OS_QC_BLOCKER: %s triggered on the input", paste(qc$blocking_ids, collapse = ", ")), call. = FALSE)
}
r <- os_engine_capture(edger_qlf_compute(mat, st, a), "compute", elog)
ft <- eq_feature_table(r, a, symbols)
cnt <- eq_counts(ft, a$alpha)
disp <- eq_display_filter(ft, a$alpha, a[["display-lfc-filter"]])
n_symbol_missing <- if (is.null(symbols)) 0L else sum(!nzchar(ft$symbol))
cr <- os_colours_for(r$design$levels, family = "group", registry = colour_reg, reference = a$reference)
rend <- os_engine_capture(edger_qlf_render(r, ft, a, outdir, cr$registry, disp), "render", elog)
qc <- os_engine_capture({ q <- edger_qlf_qc(input_rows, r, ft, cnt, a, elog, !is.null(symbols), n_symbol_missing); os_write_qc_results(q, outdir); q }, "qc", elog)
os_engine_capture({
  edger_qlf_results_json(r, ft, cnt, a, outdir, qc, disp)
  edger_qlf_draft(r, cnt, a, qc, rend, file.path(.module_dir, "references", "reporting-templates.md"), outdir, disp)
  obj <- file.path(outdir, "objects"); dir.create(obj, showWarnings = FALSE)
  saveRDS(r$y, file.path(obj, "dge.rds"), version = 3)
  os_colour_registry_write(cr$registry, file.path(obj, "colour_registry.json"))
  file.copy(counts_path, file.path(obj, "count_matrix.csv"), overwrite = TRUE)
  os_write_text(readLines(samples_path, warn = FALSE), file.path(obj, "sample_table.csv"))
  write_handoff(outdir, run_id = basename(outdir), module = EQ_MODULE, module_version = EQ_MODULE_VERSION,
                objects = list(feature_table = list(path = rend$tables$feature_table, type = "feature_table"),
                               dge = list(path = file.path(obj, "dge.rds"), type = "DGEList"),
                               expression_matrix = list(path = rend$tables$logcpm, type = "expression_matrix"),
                               count_matrix = list(path = file.path(obj, "count_matrix.csv"), type = "count_matrix"),
                               sample_table = list(path = file.path(obj, "sample_table.csv"), type = "sample_table"),
                               colour_registry = list(path = file.path(obj, "colour_registry.json"), type = "colour_registry")),
                ecosystem = "neutral", state = list(contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference),
                  design = r$design$formula_text, legacy = isTRUE(a$legacy), treat_fc_linear = a[["treat-fc"]], alpha = a$alpha),
                upstream_runs = upstream$upstream_runs %||% character(0))
  os_write_provenance(outdir, EQ_MODULE, EQ_MODULE_VERSION, canon_argv, basename(.this), a$seed,
                      inputs = list(counts = counts_path, samples = samples_path),
                      outputs = c("tables/feature_table.csv", "tables/edger_qlf_results_full.csv", "tables/ql_dispersion.csv", "tables/mds_coordinates.csv", "qc/qc_results.csv", "draft/methods_results.md", "results/edger_qlf_results.json", if (!is.null(disp)) "tables/display_filtered.csv"),
                      upstream = upstream, extra = list(design = r$design$formula_text, contrast = r$design$contrast))
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
