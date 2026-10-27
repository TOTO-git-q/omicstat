a<-commandArgs(FALSE);here<-dirname(normalizePath(sub("^--file=","",a[grepl("^--file=",a)][1])));root<-normalizePath(file.path(here,"../../../.."))
source(file.path(root,"skills/_shared/scripts/fig_all.R"));source(file.path(root,"skills/_shared/scripts/fig_mod_sc_seurat.R"));source(file.path(here,"fixtures_baseline.R"))
f<-p012_baseline_fixtures();original<-f;checks<-0L
check<-function(ok,msg) {if(!isTRUE(ok))stop(paste("FAIL",msg));checks<<-checks+1L;cat("PASS",msg,"\n")}
refuse<-function(expr,msg) check(grepl("^OS_(INVALID_INPUT|MISSING_COLUMN):",tryCatch({force(expr);"not refused"},error=conditionMessage)),msg)
forbidden<-Sys.getenv("OMICSTAT_WRITE_GOLDEN");check(!identical(forbidden,"1"),"golden writes remain disabled")
# Cell values are joined to coordinates, independently of either row order.
p<-os_feature_embedding(f$embedding,f$feature_values,"Artificial feature");d<-p$data
check(identical(d$.v[match(f$embedding$cell,d$cell)],unname(f$feature_values[f$embedding$cell])),"FE043 shuffled values joined by cell IDs")
q<-os_feature_embedding(f$embedding[4:1,],f$feature_values[c(4,2,1,3)],"Artificial feature")
check(identical(p$data[,c("cell","x","y",".v")],q$data[,c("cell","x","y",".v")]),"FE043 both input orders leave values/coordinates unchanged")
check(identical(attr(p,"os_meta")$data$coordinate_sha256,attr(q,"os_meta")$data$coordinate_sha256),"FE043 order-invariant coordinate hash")
refuse(os_feature_embedding(f$embedding,unname(f$feature_values),"X"),"FE043 unnamed positional values refused")
refuse(os_feature_embedding(f$embedding,f$feature_values[-1],"X"),"FE043 missing cell value refused")
bad<-f$feature_values;names(bad)[2]<-names(bad)[1];refuse(os_feature_embedding(f$embedding,bad,"X"),"FE043 duplicate value key refused")
bad<-f$embedding;bad$cell[2]<-bad$cell[1];refuse(os_feature_embedding(bad,f$feature_values,"X"),"FE043 duplicate coordinate key refused")
# Direct distance and one reused tree, compared to independent native stats.
dm<-as.matrix(dist(t(f$distance_expression)));hc<-hclust(as.dist(dm),method="complete")
p<-os_sample_distance(f$distance_expression,f$sample_table,"condition");meta<-attr(p,"os_meta")
check(identical(meta$data$tree$merge,hc$merge) && identical(meta$data$tree$height,hc$height),"FE018 native direct-distance merge/heights preserved")
check(identical(meta$data$row_order,meta$data$col_order) && identical(unlist(meta$data$row_order),hc$labels[hc$order]),"FE018 both axes reuse exact same leaf order")
check(meta$definition$matrix_kind=="distance" && grepl("direct distances",meta$caption),"FE018 matrix type and actual operation disclosed")
check(!identical(hc$height,hclust(dist(dm),method="complete")$height),"FE018 fixture distinguishes old distance-profile tree")
refuse(os_sample_distance(f$distance_expression,f$sample_table[-1,],"condition"),"FE018 incomplete annotation IDs refused")
bad<-hc;bad$labels[1]<-"wrong";refuse(.os_cluster(dm,precomputed=bad),"FE018 wrong source tree IDs refused")
# No zero filling in clustering or undefined row scaling.
refuse(.os_cluster(f$nonfinite_matrix),"FE019 nonfinite clustering fails by default")
check(is.null(.os_cluster(f$nonfinite_matrix,missing_policy="no_cluster")),"FE019 explicit no_cluster does not manufacture distances")
z<-.os_row_zscores(f$constant_matrix)
check(all(is.na(z$values["constant",])) && all(z$state["constant",]=="undefined_constant"),"FE019 constant row is undefined, not zero")
zz<-.os_row_zscores(f$nonfinite_matrix)
check(zz$state["missing",1]=="missing" && zz$state["infinite",3]=="infinite","FE019 original NA versus Inf reasons preserved")
refuse(os_top_heatmap(f$constant_matrix,f$heatmap_feature_table,f$sample_table,"condition",n=3),"FE019 implicit zero-fill top heatmap is refused")
p<-os_top_heatmap(f$constant_matrix,f$heatmap_feature_table,f$sample_table,"condition",n=3,missing_policy="no_cluster")
check(all(attr(p,"os_meta")$data$source_values$state[attr(p,"os_meta")$data$source_values$row_id=="constant"]=="undefined_constant"),"FE019 exported cell states retain undefined constant")
check(identical(attr(p,"os_meta")$data$raw_values[rownames(f$constant_matrix),colnames(f$constant_matrix)],f$constant_matrix),"FE019 original nonzero constant values preserved")
p<-os_heatmap(f$nonfinite_matrix,"Artificial value",cluster_rows=FALSE,cluster_cols=FALSE)
check(attr(p,"os_meta")$counts$states$true_zero==1L && attr(p,"os_meta")$counts$states$missing==1L && attr(p,"os_meta")$counts$states$infinite==1L,"FE019 true zero/NA/Inf counts distinct")
# A display cap may change chosen IDs but not full-cohort z references.
p<-os_gsva_score_heatmap(f$gsva_scores,f$gsva_samples,group_col="group",max_per_group=6)
q<-os_gsva_score_heatmap(f$gsva_scores,f$gsva_samples,group_col="group",max_per_group=3)
pd<-attr(p,"os_meta")$data;qd<-attr(q,"os_meta")$data;expected<-t(scale(t(f$gsva_scores)))
for (data in list(pd,qd)) {
 t<-data$source_values;check(isTRUE(all.equal(t$value,expected[cbind(match(t$row_id,rownames(expected)),match(t$col_id,colnames(expected)))])),"FE041 every shown value uses independent full-cohort z")
}
check(identical(pd$reference_center,qd$reference_center) && identical(pd$reference_sd,qd$reference_sd) && identical(pd$reference_sha256,qd$reference_sha256),"FE041 reference center/SD/hash do not depend on cap")
check(length(qd$selected_sample_ids)<length(pd$selected_sample_ids),"FE041 smaller cap changes display only")
refuse(os_gsva_score_heatmap(f$gsva_scores,f$gsva_samples[-1,],group_col="group"),"FE041 incomplete score metadata refused")
# Missing P is a separate state, invariant under reporting threshold.
p<-os_ma(f$ma_table,label_n=0);q<-os_ma(f$ma_table,padj_threshold=.3,label_n=0)
check(p$data$de_class[match("invented_NA",p$data$feature_id)]=="na" && q$data$de_class[match("invented_NA",q$data$feature_id)]=="na","FE013 missing P never becomes tested nonsignificance")
check(any(vapply(ggplot2::ggplot_build(p)$data,function(layer) "shape" %in% names(layer) && any(layer$shape==4),logical(1))),"FE013 missing P has redundant cross glyph, not an ns circle")
m<-attr(p,"os_meta");check(m$counts$n_input==sum(unlist(m$counts[c("up","down","ns","padj_na")])) && m$counts$missing_padj_reasons$independent_filter==1,"FE013 test-state denominator and actual reason reconcile")
check(identical(m$data$source_table,f$ma_table),"FE013 raw source values untouched")
# Real Seurat accessor path, without calling an estimator or bundled dataset.
r<-p012_marker_result(f);saved<-list();native_finalize<-os_finalize_figure
os_finalize_figure<-function(p,stem,...) {saved[[basename(stem)]]<<-p;invisible(NULL)}
os_seurat_markers_figures(r,list("top-n"=2,journal="nature"),tempdir());p<-saved$marker_dotplot
check(setequal(unique(p$data$cluster),unique(r$object$cell_type)),"FE047 actual core cell-level group-by is plotted")
check(!"invented-geneA" %in% p$data$gene,"FE047 filtered-out marker cannot reenter figures")
sel<-attr(p,"os_meta")$data$marker_selection
check(all(table(sel$cluster[sel$display_selected])==2L) && all(c("native_rank","display_rank","display_selected") %in% names(sel)),"FE047 separate native/display ranks and per-group top-n manifest")
check(setequal(unique(sel$gene[sel$display_selected]),unique(p$data$gene)),"FE047 selection table reconstructs plotted union")
check(identical(attr(p,"os_meta")$counts$cluster_n,as.list(table(r$object$cell_type))) || identical(attr(p,"os_meta")$counts$cells_per_cluster,as.list(table(r$object$cell_type))),"FE047 denominators use core grouping")
os_finalize_figure<-native_finalize
check(identical(f,original),"all artificial inputs remain unchanged")
# Render actual after figures using the exact before input, width and height.
out<-Sys.getenv("OMICSTAT_P012_OUT",file.path(tempdir(),"p012-baseline-after"));dir.create(out,recursive=TRUE,showWarnings=FALSE)
for(j in c("nature","cell")) {
 saved<-list();os_finalize_figure<-function(p,stem,...) {saved[[basename(stem)]]<<-p;invisible(NULL)}
 os_seurat_markers_figures(r,list("top-n"=2,journal=j),tempdir());os_finalize_figure<-native_finalize
 plots<-list("FE-043"=os_feature_embedding(f$embedding,f$feature_values,"Artificial feature",journal=j),
             "FE-018"=os_sample_distance(f$distance_expression,f$sample_table,"condition",journal=j),
             "FE-019"=os_top_heatmap(f$constant_matrix,f$heatmap_feature_table,f$sample_table,"condition",n=3,missing_policy="no_cluster",journal=j),
             "FE-041"=os_gsva_score_heatmap(f$gsva_scores,f$gsva_samples,group_col="group",journal=j),
             "FE-013"=os_ma(f$ma_table,label_n=0,journal=j),"FE-047"=saved$marker_dotplot)
 for(id in names(plots)) {
  lint<-os_fig_lint(plots[[id]],j);check(!any(lint$severity=="blocker"),paste(id,j,"no figure lint blocker"))
  os_save_figure(plots[[id]],file.path(out,id,j,"after"),width="double",height_mm=90,journal=j,formats=c("png","pdf"),root=out)
 }
}
cat(checks,"P0-12 six baseline correctness checks PASS\n")
