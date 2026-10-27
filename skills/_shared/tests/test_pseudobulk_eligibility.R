here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
root <- normalizePath(file.path(here,"../../.."))
source(file.path(root,"skills/_shared/scripts/fig_all.R"))
source(file.path(root,"skills/_shared/scripts/sc_backend_io.R"))
source(file.path(root,"skills/muscat-pseudobulk/scripts/muscat_pseudobulk_audit.R"))
for (pkg in c("SingleCellExperiment","SummarizedExperiment","S4Vectors","Matrix","edgeR"))
  if(!requireNamespace(pkg,quietly=TRUE))stop(paste("OS_MISSING_PACKAGE:",pkg),call.=FALSE)
passed<-0L; failures<-character()
check<-function(ok,label){if(isTRUE(ok)){passed<<-passed+1L;cat("PASS",label,"\n")}else{failures<<-c(failures,label);cat("FAIL",label,"\n")}}
bad<-function(expr,label)check(inherits(tryCatch(force(expr),error=function(e)e),"error"),label)
samples<-paste0("SYN_SAMPLE_",1:4);subtypes<-c("SYN_TYPE_A","SYN_TYPE_B","SYN_TYPE_C")
counts<-rbind(c(3,3,3,3),c(0,1,3,3),c(2,2,2,2))
source_cells<-do.call(rbind,lapply(seq_along(subtypes),function(k)do.call(rbind,lapply(seq_along(samples),function(i){
  n<-counts[k,i];if(!n)return(NULL)
  data.frame(cell_id=paste("SYN_CELL",k,i,seq_len(n),sep="_"),sample=samples[i],subtype=subtypes[k],
    condition=if(i<=2)"Reference"else"Target",donor=paste0("SYN_DONOR_",i),stringsAsFactors=FALSE)
}))))
rownames(source_cells)<-NULL
cm<-matrix(rep(c(2L,3L,4L),nrow(source_cells)),nrow=3,dimnames=list(paste0("SYN_GENE_",1:3),source_cells$cell_id))
sce<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=cm),colData=S4Vectors::DataFrame(source_cells,row.names=source_cells$cell_id))
a<-list("sample-col"="sample","condition-col"="condition","cluster-col"="subtype","donor-col"="donor")
check(identical(muscat_source_cells(sce,a),source_cells),"source audit uses exact original cell/sample/subtype/donor IDs")
dup<-sce;colnames(dup)[2]<-colnames(dup)[1]
bad(muscat_source_cells(dup,a),"reused actual cell ID refused")
mixed<-sce;mixed$donor[2]<-"SYN_OTHER_DONOR"
bad(muscat_source_cells(mixed,a),"mixed donors under one sample label refused")
split<-sce;split$donor[split$sample==samples[2]]<-"SYN_DONOR_1"
bad(muscat_source_cells(split,a),"one donor-condition split into sample labels cannot increase inferential n")
prepared_ids<-source_cells$cell_id[!(source_cells$subtype==subtypes[3]&source_cells$sample==samples[4])]
am<-matrix(c(4,5,6,5,6,7,8,9,10,9,10,11),3,dimnames=list(rownames(cm),samples))
bm<-am;bm[,1]<-0;bm[,3]<-0
cmat<-am;cmat[,4]<-0
pb<-SingleCellExperiment::SingleCellExperiment(assays=stats::setNames(list(am,bm,cmat),subtypes),
  colData=S4Vectors::DataFrame(group_id=c("Reference","Reference","Target","Target"),row.names=samples))
res<-list(data=stats::setNames(list(edgeR::DGEList(am)),subtypes[1]))
d<-muscat_pseudobulk_eligibility_table(source_cells,prepared_ids,pb,res,"Reference","Target",2)
check(nrow(d)==12 && all(table(d$subtype)==4),"complete sample-by-subtype grid includes excluded slots")
getstate<-function(s,t)d$state[d$sample==s&d$subtype==t]
check(all(d$state[d$subtype==subtypes[1]]=="fitted"),"fitted membership comes from native result data sample IDs")
check(getstate(samples[1],subtypes[2])=="zero_cell","zero-cell state remains distinct")
check(getstate(samples[2],subtypes[2])=="below_min_cells","below-minimum-cell state remains distinct")
check(getstate(samples[3],subtypes[2])=="zero_library","actual zero count library has its own state")
check(getstate(samples[4],subtypes[2])=="not_fitted","unavailable backend fitting reason remains not_fitted rather than invented zero")
check(getstate(samples[4],subtypes[3])=="prep_excluded","preparation exclusion differs from original zero cells")
check(sum(d$n_cells)==length(prepared_ids)&&sum(d$input_n_cells)==nrow(source_cells),"original and prepared cell totals independently reconcile")
check(isTRUE(muscat_check_donor_design(source_cells,pb,NULL)),"unique donors do not require an invented pairing design")
paired<-source_cells;paired$donor[paired$sample==samples[3]]<-"SYN_DONOR_1";paired$donor[paired$sample==samples[4]]<-"SYN_DONOR_2"
bad(muscat_check_donor_design(paired,pb,NULL),"repeated donors cannot silently use an unpaired native design")
design<-model.matrix(~factor(c(1,2,1,2))+factor(c(0,0,1,1)));rownames(design)<-samples
check(isTRUE(muscat_check_donor_design(paired,pb,design)),"explicit design spanning actual donor effects is accepted")
notpaired<-model.matrix(~factor(c(0,0,1,1)));rownames(notpaired)<-samples
bad(muscat_check_donor_design(paired,pb,notpaired),"explicit but donor-unadjusted design refused")
badres<-res;badres$data[[1]]<-edgeR::DGEList(am[,c(1,3,4)])
bad(muscat_pseudobulk_eligibility_table(source_cells,prepared_ids,pb,badres,"Reference","Target",2),"post-filter single reference sample blocks inferential output")
alias<-source_cells;alias$donor[alias$condition=="Reference"]<-"SYN_DONOR_1"
bad(muscat_pseudobulk_eligibility_table(alias,prepared_ids,pb,res,"Reference","Target",2),"multiple fitted sample labels cannot inflate actual donor n")
for(j in c("nature","cell")){
  p<-os_pseudobulk_eligibility(d,c("Reference","Target"),2,donor_col="donor",journal=j);m<-attr(p,"os_meta")
  check(m$counts$n_samples==4&&m$counts$n_donors==4,paste(j,"same donor across subtypes counted only once globally"))
  s<-m$data$summary;s<-s[s$subtype==subtypes[1],]
  check(all(s$n_fitted_samples==2)&&all(s$n_fitted_donors==2),paste(j,"actual fitted independent n per condition"))
  check(identical(m$data$raw_source,d),paste(j,"all raw eligibility values and reasons retained"))
  check(m$notes$cell_label_contrast_min>=4.5,paste(j,"all actual count labels meet 4.5:1 tile contrast"))
  check(inherits(p,"patchwork")&&grepl("separate count panel",m$caption,fixed=TRUE),paste(j,"actual fitted sample and donor n appear in their own visible count panel"))
  out<-Sys.getenv("OMICSTAT_DE_OUT",file.path(tempdir(),"de-semantics"))
  if(Sys.getenv("OMICSTAT_DE_RENDER","1")=="1"){
    aa<-os_finalize_figure(p,file.path(out,j,"pseudobulk_eligibility"),width="double",journal=j)
    bb<-os_finalize_figure(p,file.path(out,paste0(j,"-replay"),"pseudobulk_eligibility"),width="double",journal=j)
    check(identical(aa$spec_obj,bb$spec_obj),paste(j,"pseudobulk exact native spec/image replay"))
  }
}
no_donor<-os_pseudobulk_eligibility(d[,setdiff(names(d),"donor")],c("Reference","Target"),2)
check(is.null(attr(no_donor,"os_meta")$counts$n_donors)&&grepl("do not prove",attr(no_donor,"os_meta")$caption,fixed=TRUE),"no donor mapping leaves independence unproven")
bad(os_pseudobulk_eligibility(d[-1,],c("Reference","Target"),2),"incomplete source grid refused rather than implicitly filled with zero")
wrong<-d;wrong$n_cells[wrong$state=="zero_cell"]<-1
bad(os_pseudobulk_eligibility(wrong,c("Reference","Target"),2),"zero-cell state contradicting raw count refused")
cat("ASSERTIONS",passed,"FAILED",length(failures),"\n")
if(length(failures))stop(paste(failures,collapse="; "),call.=FALSE)
