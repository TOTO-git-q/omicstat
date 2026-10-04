# Compare GO profiles only when selection-eligible universes are identical.
options(error=function(){cat(geterrmessage(),file=stderr());quit(status=1,save="no")})
.this <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- normalizePath(file.path(.module_dir,"..","_shared"))
.suite <- normalizePath(file.path(.module_dir,"..",".."))
for (f in c("args.R","engine_run.R","module_kit.R","fig_all.R","handoff.R","enrich_io.R")) source(file.path(.shared,"scripts",f))
for (f in c("clusterprofiler_compare_core.R","clusterprofiler_compare_qc.R","clusterprofiler_compare_report.R")) source(file.path(dirname(.this),f))
SPEC <- os_arg_spec(
  usage="Rscript run_clusterprofiler_compare.R --manifest <lists.csv> --outdir <dir> [options]",
  description="GO profiles for several defined lists, with a shared universe only when their selection population is identical.",
  flags=list(
    os_flag("manifest","path",required=TRUE,must_exist=TRUE,help="CSV defining each named gene list, background and study metadata"),
    os_flag("outdir","path",required=TRUE,help="output directory"),
    os_flag("spec","path",must_exist=TRUE,help="resolved spec replay"),
    os_flag("database","enum",default="GO",values=c("GO","KEGG","MSigDB","Reactome"),help="offline collection; only registered GO is available"),
    os_flag("ontology","enum",default="BP",values=c("BP","CC","MF","ALL"),help="GO ontology"),
    os_flag("pool","enum",values=c("TRUE","FALSE"),help="explicit pooling choice required for ALL"),
    os_flag("key-type","string",default="ENTREZID",help="OrgDb key type for every list and universe"),
    os_flag("min-size","int",default=10L,range=c(1,100000),help="minimum GO set size"),
    os_flag("max-size","int",default=500L,range=c(1,1000000),help="maximum GO set size"),
    os_flag("top-n-per-group","int",default=5L,range=c(1,50),help="maximum significant sets chosen per group for the comparison figure"),
    os_flag("seed","int",default=20260925L,help="recorded seed"),
    os_flag("journal","enum",default="nature",values=c("nature","cell","science","generic"),help="figure preset")))
argv <- os_spec_argv(commandArgs(trailingOnly=TRUE)); a <- os_parse_args(SPEC,argv)
if (isTRUE(a$help)){os_print_help(SPEC);quit(status=0)}
if (a$ontology=="ALL"&&is.null(a$pool)) stop("OS_MISSING_PARAMETER: ontology ALL requires --pool.",call.=FALSE)
if (a$ontology!="ALL"&&!is.null(a$pool)) stop("OS_CONFLICTING_PARAMETERS: --pool is only for ALL.",call.=FALSE)
if (a[["min-size"]]>a[["max-size"]]) stop("OS_INVALID_PARAMETER: min-size exceeds max-size.",call.=FALSE)
canon <- os_canonical_argv(SPEC,a)
if (!is.null(a$pool)) a$pool <- identical(a$pool,"TRUE")
set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE); a$outdir <- normalizePath(a$outdir,winslash="/")
elog <- os_engine_log_new(a$outdir)
ref <- os_enrich_registry_go(.suite)
if (!a[["key-type"]] %in% AnnotationDbi::keytypes(org.Hs.eg.db::org.Hs.eg.db)) stop("OS_INVALID_PARAMETER: unsupported OrgDb key type.",call.=FALSE)
x <- os_engine_capture(cx_manifest(a$manifest),"input",elog)
r <- os_engine_capture(cx_compute(x,a),"compute",elog)
render <- os_engine_capture(cx_render(r,x,a,ref),"render",elog)
qc <- os_engine_capture(cx_qc(r,x,elog),"qc",elog); os_write_qc_results(qc,a$outdir)
os_engine_capture({
  cx_draft(r,x,a,.module_dir,render)
  write_handoff(a$outdir,basename(a$outdir),CX_MODULE,CX_MODULE_VERSION,
    objects=list(enrichment_table=list(path=render$table,type="enrichment_table")),
    state=list(mode=r$mode,ontology=a$ontology,refdata_id=ref$id))
  os_write_provenance(a$outdir,CX_MODULE,CX_MODULE_VERSION,canon,basename(.this),a$seed,
    inputs=x$inputs,outputs=c("tables/enrichment_full.csv","tables/list_definitions.csv","tables/test_families.csv","qc/qc_results.csv","draft/methods_results.md"),
    extra=list(refdata=ref,mode=r$mode,software=cx_software()))
},"provenance",elog)
cat(sprintf("%d of %d rules triggered; read %s first\n",qc$n_triggered,qc$n_rules,qc$read_first))
