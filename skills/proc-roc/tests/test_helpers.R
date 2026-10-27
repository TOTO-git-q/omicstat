# Independent OmicStat native lane only; synthetic rows are arithmetic contracts.
roc_test_root <- normalizePath(file.path(.here, "..", "..", ".."), mustWork = TRUE)
roc_test_module <- file.path(roc_test_root, "skills", "proc-roc")
roc_test_require_native <- function() {
  if (as.character(getRversion()) != "4.6.1") stop("OS_ENVIRONMENT_MISMATCH: ROC acceptance requires independent OmicStat R4.6.1", call. = FALSE)
  for (pkg in c("pROC", "jsonlite", "digest", "ggplot2")) if (!requireNamespace(pkg, quietly = TRUE)) stop(paste("OS_MISSING_PACKAGE:", pkg), call. = FALSE)
}
roc_test_args <- function(fixtures) {
  a <- jsonlite::fromJSON(file.path(roc_test_module, "tests", "base_parameters.json"), simplifyVector = FALSE)
  lapply(a, function(x) gsub("{fixtures}", fixtures, x, fixed = TRUE))
}
roc_test_argv <- function(a) c(unlist(lapply(names(a), function(k) if (!is.null(a[[k]])) c(paste0("--", k), as.character(a[[k]]))), use.names = FALSE), "--development-mode")
roc_test_run <- function(a, label, out) {
  a$outdir <- file.path(out, label); dir.create(out, recursive = TRUE, showWarnings = FALSE)
  logfile <- file.path(out, paste0(label, ".log"))
  status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(c(file.path(roc_test_module, "scripts", "run_proc_roc.R"), roc_test_argv(a))), stdout = logfile, stderr = logfile)
  if (status != 0) stop(paste(c(paste("Native CLI failed:", label, status), readLines(logfile, warn = FALSE)), collapse = "\n"), call. = FALSE)
  a$outdir
}
roc_test_table <- function(run, name) utils::read.csv(file.path(run, "tables", paste0(name, ".csv")), check.names = FALSE, stringsAsFactors = FALSE)
# Independent pair enumeration and DeLong placement covariance, no pROC call.
roc_oracle_auc <- function(score, truth) {
  positives <- score[truth == "1"]; negatives <- score[truth == "0"]
  pairs <- outer(positives, negatives, ">") + .5 * outer(positives, negatives, "==")
  v_pos <- rowMeans(pairs); v_neg <- colMeans(pairs)
  list(auc = mean(pairs), variance = stats::var(v_pos) / length(v_pos) + stats::var(v_neg) / length(v_neg), v_pos = v_pos, v_neg = v_neg)
}
roc_oracle_compare <- function(a, b, truth) {
  x <- roc_oracle_auc(a, truth); y <- roc_oracle_auc(b, truth)
  variance <- stats::var(x$v_pos - y$v_pos) / length(x$v_pos) + stats::var(x$v_neg - y$v_neg) / length(x$v_neg)
  d <- x$auc - y$auc
  list(difference = d, variance = variance, p = 2 * stats::pnorm(-abs(d / sqrt(variance))))
}
roc_oracle_wilson <- function(x, n, conf) {
  z <- stats::qnorm((1 + conf) / 2); prop <- x/n; denom <- 1 + z*z/n
  centre <- (prop + z*z/(2*n))/denom; half <- z * sqrt(prop*(1-prop)/n + z*z/(4*n*n))/denom
  c(centre-half, centre+half)
}
