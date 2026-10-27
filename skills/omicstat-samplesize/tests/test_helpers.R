# Shared only within this independent OmicStat module's tests.
ss_root <- normalizePath(file.path(.here, "..", "..", ".."), mustWork = TRUE)
ss_module <- file.path(ss_root, "skills", "omicstat-samplesize")
ss_require_native <- function() {
  if (as.character(getRversion()) != "4.6.1") stop("OS_ENVIRONMENT_MISMATCH: P0-13 native acceptance requires R 4.6.1; other R versions do not substitute", call. = FALSE)
  for (pkg in c("pwr", "gsDesign", "jsonlite", "digest", "ggplot2"))
    if (!requireNamespace(pkg, quietly = TRUE)) stop(paste0("OS_MISSING_PACKAGE: ", pkg, " absent in independent OmicStat environment"), call. = FALSE)
}
ss_base <- function(out, fixtures) {
  a <- jsonlite::fromJSON(file.path(ss_module, "tests", "base_parameters.json"), simplifyVector = FALSE)
  a$outdir <- out; a[["study-contract"]] <- file.path(fixtures, "study_contract.json")
  a
}
ss_argv <- function(a) c(unlist(lapply(names(a), function(k) if (!is.null(a[[k]])) c(paste0("--", k), as.character(a[[k]]))), use.names = FALSE), "--development-mode")
ss_run <- function(a, label, root_out, expect_ok = TRUE, argv = NULL) {
  a$outdir <- file.path(root_out, label)
  if (is.null(argv)) argv <- ss_argv(a)
  logfile <- file.path(root_out, paste0(label, ".log"));dir.create(root_out, recursive = TRUE, showWarnings = FALSE)
  status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(c(file.path(ss_module,"scripts/run_omicstat_samplesize.R"),argv)), stdout=logfile,stderr=logfile)
  if (expect_ok && status != 0) stop(paste(c(paste("Native CLI failed", label, status), readLines(logfile,warn=FALSE)),collapse="\n"),call.=FALSE)
  list(out=a$outdir,status=status,log=logfile)
}
ss_table <- function(run, name) utils::read.csv(file.path(run$out,"tables",paste0(name,".csv")),check.names=FALSE,stringsAsFactors=FALSE)
ss_variant <- function(a, design) {
  a[c("mean1","mean2","sd")] <- NULL;a$design <- design
  if (design=="mean_paired") {a[["mean-diff"]] <- "-0.5";a[["sd-diff"]] <- "1"}
  if (design=="anova") {a$k <- "3";a$f <- "0.25";a$groups <- "A,B,C";a$direction <- "omnibus"}
  if (design=="prop_2sample") {a$p1 <- "0.1";a$p2 <- "0.2"}
  if (design=="survival_logrank") {a$hr <- "0.67";a[["event-prob"]] <- "0.4"}
  a
}
ss_oracles <- function(canonical, fixtures, out) {
  mean_plan <- ss_table(list(out=canonical), "plan")
  n_base <- ceiling(stats::power.t.test(delta=.5,sd=1,sig.level=.05,power=.8,type="two.sample",alternative="two.sided")$n)
  if (n_base != 64 || mean_plan$n1 != n_base || mean_plan$n_biological_total != 2*n_base)
    stop("OS_INVALID_RESULT: SS-V1 independent base-R oracle differs",call.=FALSE)
  a <- ss_base("unused",fixtures)
  survival <- ss_run(ss_variant(a,"survival_logrank"),"oracle_survival",out)
  s <- ss_table(survival,"plan")
  event_base <- ceiling(4*(stats::qnorm(.975)+stats::qnorm(.8))^2/log(.67)^2)
  if (event_base != 196 || s$required_events != event_base || s$n_biological_total != ceiling(event_base/.4))
    stop("OS_INVALID_RESULT: SS-V2 independent Schoenfeld oracle differs",call.=FALSE)
  paired <- ss_table(ss_run(ss_variant(a,"mean_paired"),"oracle_paired",out),"plan")
  anova <- ss_table(ss_run(ss_variant(a,"anova"),"oracle_anova",out),"plan")
  prop <- ss_table(ss_run(ss_variant(a,"prop_2sample"),"oracle_proportions",out),"plan")
  stats::setNames(list(mean_plan$n1,mean_plan$n_biological_total,s$required_events,s$n_biological_total,
    paired$n1-ceiling(pwr::pwr.t.test(d=.5,sig.level=.05,power=.8,type="paired",alternative="two.sided")$n),
    anova$n1-ceiling(pwr::pwr.anova.test(k=3,f=.25,sig.level=.05,power=.8)$n),
    prop$n1-ceiling(pwr::pwr.2p.test(h=abs(pwr::ES.h(.1,.2)),sig.level=.05,power=.8,alternative="two.sided")$n)),
    c("SS-V1_mean_n1","SS-V1_mean_total","SS-V2_logrank_events","SS-V2_logrank_total",
      "paired_oracle_delta","anova_oracle_delta","proportions_oracle_delta"))
}
