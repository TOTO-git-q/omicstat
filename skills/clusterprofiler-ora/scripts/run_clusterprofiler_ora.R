# clusterProfiler ORA entry point. All analysis arguments are declared in SPEC.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this))
.shared <- normalizePath(file.path(.module_dir, "..", "_shared"))
.suite <- normalizePath(file.path(.module_dir, "..", ".."))
for (f in c("args.R", "engine_run.R", "module_kit.R", "fig_all.R", "handoff.R", "enrich_io.R", "user_genesets.R"))
  source(file.path(.shared, "scripts", f))
for (f in c("clusterprofiler_ora_core.R", "clusterprofiler_ora_report.R", "clusterprofiler_ora_qc.R"))
  source(file.path(dirname(.this), f))

SPEC <- os_arg_spec(
  usage = "Rscript run_clusterprofiler_ora.R --input <genes.csv> --universe <eligible.csv> --selection-rule <text> --outdir <dir> [options]",
  description = "GO (registered) or user-supplied gene-set over-representation analysis against an explicit eligible-gene background.",
  flags = c(list(
    os_flag("input", "path", must_exist = TRUE, help = "CSV of selected gene IDs"),
    os_flag("universe", "path", must_exist = TRUE, help = "CSV of all IDs eligible for selection"),
    os_flag("selection-rule", "string", help = "rule defining selected genes and eligibility"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream feature_table; finite padj rows define eligibility"),
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("spec", "path", must_exist = TRUE, help = "replay a resolved spec"),
    os_flag("id-column", "string", default = "feature_id", help = "ID column in input and universe CSV"),
    os_flag("key-type", "string", default = "ENTREZID", help = "org.Hs.eg.db key type matching both inputs"),
    os_flag("database", "enum", default = "GO", values = c("GO", "KEGG", "MSigDB", "Reactome", "custom"), help = "GO (registered) or custom (user-supplied --gene-sets); KEGG, MSigDB and Reactome are not bundled"),
    os_flag("ontology", "enum", default = "BP", values = c("BP", "CC", "MF", "ALL"), help = "GO ontology"),
    os_flag("pool", "enum", values = c("TRUE", "FALSE"), help = "required explicitly with ontology ALL"),
    os_flag("alpha", "num", default = 0.05, range = c(0, 1), help = "BH adjusted P threshold for the separate flag and figure"),
    os_flag("min-size", "int", default = 10L, range = c(1, 100000), help = "minimum GO set size"),
    os_flag("max-size", "int", default = 500L, range = c(1, 1000000), help = "maximum GO set size"),
    os_flag("simplify", "bool", help = "also write the Wang-simplified display table and the merged-term relation"),
    os_flag("top-n", "int", default = 15L, range = c(1, 100), help = "maximum terms in the dot plot"),
    os_flag("seed", "int", default = 20260925L, help = "recorded seed"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset")),
    os_user_geneset_flags(gmt = TRUE, feature_id_type = FALSE, gmt_help = "user-supplied local GMT for --database custom")),
  exclusive = list(c("input", "from-run")))
argv <- os_spec_argv(commandArgs(trailingOnly = TRUE))
a <- os_parse_args(SPEC, argv)
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status = 0) }
if (is.null(a[["from-run"]]) && (is.null(a$input) || is.null(a$universe) || is.null(a[["selection-rule"]])))
  stop("OS_MISSING_PARAMETER: direct ORA needs --input, --universe and --selection-rule.", call. = FALSE)
if (!is.null(a[["from-run"]]) && (!is.null(a$universe) || !is.null(a[["selection-rule"]])))
  stop("OS_CONFLICTING_PARAMETERS: --from-run determines its own universe and selection rule.", call. = FALSE)
if (a[["min-size"]] > a[["max-size"]]) stop("OS_INVALID_PARAMETER: min-size exceeds max-size.", call. = FALSE)
custom <- identical(a$database, "custom")
os_user_geneset_guard(a, custom, "--database custom", gmt = TRUE)
if (custom && (!identical(a$ontology, "BP") || !is.null(a$pool) || isTRUE(a$simplify)))
  stop("OS_CONFLICTING_PARAMETERS: --ontology, --pool and --simplify are GO options; --database custom tests the user-supplied gene sets as given.", call. = FALSE)
canon <- os_canonical_argv(SPEC, a)
if (!is.null(a$pool)) a$pool <- identical(a$pool, "TRUE")
set.seed(a$seed)
options(omicstat.journal = a$journal)
dir.create(a$outdir, recursive = TRUE, showWarnings = FALSE)
a$outdir <- normalizePath(a$outdir, winslash = "/")
elog <- os_engine_log_new(a$outdir)

ref <- if (custom) NULL else os_enrich_registry_go(.suite)
upstream <- if (!is.null(a[["from-run"]])) read_handoff(a[["from-run"]], expect = list(feature_table = "feature_table")) else NULL
x <- os_engine_capture(co_input(a, upstream), "input", elog)
co_validate(x, a)
coll <- NULL
if (custom) {
  # User-supplied collection (CONVENTIONS "User-supplied gene-set collections"):
  # clusterProfiler here is bound to org.Hs.eg.db, so the analysis species is human.
  coll <- os_user_genesets_check(os_user_genesets_resolve(a), a[["key-type"]], x$universe,
                                 "the eligible universe", "--key-type", analysis_species = "Homo sapiens")
  ref <- list(id = "user_supplied", label = coll$label, user_gene_sets = coll$record)
}
r <- os_engine_capture(co_compute(x, a, coll), "compute", elog)
render <- os_engine_capture(co_render(r, x, a, ref), "render", elog)
qc <- os_engine_capture(co_qc(r, a, elog), "qc", elog)
os_write_qc_results(qc, a$outdir)
os_engine_capture({
  co_draft(r, x, a, qc, render, .module_dir)
  if (custom) os_user_genesets_draft(file.path(a$outdir, "draft", "methods_results.md"), coll$record)
  obj <- file.path(a$outdir, "objects")
  dir.create(obj, recursive = TRUE, showWarnings = FALSE)
  os_enrich_write_csv(data.frame(feature_id = x$genes), file.path(obj, "selected_genes.csv"))
  os_enrich_write_csv(data.frame(feature_id = x$universe), file.path(obj, "eligible_universe.csv"))
  write_handoff(a$outdir, basename(a$outdir), CO_MODULE, CO_VERSION,
                objects = list(enrichment_table = list(path = render$table, type = "enrichment_table"),
                               selected_genes = list(path = file.path(obj, "selected_genes.csv"), type = "gene_list"),
                               eligible_universe = list(path = file.path(obj, "eligible_universe.csv"), type = "eligible_universe")),
                state = if (custom) list(selection_rule = x$origin, database = coll$label, key_type = a[["key-type"]],
                                         refdata_id = ref$id, gene_sets_sha256 = coll$sha256) else
                  list(selection_rule = x$origin, ontology = a$ontology, key_type = a[["key-type"]],
                       refdata_id = ref$id, orgdb_version = ref$orgdb_version),
                upstream_runs = upstream$upstream_runs %||% character(0))
  os_write_provenance(a$outdir, CO_MODULE, CO_VERSION, canon, basename(.this), a$seed,
                      inputs = c(x$inputs, if (custom) os_user_genesets_inputs(a)), outputs = c("tables/enrichment_full.csv", "tables/test_families.csv",
                        "tables/gene_symbol_map.csv", "tables/enrichment_full_symbols.csv",
                        if (a$simplify) c("tables/enrichment_simplified_display.csv", "tables/simplify_relation.csv"),
                        "qc/qc_results.csv", "draft/methods_results.md"),
                      upstream = upstream, extra = c(list(refdata = ref, selection_rule = x$origin,
                                                          software = co_software(a$simplify, custom)),
                                                     if (custom) list(user_gene_sets = coll$record)))
  if (custom) os_user_genesets_write(a$outdir, coll$record)
}, "provenance", elog)
cat(sprintf("%d of %d rules triggered; read %s first\n", qc$n_triggered, qc$n_rules, qc$read_first))
