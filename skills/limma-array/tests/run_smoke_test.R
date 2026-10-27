# requires: limma ggplot2 ggrepel patchwork ragg jsonlite digest
# Anchors (S4): PRINTED = value printed in limma User's Guide 17.4, asserted
# from the guide's own code (tests/guide_17_4.R); REPLAY = the engine on the
# guide's normalized data equals the guide code run in this session.
here<-dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
mod<-dirname(here);suite<-normalizePath(file.path(mod,"..",".."))
source(file.path(suite,"skills","_shared","scripts","calls_check.R"))
source(file.path(suite,"skills","_shared","scripts","module_kit.R"))
source(file.path(suite,"skills","_shared","scripts","handoff.R"))
source(file.path(here,"guide_17_4.R"))
errors<-character();check<-function(ok,msg){if(isTRUE(ok))cat("PASS:",msg,"\n")else{cat("FAIL:",msg,"\n");errors<<-c(errors,msg)}}
tmp<-file.path(Sys.getenv("OMICSTAT_TEST_TMP",tempdir()),"limma-array-smoke")
unlink(tmp,recursive=TRUE);dir.create(tmp,recursive=TRUE);oldwd<-setwd(tmp)
entry<-file.path(mod,"scripts","run_limma_array.R")
run<-function(...){o<-suppressWarnings(system2(file.path(R.home("bin"),"Rscript"),c(shQuote(entry),...),stdout=TRUE,stderr=TRUE));list(status=attr(o,"status")%||%0L,out=o)}
sha<-function(p)digest::digest(file=p,algo="sha256")
reg<-file.path(mod,"scripts","calls_registry.json")
cc<-check_calls(list.files(file.path(mod,"scripts"),pattern="[.]R$",full.names=TRUE),reg)
check(cc$ok,paste("calls explicit",paste(cc$problems,collapse="; ")))
check(check_default_drift(reg)$ok,"locked default drift")
for(tool in c("check_defaults.py","check_flag_docs.py","lint_r.py")){
 o<-suppressWarnings(system2("python3",c(shQuote(file.path(suite,"tools",tool)),shQuote(mod)),stdout=TRUE,stderr=TRUE))
 check((attr(o,"status")%||%0L)==0L,paste(tool,paste(o,collapse=" | ")))
}
# Annotation package of 17.4.4 through the acceptance layer only.
annot<-FALSE
ae<-tryCatch(list(os_acceptance_entry(suite,"RnAgilentDesign028282.db"),os_acceptance_entry(suite,"org.Rn.eg.db")),
             error=function(e){check(FALSE,conditionMessage(e));list(NULL,NULL)})
if(!is.null(ae[[1]])&&!is.null(ae[[2]])&&identical(ae[[1]]$mode,"installed")&&identical(ae[[2]]$mode,"installed")){
 os_acceptance_lib(suite);annot<-requireNamespace("RnAgilentDesign028282.db",quietly=TRUE)
}
g<-gse33005_guide(file.path(tmp,"guide"),suite,annotate=annot)
if(is.null(g))cat("SKIP: GSE33005 F5/F6 absent\n")else{
 g174_check_raw_printed(g,check)
 p<-gse33005_engine_inputs(g,file.path(tmp,"fixture"))
 guide_rows<-g$NotControl&g$IsExpr
 base<-c("--matrix",shQuote(p$matrix),"--samples",shQuote(p$samples),"--control-ids",shQuote(p$controls),
         "--above-background",shQuote(p$background),"--background-k","4","--platform","agilent","--reference","saline","--target","corn10","--keep-other-levels")
 PRE<-"normexp background correction followed by quantile normalization between arrays (limma backgroundCorrect and normalizeBetweenArrays)"
 a0args<-c(base,"--probe-annotation",shQuote(p$annotation),"--preprocessing",shQuote(PRE))
 a0<-file.path(tmp,"a0");r<-run(a0args,"--outdir",shQuote(a0))
 check(r$status==0,paste("GSE33005 full-data engine run",paste(utils::tail(r$out,2),collapse=" | ")))
 if(r$status==0){
  ft<-utils::read.csv(file.path(a0,"tables","feature_table.csv"),stringsAsFactors=FALSE)
  check(nrow(ft)==sum(guide_rows)&&g174_compare_engine(a0,g$partial$tt,p$feature_id[guide_rows]),
        sprintf("REPLAY 17.4 (guide filter minus NoSymbol, %d probes, ~Treatment 4 levels, eBayes trend/robust): engine fit logFC/AveExpr/t/P/adj.P/B equal guide code (tol 1e-10), feature table at its 10 printed digits",sum(guide_rows)))
  ds<-utils::read.csv(file.path(a0,"tables","direction_summary.csv"))
  gd<-g$partial$decide[,"Treatment10 ml/kg corn oil"]
  check(ds$coefficient=="conditioncorn10"&&ds$Down==gd[["Down"]]&&ds$NotSig==gd[["NotSig"]]&&ds$Up==gd[["Up"]],
        sprintf("REPLAY 17.4 direction summary 10 ml/kg vs saline = guide decideTests (Down %d / NotSig %d / Up %d)",gd[["Down"]],gd[["NotSig"]],gd[["Up"]]))
  check(all(ft$n_group1==5)&&all(ft$n_group2==5),"corn10 vs saline: five arrays per group, corn2/corn5 arrays kept in the design")
  # F3: explicit probe annotation, original IDs, unmapped marked.
  fa0<-utils::read.csv(file.path(a0,"tables","feature_annotation.csv"),stringsAsFactors=FALSE,na.strings="NA")
  full0<-utils::read.csv(file.path(a0,"tables","limma_full.csv"),stringsAsFactors=FALSE,check.names=FALSE)
  pa<-utils::read.csv(p$annotation,stringsAsFactors=FALSE)
  mapped<-fa0$feature_id[fa0$annotation_status=="mapped"]
  check(nrow(fa0)==nrow(ft)&&setequal(fa0$feature_id,ft$feature_id)&&all(ft$feature_id%in%p$feature_id)&&
        all(fa0$annotation_status%in%c("mapped","unmapped"))&&all(fa0$symbol[fa0$annotation_status=="unmapped"]%in%c("",NA))&&
        setequal(mapped,intersect(pa$feature_id[!is.na(pa$symbol)],ft$feature_id)),
        sprintf("F3 feature_annotation.csv: one row per tested feature, original ProbeName IDs, %d mapped / %d unmapped marked",length(mapped),sum(fa0$annotation_status=="unmapped")))
  top_id<-p$feature_id[28763]
  check(top_id=="A_44_P552452"&&ft$symbol[ft$feature_id==top_id]=="RT1-Bb"&&
        all(c("symbol","entrez","annotation_status","probe_ids","probe_name")%in%names(full0))&&
        full0$entrez[full0[[1]]==top_id]==309622,
        "F3 symbol/Entrez carried into feature_table and limma_full (A_44_P552452 -> RT1-Bb, 309622)")
  # F2: Methods state the operations of this run.
  md0<-paste(readLines(file.path(a0,"draft","methods_results.md")),collapse=" ")
  nctl<-length(utils::read.csv(p$controls)$feature_id)
  f2<-c(sprintf("%s control probes listed in the control-ID file (controls.csv) were removed",format(nctl,big.mark=",")),
        "at least k = 4 of 19 arrays",sprintf("%s of 44,254 input probes were retained",format(nrow(ft),big.mark=",")),
        "No technical averaging was applied","contained all 4 levels of condition",
        "trend = TRUE and robust = TRUE (registered Agilent preset)",paste0("as declared by the user (performed upstream, not verified by this module): ",PRE),
        "Down / NotSig / Up",sprintf("%d were not significant",ds$NotSig),sprintf("%s of %s tested features mapped to one symbol",format(length(mapped),big.mark=","),format(nrow(ft),big.mark=",")))
  hit<-vapply(f2,function(z)grepl(z,md0,fixed=TRUE),TRUE)
  check(all(hit),paste("F2 Methods report controls, k, retention, averaging, design levels, trend/robust source, declared preprocessing, direction summary, annotation; missing:",paste(f2[!hit],collapse=" | ")))
  # F4: every auxiliary input is hashed.
  pv<-jsonlite::fromJSON(file.path(a0,"provenance","provenance.json"))
  auxp<-c(control_ids=p$controls,above_background=p$background,probe_annotation=p$annotation,matrix=p$matrix,samples=p$samples)
  check(setequal(names(pv$inputs),names(auxp))&&all(vapply(names(auxp),function(k)identical(pv$inputs[[k]]$sha256,sha(auxp[[k]])),TRUE)),
        "F4 provenance inputs hash matrix, samples, control IDs, above-background and probe annotation")
  c2<-file.path(tmp,"controls_reordered.csv");cc0<-utils::read.csv(p$controls,stringsAsFactors=FALSE)
  utils::write.csv(cc0[rev(seq_len(nrow(cc0))),,drop=FALSE],c2,row.names=FALSE)
  rc<-run(sub(p$controls,c2,a0args,fixed=TRUE),"--outdir",shQuote(file.path(tmp,"aux_changed")))
  pv2<-if(rc$status==0)jsonlite::fromJSON(file.path(tmp,"aux_changed","provenance","provenance.json"))else NULL
  check(rc$status==0&&sha(file.path(a0,"tables","feature_table.csv"))==sha(file.path(tmp,"aux_changed","tables","feature_table.csv"))&&
        pv2$inputs$control_ids$sha256==sha(c2)&&pv2$inputs$control_ids$sha256!=pv$inputs$control_ids$sha256&&
        pv2$inputs$matrix$sha256==pv$inputs$matrix$sha256,
        "F4 a changed control-ID file (same IDs, other order) is detected by its provenance hash")
  two<-run(base[base!="--keep-other-levels"],"--outdir",shQuote(file.path(tmp,"twolevel")))
  check(two$status!=0&&any(grepl("OS_INVALID_DESIGN: condition has 4 levels",two$out)),"more than two levels refused unless --keep-other-levels")
  a1<-file.path(tmp,"a1");r1<-run("--spec",shQuote(file.path(a0,"provenance","resolved_spec.json")),"--outdir",shQuote(a1))
  check(r1$status==0,"--spec replay")
  if(r1$status==0)for(f in c("tables/feature_table.csv","tables/limma_full.csv","tables/direction_summary.csv","figures/volcano.png","figures/md.png","figures/volcano.figure_spec.json","figures/md.figure_spec.json"))check(sha(file.path(a0,f))==sha(file.path(a1,f)),paste("byte-identical replay",f))
  ad<-file.path(tmp,"display");rd<-run(a0args,"--display-lfc-filter","1","--outdir",shQuote(ad))
  check(rd$status==0&&sha(file.path(a0,"tables","feature_table.csv"))==sha(file.path(ad,"tables","feature_table.csv"))&&file.exists(file.path(ad,"tables","display_filtered.csv")),"display filter keeps full table")
  at<-file.path(tmp,"treat");rt<-run(base,"--min-effect-fc","1.5","--outdir",shQuote(at))
  check(rt$status==0&&sha(file.path(a0,"tables","feature_table.csv"))!=sha(file.path(at,"tables","feature_table.csv")),"minimum-effect treat changes test")
  ar<-file.path(tmp,"override");rr<-run(base,"--trend","false","--robust","false","--outdir",shQuote(ar))
  check(rr$status==0&&sha(file.path(a0,"tables","feature_table.csv"))!=sha(file.path(ar,"tables","feature_table.csv")),"Agilent trend/robust override is effective")
  if(rr$status==0){
   mdo<-paste(readLines(file.path(ar,"draft","methods_results.md")),collapse=" ")
   check(grepl("trend = FALSE and robust = FALSE (chosen explicitly by the user)",mdo,fixed=TRUE)&&grepl("were not stated to this module",mdo,fixed=TRUE)&&
         grepl("No probe annotation was supplied",mdo,fixed=TRUE),"F2 Methods: user override, preprocessing not stated, no annotation")
  }
  dc<-run(base[!base%in%c("--control-ids",shQuote(p$controls))],"--controls-removed","--outdir",shQuote(file.path(tmp,"declared")))
  check(dc$status==0&&grepl("declared free of control probes (--controls-removed); no control probes were removed",paste(readLines(file.path(tmp,"declared","draft","methods_results.md")),collapse=" "),fixed=TRUE)&&
        !"control_ids"%in%names(jsonlite::fromJSON(file.path(tmp,"declared","provenance","provenance.json"))$inputs),
        "F2 Methods report a declared (not performed) control removal; no control file is hashed")
  b2<-file.path(tmp,"background2");r2<-run(base[!base%in%c("4")],"--outdir",shQuote(b2))
  # Above call intentionally lacks k; typed refusal proves the pair requirement.
  check(r2$status!=0&&any(grepl("OS_MISSING_PARAMETER",r2$out)),"background evidence requires explicit k")
  bk<-sub("^4$","5",base)
  kb<-run(bk,"--outdir",shQuote(file.path(tmp,"k5")))
  if(kb$status==0){
    f5<-utils::read.csv(file.path(tmp,"k5","tables","feature_table.csv"))
    check(nrow(f5)<nrow(ft),"background-k changes the retained probe set")
  }else check(FALSE,"background-k=5 run")
  # Validated technical IDs: replicate spots of one Agilent ProbeName are the
  # same probe sequence; the fixture maps feature_id -> ProbeName.
  av<-run(base,"--technical-ids",shQuote(p$technical_ids),"--verified-technical-ids","--probe-annotation",shQuote(p$annotation),"--outdir",shQuote(file.path(tmp,"avereps")))
  if(av$status==0){
    fav<-utils::read.csv(file.path(tmp,"avereps","tables","feature_table.csv"),stringsAsFactors=FALSE)
    pm<-utils::read.csv(file.path(tmp,"avereps","tables","probe_mapping.csv"),stringsAsFactors=FALSE)
    tid<-utils::read.csv(p$technical_ids,stringsAsFactors=FALSE)
    kept_pn<-tid$technical_id[match(p$feature_id[guide_rows],tid$feature_id)]
    mat<-os_read_matrix(p$matrix);st<-utils::read.csv(p$samples,stringsAsFactors=FALSE)
    st$condition<-factor(st$condition,levels=c("saline","corn10","corn2","corn5"))
    xa<-limma::avereps(mat[guide_rows,,drop=FALSE],ID=kept_pn)
    fa<-limma::eBayes(limma::lmFit(xa,stats::model.matrix(~condition,data=st)),trend=TRUE,robust=TRUE)
    ta<-limma::topTable(fa,coef="conditioncorn10",number=Inf,sort.by="none")
    zz<-fav[match(rownames(ta),fav$feature_id),]
    check(nrow(fav)==length(unique(kept_pn))&&nrow(fav)<nrow(ft)&&nrow(pm)==sum(guide_rows)&&
          identical(sort(unique(pm$technical_id)),sort(fav$feature_id))&&isTRUE(all.equal(zz$pvalue,unname(ta$P.Value),tolerance=1e-10)),
          sprintf("validated technical-ID avereps: %d retained spots -> %d probes; probe map kept; P equal to direct avereps+lmFit+eBayes",sum(guide_rows),nrow(fav)))
    faa<-utils::read.csv(file.path(tmp,"avereps","tables","feature_annotation.csv"),stringsAsFactors=FALSE)
    fk<-faa[faa$feature_id=="A_42_P667782",]
    nsp<-sum(kept_pn=="A_42_P667782")
    mda<-paste(readLines(file.path(tmp,"avereps","draft","methods_results.md")),collapse=" ")
    pva<-jsonlite::fromJSON(file.path(tmp,"avereps","provenance","provenance.json"))
    check(nrow(faa)==nrow(fav)&&nrow(fk)==1&&fk$symbol=="Fastkd2"&&fk$n_probes==nsp&&nsp>1&&
          setequal(strsplit(fk$probe_ids,";",fixed=TRUE)[[1]],p$feature_id[guide_rows][kept_pn=="A_42_P667782"])&&
          grepl(sprintf("%s retained probes gave %s tested features, %s of which combined two or more probes",format(sum(guide_rows),big.mark=","),format(nrow(fav),big.mark=","),format(sum(table(kept_pn)>1),big.mark=",")),mda,fixed=TRUE)&&
          pva$inputs$technical_ids$sha256==sha(p$technical_ids),
          sprintf("F2/F3/F4 averaging keeps the probe->gene mapping (A_42_P667782: %d spots -> Fastkd2, spot IDs listed), Methods state the counts, technical-ID file hashed",nsp))
  }else check(FALSE,paste("validated avereps run",paste(utils::tail(av$out,2),collapse=" | ")))
  # F3 conflicting symbols across averaged spots and typed annotation errors.
  ab<-utils::read.csv(p$annotation,stringsAsFactors=FALSE,colClasses="character")
  fk_ids<-p$feature_id[guide_rows][kept_pn=="A_42_P667782"]
  ab$symbol[ab$feature_id==fk_ids[1]]<-"Xconflict"
  abp<-file.path(tmp,"annotation_conflict.csv");utils::write.csv(ab,abp,row.names=FALSE)
  ac<-run(base,"--technical-ids",shQuote(p$technical_ids),"--verified-technical-ids","--probe-annotation",shQuote(abp),"--outdir",shQuote(file.path(tmp,"conflict")))
  fc<-if(ac$status==0){z<-utils::read.csv(file.path(tmp,"conflict","tables","feature_annotation.csv"),stringsAsFactors=FALSE);z[z$feature_id=="A_42_P667782",]}else NULL
  check(ac$status==0&&identical(fc$annotation_status,"conflicting")&&identical(fc$symbol,"Fastkd2;Xconflict"),"F3 conflicting symbols across averaged probes are marked, not resolved")
  bad1<-file.path(tmp,"annotation_nocol.csv");utils::write.csv(ab[,c("feature_id","symbol")],bad1,row.names=FALSE)
  e1<-run(base,"--probe-annotation",shQuote(bad1),"--outdir",shQuote(file.path(tmp,"ann_bad1")))
  bad2<-file.path(tmp,"annotation_otherids.csv");ab2<-ab;ab2$feature_id<-paste0("x",ab2$feature_id);utils::write.csv(ab2,bad2,row.names=FALSE)
  e2<-run(base,"--probe-annotation",shQuote(bad2),"--outdir",shQuote(file.path(tmp,"ann_bad2")))
  check(e1$status!=0&&any(grepl("OS_MISSING_COLUMN: --probe-annotation",e1$out))&&e2$status!=0&&any(grepl("OS_INVALID_INPUT: no retained probe ID",e2$out)),
        "F3 annotation without entrez column or with foreign IDs refused")
  non<-run(base,"--platform","other","--outdir",shQuote(file.path(tmp,"nonpreset")))
  check(non$status!=0&&any(grepl("OS_CONFLICTING_PARAMETERS",non$out)),"duplicate platform flag rejected")
  np<-run(sub("agilent","other",base),"--outdir",shQuote(file.path(tmp,"nonpreset2")))
  check(np$status!=0&&any(grepl("OS_MISSING_PARAMETER: non-Agilent",np$out)),"non-Agilent unresolved preset refused")
  other<-run(sub("agilent","other",base),"--trend","false","--robust","false","--outdir",shQuote(file.path(tmp,"other")))
  check(other$status==0&&file.exists(file.path(tmp,"other","figures","sa_diagnostic.figure_spec.json")),"other platform requires explicit choices and mean-variance plot")
  miss<-run("--matrix",shQuote(p$matrix),"--samples",shQuote(p$samples),"--platform","agilent","--reference","saline","--target","corn10","--keep-other-levels","--outdir",shQuote(file.path(tmp,"missing")))
  check(miss$status!=0&&any(grepl("OS_MISSING_PARAMETER",miss$out)),"unknown control status refused")
  up<-file.path(tmp,"upstream");dir.create(file.path(up,"objects"),recursive=TRUE)
  file.copy(p$matrix,file.path(up,"objects","matrix.csv"));file.copy(p$samples,file.path(up,"objects","samples.csv"))
  write_handoff(up,"upstream","array-preprocess","1.0.0",objects=list(expression_matrix=list(path=file.path(up,"objects","matrix.csv"),type="expression_matrix"),sample_table=list(path=file.path(up,"objects","samples.csv"),type="sample_table")))
  h<-run("--from-run",shQuote(up),"--control-ids",shQuote(p$controls),"--above-background",shQuote(p$background),"--background-k","4","--platform","agilent","--reference","saline","--target","corn10","--keep-other-levels","--probe-annotation",shQuote(p$annotation),"--preprocessing",shQuote(PRE),"--outdir",shQuote(file.path(tmp,"chained")))
  check(h$status==0&&sha(file.path(a0,"tables","feature_table.csv"))==sha(file.path(tmp,"chained","tables","feature_table.csv")),"verified from-run chain")
  cat("tamper\n",file=file.path(up,"objects","matrix.csv"),append=TRUE)
  ht<-run("--from-run",shQuote(up),"--controls-removed","--platform","agilent","--reference","saline","--target","corn10","--keep-other-levels","--outdir",shQuote(file.path(tmp,"tampered")))
  check(ht$status!=0&&any(grepl("OS_HANDOFF_MISMATCH",ht$out)),"tampered upstream refused")
  for(f in c("volcano","md")){
   sp<-jsonlite::fromJSON(file.path(a0,"figures",paste0(f,".figure_spec.json")))
   check(file.exists(file.path(a0,"figures",paste0(f,".png")))&&grepl("adjusted_p < 0.05",sp$caption,fixed=TRUE),paste(f,"caption and PNG"))
  }
  golden<-c("tables/feature_table.csv","tables/limma_full.csv","tables/direction_summary.csv","tables/feature_annotation.csv","draft/methods_results.md","results/limma_results.json","figures/volcano.figure_spec.json","figures/md.figure_spec.json")
  if(nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN")))os_golden_write(mod,a0,golden)
  gc<-os_golden_check(mod,a0)
  if(gc$status=="SKIP")cat("SKIP: golden --",gc$reason,"\n")else check(gc$status=="PASS","container golden")
 }
 if(annot){
  g174_check_full_printed(g,check)
  g174_check_full_engine(g,tmp,run,check)
 }else cat("NOT-RUN ANCHOR: limma User's Guide 17.4 full printed chain (x$genes Symbol/EntrezID; dim(yfilt) 27024 x 19; decideTests 10 ml/kg Down 756 / NotSig 24734 / Up 1534; topTable coef 4 top 20 with RT1-Bb logFC 9.33) and its engine replay -- RnAgilentDesign028282.db 3.2.3 + org.Rn.eg.db 3.23.0 are not in the acceptance layer (acceptance/exemplars/limma-array/S4_FIXES.md, Shared needs)\n")
}
setwd(oldwd);check(!file.exists(file.path(tmp,"Rplots.pdf")),"no Rplots.pdf")
if(length(errors)){cat(length(errors),"checks FAILED\n");quit(status=1)}else cat("SMOKE PASSED\n")
