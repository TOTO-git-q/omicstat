# Ten-stage entry: shared, args, validation, input, compute, result, render, QC, provenance, closing.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- file.path(dirname(.module_dir), "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "handoff.R", "convert.R", "sc_backend_io.R", "fig_all.R", "fig_mod_sc_backend.R")) source(file.path(.shared, f))
for (f in c("core", "report", "qc")) source(file.path(dirname(.this), paste0("singler_annotate_", f, ".R")))
SPEC <- os_arg_spec(usage = "Rscript run_singler_annotate.R --input FILE --cluster-col COLUMN --reference FILE --outdir DIR [options]",
 description = "SingleR reference annotation with explicit reference identity and score diagnostics.",
 flags = c(os_backend_flags(), os_backend_function_flags(SingleR::SingleR, "singler", c("test", "ref", "labels", "clusters")), os_backend_function_flags(SingleR::pruneScores, "prune", "results"), list(
  os_flag("reference", "path", required = TRUE, must_exist = TRUE, help = "labelled SCE reference RDS, normalized logcounts"),
  os_flag("reference-name", "string", required = TRUE, help = "reference identity"),
  os_flag("reference-version", "string", required = TRUE, help = "reference data version/date"),
  os_flag("species", "string", required = TRUE, help = "species shared by test and reference; user declaration"),
  os_flag("reference-label-col", "string", required = TRUE, help = "reference cell metadata label column"),
  os_flag("unit", "enum", default = "cell", values = c("cell", "cluster"), help = "annotation unit; locked clusters=NULL default is per cell"),
  os_flag("test-role", "enum", default = "logcounts", values = c("logcounts", "counts"), help = "test assay role; ranking may also use counts"),
  os_flag("de-method", "enum", default = "classic", values = c("classic", "wilcox", "t"), help = "reference marker method; choose wilcox for single-cell references per vignette"),
  os_flag("de-n", "int", range = c(1, 100000), help = "markers per label comparison; absent preserves package NULL"),
  os_flag("aggr-ref", "enum", default = "false", values = c("false", "true"), help = "aggregate reference; locked FALSE default"),
  os_flag("fine-tune", "enum", default = "true", values = c("true", "false"), help = "fine-tune assignments"),
  os_flag("quantile", "num", default = 0.8, range = c(0, 1), help = "SingleR score quantile"),
  os_flag("tune-thresh", "num", default = 0.05, range = c(0, 1), help = "fine tuning threshold"),
  os_flag("nmads", "num", default = 3, range = c(0, 100), help = "pruneScores outlier MAD threshold"))),
 exclusive = list(c("input", "from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
argv <- os_canonical_argv(SPEC, a); seed <- a$seed; set.seed(seed)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_backend_input(a, need = a[["test-role"]]), "input", elog)
ref <- readRDS(a$reference)
if (!methods::is(ref, "SingleCellExperiment")) stop("OS_INVALID_INPUT: reference must be SingleCellExperiment.", call. = FALSE)
r <- os_engine_capture(singler_annotate_compute(inp$sce, ref, a), "compute", elog)
figs <- os_engine_capture(singler_annotate_render(r, a), "render", elog)
qc <- os_engine_capture(singler_annotate_qc(r, inp, a, elog), "qc", elog)
os_write_qc_results(qc, a$outdir)
os_engine_capture(singler_annotate_report(r, a, qc, figs, .module_dir), "report", elog)
obj <- file.path(a$outdir, "objects", "sce.rds"); dir.create(dirname(obj), recursive = TRUE, showWarnings = FALSE)
S4Vectors::metadata(r$sce)$omicstat <- utils::modifyList(inp$state, list(annotated = TRUE))
saveRDS(r$sce, obj, version = 3)
saveRDS(r$prediction, file.path(a$outdir, "objects", "singler.rds"), version = 3)
write_handoff(a$outdir, run_id = basename(a$outdir), module = SA_MODULE, module_version = SA_MODULE_VERSION,
 objects = list(sce = list(path = obj, type = "SingleCellExperiment")), ecosystem = "neutral", state = c(inp$state, list(annotated = TRUE)),
 contract_hash = inp$upstream$contract_hash %||% NA_character_, upstream_runs = inp$upstream$upstream_runs %||% character(0))
paths <- c("tables/annotations.csv", "tables/scores.csv", "tables/cluster_labels.csv", "qc/qc_results.csv", "draft/methods_results.md", "results/singler_annotate_results.json")
os_write_provenance(a$outdir, SA_MODULE, SA_MODULE_VERSION, argv, basename(.this), seed,
 inputs = list(input = inp$path, reference = a$reference), outputs = paths, upstream = inp$upstream,
 extra = list(front_end_ecosystem = inp$ecosystem, backend_ecosystem = "neutral", conversion = inp$conversion, python_to_r_crossing = inp$crossing, resolved_native=r$resolved))
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
