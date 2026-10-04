# run_deseq2_qc.R -- entry point of module deseq2-qc (omicstat).
# ASCII only on purpose. Structure follows ENGINEERING_PLAN lock 2 (3.2):
# 1 locate _shared | 2 parse_args | 3 validate params | 4 validate input |
# 5 compute (registered calls only) | 6 result object | 7 render | 8 QC |
# 9 provenance | 10 closing line "N of M rules triggered; read X first".
#
# Sample-level QA (VST/rlog transform, PCA, sample distances) BEFORE any
# differential test. No --from-run input: this module has no upstream (it
# IS the upstream of deseq2-wald / deseq2-lrt via its own handoff.json).

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
source(file.path(.shared, "scripts", "handoff.R"))
source(file.path(dirname(.this), "deseq2_qc_core.R"))
source(file.path(dirname(.this), "deseq2_qc_report.R"))
source(file.path(dirname(.this), "deseq2_qc_qc.R"))

# ---- 2-3. parse_args + typed validation: ONE spec ----------------------------
SPEC <- os_arg_spec(
  usage = "Rscript run_deseq2_qc.R --counts <file> --samples <file> --outdir <dir> [options]",
  description = "DESeq2 sample-level QA (vst/rlog transform, PCA, sample distances) on an RNA-seq count matrix, before any differential test.",
  flags = list(
    os_flag("counts", "path", required = TRUE, must_exist = TRUE, help = "raw integer count matrix (csv/tsv; first column feature id, one column per sample)"),
    os_flag("samples", "path", required = TRUE, must_exist = TRUE, help = "sample table (csv/tsv) with the sample id column and the condition column"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay provenance/resolved_spec.json of an earlier run; flags given here win"),
    os_flag("sample-col", "string", default = "sample", help = "sample id column of the sample table"),
    os_flag("condition", "string", default = "condition", help = "column holding the biological group used to colour PCA/distance figures and as the last design term"),
    os_flag("shape-col", "string", help = "an optional second sample-table column used as the PCA point shape (e.g. batch, sequencing type)"),
    os_flag("covariates", "string", help = "comma-separated extra design columns (factors) placed before --condition, e.g. batch"),
    os_flag("min-count", "int", default = 10L, range = c(0, 1e9), help = "pre-filter: minimum count"),
    os_flag("min-samples", "int", default = 0L, range = c(0, 1e6), help = "pre-filter: samples that must reach the minimum count; 0 = the smaller --condition level, ONLY for a simple two-level, no-covariate design"),
    os_flag("transform", "enum", default = "vst", values = DQ_TRANSFORMS, help = "sample QA transform"),
    os_flag("fit-type", "enum", default = "parametric", values = c("parametric", "local", "mean"), help = "dispersion trend fit (vst/rlog fitType)"),
    os_flag("sf-type", "enum", default = "ratio", values = c("ratio", "poscounts"), help = "size factor estimator (estimateSizeFactors type)"),
    os_flag("ntop", "int", default = 500L, range = c(10, 100000), help = "most-variable features used for the PCA (plotPCA ntop)"),
    os_flag("blind-false-supplement", "bool", help = "also compute and plot the blind = FALSE (design-aware) transform as a labelled supplementary figure; never replaces the primary blind = TRUE QA figure"),
    os_flag("seed", "int", default = DQ_DEFAULT_SEED, help = "random seed (recorded; this pipeline itself is deterministic)"),
    os_flag("journal", "enum", default = "nature", values = DQ_JOURNALS, help = "figure preset")))
argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
args <- os_parse_args(SPEC, argv)
if (isTRUE(args$help)) {
  os_print_help(SPEC)
  quit(status = 0)
}
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
counts_path <- args$counts
samples_path <- args$samples
mat <- os_read_matrix(counts_path, "count matrix")
st <- os_align_samples(mat, os_read_sample_table(samples_path, args[["sample-col"]]), args[["sample-col"]])
dq_check_design_args(st, args$condition, args$covariates)
os_check_sample_condition(st, args[["sample-col"]], args$condition)
cs <- os_count_state(mat)
reps <- os_classify_replicates(os_replicate_counts(st, args$condition, args[["sample-col"]]), blocker_below = 1L, warning_below = 2L)
input_rows <- dq_input_qc(cs, reps)
input_blockers <- vapply(input_rows, function(r) r$blocking, logical(1))
if (any(input_blockers)) {
  qc <- os_qc_finalize(input_rows, read_first = "qc/qc_results.csv")
  os_write_qc_results(qc, outdir)
  os_write_text(c("# deseq2-qc: draft withheld", "",
                  sprintf("Blocker QC rule(s) %s were triggered before any transform; nothing was computed.", paste(qc$blocking_ids, collapse = ", ")),
                  "Read qc/qc_results.csv."), file.path(outdir, "draft", "methods_results.md"))
  cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
  stop(sprintf("OS_QC_BLOCKER: %s triggered on the input; see %s", paste(qc$blocking_ids, collapse = ", "),
               file.path(outdir, "qc", "qc_results.csv")), call. = FALSE)
}

# ---- 5-6. compute -> one result object -------------------------------------
r <- os_engine_capture(deseq2_qc_compute(mat, st, args), "compute", elog)

# ---- 7. render: tables, figures (ONLY via _shared fig_* functions) ----------
lv <- sort(unique(as.character(st[[args$condition]])), method = "radix")
cr <- os_colours_for(lv, family = "group", registry = os_colour_registry_new(), reference = NULL)
rend <- os_engine_capture(deseq2_qc_render(r, args, outdir, cr$registry), "render", elog)

# ---- 8. QC ------------------------------------------------------------------
qc <- os_engine_capture({
  q <- deseq2_qc_qc(input_rows, r, elog)
  os_write_qc_results(q, outdir)
  q
}, "qc", elog)

# ---- 9. draft, results, handoff, provenance ---------------------------------
os_engine_capture({
  deseq2_qc_results_json(r, args, outdir, qc)
  deseq2_qc_draft(r, args, qc, file.path(.module_dir, "references", "reporting-templates.md"), outdir)
  obj <- file.path(outdir, "objects")
  dir.create(obj, showWarnings = FALSE)
  os_colour_registry_write(cr$registry, file.path(obj, "colour_registry.json"))
  file.copy(counts_path, file.path(obj, "count_matrix.csv"), overwrite = TRUE)
  os_write_text(readLines(samples_path, warn = FALSE), file.path(obj, "sample_table.csv"))
  write_handoff(outdir, run_id = basename(outdir), module = DQ_MODULE, module_version = DQ_MODULE_VERSION,
                objects = list(count_matrix = list(path = file.path(obj, "count_matrix.csv"), type = "count_matrix"),
                               sample_table = list(path = file.path(obj, "sample_table.csv"), type = "sample_table"),
                               expression_matrix = list(path = rend$tables$transform, type = "expression_matrix"),
                               colour_registry = list(path = file.path(obj, "colour_registry.json"), type = "colour_registry")),
                ecosystem = "neutral",
                state = list(design = r$design$formula_text, transform = args$transform, transform_blind = TRUE,
                             fit_type = args[["fit-type"]], sf_type = args[["sf-type"]], ntop = args$ntop))
  outs <- c("tables/sample_qc_descriptive.csv", sprintf("tables/%s_matrix.csv", args$transform),
            "tables/size_factors.csv", "tables/sample_distances.csv", "qc/qc_results.csv", "draft/methods_results.md",
            "results/deseq2_qc_results.json")
  os_write_provenance(outdir, DQ_MODULE, DQ_MODULE_VERSION, canon_argv, basename(.this), seed,
                      inputs = list(counts = counts_path, samples = samples_path), outputs = outs,
                      extra = list(design = r$design$formula_text, transform = args$transform))
}, "provenance", elog)

# ---- 10. closing line -------------------------------------------------------
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
