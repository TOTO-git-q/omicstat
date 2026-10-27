# P0-13B2: independent, explicitly selected Gaussian longitudinal post-fit port.
# MedStat is a read-only provenance source, never a runtime dependency.
.os_longitudinal_script <- local({
 files <- vapply(sys.frames(),function(f) if(is.null(f$ofile)) "" else f$ofile,"")
 file.path(dirname(normalizePath(tail(files[nzchar(files)],1))),"longitudinal_ported.R")
})
os_longitudinal_port <- function() {
 env <- new.env(parent=baseenv())
 env$add_effect_rows <- add_effect_rows
 env$new_effect_table <- new_effect_table
 sys.source(.os_longitudinal_script,envir=env)
 env
}
os_longitudinal_stop <- function(code,message) stop(paste0(code,": ",message),call.=FALSE)

# Pure input contract, separated from native fitting for exact refusal tests.
os_longitudinal_frame <- function(data,subject,group,time,response,time_levels) {
 required <- c(subject,group,time,response)
 if(length(unique(required))!=4L || !all(required %in% names(data)))
  os_longitudinal_stop("OS_INVALID_DESIGN","subject, group, time and response must name distinct fitted columns")
 if(any(make.names(required)!=required))
  os_longitudinal_stop("OS_INVALID_PARAMETER","longitudinal fitted column names must be syntactic; no implicit renaming")
 if(!is.factor(data[[group]]) || !is.factor(data[[time]]) || nlevels(data[[group]])<2L || nlevels(data[[time]])<2L)
  os_longitudinal_stop("OS_INVALID_DESIGN","group and categorical time must have at least two fitted levels")
 if(any(grepl(" - ",levels(data[[group]]),fixed=TRUE)) || any(grepl("[\\r\\n]",levels(data[[group]]),perl=TRUE)))
  os_longitudinal_stop("OS_INVALID_PARAMETER","group labels must not collide with the source contrast delimiter or keyed row separator")
 if(anyNA(data) || !is.numeric(data[[response]]) || any(!is.finite(data[[response]])))
  os_longitudinal_stop("OS_INVALID_INPUT","fitted analysis data must be complete with a finite numeric response")
 if(is.null(time_levels) || !is.character(time_levels) || length(time_levels)!=1L || !nzchar(time_levels))
  os_longitudinal_stop("OS_MISSING_PARAMETER","--longitudinal requires --time-levels with prespecified chronological labels")
 order <- trimws(strsplit(time_levels,",",fixed=TRUE)[[1]])
 if(length(order)<2L || any(!nzchar(order)) || anyDuplicated(order) ||
    !setequal(order,levels(data[[time]])))
  os_longitudinal_stop("OS_INVALID_PARAMETER","--time-levels must list each fitted time level exactly once")
 if(anyDuplicated(data[c(subject,time)]))
  os_longitudinal_stop("OS_INVALID_DESIGN","duplicate biological-unit/time rows are not independent repeats; curate technical replicates explicitly")
 groups_by_unit <- split(as.character(data[[group]]),as.character(data[[subject]]))
 if(length(groups_by_unit)<2L || any(vapply(groups_by_unit,function(x) length(unique(x))!=1L,logical(1))))
  os_longitudinal_stop("OS_INVALID_DESIGN","each biological unit must retain one group across time")
 if(any(table(data[[group]],data[[time]])==0L))
  os_longitudinal_stop("OS_INVALID_DESIGN","an observed group-by-time cell is empty; no invented mean or contrast")
 port <- os_longitudinal_port()
 port$check_longitudinal(data,subject)
 waves <- port$scan_waves(data,subject,time,time_levels=order)
 list(data=data,subject=subject,group=group,time=time,outcome=response,time_levels=order,
  k_time=length(order),n_subjects_used=length(groups_by_unit),n_rows_used=nrow(data),
  monotone=waves$monotone,n_non_monotone=waves$n_non_monotone)
}

os_longitudinal_compute <- function(a,up) {
 ex_require("lme4");ex_require("emmeans")
 if(!identical(up$module,"lme4-lmm") || !isTRUE(up$state$development_only) || !isTRUE(up$state$model_ready))
  os_longitudinal_stop("OS_CHAIN_STATE","longitudinal contrasts require the verified converged, non-singular lme4-lmm handoff")
 if(is.null(a[["dataset-name"]]) || !is.character(a[["dataset-name"]]) || length(a[["dataset-name"]])!=1L || !nzchar(trimws(a[["dataset-name"]])))
  os_longitudinal_stop("OS_MISSING_PARAMETER","--longitudinal requires the actual --dataset-name")
 if(grepl("[\\r\\n\\t]",a[["dataset-name"]],perl=TRUE))
  os_longitudinal_stop("OS_INVALID_PARAMETER","dataset label must be one plain line")
 if(is.null(a$by) || !nzchar(a$by)) os_longitudinal_stop("OS_MISSING_PARAMETER","--longitudinal requires --by naming categorical time")
 if(!a[["df-method"]] %in% c("kenward-roger","satterthwaite"))
  os_longitudinal_stop("OS_INVALID_PARAMETER","ported longitudinal mode requires Kenward-Roger or Satterthwaite; asymptotic remains available only in the original mode")
 if(!a$adjust %in% c("none","bonferroni","holm","sidak"))
  os_longitudinal_stop("OS_INVALID_PARAMETER","longitudinal across-time adjustment must be none, bonferroni, holm or sidak; no automatic Tukey substitution")
 fit <- readRDS(up$objects$model$path);meta <- readRDS(up$objects$metadata$path)
 if(!inherits(fit,"lmerMod") || !identical(meta$study_contract_sha256,a[["study-contract-sha256"]]))
  os_longitudinal_stop("OS_HANDOFF_MISMATCH","fitted model class or study contract differs")
 mf <- stats::model.frame(fit)
 prep <- os_longitudinal_frame(mf,meta$subject,a$factor,a$by,meta$response,a[["time-levels"]])
 if(!identical(as.integer(meta$n_obs),as.integer(nrow(mf))) ||
    !identical(as.integer(meta$n_subject),as.integer(prep$n_subjects_used)))
  os_longitudinal_stop("OS_HANDOFF_MISMATCH","fitted biological-unit/row counts disagree with metadata")
 if(nrow(mf)>3000L) os_longitudinal_stop("OS_LIMIT_EXCEEDED","finite-df first release is limited to 3000 fitted rows; no raised ceiling or asymptotic fallback")
 pkg <- if(a[["df-method"]]=="kenward-roger") "pbkrtest" else "lmerTest"
 ex_require(pkg)
 formula_pkg <- if(requireNamespace("reformulas",quietly=TRUE)) "reformulas" else "lme4"
 f <- stats::formula(fit)
 fixed <- if(formula_pkg=="reformulas") reformulas::nobars(f) else lme4::nobars(f)
 bars <- if(formula_pkg=="reformulas") reformulas::findbars(f) else lme4::findbars(f)
 terms <- strsplit(attr(stats::terms(fixed),"term.labels"),":",fixed=TRUE)
 target <- c(a$factor,a$by)
 if(!any(vapply(terms,function(x) length(x)==2L && setequal(x,target),logical(1))) ||
    any(vapply(terms,function(x) length(x)>2L && any(target %in% x),logical(1))))
  os_longitudinal_stop("OS_INVALID_DESIGN","the same model must contain the explicit group-by-time interaction, without a higher-order interaction involving either")
 if(!all(vapply(bars,function(x) identical(as.character(x[[3]]),meta$subject),logical(1))))
  os_longitudinal_stop("OS_INVALID_DESIGN","the fitted random effects must use the recorded biological-unit grouping")
 has_slope <- any(vapply(bars,function(x) length(all.vars(x[[2]]))>0L,logical(1)))
 if(has_slope && prep$k_time<=2L) os_longitudinal_stop("OS_INVALID_DESIGN","source guard refuses random slopes with only two timepoints; no automatic refit")
 covars <- setdiff(all.vars(fixed),c(meta$response,a$factor,a$by))
 for(nm in covars) if(any(vapply(split(mf[[nm]],mf[[meta$subject]]),function(x) length(unique(x))>1L,logical(1))))
  os_longitudinal_stop("OS_INVALID_DESIGN","additional adjustment covariates must be constant within biological unit in this bounded port")
 port <- os_longitudinal_port()
 degenerate <- port$.lc_singular(fit)
 if(isTRUE(degenerate$degenerate)) os_longitudinal_stop("OS_NUMERICAL_DEGENERACY","source three-criterion guard detected singular covariance, absolute random-effect correlation above 0.99, or convergence messages; no alternate model fitted")
 declared <- if(a[["df-method"]]=="kenward-roger") "Kenward-Roger" else "Satterthwaite"
 fit_result <- list(model=fit,engine="lmer",time_type="factor",emm_args=list(weights=a$weights))
 native <- port$lc_emm_and_tests(fit_result,prep,declared,multiplicity=a$adjust,alpha=1-a[["ci-level"]])
 jt <- as.data.frame(native$joint_tests)
 expected <- c("model term","df1","df2","F.ratio","p.value")
 if(!nrow(jt) || !all(expected %in% names(jt))) os_longitudinal_stop("OS_INVALID_RESULT","same-model joint_tests did not return its required numerical table")
 is_interaction <- vapply(strsplit(as.character(jt[["model term"]]),":",fixed=TRUE),function(x) length(x)==2L && setequal(x,target),logical(1))
 if(sum(is_interaction)!=1L) os_longitudinal_stop("OS_INVALID_RESULT","exact group-by-time joint test is absent or duplicated")
 means <- native$emm_df;raw <- native$contrast_raw;adjusted <- native$contrast_adjusted
 for(tab in list(means,raw,if(is.null(adjusted))raw else adjusted)) {
  if(!nrow(tab) || !"df" %in% names(tab) || any(!is.finite(tab$df) | tab$df<=0))
   os_longitudinal_stop("OS_INVALID_RESULT","every EMM and contrast must retain positive finite df under the declared method")
 }
 if(any(!is.finite(jt$df1) | jt$df1<=0 | !is.finite(jt$df2) | jt$df2<=0 | !is.finite(jt$F.ratio) | jt$F.ratio<0 | !is.finite(jt$p.value) | jt$p.value<0 | jt$p.value>1))
  os_longitudinal_stop("OS_INVALID_RESULT","same-model joint-test inference is non-estimable or used asymptotic df")
 for(tab in list(means,raw,if(is.null(adjusted))raw else adjusted)) {
  estimate <- if("emmean" %in% names(tab))tab$emmean else tab$estimate
  if(any(!is.finite(estimate) | !is.finite(tab$SE) | tab$SE<=0 | !is.finite(tab$lower.CL) | !is.finite(tab$upper.CL) | tab$lower.CL>estimate | tab$upper.CL<estimate))
   os_longitudinal_stop("OS_NUMERICAL_DEGENERACY","EMM/contrast estimate, standard error or interval is not estimable")
  if("p.value" %in% names(tab) && any(!is.finite(tab$p.value) | tab$p.value<0 | tab$p.value>1))
   os_longitudinal_stop("OS_NUMERICAL_DEGENERACY","every raw and adjusted contrast must have a finite P value in [0,1]")
 }
 if(anyDuplicated(raw[c("contrast",a$by)]) || (!is.null(adjusted) && anyDuplicated(adjusted[c("contrast",a$by)])))
  os_longitudinal_stop("OS_INVALID_RESULT","duplicate (contrast,time) keys cannot be matched safely")
 source_hash <- digest::digest(file=up$objects$model$path,algo="sha256")
 effects <- port$diff_effect_rows(raw,adjusted,a$by,"emmeans-longitudinal",FALSE,source_hash,
  adjust_method=a$adjust,ci_level=a[["ci-level"]],prep=prep,group=a$factor)
 effects$stratum_var <- a$by;effects$stratum <- as.character(effects$level)
 effects$test_name <- paste("ported emmeans revpairwise",a[["df-method"]])
 effects$notes <- "Pointwise raw contrast CI; adjusted P uses all contrasts/timepoints jointly. Adjusted native CI and messages are in separate tables."
 audit <- list(marginal_means=emmeans_summary_audit(means,"marginal_means","none",a$by,TRUE,FALSE),
  contrasts_unadjusted=emmeans_summary_audit(raw,"contrasts_unadjusted","none",a$by,TRUE,TRUE))
 if(!is.null(adjusted)) audit$contrasts_adjusted <- emmeans_summary_audit(adjusted,"contrasts_adjusted",a$adjust,NULL,TRUE,TRUE)
 joint <- port$interaction_effect_rows(jt,"emmeans-longitudinal",source_hash)
 joint$test_name <- paste("emmeans joint_tests",a[["df-method"]]);joint$notes <- paste(joint$notes,"Same fitted model and df method; numerical df need not equal contrast-specific df.")
 joint$is_group_time_interaction <- is_interaction
 settings <- list(factor=a$factor,by=a$by,weights=a$weights,df_method=a[["df-method"]],adjust=a$adjust,
  scope="all_contrasts_across_time",scale="link",ci_level=a[["ci-level"]],longitudinal=TRUE,
  time_order=prep$time_levels,dataset_name=a[["dataset-name"]],contrast_direction="revpairwise (later fitted group level minus earlier)",
  model_sha256=source_hash,refit_performed=FALSE,global_emmeans_options_changed=FALSE,
  df_limit=3000L,df_actual_contrasts=as.numeric(raw$df),df_actual_joint=as.numeric(jt$df2),
  summaries=lapply(audit,function(x)x$metadata),
  interpretation="Categorical-time Gaussian model EMMs and pointwise CI. Across-time adjustment belongs to contrast P/adjusted CI, not marginal-mean bands.")
 meta$emmeans <- settings
 meta$longitudinal_source <- list(ported_from="TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa:skills/longitudinal-change/scripts/longitudinal_core.R",runtime_dependency=FALSE)
 alpha <- 1-a[["ci-level"]];interaction_p <- jt$p.value[is_interaction]
 conflict <- interaction_p>=alpha && any(raw$p.value<alpha)
 borderline <- any(raw$p.value>=.01 & raw$p.value<=.10)
 tables <- list(effect_table=effects,marginal_means=means,contrasts_unadjusted=raw,
  joint_tests_native=jt,interaction_tests=joint,
  inference_families=do.call(rbind,lapply(audit,function(x)x$table)),
  longitudinal_design=data.frame(n_subject=prep$n_subjects_used,n_rows=prep$n_rows_used,n_time=prep$k_time,
    n_non_monotone=prep$n_non_monotone,df_method=a[["df-method"]],refit=FALSE,model_sha256=source_hash))
 if(!is.null(adjusted)) tables$contrasts_adjusted <- adjusted
 list(object=native$emm,type="emmGrid",metadata=meta,packages=unique(c("emmeans","lme4",pkg,formula_pkg,"jsonlite","digest")),ready=TRUE,
  method=sprintf("Explicit longitudinal mode; one existing Gaussian lme4 fit, no refit; EMM, revpairwise per-time contrast and joint interaction tests use %s and weights %s. %s adjustment over all contrasts/timepoints jointly; mean and raw contrast intervals are pointwise %g%%. Actual contrast/joint df and native adjustment messages retained. No global options or finite-df ceiling changed.",a[["df-method"]],a$weights,a$adjust,100*a[["ci-level"]]),tables=tables,
  qc=list(os_qc_rule("EMM-LC03","Low-information random slope",has_slope && prep$k_time==3L,"warning","A random slope with exactly three timepoints is low-information.","Review the prespecified random effects; no automatic fallback or sensitivity fit was performed."),
   os_qc_rule("EMM-LC04","Borderline per-time contrast",borderline,"warning","At least one raw per-time P is in [0.01,0.10].","Review model sensitivity as a separate prespecified analysis; this run did not fit an alternative model."),
   os_qc_rule("EMM-LC05","Global and local inference differ",conflict,"warning","The omnibus interaction is not significant but at least one raw per-time contrast is significant.","State the prespecified reporting and multiplicity convention; the software does not select one."),
   os_qc_rule("EMM-LC08","Same model and df method",FALSE,"info","Actual finite df from the same fitted model are retained for EMMs, contrasts and joint tests.","Numerical denominator df can differ by contrast; one common value is not asserted."),
   os_qc_rule("EMM-LC09","Across-time contrast family",FALSE,"info","Raw and adjusted results stay separate; correction uses by=NULL across all times.","Read native messages for actual CI and P adjustments, especially Holm.")))
}
