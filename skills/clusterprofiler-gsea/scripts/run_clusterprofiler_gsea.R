# clusterProfiler GO GSEA with a named directional ranking.
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- normalizePath(file.path(.module_dir,"..","_shared"))
.suite <- normalizePath(file.path(.module_dir,"..",".."))
for (f in c("args.R","engine_run.R","module_kit.R","fig_all.R","handoff.R","ranked_list.R","enrich_io.R")) source(file.path(.shared,"scripts",f))
for (f in c("clusterprofiler_gsea_core.R","clusterprofiler_gsea_qc.R","clusterprofiler_gsea_report.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(
  usage = "Rscript run_clusterprofiler_gsea.R --ranked <feature_id,score.csv> --ranking-metric <name> --direction <contrast> --outdir <dir> [options]",
  description = "GO preranked GSEA on all finite genes of one directional contrast.",
  flags = list(
    os_flag("ranked","path",must_exist=TRUE,help="CSV of feature_id and signed score, without significance filtering"),
    os_flag("ranking-metric","string",help="explicit signed statistic or effect type, e.g. Wald stat or moderated t"),
    os_flag("direction","string",help="positive-score contrast direction"),
    os_flag("statistic-kind","enum",default="test_statistic",values=c("test_statistic","effect_size"),help="whether a --ranked score is a signed test statistic or an effect size"),
    os_flag("lfc-type","string",help="named LFC type of an effect-size ranking (required with --statistic-kind effect_size)"),
    os_flag("from-run","path",must_exist=TRUE,help="upstream directional DE run"),
    os_flag("outdir","path",required=TRUE,help="output directory"),
    os_flag("spec","path",must_exist=TRUE,help="resolved spec replay"),
    os_flag("database","enum",default="GO",values=c("GO","MSigDB","KEGG","Reactome"),help="offline collection; only registered GO is available"),
    os_flag("ontology","enum",default="BP",values=c("BP","CC","MF","ALL"),help="GO ontology"),
    os_flag("key-type","string",default="ENTREZID",help="OrgDb key type matching ranked IDs"),
    os_flag("min-size","int",default=10L,range=c(1,100000),help="minimum gene set size after rank intersection"),
    os_flag("max-size","int",default=500L,range=c(1,1000000),help="maximum gene set size after rank intersection"),
    os_flag("exploratory-fdr","bool",help="also flag BH adjusted P below 0.25 as exploratory"),
    os_flag("top-n","int",default=15L,range=c(1,100),help="maximum sets in dot plot"),
    os_flag("seed","int",default=20260925L,help="R RNG seed before enrichit multilevel run"),
    os_flag("journal","enum",default="nature",values=c("nature","cell","science","generic"),help="figure preset")),
  exclusive=list(c("ranked","from-run")))
argv <- os_spec_argv(commandArgs(trailingOnly=TRUE)); a <- os_parse_args(SPEC,argv)
if (isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
if (is.null(a[["from-run"]]) && (is.null(a$ranked) || is.null(a[["ranking-metric"]]) || is.null(a$direction)))
  stop("OS_MISSING_PARAMETER: direct ranking needs --ranked, --ranking-metric and --direction.",call.=FALSE)
if (!is.null(a[["from-run"]]) && (!is.null(a[["ranking-metric"]]) || !is.null(a$direction) || !is.null(a[["lfc-type"]]) || "statistic-kind" %in% (attr(a,"given") %||% character(0))))
  stop("OS_CONFLICTING_PARAMETERS: upstream ranking metric and direction are inherited.",call.=FALSE)
if (a[["min-size"]] > a[["max-size"]]) stop("OS_INVALID_PARAMETER: min-size exceeds max-size.",call.=FALSE)
if (!is.null(a[["ranking-metric"]]) && grepl("(^|[^A-Za-z])(LRT|F.stat|F-test)([^A-Za-z]|$)",a[["ranking-metric"]],ignore.case=TRUE))
  stop("OS_RANKING_UNDIRECTIONAL: give a signed contrast statistic.",call.=FALSE)
canon <- os_canonical_argv(SPEC,a)
a$alpha <- 0.05
set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE); a$outdir <- normalizePath(a$outdir,winslash="/")
elog <- os_engine_log_new(a$outdir)
ref <- os_enrich_registry_go(.suite)
upstream <- if (!is.null(a[["from-run"]])) read_handoff(a[["from-run"]],expect=list(ranked_list="ranked_list")) else NULL
x <- os_engine_capture(cg_input(a,upstream),"input",elog)
if (!a[["key-type"]] %in% AnnotationDbi::keytypes(org.Hs.eg.db::org.Hs.eg.db)) stop("OS_INVALID_PARAMETER: unsupported OrgDb key type.",call.=FALSE)
r <- os_engine_capture(cg_compute(x,a),"compute",elog)
render <- os_engine_capture(cg_render(r,x,a,ref),"render",elog)
qc <- os_engine_capture(cg_qc(r,a,elog),"qc",elog); os_write_qc_results(qc,a$outdir)
os_engine_capture({
  cg_draft(r,x,a,render,.module_dir)
  obj <- file.path(a$outdir,"objects"); dir.create(obj,recursive=TRUE,showWarnings=FALSE)
  os_enrich_write_csv(data.frame(feature_id=names(x$scores),symbol="",score=unname(x$scores)),file.path(obj,"ranked_list.csv"))
  write_handoff(a$outdir,basename(a$outdir),CG_MODULE,CG_MODULE_VERSION,
                objects=list(enrichment_table=list(path=render$table,type="enrichment_table"),
                             ranked_list=list(path=file.path(obj,"ranked_list.csv"),type="ranked_list")),
                state=list(ranking_metric=x$metric,direction=x$direction,statistic_kind=x$statistic_kind,lfc_type=x$lfc_type,
                           contrast=x$contrast,ranking_source=x$source,ontology=a$ontology,refdata_id=ref$id,
                           ranked_list=if (!is.null(upstream)) upstream$state$ranked_list else NULL),
                upstream_runs=upstream$upstream_runs %||% character(0))
  os_write_provenance(a$outdir,CG_MODULE,CG_MODULE_VERSION,canon,basename(.this),a$seed,
                      inputs=x$inputs,outputs=c("tables/enrichment_full.csv","qc/qc_results.csv","draft/methods_results.md",
                                                paste0("figures/",c(if (!is.null(render$figures$dotplot)) "gsea_dotplot",
                                                                    if (!is.null(render$figures$dotplot_signed)) "gsea_dotplot_signed",
                                                                    if (!is.null(render$figures$ridge)) "gsea_ridge",
                                                                    if (!is.null(render$figures$curve)) "gsea_curve"),".figure_spec.json")),
                      upstream=upstream,extra=list(refdata=ref,ranking_metric=x$metric,direction=x$direction,statistic_kind=x$statistic_kind,lfc_type=x$lfc_type,
                                                    rng_kind=RNGkind(),threads=1L,downstream_engine="enrichit 0.2.1"))
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
