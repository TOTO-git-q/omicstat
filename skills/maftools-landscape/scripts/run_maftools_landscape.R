# Official maftools landscape workflow, wrapped.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .suite <- dirname(dirname(.module_dir)); .shared <- file.path(.suite, "skills", "_shared", "scripts")
for (f in c("args.R", "module_kit.R", "handoff.R", "engine_run.R", "fig_all.R", "m4_io.R", "fig_mod_m4.R")) source(file.path(.shared, f))
source(file.path(dirname(.this), "maftools_landscape_core.R"))
SPEC <- os_arg_spec(usage = "Rscript run_maftools_landscape.R --input <maf>|--from-run <dir> --call-source <audit> --capture-size <Mb> --outdir <dir>", flags = list(
 os_flag("input", "path", must_exist = TRUE, help = "somatic MAF file"),
 os_flag("from-run", "path", must_exist = TRUE, help = "verified MAF upstream"),
 os_flag("upstream-object", "string", default = "maf", help = "upstream object name"),
 os_flag("clinical", "path", must_exist = TRUE, help = "clinical TSV with Tumor_Sample_Barcode"),
 os_flag("outdir", "path", required = TRUE, help = "output directory"),
 os_flag("spec", "path", must_exist = TRUE, help = "resolved spec replay"),
 os_flag("call-source", "string", required = TRUE, help = "caller accession genome build and filters"),
 os_flag("use-all", "enum", default = "true", values = c("true", "false"), help = "TRUE includes all Mutation_Status values"),
 os_flag("is-tcga", "enum", default = "false", values = c("true", "false"), help = "truncate TCGA barcode to twelve characters"),
 os_flag("remove-duplicates", "enum", default = "true", values = c("true", "false"), help = "remove repeated variants"),
 os_flag("rm-flags", "enum", default = "false", values = c("true", "false"), help = "remove FLAG genes"),
 os_flag("non-synonymous", "string", help = "comma separated vc_nonSyn override; absent locked classes"),
 os_flag("cn-table", "path", must_exist = TRUE, help = "native CNV table"),
 os_flag("cn-level", "enum", default = "all", values = c("all", "deep", "shallow"), help = "GISTIC CN level"),
 os_flag("gistic-lesions", "path", must_exist = TRUE, help = "GISTIC all lesions"),
 os_flag("gistic-amp", "path", must_exist = TRUE, help = "GISTIC amplified genes"),
 os_flag("gistic-del", "path", must_exist = TRUE, help = "GISTIC deleted genes"),
 os_flag("gistic-scores", "path", must_exist = TRUE, help = "GISTIC scores"),
 os_flag("top", "int", default = 10, range = c(1, 1000000000), help = "oncoplot top genes; vignette example 10"),
 os_flag("capture-size", "num", required = FALSE, range = c(0.001, 1000000), help = "assay callable territory in Mb; vignette example 50"),
 os_flag("capture-regions","path",must_exist=TRUE,help="native tmb captureRegions TSV; first three columns chrom/start/end, mutually exclusive with capture-size"),
 os_flag("capture-regions-source","string",help="required region source/build/version declaration when using capture-regions"),
 os_flag("ignore-cnv", "enum", default = "true", values = c("true", "false"), help = "exclude CNV from TMB"),
 os_flag("interaction-top", "int", default = 25, range = c(1, 1000000000), help = "native interaction gene universe top N"),
 os_flag("interaction-genes", "string", help = "comma separated interaction genes; overrides top"),
 os_flag("seed", "int", default = 20260925, range = c(1, 1000000000), help = "explicit seed"),
 os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "suite figure preset")), exclusive = list(c("input", "from-run"),c("capture-size","capture-regions")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly = TRUE)))
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if(is.null(a[["capture-size"]]) && is.null(a[["capture-regions"]])) stop("OS_MISSING_PARAMETER: supply --capture-size or --capture-regions.",call.=FALSE)
if(!is.null(a[["capture-regions"]]) && (is.null(a[["capture-regions-source"]]) || !nzchar(trimws(a[["capture-regions-source"]])))) stop("OS_MISSING_PARAMETER: declare --capture-regions-source.",call.=FALSE)
set.seed(a$seed); options(omicstat.journal = a$journal)
u <- if (is.null(a[["from-run"]])) NULL else read_handoff(a[["from-run"]])
p <- a$input
if (!is.null(u)) {
 obj <- u$objects[[a[["upstream-object"]]]]
 if (is.null(obj) || !obj$type %in% c("MAF", "maf_file")) stop("OS_HANDOFF_MISMATCH: expected native MAF RDS or maf_file.", call. = FALSE)
 p <- obj$path
}
if (is.null(p)) stop("OS_MISSING_PARAMETER: --input or --from-run required.", call. = FALSE)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
elog <- os_engine_log_new(a$outdir)
res <- os_engine_capture(maftools_landscape_compute(a, p), "official workflow", elog)
os_m4_write_tables(res$tables, a$outdir)
dir.create(file.path(a$outdir, "objects"), showWarnings = FALSE)
saveRDS(res$maf, file.path(a$outdir, "objects", "maf.rds"))
plot <- os_m4_maf_plot(res$maf, a)
fig <- os_finalize_figure(plot, file.path(a$outdir, "figures", "oncoplot"), width = "double", journal = a$journal, root = a$outdir)
fig2 <- os_finalize_figure(os_m4_variant_summary(res$maf, a), file.path(a$outdir, "figures", "variant_summary"), width = "double", journal = a$journal, root = a$outdir)
fig_args <- a; fig_args[["capture-size"]] <- res$capture$size_mb
tmb_plot <- os_m4_tmb(res$tables$tmb,fig_args)
if(!is.null(res$capture$regions)) { meta <- attr(tmb_plot,"os_meta");meta$caption <- paste(meta$caption,"Native captureRegions subset; source",res$capture$source,"SHA-256",res$capture$sha256);attr(tmb_plot,"os_meta") <- meta }
fig3 <- os_finalize_figure(tmb_plot, file.path(a$outdir, "figures", "tmb"), width = "double", journal = a$journal, root = a$outdir)
fig4 <- os_finalize_figure(os_m4_interactions(res$tables$interactions, a, nrow(res$tables$sample_summary)), file.path(a$outdir, "figures", "interactions"), width = "double", height_mm = 170, journal = a$journal, root = a$outdir)
values <- list(version = as.character(utils::packageVersion("maftools")), n = nrow(res$tables$sample_summary), genes = nrow(res$tables$gene_summary), variants = nrow(res$maf@data), silent = nrow(res$maf@maf.silent), source = a[["call-source"]], capture = res$capture$size_mb,capture_regions=jsonlite::toJSON(res$capture,auto_unbox=TRUE,null="null",digits=NA), top = a$top, options = jsonlite::toJSON(a, auto_unbox = TRUE))
os_m4_draft(.module_dir, values, list(oncoplot = fig, variant_summary = fig2, tmb = fig3, interactions = fig4), a$outdir)
jsonlite::write_json(values, file.path(a$outdir, "results.json"), auto_unbox = TRUE, pretty = TRUE)
write_handoff(a$outdir, os_run_id(a$outdir), "maftools-landscape", MF_MODULE_VERSION, objects = list(maf = list(path = file.path(a$outdir, "objects", "maf.rds"), type = "MAF")), state = list(ecosystem = "neutral", call_source = a[["call-source"]]), upstream_runs = u$upstream_runs %||% character(0))
os_write_provenance(a$outdir, "maftools-landscape", MF_MODULE_VERSION, os_canonical_argv(SPEC, a), .this, a$seed, inputs = Filter(Negate(is.null), list(maf = p, clinical = a$clinical, capture_regions=a[["capture-regions"]])), outputs = c("tables/gene_summary.csv", "tables/tmb.csv"), upstream = u, packages = "maftools",extra=list(capture=res$capture))
cat("maftools landscape completed\n")
