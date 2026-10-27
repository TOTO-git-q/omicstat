here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
root <- normalizePath(file.path(here,"../../.."))
source(file.path(root,"skills/_shared/scripts/fig_all.R"))
source(file.path(here,"fixtures/fig_fixtures_de_semantics.R"))
x <- os_fixture_de_semantics(); ft <- x$ft
failures <- character(); passed <- 0L
check <- function(ok,label) {if(isTRUE(ok)){passed <<- passed+1L;cat("PASS",label,"\n")}else{failures <<- c(failures,label);cat("FAIL",label,"\n")}}
bad <- function(expr,label) check(inherits(tryCatch(force(expr),error=function(e)e),"error"),label)
meta <- function(p)attr(p,"os_meta")
call <- function(test=x$zero, display=1, table=ft, ...) os_de_class(table$log2fc,table$padj,.05,display,
  test_contract=test,tested_log2fc=table$tested_effect,return_details=TRUE,...)
z <- call()
check(z$statistical_call[5]=="supported_positive" && !z$display_selected[5],"significant small effect remains a statistical call outside the display filter")
check(z$statistical_call[6]=="inconclusive","large point estimate does not manufacture statistical support")
check(z$statistical_call[9]=="not_tested" && z$de_class[9]=="na","missing result remains untested")
equiv <- call(x$small,0,x$equivalence)
check(equiv$statistical_call[7]=="within_margin" && equiv$de_class[7]=="within_margin","small effect with equivalence q .001 is within margin")
check(equiv$statistical_call[8]=="inconclusive","zero estimate with equivalence q .8 is not equivalence")
check(z$statistical_call[5]=="supported_positive" && equiv$statistical_call[5]=="within_margin","same feature can support different conclusions in distinct actual test tables")
check(call(x$minimum,table=x$minimum_table)$statistical_call[6]=="inconclusive","minimum-effect q .2 is inconclusive despite estimate beyond margin")
bad(os_de_test_contract("minimum_effect",1,"zero_effect",0,"zero P","t",TRUE),"zero-null P cannot be relabelled a minimum-effect test")
bad(os_de_test_contract("small_effect",1,"zero_effect",0,"zero P","t",TRUE),"zero-null P cannot be reversed into equivalence")
bad(os_de_test_contract("small_effect",1,"small_effect",1,"equiv P","t",FALSE),"post-hoc plot-selected margin refused")
bad(os_de_test_contract("minimum_effect",1,"minimum_effect",1,"P","t",TRUE,effect_unit="linear_fold_change"),"linear and log2 effect margins cannot be confused")
bad(os_de_class(c(1,2),c(.1,Inf),.05,0),"infinite decision statistic refused")
bad(os_de_class(c(1,2),c(.1,.2),.05,0,statistic_kind="posterior_probability"),"posterior probability is not silently a P-value decision")
check(!call(p_operator="<")$statistical_supported[14] && call(p_operator="<=")$statistical_supported[14],"strict and inclusive P boundaries differ exactly")
q <- data.frame(log2fc=1,tested_effect=1,padj=.001)
check(!call(table=q)$display_selected && call(table=q,display_operator=">=")$display_selected,"strict and inclusive LFC display boundaries differ exactly")
check(call(display=0,table=data.frame(log2fc=0,tested_effect=0,padj=.001))$display_selected,"zero display cutoff explicitly disables the effect gate")
check(call(display=0,table=data.frame(log2fc=0,tested_effect=0,padj=.001))$de_class=="supported_undirected","supported zero estimate is not coloured as inconclusive")
check(call(display=0,table=data.frame(log2fc=.1,tested_effect=NA_real_,padj=.001))$de_class=="supported_undirected","unavailable tested direction does not erase supplied statistical support")
check(identical(call(display=0)$statistical_call,call(display=4)$statistical_call),"display threshold cannot change statistical calls")
check(identical(call(display=0)$test,call(display=4)$test),"display threshold cannot change test null or margin")
fids <- ft$feature_id[is.finite(ft$padj)]
s <- os_statistic_contract("actual",ft$padj,ft$feature_id,"adjusted_p",family_size=length(fids))
check(s$n_reported==16 && s$family_size==length(fids) && s$n_missing==sum(is.na(ft$padj)),"excluded input rows do not inflate the actual finite-test family")
bad(os_statistic_contract("bad",ft$padj,ft$feature_id,"adjusted_p",family_size=length(fids)-1),"family smaller than finite supplied tests refused")
p <- os_volcano(ft,label_n=0,test_contract=x$zero,effect_provenance=x$effect,family_size=length(fids),family_source_ids=fids)
m <- meta(p)
check(m$counts$n_input==16 && m$counts$n_prefilter_pass==15 && m$counts$n_finite_raw_p==12 && m$counts$n_finite_padj==11,"input, prefilter, raw-P and adjusted-P denominators remain distinct")
check(m$counts$n_displayed+m$counts$n_excluded==nrow(ft),"volcano displayed plus excluded reconciles to input")
check(all(c("outlier","independent_filtering","failed_model","unknown","prefilter_count_rule")%in%names(m$counts$missing_statistic_reasons)),"native missing/failed/filter reasons are not all independent filtering")
check(m$data$decision_table$test_state[8]=="tested" && m$data$decision_table$test_state[9]=="outlier","valid P=1 is distinct from unavailable outlier result")
check(identical(m$data$raw_source,ft),"volcano preserves complete raw table")
check(is.character(p$labels$x)&&length(p$labels$x)==1&&grepl("log2 fold change",p$labels$x,fixed=TRUE),"estimator suffix preserves the actual fold-change axis title")
check(identical(unlist(m$definition$de_contract$family_source_ids),fids),"complete actual native family IDs retained")
bad(os_volcano(ft,family_size=length(fids),family_source_ids=rev(ft$feature_id)[seq_along(fids)]),"incorrect native family member IDs refused")
bad(os_volcano(ft,statistic_kind="raw_p"),"padj cannot be relabelled as raw P")
raw <- os_volcano(ft,statistic_kind="raw_p",statistic_col="pvalue",adjustment="none",label_n=0)
check(grepl("unadjusted P",raw$labels$y,fixed=TRUE) && meta(raw)$notes$statistic_kind=="raw_p","raw-P axis and metadata remain explicitly raw")
anno_args <- list(colour_mode="annotation",annotation_col="annotation",annotation_title="Binding annotation",
  annotation_levels=c("Unbound","Bound","Missing annotation"),annotation_denominator="direction")
ann <- do.call(os_volcano,c(list(ft=ft,label_n=0,test_contract=x$zero,effect_provenance=x$effect),anno_args))
check(identical(meta(ann)$data$decision_table,m$data$decision_table),"annotation colour leaves all statistical decisions unchanged")
check(identical(unlist(meta(ann)$definition$de_contract$annotation$levels),anno_args$annotation_levels),"explicit annotation registry order retained")
check(meta(ann)$encodings$colour[["Missing annotation"]]==OS_FIG$col_reference_group,"missing annotation uses neutral grey")
check(!grepl("Red,",meta(ann)$caption,fixed=TRUE) && grepl("Binding annotation",meta(ann)$caption,fixed=TRUE),"annotation caption does not falsely describe red as up")
for (row in meta(ann)$data$direction_category) check(is.null(row$fraction) || identical(row$fraction,row$numerator/row$denominator),paste("actual direction-category fraction",row$direction,row$category))
bad(do.call(os_volcano,c(list(ft=ft),modifyList(anno_args,list(annotation_denominator="guessed")))),"undefined annotation percentage denominator refused")
terc <- os_volcano(ft,colour_mode="effect_tercile",tercile_cutpoints=c(.5,2),label_n=0)
tab <- meta(terc)$data$display_table
check(tab$.colour[match(ft$feature_id[1],tab$feature_id)]==tab$.colour[match(ft$feature_id[2],tab$feature_id)],"large positive and negative effects share absolute-effect tercile")
check(grepl("Absolute plotted effect tercile",meta(terc)$caption,fixed=TRUE),"tercile caption does not claim all largest effects are up")
ma <- os_ma(ft,label_n=0,y_max=4,test_contract=x$zero,effect_provenance=x$effect)
mt <- meta(ma)$data$display_table
check(identical(mt$cap_direction[match(ft$feature_id[1:4],mt$feature_id)],c("upper","lower","none","none")),"positive/negative caps point outward and exact boundary is not capped")
check(identical(mt$y[match(ft$feature_id[1:4],mt$feature_id)],c(4,-4,4,-4)) && identical(meta(ma)$data$raw_source,ft),"display clipping leaves raw +/-8 unchanged")
check(meta(ma)$encodings$shape$upper==24 && meta(ma)$encodings$shape$lower==25,"separate upward/downward triangle glyphs")
check(meta(ma)$counts$n_excluded==3 && meta(ma)$counts$n_displayed==13,"nonpositive abundance and nonfinite effect excluded with counts")
check(meta(ma)$data$decision_table$de_class[10]=="na","MA missing q is not turned into nonsignificance")
logft <- ft; logft$base_mean <- seq(-4,3.5,length.out=nrow(ft))
logma <- os_ma(logft,mean_kind="mean_log_abundance",mean_scale="log2",mean_unit="normalized protein intensity",italic_labels=FALSE,label_n=0)
check(any(meta(logma)$data$display_table$x<0) && meta(logma)$counts$n_displayed==15,"already-log negative abundance remains visible")
check(!grepl("normalized counts",meta(logma)$caption,fixed=TRUE) && logma$labels$x=="Mean log2 abundance (normalized protein intensity)","protein abundance is not normalized count wording")
bad(os_ma(ft,mean_kind="mean_log_abundance",mean_scale="linear"),"mean(log abundance) cannot be labelled as linear mean")
bad(os_ma(logft,mean_kind="mean_log_abundance",mean_scale="log2",mean_transform="log10"),"already-log values cannot be logged again")
check(grepl("reference_subjects=4",meta(ma)$caption,fixed=TRUE) && grepl("Two explicitly declared",meta(ma)$caption,fixed=TRUE),"caption includes actual sample n and expanded control provenance")
check(is.character(ma$labels$y)&&length(ma$labels$y)==1&&grepl("log2 fold change",ma$labels$y,fixed=TRUE),"MA estimator suffix cannot coerce a plotmath call into an asterisk")
smallma <- os_ma(x$equivalence,lfc_threshold=0,label_n=0,test_contract=x$small,effect_provenance=x$effect,y_max=4)
check(grepl("equivalent within the prespecified margin",meta(smallma)$caption,fixed=TRUE) && !grepl("identical effect",meta(smallma)$caption,fixed=TRUE),"within-margin caption is not biological identity")
line_labels <- ggplot2::ggplot_build(smallma)$plot$scales$get_scales("linetype")$get_breaks()
check(any(grepl("Effect margin",line_labels,fixed=TRUE)),"actual effect-margin line is explicitly named in its legend")
small_colour <- ggplot2::ggplot_build(smallma)$plot$scales$get_scales("colour")
check(identical(small_colour$name,"Statistical decision") &&
  "Within margin" %in% small_colour$get_labels(small_colour$get_breaks()),
  "explicit small-effect MA includes a named within-margin color legend")
grobs_text <- function(g) {
  label <- if (inherits(g,"text")) as.character(g$label) else character()
  c(label,unlist(lapply(g$grobs %||% list(),grobs_text)),unlist(lapply(g$children %||% list(),grobs_text)))
}
device_before_guide_check <- grDevices::dev.cur()
guide_labels <- local({
  # grid's font metrics otherwise open the default Rplots.pdf device. This
  # inspection owns a disposable device; actual figures still use the renderer.
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add=TRUE)
  grobs_text(ggplot2::ggplotGrob(smallma))
})
check(all(c("Statistical decision","Within margin") %in% guide_labels),
  "actual rendered guide tree contains within-margin meaning without relying on a separate caption")
check(identical(grDevices::dev.cur(),device_before_guide_check),
  "guide inspection closes its own device and does not create Rplots.pdf")
coincident <- os_ma(x$minimum_table,lfc_threshold=1,label_n=0,test_contract=x$minimum,effect_provenance=x$effect)
check(any(grepl("Effect margin + display filter",ggplot2::ggplot_build(coincident)$plot$scales$get_scales("linetype")$get_breaks(),fixed=TRUE)),"coincident margin and display threshold retain both meanings")
check(inherits(ann,"patchwork")&&grepl("separate count band",meta(ann)$caption,fixed=TRUE),"direction-category counts occupy a separate panel outside point labels and axes")
copy <- os_with_meta(ma,notes=list(extra="annotation only"))
check(identical(meta(copy)$definition$de_contract,meta(ma)$definition$de_contract),"later metadata merge preserves complete DE contract and explicit nulls")
bad(os_with_meta(ma,definition=list(de_contract=NULL)),"later metadata cannot erase a DE contract")
baseargs <- list(d=x$points,selected_features=c("SYN_FEATURE_A","SYN_FEATURE_B"),selection_reason="Predeclared synthetic examples",
  normalization="invented size-factor scaling",unit="normalized counts",reference="Reference",group_order=c("Reference","Target"))
pts <- do.call(os_selected_feature_points,baseargs)
check(meta(pts)$counts$n_visible_points==16 && is.null(meta(pts)$counts$n_subjects),"all small-n sample points shown without inventing subject n")
check(any(meta(pts)$data$selected_values$value==0) && meta(pts)$counts$n_log_excluded==0,"linear selected-feature zero retained")
check(!any(vapply(pts$layers,function(l)inherits(l$geom,"GeomLine"),logical(1))),"no sample-pair lines without pair IDs")
median_points <- do.call(os_selected_feature_points,modifyList(baseargs,
  list(selected_features="SYN_FEATURE_A",group_order=NULL,order_by="median"),keep.null=TRUE))
check(grepl("median expression; not time or disease stage",median_points$labels$x,fixed=TRUE) &&
  identical(unlist(meta(median_points)$definition$notes$group_order),c("Reference","Target")),
  "actual median group ordering is labelled descriptive rather than temporal")
pair <- do.call(os_selected_feature_points,c(baseargs,list(subject_col="subject",pair_col="pair")))
check(meta(pair)$counts$n_subjects==4 && meta(pair)$counts$n_selected_samples==8,"repeated subjects across samples/features do not inflate biological n")
check(any(vapply(pair$layers,function(l)inherits(l$geom,"GeomLine"),logical(1))),"true pair IDs produce actual connecting lines")
check(all(meta(pair)$data$group_summary$n_subjects==4),"per-feature/group subject counts derive from actual IDs")
bad(do.call(os_selected_feature_points,modifyList(baseargs,list(d=rbind(x$points,x$points[1,])))),"duplicate feature/sample source refused")
bad(do.call(os_selected_feature_points,modifyList(baseargs,list(selected_features="ABSENT"))),"absent selected feature refused")
missing <- x$points; missing$value[1] <- NA_real_
pm <- do.call(os_selected_feature_points,modifyList(baseargs,list(d=missing)))
check(meta(pm)$counts$n_missing==1 && meta(pm)$counts$n_visible_points==15,"missing sample value remains a counted missing point")
lp <- do.call(os_selected_feature_points,c(baseargs,list(display_transform="log10")))
check(meta(lp)$counts$n_log_excluded==1 && meta(lp)$data$raw_source$value[1]==0,"log-zero exclusion retains original zero and named state")
bad(do.call(os_selected_feature_points,c(baseargs,list(source_scale="log2",display_transform="log10"))),"selected-feature double log refused")
union_source <- data.frame(feature_id=c("SYN_U_A","SYN_U_B","SYN_U_C","SYN_U_A","SYN_U_B","SYN_U_C"),
  subtype=rep(c("SYN_SUB_A","SYN_SUB_B"),each=3),test_id=rep(c("SYN_TEST_A","SYN_TEST_B"),each=3),
  family_id=rep(c("SYN_FAM_A","SYN_FAM_B"),each=3),statistic_kind="adjusted_p",statistic_value=c(.001,.01,NA,.002,.8,.05))
u_ids <- .os_sem_rows(union_source,c("feature_id","test_id"))
families <- list(SYN_FAM_A=list(source_ids=u_ids[1:2],method="supplied illustrative test",adjustment="BH",provenance="complete synthetic test A source"),
  SYN_FAM_B=list(source_ids=u_ids[4:6],method="supplied illustrative test",adjustment="BH",provenance="complete synthetic test B source"))
u <- os_de_detected_union(union_source,families)
check(u$counts$n_unique_detected_features==2&&u$counts$n_detected_tests==3,"subtype union counts one original feature once while retaining repeated detections")
check(nrow(u$all_tests)==6&&identical(u$all_tests$statistic_value,union_source$statistic_value),"union retains every subtype statistic including unavailable and inconclusive results")
check(grepl("Detected only",u$union$interpretation[u$union$feature_id=="SYN_U_B"],fixed=TRUE)&&!u$definition$specificity_claim,"single-subtype detection does not manufacture specificity")
check(os_de_detected_union(union_source,families,p_operator="<=")$counts$n_unique_detected_features==3,"union preserves exact strict or inclusive native threshold rule")
wrong_family <- families;wrong_family$SYN_FAM_A$source_ids<-u_ids[1]
bad(os_de_detected_union(union_source,wrong_family),"union refuses a declared family omitting an available supplied test")
check(!u$definition$separate_selected_family_FDR&&!u$definition$interaction_test_performed&&grepl("not independent validation",u$definition$selection_display,fixed=TRUE),"union selection adds neither FDR guarantee, interaction test nor independent validation")
out <- Sys.getenv("OMICSTAT_DE_OUT",file.path(tempdir(),"de-semantics"));dir.create(out,recursive=TRUE,showWarnings=FALSE)
if (Sys.getenv("OMICSTAT_DE_RENDER","1")=="1") {
  for(j in c("nature","cell")) {
    plots <- list(
      volcano_zero=os_volcano(ft,label_n=0,test_contract=x$zero,effect_provenance=x$effect,family_size=length(fids),family_source_ids=fids,journal=j),
      ma_caps=os_ma(ft,label_n=0,y_max=4,test_contract=x$zero,effect_provenance=x$effect,journal=j),
      ma_small=os_ma(x$equivalence,lfc_threshold=0,label_n=0,test_contract=x$small,effect_provenance=x$effect,y_max=4,journal=j),
      ma_log_abundance=os_ma(logft,mean_kind="mean_log_abundance",mean_scale="log2",mean_unit="normalized protein intensity",italic_labels=FALSE,label_n=0,journal=j),
      volcano_annotation=do.call(os_volcano,c(list(ft=ft,label_n=0,test_contract=x$zero,effect_provenance=x$effect,journal=j),anno_args)),
      volcano_tercile=os_volcano(ft,colour_mode="effect_tercile",tercile_cutpoints=c(.5,2),label_n=0,journal=j),
      selected_features=do.call(os_selected_feature_points,c(baseargs,list(subject_col="subject",pair_col="pair",journal=j))))
    for(n in names(plots)) {
    a <- os_finalize_figure(plots[[n]],file.path(out,j,n),width=if(n=="selected_features")"double"else"single",journal=j)
    b <- os_finalize_figure(plots[[n]],file.path(out,paste0(j,"-replay"),n),width=if(n=="selected_features")"double"else"single",journal=j)
    check(identical(a$spec_obj,b$spec_obj),paste(j,n,"exact spec replay"))
    check(identical(a$spec_obj$files$png$sha256,b$spec_obj$files$png$sha256) && identical(a$spec_obj$files$pdf$content_sha256,b$spec_obj$files$pdf$content_sha256),paste(j,n,"exact PNG and normalized PDF replay"))
    }
  }
}
cat("ASSERTIONS",passed,"FAILED",length(failures),"\n")
if(length(failures))stop(paste(failures,collapse="; "),call.=FALSE)
