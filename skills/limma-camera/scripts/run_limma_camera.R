# run_limma_camera.R -- question-first competitive or self-contained gene-set tests.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.suite <- normalizePath(file.path(.module_dir, "..", ".."))
.shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "handoff.R", "ranked_list.R", "enrich_rank_io.R", "limma_io.R", "fig_all.R")) source(file.path(.shared, f))
for (f in c("limma_camera_core.R", "limma_camera_report.R", "limma_camera_qc.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(
  usage = "Rscript run_limma_camera.R --question competitive|self-contained --input <csv>|--ranked-list <csv>|--from-run <dir> --outdir <dir> [options]",
  description = "limma gene-set test chosen by competitive versus self-contained question; one method per run.",
  flags = list(
    os_flag("input", "path", must_exist = TRUE, help = "continuous gene-by-sample expression CSV"),
    os_flag("ranked-list", "path", must_exist = TRUE, help = "feature_id,symbol,score CSV for competitive cameraPR only"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream limma run (EList, design, coefficient), expression_matrix or ranked_list handoff"),
    os_flag("upstream-object", "string", help = "select one upstream object by name (e.g. ranked_list of a limma run)"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay a prior resolved spec"),
    os_flag("question", "enum", required = TRUE, values = c("competitive", "self-contained"), help = "scientific null hypothesis, fixed before computation"),
    os_flag("self-contained-method", "enum", values = c("fry", "roast", "mroast"), help = "explicit method for self-contained question"),
    os_flag("set-id", "string", help = "one registered term ID for roast"),
    os_flag("collection", "string", default = "msigdb_collections", help = "offline registered gene-set collection"),
    os_flag("gene-sets", "path", must_exist = TRUE, help = "local GMT matching registered SHA-256"),
    os_flag("input-scale", "enum", values = c("logcpm", "vst", "normalized_array"), help = "scale of a CSV or non-limma expression input; a limma upstream states its own"),
    os_flag("samples", "path", must_exist = TRUE, help = "sample table for expression input"),
    os_flag("sample-col", "string", default = "sample", help = "sample ID column"),
    os_flag("group-col", "string", default = "condition", help = "condition column"),
    os_flag("reference", "string", help = "reference condition for expression design"),
    os_flag("target", "string", help = "target condition for expression design"),
    os_flag("covariates", "string", help = "comma-separated factor covariates in the design"),
    os_flag("weights", "path", must_exist = TRUE, help = "voom precision-weight matrix matching expression dimensions"),
    os_flag("block-col", "string", help = "repeated-unit column for self-contained tests"),
    os_flag("correlation", "num", range = c(-0.99, 0.99), help = "prespecified or upstream-estimated within-block correlation"),
    os_flag("acknowledge-block-ignored", "bool", help = "run camera on a limma-dupcor upstream although camera cannot model its block"),
    os_flag("rank-metric", "enum", default = "wald_stat", values = c("wald_stat", "moderated_t", "other"), help = "name of ranked statistic of a file without omicstat metadata"),
    os_flag("metric-name", "string", help = "name of another ranking statistic"),
    os_flag("direction", "string", help = "positive score meaning of a ranked file without omicstat metadata"),
    os_flag("alpha", "num", default = 0.05, range = c(0.000001, 0.5), help = "BH adjusted P reporting threshold"),
    os_flag("nrot", "int", default = 9999L, range = c(1999, 100000), help = "rotations for roast/mroast; 1999 development only"),
    os_flag("seed", "int", default = 20260925L, help = "seed for rotation tests"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")),
  exclusive = list(c("input", "ranked-list", "from-run")))
is_replay <- "--spec" %in% commandArgs(trailingOnly = TRUE)
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
# Conflict checks against upstream metadata use the flags the user typed; a --spec replay re-supplies every flag.
given <- if (is_replay) character(0) else attr(a, "given") %||% character(0)
if (is.null(a$input) && is.null(a[["ranked-list"]]) && is.null(a[["from-run"]])) stop("OS_MISSING_PARAMETER: give expression, ranked-list, or upstream run.", call. = FALSE)
if (a$question == "self-contained" && is.null(a[["self-contained-method"]])) stop("OS_MISSING_PARAMETER: self-contained question needs --self-contained-method fry, roast, or mroast.", call. = FALSE)
if (a$question == "competitive" && !is.null(a[["self-contained-method"]])) stop("OS_CONFLICTING_PARAMETERS: self-contained method cannot answer a competitive question.", call. = FALSE)
if (!is.null(a[["set-id"]]) && !identical(a[["self-contained-method"]], "roast")) stop("OS_CONFLICTING_PARAMETERS: --set-id applies only to roast.", call. = FALSE)
if (identical(a[["self-contained-method"]], "roast") && is.null(a[["set-id"]])) stop("OS_MISSING_PARAMETER: roast needs --set-id.", call. = FALSE)
if (!is.null(a[["self-contained-method"]]) && a[["self-contained-method"]] %in% c("roast", "mroast") &&
    a$nrot != 1999L && a$nrot < 9999L) stop("OS_INVALID_PARAMETER: publication nrot is at least 9999; 1999 is development-only.", call. = FALSE)
if (!is.null(a[["block-col"]]) && a$question == "competitive") stop("OS_UNSUPPORTED_DESIGN: competitive camera preset does not take a block; follow the prespecified competitive design or choose a self-contained question.", call. = FALSE)
if (xor(is.null(a[["block-col"]]), is.null(a$correlation))) stop("OS_MISSING_PARAMETER: --block-col and --correlation must be supplied together.", call. = FALSE)
if (a[["rank-metric"]] == "other" && is.null(a[["metric-name"]])) stop("OS_MISSING_PARAMETER: --rank-metric other needs --metric-name.", call. = FALSE)
if (isTRUE(a[["acknowledge-block-ignored"]]) && a$question != "competitive") stop("OS_CONFLICTING_PARAMETERS: --acknowledge-block-ignored applies only to camera (competitive); self-contained tests model the block.", call. = FALSE)
canon <- os_canonical_argv(SPEC, a)
options(omicstat.journal = a$journal)
set.seed(a$seed)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(a$outdir, winslash = "/")
elog <- os_engine_log_new(outdir)

upstream <- if (is.null(a[["from-run"]])) NULL else read_handoff(a[["from-run"]])
input_path <- a$input
rank_path <- a[["ranked-list"]]
samples_path <- a$samples
input <- list(rank = NULL, rank_meta = NULL, matrix = NULL, weights = NULL, samples = NULL, design = NULL, block = NULL,
              correlation = NULL, block_info = NULL, fit = NULL, scale = NULL, weights_label = NULL, producer = NULL,
              source_sentence = NULL, source_object = NULL)
limma_up <- !is.null(upstream) && upstream$module %in% c("limma-voom", "limma-array", "limma-dupcor")
rank_from_upstream <- FALSE
if (!is.null(upstream)) {
  objs <- upstream$objects
  if (limma_up) {
    choice <- a[["upstream-object"]] %||% "elist"
    if (!choice %in% c("elist", "expression_matrix", "ranked_list"))
      stop("OS_HANDOFF_MISMATCH: from a limma run choose --upstream-object elist (default) or ranked_list.", call. = FALSE)
    os_handoff_assert_uncorrected(upstream, if (choice == "ranked_list") "ranked_list" else "fit", "gene-set inference")
    if (choice == "ranked_list") {
      rank_path <- objs$ranked_list$path; rank_from_upstream <- TRUE
    }
  } else {
    choices <- names(objs)[vapply(objs, function(x) x$type %in% c("expression_matrix", "ranked_list", "batch_corrected_matrix"), logical(1))]
    if (!is.null(a[["upstream-object"]])) choices <- intersect(choices, a[["upstream-object"]])
    if (length(choices) != 1L) stop("OS_HANDOFF_MISMATCH: select exactly one upstream expression matrix or ranked list with --upstream-object.", call. = FALSE)
    os_handoff_assert_uncorrected(upstream, choices, "gene-set inference")
    obj <- objs[[choices]]
    if (obj$type == "ranked_list") { rank_path <- obj$path; rank_from_upstream <- TRUE } else input_path <- obj$path
    if (obj$type != "ranked_list" && is.null(samples_path)) {
      sample_choices <- names(objs)[vapply(objs, function(x) identical(x$type, "sample_table"), logical(1))]
      if (length(sample_choices) == 1L) samples_path <- objs[[sample_choices]]$path
    }
  }
}
is_rank <- !is.null(rank_path)
if (is_rank && a$question != "competitive") stop("OS_UNSUPPORTED_DESIGN: self-contained tests need expression samples and a design.", call. = FALSE)
if (is_rank && (!is.null(a$weights) || !is.null(samples_path))) stop("OS_CONFLICTING_PARAMETERS: rank-only cameraPR takes neither weights nor a sample table.", call. = FALSE)
if (is_rank && !is.null(a[["self-contained-method"]])) stop("OS_CONFLICTING_PARAMETERS: ranked statistic is cameraPR only.", call. = FALSE)
if (is_rank && !is.null(a[["input-scale"]])) stop("OS_CONFLICTING_PARAMETERS: --input-scale describes expression input, not a ranked list.", call. = FALSE)

if (is_rank) {
  # Ranking semantics (S4 contract; ranked_list.R): consumed from omicstat metadata, never guessed.
  meta <- NULL
  if (rank_from_upstream) {
    meta <- os_ranked_list_meta(upstream)
  } else if (file.exists(sub("[.]csv$", ".meta.json", rank_path))) {
    meta <- os_ranked_list_meta_check(jsonlite::fromJSON(sub("[.]csv$", ".meta.json", rank_path), simplifyVector = TRUE))
  }
  input$rank <- os_rank_read(rank_path)
  if (!is.null(meta)) {
    if (any(c("direction", "metric-name") %in% given) || ("rank-metric" %in% given && !identical(a[["rank-metric"]], meta$statistic)))
      stop("OS_CONFLICTING_PARAMETERS: the ranked_list metadata states the metric and direction; omit --direction/--rank-metric/--metric-name.", call. = FALSE)
  } else {
    if (is.null(a$direction)) stop("OS_MISSING_PARAMETER: a ranked file without omicstat metadata needs --direction (what a positive score means).", call. = FALSE)
    metric <- if (a[["rank-metric"]] == "other") a[["metric-name"]] else c(wald_stat = "DESeq2 Wald statistic", moderated_t = "limma moderated t-statistic")[[a[["rank-metric"]]]]
    meta <- list(schema = OS_RANKED_LIST_SCHEMA, metric = metric, statistic = if (a[["rank-metric"]] == "other") "other" else a[["rank-metric"]],
                 statistic_kind = "user_declared", lfc_type = NA_character_, directional = TRUE, contrast = "user-declared",
                 positive_end = a$direction, negative_end = "the opposite direction", null_test = "null test not stated in the file",
                 universe = "the rows of the supplied ranked list", producer = "a user-supplied file", producer_version = NA_character_,
                 id_type = "feature_id as supplied", n_excluded_nonfinite = 0L)
  }
  os_ranked_list_assert_directional(meta$metric)
  meta$n_ranked <- nrow(input$rank$table); meta$n_ties <- input$rank$n_tied
  input$rank_meta <- meta
  input$source_sentence <- sprintf("The input was a ranked list of %d features%s.", nrow(input$rank$table),
                                   if (rank_from_upstream) sprintf(" handed on by %s run %s", upstream$module, upstream$run_id) else " read from a CSV file")
  input$source_object <- "ranked_list"
} else if (limma_up) {
  # S4 contract b: the real limma hand-off -- its EList (E + weights), fitted design and tested coefficient.
  lh <- os_limma_handoff_read(upstream)
  clash <- intersect(c("samples", "weights", "covariates", "block-col", "correlation", "sample-col"), given)
  if (length(clash)) stop(sprintf("OS_CONFLICTING_PARAMETERS: the %s run supplies the samples, design, weights and block; do not give --%s.", lh$producer, paste(clash, collapse = ", --")), call. = FALSE)
  for (k in c("reference", "target")) if (k %in% given && !identical(a[[k]], lh[[k]]))
    stop(sprintf("OS_CONFLICTING_PARAMETERS: --%s %s disagrees with the upstream tested coefficient %s (%s vs %s).", k, a[[k]], lh$coefficient, lh$target, lh$reference), call. = FALSE)
  if ("group-col" %in% given && !identical(a[["group-col"]], lh$condition))
    stop(sprintf("OS_CONFLICTING_PARAMETERS: --group-col disagrees with the upstream condition '%s'.", lh$condition), call. = FALSE)
  scale <- if (grepl("counts per million", lh$scale, fixed = TRUE)) "logcpm" else "normalized_array"
  if (!is.null(a[["input-scale"]]) && !identical(a[["input-scale"]], scale))
    stop(sprintf("OS_HANDOFF_MISMATCH: the %s run hands on %s ('%s'); --input-scale %s disagrees.", lh$producer, lh$source, lh$scale, a[["input-scale"]]), call. = FALSE)
  input$matrix <- lh$E; input$weights <- lh$weights; input$samples <- lh$samples; input$scale <- scale; input$producer <- lh$producer
  input$fit <- readRDS(upstream$objects$fit$path)
  if (!identical(rownames(input$fit$coefficients), rownames(lh$E))) stop("OS_HANDOFF_MISMATCH: the limma fit rows differ from the EList rows.", call. = FALSE)
  cond <- as.character(lh$samples[[lh$condition]])
  input$design <- list(matrix = lh$design, contrast = which(colnames(lh$design) == lh$coefficient), coefficient = lh$coefficient,
                       formula = upstream$state$design %||% paste(colnames(lh$design), collapse = " + "),
                       source = sprintf("the fitted design of %s run %s", lh$producer, upstream$run_id),
                       reference = lh$reference, target = lh$target, group_col = lh$condition,
                       n_reference = sum(cond == lh$reference), n_target = sum(cond == lh$target))
  input$weights_label <- if (is.null(lh$weights)) "none" else "observation-level precision weights carried by the upstream EList"
  if (!is.null(lh$block)) {
    bcol <- lh$block$column
    if (!bcol %in% names(lh$samples)) stop("OS_HANDOFF_MISMATCH: the limma sample table lacks the recorded block column.", call. = FALSE)
    if (identical(lh$block$role %||% "correlated_unit", "correlated_unit"))
      limma_camera_assert_blocks(lh$samples[[bcol]], cond, lh$reference, lh$target)
    input$block_info <- list(column = bcol, n_blocks = lh$block$n_blocks, correlation = lh$block$consensus_correlation,
                             source = sprintf("consensus correlation estimated by %s run %s", lh$producer, upstream$run_id))
    if (a$question == "competitive" && !isTRUE(a[["acknowledge-block-ignored"]]))
      stop(sprintf(paste0("OS_UNSUPPORTED_DESIGN: the %s run models repeated units (block %s, correlation %s) but camera cannot model a block. ",
                          "Use --question self-contained (fry/roast/mroast use the block and correlation), or add --acknowledge-block-ignored ",
                          "to run camera without the block as the User's Guide 18.1.10 camera call does."),
                   lh$producer, bcol, format(signif(lh$block$consensus_correlation, 4))), call. = FALSE)
    if (a$question == "self-contained") {
      if (!bcol %in% names(lh$samples)) stop("OS_HANDOFF_MISMATCH: the limma sample table lacks the recorded block column.", call. = FALSE)
      input$block <- lh$samples[[bcol]]; input$correlation <- lh$block$consensus_correlation
    }
  } else if (isTRUE(a[["acknowledge-block-ignored"]])) stop("OS_CONFLICTING_PARAMETERS: the upstream run has no block to ignore.", call. = FALSE)
  input$source_sentence <- sprintf(paste0("The input was the EList handed on by %s %s run %s: E on the %s scale (%d features x %d samples) %s; ",
                                          "the test used this E%s and the upstream design and coefficient unchanged."),
                                   lh$producer, lh$producer_version, upstream$run_id, lh$scale, nrow(lh$E), ncol(lh$E),
                                   if (is.null(lh$weights)) "without observation weights" else "with its observation-level precision weights",
                                   if (is.null(lh$weights)) "" else " and these weights")
  input$source_object <- "EList"
} else {
  if (is.null(samples_path) || is.null(a$reference) || is.null(a$target)) stop("OS_MISSING_PARAMETER: expression route needs sample table, --reference and --target.", call. = FALSE)
  if (identical(a$reference, a$target)) stop("OS_INVALID_DESIGN: reference and target must differ.", call. = FALSE)
  if (is.null(a[["input-scale"]])) stop("OS_MISSING_PARAMETER: expression input needs --input-scale (logcpm, vst or normalized_array) for the Methods.", call. = FALSE)
  if (isTRUE(a[["acknowledge-block-ignored"]])) stop("OS_CONFLICTING_PARAMETERS: --acknowledge-block-ignored applies only to a limma-dupcor upstream.", call. = FALSE)
  input$matrix <- os_read_matrix(input_path, "continuous expression")
  if (any(!is.finite(input$matrix))) stop("OS_INVALID_INPUT: expression matrix must be finite.", call. = FALSE)
  input$samples <- os_align_samples(input$matrix, os_read_sample_table(samples_path, a[["sample-col"]]), a[["sample-col"]])
  if (!a[["group-col"]] %in% names(input$samples)) stop("OS_MISSING_COLUMN: group column is absent.", call. = FALSE)
  groups <- as.character(input$samples[[a[["group-col"]]]])
  if (anyNA(groups) || !setequal(unique(groups), c(a$reference, a$target)) ||
      sum(groups == a$reference) < 2 || sum(groups == a$target) < 2)
    stop("OS_INVALID_DESIGN: expression test needs exactly two named groups with at least two samples each.", call. = FALSE)
  covars <- if (is.null(a$covariates)) character(0) else trimws(strsplit(a$covariates, ",", fixed = TRUE)[[1]])
  if (length(covars) && (any(!nzchar(covars)) || any(!covars %in% names(input$samples)) || a[["group-col"]] %in% covars))
    stop("OS_INVALID_DESIGN: covariates must be existing non-group sample columns.", call. = FALSE)
  if (!is.null(a[["block-col"]]) && !a[["block-col"]] %in% names(input$samples)) stop("OS_MISSING_COLUMN: block column is absent.", call. = FALSE)
  if (!is.null(a$weights)) {
    input$weights <- os_read_matrix(a$weights, "precision weights")
    if (!identical(dimnames(input$weights), dimnames(input$matrix)) || any(!is.finite(input$weights)) || any(input$weights <= 0))
      stop("OS_INVALID_INPUT: weights must match expression IDs and samples and be finite positive values.", call. = FALSE)
  }
  input$design <- limma_camera_design(input$samples, a)
  input$scale <- a[["input-scale"]]
  input$weights_label <- if (is.null(input$weights)) "none" else "observation-level precision weights from --weights"
  if (!is.null(a[["block-col"]])) {
    input$block <- input$samples[[a[["block-col"]]]]; input$correlation <- a$correlation
    input$block_info <- list(column = a[["block-col"]], n_blocks = length(unique(input$block)), correlation = a$correlation,
                             source = "prespecified with --correlation")
  }
  input$source_sentence <- sprintf("The input was a continuous expression matrix on the declared %s scale (%d features x %d samples) %s, %s.",
                                   a[["input-scale"]], nrow(input$matrix), ncol(input$matrix),
                                   if (is.null(upstream)) "read from a CSV file" else sprintf("handed on by %s run %s", upstream$module, upstream$run_id),
                                   if (is.null(input$weights)) "without observation weights" else "with observation-level precision weights from --weights")
  input$source_object <- "expression_matrix"
}
if (!is_rank && !is_replay && "nrot" %in% given && (is.null(a[["self-contained-method"]]) || !a[["self-contained-method"]] %in% c("roast", "mroast")))
  stop("OS_CONFLICTING_PARAMETERS: --nrot affects only roast/mroast.", call. = FALSE)
collection <- os_genesets_read(.suite, a$collection, a[["gene-sets"]])
if (!is.null(a[["set-id"]]) && !a[["set-id"]] %in% names(collection$sets)) stop("OS_INVALID_PARAMETER: --set-id is absent from registered collection.", call. = FALSE)
r <- os_engine_capture(limma_camera_compute(input, collection, a), "compute", elog)
rend <- os_engine_capture(limma_camera_render(r, a, input, outdir), "render", elog)
qc <- os_engine_capture({q <- limma_camera_qc(r, a, input); os_write_qc_results(q, outdir); q}, "qc", elog)
os_engine_capture({
  limma_camera_report(r, a, qc, collection, outdir, file.path(.module_dir, "references", "reporting-templates.md"), input, rend$figures)
  obj <- file.path(outdir, "objects")
  dir.create(obj, showWarnings = FALSE)
  set_path <- file.path(obj, "gene_sets.gmt")
  os_write_text(vapply(sort(names(collection$sets), method = "radix"), function(n)
    paste(c(n, a$collection, collection$sets[[n]]), collapse = "\t"), ""), set_path)
  objects <- list(gene_sets = list(path = set_path, type = "gene_sets"),
                  enrichment_table = list(path = rend$table, type = "enrichment_table"))
  if (is_rank) {
    file.copy(rank_path, file.path(obj, "ranked_list.csv"), overwrite = TRUE)
    objects$ranked_list <- list(path = file.path(obj, "ranked_list.csv"), type = "ranked_list")
  } else if (limma_up) {
    utils::write.csv(input$samples, file.path(obj, "sample_table.csv"), row.names = FALSE)
    objects$sample_table <- list(path = file.path(obj, "sample_table.csv"), type = "sample_table")
  } else {
    file.copy(input_path, file.path(obj, "expression.csv"), overwrite = TRUE)
    file.copy(samples_path, file.path(obj, "samples.csv"), overwrite = TRUE)
    objects$expression_matrix <- list(path = file.path(obj, "expression.csv"), type = "expression_matrix")
    objects$sample_table <- list(path = file.path(obj, "samples.csv"), type = "sample_table")
  }
  write_handoff(outdir, run_id = basename(outdir), module = OLC_MODULE, module_version = OLC_MODULE_VERSION,
                objects = objects, ecosystem = "neutral",
                state = list(question = a$question, method = r$method, collection = a$collection,
                             collection_sha256 = collection$sha256, alpha = a$alpha, input_object = input$source_object,
                             design = r$design$formula %||% NULL, coefficient = r$design$coefficient %||% NULL,
                             weights = input$weights_label %||% "none", block_modelled = r$block_used,
                             inter_gene_cor = if (r$method %in% c("camera", "cameraPR")) 0.01 else NULL,
                             ranked_list = if (is_rank) input$rank_meta else NULL,
                             seed = a$seed, nrot = if (r$method %in% c("roast", "mroast")) a$nrot else NULL),
                upstream_runs = upstream$upstream_runs %||% character(0))
  outputs <- c("tables/gene_set_table.csv", "tables/method_raw.csv", "qc/qc_results.csv",
               "draft/methods_results.md", "results/limma_camera_results.json", rend$outputs)
  inputs <- list()
  if (is_rank) inputs$ranked_list <- rank_path else if (!limma_up) { inputs$expression <- input_path; inputs$samples <- samples_path }
  if (!is.null(a$weights)) inputs$weights <- a$weights
  if (!is.null(a[["gene-sets"]])) inputs$gene_sets <- a[["gene-sets"]]
  os_write_provenance(outdir, OLC_MODULE, OLC_MODULE_VERSION, canon, basename(.this), a$seed,
                      inputs = inputs, outputs = outputs, upstream = upstream,
                      extra = list(question = a$question, method = r$method, input_object = input$source_object,
                                   input_scale = input$scale %||% NULL, weights = input$weights_label %||% "none",
                                   design = r$design$formula %||% NULL, coefficient = r$design$coefficient %||% NULL,
                                   block_modelled = r$block_used,
                                   collection = a$collection, collection_sha256 = collection$sha256))
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
