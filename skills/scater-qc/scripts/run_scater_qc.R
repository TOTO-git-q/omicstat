# Entry: locate shared, parse/validate, input, compute, render, QC, report/provenance, closing.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "engine_run.R", "module_kit.R", "handoff.R", "convert.R", "fig_all.R", "sc_bioc_io.R", "fig_mod_sc_bioc.R")) source(file.path(.shared, f))
for (f in c("scater_qc_core.R", "scater_qc_report.R", "scater_qc_qc.R")) source(file.path(dirname(.this), f))
SPEC <- os_arg_spec(usage = "Rscript run_scater_qc.R --input <sce.rds>|--from-run <dir> --mt-genes <file> --qc-mode mad|fixed --species <name> --id-type <name> --outdir <dir>",
 description = "SCE quality-control metrics and explicit adaptive or fixed filtering.", flags = list(
 os_flag("input", "path", must_exist = TRUE, help = "SCE RDS with raw counts"),
 os_flag("from-run", "path", must_exist = TRUE, help = "upstream SCE handoff"),
 os_flag("outdir", "path", required = TRUE, help = "output directory"),
 os_flag("spec", "path", must_exist = TRUE, help = "replay resolved spec"),
 os_flag("mt-genes", "path", required = TRUE, must_exist = TRUE, help = "one mitochondrial feature ID per line"),
 os_flag("species", "string", required = TRUE, help = "declared species"),
 os_flag("id-type", "string", required = TRUE, help = "declared feature ID namespace"),
 os_flag("qc-mode", "enum", required = TRUE, values = c("mad", "fixed"), help = "explicit filtering policy"),
 os_flag("nmads", "num", range = c(0, 100), help = "required for mad mode; vignette example 3"),
 os_flag("min-counts", "num", range = c(0, 1e12), help = "fixed-mode minimum total counts"),
 os_flag("min-features", "int", range = c(0, 1e7), help = "fixed-mode minimum detected genes"),
 os_flag("max-mito", "num", range = c(0, 100), help = "fixed-mode maximum mitochondrial percent"),
 os_flag("batch-col", "string", help = "metadata column for per-batch MAD estimates"),
 os_flag("metrics-args", "path", must_exist = TRUE, help = "JSON named supplementary perCellQCMetrics arguments"),
 os_flag("filter-args", "path", must_exist = TRUE, help = "JSON named supplementary perCellQCFilters arguments; explicit thresholds take precedence"),
 os_flag("seed", "int", default = 20260925L, help = "recorded random seed"),
 os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")), exclusive = list(c("input", "from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
need <- if (a[["qc-mode"]] == "mad") "nmads" else c("min-counts", "min-features", "max-mito")
if (any(vapply(need, function(k) is.null(a[[k]]), logical(1)))) stop("OS_MISSING_PARAMETER: explicitly provide the selected mode's thresholds.", call. = FALSE)
unused <- if (a[["qc-mode"]] == "mad") c("min-counts", "min-features", "max-mito") else "nmads"
if (any(vapply(unused, function(k) !is.null(a[[k]]), logical(1)))) stop("OS_CONFLICTING_PARAMETERS: thresholds belong to the other QC mode.", call. = FALSE)
set.seed(a$seed); options(omicstat.journal = a$journal)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE); elog <- os_engine_log_new(a$outdir)
i <- os_engine_capture(os_bioc_input(a, XQ_MODULE), "input", elog)
r <- os_engine_capture(scater_qc_compute(i$sce, a), "compute", elog)
r$colours <- os_colours_for(sort(unique(r$metrics$status)), family = "status", registry = i$colours)$registry
rend <- os_engine_capture(scater_qc_render(r, a), "render", elog)
qc <- os_engine_capture(scater_qc_qc(r, elog), "qc", elog); os_write_qc_results(qc, a$outdir)
if (qc$blocking) { os_write_text("Draft withheld: too few retained cells; read qc/qc_results.csv.", file.path(a$outdir, "draft", "methods_results.md")); stop("OS_QC_BLOCKER: too few retained cells.", call. = FALSE) }
os_engine_capture({
 scater_qc_report(r, a, qc, .module_dir)
 os_bioc_write(r, i, a, XQ_MODULE, XQ_MODULE_VERSION)
 os_write_provenance(a$outdir, XQ_MODULE, XQ_MODULE_VERSION, os_canonical_argv(SPEC, a), basename(.this), a$seed,
   inputs = list(sce = i$path, mitochondrial_ids = a[["mt-genes"]]), outputs = rend,
   upstream = i$upstream, extra = list(state = r$state))
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
