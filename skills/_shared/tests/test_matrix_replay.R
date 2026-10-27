a<-commandArgs(FALSE);here<-dirname(normalizePath(sub('^--file=','',a[grepl('^--file=',a)][1])))
S<-normalizePath(file.path(here,'../scripts'))
for(f in c('args.R','engine_run.R','module_kit.R','feature_table.R','handoff.R','fig_all.R','render_figure_request.R'))source(file.path(S,f))
out<-Sys.getenv('OMICSTAT_MATRIX_REPLAY_OUT',file.path(tempdir(),'matrix-replay'));dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(j in c('nature','cell')) {
 run<-file.path(out,j,'request');native_root<-file.path(out,j,'native')
 stopifnot(system2('python',c(shQuote(file.path(here,'figure-evidence-P0-12/make_matrix_request.py')),shQuote(run),j))==0)
 rec<-os_render_figure_request(run)
 req<-jsonlite::fromJSON(file.path(run,'figure_data/figure_request.json'),simplifyVector=FALSE)
 old<-options(omicstat.journal=j);reg<-os_colour_registry_new()
 for(f in req$figures) {
   data<-lapply(names(f$data),function(a)os_rr_read_data(run,f$data[[a]],a));names(data)<-names(f$data)
   args<-c(data,lapply(f$args,.os_rr_simplify));args$journal<-j
   fn<-get(f$builder);if('colour_registry'%in%names(formals(fn)))args$colour_registry<-reg
   p<-do.call(fn,args);m<-attr(p,'os_meta');if(!is.null(m$colour_registry))reg<-m$colour_registry
   native<-os_finalize_figure(p,file.path(native_root,f$out_stem),width=f$width,height_mm=f$height_mm,journal=j,root=native_root)
   actual<-jsonlite::fromJSON(file.path(run,paste0(f$out_stem,'.figure_spec.json')),simplifyVector=FALSE)
   expected<-jsonlite::fromJSON(native$spec,simplifyVector=FALSE)
   if(!identical(actual,expected)) {
     cat('SPEC DIFFERENCES:',j,f$id,'\n');print(all.equal(actual,expected));stop('complete matrix request/native spec differs')
   }
   stopifnot(identical(digest::digest(file=file.path(run,paste0(f$out_stem,'.png')),algo='sha256'),digest::digest(file=native$files$png,algo='sha256')))
   stopifnot(identical(actual$definition$matrix_contract$source_sha256,expected$definition$matrix_contract$source_sha256))
   cat('PASS',j,f$id,'complete native/request spec, source hash, normalized PDF content and PNG identical\n')
 }
 options(old)
 rec2<-os_render_figure_request(run)
 stopifnot(identical(vapply(rec$figures,function(x)x$spec$sha256,''),vapply(rec2$figures,function(x)x$spec$sha256,'')))
 cat('PASS',j,'byte-identical five-figure matrix request replay\n')
 file<-file.path(run,req$figures[[1]]$data$mat$path);cat('\n',file=file,append=TRUE)
 e<-tryCatch({os_render_figure_request(run);''},error=conditionMessage)
 stopifnot(grepl('OS_FIGURE_DATA_MISMATCH',e,fixed=TRUE));cat('PASS',j,'changed matrix data checksum refused\n')
}
cat('ALL MATRIX REPLAY CHECKS PASSED (10 figures, 2 exact request replays, 2 source checksum refusals)\n')
