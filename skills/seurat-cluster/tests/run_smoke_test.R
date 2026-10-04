# requires: Seurat SeuratObject Matrix jsonlite digest ggplot2 patchwork
script <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])); root <- normalizePath(file.path(dirname(script),"..","..","..")); mod <- file.path(root,"skills","seurat-cluster")
source(file.path(root,"skills/_shared/scripts/module_kit.R"))
source(file.path(root,"skills/_shared/scripts/handoff.R"))
scratch <- Sys.getenv("OMICSTAT_TEST_TMP","/scratch")
check <- function(ok,label) { if(!isTRUE(ok)) stop(paste("FAIL",label)); cat("PASS",label,"\n") }
run <- function(module,args) { entry <- file.path(root,"skills",module,"scripts",paste0("run_",gsub("-","_",module),".R")); log <- tempfile(tmpdir=scratch); status <- system2("Rscript",c(entry,shQuote(args)),stdout=log,stderr=log); if(status!=0) stop(paste(readLines(log),collapse="\n")); cat(paste(readLines(log),collapse="\n"),"\n") }
# Anchor chain uses the real QC engine, not a fabricated chain state.
raw <- file.path(scratch,"cluster_pbmc"); dir.create(raw,recursive=TRUE,showWarnings=FALSE); utils::untar(file.path(root,"acceptance/data/pbmc3k_filtered_gene_bc_matrices.tar.gz"),exdir=raw)
qc <- file.path(scratch,"cluster_qc")
run("seurat-qc",c("--input",file.path(raw,"filtered_gene_bc_matrices/hg19"),"--outdir",qc,"--organism","Homo_sapiens","--feature-type","symbol","--mito-pattern","^MT-","--min-cells","3","--create-min-features","200","--min-features","200","--max-features","2500","--min-counts","0","--max-counts","1000000000","--max-mito","5"))
out <- file.path(scratch,"cluster_anchor")
args <- c("--from-run",qc,"--outdir",out,"--normalization","LogNormalize","--n-hvg","2000","--n-pcs","50","--dims","10","--neighbors","20","--umap-neighbors","30","--resolution","0.5","--seed","42")
run("seurat-cluster",args)
x <- readRDS(file.path(out,"objects/seurat.rds"))
check(ncol(x)==2638L,"PRINTED PBMC 2638 graph nodes")
check(length(unique(x$cluster))==9L,"PRINTED PBMC nine communities")
check((length(x@graphs$omic_snn@x)-ncol(x))/2==95927L,"PRINTED PBMC 95927 graph edges")
check(length(SeuratObject::VariableFeatures(x))==2000L,"tutorial 2000 HVGs")
check(nrow(x[["umap"]])==2638L && ncol(x[["pca"]])==50L,"native reduction shape")
cat("OBSERVED communities",length(unique(x$cluster)),"first five",paste(head(as.character(x$cluster),5),collapse=","),"SNN nonzero",length(x@graphs$omic_snn@x),"\n")
# Independent official-code replay verifies native package results under locked dependencies.
y <- readRDS(file.path(qc,"objects/seurat.rds")); y <- Seurat::NormalizeData(y,verbose=FALSE); y <- Seurat::FindVariableFeatures(y,selection.method="vst",nfeatures=2000,verbose=FALSE); y <- Seurat::ScaleData(y,features=SeuratObject::VariableFeatures(y),verbose=FALSE); y <- Seurat::RunPCA(y,npcs=50,seed.use=42,verbose=FALSE); y <- Seurat::FindNeighbors(y,dims=1:10,verbose=FALSE); y <- Seurat::FindClusters(y,resolution=0.5,random.seed=42,verbose=FALSE)
check(identical(as.character(x$cluster),as.character(SeuratObject::Idents(y))),"REPLAY native community identities")
check(isTRUE(all.equal(SeuratObject::Embeddings(x[["pca"]]),SeuratObject::Embeddings(y[["pca"]]))),"REPLAY PCA")
h <- read_handoff(out,expect=list(seurat="Seurat"),front_end_ecosystem="seurat"); check(isTRUE(h$state$seurat$clustered),"from-run chain state")
paths <- c("tables/clusters.csv","tables/hvg.csv","tables/pca_stdev.csv")
if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1") os_golden_write(mod,out,paths)
check(os_golden_check(mod,out)$status=="PASS","main tables golden")

source(file.path(mod,"tests/run_binding_test.R"))
