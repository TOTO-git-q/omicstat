# run_fgsea_prerank.R -- fgsea-prerank S2 entry point.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.suite <- normalizePath(file.path(.module_dir, "..", ".."))
.shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "handoff.R", "ranked_list.R", "enrich_rank_io.R", "fig_all.R")) source(file.path(.shared, f))
for (f in c("fgsea_prerank_core.R", "fgsea_prerank_report.R", "fgsea_prerank_qc.R")) source(file.path(dirname(.this), f))

SPEC <- os_arg_spec(
  usage = "Rscript run_fgsea_prerank.R --ranked-list <csv> --direction <text>|--from-run <dir> --outdir <dir> [options]",
  description = "Preranked fgsea multilevel enrichment on an offline registered gene-set collection.",
  flags = list(
    os_flag("ranked-list", "path", must_exist = TRUE, help = "CSV with feature_id,symbol,score sorted descending"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream run with a ranked_list handoff"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay a resolved spec"),
    os_flag("rank-metric", "enum", default = "wald_stat", values = c("wald_stat", "moderated_t", "other"), help = "named ranking statistic of a --ranked-list file; with --from-run the upstream ranked_list metadata decides and a conflicting explicit value is refused"),
    os_flag("metric-name", "string", help = "name of another ranking statistic when --rank-metric other"),
    os_flag("direction", "string", help = "meaning of a positive score, e.g. higher in treated than control; required with --ranked-list unless the file carries omicstat ranked_list metadata; taken from the metadata with --from-run"),
    os_flag("collection", "string", default = "msigdb_collections", help = "offline registered collection ID; Hallmark entry awaits M1-3"),
    os_flag("gene-sets", "path", must_exist = TRUE, help = "local GMT whose SHA-256 matches the registry entry"),
    os_flag("min-size", "int", default = 15L, range = c(1, 100000), help = "minimum set size after rank intersection"),
    os_flag("max-size", "int", default = 500L, range = c(1, 100000), help = "maximum set size after rank intersection"),
    os_flag("alpha", "num", default = 0.05, range = c(0.000001, 0.5), help = "BH adjusted P reporting threshold"),
    os_flag("seed", "int", default = 20260925L, help = "RNG seed for fgseaMultilevel"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")),
  exclusive = list(c("ranked-list", "from-run")))
args <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(args$help)) { os_print_help(SPEC); quit(status = 0) }
if (is.null(args[["ranked-list"]]) && is.null(args[["from-run"]])) stop("OS_MISSING_PARAMETER: give --ranked-list or --from-run.", call. = FALSE)
if (args[["min-size"]] > args[["max-size"]]) stop("OS_INVALID_PARAMETER: --min-size exceeds --max-size.", call. = FALSE)
if (args[["rank-metric"]] == "other" && is.null(args[["metric-name"]])) stop("OS_MISSING_PARAMETER: --rank-metric other requires --metric-name.", call. = FALSE)
if (args[["rank-metric"]] != "other" && !is.null(args[["metric-name"]])) stop("OS_CONFLICTING_PARAMETERS: --metric-name applies only to --rank-metric other.", call. = FALSE)
canon <- os_canonical_argv(SPEC, args)
options(omicstat.journal = args$journal)
set.seed(args$seed)
dir.create(args$outdir, recursive = TRUE, showWarnings = FALSE)
outdir <- normalizePath(args$outdir, winslash = "/")
elog <- os_engine_log_new(outdir)

upstream <- if (!is.null(args[["from-run"]])) read_handoff(args[["from-run"]], expect = list(ranked_list = "ranked_list")) else NULL
rank_path <- if (is.null(upstream)) args[["ranked-list"]] else upstream$objects$ranked_list$path
# Ranking semantics (S1 cross-module rule 2; S4 contract a): consumed from the
# upstream ranked_list metadata, never inferred from the producer's name.
given <- attr(args, "given") %||% character(0)
rank_meta <- NULL; meta_validated <- FALSE
if (!is.null(upstream)) {
  rank_meta <- os_ranked_list_meta(upstream)
} else if (file.exists(sub("[.]csv$", ".meta.json", rank_path))) {
  rank_meta <- os_ranked_list_meta_check(jsonlite::fromJSON(sub("[.]csv$", ".meta.json", rank_path), simplifyVector = TRUE))
}
meta_validated <- !is.null(rank_meta)
if (!is.null(rank_meta)) {
  if ("rank-metric" %in% given && !identical(args[["rank-metric"]], "other") && !identical(args[["rank-metric"]], rank_meta$statistic))
    stop(sprintf("OS_CONFLICTING_PARAMETERS: --rank-metric %s disagrees with the ranked_list metadata (%s).", args[["rank-metric"]], rank_meta$statistic), call. = FALSE)
  if ("direction" %in% given && !identical(args$direction, rank_meta$positive_end))
    stop("OS_CONFLICTING_PARAMETERS: --direction disagrees with the ranked_list metadata; omit it, the metadata states the direction.", call. = FALSE)
  metric <- rank_meta$metric
  args$direction <- rank_meta$positive_end
} else {
  if (is.null(args$direction)) stop("OS_MISSING_PARAMETER: --ranked-list without omicstat metadata needs --direction (what a positive score means).", call. = FALSE)
  metric <- if (args[["rank-metric"]] == "other") args[["metric-name"]] else c(wald_stat = "DESeq2 Wald statistic", moderated_t = "limma moderated t-statistic")[[args[["rank-metric"]]]]
  rank_meta <- list(schema = OS_RANKED_LIST_SCHEMA, metric = metric, statistic = if (args[["rank-metric"]] == "other") "other" else args[["rank-metric"]],
                    statistic_kind = "user_declared", lfc_type = NA_character_, directional = TRUE, contrast = "declared by the user",
                    positive_end = args$direction, negative_end = sprintf("the opposite of: %s", args$direction), null_test = "not stated",
                    universe = "the rows of the supplied ranked list", producer = "user-supplied file", producer_version = NA_character_,
                    id_type = "feature_id as supplied")
}
rank <- os_rank_read(rank_path)
rank_meta$n_ranked <- nrow(rank$table); rank_meta$n_ties <- rank$n_tied
collection <- os_genesets_read(.suite, args$collection, args[["gene-sets"]])
r <- os_engine_capture(fgsea_prerank_compute(rank, collection, args), "compute", elog)
rend <- os_engine_capture(fgsea_prerank_render(r, args, outdir, rank_meta), "render", elog)
qc <- os_engine_capture({
  q <- fgsea_prerank_qc(r, args, elog)
  os_write_qc_results(q, outdir)
  q
}, "qc", elog)
os_engine_capture({
  fgsea_prerank_report(r, args, qc, outdir, file.path(.module_dir, "references", "reporting-templates.md"), metric, collection)
  obj <- file.path(outdir, "objects")
  dir.create(obj, showWarnings = FALSE)
  file.copy(rank_path, file.path(obj, "ranked_list.csv"), overwrite = TRUE)
  set_path <- file.path(obj, "gene_sets.gmt")
  lines <- vapply(sort(names(collection$sets), method = "radix"), function(n)
    paste(c(n, args$collection, collection$sets[[n]]), collapse = "\t"), "")
  os_write_text(lines, set_path)
  write_handoff(outdir, run_id = basename(outdir), module = FG_MODULE, module_version = FG_VERSION,
                objects = list(ranked_list = list(path = file.path(obj, "ranked_list.csv"), type = "ranked_list"),
                               gene_sets = list(path = set_path, type = "gene_sets"),
                               enrichment_table = list(path = rend$table, type = "enrichment_table")),
                ecosystem = "neutral", state = list(metric = metric, direction = args$direction, ranked_list_source = rank_meta,
                ranked_list = if (meta_validated) rank_meta else NULL,
                collection = args$collection, collection_version = collection$entry$version,
                collection_sha256 = collection$sha256, alpha = args$alpha),
                upstream_runs = upstream$upstream_runs %||% character(0))
  outs <- c("tables/enrichment_table.csv", "qc/qc_results.csv", "draft/methods_results.md",
            "results/fgsea_prerank_results.json", rend$figures)
  inputs <- list(ranked_list = rank_path)
  if (!is.null(args[["gene-sets"]])) inputs$gene_sets <- args[["gene-sets"]]
  os_write_provenance(outdir, FG_MODULE, FG_VERSION, canon, basename(.this), args$seed,
                      inputs = inputs, outputs = outs, upstream = upstream,
                      extra = list(collection = args$collection, collection_sha256 = collection$sha256,
                                   ranking_metric = metric, ranking_direction = args$direction))
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
