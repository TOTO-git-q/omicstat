a<-commandArgs(TRUE);out<-a[1];dir.create(out,recursive=TRUE,showWarnings=FALSE);set.seed(20261016)
x<-cbind(stats::rmultinom(200,50,rep(1,50)),stats::rmultinom(40,500,c(rep(40,10),rep(1,40))),matrix(0L,50,10));x<-rbind(x,zero_feature=0L);dimnames(x)<-list(paste0("gene",seq_len(nrow(x))),sprintf("barcode%04d",seq_len(ncol(x))))
saveRDS(x,file.path(out,"counts.rds"));write.csv(data.frame(feature_id=rownames(x),x,check.names=FALSE),file.path(out,"counts.csv"),row.names=FALSE)
for(kind in c("fractional","negative","nonfinite","duplicate","filtered","no-ambient","too-large")){
 z<-x
 if(kind=="fractional")z[1,1]<-.5
 if(kind=="negative")z[1,1]<- -1
 if(kind=="nonfinite")z[1,1]<-NA
 if(kind=="duplicate")colnames(z)[2]<-colnames(z)[1]
 if(kind=="filtered")z<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=z))
 if(kind=="no-ambient")z<-x[,201:240]
 if(kind=="too-large"){z<-Matrix::sparseMatrix(i=1,j=1,x=1,dims=c(40001,3));dimnames(z)<-list(paste0("g",1:40001),letters[1:3])}
 saveRDS(z,file.path(out,paste0(kind,".rds")))
}
