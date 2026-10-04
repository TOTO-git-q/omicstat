# requires: clusterProfiler, enrichit, DOSE, org.Hs.eg.db, GO.db, DESeq2, edgeR, limma, jsonlite, digest
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mdir <- dirname(here); suite <- normalizePath(file.path(mdir,"..",".."))
for (f in c("module_kit.R","calls_check.R","handoff.R","ranked_list.R")) source(file.path(suite,"skills","_shared","scripts",f))
fail <- character()
check <- function(ok,msg) { cat(if (isTRUE(ok)) "PASS: " else "FAIL: ",msg,"\n",sep=""); if (!isTRUE(ok)) fail <<- c(fail,msg) }
reg <- file.path(mdir,"scripts","calls_registry.json"); scripts <- list.files(file.path(mdir,"scripts"),pattern="[.]R$",full.names=TRUE)
check(check_calls(scripts,reg)$ok,"call registry")
check(check_default_drift(reg)$ok,"container formals")
for (nm in c("check_defaults.py","check_flag_docs.py","lint_r.py")) {
 z <- suppressWarnings(system2("python3",shQuote(c(file.path(suite,"tools",nm),if (nm=="lint_r.py") file.path(mdir,"scripts") else mdir)),stdout=TRUE,stderr=TRUE))
 check(is.null(attr(z,"status"))||attr(z,"status")==0L,paste(nm,paste(z,collapse=" | ")))
}
tmp <- Sys.getenv("OMICSTAT_TEST_TMP",file.path(tempdir(),"gsea_smoke")); dir.create(tmp,recursive=TRUE,showWarnings=FALSE)
data(geneList,package="DOSE")
infile <- file.path(tmp,"ranked.csv")
write.csv(data.frame(feature_id=names(geneList),score=unname(geneList)),infile,row.names=FALSE)
entry <- file.path(mdir,"scripts","run_clusterprofiler_gsea.R")
run <- function(args) suppressWarnings(system2("Rscript",shQuote(c(entry,args)),stdout=TRUE,stderr=TRUE))
status <- function(z) attr(z,"status") %||% 0L
base <- c("--ranked",infile,"--ranking-metric","DOSE geneList log2 fold change","--direction","positive means up",
          "--statistic-kind","effect_size","--lfc-type","DOSE geneList logFC as distributed (breast cancer expression data)")
one <- file.path(tmp,"anchor")
z <- run(c(base,"--outdir",one)); check(status(z)==0L,paste("DOSE gseGO anchor run",paste(z,collapse=" | ")))
if (status(z)==0L) {
 tab <- read.csv(file.path(one,"tables","enrichment_full.csv"),check.names=FALSE)
 set.seed(20260925)
 geneList <- geneList[order(-geneList,names(geneList),method="radix")]
 ref <- clusterProfiler::gseGO(geneList=geneList,ont="BP",OrgDb=org.Hs.eg.db::org.Hs.eg.db,keyType="ENTREZID",
   exponent=1,minGSSize=10,maxGSSize=500,pvalueCutoff=1,pAdjustMethod="BH",verbose=FALSE,nPerm=1000,
   method="multilevel",adaptive=FALSE,minPerm=101,maxPerm=1e5,pvalThreshold=0.1)
 exp <- as.data.frame(ref)
 check(nrow(tab)==nrow(exp)&&identical(tab$ID,exp$ID)&&isTRUE(all.equal(tab$NES,exp$NES,tolerance=1e-14))&&
       isTRUE(all.equal(tab$p.adjust,exp$p.adjust,tolerance=1e-14)),
       sprintf("DOSE replay anchor: %d sets, first %s NES %.9g padj %.9g",nrow(exp),exp$ID[1],exp$NES[1],exp$p.adjust[1]))
 check(all(c("pvalue","p.adjust","qvalue","significant_bh05") %in% names(tab)),"full tested table with separate P/q/BH")
 check(file.exists(file.path(one,"figures","gsea_dotplot.figure_spec.json"))&&
       file.exists(file.path(one,"figures","gsea_curve.figure_spec.json")),"figure specifications")
 # S4-F3: PACK F ridge (core-enrichment distribution) and sign-split dot plot
 sg <- jsonlite::fromJSON(file.path(one,"figures","gsea_dotplot_signed.figure_spec.json"))
 rg <- jsonlite::fromJSON(file.path(one,"figures","gsea_ridge.figure_spec.json"))
 npos <- sum(tab$p.adjust<0.05&tab$NES>0); nneg <- sum(tab$p.adjust<0.05&tab$NES<0)
 check(npos>0&&nneg>0&&sg$counts$positive==min(10,npos)&&sg$counts$negative==min(10,nneg)&&
       grepl("split by the sign of NES",sg$caption,fixed=TRUE)&&
       grepl("Positive NES: relative enrichment toward the top of the ranking (highest scores; positive scores: positive means up)",sg$caption,fixed=TRUE)&&
       grepl("negative NES: relative enrichment toward the bottom (lowest scores; negative scores: the opposite of: positive means up)",sg$caption,fixed=TRUE),
       sprintf("S4-F3/S5-R2 sign-split dot plot: %d positive / %d negative significant sets, per-sign selection; caption reads NES as top/bottom relative enrichment",npos,nneg))
 cv <- jsonlite::fromJSON(file.path(one,"figures","gsea_curve.figure_spec.json"))
 check(grepl("Bottom, ranking metric; dashed line, where it crosses zero.",cv$caption,fixed=TRUE),
       "S5-R2 signed ranking: the curve caption names the zero-crossing line the figure draws")
 check(identical(rg$figure_type,"gsea_ridge")&&grepl("core-enrichment (leading-edge) genes",rg$caption,fixed=TRUE)&&
       grepl("DOSE geneList log2 fold change",rg$caption,fixed=TRUE)&&file.exists(file.path(one,"figures","gsea_ridge.png")),
       "S4-F3 ridge plot of core-enrichment scores with metric and threshold in the caption")
 d <- readLines(file.path(one,"draft","methods_results.md"))
 check(any(grepl("The ranking is an effect size (LFC type: DOSE geneList logFC as distributed",d,fixed=TRUE))&&
       any(grepl(sprintf("clusterProfiler %s with enrichit %s",packageVersion("clusterProfiler"),packageVersion("enrichit")),d,fixed=TRUE)),
       "S4-F1 explicit effect-size ranking: LFC type and package versions in the Methods")
 rep <- file.path(tmp,"replay"); z <- run(c("--spec",file.path(one,"provenance","resolved_spec.json"),"--outdir",rep))
 check(status(z)==0L,"resolved spec replay")
 if (status(z)==0L) for (p in c("tables/enrichment_full.csv","figures/gsea_dotplot.png","figures/gsea_curve.png","figures/gsea_dotplot_signed.png","figures/gsea_ridge.png"))
   check(identical(digest::digest(file=file.path(one,p),algo="sha256"),digest::digest(file=file.path(rep,p),algo="sha256")),paste("byte-identical",p))
 if (identical(Sys.getenv("OMICSTAT_WRITE_GOLDEN"),"1"))
   os_golden_write(mdir,one,c("tables/enrichment_full.csv","results/clusterprofiler_gsea_results.json",
                               "figures/gsea_dotplot.figure_spec.json","figures/gsea_curve.figure_spec.json",
                               "figures/gsea_dotplot_signed.figure_spec.json","figures/gsea_ridge.figure_spec.json"))
 g <- os_golden_check(mdir,one); check(g$status %in% c("PASS","SKIP"),paste("golden",g$status,paste(g$problems,collapse=",")))
}
flag <- file.path(tmp,"exploratory")
z <- run(c(base,"--exploratory-fdr","--min-size","20","--outdir",flag))
check(status(z)==0L,"exploratory flag and min-size run")
if (status(z)==0L) {
  ft <- read.csv(file.path(flag,"tables","enrichment_full.csv"),check.names=FALSE)
  check("exploratory_bh25" %in% names(ft) && all(ft$setSize>=20) && nrow(ft)<nrow(tab),"flag effectiveness: BH 0.25 column and size floor")
}
err <- run(c("--ranked",infile,"--outdir",file.path(tmp,"missing")))
check(status(err)!=0L&&any(grepl("OS_MISSING_PARAMETER",err)),"missing metric and direction typed refusal")
err <- run(c(base,"--database","KEGG","--outdir",file.path(tmp,"kegg")))
check(status(err)!=0L&&any(grepl("OS_REFDATA_MISSING",err)),"missing KEGG typed refusal")
err <- run(c("--ranked",infile,"--ranking-metric","LRT F-stat","--direction","unspecified","--outdir",file.path(tmp,"nondirectional")))
check(status(err)!=0L&&any(grepl("OS_RANKING_UNDIRECTIONAL",err)),"nondirectional rank refused")
up <- file.path(tmp,"upstream"); dir.create(file.path(up,"objects"),recursive=TRUE,showWarnings=FALSE)
upfile <- file.path(up,"objects","ranked_list.csv"); write.csv(data.frame(feature_id=names(geneList),symbol="",score=unname(geneList)),upfile,row.names=FALSE)
write_handoff(up,"no-metadata","deseq2-wald","1.1.0",objects=list(ranked_list=list(path=upfile,type="ranked_list")),state=list(contrast="positive means up"))
z <- run(c("--from-run",up,"--outdir",file.path(tmp,"from_run_nometa")))
check(status(z)!=0L&&any(grepl("OS_HANDOFF_MISMATCH: the ranked_list carries no metadata",z,fixed=TRUE)),
      "S4-F1 an upstream ranked_list without metric/direction metadata is refused, never named after its producer")
# S4-F2: one-sided directional ranking is valid; undirectional is refused
oneside <- file.path(tmp,"oneside.csv")
write.csv(data.frame(feature_id=names(geneList),score=abs(unname(geneList))+1e-6*seq_along(geneList)),oneside,row.names=FALSE)
os1 <- file.path(tmp,"oneside")
# S5 R2 regression: the S3 final-verification counterexample (all 12495 scores
# positive, GO CC, sizes 10-30) has sets with negative NES, including a
# BH-significant one; the ranking has a bottom even though no score is negative.
z <- run(c("--ranked",oneside,"--ranking-metric","synthetic one-sided moderated t","--direction","higher in B than A",
           "--ontology","CC","--min-size","10","--max-size","30","--outdir",os1))
check(status(z)==0L,paste("S4-F2 an all-positive single-contrast statistic is accepted",paste(utils::tail(z,2),collapse=" | ")))
if (status(z)==0L) {
  d <- readLines(file.path(os1,"draft","methods_results.md")); dd <- paste(d,collapse=" ")
  ot <- read.csv(file.path(os1,"tables","enrichment_full.csv"),check.names=FALSE)
  oj <- jsonlite::fromJSON(file.path(os1,"results","clusterprofiler_gsea_results.json"))
  neg_sig <- ot$ID[ot$NES<0&ot$p.adjust<0.05]
  ref_row <- ot[ot$ID=="GO:0031082",]
  check(oj$n_negative_scores==0L&&oj$n_positive_scores==12495L&&sum(ot$NES<0)>0L&&length(neg_sig)>0L&&
        nrow(ref_row)==1L&&abs(ref_row$NES-(-2.057091))<5e-7&&abs(ref_row$p.adjust-0.03071103)<5e-9,
        sprintf("S5-R2 all-positive fixture: %d tested, %d negative NES, BH-significant negative %s; GO:0031082 NES %.7g BH %.7g",
                nrow(ot),sum(ot$NES<0),paste(neg_sig,collapse=","),ref_row$NES[1],ref_row$p.adjust[1]))
  check(!grepl("only one end",dd,fixed=TRUE)&&!grepl("cannot be observed",dd,fixed=TRUE)&&
        grepl("NES is read as relative enrichment of a set toward the top (NES > 0, highest scores) or the bottom (NES < 0, lowest scores) of this ranking.",dd,fixed=TRUE)&&
        grepl("All 12495 finite scores are positive, so no gene scores on the negative side of the contrast; the ranking still has a bottom, formed by the smallest scores, and a negative NES marks relative enrichment there. It does not by itself indicate the opposite of: higher in B than A.",dd,fixed=TRUE),
        "S5-R2 Methods: same-sign input still has a bottom end; negative NES is relative enrichment there, not an opposite effect")
  sp1 <- jsonlite::fromJSON(file.path(os1,"figures","gsea_dotplot_signed.figure_spec.json"))
  cv1 <- jsonlite::fromJSON(file.path(os1,"figures","gsea_curve.figure_spec.json"))
  check(sp1$counts$negative==min(10L,length(neg_sig))&&sp1$counts$negative>0L&&
        grepl("negative NES: relative enrichment toward the bottom (smallest scores). All scores are positive, so a negative NES does not by itself indicate the opposite of: higher in B than A.",sp1$caption,fixed=TRUE)&&
        !grepl("negative scores:",sp1$caption,fixed=TRUE)&&!grepl("negative end",sp1$caption,fixed=TRUE),
        sprintf("S5-R2 signed dot plot of the all-positive ranking: %d negative-NES sets shown, caption does not read them as the opposite effect",sp1$counts$negative))
  check(!grepl("crosses zero",cv1$caption,fixed=TRUE)&&grepl("all scores have the same sign, so the metric has no zero crossing and no crossing line is drawn",cv1$caption,fixed=TRUE),
        "S5-R2 curve caption of the all-positive ranking names no zero-crossing line")
  check(grepl(sp1$caption,dd,fixed=TRUE)&&grepl(cv1$caption,dd,fixed=TRUE)&&
        grepl(sprintf("Of %d testable GO sets, %d had BH adjusted P < 0.05.",nrow(ot),sum(ot$p.adjust<0.05)),dd,fixed=TRUE),
        "S5-R2 draft legends equal the figure-spec captions; Results counts equal the table")
}
und <- file.path(tmp,"undirectional"); dir.create(file.path(und,"objects"),recursive=TRUE,showWarnings=FALSE)
file.copy(upfile,file.path(und,"objects","ranked_list.csv"),overwrite=TRUE)
um <- list(schema="omicstat.ranked_list.v1",metric="DESeq2 LRT statistic",statistic="wald_stat",statistic_kind="test_statistic",lfc_type=NA,
           directional=FALSE,contrast="full vs reduced",positive_end="n/a",negative_end="n/a",null_test="zero_effect",universe="all",
           n_ranked=length(geneList),n_excluded_nonfinite=0,n_ties=0,producer="deseq2-lrt",producer_version="1.1.0",id_type="Entrez")
write_handoff(und,"und","deseq2-lrt","1.1.0",objects=list(ranked_list=list(path=file.path(und,"objects","ranked_list.csv"),type="ranked_list")),state=list(ranked_list=um))
z <- run(c("--from-run",und,"--outdir",file.path(tmp,"und_out")))
check(status(z)!=0L&&any(grepl("OS_RANKING_UNDIRECTIONAL",z,fixed=TRUE)),"S4-F2 an undirectional (LRT) ranking from metadata is refused")
z <- run(c("--ranked",infile,"--ranking-metric","x","--direction","y","--statistic-kind","effect_size","--outdir",file.path(tmp,"nolfc")))
check(status(z)!=0L&&any(grepl("OS_MISSING_PARAMETER: an effect-size ranking needs --lfc-type",z,fixed=TRUE)),"S4-F1 an effect-size ranking without its LFC type is refused")
# S4-F1: real producers -> clusterprofiler-gsea (deseq2-wald Wald stat, limma-voom moderated t)
set.seed(11)
gids <- names(geneList)
cnt <- matrix(stats::rnbinom(length(gids)*6,mu=120,size=8),length(gids),6,dimnames=list(gids,paste0("s",1:6)))
cnt[utils::head(gids,300),4:6] <- cnt[utils::head(gids,300),4:6]*3L
write.csv(data.frame(feature_id=gids,cnt,check.names=FALSE),file.path(tmp,"chain_counts.csv"),row.names=FALSE)
write.csv(data.frame(sample=colnames(cnt),condition=rep(c("ctrl","trt"),each=3)),file.path(tmp,"chain_samples.csv"),row.names=FALSE)
producers <- list(`deseq2-wald`=c("run_deseq2_wald.R","--shrinkage","none"),`limma-voom`=c("run_limma_voom.R"))
want <- c(`deseq2-wald`="DESeq2 Wald statistic",`limma-voom`="limma moderated t-statistic")
for (pm in names(producers)) {
  pd <- file.path(tmp,paste0("chain_",pm))
  z <- suppressWarnings(system2("Rscript",shQuote(c(file.path(suite,"skills",pm,"scripts",producers[[pm]][1]),"--counts",file.path(tmp,"chain_counts.csv"),
        "--samples",file.path(tmp,"chain_samples.csv"),"--reference","ctrl","--target","trt",producers[[pm]][-1],"--outdir",pd)),stdout=TRUE,stderr=TRUE))
  check(status(z)==0L,paste("S4-F1 upstream",pm,"run exits 0",paste(utils::tail(z,2),collapse=" | ")))
  if (status(z)!=0L) next
  cd <- file.path(tmp,paste0("chain_gsea_",pm))
  z <- run(c("--from-run",pd,"--outdir",cd))
  check(status(z)==0L,paste("S4-F1",pm,"-> clusterprofiler-gsea --from-run exits 0",paste(utils::tail(z,2),collapse=" | ")))
  if (status(z)!=0L) next
  j <- jsonlite::fromJSON(file.path(cd,"results","clusterprofiler_gsea_results.json"))
  d <- readLines(file.path(cd,"draft","methods_results.md"))
  check(identical(j$ranking_metric,want[[pm]])&&identical(j$direction,"higher expression in trt than in ctrl")&&identical(j$statistic_kind,"test_statistic")&&
        any(grepl(sprintf("The ranking was %s, positive for higher expression in trt than in ctrl.",want[[pm]]),d,fixed=TRUE))&&
        any(grepl("The ranking is a signed test statistic. Contrast: condition: trt vs ctrl",d,fixed=TRUE)),
        sprintf("S4-F1 %s metric, contrast and direction are consumed from the ranked_list metadata (JSON and Methods)",pm))
}
tampered <- file.path(tmp,"chain_deseq2-wald")
if (dir.exists(tampered)) {
  write("tamper",file.path(tampered,"objects","ranked_list.csv"),append=TRUE)
  err <- run(c("--from-run",tampered,"--outdir",file.path(tmp,"tamper")))
  check(status(err)!=0L&&any(grepl("OS_HANDOFF_MISMATCH",err)),"tampered handoff refused")
}
check(!file.exists(file.path(suite,"Rplots.pdf")),"no Rplots.pdf")
if (length(fail)) quit(status=1) else cat("SMOKE PASSED\n")
