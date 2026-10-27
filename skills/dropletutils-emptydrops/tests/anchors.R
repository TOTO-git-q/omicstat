a<-commandArgs(TRUE);out<-a[2];d<-read.csv(file.path(out,"tables/barcodes.csv"),stringsAsFactors=FALSE);x<-readRDS(file.path(a[3],"counts.rds"));sce<-readRDS(file.path(out,"objects/sce.rds"));p<-d$p_value;p[d$retained_by_count]<-0;p[d$total_umi<=100]<-NA_real_
# Independent BH rank/minimum implementation; not stats::p.adjust or engine output as truth.
o<-order(p,na.last=NA);bh<-rep(NA_real_,length(p));last<-1
for(k in rev(seq_along(o))){i<-o[k];last<-min(last,p[i]*length(o)/k);bh[i]<-last}
if(!identical(is.na(bh),is.na(d$fdr)))stop("FDR missingness differs")
profile<-read.csv(file.path(out,"tables/ambient_profile.csv"));got<-list(raw_barcode_count=nrow(d),total_umi=sum(d$total_umi),zero_barcode_count=sum(d$total_umi==0),ambient_probability_sum=sum(profile$probability),zero_feature_probability=profile$probability[profile$feature_id=='gene51'],independent_bh_error=max(abs(bh-d$fdr),na.rm=TRUE),raw_counts_preserved=as.integer(identical(SummarizedExperiment::assay(sce,'counts'),x)))
jsonlite::write_json(got,a[1],auto_unbox=TRUE,pretty=TRUE,digits=NA)
