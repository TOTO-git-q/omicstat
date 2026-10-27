# Entirely invented independent software fixture. No patient data or copied source dataset.
a <- commandArgs(trailingOnly = TRUE); out <- a[1]; training <- a[2]
if (dir.exists(out)) stop("use a new fixture directory")
dir.create(out, recursive = TRUE)
beta <- utils::read.csv(file.path(training, "tables", "coefficients.csv"), check.names = FALSE)
seed <- 19022L; set.seed(seed); n <- 240L
ids <- sprintf("B4_invented_validation_%04d", seq_len(n))
E <- matrix(stats::rnorm(nrow(beta)*n), nrow=nrow(beta), dimnames=list(beta$gene,ids))
lp <- as.numeric(t(E) %*% beta$coefficient)
event_time <- stats::rexp(n, rate=.08*exp(lp)); censor <- stats::runif(n,2,30)
observed <- pmin(event_time,censor); event <- as.integer(event_time<=censor)
extra <- matrix(stats::rnorm(100*n,8,1),nrow=100,dimnames=list(paste0("B4NOISE",seq_len(100)),ids))
E <- rbind(E,extra)
utils::write.csv(data.frame(feature_id=rownames(E),E,check.names=FALSE),file.path(out,"expression.csv"),row.names=FALSE)
utils::write.csv(data.frame(sample=ids,condition=rep(c("A","B"),length.out=n)),file.path(out,"samples.csv"),row.names=FALSE)
utils::write.csv(data.frame(unit=ids,time=observed,event=event),file.path(out,"clinical.csv"),row.names=FALSE)
cat("Generated independent invented subjects:",n,"; observed events:",sum(event),"; no patient data.\n")
