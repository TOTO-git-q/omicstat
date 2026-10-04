OSS_MODULE_VERSION <- "1.0.0"
seurat_modulescore_compute <- function(x,a) {
 if(!identical(a[["set-organism"]],x@misc$omicstat_state$organism)) os_seurat_fail("OS_INVALID_PARAMETER","Gene-set and chain organisms differ; supply explicit matching sets.")
 lines <- readLines(a[["gene-sets"]],warn=FALSE)
 fields <- strsplit(lines,"\t",fixed=TRUE)
 if(!length(fields) || any(lengths(fields)<3L)) os_seurat_fail("OS_INVALID_INPUT","GMT requires name, source and at least one feature per row.")
 nm <- vapply(fields,`[`,"",1L)
 if(anyDuplicated(nm)) os_seurat_fail("OS_INVALID_INPUT","Gene-set names must be unique.")
 sets <- lapply(fields,function(v) unique(v[-c(1,2)])); names(sets) <- nm
 assay <- a$assay %||% x@misc$omicstat_state$assay
 pool <- if(is.null(a$pool)) NULL else readLines(a$pool,warn=FALSE)
 if(a$k=="true") {
  if(is.null(a[["kmeans-object"]])) os_seurat_fail("OS_MISSING_PARAMETER","--k true requires --kmeans-object from Seurat DoKMeans.")
  x@kmeans.obj <- readRDS(a[["kmeans-object"]])
 }
 x <- Seurat::AddModuleScore(object=x,features=sets,pool=pool,nbin=a$nbin,ctrl=a$ctrl,k=identical(a$k,"true"),assay=assay,name=a$name,seed=a$seed,search=FALSE,slot=a$slot)
 cols <- paste0(a$name,seq_along(sets))
 if(a$k=="true") cols <- grep(paste0("^",a$name),names(x[[]]),value=TRUE)
 score <- data.frame(cell=colnames(x),x[[]][cols],check.names=FALSE)
 long <- do.call(rbind,lapply(seq_along(cols),function(i) data.frame(cell=colnames(x),sample=x$sample,cluster=x$cluster,set=if(a$k=="true") cols[i] else nm[i],score=x[[cols[i]]][,1])))
 manifest <- do.call(rbind,lapply(seq_along(sets),function(i) data.frame(set=nm[i],source=fields[[i]][2],organism=a[["set-organism"]],supplied=length(sets[[i]]),matched=sum(sets[[i]] %in% rownames(x[[assay]])),dropped=paste(setdiff(sets[[i]],rownames(x[[assay]])),collapse=";"),score_column=if(a$k=="true") NA_character_ else cols[i])))
 st <- x@misc$omicstat_state; st$module_scores <- list(assay=assay,slot=a$slot,sets=nm,columns=cols,nbin=a$nbin,ctrl=a$ctrl,seed=a$seed)
 details <- sprintf("n=%d cells; Seurat AddModuleScore, assay=%s, slot=%s, nbin=%d, ctrl=%d, k=%s, pool=%s, name=%s, seed=%d, offline search=FALSE; raw scores, no cutoff or standardization. Gene-set sources and matched counts are in gene_sets.csv.",ncol(x),assay,a$slot,a$nbin,a$ctrl,a$k,if(is.null(pool)) "all assay genes" else paste(length(pool),"supplied genes"),a$name,a$seed)
 list(object=x,state=st,tables=list(module_scores=score,scores=long,gene_sets=manifest),details=details)
}
