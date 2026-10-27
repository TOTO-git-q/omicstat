# requires: pwr gsDesign jsonlite digest ggplot2
# All native execution is in the independent OmicStat R4.6.1 environment.
a <- commandArgs(FALSE); .here <- dirname(normalizePath(sub("^--file=", "", a[grepl("^--file=", a)][1])))
source(file.path(.here, "test_helpers.R")); ss_require_native()
out <- Sys.getenv("OMICSTAT_SAMPLESIZE_TEST_OUT", tempfile("omicstat-samplesize-native-"))
if (dir.exists(out) && length(list.files(out, all.files = TRUE, no.. = TRUE))) stop("Use a fresh native evidence directory")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
fixtures <- file.path(out, "fixtures"); dir.create(fixtures)
stopifnot(file.copy(file.path(.here, "fixtures", "study_contract.json"), fixtures, overwrite = FALSE))
ncheck <- 0L; failures <- character()
check <- function(value, label) {
  ncheck <<- ncheck + 1L
  if (isTRUE(value)) cat("PASS:", label, "\n") else {
    cat("FAIL:", label, "\n"); failures <<- c(failures, label)
  }
}
a <- ss_base("unused", fixtures)
canonical <- ss_run(a, "canonical", out)
obtained <- ss_oracles(canonical$out, fixtures, file.path(out, "anchors"))
expected <- jsonlite::fromJSON(file.path(.here, "anchors.json"), simplifyVector = FALSE)
for (row in expected) check(is.finite(obtained[[row$id]]) && abs(obtained[[row$id]] - row$expected) <= row$tolerance,
                           paste("original/supplementary native anchor", row$id))
jsonlite::write_json(obtained, file.path(out, "anchors.obtained.json"), auto_unbox = TRUE, pretty = TRUE, digits = 17)

# Actual resolved-spec replay; compare all numeric table bytes without re-creating goldens.
replay <- ss_run(a, "replay", out, argv = c("--spec", file.path(canonical$out, "provenance", "resolved_spec.json"),
  "--outdir", file.path(out, "replay")))
for (name in c("plan", "biological_groups", "scenarios", "planning_effect")) {
  p1 <- file.path(canonical$out, "tables", paste0(name, ".csv"))
  p2 <- file.path(replay$out, "tables", paste0(name, ".csv"))
  check(identical(digest::digest(file = p1, algo = "sha256"), digest::digest(file = p2, algo = "sha256")), paste("same-input table replay", name))
}
groups <- ss_table(canonical, "biological_groups"); plan <- ss_table(canonical, "plan")
check(all(groups$planned_technical_measurements == 3 * groups$n_biological_recruit), "technical measurement budget is separate")
one <- a; one[["technical-replicates"]] <- "1"
one_run <- ss_run(one, "one_technical_measurement", out)
check(identical(plan, ss_table(one_run, "plan")), "technical repeat number cannot change biological N")
effect <- ss_table(canonical, "planning_effect")
check(effect$estimate == -.5 && all(is.na(effect$ci_low)) && all(is.na(effect$ci_high)), "signed planning assumption has no fabricated CI")
check(effect$effect_scale == "mean_difference_group1_minus_group2" && grepl("not_estimated", effect$value_role), "groupcompare orientation is explicit and not an estimated effect handoff")
scenarios <- ss_table(canonical, "scenarios")
check(all(diff(scenarios$n_biological_total) >= 0), "higher target power never lowers required biological N")

paired_a <- ss_variant(a, "mean_paired")
paired <- ss_run(paired_a, "paired_counts", out)
pg <- ss_table(paired, "biological_groups"); pp <- ss_table(paired, "plan")
check(pp$n_biological_total == pp$n1 && pp$n1 == pp$n2, "paired biological units counted once")
check(all(pg$shared_units_across_conditions) && pp$n_biological_recruit_total == pg$n_biological_recruit[1], "paired recruitment counts shared units once")
derived <- paired_a; derived[["sd-diff"]] <- NULL; derived$sd1 <- "1"; derived$sd2 <- "1"; derived$corr <- "0.5"
derived_run <- ss_run(derived, "paired_sd_from_correlation", out)
check(identical(pp, ss_table(derived_run, "plan")), "equivalent paired SD declarations agree")

surv <- ss_variant(a, "survival_logrank"); surv[["event-prob"]] <- NULL
events_run <- ss_run(surv, "events_only", out); ep <- ss_table(events_run, "plan")
check(ep$required_events == 196 && is.na(ep$n_biological_total) && is.na(ep$n_biological_recruit_total), "events-only does not fabricate biological N")
drop <- a; drop$dropout <- "0.15"
drop_run <- ss_run(drop, "attrition", out); dg <- ss_table(drop_run, "biological_groups"); dp <- ss_table(drop_run, "plan")
check(dp$n_biological_total == plan$n_biological_total && dp$n_biological_recruit_total == sum(ceiling(dg$n_biological_analyzable/.85)), "attrition inflates recruitment, not analyzable N")

ratio <- a; ratio$ratio <- "2"
ratio_run <- ss_run(ratio, "ratio_two", out); rp <- ss_table(ratio_run, "plan")
pw <- pwr::pwr.t2n.test(n1 = rp$n1, n2 = rp$n2, d = .5, sig.level = .05, alternative = "two.sided")$power
pw_prev <- pwr::pwr.t2n.test(n1 = rp$n1 - 1, n2 = ceiling((rp$n1 - 1) * 2), d = .5, sig.level = .05, alternative = "two.sided")$power
check(rp$n2 == 2 * rp$n1 && pw >= .8 && pw_prev < .8, "original unequal-allocation native minimality oracle")
source(file.path(ss_module, "scripts", "omicstat_samplesize_core.R"))
port <- os_samplesize_port()
check(port$.bisect_n1(function(n) 1, .8) == 2, "reproducible old lower-endpoint defect fixed")
check(port$.bisect_n1(function(n) n/20, .8, lo = 2, hi = 30) == 16, "integer search retains interior crossing")
check(port$.bisect_n1(function(n) n/20, 1, lo = 2, hi = 20) == 20, "integer search preserves the upper endpoint")
boundary <- ratio; boundary$mean2 <- "100"
br <- ss_table(ss_run(boundary, "large_effect_boundary", out), "plan")
check(br$n1 == 2 && br$n2 == 4, "native large-effect power at lower endpoint does not round up to three")
small_ratio <- ratio; small_ratio$ratio <- "0.25"
sr <- ss_table(ss_run(small_ratio, "small_ratio", out), "plan")
check(sr$n1 >= 5 && sr$n2 >= 2 && sr$n2 == ceiling(sr$n1*.25), "both native arms retain at least two units")
small_boundary <- small_ratio; small_boundary$mean2 <- "100"
sb <- ss_table(ss_run(small_boundary, "small_ratio_lower_boundary", out), "plan")
check(sb$n1 == 5 && sb$n2 == 2, "minimal rounded allocation at ratio 0.25 does not over-recruit to eight")

# Scientific guard conditions copied from SS-01..SS-06; no automatic convention choice.
q <- port$run_qc_ss(list(design="survival_logrank", dropout=0, effect_from_convention=TRUE,
  power=.7, event_prob=NULL, ratio=5, alpha=.03))
check(identical(q$id, paste0("SS-0", 1:6)) && all(q$triggered), "six original source guards still fire")
q <- port$run_qc_ss(list(design="mean_2sample", dropout=.1, effect_from_convention=FALSE,
  power=.8, event_prob=NULL, ratio=1, alpha=.05))
check(!any(q$triggered), "six original source guards keep their non-trigger conditions")

rows <- utils::read.csv(file.path(.here, "refusals.csv"), stringsAsFactors = FALSE, check.names = FALSE)
refusal_results <- list()
for (i in seq_len(nrow(rows))) {
  args <- unlist(jsonlite::fromJSON(rows$argv[i]), use.names = FALSE)
  folder <- file.path(out, "refusals", rows$case[i])
  args <- gsub("{fixtures}", fixtures, args, fixed = TRUE)
  args <- gsub("{outdir}", folder, args, fixed = TRUE)
  rr <- ss_run(a, rows$case[i], file.path(out, "refusal_logs"), expect_ok = FALSE, argv = args)
  log <- paste(readLines(rr$log, warn = FALSE), collapse = "\n")
  ok <- rr$status != 0 && grepl(rows$expected_code[i], log, fixed = TRUE) && !dir.exists(file.path(folder, "tables"))
  check(ok, paste("typed refusal", rows$case[i]))
  refusal_results[[i]] <- list(case=rows$case[i],expected_code=rows$expected_code[i],status=rr$status,pass=ok,log=rr$log)
}
jsonlite::write_json(refusal_results, file.path(out, "refusals.obtained.json"), auto_unbox=TRUE,pretty=TRUE)
specs <- list.files(file.path(canonical$out,"figures"),pattern="figure_spec.*json$",full.names=TRUE,recursive=TRUE)
check(length(specs)>0, "real emitted figure specifications exist")
for (path in specs) {
  text <- paste(readLines(path,warn=FALSE),collapse="\n")
  check(grepl("model_grid",text,fixed=TRUE) && grepl("no_observed_sample_count",text,fixed=TRUE), "planning grid is never counted as observations")
}
versions <- stats::setNames(vapply(c("pwr","gsDesign","jsonlite","digest","ggplot2"), function(p) as.character(utils::packageVersion(p)), ""),
                           c("pwr","gsDesign","jsonlite","digest","ggplot2"))
jsonlite::write_json(list(R=as.character(getRversion()),packages=as.list(versions),checks=ncheck,failures=as.list(failures),
  scope="Fresh R4.6.1 scientific/CLI contract tests only; exact dependency source closure and registered real owner contact sheet are separate gates",
  golden_written=FALSE,seal_written=FALSE),file.path(out,"native_test_summary.json"),auto_unbox=TRUE,pretty=TRUE)
cat(sprintf("%d native checks; %d failures. Evidence: %s\n",ncheck,length(failures),out))
if (length(failures)) quit(status=1)
