# Export only a declaration of already installed resources. No fetch or licence inference.
a<-commandArgs(trailingOnly=TRUE)
if(length(a)!=6L)stop("Usage: Rscript tools/export_reactome_snapshot.R organism manifest.json provenance.json refdata_id licence permitted_use")
here<-dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])));shared<-file.path(here,"..","skills","_shared","scripts")
for(f in c("module_kit.R","refdata_io.R","annotation_io.R"))source(file.path(shared,f))
if(file.exists(a[2])||file.exists(a[3]))stop("OS_OUTPUT_EXISTS: refusing snapshot overwrite")
x<-os_reactome_snapshot(a[1]);jsonlite::write_json(x$manifest,a[2],auto_unbox=TRUE,pretty=TRUE,digits=NA)
p<-list(refdata_id=a[4],source_url="https://bioconductor.org/packages/ReactomePA/",version=paste(vapply(x$manifest$bindings,function(b)paste(b$package,b$version),""),collapse="; "),licence=a[5],permitted_use=a[6],sha256=digest::digest(file=a[2],algo="sha256"),species=x$manifest$species,redistribution="user_supplied",declaration="Caller-supplied licence/use statement; exporter grants no permission and downloads nothing")
jsonlite::write_json(p,a[3],auto_unbox=TRUE,pretty=TRUE,digits=NA)
