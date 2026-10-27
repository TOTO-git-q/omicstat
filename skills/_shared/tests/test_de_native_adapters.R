# Real native fits on wholly invented matrices. No public biological fixture,
# remote package installation or golden-output update is performed by this test.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
root <- normalizePath(file.path(here, "../../.."))
shared <- file.path(root, "skills/_shared/scripts")
for (f in c("module_kit.R", "feature_table.R", "fig_all.R", "limma_io.R")) source(file.path(shared, f))
for (f in c("deseq2-wald/scripts/deseq2_wald_core.R", "deseq2-wald/scripts/deseq2_wald_report.R",
            "limma-array/scripts/limma_array_core.R", "limma-voom/scripts/limma_voom_core.R",
            "limma-dupcor/scripts/limma_dupcor_core.R")) source(file.path(root, "skills", f))
for (pkg in c("DESeq2", "limma", "edgeR", "statmod", "S4Vectors"))
  if (!requireNamespace(pkg, quietly = TRUE)) stop(paste("OS_MISSING_PACKAGE:", pkg), call. = FALSE)
passed <- 0L; failures <- character()
check <- function(ok, label) {
  if (isTRUE(ok)) {passed <<- passed + 1L; cat("PASS", label, "\n")}
  else {failures <<- c(failures, label); cat("FAIL", label, "\n")}
}
bad <- function(expr, label) check(inherits(tryCatch(force(expr), error = function(e)e), "error"), label)
same <- function(x,y) isTRUE(all.equal(x,y,tolerance=0,check.attributes=FALSE))
meta <- function(p) attr(p, "os_meta")
out <- Sys.getenv("OMICSTAT_DE_NATIVE_OUT", file.path(tempdir(), "de-native-adapters"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
render <- Sys.getenv("OMICSTAT_DE_NATIVE_RENDER", "1") == "1"
set.seed(20261016)
n <- 240L; samples <- sprintf("SYN_NATIVE_SAMPLE_%02d", 1:8)
ids <- sprintf("SYN_NATIVE_GENE_%03d", seq_len(n + 6L))
st <- data.frame(sample=samples, condition=rep(c("Reference","Target"), each=4),
  subject=rep(paste0("SYN_NATIVE_SUBJECT_",1:4),2), pair=rep(paste0("SYN_NATIVE_SUBJECT_",1:4),2),
  row.names=samples, stringsAsFactors=FALSE)
base <- exp(seq(log(15), log(800), length.out=n))
beta <- c(rep(2,20),rep(-2,20),rep(.35,20),rep(0,n-60))
mu <- outer(base, rep(1,8)) * 2^outer(beta, as.numeric(st$condition=="Target"))
counts <- rbind(matrix(stats::rnbinom(n*8,mu=as.numeric(mu),size=25),nrow=n),matrix(0L,6,8))
dimnames(counts) <- list(ids,samples); storage.mode(counts) <- "integer"
intensity <- matrix(rep(seq(-4,7,length.out=n),8),nrow=n) +
  outer(beta,as.numeric(st$condition=="Target")) + matrix(stats::rnorm(n*8,sd=.18),nrow=n) +
  outer(stats::rnorm(n,sd=.4),rep(c(-.4,.2,-.1,.3),2))
dimnames(intensity) <- list(ids[seq_len(n)], samples)
.dw_write_csv(data.frame(feature_id=rownames(counts),counts,check.names=FALSE),file.path(out,"synthetic_counts.csv"),digits=17)
.dw_write_csv(data.frame(feature_id=rownames(intensity),intensity,check.names=FALSE),file.path(out,"synthetic_log2_intensity.csv"),digits=17)
.dw_write_csv(st,file.path(out,"synthetic_samples.csv"),digits=17)
versions <- vapply(c("DESeq2","limma","edgeR","statmod","R"),function(pkg)
  if(pkg=="R")as.character(getRversion())else as.character(utils::packageVersion(pkg)),"")
jsonlite::write_json(list(data_origin="project-invented seeded values; no external biological observations",seed=20261016,
  versions=as.list(versions),muscat_native_fit_executed=FALSE),file.path(out,"run_context.json"),pretty=TRUE,auto_unbox=TRUE)

# DESeq2 core and plotting adapter share one actual native result object.
da <- list(condition="condition",reference="Reference",target="Target",covariates="subject",
  "min-count"=5L,"min-samples"=2L,"fit-type"="mean","sf-type"="ratio","lfc-threshold"=0,
  alpha=.1,shrinkage="none","label-n"=0L,"top-n"=10L,"display-lfc-filter"=1,journal="nature",
  "selected-features"=paste(ids[c(1,21)],collapse=","),"selection-reason"="Predeclared invented positive/negative examples",
  "subject-col"="subject","pair-col"="pair")
native_de <- list()
check(identical(dw_missing_reason(c(NA,.1,NA,NA,NA),rep(NA_real_,5),c(10,10,10,10,0),
  c(.01,.1,NA,NA,NA),c(TRUE,TRUE,FALSE,NA,NA)),
  c("outlier","independent_filtering","failed_model","unknown","low_count")),
  "native Cook-suppressed, independent-filtered, failed, unknown and zero-count states stay distinct")
check(dw_missing_reason(NA_real_,NA_real_,10)=="unknown","missing diagnostics cannot manufacture an outlier label")
for (threshold in c(0,1)) {
  a <- da; a[["lfc-threshold"]] <- threshold
  r <- deseq2_wald_compute(counts,st,a);ft <- dw_feature_table(r,a)
  ps <- dw_de_figure_source(r,ft,a)
  key <- if(threshold==0)"zero"else"minimum"; native_de[[key]] <- list(r=r,ft=ft,a=a,source=ps)
  check(identical(r$sample_metadata,st),paste("DESeq2",key,"retains actual optional sample/subject metadata"))
  check(nrow(ps$table)==nrow(counts)&&sum(!ps$table$prefilter_pass)==6, paste("DESeq2",key,"input and prefilter universes reconcile"))
  check(all(is.na(ps$table$pvalue[!ps$table$prefilter_pass]))&&all(ps$table$filtered_reason[!ps$table$prefilter_pass]=="prefilter_count_rule"),
    paste("DESeq2",key,"prefiltered rows receive no invented test value"))
  check(same(ft$pvalue,r$res$pvalue[match(ft$feature_id,rownames(r$res))])&&same(ft$padj,r$res$padj[match(ft$feature_id,rownames(r$res))]),
    paste("DESeq2",key,"exact native raw and adjusted P retained"))
  check(ps$family_size==sum(is.finite(r$res$padj))&&setequal(ps$family_ids,rownames(r$res)[is.finite(r$res$padj)]),
    paste("DESeq2",key,"family uses actual independent-filter threshold and finite native P"))
  bad_a<-a;bad_a[["lfc-threshold"]]<-threshold+.25
  bad(dw_de_figure_source(r,ft,bad_a),paste("DESeq2",key,"false test margin refused"))
  bad_ft<-ft;bad_ft$padj[1]<-.987654321
  bad(dw_de_figure_source(r,bad_ft,a),paste("DESeq2",key,"changed adjusted P refused"))
  bad_ft<-ft;bad_ft$log2fc[1]<-bad_ft$log2fc[1]+.01
  bad(dw_de_figure_source(r,bad_ft,a),paste("DESeq2",key,"changed plotted native estimator refused"))
  .dw_write_csv(ps$table,file.path(out,paste0("deseq2_",key,"_full_plot_source.csv")),digits=17)
  .dw_write_csv(ps$universe,file.path(out,paste0("deseq2_",key,"_universe.csv")),digits=17)
  saveRDS(r,file.path(out,paste0("deseq2_",key,"_native.rds")),version=3)
  if(render)for(j in c("nature","cell")) {
    a$journal<-j;dest<-file.path(out,paste0("deseq2_",key),j)
    result<-deseq2_wald_render(r,ft,a,dest,os_colour_registry_new(),dw_display_filter(ft,a$alpha,a[["display-lfc-filter"]]))
    vc<-result$figures$volcano$spec_obj;ma<-result$figures$ma$spec_obj
    check(vc$definition$de_contract$test$hypothesis==if(threshold==0)"zero_effect"else"minimum_effect",
      paste("DESeq2",key,j,"native null reaches exported figure spec"))
    check(vc$counts$n_input==nrow(counts)&&vc$counts$n_prefilter_pass==nrow(ft)&&vc$counts$n_finite_padj==ps$family_size,
      paste("DESeq2",key,j,"exported denominators come from the model universe"))
    check(identical(vc$data$decision_table,ma$data$decision_table),paste("DESeq2",key,j,"MA and volcano share exact decisions"))
    sp<-result$figures$selected_features$spec_obj
    check(sp$counts$n_subjects==4&&sp$counts$n_selected_samples==8&&sp$counts$n_visible_points==16,
      paste("DESeq2",key,j,"selected native points retain four paired subjects and eight observations"))
    imported<-utils::read.csv(result$tables$selected_feature_values,check.names=FALSE)
    exact<-r$norm[cbind(match(imported$feature_id,rownames(r$norm)),match(imported$sample,colnames(r$norm)))]
    check(same(imported$value,exact),paste("DESeq2",key,j,"selected numerical export roundtrips native counts at binary64 precision"))
    imported<-utils::read.csv(result$tables$de_plot_source,check.names=FALSE)
    check(same(imported$pvalue,ps$table$pvalue)&&same(imported$padj,ps$table$padj),paste("DESeq2",key,j,"source P export retains binary64 precision"))
  }
}
check(!same(native_de$zero$ft$pvalue,native_de$minimum$ft$pvalue),"DESeq2 minimum-effect P is a separate actual test, not a relabelled zero-null column")
normal_a<-da;normal_a$shrinkage<-"normal"
normal_r<-deseq2_wald_compute(counts,st,normal_a);normal_ft<-dw_feature_table(normal_r,normal_a)
normal_source<-dw_de_figure_source(normal_r,normal_ft,normal_a)
check(same(normal_ft$pvalue,native_de$zero$ft$pvalue)&&same(normal_ft$padj,native_de$zero$ft$padj),"native normal display shrinkage leaves actual unshrunken Wald P/q unchanged")
check(!same(normal_ft$log2fc,normal_source$table$log2fc_mle[normal_source$table$prefilter_pass]),"actual shrunken display and tested MLE remain distinct numeric columns")

# Exercise all three registered limma computation paths, including actual TREAT.
la<-list(condition="condition",reference="Reference",target="Target",covariates=NULL,alpha=.05,
  "controls-removed"=TRUE,"verified-technical-ids"=FALSE,platform="other",trend="false",robust="false",
  "min-effect-fc"=1,"display-lfc-filter"=0,preprocessing="wholly invented already-log2 input")
lv<-modifyList(la,list(interface="voom","sample-weights"=FALSE,"min-count"=5L))
ld<-modifyList(la,list(mode="array",block="subject","block-role"="correlated_unit","block-description"="invented repeated biological subject"))
for(module in c("limma-array","limma-voom","limma-dupcor")) {
  a<-switch(module,"limma-array"=la,"limma-voom"=lv,"limma-dupcor"=ld)
  mat<-if(module=="limma-voom")counts else intensity
  model<-os_limma_design(mat,st,a,block_col=if(module=="limma-dupcor")"subject"else NULL)
  pvalues<-list()
  for(fc in c(1,1.5)) {
    a[["min-effect-fc"]]<-fc
    res<-switch(module,"limma-array"=limma_array_compute(mat,model,a),
      "limma-voom"=limma_voom_compute(mat,model,a),"limma-dupcor"=limma_dupcor_compute(mat,model,a))
    ft<-os_limma_feature(res$tt,model,a,module,res$annotation)
    context<-os_limma_figure_context(res,ft,model,a,module)
    kind<-if(fc==1)"zero"else"minimum";pvalues[[kind]]<-stats::setNames(ft$pvalue,ft$feature_id)
    check(context$test$hypothesis==if(fc==1)"zero_effect"else"minimum_effect",paste(module,kind,"uses actual eBayes or TREAT hypothesis"))
    check(same(context$test$margin,log2(fc))&&same(context$test$margin,res$fit$treat.lfc %||% 0),paste(module,kind,"native FC and log2 margin agree"))
    check(setequal(context$family_source_ids,rownames(res$fit$coefficients)[is.finite(res$fit$p.value[,model$coef])]),paste(module,kind,"complete native coefficient family preserved"))
    bad_ft<-ft;bad_ft$padj[1]<-.987654321
    bad(os_limma_figure_context(res,bad_ft,model,a,module),paste(module,kind,"changed native adjusted P refused"))
    bad_a<-a;bad_a[["min-effect-fc"]]<-fc+.25
    bad(os_limma_figure_context(res,ft,model,bad_a,module),paste(module,kind,"false native margin refused"))
    p1<-os_limma_volcano(ft,a$alpha,0,"Target vs Reference",module,"nature",context)
    altered<-context;altered$display_threshold<-2
    p2<-os_limma_volcano(ft,a$alpha,0,"Target vs Reference",module,"nature",altered)
    check(identical(meta(p1)$data$decision_table$statistical_call,meta(p2)$data$decision_table$statistical_call)&&
      identical(meta(p1)$data$raw_source,meta(p2)$data$raw_source)&&identical(meta(p1)$definition$de_contract$family_source_ids,meta(p2)$definition$de_contract$family_source_ids),
      paste(module,kind,"display gate cannot alter native calls, P/q or family"))
    if(module!="limma-voom") {
      md<-os_limma_md(ft,a$alpha,0,"Target vs Reference",module,"nature",context)
      check(any(meta(md)$data$display_table$x<0)&&meta(md)$counts$n_displayed==nrow(ft),paste(module,kind,"negative mean-log intensities are retained"))
    }
    .dw_write_csv(ft,file.path(out,paste0(module,"_",kind,"_feature_table.csv")),digits=17)
    if(render)for(j in c("nature","cell")) {
      plots<-list(volcano=os_limma_volcano(ft,a$alpha,0,"Target vs Reference",module,j,context),
        md=os_limma_md(ft,a$alpha,0,"Target vs Reference",module,j,context))
      for(name in names(plots)) {
        fig<-os_finalize_figure(plots[[name]],file.path(out,paste0(module,"_",kind),j,name),journal=j)
        check(fig$spec_obj$definition$de_contract$test$hypothesis==context$test$hypothesis&&
          identical(fig$spec_obj$definition$de_contract$statistic$values,meta(plots[[name]])$definition$de_contract$statistic$values),
          paste(module,kind,j,name,"exports exact native test provenance"))
      }
    }
  }
  common<-intersect(names(pvalues$zero),names(pvalues$minimum))
  check(!same(pvalues$zero[common],pvalues$minimum[common]),paste(module,"actual TREAT P differs from zero-null P"))
}
cat("ASSERTIONS",passed,"FAILED",length(failures),"\n")
if(length(failures))stop(paste(failures,collapse="; "),call.=FALSE)
