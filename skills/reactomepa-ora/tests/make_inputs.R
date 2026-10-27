a<-commandArgs(trailingOnly=TRUE);out<-a[1];here<-dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])));root<-normalizePath(file.path(here,"../../.."));shared<-file.path(root,"skills/_shared/scripts")
for(f in c("module_kit.R","refdata_io.R","annotation_io.R"))source(file.path(shared,f))
q<-c("11171","8243","112464","2194","9318","79026","1654","65003","6240","3476","6238","3836","4176","1017","249")
available<-requireNamespace("ReactomePA",quietly=TRUE)
if(available){x<-os_reactome_snapshot("human");u<-sort(unique(c(x$pairs$gene_id,q)),method="radix");manifest<-x$manifest}else{
 # Typed missing-engine fixture supports input-refusal tests only. It is never a real snapshot.
 u<-sort(unique(c(q,as.character(1:100))),method="radix");manifest<-list(schema="omicstat.reactome-snapshot.v1",organism="human",species="Homo sapiens",fixture_incomplete="ReactomePA missing; canonical/anchors cannot run")
}
write.csv(data.frame(gene_id=q),file.path(out,"selected.csv"),row.names=FALSE);write.csv(data.frame(gene_id=u),file.path(out,"universe.csv"),row.names=FALSE)
jsonlite::write_json(manifest,file.path(out,"snapshot.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
p<-list(refdata_id="reactome_gene_sets",source_url="https://bioconductor.org/packages/ReactomePA/",version=if(available)"Actual installed SQLite versions bound in snapshot" else "INCOMPLETE: engine unavailable",licence="Installed package licences apply; private development use only; redistribution not authorized by this fixture",permitted_use="Private software validation only; owner must review real resource terms before redistribution",sha256=digest::digest(file=file.path(out,"snapshot.json"),algo="sha256"),species="Homo sapiens")
jsonlite::write_json(p,file.path(out,"provenance.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
jsonlite::write_json(list(engine_available=available,canonical_ready=available,no_download=TRUE),file.path(out,"FIXTURE_STATUS.json"),auto_unbox=TRUE,pretty=TRUE)
