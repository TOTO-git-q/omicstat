# F7-F9, limma User's Guide sec 17.3, hash-locked in ANCHOR_REGISTRY.md.
ILLUMINA_SHA <- c(probe="6493d66dabb22fbd11023c5f412482edd972ad222fea3865d530335905cda0ed",
                  control="1ce713157988d8bfb195c93b08c079aa63daf25ae95e817d2bff797e24423ba9",
                  targets="8a52b386e482ba0f686e0b4c57c2fd593621dbfeae9b72f64dc512b26f337ddb")
make_illumina <- function(dir,suite){
  src<-file.path(suite,"acceptance","data",c("limma_IlluminaCaseStudy_probe_profile.txt.gz",
                                            "limma_IlluminaCaseStudy_control_probe_profile.txt.gz",
                                            "limma_IlluminaCaseStudy_Targets.txt"))
  if(!all(file.exists(src)))return(NULL)
  got<-vapply(src,function(p)digest::digest(file=p,algo="sha256"),"")
  if(!identical(unname(got),unname(ILLUMINA_SHA)))stop("OS_ANCHOR_HASH_MISMATCH: Illumina F7-F9")
  dir.create(dir,recursive=TRUE,showWarnings=FALSE)
  x<-limma::read.ilmn(files=src[1],ctrlfiles=src[2],other.columns="Detection")    # guide read.ilmn step (sec 17.3)
  y<-limma::neqc(x)                                                               # guide:6488
  y<-y[rowSums(y$other$Detection<0.05)>=3,]                                       # guide:6497-6498
  targets<-utils::read.delim(src[3])
  mat<-y$E;colnames(mat)<-sprintf("array%02d",seq_len(ncol(mat)))
  samples<-data.frame(sample=colnames(mat),condition=targets$CellType,donor=as.character(targets$Donor))
  utils::write.csv(data.frame(feature_id=rownames(mat),mat,check.names=FALSE),file.path(dir,"matrix.csv"),row.names=FALSE)
  utils::write.csv(samples,file.path(dir,"samples.csv"),row.names=FALSE)
  list(matrix=file.path(dir,"matrix.csv"),samples=file.path(dir,"samples.csv"),n_filtered=nrow(mat),y=y,targets=targets)
}
