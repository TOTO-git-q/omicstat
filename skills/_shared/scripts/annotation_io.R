# Offline annotation snapshots. No downloads, remote lookup or implicit licence grant.
os_annotation_stop <- function(code,msg) stop(paste0(code,": ",msg),call.=FALSE)
os_annotation_registry <- function(registry, refdata_id, consumer, kind) {
 d <- tryCatch(jsonlite::fromJSON(registry,simplifyVector=FALSE),error=function(e) os_annotation_stop("OS_REFDATA_MISSING","registry JSON missing or invalid"))
 if (!identical(d$schema,"omicstat.refdata.v2")) os_annotation_stop("OS_REFDATA_MISMATCH","v2 registry required")
 z <- Filter(function(e)identical(e$id,refdata_id),d$entries)
 if(length(z)!=1L)os_annotation_stop("OS_REFDATA_MISSING","reference ID must resolve exactly once")
 e<-z[[1]]
 if(!identical(e$kind,kind) || !consumer %in% unlist(e$consumers))os_annotation_stop("OS_REFDATA_MISMATCH","reference kind/consumer differs")
 if(!identical(e$redistribution,"user_supplied"))os_annotation_stop("OS_REFDATA_MISMATCH","this entry path requires explicit user-supplied provenance")
 e
}
os_reactome_species <- function(organism) {
 z<-list(human=c("Homo sapiens","org.Hs.eg.db"),mouse=c("Mus musculus","org.Mm.eg.db"),rat=c("Rattus norvegicus","org.Rn.eg.db"),celegans=c("Caenorhabditis elegans","org.Ce.eg.db"),yeast=c("Saccharomyces cerevisiae","org.Sc.sgd.db"),zebrafish=c("Danio rerio","org.Dr.eg.db"),fly=c("Drosophila melanogaster","org.Dm.eg.db"))
 if(!is.character(organism)||length(organism)!=1L||!organism %in% names(z))os_annotation_stop("OS_INVALID_PARAMETER","unsupported explicit organism")
 z[[organism]]
}
os_annotation_db_binding <- function(pkg) {
 os_require_pkg(pkg);os_require_pkg("AnnotationDbi")
 db<-getExportedValue(pkg,pkg); path<-AnnotationDbi::dbfile(db)
 if(length(path)!=1L||!file.exists(path))os_annotation_stop("OS_REFDATA_MISSING","installed annotation SQLite unavailable")
 list(package=pkg,version=as.character(utils::packageVersion(pkg)),file=basename(path),sha256=digest::digest(file=path,algo="sha256"))
}
os_reactome_snapshot <- function(organism) {
 species<-os_reactome_species(organism);os_require_pkg("ReactomePA")
 # This inspected version reads installed SQLite. New APIs must be reviewed before use.
 if(as.character(utils::packageVersion("ReactomePA"))!="1.56.0")os_annotation_stop("OS_PACKAGE_VERSION","offline binding is reviewed for ReactomePA1.56.0 only")
 bindings<-lapply(c("reactome.db",species[2]),os_annotation_db_binding)
 g<-ReactomePA::gson_Reactome(organism=organism)
 pairs<-as.data.frame(methods::slot(g,"gsid2gene"),stringsAsFactors=FALSE);names(pairs)<-c("term_id","gene_id")
 terms<-as.data.frame(methods::slot(g,"gsid2name"),stringsAsFactors=FALSE);names(terms)<-c("term_id","term_name")
 for(k in names(pairs))pairs[[k]]<-as.character(pairs[[k]])
 for(k in names(terms))terms[[k]]<-as.character(terms[[k]])
 pairs<-unique(pairs);pairs<-pairs[order(pairs$term_id,pairs$gene_id,method="radix"),,drop=FALSE]
 terms<-unique(terms);terms<-terms[order(terms$term_id,terms$term_name,method="radix"),,drop=FALSE]
 if(anyNA(pairs)||anyNA(terms)||anyDuplicated(terms$term_id)||any(!nzchar(pairs$gene_id)))os_annotation_stop("OS_INVALID_RESULT","resource has invalid identifiers")
 bytes<-paste0(paste(paste(pairs$term_id,pairs$gene_id,sep="\t"),collapse="\n"),"\n")
 names_bytes<-paste0(paste(paste(terms$term_id,terms$term_name,sep="\t"),collapse="\n"),"\n")
 manifest<-list(schema="omicstat.reactome-snapshot.v1",organism=organism,species=species[1],engine_version="1.56.0",bindings=bindings,mapping_sha256=digest::digest(bytes,algo="sha256",serialize=FALSE),names_sha256=digest::digest(names_bytes,algo="sha256",serialize=FALSE),n_memberships=nrow(pairs),n_terms=nrow(terms))
 list(manifest=manifest,pairs=pairs,terms=terms)
}
os_reactome_bound <- function(a) {
 e<-os_annotation_registry(a[["refdata-registry"]],a[["refdata-id"]],"reactomepa-ora","geneset")
 p<-os_user_refdata(a[["refdata-input"]],a[["refdata-provenance"]],a[["refdata-id"]])
 d<-tryCatch(jsonlite::fromJSON(a[["refdata-input"]],simplifyVector=FALSE),error=function(e)os_annotation_stop("OS_REFDATA_MISMATCH","snapshot manifest invalid"))
 species<-os_reactome_species(a$organism)[1]
 if(!identical(p$species,species)||!identical(d$species,species)||!identical(d$organism,a$organism)||!identical(d$schema,"omicstat.reactome-snapshot.v1"))os_annotation_stop("OS_REFDATA_MISMATCH","snapshot/provenance organism differs")
 x<-os_reactome_snapshot(a$organism);actual<-x$manifest
 scalar<-c("engine_version","mapping_sha256","names_sha256","n_memberships","n_terms")
 if(any(vapply(scalar,function(k)!identical(as.character(unlist(d[[k]])),as.character(actual[[k]])),logical(1))))os_annotation_stop("OS_REFDATA_MISMATCH","actual installed mapping differs from declared resource")
 if(length(d$bindings)!=length(actual$bindings))os_annotation_stop("OS_REFDATA_MISMATCH","SQLite bindings missing")
 for(i in seq_along(actual$bindings))for(k in c("package","version","file","sha256"))if(!identical(d$bindings[[i]][[k]],actual$bindings[[i]][[k]]))os_annotation_stop("OS_REFDATA_MISMATCH","installed SQLite package/version/bytes differ")
 x$provenance<-p;x$refdata_id<-e$id;x
}
