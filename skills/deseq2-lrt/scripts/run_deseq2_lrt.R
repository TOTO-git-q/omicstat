# deseq2-lrt entry: nested full/reduced likelihood ratio test.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir, "..", "_shared"))
for (f in c("args.R", "engine_run.R", "design_check.R", "module_kit.R", "fig_all.R", "feature_table.R", "handoff.R")) source(file.path(.shared, "scripts", f))
for (f in c("deseq2_lrt_core.R", "deseq2_lrt_report.R", "deseq2_lrt_qc.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(
  usage = "Rscript run_deseq2_lrt.R --counts <file> --samples <file> --full '<formula>' --reduced '<formula>' --min-samples <n> --outdir <dir> [options]",
  description = "DESeq2 likelihood ratio test of nested RNA-seq designs; joint significance with one labelled coefficient.",
  flags = list(
    os_flag("counts", "path", must_exist = TRUE, help = "raw integer count matrix"),
    os_flag("samples", "path", must_exist = TRUE, requires = "counts", help = "sample table"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream deseq2-qc run"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay resolved spec"),
    os_flag("sample-col", "string", default = "sample", help = "sample ID column"),
    os_flag("full", "string", required = TRUE, help = "full design formula"),
    os_flag("reduced", "string", required = TRUE, help = "nested reduced formula"),
    os_flag("adjust", "string", help = "comma-separated adjustment terms retained in both formulas"),
    os_flag("group-col", "string", help = "sample column colouring figures"),
    os_flag("group-reference", "string", help = "reference level for figure colours"),
    os_flag("time-col", "string", help = "sample time column for trajectory figure"),
    os_flag("min-count", "int", default = 10L, range = c(0, 1e9), help = "pre-filter count threshold"),
    os_flag("min-samples", "int", default = 0L, range = c(0, 1e6), help = "pre-filter sample count; must be explicit and positive"),
    os_flag("alpha", "num", default = 0.05, range = c(1e-6, 0.5), help = "FDR level"),
    os_flag("report-coef", "string", help = "one resultsNames coefficient to report as log2fc"),
    os_flag("fit-type", "enum", default = "parametric", values = c("parametric", "local", "mean"), help = "dispersion trend fit"),
    os_flag("sf-type", "enum", default = "ratio", values = c("ratio", "poscounts"), help = "size factor estimator"),
    os_flag("gene-annotation", "path", must_exist = TRUE, help = "feature_id and symbol table"),
    os_flag("top-n", "int", default = 50L, range = c(2, 500), help = "top heatmap features"),
    os_flag("pattern-clustering", "bool", help = "enable exploratory DEGreport patterns; default off; requires pattern-genes and time-col"),
    os_flag("pattern-genes", "path", must_exist = TRUE, help = "explicit gene selection: one tested gene ID per line; required with pattern-clustering"),
    os_flag("pattern-group-col", "string", help = "DEGreport metadata grouping column; native NULL default"),
    os_flag("pattern-options", "path", must_exist = TRUE, help = "named JSON overrides for native degPatterns arguments; see parameters.md"),
    os_flag("seed", "int", default = DL_DEFAULT_SEED, help = "recorded random seed"),
    os_flag("journal", "enum", default = "nature", values = DL_JOURNALS, help = "figure preset")),
  exclusive = list(c("counts", "from-run")))
argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
a <- os_parse_args(SPEC, argv)
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (isTRUE(a[["pattern-clustering"]]) && (is.null(a[["pattern-genes"]]) || is.null(a[["time-col"]]))) stop("OS_MISSING_PARAMETER: --pattern-clustering requires --pattern-genes and --time-col; gene selection is an explicit scientific choice.", call. = FALSE)
if (is.null(a$counts) && is.null(a[["from-run"]])) stop("OS_MISSING_PARAMETER: give --counts with --samples, or --from-run.", call. = FALSE)
if (!is.null(a$counts) && is.null(a$samples)) stop("OS_MISSING_PARAMETER: --counts needs --samples.", call. = FALSE)
dl_check_prefilter_rule(a[["min-samples"]])
canon_argv <- os_canonical_argv(SPEC, a)
a$adjust <- if (is.null(a$adjust)) character(0) else trimws(strsplit(a$adjust, ",", fixed = TRUE)[[1]])
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
chk <- dl_check_design_args(st, a$full, a$reduced, a$adjust)
a[["group-col"]] <- dl_resolve_group_col(st, a[["group-col"]], chk$vars_full, chk$vars_reduced)
if (!is.null(a[["time-col"]]) && !a[["time-col"]] %in% names(st)) stop("OS_MISSING_COLUMN: --time-col is not in the sample table.", call. = FALSE)
if (!is.null(a[["group-reference"]]) && !a[["group-reference"]] %in% st[[a[["group-col"]]]]) stop("OS_INVALID_PARAMETER: --group-reference is absent from --group-col.", call. = FALSE)
symbols <- NULL
if (!is.null(a[["gene-annotation"]])) {
  ga <- os_read_sample_table(a[["gene-annotation"]], "feature_id")
  if (!"symbol" %in% names(ga)) stop("OS_MISSING_COLUMN: --gene-annotation needs feature_id and symbol.", call. = FALSE)
  symbols <- stats::setNames(ga$symbol, ga$feature_id)
}
des <- dl_design(st, a$full, a$reduced, a$adjust)
cs <- os_count_state(mat)
# For an interaction, replication is assessed in each interaction cell. For
# an additive model, the displayed group is the biological replicate group;
# requiring repeats of every covariate combination would incorrectly block
# the vignette's pasilla ~ type + condition example.
cell <- if (any(grepl(":", .dl_term_labels(des$full_f), fixed = TRUE)))
  interaction(des$coldata[, des$vars_full, drop = FALSE], drop = TRUE, sep = ":") else
  factor(st[[a[["group-col"]]]])
reps_st <- data.frame(sample = rownames(st), design_cell = cell)
reps <- os_classify_replicates(os_replicate_counts(reps_st, "design_cell", "sample"), blocker_below = DL_REPS_BLOCKER_BELOW, warning_below = DL_REPS_WARNING_BELOW)
input_rows <- dl_input_qc(cs, reps)
if (any(vapply(input_rows, function(x) x$blocking, logical(1)))) {
  qc <- os_qc_finalize(input_rows, read_first = "qc/qc_results.csv")
  os_write_qc_results(qc, outdir)
  os_write_text(c("# deseq2-lrt: draft withheld", "", "Input blocker; nothing was estimated. Read qc/qc_results.csv."), file.path(outdir, "draft", "methods_results.md"))
  cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
  stop(sprintf("OS_QC_BLOCKER: %s triggered on the input", paste(qc$blocking_ids, collapse = ", ")), call. = FALSE)
}
r <- os_engine_capture(deseq2_lrt_compute(mat, st, a), "compute", elog)
if (isTRUE(a[["pattern-clustering"]])) {
  genes <- unique(trimws(readLines(a[["pattern-genes"]], warn = FALSE)))
  genes <- genes[nzchar(genes)]
  if (!length(genes) || !all(genes %in% rownames(r$vst))) stop("OS_INVALID_PARAMETER: pattern genes must be nonempty tested genes retained by the prefilter.", call. = FALSE)
  opts <- list(minc=15, summarize="merge", consensusCluster=FALSE, reduce=FALSE,
               cutoff=0.7, scale=TRUE, pattern=NULL, groupDifference=NULL,
               eachStep=FALSE, fixy=NULL, nClusters=NULL, skipDendrogram=TRUE)
  if (!is.null(a[["pattern-options"]])) {
    overrides <- jsonlite::fromJSON(a[["pattern-options"]], simplifyVector=FALSE)
    if (!all(names(overrides) %in% names(opts))) stop("OS_INVALID_PARAMETER: unknown pattern option or attempted fixed-input override.", call. = FALSE)
    for (key in names(overrides)) opts[key] <- overrides[key]
  }
  run_patterns <- function(...) DEGreport::degPatterns(ma=r$vst[genes,,drop=FALSE], metadata=r$sample_table, time=a[["time-col"]], col=a[["pattern-group-col"]], plot=FALSE, ...)
  patterns <- os_engine_capture(do.call(run_patterns, opts), "DEGreport exploratory pattern clustering", elog)
  dir.create(file.path(outdir,"objects"),showWarnings=FALSE)
  dir.create(file.path(outdir,"tables"),showWarnings=FALSE)
  saveRDS(patterns,file.path(outdir,"objects","patterns.rds"))
  utils::write.csv(patterns$df,file.path(outdir,"tables","patterns.csv"),row.names=FALSE)
  jsonlite::write_json(list(gene_selection_file=a[["pattern-genes"]],genes=genes,time=a[["time-col"]],col=a[["pattern-group-col"]],options=opts,package_version=as.character(utils::packageVersion("DEGreport")),interpretation="exploratory display only; no new confirmatory test"),file.path(outdir,"objects","pattern_options.json"),pretty=TRUE,auto_unbox=TRUE,null="null")
}
ft <- dl_feature_table(r, a, symbols)
cnt <- dl_counts(ft, a$alpha)
n_symbol_missing <- if (is.null(symbols)) 0L else sum(!nzchar(ft$symbol))
cr <- os_colours_for(sort(unique(as.character(st[[a[["group-col"]]]])), method = "radix"), family = "group", registry = colour_reg, reference = a[["group-reference"]])
rend <- os_engine_capture(deseq2_lrt_render(r, ft, a, outdir, cr$registry), "render", elog)
qc <- os_engine_capture({ q <- deseq2_lrt_qc(input_rows, r, ft, cnt, a, elog, !is.null(symbols), n_symbol_missing); os_write_qc_results(q, outdir); q }, "qc", elog)
os_engine_capture({
  deseq2_lrt_results_json(r, ft, cnt, a, outdir, qc)
  deseq2_lrt_draft(r, cnt, a, qc, rend, file.path(.module_dir, "references", "reporting-templates.md"), outdir)
  obj <- file.path(outdir, "objects"); dir.create(obj, showWarnings = FALSE)
  saveRDS(r$dds, file.path(obj, "dds.rds"), version = 3)
  os_colour_registry_write(cr$registry, file.path(obj, "colour_registry.json"))
  file.copy(counts_path, file.path(obj, "count_matrix.csv"), overwrite = TRUE)
  os_write_text(readLines(samples_path, warn = FALSE), file.path(obj, "sample_table.csv"))
  write_handoff(outdir, run_id = basename(outdir), module = DL_MODULE, module_version = DL_MODULE_VERSION,
                objects = list(feature_table = list(path = rend$tables$feature_table, type = "feature_table"),
                               dds = list(path = file.path(obj, "dds.rds"), type = "DESeqDataSet"),
                               vst_matrix = list(path = rend$tables$vst, type = "expression_matrix"),
                               count_matrix = list(path = file.path(obj, "count_matrix.csv"), type = "count_matrix"),
                               sample_table = list(path = file.path(obj, "sample_table.csv"), type = "sample_table"),
                               colour_registry = list(path = file.path(obj, "colour_registry.json"), type = "colour_registry")),
                ecosystem = "neutral", state = list(full = r$design$full_formula, reduced = r$design$reduced_formula,
                tested_terms = r$design$tested_terms, df = r$design$df, coefficient = r$used_coef, alpha = a$alpha),
                upstream_runs = upstream$upstream_runs %||% character(0))
  os_write_provenance(outdir, DL_MODULE, DL_MODULE_VERSION, canon_argv, basename(.this), a$seed,
                      inputs = list(counts = counts_path, samples = samples_path),
                      outputs = c("tables/feature_table.csv", "tables/deseq2_lrt_results_full.csv", "qc/qc_results.csv", "draft/methods_results.md", "results/deseq2_lrt_results.json"),
                      upstream = upstream, extra = list(full = r$design$full_formula, reduced = r$design$reduced_formula))
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
