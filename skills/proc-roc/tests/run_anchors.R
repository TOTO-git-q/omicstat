# Retain the original synthetic counted numerical anchor; this is not owner data.
args <- commandArgs(FALSE); .here <- dirname(normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1])))
source(file.path(.here, "test_helpers.R")); roc_test_require_native()
x <- commandArgs(TRUE); get <- function(k) {i <- match(k, x); if (is.na(i) || i == length(x)) stop(paste("missing", k)); x[i+1L]}
run <- get("--run"); fixtures <- get("--fixtures"); output <- get("--results")
if (!file.exists(file.path(run, "provenance", "resolved_spec.json"))) stop("OS_MISSING_FILE: successful canonical execution required")
d <- utils::read.csv(file.path(fixtures, "measurements.csv")); sheet <- utils::read.csv(file.path(fixtures, "sample_sheet.csv"))
stopifnot(identical(d$id, sheet$id)); truth <- as.character(sheet$truth)
eff <- roc_test_table(run, "auc_summary"); acc <- roc_test_table(run, "accuracy_primary")
out <- list(); add <- function(key, value) out[[key]] <<- unname(value)
value <- function(k) acc$estimate[match(k, acc$term)]
tp <- sum(d$marker1 >= .5 & truth == "1"); fn <- sum(d$marker1 < .5 & truth == "1")
fp <- sum(d$marker1 >= .5 & truth == "0"); tn <- sum(d$marker1 < .5 & truth == "0")
add("sensitivity", value("sensitivity")); add("specificity", value("specificity")); add("ppv", value("positive_predictive_value")); add("auc_pair_count", eff$estimate[1])
ind <- roc_oracle_auc(d$marker1, truth); z <- stats::qnorm(.975)
add("auc_delong_ci_low_delta", eff$ci_low[1] - max(0, ind$auc-z*sqrt(ind$variance)))
add("auc_delong_ci_high_delta", eff$ci_high[1] - min(1, ind$auc+z*sqrt(ind$variance)))
before <- new.env(parent = baseenv()); sys.source(file.path(roc_test_module, "scripts", "roc_ported_core.R"), envir = before)
# The copied-original numerical function is bound by COPIED_FUNCTIONS hashes;
# this is a same-input adapter comparison, not re-execution of MedStat's report.
original <- before$fit_full_roc(factor(truth, levels=c("0","1")), d$marker1, c("0","1"), "<", .95)
add("same_input_before_after_auc_delta", eff$estimate[1]-original$auc)
root_out <- file.path(dirname(output), "additional-original-contracts")
if (dir.exists(root_out) && length(list.files(root_out, all.files=TRUE,no..=TRUE))) stop("Use a fresh anchor evidence directory; keep prior failures")
a <- roc_test_args(fixtures); a$markers <- "marker1,marker2,marker3"; a[["p-adjust"]] <- "holm"; a[["comparison-family"]] <- "primary-versus-rest"
multi <- roc_test_run(a, "paired", root_out); ct <- roc_test_table(multi, "auc_comparison")
oracle <- roc_oracle_compare(d$marker1,d$marker2,truth)
add("paired_delong_p_delta", ct$p_raw[1]-oracle$p); add("paired_auc_difference_delta",ct$estimate[1]-oracle$difference)
# Independent Holm step-down arithmetic for the explicitly sized family.
raw <- ct$p_raw; o <- order(raw); adj <- numeric(length(raw)); adj[o] <- pmin(1, cummax((length(raw)-seq_along(raw)+1)*raw[o]))
add("holm_adjustment_delta", max(abs(ct$p_adjusted-adj)))
a <- roc_test_args(fixtures); a[["ci-method"]] <- "wilson"
wilson <- roc_test_table(roc_test_run(a,"wilson",root_out),"accuracy_primary")
add("wilson_sensitivity_low_delta",wilson$ci_low[wilson$term=="sensitivity"]-roc_oracle_wilson(tp,tp+fn,.95)[1])
se <- tp/(tp+fn); sp <- tn/(tn+fp); lr <- se/(1-sp); se_log <- sqrt(1/tp-1/(tp+fn)+1/fp-1/(tn+fp))
add("simel_lr_positive_delta",value("lr_positive")-lr)
add("simel_lr_positive_low_delta",acc$ci_low[acc$term=="lr_positive"]-exp(log(lr)-z*se_log))
expected <- jsonlite::fromJSON(file.path(.here,"anchors.json"), simplifyVector=FALSE)
bad <- vapply(expected,function(r)length(out[[r$id]])!=1||!is.finite(out[[r$id]])||abs(out[[r$id]]-r$expected)>r$tolerance,logical(1))
dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE);jsonlite::write_json(out,output,auto_unbox=TRUE,pretty=TRUE,digits=17,na="null")
cat(sprintf("Original synthetic counted case plus %d checks; %d failures. No owner real-data claim.\n",length(expected),sum(bad)))
if(any(bad))quit(status=1)
