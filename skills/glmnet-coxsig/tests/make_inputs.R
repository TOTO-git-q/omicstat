args <- commandArgs(trailingOnly = TRUE); out <- args[1]; dir.create(out, recursive = TRUE, showWarnings = FALSE)
e <- new.env(); utils::data("CoxExample",package="glmnet",envir=e); x <- e$CoxExample$x; y <- e$CoxExample$y
ids <- sprintf("training_%04d",seq_len(nrow(x))); colnames(x) <- paste0("V",seq_len(ncol(x))); set.seed(20261016)
extra <- matrix(stats::rnorm(nrow(x)*100,8,1),nrow=100); E <- rbind(t(x),extra); rownames(E) <- c(colnames(x),paste0("SIM",seq_len(nrow(extra))));colnames(E) <- ids
write.csv(data.frame(feature_id=rownames(E),E,check.names=FALSE),file.path(out,"expression.csv"),row.names=FALSE)
write.csv(data.frame(sample=ids,condition=rep(c("A","B"),length.out=length(ids))),file.path(out,"samples.csv"),row.names=FALSE)
d <- data.frame(unit=ids,time=y[,"time"],event=y[,"status"]); write.csv(d,file.path(out,"clinical.csv"),row.names=FALSE)
f <- data.frame(unit=ids,fold=rep(1:10,length.out=length(ids)));write.csv(f,file.path(out,"folds.csv"),row.names=FALSE)
f$fold<-1;write.csv(f,file.path(out,"bad-folds.csv"),row.names=FALSE)
write.csv(d[-1,],file.path(out,"missing-subject.csv"),row.names=FALSE)
z<-d;z$event[1]<-2;write.csv(z,file.path(out,"bad-event.csv"),row.names=FALSE)
