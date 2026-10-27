# run_deseq2_wald.R -- entry point of module deseq2-wald (omicstat).
# ASCII only on purpose. Structure follows ENGINEERING_PLAN lock 2 (3.2):
# 1 locate _shared | 2 parse_args | 3 validate params | 4 validate input |
# 5 compute (registered calls only) | 6 result object | 7 render | 8 QC |
# 9 provenance | 10 closing line "N of M rules triggered; read X first".

options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })

# ---- 1. locate _shared ------------------------------------------------------
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir, "..", "_shared"))
source(file.path(.shared, "scripts", "args.R"))
source(file.path(.shared, "scripts", "engine_run.R"))
source(file.path(.shared, "scripts", "design_check.R"))
source(file.path(.shared, "scripts", "module_kit.R"))
source(file.path(.shared, "scripts", "fig_all.R"))
source(file.path(.shared, "scripts", "feature_table.R"))
source(file.path(.shared, "scripts", "handoff.R"))
source(file.path(.shared, "scripts", "ranked_list.R"))
source(file.path(dirname(.this), "deseq2_wald_core.R"))
source(file.path(dirname(.this), "deseq2_wald_report.R"))
source(file.path(dirname(.this), "deseq2_wald_qc.R"))

# ---- 2-3. parse_args + typed validation: ONE spec ----------------------------
SPEC <- os_arg_spec(
  usage = "Rscript run_deseq2_wald.R --counts <file> --samples <file> --reference <level> --target <level> --outdir <dir> [options]",
  description = "DESeq2 Wald test for one two-level contrast of an RNA-seq count matrix, with apeglm log2 fold change shrinkage.",
  flags = list(
    os_flag("counts", "path", must_exist = TRUE, help = "raw integer count matrix (csv/tsv; first column feature id, one column per sample)"),
    os_flag("samples", "path", must_exist = TRUE, requires = "counts", help = "sample table (csv/tsv) with the sample id column and the condition column"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream run directory (deseq2-qc) handing on count_matrix and sample_table"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay provenance/resolved_spec.json of an earlier run; flags given here win"),
    os_flag("sample-col", "string", default = "sample", help = "sample id column of the sample table"),
    os_flag("condition", "string", default = "condition", help = "column holding the compared groups"),
    os_flag("reference", "string", required = TRUE, help = "reference (denominator) level of the condition column"),
    os_flag("target", "string", required = TRUE, help = "target (numerator) level of the condition column"),
    os_flag("covariates", "string", help = "comma-separated extra design columns (factors) placed before the condition, e.g. batch"),
    os_flag("min-count", "int", default = 10L, range = c(0, 1e9), help = "pre-filter: minimum count"),
    os_flag("min-samples", "int", default = 0L, range = c(0, 1e6), help = "pre-filter: samples that must reach the minimum count; 0 = the smaller compared group"),
    os_flag("alpha", "num", default = 0.05, range = c(1e-6, 0.5), help = "FDR level: independent-filtering target and significance cutoff for adjusted P"),
    os_flag("lfc-threshold", "num", default = 0, range = c(0, 20), help = "log2 fold change threshold of the Wald null hypothesis (results lfcThreshold)"),
    os_flag("display-lfc-filter", "num", default = 0, range = c(0, 20), help = "display-only filter, log2 units: also list significant features with |log2fc| >= this in tables/display_filtered.csv; never changes padj; 0 = off"),
    os_flag("shrinkage", "enum", default = "apeglm", values = DW_SHRINKAGE, help = "log2 fold change shrinkage estimator"),
    os_flag("fit-type", "enum", default = "parametric", values = c("parametric", "local", "mean"), help = "dispersion trend fit"),
    os_flag("sf-type", "enum", default = "ratio", values = c("ratio", "poscounts"), help = "size factor estimator"),
    os_flag("gene-annotation", "path", must_exist = TRUE, help = "csv/tsv with columns feature_id and symbol (display symbols)"),
    os_flag("top-n", "int", default = 50L, range = c(2, 500), help = "features in the top heatmap"),
    os_flag("label-n", "int", default = 10L, range = c(0, 50), help = "labelled features per direction in volcano and MA plots"),
    os_flag("selected-features", "string", help = "Optional comma-separated predeclared feature IDs for actual normalized sample points"),
    os_flag("selection-reason", "string", requires = "selected-features", help = "Required rationale for the optional selected-feature display; no genome-wide performance claim"),
    os_flag("subject-col", "string", requires = "selected-features", help = "Optional actual biological-subject metadata for deduplicated descriptive n; does not change the model design"),
    os_flag("pair-col", "string", requires = "selected-features", help = "Optional actual pair IDs; no connecting lines without explicit pairing"),
    os_flag("seed", "int", default = DW_DEFAULT_SEED, help = "random seed (recorded; the Wald pipeline itself is deterministic)"),
    os_flag("journal", "enum", default = "nature", values = DW_JOURNALS, help = "figure preset")),
  exclusive = list(c("counts", "from-run")))
argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
args <- os_parse_args(SPEC, argv)
if (isTRUE(args$help)) {
  os_print_help(SPEC)
  quit(status = 0)
}
if (is.null(args$counts) && is.null(args[["from-run"]])) stop("OS_MISSING_PARAMETER: give --counts with --samples, or --from-run.", call. = FALSE)
if (!is.null(args$counts) && is.null(args$samples)) stop("OS_MISSING_PARAMETER: --counts needs --samples.", call. = FALSE)
if (!is.null(args[["selected-features"]]) && (is.null(args[["selection-reason"]]) || !nzchar(trimws(args[["selection-reason"]]))))
  stop("OS_MISSING_PARAMETER: --selected-features needs --selection-reason.", call. = FALSE)
canon_argv <- os_canonical_argv(SPEC, args)   # before any flag is post-processed
args$covariates <- if (!is.null(args$covariates)) trimws(strsplit(args$covariates, ",", fixed = TRUE)[[1]]) else character(0)
if (args$condition %in% args$covariates) stop("OS_CONFLICTING_PARAMETERS: the condition column cannot also be a covariate.", call. = FALSE)
seed <- args$seed
set.seed(seed)
options(omicstat.journal = args$journal)
outdir <- args$outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(outdir, winslash = "/")
elog <- os_engine_log_new(outdir)

# ---- 4. input validation ----------------------------------------------------
upstream <- NULL
if (!is.null(args[["from-run"]])) {
  upstream <- read_handoff(args[["from-run"]], expect = list(count_matrix = "count_matrix", sample_table = "sample_table"))
  counts_path <- upstream$objects$count_matrix$path
  samples_path <- upstream$objects$sample_table$path
} else {
  counts_path <- args$counts
  samples_path <- args$samples
}
colour_reg <- if (!is.null(upstream$objects$colour_registry)) os_colour_registry_read(upstream$objects$colour_registry$path) else os_colour_registry_new()
mat <- os_read_matrix(counts_path, "count matrix")
st <- os_align_samples(mat, os_read_sample_table(samples_path, args[["sample-col"]]), args[["sample-col"]])
dw_check_design_args(st, args$condition, args$reference, args$target, args$covariates)
os_check_sample_condition(st, args[["sample-col"]], args$condition)
dw_check_prefilter_rule(st, args$condition, args$covariates, args[["min-samples"]])
symbols <- NULL
if (!is.null(args[["gene-annotation"]])) {
  ga <- os_read_sample_table(args[["gene-annotation"]], "feature_id")
  if (!"symbol" %in% names(ga)) stop("OS_MISSING_COLUMN: --gene-annotation needs columns feature_id and symbol.", call. = FALSE)
  symbols <- stats::setNames(ga$symbol, ga$feature_id)
}
cs <- os_count_state(mat)
sub_st <- st[st[[args$condition]] %in% c(args$reference, args$target), , drop = FALSE]
sub_st[[args$condition]] <- factor(sub_st[[args$condition]], levels = c(args$reference, args$target))
reps <- os_classify_replicates(os_replicate_counts(sub_st, args$condition, args[["sample-col"]]),
                               blocker_below = DW_REPS_BLOCKER_BELOW, warning_below = DW_REPS_WARNING_BELOW)
input_rows <- dw_input_qc(cs, reps)
input_blockers <- vapply(input_rows, function(r) r$blocking, logical(1))
if (any(input_blockers)) {
  qc <- os_qc_finalize(input_rows, read_first = "qc/qc_results.csv")
  os_write_qc_results(qc, outdir)
  os_write_text(c("# deseq2-wald: draft withheld", "",
                  sprintf("Blocker QC rule(s) %s were triggered before fitting; nothing was estimated.", paste(qc$blocking_ids, collapse = ", ")),
                  "Read qc/qc_results.csv."), file.path(outdir, "draft", "methods_results.md"))
  cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
  stop(sprintf("OS_QC_BLOCKER: %s triggered on the input; see %s", paste(qc$blocking_ids, collapse = ", "),
               file.path(outdir, "qc", "qc_results.csv")), call. = FALSE)
}

# ---- 5-6. compute -> one result object -------------------------------------
r <- os_engine_capture(deseq2_wald_compute(mat, st, args), "compute", elog)
ft <- dw_feature_table(r, args, symbols)
cnt <- dw_counts(ft, args$alpha)
disp <- dw_display_filter(ft, args$alpha, args[["display-lfc-filter"]])
n_symbol_missing <- if (is.null(symbols)) 0L else sum(!nzchar(ft$symbol))

# ---- 7. render: tables, figures (ONLY via _shared fig_* functions) ----------
lv <- sort(unique(as.character(st[[args$condition]])), method = "radix")
cr <- os_colours_for(lv, family = "group", registry = colour_reg, reference = args$reference)
rend <- os_engine_capture(deseq2_wald_render(r, ft, args, outdir, cr$registry, disp), "render", elog)
if (!is.null(rend$colour_registry)) cr$registry <- rend$colour_registry

# ---- 8. QC ------------------------------------------------------------------
qc <- os_engine_capture({
  q <- deseq2_wald_qc(input_rows, r, ft, cnt, args, elog, !is.null(symbols), n_symbol_missing)
  os_write_qc_results(q, outdir)
  q
}, "qc", elog)

# ---- 9. draft, results, handoff, provenance ---------------------------------
os_engine_capture({
  deseq2_wald_results_json(r, ft, cnt, args, outdir, qc, disp)
  deseq2_wald_draft(r, cnt, args, qc, rend, file.path(.module_dir, "references", "reporting-templates.md"), outdir, disp)
  obj <- file.path(outdir, "objects")
  dir.create(obj, showWarnings = FALSE)
  saveRDS(r$dds, file.path(obj, "dds.rds"), version = 3)
  os_colour_registry_write(cr$registry, file.path(obj, "colour_registry.json"))
  file.copy(counts_path, file.path(obj, "count_matrix.csv"), overwrite = TRUE)
  os_write_text(readLines(samples_path, warn = FALSE), file.path(obj, "sample_table.csv"))
  # ranked_list hand-off (MODULE_BUILD_BRIEF sec 3; S1 cross-module rule 2):
  # the unshrunken Wald statistic of this single contrast, named and directed.
  lfc_t <- args[["lfc-threshold"]]
  rl <- os_ranked_list_write(file.path(obj, "ranked_list.csv"), ft$feature_id, ft$symbol, ft$stat, meta = list(
    metric = if (lfc_t > 0) sprintf("DESeq2 Wald statistic of the threshold test (lfcThreshold = %s, altHypothesis = greaterAbs)", format(lfc_t)) else "DESeq2 Wald statistic",
    statistic = "wald_stat", statistic_kind = "test_statistic", lfc_type = NA_character_, directional = TRUE,
    contrast = sprintf("%s: %s vs %s", args$condition, args$target, args$reference),
    positive_end = sprintf("higher expression in %s than in %s", args$target, args$reference),
    negative_end = sprintf("lower expression in %s than in %s", args$target, args$reference),
    null_test = if (lfc_t > 0) sprintf("minimum_effect (lfcThreshold = %s)", format(lfc_t)) else "zero_effect",
    universe = sprintf(paste0("features tested after the pre-filter (count >= %d in >= %d samples) with a finite unshrunken Wald statistic; ",
                              "independent filtering and Cook's distance flags do not remove features from the ranking"),
                       args[["min-count"]], r$prefilter$min_samples_used),
    producer = DW_MODULE, producer_version = DW_MODULE_VERSION, id_type = "feature_id of the input count matrix"))
  write_handoff(outdir, run_id = basename(outdir), module = DW_MODULE, module_version = DW_MODULE_VERSION,
                objects = list(feature_table = list(path = rend$tables$feature_table, type = "feature_table"),
                               dds = list(path = file.path(obj, "dds.rds"), type = "DESeqDataSet"),
                               vst_matrix = list(path = rend$tables$vst, type = "expression_matrix"),
                               count_matrix = list(path = file.path(obj, "count_matrix.csv"), type = "count_matrix"),
                               sample_table = list(path = file.path(obj, "sample_table.csv"), type = "sample_table"),
                               colour_registry = list(path = file.path(obj, "colour_registry.json"), type = "colour_registry"),
                               ranked_list = list(path = rl$path, type = "ranked_list"),
                               ranked_list_meta = list(path = rl$meta_path, type = "ranked_list_meta")),
                ecosystem = "neutral",
                state = list(contrast = sprintf("%s: %s vs %s", args$condition, args$target, args$reference),
                             design = r$design$formula_text, shrinkage = args$shrinkage, alpha = args$alpha,
                             lfc_threshold = args[["lfc-threshold"]], display_lfc_filter = args[["display-lfc-filter"]],
                             ranked_list = rl$meta),
                upstream_runs = upstream$upstream_runs %||% character(0))
  outs <- c("tables/feature_table.csv", "tables/deseq2_results_full.csv", "qc/qc_results.csv", "draft/methods_results.md",
            "results/deseq2_wald_results.json", if (!is.null(disp)) "tables/display_filtered.csv")
  os_write_provenance(outdir, DW_MODULE, DW_MODULE_VERSION, canon_argv, basename(.this), seed,
                      inputs = c(list(counts = counts_path, samples = samples_path),
                                 if (!is.null(args[["gene-annotation"]])) list(gene_annotation = args[["gene-annotation"]])),
                      outputs = c(outs, "objects/ranked_list.csv", "objects/ranked_list.meta.json"), upstream = upstream,
                      extra = list(design = r$design$formula_text, coefficient = r$coef))
}, "provenance", elog)

# ---- 10. closing line -------------------------------------------------------
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
