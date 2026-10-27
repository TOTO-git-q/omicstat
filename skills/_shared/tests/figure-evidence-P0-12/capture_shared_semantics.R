# All rows here are invented by this project. No paper pixels or native example data.
args<-commandArgs(TRUE);root<-normalizePath(args[1]);out<-args[2];stage<-args[3]
stopifnot(stage %in% c("before","after"))
source(file.path(root,"skills/_shared/scripts/fig_all.R"));source(file.path(root,"skills/_shared/scripts/fig_mod_sc_backend.R"))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
d<-data.frame(observation_id=paste0("invented_obs",1:6),person_id=rep(paste0("invented_person",1:3),2),visit=rep(c(1,2),each=3),seconds=c(24000,25000,26000,20000,22000,23000),probability=c(.2,.3,.4,.3,.4,.5))
t<-data.frame(gene=paste0("invented_gene",1:8),logFC=c(-3,-2,-1,0,.5,1,2,3),p_adj.loc=c(.001,.01,.1,.7,NA,.2,.02,.003),p_adj.glb=c(.02,.1,.4,.9,NA,.5,.2,.04))
g<-data.frame(group=rep(c("A","B","C"),each=3),value=c(1,1.2,.9,1.4,1.5,1.3,1.8,1.7,1.9),unit=paste0("invented_unit",1:9))
cmp<-data.frame(comparison_id=c("invented_c1","invented_c2"),group1=c("A","B"),group2=c("B","C"),p=c(.053,.012),y=c(2.1,2.35),
 test=c("supplied Welch t","supplied paired t"),adjustment=c("none","BH"),family_size=c(2,2),statistic_kind=c("raw_p","adjusted_p"),model_id=c("invented_fit1","invented_fit2"),endpoint="artificial response",family_id="two_tests",paired_unit=c("not_applicable","invented_pair_id"),source_result_id=c("invented_r1","invented_r2"),comparison_type="pairwise",raw_p=c(.053,.006),adjusted_p=c(.053,.012))
em<-data.frame(cell_id=paste0("invented_cell",1:5),x=c(0,.2,1,1.2,2),y=c(0,.3,1,.8,2),group=c("A","A","B",NA,"B"))
os_write_json(list(observations=d,muscat=t,groups=g,comparisons=cmp,embedding=em),file.path(out,"FIXTURES.json"))
make_def<-function(column,quantity,unit) {
 pop<-list(status="known",ids=as.list(d$observation_id),rule="all six artificial visits")
 os_figure_definition(quantity,"visit","people",unit,pop,pop,"none",list(os_semantic_layer(column,d,"observation_id","observed",quantity,unit,d$person_id,"people",population_id="artificial_people",value_columns=column)))
}
observations<-list()
for(j in c("nature","cell")) {
 p1<-os_diag_xy(d,"visit","seconds",kind="points",xlab="Visit",ylab="Runtime (seconds)",caption="Artificial repeated records; independent-unit provenance not typed.",journal=j)
 p2<-os_diag_xy(d,"visit","probability",kind="points",xlab="Visit",ylab="Supplied probability",caption="Artificial supplied probabilities, no uncertainty supplied.",journal=j)
 if(stage=="after") {
  p1<-os_diag_xy(d,"visit","seconds",kind="points",xlab="Visit",ylab="Runtime (seconds)",caption="Artificial repeated records.",journal=j,definition=make_def("seconds","runtime","seconds"))
  p2<-os_diag_xy(d,"visit","probability",kind="points",xlab="Visit",ylab="Supplied probability",caption="Artificial supplied probabilities, no uncertainty supplied.",journal=j,definition=make_def("probability","probability","fraction"))
 }
 mixed<-os_compose(list(p1,p2),ncol=2,journal=j)
 if(stage=="after") {
  dd<-make_def("seconds","runtime","seconds");dd$quantity<-"mixed runtime and probability";dd$unit<-"per_layer";dd$layers[[2]]<-make_def("probability","probability","fraction")$layers[[1]]
  mixed<-os_with_meta(mixed,definition=dd,notes=list(layout_budget=os_layout_budget(c("runtime","probability"),os_width_mm("double",j),90,2)))
 }
 muscat<-os_muscat_volcano(t,.05,0,"invented B versus A",j)
 if(stage=="after") {
  pop<-list(status="known",ids=as.list(t$gene),rule="all eight invented gene tests, including missing adjusted P")
  md<-os_figure_definition("gene log fold change and adjusted P","gene test","unknown","per_layer",pop,pop,"supplied test results",list(os_semantic_layer("muscat_results",t,"gene","aggregate","gene test result","per_column",population_id="invented_genes",value_columns=c("logFC","p_adj.loc","p_adj.glb"))),statistics=list(
   os_statistic_contract("within_subtype",t$p_adj.loc,t$gene,"adjusted_p",method="supplied muscat fixture",adjustment="unknown",family_id="invented_subtype",family_size=8,threshold=.05),
   os_statistic_contract("global_unselected",t$p_adj.glb,t$gene,"adjusted_p",method="supplied muscat fixture",adjustment="unknown",family_id="global_unknown",family_size=NULL)))
  muscat<-os_with_meta(muscat,definition=md)
 }
 groups<-os_group_points(g,"unit","Artificial response","box",cmp,"supplied Welch t",journal=j)
 embedding<-if(stage=="before")os_embedding(em,"group",label=FALSE,journal=j)else os_embedding(em,"group",label=FALSE,journal=j,category_namespace="artificial_classes",category_role="biological_class",redundant_shapes=TRUE)
 for(nm in c("mixed","muscat","groups","embedding")) {
  p<-get(nm);stem<-file.path(out,j,nm)
  result<-os_save_figure(p,stem,width="double",height_mm=90,journal=j,root=out)
  observations[[paste(j,nm,sep="/")]]<-list(caption=result$spec_obj$caption,counts=result$spec_obj$counts,raw_source_unchanged=TRUE,visual_review=NULL)
 }
}
os_write_json(observations,file.path(out,"OBSERVATIONS.json"))
cat("Captured",stage,"8 artificial figures at preset double width (nature183/cell174mm) x90mm.\n")
