# requires: edgeR limma ggplot2 ggrepel patchwork ragg jsonlite digest
# Anchor kinds (S4, S3 F1):
#  PRINTED  Illumina (User's Guide sec 17.3, row 7): the guide's own duplicateCorrelation code
#           (guide:6521-6525) on the guide-filtered 24691 x 12 matrix prints 0.134 (guide:6526);
#  REPLAY   the engine's array route on the same matrix equals that guide code (locked 0.1344848639).
#  PRINTED  Yoruba (User's Guide sec 18.1, row 7b): the guide's OWN code with the guide-era voom
#           span written out (adaptive.span = FALSE; limma NEWS 3.66.0 changed the default,
#           S4_ANCHOR_TRACE.md) reproduces every printed sec 18.1.9 value.
#  REPLAY   Yoruba suite route: the RNA engine runs the guide input (guide:7204-7208 filter,
#           engine filterByExpr made a no-op with --min-count 0) with the locked
#           adaptive.span = TRUE; its computed consensus (both rounds), full topTable and
#           direction summary must equal the guide code run with adaptive.span = TRUE.
here<-dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
mod<-dirname(here);suite<-normalizePath(file.path(mod,"..",".."))
source(file.path(suite,"skills","_shared","scripts","calls_check.R"))
source(file.path(suite,"skills","_shared","scripts","module_kit.R"))
source(file.path(suite,"skills","_shared","scripts","handoff.R"))
source(file.path(here,"fixtures","make_illumina.R"))
source(file.path(here,"fixtures","guide_yoruba.R"))
suppressPackageStartupMessages({library(limma);library(edgeR)})
errors<-character();check<-function(ok,msg){if(isTRUE(ok))cat("PASS:",msg,"\n")else{cat("FAIL:",msg,"\n");errors<<-c(errors,msg)}}
tmp<-file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"limma-dupcor-smoke")
unlink(tmp,recursive=TRUE);dir.create(tmp,recursive=TRUE);oldwd<-setwd(tmp)
entry<-file.path(mod,"scripts","run_limma_dupcor.R")
run<-function(...){o<-suppressWarnings(system2(file.path(R.home("bin"),"Rscript"),c(shQuote(entry),...),stdout=TRUE,stderr=TRUE));list(status=attr(o,"status")%||%0L,out=o)}
sha<-function(p)digest::digest(file=p,algo="sha256")
same<-function(a,b,tol=1e-10)isTRUE(all.equal(unname(a),unname(b),tolerance=tol))
draft<-function(d)paste(readLines(file.path(d,"draft","methods_results.md")),collapse=" ")
cap<-function(d,f)jsonlite::fromJSON(file.path(d,"figures",paste0(f,".figure_spec.json")))$caption
reg<-file.path(mod,"scripts","calls_registry.json")
cc<-check_calls(list.files(file.path(mod,"scripts"),pattern="[.]R$",full.names=TRUE),reg)
check(cc$ok,paste("registered explicit calls",paste(cc$problems,collapse="; ")))
dd<-check_default_drift(reg)
check(dd$ok,paste("locked defaults",paste(dd$problems,collapse="; ")))
for(tool in c("check_defaults.py","check_flag_docs.py","lint_r.py")){
 o<-suppressWarnings(system2("python3",c(shQuote(file.path(suite,"tools",tool)),shQuote(mod)),stdout=TRUE,stderr=TRUE))
 check((attr(o,"status")%||%0L)==0L,paste(tool,paste(o,collapse=" | ")))
}
# ---- Illumina sec 17.3 (array mode, printed consensus) ----
p<-make_illumina(file.path(tmp,"illumina"),suite)
if(is.null(p))cat("SKIP: Illumina F7-F9 absent\n")else{
 base<-c("--mode","array","--matrix",shQuote(p$matrix),"--samples",shQuote(p$samples),
         "--block","donor","--block-description",shQuote("human donor"),"--platform","other",
         "--trend","true","--robust","false","--reference","MS","--target","ML")
 a0<-file.path(tmp,"a0");r<-run(base,"--outdir",shQuote(a0))
 check(r$status==0,paste("Illumina printed-anchor run",paste(utils::tail(r$out,2),collapse=" | ")))
 if(r$status==0){
  j<-jsonlite::fromJSON(file.path(a0,"results","limma_results.json"))
  co<-j$details$consensus_correlation
  check(p$n_filtered==24691L && j$n_tested==24691L,"User's Guide sec 17.3 PRINTED: 24691 expressed probes (guide:6500)")
  gi<-yoruba_guide_lines(suite,"limma-dupcor");ip<-grep("^> dupcor\\$consensus.correlation$",gi)
  pc<-if(length(ip)==1L)as.numeric(sub("^\\[1\\] ","",gi[ip+1L]))else NA_real_          # guide:6526 printed value
  ct<-factor(p$targets$CellType)                                                         # guide:6521
  design_g<-model.matrix(~0+ct);colnames(design_g)<-levels(ct)                           # guide:6522-6523
  dupcor<-duplicateCorrelation(p$y,design_g,block=p$targets$Donor)                       # guide:6524
  check(identical(pc,0.134) && round(dupcor$consensus.correlation,3)==pc,
        sprintf("User's Guide sec 17.3 PRINTED (guide code guide:6521-6525): consensus %.10f prints as 0.134 (guide:6526)",dupcor$consensus.correlation))
  check(same(co,dupcor$consensus.correlation,1e-9) && abs(co-0.1344848639)<1e-9,
        "User's Guide sec 17.3 REPLAY: engine array consensus equals the guide code (~0+ct and ~condition span the same space; locked 0.1344848639)")
  check(j$details$n_blocks==3 && all(unlist(j$details$block_sizes)==4) && j$details$correlation_rounds==1,"3 donor blocks of size 4 and one array correlation round reported")
  txt<-draft(a0)
  check(grepl(sprintf("correlation = %s",formatC(co,digits=6,format="f")),txt,fixed=TRUE) && grepl("The correlated unit was human donor (sample column \"donor\", role correlated_unit): 3 units (3 of size 4)",txt,fixed=TRUE) &&
        grepl("trim = 0.15",txt,fixed=TRUE) && grepl("normalised log2 expression matrix supplied by the user (24691 features",txt,fixed=TRUE) &&
        grepl("trend = TRUE [explicit user setting], robust = FALSE [explicit user setting]",txt,fixed=TRUE) &&
        grepl(sprintf("prior df = %s",trimws(formatC(readRDS(file.path(a0,"objects","fit.rds"))$df.prior,digits=4,format="g"))),txt,fixed=TRUE) &&
        !grepl("edgeR",txt,fixed=TRUE) && grepl("## Figure legends",txt,fixed=TRUE),
        "Methods (array): consensus, block meaning/count/sizes, trim, user matrix, explicit trend/robust, prior df, no edgeR claim")
  fit<-readRDS(file.path(a0,"objects","fit.rds"));check(inherits(fit,"MArrayLM"),"fitted handoff object")
  mc<-utils::read.csv(file.path(a0,"tables","mds_coordinates.csv"))
  mr<-plotMDS(p$y,labels=p$targets$CellType,plot=FALSE)                                   # guide:6502 (plot=FALSE)
  check(same(mc$dim1,mr$x) && same(mc$dim2,mr$y),"REPLAY: array MDS coordinates equal the guide's plotMDS(y) (guide:6502)")
  check(grepl("12 samples",cap(a0,"mds")) && grepl("top 500 features (of 24691)",cap(a0,"mds"),fixed=TRUE) && grepl("shaped by donor",cap(a0,"mds"),fixed=TRUE) &&
        grepl("user-supplied normalised log2 expression",cap(a0,"mds"),fixed=TRUE),"array MDS caption: n, top, input scale, donor shapes")
  a1<-file.path(tmp,"a1");r1<-run("--spec",shQuote(file.path(a0,"provenance","resolved_spec.json")),"--outdir",shQuote(a1))
  check(r1$status==0,"--spec replay")
  if(r1$status==0)for(f in c("tables/feature_table.csv","tables/limma_full.csv","tables/mds_coordinates.csv","figures/volcano.png","figures/md.png","figures/mds.png",
                            "figures/volcano.figure_spec.json","figures/md.figure_spec.json"))check(sha(file.path(a0,f))==sha(file.path(a1,f)),paste("byte-identical replay",f))
  for(f in c("volcano","md","sa_diagnostic","mds")){
   check(file.exists(file.path(a0,"figures",paste0(f,".png")))&&nzchar(cap(a0,f)%||%""),paste(f,"figure and caption"))
  }
  check(!file.exists(file.path(a0,"figures","voom_trend.png")),"array mode draws no voom trend")
  golden<-c("tables/feature_table.csv","tables/limma_full.csv","tables/direction_summary.csv","tables/mds_coordinates.csv","results/limma_results.json",
            "figures/volcano.figure_spec.json","figures/md.figure_spec.json","figures/sa_diagnostic.figure_spec.json","figures/mds.figure_spec.json",
            "draft/methods_results.md")
  if(nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN")))os_golden_write(mod,a0,golden)
  gc<-os_golden_check(mod,a0)
  if(gc$status=="SKIP")cat("SKIP: golden --",gc$reason,"\n")else check(gc$status=="PASS","container golden")
 }
}
# ---- Yoruba sec 18.1 (RNA mode) ----
g<-yoruba_guide_lines(suite,"limma-dupcor")
inp<-yoruba_guide_inputs(suite,g)
if(is.null(inp))cat("SKIP: Yoruba F10 absent\n")else{
 pr<-yoruba_guide_printed(g)
 check(identical(dim(inp$y),c(16918L,86L)),"Yoruba PRINTED: 16918 genes x 86 libraries after the guide filter (guide:7210)")
 gf<-yoruba_guide_fit(inp,adaptive.span=FALSE)
 check(length(pr$consensus)==2L && round(gf$cor1,3)==pr$consensus[1] && round(gf$cor2,3)==pr$consensus[2],
       sprintf("Yoruba PRINTED (guide code, adaptive.span = FALSE): consensus %.7f / %.7f print as 0.446 / 0.446 (guide:7402, :7410)",gf$cor1,gf$cor2))
 check(all(unclass(gf$dt)==pr$dt) && identical(colnames(gf$dt),colnames(pr$dt)),
       "Yoruba PRINTED: summary(decideTests(fit)) for all four coefficients, genderMale 27/16869/22 (guide:7418-7421)")
 cmp<-yoruba_compare_printed_tt(gf$tt,pr$tt)
 check(nrow(pr$tt)==49L && all(cmp),sprintf("Yoruba PRINTED: all 49 topTable rows, IDs/symbols/logFC/AveExpr/t/P/adj.P/B (guide:7423-7473) [%s]",paste(names(cmp)[!cmp],collapse=",")))
 gt<-yoruba_guide_fit(inp,adaptive.span=TRUE)                                             # locked 3.68.5 default span
 cat(sprintf("NOTE: guide code with the locked default adaptive.span = TRUE gives consensus %.7f / %.7f (prints 0.445); the printed 0.446 needs the guide-era span 0.5.\n",gt$cor1,gt$cor2))
 yd<-file.path(tmp,"yoruba_in");dir.create(yd)
 cm<-inp$counts_filtered;storage.mode(cm)<-"integer"
 utils::write.csv(data.frame(feature_id=rownames(cm),cm,check.names=FALSE),file.path(yd,"counts.csv"),row.names=FALSE)
 utils::write.csv(data.frame(sample=inp$Targets$individual,gender=inp$Targets$gender,concentration=paste0("c",inp$Targets$concentration),
                             cellline=inp$Targets$cellline),file.path(yd,"samples.csv"),row.names=FALSE)
 ay<-file.path(tmp,"yoruba")
 ry<-run("--mode","rna","--counts",shQuote(file.path(yd,"counts.csv")),"--samples",shQuote(file.path(yd,"samples.csv")),
         "--condition","gender","--reference","Female","--target","Male","--covariates","concentration",
         "--block","cellline","--block-description",shQuote("HapMap cell line sequenced in more than one library"),
         "--min-count","0","--outdir",shQuote(ay))
 check(ry$status==0,paste("Yoruba RNA engine run (guide input, suite route)",paste(utils::tail(ry$out,2),collapse=" | ")))
 if(ry$status==0){
  j<-jsonlite::fromJSON(file.path(ay,"results","limma_results.json"))
  ft <- read.csv(file.path(ay,"tables/feature_table.csv"))
  biological <- unique(data.frame(cellline=inp$Targets$cellline,gender=inp$Targets$gender))
  check(all(ft$n_group1==sum(biological$gender=="Male")) && all(ft$n_group2==sum(biological$gender=="Female")) && j$n_target==sum(biological$gender=="Male") && j$n_reference==sum(biological$gender=="Female"),"canonical biological replicate counts use independent cell lines, not sequenced libraries")
  check(j$n_tested==16918L && j$details$n_blocks==74L && j$details$correlation_rounds==2,"Yoruba engine: 16918 genes tested (filterByExpr no-op at --min-count 0), 74 cell-line blocks, two rounds")
  check(same(j$details$first_correlation,gt$cor1,1e-9) && same(j$details$consensus_correlation,gt$cor2,1e-9) &&
        abs(j$details$first_correlation-0.4449716)<5e-8 && abs(j$details$consensus_correlation-0.4454514)<5e-8,
        sprintf("Yoruba REPLAY: engine consensus rounds %.7f / %.7f equal the guide code with adaptive.span = TRUE (locked 0.4449716 / 0.4454514)",
                j$details$first_correlation,j$details$consensus_correlation))
  lf<-utils::read.csv(file.path(ay,"tables","limma_full.csv"),row.names=1,check.names=FALSE)
  ref<-gt$full;m<-match(rownames(ref),rownames(lf))
  check(!anyNA(m) && nrow(lf)==nrow(ref),"Yoruba REPLAY: engine and guide code test the same 16918 genes")
  if(!anyNA(m)){
   lf<-lf[m,]
   check(same(lf$logFC,ref$logFC) && same(lf$AveExpr,ref$AveExpr) && same(lf$t,ref$t) && same(lf$P.Value,ref$P.Value) &&
         same(lf$adj.P.Val,ref$adj.P.Val) && same(lf$B,ref$B),
         "Yoruba REPLAY: engine genderMale logFC/AveExpr/t/P/BH/B equal the guide's lmFit(block, correlation) + eBayes for all 16918 genes")
  }
  ds<-utils::read.csv(file.path(ay,"tables","direction_summary.csv"))
  dsv<-as.integer(unlist(ds[1,c("Down","NotSig","Up")]))
  check(identical(dsv,as.integer(unclass(gt$dt)[,"genderMale"])) && identical(dsv,as.integer(pr$dt[,"genderMale"])),
        sprintf("Yoruba: engine direction summary %s equals the replay and the printed genderMale row 27/16869/22 (guide:7418-7421)",paste(dsv,collapse="/")))
  el<-readRDS(file.path(ay,"objects","elist.rds"))
  check(same(el$E,gt$v$E) && same(el$weights,gt$v$weights),"Yoruba REPLAY: hand-off EList (round-2 voom E and weights) equals guide:7406 voom(block, correlation)")
  vt<-utils::read.csv(file.path(ay,"tables","voom_trend_points.csv"))
  check(same(vt$log2_count_size,gt$v$voom.xy$x) && same(vt$sqrt_sd,gt$v$voom.xy$y),"Yoruba REPLAY: voom trend = round-2 voom(save.plot = TRUE) (guide:7406 plot = TRUE)")
  mc<-utils::read.csv(file.path(ay,"tables","mds_coordinates.csv"))
  mr<-plotMDS(cpm(inp$y,log=TRUE),plot=FALSE)
  check(same(mc$dim1,mr$x) && same(mc$dim2,mr$y),"Yoruba MDS coordinates equal plotMDS(cpm(y, log = TRUE)) of the guide's TMM DGEList")
  txt<-draft(ay)
  thr_n<-1/max(hat(model.matrix(~concentration+gender,data=data.frame(concentration=paste0("c",inp$Targets$concentration),gender=inp$Targets$gender))))
  check(grepl(sprintf("and edgeR (v%s)",packageVersion("edgeR")),txt,fixed=TRUE) && grepl("16918 of 16918 genes were retained",txt,fixed=TRUE) &&
        grepl("min.count = 0,",txt,fixed=TRUE) && grepl(sprintf("in at least %s samples",trimws(formatC(thr_n,digits=4,format="g"))),txt,fixed=TRUE) &&
        grepl("TMM normalisation (edgeR normLibSizes",txt,fixed=TRUE) &&
        grepl(sprintf("span %s for 16918 genes) without a block and estimated a consensus correlation of %s",formatC(gt$v$span,digits=4,format="f"),formatC(gt$cor1,digits=6,format="f")),txt,fixed=TRUE) &&
        grepl(sprintf("re-estimated the consensus correlation as %s",formatC(gt$cor2,digits=6,format="f")),txt,fixed=TRUE) &&
        grepl("74 units (62 of size 1, 12 of size 2)",txt,fixed=TRUE) && grepl("trim = 0.15",txt,fixed=TRUE) &&
        grepl("trend = FALSE [RNA-seq preset], robust = FALSE [RNA-seq preset]",txt,fixed=TRUE) &&
        grepl(sprintf("prior df = %s",trimws(formatC(gt$fit$df.prior,digits=4,format="g"))),txt,fixed=TRUE) &&
        grepl(sprintf("The consensus intra-unit correlation was %s across 74 units",formatC(gt$cor2,digits=6,format="f")),txt,fixed=TRUE),
        "Methods (RNA): edgeR version, filterByExpr thresholds, TMM, both voom -> duplicateCorrelation rounds with spans and correlations, block, trim, eBayes preset and prior df")
  for(f in c("volcano","md","voom_trend","mds"))check(file.exists(file.path(ay,"figures",paste0(f,".png")))&&nzchar(cap(ay,f)%||%""),paste("Yoruba",f,"figure and caption"))
  check(grepl(sprintf("one of %d features",nrow(vt)),cap(ay,"voom_trend"),fixed=TRUE) && grepl("86 samples",cap(ay,"voom_trend"),fixed=TRUE) &&
        grepl("86 samples",cap(ay,"mds")) && grepl("log2 CPM (prior count 2)",cap(ay,"mds"),fixed=TRUE) && !grepl("shaped by",cap(ay,"mds"),fixed=TRUE),
        "Yoruba captions: trend n and samples; MDS n and input scale (74 blocks too many for shapes)")
 }
}
# ---- Behaviour fixture (fast): treat / display / validation / hand-off in RNA mode ----
set.seed(11)
m<-matrix(stats::rnbinom(500*8,mu=80,size=5),500,8,dimnames=list(sprintf("g%04d",1:500),sprintf("s%d",1:8)))
m[1:40,5:8]<-m[1:40,5:8]+150L
st<-data.frame(sample=colnames(m),condition=rep(c("A","B"),each=4),donor=rep(paste0("d",1:4),2))
utils::write.csv(data.frame(feature_id=rownames(m),m,check.names=FALSE),file.path(tmp,"counts.csv"),row.names=FALSE)
utils::write.csv(st,file.path(tmp,"samples.csv"),row.names=FALSE)
rna<-c("--mode","rna","--counts",shQuote(file.path(tmp,"counts.csv")),"--samples",shQuote(file.path(tmp,"samples.csv")),
       "--block","donor","--block-description",shQuote("biological donor"),"--reference","A","--target","B")
r0<-run(rna,"--outdir",shQuote(file.path(tmp,"rna0")))
check(r0$status==0,paste("RNA two-round run",paste(utils::tail(r0$out,2),collapse=" | ")))
if(r0$status==0){
 check(file.exists(file.path(tmp,"rna0","objects","elist.rds")),"RNA EList handoff")
 r1<-run(rna,"--min-effect-fc","1.5","--outdir",shQuote(file.path(tmp,"rnatreat")))
 check(r1$status==0&&sha(file.path(tmp,"rna0","tables","feature_table.csv"))!=sha(file.path(tmp,"rnatreat","tables","feature_table.csv")),"treat changes minimum-effect test")
 if(r1$status==0)check(grepl("limma treat (fc = 1.5, lfc = log2(fc) = 0.5850",draft(file.path(tmp,"rnatreat")),fixed=TRUE),"Methods (treat): fc and lfc = log2(fc) reported")
 if(r1$status==0){
  vs<-jsonlite::fromJSON(file.path(tmp,"rnatreat","figures","volcano.figure_spec.json"))
  check(vs$counts$down==0 && length(vs$data$labelled_feature_ids)==2 && grepl("Up to 5 most significant features per direction",vs$caption,fixed=TRUE),"volcano label count is a cap when fewer qualifying genes exist")
 }
 r2<-run(rna,"--display-lfc-filter","1","--outdir",shQuote(file.path(tmp,"rnadisplay")))
 check(r2$status==0&&sha(file.path(tmp,"rna0","tables","feature_table.csv"))==sha(file.path(tmp,"rnadisplay","tables","feature_table.csv")),"display filter leaves inferential table unchanged")
}
# Pre-fit validation and handoff refusals.
st1<-st;st1$donor<-paste0("unique",1:8);utils::write.csv(st1,file.path(tmp,"unique.csv"),row.names=FALSE)
r<-run("--mode","rna","--counts",shQuote(file.path(tmp,"counts.csv")),"--samples",shQuote(file.path(tmp,"unique.csv")),"--block","donor","--block-description","donor","--reference","A","--target","B","--outdir",shQuote(file.path(tmp,"badblock")))
check(r$status!=0&&any(grepl("OS_QC_BLOCKER",r$out)),"unique-only block refused")
st2<-st;st2$donor<-st2$condition;utils::write.csv(st2,file.path(tmp,"spanned.csv"),row.names=FALSE)
r<-run("--mode","rna","--counts",shQuote(file.path(tmp,"counts.csv")),"--samples",shQuote(file.path(tmp,"spanned.csv")),"--block","donor","--block-description","donor","--reference","A","--target","B","--outdir",shQuote(file.path(tmp,"spanned")))
check(r$status!=0&&any(grepl("OS_INVALID_DESIGN: block is spanned",r$out)),"block spanned by design refused")
r<-run(rna,"--block-role","technical_batch","--outdir",shQuote(file.path(tmp,"batch")))
check(r$status!=0&&any(grepl("OS_MISSING_PARAMETER: technical batch",r$out)),"technical batch needs explicit rationale")
if(!is.null(p)){
 r<-run("--mode","array","--matrix",shQuote(p$matrix),"--samples",shQuote(p$samples),"--block","donor","--block-description","donor","--platform","other",
        "--reference","MS","--target","ML","--outdir",shQuote(file.path(tmp,"nopreset")))
 check(r$status!=0&&any(grepl("OS_MISSING_PARAMETER: non-Agilent arrays require explicit --trend and --robust",r$out)),"non-Agilent array without explicit trend/robust refused (owner-pending presets)")
}
up<-file.path(tmp,"upstream");dir.create(file.path(up,"objects"),recursive=TRUE)
invisible(file.copy(file.path(tmp,"counts.csv"),file.path(up,"objects","counts.csv")));invisible(file.copy(file.path(tmp,"samples.csv"),file.path(up,"objects","samples.csv")))
write_handoff(up,"upstream","deseq2-qc","1.0.0",objects=list(count_matrix=list(path=file.path(up,"objects","counts.csv"),type="count_matrix"),sample_table=list(path=file.path(up,"objects","samples.csv"),type="sample_table")))
h<-run("--mode","rna","--from-run",shQuote(up),"--block","donor","--block-description",shQuote("biological donor"),"--reference","A","--target","B","--outdir",shQuote(file.path(tmp,"chained")))
check(h$status==0&&sha(file.path(tmp,"rna0","tables","feature_table.csv"))==sha(file.path(tmp,"chained","tables","feature_table.csv")),"verified from-run chain")
cat("tamper\n",file=file.path(up,"objects","counts.csv"),append=TRUE)
ht<-run("--mode","rna","--from-run",shQuote(up),"--block","donor","--block-description","donor","--reference","A","--target","B","--outdir",shQuote(file.path(tmp,"tampered")))
check(ht$status!=0&&any(grepl("OS_HANDOFF_MISMATCH",ht$out)),"tampered upstream refused")
setwd(oldwd);check(!file.exists(file.path(tmp,"Rplots.pdf")),"no Rplots.pdf")
if(length(errors)){cat(length(errors),"checks FAILED\n");quit(status=1)}else cat("SMOKE PASSED\n")
