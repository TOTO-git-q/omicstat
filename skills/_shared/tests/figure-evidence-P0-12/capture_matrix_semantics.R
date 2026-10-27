# Project-invented fixtures only. The identical source file is used at both refs.
a<-commandArgs(TRUE);root<-normalizePath(a[1]);out<-a[2];stage<-a[3];stopifnot(stage%in%c('before','after'))
source(file.path(root,'skills/_shared/scripts/fig_all.R'));dir.create(out,recursive=TRUE,showWarnings=FALSE)
m<-matrix(c(0,2,8,5,1,3,5,7,2,9,4,8,6,8,3,11,9,12,1,6,10,14,4,15),4,dimnames=list(paste0('feature',1:4),paste0('sample',1:6)))
cd<-data.frame(sample=colnames(m),condition=rep(c('reference','treated'),each=3),time=rep(c('early','late','late'),2),stringsAsFactors=FALSE)
ft<-data.frame(feature_id=rownames(m),padj=c(.03,.01,.02,.2),log2fc=c(1,2,-2,0))
missing<-m;missing[1,1]<-NA;missing[2,]<-3;missing[4,2]<-Inf
as_table<-function(x)data.frame(row_id=rep(rownames(x),ncol(x)),col_id=rep(colnames(x),each=nrow(x)),value=as.vector(x),source_state=ifelse(is.na(as.vector(x)),'missing',ifelse(is.infinite(as.vector(x)),'positive_infinity',ifelse(as.vector(x)==0,'true_zero','observed'))))
os_write_json(list(expression=as_table(m),unavailable=as_table(missing),sample_metadata=cd,feature_results=ft,
  input_provenance='manually invented deterministic numeric fixtures; no real biological records or paper pixels'),file.path(out,'FIXTURES.json'),digits=I(17))
observations<-list()
for(j in c('nature','cell')) {
 old<-options(omicstat.journal=j)
 distance<-if(stage=='before')os_sample_distance(m,cd,'condition',journal=j)else os_sample_distance(m,cd,'condition',annotation_cols=c('condition','time'),preprocessing='unknown',journal=j)
 if(stage=='before') { z<-.os_row_zscores(missing);states<-os_heatmap(z$values,'Row z-score','diverging',missing_policy='no_cluster',value_state=z$state,journal=j) }
 else states<-os_heatmap(missing,'Row z-score','diverging',missing_policy='no_cluster',normalization='row_zscore',matrix_kind='expression',row_entity='feature',col_entity='sample',quantity='row z-score',unit='dimensionless',journal=j)
 top<-os_top_heatmap(m,ft,cd,'condition',n=3,journal=j)
 make_panel<-function(x) {
  if(stage=='before')os_heatmap(x,'Runtime (seconds)','sequential',cluster_rows=FALSE,cluster_cols=FALSE,journal=j)
  else os_heatmap(x,'Runtime (seconds)','sequential',cluster_rows=FALSE,cluster_cols=FALSE,quantity='runtime',unit='seconds',row_entity='artificial task',col_entity='artificial condition',journal=j)
 }
 panels<-list(make_panel(m+10),make_panel(m+10))
 composition<-if(stage=='before')os_compose(panels,ncol=2,collect_guides=TRUE,journal=j)else os_compose(panels,ncol=2,collect_guides=TRUE,linked_rows=TRUE,linked_cols=TRUE,journal=j)
 for(nm in c('distance','states','top','composition')) {
  result<-os_save_figure(get(nm),file.path(out,j,nm),width='double',height_mm=100,journal=j,root=out)
  observations[[paste(j,nm,sep='/')]]<-list(caption=result$spec_obj$caption,counts=result$spec_obj$counts,source_fixture_unchanged=TRUE,owner_visual_review=NULL)
 }
 options(old)
}
os_write_json(observations,file.path(out,'OBSERVATIONS.json'),digits=I(17))
cat('Captured',stage,'8 invented figures at matched preset double width and 100 mm height.\n')
