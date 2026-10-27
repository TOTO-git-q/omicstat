SQ_MODULE_VERSION <- "1.0.0"
seurat_qc_compute <- function(mat,a) {
 if(a[["min-features"]]>=a[["max-features"]] || a[["min-counts"]]>=a[["max-counts"]]) os_seurat_fail("OS_INVALID_PARAMETER","Lower QC limits must be below upper limits.")
 if(a[["missing-mito"]]=="error" && !any(grepl(a[["mito-pattern"]],rownames(mat)))) os_seurat_fail("OS_MITO_FEATURES","Mitochondrial pattern matches no input genes.")
 md <- data.frame(sample=rep(a$sample,ncol(mat)),row.names=colnames(mat))
 if(!is.null(a$metadata)) {
   md <- os_read_sample_table(a$metadata,"cell")
   if(!"sample" %in% names(md)) os_seurat_fail("OS_MISSING_COLUMN","Metadata requires cell and sample.")
   if(!setequal(md$cell,colnames(mat))) os_seurat_fail("OS_SAMPLE_MISMATCH","Metadata cells differ from count columns.")
   md <- md[match(colnames(mat),md$cell),,drop=FALSE]; rownames(md) <- md$cell; md$cell <- NULL
 }
 x <- SeuratObject::CreateSeuratObject(assay="RNA", names.field=os_seurat_option(a,"create-names-field",1L), names.delim=os_seurat_option(a,"create-names-delim","_"), meta.data=md, project=os_seurat_option(a,"create-project","SeuratProject"), min.cells=a[["min-cells"]], min.features=a[["create-min-features"]], counts=mat)
 # Definitions describe the exact feature universe used by the QC computation.
 # Creation may remove features/cells before these metrics exist.
 metric_definitions <- list(
   nFeature_RNA=list(unit="detected RNA features",definition="Number of retained RNA features with raw count greater than zero per cell",measured_at="after_creation",retained_feature_count=nrow(x)),
   nCount_RNA=list(unit="raw RNA counts",definition="Sum of raw counts across retained RNA features per cell",measured_at="after_creation",retained_feature_count=nrow(x)),
   percent.mt=list(unit="percent",definition="100 times raw counts in pattern-matched retained RNA features divided by total raw RNA counts in the same cell",measured_at="after_creation",
                   mitochondrial_pattern=a[["mito-pattern"]],matched_feature_count=sum(grepl(a[["mito-pattern"]],rownames(x))),retained_feature_count=nrow(x),
                   organism=a$organism,feature_type=a[["feature-type"]],annotation="User-supplied feature identifiers and explicit regular expression; no external annotation lookup"))
 x$percent.mt <- Seurat::PercentageFeatureSet(pattern=a[["mito-pattern"]], features=NULL, col.name=NULL, assay="RNA", object=x)
 d <- data.frame(cell=colnames(x),x[[]],check.names=FALSE)
 d$fail_features <- d$nFeature_RNA <= a[["min-features"]] | d$nFeature_RNA >= a[["max-features"]]
 d$fail_counts <- d$nCount_RNA < a[["min-counts"]] | d$nCount_RNA >= a[["max-counts"]]
 d$fail_mito <- d$percent.mt >= a[["max-mito"]]
 d$pass <- !(d$fail_features | d$fail_counts | d$fail_mito)
 d$reason <- vapply(seq_len(nrow(d)),function(i) paste(c(if(d$fail_features[i]) "features",if(d$fail_counts[i]) "counts",if(d$fail_mito[i]) "mitochondrial"),collapse=";"),"")
 if(!any(d$pass)) os_seurat_fail("OS_QC_BLOCKER","No cells remain under explicit QC criteria; no draft produced.")
 x <- subset(x,cells=d$cell[d$pass])
 flow <- do.call(rbind,lapply(sort(unique(md$sample),method="radix"),function(s) {
  before <- d[d$sample==s,,drop=FALSE]
  data.frame(sample=s,input=sum(md$sample==s),after_creation=nrow(before),creation_removed=sum(md$sample==s)-nrow(before),fail_features=sum(before$fail_features),fail_counts=sum(before$fail_counts),fail_mito=sum(before$fail_mito),sequential_features=sum(before$fail_features),sequential_counts=sum(!before$fail_features & before$fail_counts),sequential_mito=sum(!before$fail_features & !before$fail_counts & before$fail_mito),retained=sum(before$pass))
 }))
 state <- list(front_end_ecosystem="seurat",qc_done=TRUE,normalized=FALSE,clustered=FALSE,integrated=FALSE,assay="RNA",organism=a$organism,feature_type=a[["feature-type"]],qc_parameters=a[c("min-cells","create-min-features","min-features","max-features","min-counts","max-counts","max-mito","mito-pattern")])
 details <- sprintf("n=%d input cells; %d after creation; %d retained. Strict feature interval (%d,%d), UMI interval [%d,%d), mitochondrial percentage < %g; pattern %s.",ncol(mat),nrow(d),ncol(x),a[["min-features"]],a[["max-features"]],a[["min-counts"]],a[["max-counts"]],a[["max-mito"]],a[["mito-pattern"]])
 details <- paste(details,sprintf("Mitochondrial-pattern features present=%d; missing-mito policy=%s.",sum(grepl(a[["mito-pattern"]],rownames(mat))),a[["missing-mito"]]))
 list(object=x,state=state,tables=list(cell_qc=d,filter_flow=flow),details=details,metric_definitions=metric_definitions)
}
