a<-commandArgs(FALSE);here<-dirname(normalizePath(sub("^--file=","",a[grepl("^--file=",a)][1])))
S<-normalizePath(file.path(here,"../scripts"))
for(f in c("args.R","engine_run.R","module_kit.R","feature_table.R","handoff.R","fig_all.R","render_figure_request.R"))source(file.path(S,f))
out<-Sys.getenv("OMICSTAT_SEMANTICS_REPLAY_OUT",file.path(tempdir(),"semantic-replay"));dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(j in c("nature","cell")) {
 run<-file.path(out,j,"request")
 stopifnot(system2("python",c(shQuote(file.path(here,"figure-evidence-P0-12/make_shared_request.py")),shQuote(run),j))==0)
 rec<-os_render_figure_request(run)
 req<-jsonlite::fromJSON(file.path(run,"figure_data/figure_request.json"),simplifyVector=FALSE)
 for(f in req$figures) {
   d<-os_rr_read_data(run,f$data$df,"synthetic data")
   p<-os_diag_xy(d,"visit",f$id,kind="points",xlab="Visit",ylab=if(f$id=="seconds")"Runtime (seconds)"else"Supplied probability",journal=j,definition=f$definition)
   native<-os_finalize_figure(p,file.path(out,j,"native",f$id),width="double",height_mm=90,journal=j,root=file.path(out,j,"native"))
   saved<-jsonlite::fromJSON(file.path(run,"figures",paste0(f$id,".figure_spec.json")),simplifyVector=FALSE)
   ns<-jsonlite::fromJSON(native$spec,simplifyVector=FALSE)
   stopifnot(identical(.os_sort_keys(saved$definition),.os_sort_keys(ns$definition)),identical(saved$counts$semantic,ns$counts$semantic),
       identical(saved$definition$layers[[1]]$source_sha256,f$definition$layers[[1]]$source_sha256))
   stopifnot(identical(digest::digest(file=file.path(run,"figures",paste0(f$id,".png")),algo="sha256"),digest::digest(file=native$files$png,algo="sha256")))
   cat("PASS",j,f$id,"Python request and native R exact semantic/spec counts, source SHA and PNG\n")
 }
 rec2<-os_render_figure_request(run)
 stopifnot(identical(vapply(rec$figures,function(f)f$spec$sha256,""),vapply(rec2$figures,function(f)f$spec$sha256,"")))
 cat("PASS",j,"byte-identical typed request replay\n")
 # Corrupt only semantic raw values, leaving the actual data checksums intact.
 req$figures[[1]]$definition$layers[[1]]$raw_source$seconds[[1]]<-999
 os_write_json(req,file.path(run,"figure_data/figure_request.json"),digits=I(17))
 err<-tryCatch({os_render_figure_request(run);""},error=conditionMessage)
 stopifnot(grepl("OS_INVALID_INPUT",err,fixed=TRUE));cat("PASS",j,"corrupt semantic source rejected\n")
}
cat("ALL SEMANTIC REPLAY CHECKS PASSED (4 figures,2 presets,2 byte replays,2 refusals)\n")
