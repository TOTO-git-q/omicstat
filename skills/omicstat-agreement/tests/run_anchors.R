# Original three published examples (public textbook tables, committed under
# tests/fixtures/published_anchor_inputs; no patient-level clinical records).
a <- commandArgs(FALSE); .here <- dirname(normalizePath(sub("^--file=", "", a[grepl("^--file=", a)][1])))
source(file.path(.here, "test_helpers.R")); ag_test_require_native()
x <- commandArgs(TRUE); get <- function(k) {i <- match(k,x);if(is.na(i)||i==length(x))stop(paste("missing",k));x[i+1L]}
output <- get("--results"); fixtures <- get("--fixtures"); canonical <- get("--run")
if (!file.exists(file.path(canonical,"provenance","resolved_spec.json"))) stop("OS_MISSING_FILE: canonical contract run is absent",call.=FALSE)
# The three public published tables ship with the repository; the environment
# variables remain as optional overrides (the same identity check applies).
external <- Sys.getenv("OMICSTAT_AGREEMENT_ANCHOR_DIR", "")
if (!nzchar(external)) external <- file.path(.here,"fixtures","published_anchor_inputs")
private <- Sys.getenv("OMICSTAT_AGREEMENT_PRIVATE_ANCHOR_OUT", "")
if (!nzchar(private)) private <- tempfile("agreement-anchor-work-")
external <- normalizePath(external, mustWork=TRUE); private <- normalizePath(private,mustWork=FALSE)
inside <- function(path,root) identical(path,root)||startsWith(path,paste0(root,.Platform$file.sep))
if (inside(private,ag_test_root)||inside(private,dirname(normalizePath(output,mustWork=FALSE))))
  stop("OS_INVALID_INPUT: the scratch work directory must stay outside the repository and the shareable evidence tree",call.=FALSE)
if (dir.exists(private) && length(list.files(private,all.files=TRUE,no..=TRUE))) stop("Use a new anchor work directory; preserve previous failures",call.=FALSE)
dir.create(private,recursive=TRUE,showWarnings=FALSE)
python <- Sys.getenv("OMICSTAT_PYTHON", "python3")
status <- system2(python,shQuote(c(file.path(.here,"verify_official_inputs.py"),"--source",external,"--receipt",file.path(private,"input_identity.json"))))
if (status!=0) stop("OS_INVALID_INPUT: external original anchor identity was not verified",call.=FALSE)
# All local-only outputs can contain source observations. Only aggregate
# anchors.obtained.json and redacted summary are suitable for publication.
writeLines("Scratch work directory of the agreement anchor run (public published example tables; safe to delete).",file.path(private,"SCRATCH.txt"))
out <- list(); add <- function(name,value) out[[name]] <<- unname(value)
base <- function(route,dataset,labels) {
  a <- ag_test_args(route,fixtures); a[["dataset-name"]] <- dataset
  path <- file.path(private,paste0(route,"-labels.json"));jsonlite::write_json(labels,path,auto_unbox=TRUE)
  a$labels <- path; a[["unit-description"]] <- "Original published independent-unit worked example; no repeated observations"
  contract <- jsonlite::fromJSON(file.path(fixtures,"study_contract.json"),simplifyVector=FALSE)
  contract$study_design <- paste("Original published worked example:",dataset)
  contract$analysis_population <- labels$population
  contract$estimand <- paste("Published original",route,"anchor with its explicit design and unchanged numerical oracle")
  contract$outcomes <- list(list(name=labels$measurement,timepoint="Original specified paired/rating occasion"))
  contract$analysis_sets <- list("Local-only original anchor validation; not real-data owner figure approval")
  cpath <- file.path(private,paste0(route,"-contract.json"));jsonlite::write_json(contract,cpath,auto_unbox=TRUE)
  a[["study-contract"]] <- cpath
  a
}
lv <- c("terrible","poor","marginal","clear")
a <- base("kappa","SAS SkinCondition published 4 by 4 agreement table",
  c(list(derm1="Dermatologist 1",derm2="Dermatologist 2",population="Original published dermatology example",measurement="Skin condition rating"),as.list(stats::setNames(lv,lv))))
a$input <- file.path(external,"skin.csv");a$format <- "counts";a[["id-col"]] <- NULL;a[["rater-cols"]] <- "derm1,derm2";a[["count-col"]] <- "n"
a[["independent-unit"]] <- "aggregate-unit";a$levels <- paste(lv,collapse=",")
skin <- utils::read.csv(a$input,stringsAsFactors=FALSE);tab <- matrix(skin$n,4,4,byrow=TRUE)
run <- ag_test_run(a,"skin",private);e <- ag_test_table(run,"effect_table"); idx <- outer(1:4,1:4,function(i,j)abs(i-j))
weights <- list(none=diag(4),linear=1-idx/3,quadratic=1-idx^2/9);z <- stats::qnorm(.975)
for(w in names(weights)) {
  row <- e[e$term==paste0("kappa_",w),,drop=FALSE];ref <- ag_oracle_fce(tab,weights[[w]])
  for (part in c("estimate","ci_low","ci_high")) add(paste0("skin_",w,"_",part,"_delta"),row[[part]]-switch(part,estimate=ref$kappa,ci_low=ref$kappa-z*ref$ase,ci_high=ref$kappa+z*ref$ase))
}
row <- e[e$term=="kappa_none",,drop=FALSE]
add("skin_kappa_published",row$estimate);add("skin_lower_published",row$ci_low);add("skin_upper_published",row$ci_high)
a <- base("bland-altman","Bland and Altman 1986 PEFR first paired readings (published source data)",
  list(wright="Wright peak flow meter",mini="Mini Wright peak flow meter",population="Original published PEFR example",measurement="Peak expiratory flow rate"))
a$input <- file.path(external,"pefr.csv");a[["id-col"]] <- "subject";a[["method-a-col"]] <- "wright";a[["method-b-col"]] <- "mini"
a[["independent-unit"]] <- "donor";a[["outcome-unit"]] <- "litres per minute"
run <- ag_test_run(a,"pefr",private);e <- ag_test_table(run,"effect_table");d <- utils::read.csv(a$input)
got <- ag_ba_values(e);ref <- ag_oracle_ba(d$wright,d$mini)
for(k in names(ref))add(paste0("pefr_",k,"_delta"),got[k]-ref[k])
add("pefr_bias_published",e$estimate[1]);add("pefr_ci_low_published",e$ci_low[1]);add("pefr_ci_high_published",e$ci_high[1])
a <- base("icc","Shrout and Fleiss 1979 Table 2 targets and judges",list(j1="Judge 1",j2="Judge 2",j3="Judge 3",j4="Judge 4",population="Published target-rating example",measurement="Rating"))
a$input <- file.path(external,"sf.csv");a[["id-col"]] <- "target";a[["rater-cols"]] <- "j1,j2,j3,j4";a[["outcome-unit"]] <- "rating points"
d <- utils::read.csv(a$input);ref <- ag_oracle_icc(as.matrix(d[c("j1","j2","j3","j4")]))
for(typ in c("21","31")) {
  a[["rater-population"]] <- if(typ=="21")"random" else "fixed";a[["icc-definition"]] <- if(typ=="21")"agreement" else "consistency"
  e <- ag_test_table(ag_test_run(a,paste0("icc",typ),private),"effect_table")
  add(paste0("icc",typ,"_published"),e$estimate);add(paste0("icc",typ,"_delta"),e$estimate-ref[paste0("icc",typ)])
  if(typ=="31") {add("icc31_ci_low_delta",e$ci_low-ref['icc31_low']);add("icc31_ci_high_delta",e$ci_high-ref['icc31_high'])}
}
expected <- jsonlite::fromJSON(file.path(.here,"anchors.json"),simplifyVector=FALSE)
bad <- vapply(expected,function(row)length(out[[row$id]])!=1||!is.finite(out[[row$id]])||abs(out[[row$id]]-row$expected)>row$tolerance,logical(1))
dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
jsonlite::write_json(out,output,auto_unbox=TRUE,pretty=TRUE,na="null",digits=17)
cat(sprintf("Original three cases, %d aggregate anchor checks, %d failures; published example tables.\n",length(expected),sum(bad)))
if(any(bad))quit(status=1)
