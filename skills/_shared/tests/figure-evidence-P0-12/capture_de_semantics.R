# Matched-input rendering against explicit baseline/current source directories.
# Usage: Rscript capture_de_semantics.R ROOT FIXTURES_JSON OUT before|after
a <- commandArgs(TRUE);root <- normalizePath(a[1]);fixture <- normalizePath(a[2]);out <- a[3];stage <- a[4]
stopifnot(stage %in% c("before","after"))
source(file.path(root,"skills/_shared/scripts/fig_all.R"))
x <- jsonlite::read_json(fixture,simplifyVector=TRUE)
# os_write_json preserves data frames as named column arrays; restore their
# explicit rectangular type rather than treating the list length as row n.
for (key in c("ft","equivalence","minimum_table","points"))
  x[[key]] <- as.data.frame(x[[key]],stringsAsFactors=FALSE,check.names=FALSE)
ft <- x$ft;dir.create(out,recursive=TRUE,showWarnings=FALSE)
file.copy(fixture,file.path(out,"FIXTURES.json"),overwrite=TRUE)
observations <- list()
for(j in c("nature","cell")) {
  old <- options(omicstat.journal=j)
  logft <- ft;logft$base_mean <- seq(-4,3.5,length.out=nrow(ft))
  if(stage=="before") {
    plots <- list(
      volcano_zero=os_volcano(ft,lfc_threshold=1,label_n=0,journal=j),
      ma_caps=os_ma(ft,lfc_threshold=0,label_genes=ft$feature_id[1:4],y_max=4,journal=j),
      ma_small=os_ma(x$equivalence,lfc_threshold=0,label_n=0,y_max=4,journal=j),
      ma_log_abundance=os_ma(logft,lfc_threshold=0,label_n=0,italic_labels=FALSE,journal=j),
      volcano_annotation=os_volcano(ft,lfc_threshold=1,label_n=0,journal=j))
    err <- tryCatch(get("os_selected_feature_points",mode="function"),error=function(e)conditionMessage(e))
    observations[[paste(j,"selected_features",sep="/")]] <- list(status="unavailable_at_parent",native_lookup_error=err,
      same_source_values="FIXTURES.json#/points",figure_not_fabricated=TRUE,owner_visual_review=NULL)
  } else {
    plots <- list(
      volcano_zero=os_volcano(ft,lfc_threshold=1,label_n=0,test_contract=x$zero,effect_provenance=x$effect,journal=j),
      ma_caps=os_ma(ft,lfc_threshold=0,label_genes=ft$feature_id[1:4],y_max=4,test_contract=x$zero,effect_provenance=x$effect,journal=j),
      ma_small=os_ma(x$equivalence,lfc_threshold=0,label_n=0,y_max=4,test_contract=x$small,effect_provenance=x$effect,journal=j),
      ma_log_abundance=os_ma(logft,lfc_threshold=0,label_n=0,italic_labels=FALSE,mean_kind="mean_log_abundance",
        mean_scale="log2",mean_unit="normalized protein intensity",journal=j),
      volcano_annotation=os_volcano(ft,lfc_threshold=1,label_n=0,test_contract=x$zero,effect_provenance=x$effect,
        colour_mode="annotation",annotation_col="annotation",annotation_title="Binding annotation",
        annotation_levels=c("Unbound","Bound","Missing annotation"),annotation_denominator="direction",journal=j),
      selected_features=os_selected_feature_points(x$points,c("SYN_FEATURE_A","SYN_FEATURE_B"),"Predeclared synthetic examples",
        "invented size-factor scaling","normalized counts","Reference",subject_col="subject",pair_col="pair",
        group_order=c("Reference","Target"),journal=j))
  }
  for(n in names(plots)) {
    # Matched physical canvases for comparisons, not resized screenshots.
    result <- os_finalize_figure(plots[[n]],file.path(out,j,n),width="double",height_mm=118,journal=j,root=out)
    observations[[paste(j,n,sep="/")]] <- list(status="rendered",caption=result$spec_obj$caption,
      counts=result$spec_obj$counts,source_fixture_unchanged=TRUE,owner_visual_review=NULL)
  }
  options(old)
}
os_write_json(observations,file.path(out,"OBSERVATIONS.json"),digits=I(17))
cat("Captured",stage,"at identical source values and matched physical canvases.\n")
