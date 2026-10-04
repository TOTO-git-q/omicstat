# requires: Seurat SeuratObject Matrix jsonlite digest ggplot2 patchwork
script <- normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])); root <- normalizePath(file.path(dirname(script),"..","..","..")); mod <- file.path(root,"skills","seurat-markers")
source(file.path(root,"skills/_shared/scripts/module_kit.R"))
source(file.path(root,"skills/_shared/scripts/handoff.R"))
scratch <- Sys.getenv("OMICSTAT_TEST_TMP","/scratch")
check <- function(ok,label) { if(!isTRUE(ok)) stop(paste("FAIL",label)); cat("PASS",label,"\n") }
run <- function(module,args) { entry <- file.path(root,"skills",module,"scripts",paste0("run_",gsub("-","_",module),".R")); log <- tempfile(tmpdir=scratch); status <- system2("Rscript",c(entry,shQuote(args)),stdout=log,stderr=log); if(status!=0) stop(paste(readLines(log),collapse="\n")); cat(paste(readLines(log),collapse="\n"),"\n") }
# Anchor chain uses the real QC engine, not a fabricated chain state.
check(digest::digest(file=file.path(root,"acceptance/data/pbmc3k_filtered_gene_bc_matrices.tar.gz"),algo="sha256")=="847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5","PACK C PBMC archive hash")
raw <- file.path(scratch,"markers_pbmc"); dir.create(raw,recursive=TRUE,showWarnings=FALSE); utils::untar(file.path(root,"acceptance/data/pbmc3k_filtered_gene_bc_matrices.tar.gz"),exdir=raw)
qc <- file.path(scratch,"markers_qc")
run("seurat-qc",c("--input",file.path(raw,"filtered_gene_bc_matrices/hg19"),"--outdir",qc,"--organism","Homo_sapiens","--feature-type","symbol","--mito-pattern","^MT-","--min-cells","3","--create-min-features","200","--min-features","200","--max-features","2500","--min-counts","0","--max-counts","1000000000","--max-mito","5"))
out <- file.path(scratch,"markers_cluster")
args <- c("--from-run",qc,"--outdir",out,"--normalization","LogNormalize","--n-hvg","2000","--n-pcs","50","--dims","10","--neighbors","20","--umap-neighbors","30","--resolution","0.5","--seed","42")
run("seurat-cluster",args)
upstream <- out; out <- file.path(scratch,"markers_anchor")
run("seurat-markers",c("--from-run",upstream,"--outdir",out,"--seed","42"))
x <- readRDS(file.path(upstream,"objects/seurat.rds")); SeuratObject::Idents(x) <- x$cluster
actual <- read.csv(file.path(out,"tables/markers_full.csv"))
expected <- Seurat::FindAllMarkers(x,only.pos=TRUE,random.seed=42,verbose=FALSE)
check(isTRUE(all.equal(actual,read.csv(text=paste(capture.output(write.csv(expected,row.names=FALSE)),collapse="\n")))),"REPLAY native FindAllMarkers table")
check(ncol(x)==2638L && length(unique(actual$cluster))==9L,"printed PBMC cell/cluster shape")
cat("OBSERVED marker rows",nrow(actual),"above log2FC 1",sum(actual$avg_log2FC>1),"\n")
# Contrast in the tutorial; preserve numeric values without historical rounding tolerance inflation.
contrast <- file.path(scratch,"markers_contrast")
run("seurat-markers",c("--from-run",upstream,"--outdir",contrast,"--mode","contrast","--ident-1","2","--only-pos","false","--seed","42"))
ct <- read.csv(file.path(contrast,"tables/markers_full.csv")); native <- Seurat::FindMarkers(x,ident.1="2",random.seed=42,verbose=FALSE)
check(identical(ct$gene,rownames(native)),"REPLAY tutorial contrast gene identities")
check(isTRUE(all.equal(ct$avg_log2FC,native$avg_log2FC)),"REPLAY contrast native log2FC")
cat("OBSERVED contrast head",paste(head(ct$gene,5),collapse=","),"IL32 FC",ct$avg_log2FC[ct$gene=="IL32"],"\n")
h <- read_handoff(out,expect=list(seurat="Seurat"),front_end_ecosystem="seurat"); check(isTRUE(h$state$seurat$clustered) && length(h$upstream_runs)==3L,"real QC-cluster-marker chain")
if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1") os_golden_write(mod,out,"tables/markers_full.csv")
check(os_golden_check(mod,out)$status=="PASS","main result table golden")

source(file.path(root,"skills/_shared/scripts/calls_check.R"))
check(check_calls(list.files(file.path(mod,"scripts"),pattern="[.]R$",full.names=TRUE),file.path(mod,"scripts/calls_registry.json"))$ok,"registered calls")
check(check_default_drift(file.path(mod,"scripts/calls_registry.json"))$ok,"locked defaults")
check(!file.exists(file.path(root,"Rplots.pdf")),"no device leak")

# Direct native comparisons for the repaired contrast base and both mean.fxn routes.
source(file.path(root,"skills/_shared/scripts/sc_seurat_io.R"))
source(file.path(mod,"scripts/seurat_markers_core.R"))
a <- list(mode="contrast",`ident-1`="2",test="wilcox",`logfc-threshold`=.1,`min-pct`=.01,`only-pos`="false",seed=42,`return-thresh`=.01,`display-lfc-filter`=1,`markers-base`=sprintf("%.17g",exp(1)))
r <- seurat_markers_compute(x,a)
native <- Seurat::FindMarkers(x,ident.1="2",base=exp(1),random.seed=42,verbose=FALSE)
check(isTRUE(all.equal(r$tables$markers_full$avg_logFC,native$avg_logFC)),"contrast base exp(1) native effect")
check(!"avg_log2FC" %in% names(r$tables$markers_full),"native base-dependent column retained")
a[["markers-mean-fxn"]] <- "Matrix::rowMeans"
r <- seurat_markers_compute(x,a)
native <- Seurat::FindMarkers(x,ident.1="2",base=exp(1),mean.fxn=Matrix::rowMeans,random.seed=42,verbose=FALSE)
check(isTRUE(all.equal(r$tables$markers_full$avg_logFC,native$avg_logFC)),"contrast supplied native mean.fxn")
a$mode <- "all"; a[["only-pos"]] <- "true"
r <- seurat_markers_compute(x,a)
native <- Seurat::FindAllMarkers(x,only.pos=TRUE,base=exp(1),mean.fxn=Matrix::rowMeans,random.seed=42,verbose=FALSE)
check(isTRUE(all.equal(r$tables$markers_full,native)),"all supplied native mean.fxn")

for(d in c(out,contrast)) {
 methods <- paste(readLines(file.path(d,"draft/methods_results.md")),collapse="\n")
 check(all(vapply(c("native wilcox test","logfc.threshold=0.1","min.pct=0.01","Fold-change base=2","Bonferroni correction over all features","delegates the Wilcoxon test to presto","Bonferroni-adjusted P (p_val_adj)"),grepl,logical(1),x=methods,fixed=TRUE)),"resolved Methods/test/prefilters/Bonferroni both routes")
}
