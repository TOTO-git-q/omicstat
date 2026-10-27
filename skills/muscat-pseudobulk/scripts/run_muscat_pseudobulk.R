options(error = function() { cat(geterrmessage(), file=stderr()); quit(status=1,save="no") })
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value=TRUE)[1]))
.module_dir <- dirname(dirname(.this)); .shared <- file.path(dirname(.module_dir), "_shared", "scripts")
.libPaths(c(file.path(dirname(dirname(.module_dir)), ".omicstat-acceptance"), .libPaths()))
for(f in c("args.R","engine_run.R","module_kit.R","handoff.R","convert.R","sc_backend_io.R","fig_all.R","fig_mod_sc_backend.R")) source(file.path(.shared,f))
source(file.path(dirname(.this),"muscat_pseudobulk_core.R"))
source(file.path(dirname(.this),"muscat_pseudobulk_audit.R"))
SPEC <- os_arg_spec(usage="Rscript run_muscat_pseudobulk.R --input FILE|--from-run DIR [options]", description="Official muscat-pseudobulk workflow", flags=c(os_backend_flags(),
os_backend_function_flags(muscat::prepSCE,"prep",c("x","kid","sid","gid")),
os_backend_function_flags(muscat::aggregateData,"aggregate",c("x","assay","by")),
os_backend_function_flags(muscat::pbDS,"ds",c("pb")),
list(os_flag("display-fdr","num",default=0.05,help="Display-only adjusted P cutoff"),os_flag("display-lfc","num",default=1,help="Display-only absolute logFC cutoff"),os_flag("sample-col","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("condition-col","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("donor-col","string",help="Optional explicit donor metadata; repeated sample labels cannot inflate biological n; see options.md"),
os_flag("reference","string",required=TRUE,help="Scientific input; see options.md"),
os_flag("target","string",required=TRUE,help="Scientific input; see options.md"))), exclusive=list(c("input","from-run")))
a <- os_parse_args(SPEC, os_spec_argv(commandArgs(trailingOnly=TRUE)))
if(isTRUE(a$help)) { os_print_help(SPEC); quit(status=0) }
attr(a,"canonical") <- os_canonical_argv(SPEC,a)
set.seed(a$seed); options(omicstat.journal=a$journal)
dir.create(a$outdir,recursive=TRUE,showWarnings=FALSE)
elog <- os_engine_log_new(a$outdir)
inp <- os_engine_capture(os_backend_input(a,need="counts"), "input", elog)
r <- os_engine_capture(muscat_pseudobulk_compute(inp$sce,a), "compute", elog)
os_backend_finish(r,inp,a,"muscat-pseudobulk",.this)
pd <- os_backend_proportions(r$sce,"cluster_id","sample_id","group_id")
p <- os_proportion_bar(pd,journal=a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","proportions"),width="double",journal=a$journal)
p <- os_pseudobulk_eligibility(r$eligibility, c(a$reference, a$target), r$options$pbDS$min_cells,
  donor_col=if(is.null(a[["donor-col"]])) NULL else "donor", journal=a$journal)
os_finalize_figure(p,file.path(a$outdir,"figures","pseudobulk_eligibility"),width="double",journal=a$journal)
for(nm in r$differential_table_names) {
  p <- os_muscat_volcano(r$tables[[nm]],a[["display-fdr"]],a[["display-lfc"]],nm,a$journal)
  os_finalize_figure(p,file.path(a$outdir,"figures",paste0("volcano_",gsub("[^A-Za-z0-9]","_",nm))),width="double",journal=a$journal)
}
cat("Completed muscat-pseudobulk; review qc and native objects.\n")
