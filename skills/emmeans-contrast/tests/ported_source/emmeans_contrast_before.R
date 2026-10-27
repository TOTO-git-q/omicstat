# Preserve native inference annotations before CSV export drops R attributes.
# A summary's adjust attribute describes the requested/resolved summary method;
# CI and P adjustments may differ. Native messages remain authoritative for each.
emmeans_summary_audit <- function(tab, table, requested, by, ci, tests) {
 reported <- attr(tab,"adjust",exact=TRUE)
 if (!is.character(reported) || length(reported)!=1L || !nzchar(reported))
  ex_stop("native emmeans summary did not report its adjustment")
 native_by <- attr(tab,"by.vars",exact=TRUE) %||% character()
 expected_by <- by %||% character()
 if (!identical(native_by,expected_by)) ex_stop("native emmeans summary changed the declared by family")
 families <- if (is.null(by)) rep("all",nrow(tab)) else as.character(tab[[by]])
 if (anyNA(families)) ex_stop("native emmeans family labels contain missing values")
 levels <- unique(families)
 messages <- attr(tab,"mesg",exact=TRUE) %||% character()
 rows <- lapply(seq_along(levels),function(i) {
  selected <- which(families==levels[i])
  data.frame(table=table,family_id=paste0(table,":",i),by_variable=by %||% NA_character_,
   by_value=if (is.null(by)) NA_character_ else levels[i],rows_in_family=length(selected),
   requested_adjustment=requested,native_summary_adjustment=reported,
   confidence_intervals=ci,p_value_tests=tests,cross_adjustment="none",
   native_messages=paste(messages,collapse=" | "),stringsAsFactors=FALSE)
 })
 list(table=do.call(rbind,rows),metadata=list(requested_adjustment=requested,
  native_summary_adjustment=reported,by_variables=native_by,
  primary_variables=attr(tab,"pri.vars",exact=TRUE),native_messages=messages,
  confidence_intervals=ci,p_value_tests=tests,cross_adjustment="none",
  family_row_indices=lapply(levels,function(x)which(families==x)),
  count_semantics="displayed rows, not the native multiplicity denominator",
  ci_adjustment_source="native_messages; do not infer CI adjustment from the adjust attribute"))
}

emmeans_contrast_compute <- function(a,up) {
 ex_require("emmeans");ex_require("lme4")
 if (!identical(up$module,"lme4-lmm") || !isTRUE(up$state$development_only) || !isTRUE(up$state$model_ready)) ex_stop("requires a converged, non-singular lme4-lmm handoff")
 fit <- readRDS(up$objects$model$path);meta <- readRDS(up$objects$metadata$path)
 if (!inherits(fit,"lmerMod")) ex_stop("upstream object is not lmerMod")
 if (!identical(meta$study_contract_sha256,a[["study-contract-sha256"]])) ex_stop("upstream study contract differs")
 mf <- stats::model.frame(fit)
 if (!a$factor %in% names(mf) || !is.factor(mf[[a$factor]])) ex_stop("--factor must name a fitted categorical predictor")
 if (!is.null(a$by) && (!a$by %in% names(mf) || !is.factor(mf[[a$by]]))) ex_stop("--by must name one fitted categorical predictor")
 pkg <- switch(a[["df-method"]],`kenward-roger`="pbkrtest",satterthwaite="lmerTest",asymptotic=NULL)
 if(!is.null(pkg)) ex_require(pkg)
 if(meta$n_obs>3000L && a[["df-method"]]!="asymptotic") ex_stop("finite-df first release limited to 3000 observations; no silent fallback")
 emm <- emmeans::emmeans(object=fit,specs=a$factor,by=a$by,weights=a$weights,lmer.df=a[["df-method"]],
  pbkrtest.limit=3000L,lmerTest.limit=3000L,disable.pbkrtest=a[["df-method"]]!="kenward-roger",disable.lmerTest=a[["df-method"]]!="satterthwaite")
 cmp <- emmeans::contrast(object=emm,method="pairwise",adjust=a$adjust)
 tab <- as.data.frame(summary(cmp,infer=c(TRUE,TRUE),level=a[["ci-level"]],adjust=a$adjust,by=a$by,cross.adjust="none",type="link"))
 lo <- if("lower.CL" %in% names(tab)) "lower.CL" else "asymp.LCL"
 hi <- if("upper.CL" %in% names(tab)) "upper.CL" else "asymp.UCL"
 if (!nrow(tab) || !all(c("estimate","SE","p.value",lo,hi) %in% names(tab))) ex_stop("empty or unexpected contrast table")
 nonest <- any(!is.finite(tab$estimate) | !is.finite(tab$SE) | !is.finite(tab[[lo]]) | !is.finite(tab[[hi]]) | !is.finite(tab$p.value) | tab$p.value<0 | tab$p.value>1)
 if(a[["df-method"]]!="asymptotic" && any(!is.finite(tab$df))) ex_stop("requested finite df was not delivered; no silent fallback")
 raw <- as.data.frame(summary(cmp,infer=c(FALSE,TRUE),adjust="none",by=a$by,cross.adjust="none",type="link"))
 means <- as.data.frame(summary(emm,infer=c(TRUE,FALSE),level=a[["ci-level"]],
  adjust="none",by=a$by,cross.adjust="none",type="link"))
 audit <- list(contrasts_native=emmeans_summary_audit(tab,"contrasts_native",a$adjust,a$by,TRUE,TRUE),
  marginal_means=emmeans_summary_audit(means,"marginal_means","none",a$by,TRUE,FALSE),
  unadjusted_contrasts=emmeans_summary_audit(raw,"unadjusted_contrasts","none",a$by,FALSE,TRUE))
 et <- add_effect_rows(term=tab$contrast,analysis_id="emmeans-contrast",effect_type="mean_diff",estimate=tab$estimate,
  ci_low=tab[[lo]],ci_high=tab[[hi]],ci_level=a[["ci-level"]],p_value=raw$p.value,p_adjusted=tab$p.value,p_adj_method=audit$contrasts_native$metadata$native_summary_adjustment,
  n_unweighted=meta$n_subject,stratum_var=a$by %||% NA_character_,stratum=if(is.null(a$by))NA_character_ else as.character(tab[[a$by]]),
  test_name=paste("emmeans pairwise",a[["df-method"]]),notes="Multiplicity is controlled separately within each by stratum; Gaussian identity scale")
 meta$emmeans <- list(factor=a$factor,by=a$by,weights=a$weights,df_method=a[["df-method"]],adjust=a$adjust,scope="within_by",scale="link",ci_level=a[["ci-level"]],
  summaries=lapply(audit,function(x)x$metadata),
  interpretation="Marginal-mean intervals are unadjusted pointwise intervals. Use contrast tests, not interval overlap, for pairwise inference.")
 list(object=emm,type="emmGrid",metadata=meta,packages=c("emmeans","lme4",pkg,"jsonlite","digest"),ready=!nonest,
  method=sprintf("emmeans %s; factor %s; weights %s; df %s; pairwise contrasts, %s adjustment within each by stratum.",utils::packageVersion("emmeans"),a$factor,a$weights,a[["df-method"]],a$adjust),
  tables=list(effect_table=et,contrasts_native=tab,marginal_means=means,
   inference_families=do.call(rbind,lapply(audit,function(x)x$table))),
  qc=list(os_qc_rule("EMM-01","Non-estimable contrasts",nonest,"blocker","One or more contrasts are non-estimable.","Review design and empty factor cells.")))
}
