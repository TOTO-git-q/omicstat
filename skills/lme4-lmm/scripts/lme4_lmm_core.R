lme4_lmm_compute <- function(a) {
 ex_require("lme4")
 d <- utils::read.csv(a$input,check.names=FALSE,stringsAsFactors=FALSE,
  colClasses=structure("character",names=a$subject))
 ex_columns(d,c(a$response,a$subject))
 if (anyNA(d) || any(vapply(d,function(x) is.character(x) && any(!nzchar(trimws(x))),logical(1)))) ex_stop("missing data are refused; provide an explicitly curated analysis table")
 d[[a$response]] <- ex_numeric(d[[a$response]],"response")
 d[[a$subject]] <- factor(d[[a$subject]])
 for (nm in names(d)) if (is.character(d[[nm]])) d[[nm]] <- factor(d[[nm]])
 f <- ex_formula(a$formula,names(d))
 if (!identical(as.character(f[[2]]),a$response)) ex_stop("formula response differs from --response")
 # lme4 >= 2 moved these helpers to reformulas. Keep older installs usable.
 formula_pkg <- if (requireNamespace("reformulas",quietly=TRUE)) "reformulas" else "lme4"
 bars <- if (formula_pkg=="reformulas") reformulas::findbars(f) else lme4::findbars(f)
 # findbars expands || into multiple terms, all for the same grouping factor.
 if (!length(bars) || !all(vapply(bars,function(b) is.name(b[[3]]) && identical(as.character(b[[3]]),a$subject),logical(1)))) ex_stop("first release supports exactly one subject grouping factor")
 ng <- nlevels(d[[a$subject]])
 if (ng<2L || all(table(d[[a$subject]])<2L)) ex_stop("at least two subjects and repeated observations are required")
 fixed <- if (formula_pkg=="reformulas") reformulas::nobars(f) else lme4::nobars(f)
 # Freeze predictor coding, not a potentially huge subject-only indicator matrix.
 # This covers categorical fixed effects and categorical random slopes.
 predictors <- setdiff(unique(c(all.vars(fixed),unlist(lapply(bars,function(b) all.vars(b[[2]]))))),a$response)
 for (nm in predictors) if (is.factor(d[[nm]]) && nlevels(d[[nm]])>1L) stats::contrasts(d[[nm]]) <- stats::contrasts(d[[nm]],contrasts=TRUE)
 x <- stats::model.matrix(fixed,data=d)
 if (qr(x)$rank<ncol(x) || nrow(x)<=ncol(x)) ex_stop("fixed-effect design is rank deficient or saturated")
 # Embed evaluated inputs in the recorded call, rather than local f/d/a symbols.
 # lmerTest reconstructs a deviance function from getCall(fit) after readRDS().
 # The validated formula uses baseenv(); no producer frame or global data is needed.
 fit_call <- bquote(lme4::lmer(formula=.(f),data=.(d),REML=.(a$estimation=="REML"),
  control=.(lme4::lmerControl(optimizer="nloptwrap")),contrasts=.(attr(x,"contrasts")),na.action=stats::na.fail))
 fit <- eval(fit_call,envir=baseenv())
 singular <- lme4::isSingular(fit,tol=a[["singular-tolerance"]])
 conv <- fit@optinfo$conv
 converged <- is.null(conv$lme4$messages) && (is.null(conv$opt) || all(conv$opt==0))
 beta <- lme4::fixef(fit,add.dropped=TRUE)
 ci <- stats::confint(fit,parm="beta_",level=a[["ci-level"]],method="Wald")
 et <- add_effect_rows(term=names(beta),analysis_id="lme4-lmm",effect_type="beta",estimate=as.numeric(beta),
  ci_low=ci[names(beta),1],ci_high=ci[names(beta),2],ci_level=a[["ci-level"]],n_unweighted=ng,
  test_name="lme4::lmer; Wald confidence interval; no coefficient p-value",notes="n_unweighted counts subjects; n_obs is in model_summary")
 meta <- list(formula=a$formula,response=a$response,subject=a$subject,n_obs=nrow(d),n_subject=ng,
  estimation=a$estimation,ci_method="Wald",singular=singular,converged=converged,study_contract_sha256=a[["study-contract-sha256"]])
 list(object=fit,type="lmerMod",metadata=meta,packages=unique(c("lme4",formula_pkg,"Matrix","jsonlite","digest")),ready=converged&&!singular,
  method=sprintf("lme4 %s; formula %s; %s; optimizer nloptwrap; Wald intervals; coefficient p-values not calculated.",utils::packageVersion("lme4"),a$formula,a$estimation),
  tables=list(effect_table=et,variance_components=as.data.frame(lme4::VarCorr(fit)),model_summary=data.frame(n_obs=nrow(d),n_subject=ng,singular=singular,converged=converged),
   residuals=data.frame(observation=seq_len(nrow(d)),fitted=stats::fitted(fit),residual=stats::residuals(fit))),
  qc=list(os_qc_rule("LMM-01","Singular fit",singular,"blocker","Random-effect covariance is singular.","Review the pre-specified model."),
   os_qc_rule("LMM-02","Convergence",!converged,"blocker","Optimizer or derivative convergence failed.","Review the fit before contrasts.")))
}
