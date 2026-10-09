# requires: AUCell GSEABase SingleCellExperiment scuttle data.table jsonlite digest ggplot2
.this<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]));.module<-dirname(dirname(.this));suite<-dirname(dirname(.module))
source(file.path(suite,"skills/_shared/scripts/module_kit.R"));source(file.path(.module,"tests/fixtures/make_aucell_brain.R"))
work<-file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"aucell-score-smoke");dir.create(work,recursive=TRUE,showWarnings=FALSE)
check<-function(x,label){stopifnot(isTRUE(x));cat("PASS",label,"\n")}
mat<-make_aucell_brain(suite);set.seed(333);mat<-mat[sample(rownames(mat),5000),]
check(identical(dim(mat),c(5000L,3005L)),"AUCell vignette printed 5000 x 3005")
# Preserve official gene sampling; use 120 cells for engine smoke.
mat<-mat[,1:120];sce<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=mat));sce<-scuttle::logNormCounts(sce)
sce$cluster<-rep(c("first","second"),each=60)
source(file.path(suite,"skills/_shared/scripts/handoff.R"));up<-file.path(work,"upstream");dir.create(file.path(up,"objects"),recursive=TRUE,showWarnings=FALSE)
state<-list(qc_complete=TRUE,normalized=TRUE,front_end_ecosystem="bioconductor");S4Vectors::metadata(sce)$omicstat<-state
saveRDS(sce,file.path(up,"objects/sce.rds"));write_handoff(up,"anchor","scran-cluster","1.0.0",objects=list(sce=list(path=file.path(up,"objects/sce.rds"),type="SingleCellExperiment")),ecosystem="bioconductor",state=state)
decl <- c("--sets-file",system.file("examples","geneSignatures.gmt",package="AUCell"),"--sets-source","AUCell GPL-3 bundled example","--sets-licence","GPL-3","--accept-licence","user-permitted")
out<-file.path(work,"anchor");log<-file.path(work,"anchor.log");entry<-file.path(.module,"scripts/run_aucell_score.R")
st<-system2("Rscript",c(shQuote(entry),shQuote(c(decl,"--from-run",up,"--cluster-col","cluster","--assay","counts","--outdir",out))),stdout=log,stderr=log)
if(st!=0)cat(readLines(log),sep="\n");check(st==0,"normalized SCE from-run scoring")
sets<-GSEABase::getGmt(system.file("examples","geneSignatures.gmt",package="AUCell"))
set.seed(333);rankings<-AUCell::AUCell_buildRankings(mat,plotStats=FALSE,BPPARAM=BiocParallel::SerialParam(),verbose=FALSE)
auc<-AUCell::AUCell_calcAUC(sets,rankings,nCores=1,aucMaxRank=250,normAUC=TRUE,verbose=FALSE)
native<-readRDS(file.path(out,"objects/aucell.rds"));check(identical(AUCell::getAUC(native),AUCell::getAUC(auc)),"official buildRankings/calcAUC replay")
check(ncol(AUCell::getAUC(native))==120 && all(is.finite(AUCell::getAUC(native))),"finite native AUC shape")
anchor_summary <- jsonlite::read_json(file.path(out,"results/analysis_summary.json"))
check(anchor_summary$n_gene_sets==nrow(AUCell::getAUC(native)) && anchor_summary$n_input_gene_sets==length(sets) && anchor_summary$n_gene_sets < anchor_summary$n_input_gene_sets,"summary distinguishes scored sets from loaded sets excluded by AUCell")
# Missing/unapproved references refuse with required typed error.
bad<-file.path(work,"unapproved.gmt");writeLines("KEGG\tblocked\tgene",bad);badlog<-file.path(work,"refused.log")
st<-system2("Rscript",c(shQuote(entry),shQuote(c("--from-run",up,"--cluster-col","cluster","--assay","counts","--sets-file",bad,"--sets-source","KEGG","--sets-licence","user-declared","--accept-licence","user-permitted","--outdir",file.path(work,"refused")))),stdout=badlog,stderr=badlog)
check(st!=0 && any(grepl("OS_REFDATA_MISSING",readLines(badlog))),"reference licence gate")
paths<-c("tables/scores.csv","tables/sets_table.csv")
if(Sys.getenv("OMICSTAT_WRITE_GOLDEN")=="1")os_golden_write(.module,out,paths)
check(os_golden_check(.module,out)$status=="PASS","golden")

if(identical(Sys.getenv("OMICSTAT_TEST_H5AD"),"1")) {
 source(file.path(suite,"skills/_shared/scripts/convert.R"))
 hp<-file.path(work,"input.h5ad")
 cv<-os_sc_convert(sce,to="AnnData",consumer="back_end",layers=c(counts="counts",logcounts="logcounts"),cluster_col="cluster",x_role="logcounts",file=hp)
 ann<-file.path(work,"anndata");alog<-file.path(work,"anndata.log")
 st<-system2("Rscript",c(shQuote(entry),shQuote(c(decl,"--input",hp,"--cluster-col","cluster","--assay","counts","--counts-layer","counts","--logcounts-layer","X","--outdir",ann))),stdout=alog,stderr=alog)
 if(st!=0)cat(readLines(alog),sep="\n");check(st==0,"non-root offline h5ad scoring")
 check(identical(digest::digest(file=file.path(out,"tables/scores.csv"),algo="sha256"),digest::digest(file=file.path(ann,"tables/scores.csv"),algo="sha256")),"AnnData scores equal existing golden result")
}

# Two permitted custom sets, scored through the real CLI and independently replayed.
custom <- file.path(work,"custom.gmt")
writeLines(c(paste(c("user_A","user-derived",rownames(mat)[1:50]),collapse="\t"),paste(c("user_B","user-derived",rownames(mat)[101:160]),collapse="\t")),custom)
co <- file.path(work,"custom")
args <- c("--from-run",up,"--cluster-col","cluster","--assay","counts","--sets-file",custom,"--sets-source","user-derived brain subsets","--sets-licence","user permission","--accept-licence","user-permitted","--outdir",co)
st <- system2("Rscript",c(shQuote(entry),shQuote(args)),stdout=file.path(work,"custom.log"),stderr=file.path(work,"custom.log"));check(st==0,"permitted custom GMT CLI")
set.seed(333);rn <- AUCell::AUCell_buildRankings(mat,plotStats=FALSE,BPPARAM=BiocParallel::SerialParam(),verbose=FALSE)
ac <- AUCell::AUCell_calcAUC(GSEABase::getGmt(custom),rn,nCores=1,aucMaxRank=250,normAUC=TRUE,verbose=FALSE)
check(identical(AUCell::getAUC(readRDS(file.path(co,"objects/aucell.rds"))),AUCell::getAUC(ac)),"two custom sets native AUC parity")
check(any(grepl("user-derived brain subsets",readLines(file.path(co,"draft/methods_results.md")),fixed=TRUE)),"custom source Methods")
missing_ack <- args[-c(match("--accept-licence",args),match("--accept-licence",args)+1)]
st <- system2("Rscript",c(shQuote(entry),shQuote(missing_ack)),stdout=file.path(work,"missing_ack.log"),stderr=file.path(work,"missing_ack.log"));check(st!=0,"required licence acknowledgement")

summary <- jsonlite::read_json(file.path(co,"results/analysis_summary.json"))
check(summary$n_gene_sets==nrow(AUCell::getAUC(ac)) && summary$n_cells==ncol(AUCell::getAUC(ac)),"machine-readable scored-set and cell counts match native AUC output")

# ---- user-supplied gene sets through the provenance contract (CONVENTIONS "User-supplied gene-set collections") ----
# A synthetic PanglaoDB/KEGG-like GMT from anchor genes: the undeclared name gate above
# still refuses KEGG; the same kind of file declared with provenance is accepted and recorded.
source(file.path(suite,"skills/_shared/scripts/user_genesets.R")); source(file.path(suite,"skills/_shared/tests/user_genesets_testkit.R"))
runz <- function(a) suppressWarnings(system2("Rscript",c(shQuote(entry),shQuote(a)),stdout=TRUE,stderr=TRUE))
ugs_sets <- ugs_kegg_like_sets(rownames(mat)[1:300],rownames(mat)[-(1:300)])
ugs <- ugs_fixture(file.path(work,"user_sets"),ugs_sets,"SYMBOL")
ubase <- c("--from-run",up,"--cluster-col","cluster","--assay","counts","--sets-file",ugs$gmt,"--sets-source","KEGG REST","--sets-licence","KEGG academic terms",
           "--accept-licence","user-permitted","--feature-id-type","SYMBOL")
uo <- file.path(work,"user_anchor")
z <- runz(c(ubase,"--gene-sets-provenance",ugs$prov,"--outdir",uo)); check(is.null(attr(z,"status")),"user: declared KEGG-like GMT accepted (name gate lifted for declared files)")
uauc <- AUCell::AUCell_calcAUC(GSEABase::getGmt(ugs$gmt),rn,nCores=1,aucMaxRank=250,normAUC=TRUE,verbose=FALSE)
check(identical(AUCell::getAUC(readRDS(file.path(uo,"objects/aucell.rds"))),AUCell::getAUC(uauc)),"user: native AUC parity on the user sets")
ugs_check_recorded(check,uo,"user AUCell",length(ugs_sets))
ugs_refused(check,runz(c(ubase[-length(ubase)],"ENTREZID","--gene-sets-provenance",ugs$prov,"--outdir",file.path(work,"user_idtype"))),"OS_GENE_SET_ID_MISMATCH","user: gene-set SYMBOL vs --feature-id-type ENTREZID")
ugs_refused(check,runz(c(ubase,"--gene-sets-provenance",ugs$bad_sha,"--outdir",file.path(work,"user_sha"))),"OS_REFDATA_MISMATCH","user: sha256 differing from provenance")
lowb <- ubase; lowb[match("--sets-file",lowb)+1] <- ugs$low
ugs_refused(check,runz(c(lowb,"--gene-sets-provenance",ugs$low_prov,"--outdir",file.path(work,"user_low"))),"OS_GENE_SET_LOW_OVERLAP","user: under 10% overlap with the features")
ugs_refused(check,runz(c(ubase,"--outdir",file.path(work,"user_feature_only"))),"OS_CONFLICTING_PARAMETERS","user: --feature-id-type without a declared contract")
