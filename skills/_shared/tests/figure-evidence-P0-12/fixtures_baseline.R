# These invented values are project fixtures, not package example data.
p012_baseline_fixtures <- function() {
  emb <- data.frame(cell=paste0("invented_c",1:4),x=c(0,1,2,3),y=c(0,2,1,3))
  mat <- matrix(c(0,0,1,0,1,2,4,3),2,dimnames=list(c("featureA","featureB"),paste0("invented_s",1:4)))
  cd <- data.frame(sample=colnames(mat),condition=c("A","A","B","B"))
  constant <- rbind(constant=c(5,5,5,5),changing=c(0,1,2,3),varying=c(1,4,2,8));colnames(constant)<-colnames(mat)
  scores <- rbind(set_A=seq(-15,14),set_B=cos(seq_len(30)),set_C=(seq_len(30)%%7)-3);colnames(scores)<-sprintf("invented_gs%02d",1:30)
  counts <- matrix(c(1,2,3,4,5,6,6,4,5,2,3,1,2,6,3,5,4,1),3,byrow=TRUE,dimnames=list(c("invented-geneA","invented-geneB","invented-geneC"),paste0("invented_mc",1:6)))
  list(embedding=emb,feature_values=c(invented_c3=30,invented_c1=10,invented_c4=40,invented_c2=20),
       distance_expression=mat,sample_table=cd,
       nonfinite_matrix=matrix(c(0,1,2,3,NA,2,4,8,1,2,Inf,4),3,byrow=TRUE,dimnames=list(c("true_zero","missing","infinite"),colnames(mat))),
       constant_matrix=constant,heatmap_feature_table=data.frame(feature_id=rownames(constant),padj=c(.01,.02,.03),log2fc=c(0,1,-1)),
       gsva_scores=scores,gsva_samples=data.frame(sample=colnames(scores),group=rep(c("A","B"),each=15)),
       ma_table=data.frame(feature_id=c("invented_NA","invented_NS","invented_UP","invented_DOWN"),base_mean=c(5,10,20,40),log2fc=c(1,0.2,2,-2),padj=c(NA,.2,.01,.01),pvalue=c(.02,.2,.001,.001),filtered_reason=c("independent_filter",NA,NA,NA)),
       marker_counts=counts,marker_table=data.frame(gene=rep(rownames(counts),2),cluster=rep(c("typeA","typeB"),each=3),p_val_adj=c(.001,.01,.02,.003,.02,.01),avg_log2FC=c(.1,2,1,.1,-1,-2)))
}
p012_marker_result <- function(f) {
 x<-SeuratObject::CreateSeuratObject(counts=f$marker_counts,min.cells=0,min.features=0)
 x$cluster<-rep(c("cluster0","cluster1"),each=3);x$cell_type<-rep(c("typeA","typeB"),3);x$sample<-rep(c("sample1","sample2"),each=3)
 SeuratObject::LayerData(x[["RNA"]],layer="data")<-log1p(f$marker_counts)
 SeuratObject::LayerData(x[["RNA"]],layer="scale.data")<-t(scale(t(log1p(f$marker_counts))))
 list(object=x,state=list(marker_assay="RNA"),grouping="cell_type",tables=list(markers_full=f$marker_table,markers_display=f$marker_table[abs(f$marker_table$avg_log2FC)>=1,]),details="Artificial native object; native grouping cell_type; display filter abs(log2FC)>=1.")
}
