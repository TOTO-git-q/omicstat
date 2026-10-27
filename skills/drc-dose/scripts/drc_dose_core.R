drc_dose_compute <- function(a) {
 ex_require("drc")
 d <- utils::read.csv(a$input,check.names=FALSE,stringsAsFactors=FALSE,
  colClasses=structure("character",names=a$unit))
 ex_columns(d,c(a$dose,a$response,a$unit))
 if (anyNA(d[,c(a$dose,a$response,a$unit)])) ex_stop("missing dose, response or biological-unit values")
 if (any(!nzchar(trimws(as.character(d[[a$unit]])))) || !nzchar(trimws(a[["dose-unit"]]))) ex_stop("biological unit and dose unit must be nonempty")
 if (anyDuplicated(d[[a$unit]])) ex_stop("independent-unit first release refuses repeated biological units; do not treat technical replicates as independent")
 x <- ex_numeric(d[[a$dose]],"dose"); y <- ex_numeric(d[[a$response]],"response")
 if (any(x<0)) ex_stop("dose must be non-negative and untransformed")
 k <- switch(a$model,LL3=3L,LL4=4L)
 if (length(unique(x))<=k || length(x)<=k) ex_stop("insufficient distinct doses or observations for selected model")
 lev <- suppressWarnings(as.numeric(strsplit(a[["response-levels"]],",",fixed=TRUE)[[1]]))
 if (!length(lev) || anyNA(lev) || any(!is.finite(lev)) || anyDuplicated(lev)) ex_stop("response-levels must be distinct finite comma-separated numbers")
 if(a[["response-type"]]=="relative" && any(lev<=0|lev>=100)) ex_stop("relative levels must be strictly between 0 and 100")
 dat <- data.frame(dose=x,response=y)
 fct <- switch(a$model,LL3=drc::LL.3(),LL4=drc::LL.4())
 fit <- drc::drm(formula=response~dose,data=dat,fct=fct,type="continuous",na.action=stats::na.fail,logDose=NULL)
 ed <- drc::ED(fit,respLev=lev,interval="delta",level=a[["ci-level"]],reference=a$reference,type=a[["response-type"]],bound=TRUE,display=FALSE)
 if(ncol(ed)<4L || nrow(ed)!=length(lev)) ex_stop("unexpected ED output shape")
 finite <- all(is.finite(ed))
 extrap <- ed[,1]<min(x)|ed[,1]>max(x)
 et <- add_effect_rows(term=paste0("ED",lev),analysis_id="drc-dose",effect_type="other",estimate=ed[,1],ci_low=ed[,3],ci_high=ed[,4],ci_level=a[["ci-level"]],n_unweighted=nrow(d),test_name="drc::ED delta",notes=paste("Dose unit:",a[["dose-unit"]]))
 grid <- data.frame(dose=seq(min(x),max(x),length.out=201L))
 grid$predicted <- as.numeric(stats::predict(fit,newdata=grid))
 meta <- list(model=a$model,response_levels=lev,response_type=a[["response-type"]],reference=a$reference,dose_unit=a[["dose-unit"]],n_units=nrow(d),interval="delta",study_contract_sha256=a[["study-contract-sha256"]])
 list(object=fit,type="drc",metadata=meta,packages=c("drc","jsonlite","digest"),ready=finite&&!any(extrap),
  method=sprintf("drc %s; %s continuous response model; ED delta intervals; %s response and %s reference.",utils::packageVersion("drc"),a$model,a[["response-type"]],a$reference),
  tables=list(effect_table=et,parameters=data.frame(term=names(stats::coef(fit)),estimate=as.numeric(stats::coef(fit))),predictions=grid,observations=dat),
  qc=list(os_qc_rule("DRC-01","Non-finite ED",!finite,"blocker","ED or interval is non-finite.","Review identifiability."),
   os_qc_rule("DRC-02","ED extrapolation",any(extrap),"blocker","An ED estimate is outside the observed dose range.","Collect covering doses or explicitly review extrapolation."),
   os_qc_rule("DRC-03","Curve identifiability review",TRUE,"warning","Numerical convergence alone does not establish adequate response plateaus.","Review observed responses, residuals and model choice.")))
}
