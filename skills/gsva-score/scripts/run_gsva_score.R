# run_gsva_score.R -- GSVA parameter-object scoring and typed score hand-off (no inference; S1 P-3 owner-pending).
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.suite <- normalizePath(file.path(.module_dir, "..", ".."))
.shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "handoff.R", "enrich_rank_io.R", "limma_io.R", "fig_all.R")) source(file.path(.shared, f))
for (f in c("gsva_score_core.R", "gsva_score_report.R", "gsva_score_qc.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(
  usage = "Rscript run_gsva_score.R --input <csv>|--from-run <dir> --input-scale <scale> --outdir <dir> [options]",
  description = "GSVA pathway scores from continuous expression, handed on for later analysis; no group inference.",
  flags = list(
    os_flag("input", "path", must_exist = TRUE, help = "feature-by-sample expression CSV"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream expression_matrix / batch_corrected_matrix handoff or limma run"),
    os_flag("upstream-object", "string", help = "object name if upstream has several expression matrices"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay prior resolved spec"),
    os_flag("input-scale", "enum", required = TRUE, values = c("vst", "logcpm", "normalized_array", "counts"), help = "declared expression scale"),
    os_flag("kcdf", "enum", default = "auto", values = c("auto", "Gaussian", "Poisson", "none"), help = "GSVA ECDF kernel choice; counts require explicit Poisson"),
    os_flag("collection", "string", default = "msigdb_collections", help = "offline registered collection ID"),
    os_flag("gene-sets", "path", must_exist = TRUE, help = "registered local GMT matching its SHA-256"),
    os_flag("min-size", "int", default = 5L, range = c(1, 100000), help = "minimum set size after ID intersection and constant-row removal"),
    os_flag("max-size", "int", default = 500L, range = c(1, 100000), help = "maximum set size after ID intersection and constant-row removal"),
    os_flag("samples", "path", must_exist = TRUE, help = "sample table for group annotation of the figures"),
    os_flag("sample-col", "string", default = "sample", help = "sample ID column"),
    os_flag("group-col", "string", default = "condition", help = "group column for display"),
    os_flag("reference", "string", help = "inference request: refused, OS_OWNER_DECISION_PENDING"),
    os_flag("target", "string", help = "inference request: refused, OS_OWNER_DECISION_PENDING"),
    os_flag("covariates", "string", help = "inference request: refused, OS_OWNER_DECISION_PENDING"),
    os_flag("seed", "int", default = 20260925L, help = "recorded RNG seed"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")),
  exclusive = list(c("input", "from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (!is.null(a$reference) || !is.null(a$target) || !is.null(a$covariates))
  stop(paste0("OS_OWNER_DECISION_PENDING: group inference on GSVA scores is not available. Which limma entry receives the scores ",
              "and the eBayes trend/robust (gene-set size trend) settings are an owner decision still pending (S1 P-3); this module ",
              "scores and hands on only. Remove --reference/--target/--covariates; tables/scores.csv and the typed hand-off carry ",
              "the scores."), call. = FALSE)
if (is.null(a$input) && is.null(a[["from-run"]])) stop("OS_MISSING_PARAMETER: give --input or --from-run.", call. = FALSE)
if (a[["min-size"]] > a[["max-size"]]) stop("OS_INVALID_PARAMETER: --min-size exceeds --max-size.", call. = FALSE)
if (a[["input-scale"]] == "counts" && (a$kcdf != "Poisson" || !"kcdf" %in% attr(a, "given")))
  stop("OS_INVALID_PARAMETER: integer counts require explicit --kcdf Poisson.", call. = FALSE)
if (a[["input-scale"]] != "counts" && a$kcdf == "Poisson")
  stop("OS_INVALID_PARAMETER: Poisson kernel requires declared counts input.", call. = FALSE)
canon <- os_canonical_argv(SPEC, a)
options(omicstat.journal = a$journal)
set.seed(a$seed)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(a$outdir, winslash = "/")
elog <- os_engine_log_new(outdir)

upstream <- if (is.null(a[["from-run"]])) NULL else read_handoff(a[["from-run"]])
corrected_input <- FALSE
samples_path <- a$samples
group_col <- a[["group-col"]]
mat <- NULL
st_in <- NULL
source_info <- list(sentence = "Expression was read from a feature-by-sample CSV file.", object = "csv")
if (is.null(upstream)) {
  input_path <- a$input
} else if (upstream$module %in% c("limma-voom", "limma-array", "limma-dupcor")) {
  # S4 contract b: the real limma hand-off (EList E; GSVA does not use the weights).
  if (isTRUE(upstream$batch_corrected_lineage)) os_handoff_assert_uncorrected(upstream, "fit", "GSVA scoring of a limma run")
  lh <- os_limma_handoff_read(upstream)
  want <- if (grepl("counts per million", lh$scale, fixed = TRUE)) "logcpm" else "normalized_array"
  if (!identical(a[["input-scale"]], want))
    stop(sprintf("OS_HANDOFF_MISMATCH: the %s run hands on %s on the scale '%s'; declare --input-scale %s.",
                 lh$producer, lh$source, lh$scale, want), call. = FALSE)
  mat <- lh$E
  input_path <- upstream$objects[[if (identical(lh$source, "EList")) "elist" else "expression_matrix"]]$path
  if (!is.null(lh$samples)) {
    if (!identical(a[["sample-col"]], "sample")) stop("OS_CONFLICTING_PARAMETERS: a limma sample table uses the column 'sample'.", call. = FALSE)
    st_in <- lh$samples
    if (!"group-col" %in% attr(a, "given") && !is.null(lh$condition)) group_col <- lh$condition
  }
  wp <- !is.null(lh$weights)
  source_info <- list(
    sentence = sprintf(paste0("Expression was the %s matrix E (%s) of %s %s run %s (tested coefficient %s); %s. ",
                              "GSVA used E only%s."),
                       lh$source, lh$scale, lh$producer, lh$producer_version, upstream$run_id, lh$coefficient,
                       if (wp) "that EList also carries observation-level precision weights" else "no observation weights were handed on",
                       if (wp) " and does not use the precision weights" else ""),
    object = lh$source, run_id = upstream$run_id, module = lh$producer, scale = lh$scale, weights_present = wp)
} else {
  objs <- upstream$objects
  candidates <- names(objs)[vapply(objs, function(x) x$type %in% c("expression_matrix", "batch_corrected_matrix"), logical(1))]
  if (!is.null(a[["upstream-object"]])) candidates <- intersect(candidates, a[["upstream-object"]])
  if (length(candidates) != 1L) stop("OS_HANDOFF_MISMATCH: select exactly one upstream expression matrix with --upstream-object.", call. = FALSE)
  input_path <- objs[[candidates]]$path
  corrected_input <- identical(objs[[candidates]]$type, "batch_corrected_matrix") || isTRUE(upstream$batch_corrected_lineage)
  source_info <- list(sentence = sprintf("Expression was the %s object '%s' of upstream run %s (%s).", objs[[candidates]]$type,
                                         candidates, upstream$run_id, upstream$module),
                      object = objs[[candidates]]$type, run_id = upstream$run_id, module = upstream$module)
  if (is.null(samples_path)) {
    sample_candidates <- names(objs)[vapply(objs, function(x) identical(x$type, "sample_table"), logical(1))]
    if (length(sample_candidates) == 1L) samples_path <- objs[[sample_candidates]]$path
  }
}
if (is.null(mat)) mat <- os_read_matrix(input_path, "expression matrix")
if (any(!is.finite(mat))) stop("OS_INVALID_INPUT: expression matrix must be finite.", call. = FALSE)
if (a[["input-scale"]] == "counts" && (any(mat < 0) || any(abs(mat - round(mat)) > 1e-8)))
  stop("OS_INVALID_INPUT: counts mode requires nonnegative integer expression.", call. = FALSE)
if (a[["input-scale"]] != "counts" && all(mat >= 0) && all(abs(mat - round(mat)) < 1e-8))
  stop("OS_INVALID_INPUT: integer-like expression requires counts mode and explicit Poisson kcdf.", call. = FALSE)
st <- NULL
if (!is.null(st_in)) {
  st <- os_align_samples(mat, st_in, "sample")
} else if (!is.null(samples_path)) {
  st <- os_align_samples(mat, os_read_sample_table(samples_path, a[["sample-col"]]), a[["sample-col"]])
}
if (!is.null(st) && !group_col %in% names(st)) {
  if ("group-col" %in% attr(a, "given")) stop("OS_MISSING_COLUMN: group column is absent from sample table.", call. = FALSE)
  group_col <- NULL
}
if (is.null(st)) group_col <- NULL
collection <- os_genesets_read(.suite, a$collection, a[["gene-sets"]])
r <- os_engine_capture(gsva_score_compute(mat, collection, a), "compute", elog)
rend <- os_engine_capture(gsva_score_render(r, a, st, group_col, outdir), "render", elog)
qc <- os_engine_capture({ q <- gsva_score_qc(r, a, corrected_input); os_write_qc_results(q, outdir); q }, "qc", elog)
os_engine_capture({
  gsva_score_report(r, a, qc, collection, outdir, file.path(.module_dir, "references", "reporting-templates.md"),
                    corrected_input, source_info, rend$figures)
  obj <- file.path(outdir, "objects")
  dir.create(obj, showWarnings = FALSE)
  saveRDS(r$param, file.path(obj, "gsva_param.rds"), version = 3)
  set_path <- file.path(obj, "gene_sets.gmt")
  os_write_text(vapply(sort(names(collection$sets), method = "radix"), function(n)
    paste(c(n, a$collection, collection$sets[[n]]), collapse = "\t"), ""), set_path)
  # S4 contract c: scores of a batch-corrected input keep the corrected type
  # and the run marks its lineage, so no downstream module can test them.
  objects <- list(expression_matrix = list(path = rend$score_path, type = if (corrected_input) "batch_corrected_matrix" else "expression_matrix"),
                  gene_set_sizes = list(path = rend$size_path, type = "gene_set_sizes"),
                  gene_sets = list(path = set_path, type = "gene_sets"))
  if (!is.null(st)) {
    sp <- file.path(obj, "sample_table.csv")
    if (!is.null(st_in) || is.null(samples_path)) utils::write.csv(st, sp, row.names = FALSE) else file.copy(samples_path, sp, overwrite = TRUE)
    objects$sample_table <- list(path = sp, type = "sample_table")
  }
  state <- list(input_scale = a[["input-scale"]], input_storage = r$input_storage,
                input_object = source_info$object, precision_weights_used = FALSE,
                kcdf_requested = a$kcdf, kernel_used = r$kernel, collection = a$collection,
                collection_species = collection$entry$species, collection_sha256 = collection$sha256,
                n_scored = r$n_scored, n_excluded = r$n_excluded, n_constant_rows = r$n_constant_rows,
                inference = FALSE, score_inference_pending = TRUE, corrected_input = corrected_input)
  if (corrected_input) state$batch_corrected_lineage <- TRUE
  if (!is.null(source_info$scale)) state$upstream_scale <- source_info$scale
  write_handoff(outdir, run_id = basename(outdir), module = GV_MODULE, module_version = GV_MODULE_VERSION,
                objects = objects, ecosystem = "neutral", state = state,
                upstream_runs = upstream$upstream_runs %||% character(0))
  outputs <- c("tables/scores.csv", "qc/qc_results.csv", "draft/methods_results.md",
               "results/gsva_score_results.json", rend$extra_paths)
  inputs <- list(expression = input_path)
  if (!is.null(samples_path) && is.null(st_in)) inputs$samples <- samples_path
  if (!is.null(a[["gene-sets"]])) inputs$gene_sets <- a[["gene-sets"]]
  os_write_provenance(outdir, GV_MODULE, GV_MODULE_VERSION, canon, basename(.this), a$seed,
                      inputs = inputs, outputs = outputs, upstream = upstream,
                      extra = list(collection = a$collection, collection_sha256 = collection$sha256,
                                   input_scale = a[["input-scale"]], kernel_used = r$kernel,
                                   input_object = source_info$object, input_source = source_info$sentence,
                                   precision_weights_used = FALSE, inference = FALSE,
                                   batch_corrected_lineage = corrected_input))
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
