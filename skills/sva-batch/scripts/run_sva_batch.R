# run_sva_batch.R -- entry point of module sva-batch (omicstat).
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
source(file.path(.shared, "scripts", "handoff.R"))
source(file.path(dirname(.this), "sva_batch_core.R"))
source(file.path(dirname(.this), "sva_batch_report.R"))
source(file.path(dirname(.this), "sva_batch_qc.R"))

# ---- 2-3. parse_args + typed validation: ONE spec ----------------------------
SPEC <- os_arg_spec(
  usage = "Rscript run_sva_batch.R --input <file> --samples <file> --method <combat|combat_seq|sva|svaseq> --study-var <col> --outdir <dir> [options]",
  description = paste("Batch-effect correction for display and downstream descriptive scoring (never a",
                      "differential-test input): ComBat / ComBat-seq for a known batch, sva / svaseq to",
                      "estimate surrogate variables for an unknown source of variation."),
  flags = list(
    os_flag("input", "path", must_exist = TRUE, help = "genomic measure matrix (csv/tsv; first column feature id): raw integer counts for combat_seq/svaseq, log-scale/normalized values for combat/sva"),
    os_flag("samples", "path", must_exist = TRUE, requires = "input", help = "sample table (csv/tsv) with the sample id column, --study-var, --batch and any --covariates columns"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream run directory (e.g. deseq2-qc) handing on count_matrix (combat_seq/svaseq) or expression_matrix (combat/sva) and sample_table"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay provenance/resolved_spec.json of an earlier run; flags given here win"),
    os_flag("sample-col", "string", default = "sample", help = "sample id column of the sample table"),
    os_flag("method", "enum", required = TRUE, values = SB_METHODS,
            help = "combat/combat_seq correct a KNOWN --batch; sva/svaseq estimate surrogate variables for an UNKNOWN source of variation (no --batch)"),
    os_flag("batch", "string", help = "known batch column (required for combat/combat_seq; not allowed for sva/svaseq)"),
    os_flag("study-var", "string", required = TRUE, help = "protected research/study variable column (the biological effect that must never be removed, PACK P-2)"),
    os_flag("study-var-type", "enum", default = "categorical", values = c("categorical", "continuous"), help = "how --study-var is treated; combat_seq refuses continuous (S1 appendix clarify item, see references/troubleshooting.md)"),
    os_flag("covariates", "string", help = "comma-separated additional columns to protect alongside --study-var (factors)"),
    os_flag("num-sv-method", "enum", default = "be", values = SB_NUM_SV_METHODS, help = "num.sv() method for the number of surrogate variables (sva/svaseq only); 'leek' is an explicit sensitivity option (PACK P-3)"),
    os_flag("pca-ntop", "int", default = SB_PCA_NTOP_DEFAULT, range = c(10, 20000), help = "most-variable features used by the before/after PCA (display only)"),
    os_flag("seed", "int", default = SB_DEFAULT_SEED, help = "random seed; passed explicitly to num.sv() (PACK P-3 lock)"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")),
  exclusive = list(c("input", "from-run")))
argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
args <- os_parse_args(SPEC, argv)
if (isTRUE(args$help)) {
  os_print_help(SPEC)
  quit(status = 0)
}
if (is.null(args$input) && is.null(args[["from-run"]])) stop("OS_MISSING_PARAMETER: give --input with --samples, or --from-run.", call. = FALSE)
if (!is.null(args$input) && is.null(args$samples)) stop("OS_MISSING_PARAMETER: --input needs --samples.", call. = FALSE)
canon_argv <- os_canonical_argv(SPEC, args)   # before any flag is post-processed
args$covariates <- if (!is.null(args$covariates)) trimws(strsplit(args$covariates, ",", fixed = TRUE)[[1]]) else character(0)
sb_check_method_args(args$method, args$batch, args[["study-var"]], args[["study-var-type"]], args$covariates)
seed <- args$seed
set.seed(seed)
options(omicstat.journal = args$journal)
outdir <- args$outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(outdir, winslash = "/")
elog <- os_engine_log_new(outdir)

# ---- 4. input validation ----------------------------------------------------
upstream <- NULL
count_route <- args$method %in% SB_COUNT_METHODS
if (!is.null(args[["from-run"]])) {
  expect_name <- if (count_route) "count_matrix" else "expression_matrix"
  expect <- stats::setNames(list(expect_name, "sample_table"), c(expect_name, "sample_table"))
  upstream <- read_handoff(args[["from-run"]], expect = expect)
  input_path <- upstream$objects[[expect_name]]$path
  samples_path <- upstream$objects$sample_table$path
} else {
  input_path <- args$input
  samples_path <- args$samples
}
colour_reg <- if (!is.null(upstream$objects$colour_registry)) os_colour_registry_read(upstream$objects$colour_registry$path) else os_colour_registry_new()
mat <- os_read_matrix(input_path, "input matrix")
st <- os_align_samples(mat, os_read_sample_table(samples_path, args[["sample-col"]]), args[["sample-col"]])
os_check_sample_condition(st, args[["sample-col"]], args[["study-var"]])
if (!is.null(args$batch)) os_check_sample_condition(st, args[["sample-col"]], args$batch)
cs <- os_count_state(mat)
batch_factor <- sb_batch_factor(st, args$batch)
input_rows <- sb_input_qc(cs, args$method, batch_factor)
input_blockers <- vapply(input_rows, function(rr) rr$blocking, logical(1))
if (any(input_blockers)) {
  qc <- os_qc_finalize(input_rows, read_first = "qc/qc_results.csv")
  os_write_qc_results(qc, outdir)
  os_write_text(c("# sva-batch: draft withheld", "",
                  sprintf("Blocker QC rule(s) %s were triggered before correction; nothing was computed.", paste(qc$blocking_ids, collapse = ", ")),
                  "Read qc/qc_results.csv."), file.path(outdir, "draft", "methods_results.md"))
  cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
  stop(sprintf("OS_QC_BLOCKER: %s triggered on the input; see %s", paste(qc$blocking_ids, collapse = ", "),
               file.path(outdir, "qc", "qc_results.csv")), call. = FALSE)
}

# ---- 5-6. compute -> one result object -------------------------------------
r <- os_engine_capture(sva_batch_compute(mat, st, args, seed), "compute", elog)

# ---- 7. render: tables, figures (ONLY via _shared fig_* functions) ----------
rend <- os_engine_capture(sva_batch_render(r, args, outdir, colour_reg), "render", elog)

# ---- 8. QC ------------------------------------------------------------------
qc <- os_engine_capture({
  q <- sva_batch_qc(input_rows, r, args, elog)
  os_write_qc_results(q, outdir)
  q
}, "qc", elog)

# ---- 9. draft, results, handoff, provenance ---------------------------------
os_engine_capture({
  sva_batch_results_json(r, args, outdir, qc)
  sva_batch_draft(r, args, qc, file.path(.module_dir, "references", "reporting-templates.md"), outdir)
  obj <- file.path(outdir, "objects")
  dir.create(obj, showWarnings = FALSE)
  os_colour_registry_write(rend$colour_registry, file.path(obj, "colour_registry.json"))
  os_write_text(readLines(samples_path, warn = FALSE), file.path(obj, "sample_table.csv"))
  main_name <- if (count_route) "count_matrix" else "expression_matrix"
  objects <- list()
  # Deliberately named like a plain DE-facing object (count_matrix /
  # expression_matrix) but typed "batch_corrected_matrix": read_handoff()
  # (_shared/scripts/handoff.R) already refuses this type whenever a
  # downstream module expects anything else (PACK S1 P-1; SUITE rule 7 /
  # cross-module note "the standard DE path refuses a known-corrected-matrix
  # source"). The ORIGINAL uncorrected matrix is not re-exported here: it was
  # already available upstream (the user's own --input, or an earlier
  # deseq2-qc run); legitimate downstream use is the ORIGINAL data plus
  # --batch or the sv_table object below, added to the DE module's own design.
  objects[[main_name]] <- list(path = rend$tables$corrected, type = "batch_corrected_matrix")
  objects$sample_table <- list(path = file.path(obj, "sample_table.csv"), type = "sample_table")
  objects$colour_registry <- list(path = file.path(obj, "colour_registry.json"), type = "colour_registry")
  if (!is.null(rend$tables$sv_table)) objects$sv_table <- list(path = rend$tables$sv_table, type = "sv_table")
  write_handoff(outdir, run_id = basename(outdir), module = SB_MODULE, module_version = SB_MODULE_VERSION,
                objects = objects, ecosystem = "neutral",
                state = list(method = r$method, study_var = args[["study-var"]], batch_var = args$batch %||% "",
                            n_sv = if (is.na(r$n.sv)) NULL else as.integer(r$n.sv)),
                upstream_runs = upstream$upstream_runs %||% character(0))
  outs <- c("tables/corrected_matrix.csv", "tables/batch_report.md", "qc/qc_results.csv", "draft/methods_results.md",
           "results/sva_batch_results.json")
  if (!is.null(rend$tables$sv_table)) outs <- c(outs, "tables/sv_table.csv")
  if (!is.null(rend$tables$combat_prior)) outs <- c(outs, "tables/combat_prior.csv")
  os_write_provenance(outdir, SB_MODULE, SB_MODULE_VERSION, canon_argv, basename(.this), seed,
                      inputs = list(input = input_path, samples = samples_path), outputs = outs, upstream = upstream,
                      extra = list(method = r$method, n_sv = if (is.na(r$n.sv)) NULL else as.integer(r$n.sv)))
}, "provenance", elog)

# ---- 10. closing line -------------------------------------------------------
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
