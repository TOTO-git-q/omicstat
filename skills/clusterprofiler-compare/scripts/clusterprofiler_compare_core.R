CX_MODULE <- "clusterprofiler-compare"
CX_MODULE_VERSION <- "1.1.0"

cx_ids <- function(path) {
  d <- utils::read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
  if (!"feature_id" %in% names(d)) stop("OS_MISSING_COLUMN: gene and universe files need feature_id.",call.=FALSE)
  x <- trimws(as.character(d$feature_id))
  if (anyNA(x)||any(!nzchar(x))||anyDuplicated(x)) stop("OS_INVALID_INPUT: IDs must be nonempty and unique.",call.=FALSE)
  x
}

cx_manifest <- function(path) {
  m <- utils::read.csv(path,check.names=FALSE,stringsAsFactors=FALSE,colClasses="character")
  required <- c("group","genes","universe","population","study_unit","model","contrast","direction","threshold","top_n","selection_rule")
  miss <- setdiff(required,names(m))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: manifest needs %s.",paste(miss,collapse=", ")),call.=FALSE)
  if (nrow(m)<2) stop("OS_INVALID_INPUT: compare needs at least two named gene lists.",call.=FALSE)
  for (k in required) if (anyNA(m[[k]])||any(!nzchar(trimws(m[[k]]))))
    stop(sprintf("OS_INVALID_INPUT: manifest column %s has an empty value.",k),call.=FALSE)
  if (anyDuplicated(m$group)) stop("OS_INVALID_INPUT: group names must be unique.",call.=FALSE)
  root <- dirname(normalizePath(path))
  resolve <- function(p) if (grepl("^/",p)) p else file.path(root,p)
  genes_path <- vapply(m$genes,resolve,""); universe_path <- vapply(m$universe,resolve,"")
  if (any(!file.exists(genes_path))||any(!file.exists(universe_path))) stop("OS_INVALID_INPUT: manifest names a missing list or universe file.",call.=FALSE)
  genes <- lapply(genes_path,cx_ids); names(genes) <- m$group
  backgrounds <- lapply(universe_path,cx_ids); names(backgrounds) <- m$group
  for (i in seq_len(nrow(m))) {
    if (!length(genes[[i]])||!length(backgrounds[[i]])) stop("OS_EMPTY_DATA: a list or universe is empty.",call.=FALSE)
    if (!all(genes[[i]] %in% backgrounds[[i]])) stop(sprintf("OS_INVALID_UNIVERSE: group %s has selected genes outside its eligible background.",m$group[i]),call.=FALSE)
    if (setequal(genes[[i]],backgrounds[[i]])) stop(sprintf("OS_INVALID_UNIVERSE: group %s uses selected genes as the whole background.",m$group[i]),call.=FALSE)
  }
  same <- length(unique(m$population))==1 && all(vapply(backgrounds[-1],function(z) setequal(z,backgrounds[[1]]),logical(1)))
  list(metadata=m,genes=genes,backgrounds=backgrounds,same_population=same,
       inputs=as.list(stats::setNames(c(path,genes_path,universe_path),c("manifest",paste0("genes_",m$group),paste0("universe_",m$group)))))
}

cx_compute <- function(x,a) {
  if (a$database!="GO") stop("OS_REFDATA_MISSING: this gene-set collection is not pinned offline.",call.=FALSE)
  pool <- if (a$ontology=="ALL") a$pool else FALSE
  if (x$same_population) {
    res <- clusterProfiler::compareCluster(geneClusters=x$genes,fun="enrichGO",data="",source_from=NULL,
      OrgDb=org.Hs.eg.db::org.Hs.eg.db,keyType=a[["key-type"]],ont=a$ontology,pool=pool,
      universe=x$backgrounds[[1]],pvalueCutoff=1,qvalueCutoff=1,pAdjustMethod="BH",
      minGSSize=a[["min-size"]],maxGSSize=a[["max-size"]],readable=FALSE)
    if (is.null(res)) stop("OS_EMPTY_DATA: no testable term in the shared-population comparison.",call.=FALSE)
    raw <- as.data.frame(res)
    if (!nrow(raw)) stop("OS_EMPTY_DATA: compareCluster returned no testable terms.",call.=FALSE)
  } else {
    parts <- lapply(seq_along(x$genes),function(i) {
      res <- clusterProfiler::enrichGO(gene=x$genes[[i]],OrgDb=org.Hs.eg.db::org.Hs.eg.db,
        keyType=a[["key-type"]],ont=a$ontology,pvalueCutoff=1,pAdjustMethod="BH",
        universe=x$backgrounds[[i]],qvalueCutoff=1,minGSSize=a[["min-size"]],
        maxGSSize=a[["max-size"]],readable=FALSE,pool=pool)
      if (is.null(res)) return(NULL)
      d <- as.data.frame(res); if (!nrow(d)) return(NULL)
      d$Cluster <- x$metadata$group[i]; d
    })
    raw <- do.call(rbind,Filter(Negate(is.null),parts))
    if (is.null(raw)||!nrow(raw)) stop("OS_EMPTY_DATA: no testable term in any population.",call.=FALSE)
    rownames(raw) <- NULL
  }
  list(raw=raw,mode=if (x$same_population) "shared_universe_compareCluster" else "separate_background_ORA")
}
