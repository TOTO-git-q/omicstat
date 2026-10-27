# Native invented software contracts only. Do not run the broad clinical source smoke.
a <- commandArgs(trailingOnly = TRUE)
root <- if (length(a)) normalizePath(a[1], mustWork = TRUE) else normalizePath(".", mustWork = TRUE)
m <- file.path(root, "skills", "glmnet-coxsig")
if (as.character(getRversion()) != "4.6.1") stop("OS_PACKAGE_VERSION: exact R4.6.1 native lineage required")
for (pkg in c("survival", "glmnet", "Hmisc", "digest")) if (!requireNamespace(pkg, quietly = TRUE)) stop(paste("OS_MISSING_PACKAGE:", pkg))
for (pair in list(c("survival", "3.8-9"), c("glmnet", "5.0"), c("Hmisc", "5.3-0")))
 if (utils::packageDescription(pair[1])$Version != pair[2]) stop(paste("OS_PACKAGE_VERSION:", pair[1], "must match", pair[2]))
source(file.path(m, "scripts", "glmnet_coxsig_core.R"))
source(file.path(m, "scripts", "cpm_port_adapter.R"))
old <- new.env(parent = baseenv()); old$offset <- stats::offset
old$`%||%` <- function(a,b) if (is.null(a) || length(a)==0 || (length(a)==1 && is.na(a))) b else a
for (part in c("core", "binned", "qc")) sys.source(file.path(m, "tests", "ported_source", paste0("cpm_", part, "_selected_before.R.txt")), old)
check <- function(x, text) { if (!isTRUE(x)) stop(text); cat("PASS:", text, "\n") }
near <- function(a, b, tol = 1e-10) isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = tol, check.attributes = FALSE))
refuse <- function(expr, code) {
 msg <- tryCatch({ force(expr); "NO_ERROR" }, error = conditionMessage)
 check(startsWith(msg, paste0(code, ":")), paste("typed refusal", code, msg))
}

# Original censoring regression, exactly the same ten invented subjects.
time <- c(1, 2, rep(10, 8)); event <- c(0, 1, rep(0, 8)); p <- seq(.1, .9, length.out = 10)
before <- old$cpm_calibration_binned(p, event, time, 5)
after <- .os_cxs_port$cpm_calibration_binned(p, event, time, 5)
check(identical(before, after), "same-input source/adapted binned algorithm equality")
check(nrow(after) == 1 && near(after$observed, 1/9) && after$n_at_risk == 8, "manual censor-before-event KM risk1/9, eight at risk")
check(nrow(.os_cxs_port$cpm_calibration_binned(p, event, time, 20)) == 0, "no KM extrapolation")
account <- os_cxs_bin_accounting(p, data.frame(time = time, event = event), 20, 10, 10, .05)
check(account$n_input == 10 && account$n_omitted == 10 && account$n_displayed == 0 && !account$accounting$displayed, "unsupported bin accounts for all original subjects")
refuse(os_cxs_bin_accounting(c(NA, p[-1]), data.frame(time=time,event=event), 5, 10, 10, .05), "OS_INVALID_INPUT")

# Independent risk-set Breslow sum at fixed coefficients, including tied events/censoring.
d <- data.frame(time=c(1,2,2,3,4,5,6,6,7,8,9,10), event=c(1,1,0,0,1,0,1,1,0,1,0,0))
lp <- seq(-.4,.4,length.out=nrow(d))
b <- os_cxs_fit_baseline(d, lp); h <- 0
for (i in seq_along(b$time)) {
 tt <- b$time[i]; h <- h + sum(d$event[d$time == tt]) / sum(exp(lp[d$time >= tt]))
 check(near(b$cumulative_hazard[i], h), paste("fixed-LP independent Breslow sum at", tt))
}
check(identical(b$coefficient_refitted, FALSE), "baseline estimates no prediction coefficients")
pred <- os_cxs_survival(b, 4, lp)
check(near(pred, exp(-b$cumulative_hazard[match(4,b$time)]*exp(lp))), "frozen survival calculation")
refuse(os_cxs_survival(b, 11, lp), "OS_INVALID_PARAMETER")

# Source/native diagnostic fits, not substitution of a different prediction model.
dd <- data.frame(time=rep(seq_len(40),2),event=rep(c(1,0,1,1),20))
score <- sin(seq_len(80)) + seq_len(80)/70
one <- old$cpm_cal_slope("prognostic",score,dd,time_var="time",event_var="event")
two <- .os_cxs_port$cpm_cal_slope("prognostic",score,dd,time_var="time",event_var="event")
check(identical(one,two), "same-input original/adapted native calibration slope")
check(identical(old$cpm_harrell_c("prognostic",score,y_time=dd$time,y_event=dd$event), .os_cxs_port$cpm_harrell_c("prognostic",score,y_time=dd$time,y_event=dd$event)), "same-input original/adapted Harrell C")

# Sampling/arithmetic audit with a transparent invented callback, not an engine oracle.
dat <- data.frame(x=seq_len(30))
cb <- function(train,test) list(c_apparent=mean(train$x)/40, c_test=mean(test$x)/40,
 slope_apparent=mean(train$x)/10, slope_test=mean(test$x)/12,n_selected=1,selected="x")
seed <- 19021L; B <- 200L; apparent <- list(c_apparent=.71,slope_apparent=.63)
out <- .os_cxs_port$.cpm_validate_custom(dat,"x",B,seed,cb,apparent)
set.seed(seed); oc <- os <- numeric(B)
for (i in seq_len(B)) { z <- cb(dat[sample.int(30,30,replace=TRUE),,drop=FALSE],dat);oc[i]<-z$c_apparent-z$c_test;os[i]<-z$slope_apparent-z$slope_test }
check(near(out$corrected_C,.71-mean(oc)) && near(out$corrected_slope,.63-mean(os)), "sampling/arithmetic uses actual apparent slope, not1")
check(out$B_requested==200 && out$B_used==200 && out$B_failed==0 && nrow(out$attempts)==200, "requested and actual attempt counts reconcile")
refuse(.os_cxs_port$.cpm_validate_custom(dat,"x",200,seed,function(...) stop("invented failure"),apparent), "OS_INVALID_RESULT")

# Fixed-signature binding and explicit workup contract guards.
sig <- list(genes=c("g1","g2"),coefficients=c(g1=.2,g2=-.1),expression_scale="normalized-other",time_unit="invented units",lambda=.05,cutoff_rule="median",cutpoint=0,training_subject_sha256=rep("a",12))
w <- list(schema="omicstat.cox-workup.v1",baseline=b,horizon=4,min_bin=10,max_bins=1,prediction_model="original penalized glmnet signature")
w$sha256<-os_cxs_workup_digest(sig,w);sig$cpm_workup<-w
check(identical(os_cxs_validate_frozen_workup(sig),w), "original frozen signature/workup binding validates")
bad<-sig;bad$coefficients[1]<-.21;refuse(os_cxs_validate_frozen_workup(bad), "OS_HANDOFF_MISMATCH")
bad<-sig;bad$cpm_workup$baseline$cumulative_hazard[1]<-999;refuse(os_cxs_validate_frozen_workup(bad), "OS_HANDOFF_MISMATCH")
aa<-list(mode="validate",`dataset-name`="invented contract fixture")
check(isTRUE(os_cxs_workup_contract(aa)), "external workup consumes frozen choices")
aa$`calibration-horizon`<-4;refuse(os_cxs_workup_contract(aa), "OS_CONFLICTING_PARAMETERS")
refuse(os_cxs_workup_contract(list(mode="train",`dataset-name`="invented fixture")), "OS_MISSING_PARAMETER")

# Exact source wrapper parity is separate from an independent method validation.
if (!requireNamespace("pmsampsize",quietly=TRUE)) stop("OS_MISSING_PACKAGE: exact pmsampsize environment closure required for remaining same-input source test")
if (!identical(utils::packageDescription("pmsampsize")$Version,"1.1.3")) stop("OS_PACKAGE_VERSION: independently verified pmsampsize1.1.3 source lineage required")
one<-old$cpm_sample_size("prognostic",10,"invented prior assumption contract",rate=.1,timepoint=5,meanfup=5,csrsquared=.1,shrinkage=.9)
two<-.os_cxs_port$cpm_sample_size("prognostic",10,"invented prior assumption contract",rate=.1,timepoint=5,meanfup=5,csrsquared=.1,shrinkage=.9)
check(identical(one,two), "same-input original/adapted Riley wrapper output")
cat("Native software contracts completed; real owner and penalized end-to-end validation remain separate.\n")
