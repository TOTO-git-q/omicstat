# Same-input native comparisons, not substituted Python statistics.
here <- dirname(normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1])))
source(file.path(here,"longitudinal_test_helpers.R"));root <- lc_load_native(here)
out <- Sys.getenv("OMICSTAT_LONGITUDINAL_OUT","")
if(!nzchar(out)) out <- file.path(if(dir.exists("/evidence"))"/evidence" else tempdir(),paste0("longitudinal-native-",Sys.getpid()))
if(dir.exists(out) && length(list.files(out,all.files=TRUE,no..=TRUE))) stop("Fresh evidence directory required; earlier failures are immutable")
dir.create(out,recursive=TRUE)
checks <- list()
check <- function(label,code) {
 failure <- tryCatch({force(code);NULL},error=conditionMessage)
 checks[[length(checks)+1L]] <<- list(label=label,passed=is.null(failure),error=failure)
 cat(if(is.null(failure))"PASS" else "FAIL",label,if(is.null(failure))"" else failure,"\n")
 jsonlite::write_json(checks,file.path(out,"CHECKPOINT.json"),auto_unbox=TRUE,pretty=TRUE)
}
refuse <- function(expr,code) {
 message <- tryCatch({force(expr);"NO_ERROR"},error=conditionMessage)
 stopifnot(grepl(paste0(code,":"),message,fixed=TRUE))
}
d <- lc_source_fixture();fx <- lc_fixture_fit(d,file.path(out,"working-fit"));a <- fx$args;up <- fx$up
fit <- fx$result$object;mf <- stats::model.frame(fit)
check("original LONG-balanced-cells and same-model KR/Satterthwaite source tables",{
 metrics <- lc_anchor_values(here,out)
 defs <- jsonlite::fromJSON(file.path(here,"anchors.json"),simplifyVector=FALSE)
 for(row in defs) if(row$id %in% names(metrics)) stopifnot(abs(metrics[[row$id]]-row$expected)<=row$tolerance)
 stopifnot(length(metrics)==9L)
 jsonlite::write_json(metrics,file.path(out,"ACTUAL_LONGITUDINAL_ANCHORS.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA)
})
check("original default path numerical body has unchanged native results",{
 original <- new.env(parent=.GlobalEnv);sys.source(file.path(here,"ported_source/emmeans_contrast_before.R"),envir=original)
 b <- a;b$longitudinal <- FALSE;b[["time-levels"]] <- NULL;b[["dataset-name"]] <- NULL;b$adjust <- "bonferroni"
 old <- original$emmeans_contrast_compute(b,up);got <- emmeans_contrast_compute(b,up)
 stopifnot(identical(old$tables,got$tables),identical(old$metadata,got$metadata),identical(old$method,got$method))
})
check("source fixed row ceiling is a refusal, never a global option or df fallback",{
 port <- os_longitudinal_port();prep <- list(data=data.frame(x=seq_len(3001L)))
 previous <- emmeans::emm_options()
 refuse(port$lc_emm_and_tests(list(model=fit),prep,"Kenward-Roger"),"OS_LIMIT_EXCEEDED")
 stopifnot(identical(previous,emmeans::emm_options()))
})
check("explicit mean and contrast summaries ignore global correction injection",{
 original_options <- emmeans::emm_options()
 first <- emmeans_contrast_compute(a,up)
 emmeans::emm_options(summary=list(adjust="bonferroni",cross.adjust="bonferroni"))
 after <- tryCatch(emmeans_contrast_compute(a,up),finally=emmeans::emm_options(original_options))
 for(nm in c("marginal_means","contrasts_unadjusted","contrasts_adjusted")) stopifnot(identical(first$tables[[nm]],after$tables[[nm]]))
})
check("three-group keyed Holm join and actual native adjustment annotations",{
 third_group_seed <- 152L;set.seed(third_group_seed);third <- d[1:120,];third$id <- third$id+80L;third$grp <- "C";third$y <- third$y+1+stats::rnorm(nrow(third),sd=.18)
 multi <- lc_fixture_fit(rbind(d,third),file.path(out,"three-group"));r <- emmeans_contrast_compute(multi$args,multi$up)
 raw <- r$tables$contrasts_unadjusted;adj <- r$tables$contrasts_adjusted;port <- os_longitudinal_port()
 prep <- os_longitudinal_frame(stats::model.frame(multi$result$object),"id","grp","visit","y",a[["time-levels"]])
 joined <- port$diff_effect_rows(raw,adj[nrow(adj):1,],"visit","key-test",FALSE,"hash",adjust_method="holm",prep=prep,group="grp")
 stopifnot(nrow(raw)==9L,identical(joined$p_adjusted,r$tables$effect_table$p_adjusted),all(joined$n_unweighted==80L),
  isTRUE(all.equal(raw$p.value, r$tables$effect_table$p_value,tolerance=1e-12)),
  all(r$tables$effect_table$p_adjusted>=r$tables$effect_table$p_value-1e-8))
 native <- r$metadata$emmeans$summaries$contrasts_adjusted$native_messages
 stopifnot(any(grepl("P value adjustment: holm",native,fixed=TRUE)),any(grepl("Conf-level adjustment: bonferroni",native,fixed=TRUE)),
  !r$metadata$emmeans$refit_performed,!r$metadata$emmeans$global_emmeans_options_changed)
 refuse(port$diff_effect_rows(raw,adj[-1,],"visit","bad-key",FALSE,"hash",adjust_method="holm"),"OS_INVALID_RESULT")
 for(nm in names(r$tables)) utils::write.csv(r$tables[[nm]],file.path(out,paste0("three_group_",nm,".csv")),row.names=FALSE)
})
check("same model identity and finite df retained for means, contrasts and interaction",{
 r <- emmeans_contrast_compute(a,up);m <- r$metadata$emmeans
 stopifnot(m$model_sha256==digest::digest(file=up$objects$model$path,algo="sha256"),m$df_limit==3000L,
  all(is.finite(m$df_actual_contrasts)),all(is.finite(m$df_actual_joint)),sum(r$tables$interaction_tests$is_group_time_interaction)==1L,
  identical(r$tables$interaction_tests$df1,r$tables$joint_tests_native$df1),
  identical(r$tables$interaction_tests$design_df,r$tables$joint_tests_native$df2))
})
for(flag in c("by","time-levels","dataset-name")) check(paste("required explicit longitudinal choice",flag),{
 b <- a;b[[flag]] <- NULL;refuse(emmeans_contrast_compute(b,up),"OS_MISSING_PARAMETER")
})
for(mut in list(list(adjust="tukey"),list(`df-method`="asymptotic"),list(`time-levels`="visit1,visit2"),list(`dataset-name`="two\nlines"))) check(paste("unsupported mode setting",names(mut)),{
 refuse(emmeans_contrast_compute(utils::modifyList(a,mut),up),"OS_INVALID_PARAMETER")
})
for(flag in c("time-levels","dataset-name","holm")) check(paste("new choices require opt-in",flag),{
 b <- a;b$longitudinal <- FALSE;b[["time-levels"]] <- NULL;b[["dataset-name"]] <- NULL;b$adjust <- "none"
 if(flag=="holm")b$adjust <- "holm" else b[[flag]] <- a[[flag]]
 refuse(emmeans_contrast_compute(b,up),"OS_CONFLICTING_PARAMETERS")
})
frame <- function(z,order=a[["time-levels"]]) os_longitudinal_frame(z,"id","grp","visit","y",order)
check("duplicate unit/time refused before any aggregation",{refuse(frame(rbind(mf,mf[1,])),"OS_INVALID_DESIGN")})
check("changing group within a biological unit refused",{z <- mf;z$grp[1] <- "B";refuse(frame(z),"OS_INVALID_DESIGN")})
check("empty observed group-time cell refused",{refuse(frame(mf[!(mf$grp=="B" & mf$visit=="visit3"),]),"OS_INVALID_DESIGN")})
check("missing/nonfinite outcome refused without complete-case filtering",{z <- mf;z$y[1] <- NA_real_;refuse(frame(z),"OS_INVALID_INPUT")})
check("numeric time is not silently coerced into categorical time",{z <- mf;z$visit <- as.numeric(z$visit);refuse(frame(z),"OS_INVALID_DESIGN")})
check("every subject must represent repeated units, not independent cross-sections",{
 z <- mf;z$id <- factor(seq_len(nrow(z)));refuse(frame(z),"OS_INVALID_DESIGN")
})
check("chronology is display-only; source dropout scan is retained",{
 z <- mf[-2,];before <- lc_original_environment(here)
 a_scan <- before$scan_waves(z,"id","visit",c("visit1","visit2","visit3"))
 b_scan <- os_longitudinal_port()$scan_waves(z,"id","visit",c("visit1","visit2","visit3"))
 stopifnot(identical(a_scan,b_scan),!a_scan$monotone,a_scan$n_non_monotone==1L)
})
check("the same fit must contain the explicit interaction",{
 no_interaction <- lc_fixture_fit(d,file.path(out,"additive"),"y ~ grp + visit + (1 | id)")
 refuse(emmeans_contrast_compute(a,no_interaction$up),"OS_INVALID_DESIGN")
})
check("upstream state, metadata and study digest are independently checked",{
 b <- up;b$state$model_ready <- FALSE;refuse(emmeans_contrast_compute(a,b),"OS_CHAIN_STATE")
 z <- a;z[["study-contract-sha256"]] <- paste(rep("1",64),collapse="");refuse(emmeans_contrast_compute(z,up),"OS_HANDOFF_MISMATCH")
 bad_meta <- fx$result$metadata;bad_meta$n_obs <- bad_meta$n_obs+1L;mp <- file.path(out,"bad_metadata.rds");saveRDS(bad_meta,mp)
 b <- up;b$objects$metadata$path <- mp;refuse(emmeans_contrast_compute(a,b),"OS_HANDOFF_MISMATCH")
})
check("copied singularity guard rejects a mutated degenerate fit without refitting",{
 z <- fit;z@theta[] <- 0
 # Capture aggregate model diagnostics before the original assertion. This does
 # not repair a fit, replace the singularity rule, or relax the failing test.
 observe <- function(expr) tryCatch(list(value=force(expr),error=NULL),error=function(e)list(value=NULL,error=conditionMessage(e)))
 diagnostics <- function(m) list(class=class(m),slots=methods::slotNames(m),
  theta_slot=observe(m@theta),theta_getME=observe(lme4::getME(m,"theta")),
  isSingular=observe(lme4::isSingular(m,tol=1e-4)),
  variance_components=observe(as.data.frame(lme4::VarCorr(m))),
  copied_guard=observe(os_longitudinal_port()$.lc_singular(m)))
 jsonlite::write_json(list(R=as.character(getRversion()),lme4=as.character(utils::packageVersion("lme4")),
  mutation="z <- fit; z@theta[] <- 0",original=diagnostics(fit),mutated=diagnostics(z),
  unchanged_tolerance=1e-4,synthetic_source_fixture_only=TRUE),
  file.path(out,"SINGULARITY_DIAGNOSTICS.json"),auto_unbox=TRUE,pretty=TRUE,digits=NA,null="null")
 stopifnot(os_longitudinal_port()$.lc_singular(z)$degenerate)
 p <- file.path(out,"degenerate.rds");saveRDS(z,p);b <- up;b$objects$model$path <- p
 refuse(emmeans_contrast_compute(a,b),"OS_NUMERICAL_DEGENERACY")
})
check("shared figure reads model tables, preserves numeric values and dataset identity",{
 source(file.path(root,"skills/_shared/scripts/fig_all.R"))
 r <- emmeans_contrast_compute(a,up);t <- r$tables$marginal_means
 draw <- data.frame(time=factor(t$visit,levels=r$metadata$emmeans$time_order),group=t$grp,
  estimate=t$emmean,ci_low=t$lower.CL,ci_high=t$upper.CL)
 saved <- draw;p <- os_experiment_longitudinal_emm(draw,r$metadata$emmeans,r$metadata)
 meta <- attr(p,"os_meta");layer <- meta$definition$layers[[1]]
 stopifnot(identical(saved,draw),grepl(a[["dataset-name"]],meta$caption,fixed=TRUE),
  layer$data_role=="model_grid",is.null(layer$n_independent),is.null(meta$definition$numerator),
  is.null(meta$definition$denominator),layer$uncertainty$coverage_scope=="pointwise",
  meta$notes$render_source_binding$status=="exact_source_hash_and_keys",
  layer$source_sha256==os_semantic_table_sha256(draw,.os_sem_rows(draw,c("time","group"))))
 bad <- draw;bad$ci_high[1] <- NA_real_;refuse(os_experiment_longitudinal_emm(bad,r$metadata$emmeans,r$metadata),"OS_INVALID_INPUT")
 bad <- draw;bad$ci_low[1] <- bad$ci_high[1]+1;refuse(os_experiment_longitudinal_emm(bad,r$metadata$emmeans,r$metadata),"OS_INVALID_INPUT")
 bad <- r$metadata$emmeans;bad$model_sha256 <- "missing-model";refuse(os_experiment_longitudinal_emm(draw,bad,r$metadata),"OS_INVALID_INPUT")
 refuse(os_experiment_longitudinal_emm(rbind(draw,draw[1,]),r$metadata$emmeans,r$metadata),"OS_INVALID_INPUT")
 ggplot2::ggplot_build(p)
})
check("new native formals captured only from the actual independent installed runtime",{
 source(file.path(root,"skills/_shared/scripts/calls_check.R"))
 registry <- file.path(dirname(here),"scripts/calls_registry.json")
 checked <- check_calls(list.files(file.path(dirname(here),"scripts"),pattern="\\.R$",full.names=TRUE),registry)
 stopifnot(checked$ok,check_default_drift(registry)$ok)
 functions <- c("emmeans::emmeans","emmeans::contrast","emmeans::joint_tests","lme4::isSingular","lme4::VarCorr")
 observed <- lapply(functions,function(name) {
  bits <- strsplit(name,"::",fixed=TRUE)[[1]];f <- getExportedValue(bits[1],bits[2]);fm <- formals(f)
  list(fn=name,package_version=as.character(utils::packageVersion(bits[1])),
   actual_formals=as.list(vapply(names(fm),function(arg)paste(deparse(fm[[arg]]),collapse=""),"")))
 })
 jsonlite::write_json(list(R=as.character(getRversion()),captured_in_this_native_run=TRUE,signatures=observed),
  file.path(out,"ACTUAL_INSTALLED_FORMALS.json"),auto_unbox=TRUE,pretty=TRUE)
})
passed <- vapply(checks,function(x)isTRUE(x$passed),logical(1))
jsonlite::write_json(list(R=as.character(getRversion()),checks=checks,failed=sum(!passed),synthetic_contract_only=TRUE,
 owner_review_passed=FALSE),file.path(out,"NATIVE_CONTRACTS.json"),auto_unbox=TRUE,pretty=TRUE)
quit(status=as.integer(any(!passed)),save="no")
