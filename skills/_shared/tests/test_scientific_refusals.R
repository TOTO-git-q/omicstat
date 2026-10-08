# Regression tests for scientific guards across native options and input routes.
# requires: SingleCellExperiment SeuratObject rhdf5 jsonlite digest ggplot2
here <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value=TRUE)[1])))
suite <- normalizePath(file.path(here, '../../..'))
for (f in c('module_kit.R','handoff.R','convert.R','sc_backend_io.R','sc_bioc_io.R','ranked_list.R','fig_all.R','fig_mod_m4.R')) source(file.path(suite,'skills/_shared/scripts',f))
tmp <- file.path(Sys.getenv('OMICSTAT_TEST_TMP',tempdir()),'scientific-refusals')
dir.create(tmp,recursive=TRUE,showWarnings=FALSE)
failures <- character()
check <- function(ok,label) { cat(if(isTRUE(ok)) 'PASS:' else 'FAIL:',label,'\n'); if(!isTRUE(ok)) failures <<- c(failures,label) }
error <- function(expr) tryCatch({ force(expr); '' },error=function(e) conditionMessage(e))
# Native CLI labels cannot turn an unsigned statistic into a directional rank.
rank <- file.path(tmp,'rank.csv')
write.csv(data.frame(feature_id=c('1','2'),symbol=c('A','B'),score=c(2,1)),rank,row.names=FALSE)
for (mod in c('fgsea-prerank','limma-camera','clusterprofiler-gsea')) {
 for (metric in c('LRT','F','F statistic','likelihood ratio')) {
  args <- if(mod=='clusterprofiler-gsea') c('--ranked',rank,'--ranking-metric',metric,'--direction','target') else c('--ranked-list',rank,'--rank-metric','other','--metric-name',metric,'--direction','target')
  if(mod=='limma-camera') args <- c(args,'--question','competitive')
  entry <- file.path(suite,'skills',mod,'scripts',paste0('run_',gsub('-','_',mod),'.R'))
  output <- suppressWarnings(system2('Rscript',vapply(c(entry,args,'--outdir',file.path(tmp,paste0(mod,gsub(' ','_',metric)))),shQuote,''),stdout=TRUE,stderr=TRUE))
  check(any(grepl('OS_RANKING_UNDIRECTIONAL',output)),paste(mod,'refuses',metric))
 }
}
meta <- as.list(setNames(rep('fixture',length(OS_RANKED_REQUIRED)),OS_RANKED_REQUIRED))
meta$schema <- OS_RANKED_LIST_SCHEMA;meta$statistic <- 'wald_stat';meta$statistic_kind <- 'test_statistic';meta$directional <- TRUE;meta$metric <- 'Wald statistic';meta$lfc_type <- NA_character_
side <- meta;side$directional <- FALSE
jsonlite::write_json(side,sub('[.]csv$','.meta.json',rank),auto_unbox=TRUE,na='null')
u <- list(objects=list(ranked_list=list(path=rank,type='ranked_list')),state=list(ranked_list=meta))
check(grepl('OS_HANDOFF_MISMATCH',error(os_ranked_list_meta(u))),'sidecar direction conflict is refused')
meta$metric <- 'LRT'
check(grepl('OS_RANKING_UNDIRECTIONAL',error(os_ranked_list_meta_check(meta))),'metadata directional=true cannot legalize LRT')
# Small fixture retains biological sample IDs; only metadata is changed.
sce <- SingleCellExperiment::SingleCellExperiment(assays=list(counts=matrix(1:16,2,dimnames=list(c('A','B'),paste0('c',1:8)))))
sce$cluster <- rep(c('a','b'),4);sce$sample <- rep(paste0('s',1:4),each=2);sce$condition <- rep(c('ctrl','stim'),each=4)
fp <- file.path(tmp,'sce.rds');a <- list(input=fp,ecosystem='bioconductor',`counts-layer`='counts',`cluster-col`='cluster')
state <- list(front_end_ecosystem='bioconductor',qc_complete=TRUE,batch_corrected_lineage=TRUE)
S4Vectors::metadata(sce)$omicstat <- state;saveRDS(sce,fp)
check(grepl('OS_BATCH_CORRECTED_INPUT',error(os_backend_input(a,'counts'))),'backend direct RDS refuses corrected lineage')
check(grepl('OS_BATCH_CORRECTED_INPUT',error(os_bioc_input(a,'scran-cluster'))),'Bioconductor direct RDS refuses corrected lineage')
up <- file.path(tmp,'upstream');dir.create(file.path(up,'objects'),recursive=TRUE,showWarnings=FALSE);file.copy(fp,file.path(up,'objects/sce.rds'),overwrite=TRUE)
write_handoff(up,'fixture','fixture','1',list(sce=list(path=file.path(up,'objects/sce.rds'),type='SingleCellExperiment')),ecosystem='bioconductor',state=state)
b <- a;b$input <- NULL;b[['from-run']] <- up
check(grepl('OS_BATCH_CORRECTED_INPUT',error(os_bioc_input(b,'scran-cluster'))),'Bioconductor from-run refuses corrected lineage')
cv <- os_sc_convert(sce,'SingleCellExperiment','back_end',c(counts='counts'),'cluster')
check(isTRUE(S4Vectors::metadata(cv$object)$omicstat$batch_corrected_lineage),'SCE conversion retains scientific lineage')
state$batch_corrected_lineage <- FALSE;state$front_end_ecosystem <- 'scverse';S4Vectors::metadata(sce)$omicstat <- state;saveRDS(sce,fp)
check(grepl('OS_ECOSYSTEM_MIXED',error(os_backend_input(a,'counts'))),'backend cannot relabel embedded ecosystem')
a$ecosystem <- 'scverse';inp <- os_backend_input(a,'counts')
check(identical(inp$ecosystem,'scverse') && inp$crossing,'neutral backend preserves Python ecosystem')
# Embedding integration does not mark expression as corrected.
state$front_end_ecosystem <- 'bioconductor';state$batch_corrected <- TRUE;S4Vectors::metadata(sce)$omicstat <- state;saveRDS(sce,fp);a$ecosystem <- 'bioconductor'
check(!nzchar(error(os_backend_input(a,'counts'))),'embedding-only correction keeps uncorrected expression usable')
check(!nzchar(error(os_backend_replicates(sce,'sample','condition','ctrl','stim'))),'two biological replicates per condition accepted')
check(grepl('OS_QC_BLOCKER',error(os_backend_replicates(sce[,c(1:2,5:6)],'sample','condition','ctrl','stim'))),'one biological replicate per condition refused')
check(grepl('OS_OWNER_DECISION_PENDING',error(os_handoff_assert_inference_ready(list(module='gsva-score',state=list())))),'GSVA downstream inference cannot bypass owner gate')
# Captions follow native correlation and cutoff controls.
source(file.path(suite,"skills/wgcna-network/scripts/wgcna_network_report.R"))
r <- list(r=matrix(.2,1,1,dimnames=list('MEa','trait')),p=matrix(.3,1,1),samples=8,assoc=data.frame(x=1),genes=20,diagnostics=data.frame(power=1:3,signed_r2=c(.5,.7,.9),mean_k=3:1),native_controls=list(cor=list(method='spearman'),pickSoftThreshold=list(RsquaredCut=.7,corFnc='WGCNA::cor',corOptions=list(use='p',method='spearman'))))
a <- list(power=2,journal='nature',`network-type`='unsigned',`input-scale`='normalized_array',`power-reason`='explicit')
cap <- attr(wgcna_trait(r,a),'os_meta')$caption
check(grepl('spearman correlation',cap,fixed=TRUE) && !grepl('Pearson',cap),'trait caption reports actual correlation')
p <- wgcna_soft(r,a);cap <- attr(p,'os_meta')$caption
check(grepl('R2 = 0.7',cap,fixed=TRUE) && grepl('spearman',cap) && !grepl('Pearson',cap),'soft threshold caption and line follow actual native options')
source(file.path(suite,'skills/_shared/scripts/limma_io.R'))
st <- data.frame(condition=rep(c('ctrl','stim'),each=4),donor=rep(c('d1','d2','d3'),c(4,2,2)))
aa <- list(condition='condition',reference='ctrl',target='stim',`block-role`='correlated_unit')
check(grepl('OS_PSEUDOREPLICATION',error(os_limma_design(matrix(1,2,8),st,aa,'donor'))),'duplicateCorrelation cannot count repeated observations as biological replicates')
st$donor <- rep(c('d1','d2','d3','d4'),each=2)
check(!nzchar(error(os_limma_design(matrix(1,2,8),st,aa,'donor'))),'duplicateCorrelation accepts two independent units per group')
override_path <- file.path(tmp,"override.json")
source(file.path(suite,'skills/limma-camera/scripts/limma_camera_core.R'))
check(grepl('OS_PSEUDOREPLICATION',error(limma_camera_assert_blocks(rep(c('d1','d2'),each=4),st$condition,'ctrl','stim'))),'gene-set repeated-unit test refuses one biological unit per group')
check(!nzchar(error(limma_camera_assert_blocks(st$donor,st$condition,'ctrl','stim'))),'gene-set repeated-unit test accepts two biological units per group')
jsonlite::write_json(list(exprMat="replacement",aucMaxRank=1),override_path,auto_unbox=TRUE)
check(grepl("OS_CONFLICTING_PARAMETERS",error(os_bioc_call(function(exprMat,aucMaxRank) exprMat,override_path,exprMat=matrix(1,2,2),aucMaxRank=2))),"supplementary JSON cannot replace or misreport protected native controls")
if(length(failures)) stop(paste(failures,collapse='; '))
cat('ALL SCIENTIFIC REFUSAL CHECKS PASSED\n')

# UMAP curation state is rejected before neutral inferential backends.
display_upstream <- list(module = "scanpy-purity", state = list(display_only = TRUE),
                         objects = list(adata = list(type = "AnnData")))
display_message <- tryCatch({ os_handoff_assert_uncorrected(display_upstream, "adata"); "" }, error = conditionMessage)
stopifnot(grepl("OS_DISPLAY_ONLY_INPUT", display_message, fixed = TRUE))
cat("PASS: display-only UMAP curation is refused before single-cell inference\n")
