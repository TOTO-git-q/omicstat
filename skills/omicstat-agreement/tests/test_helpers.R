# All helper execution uses OmicStat sources and its independent native library.
ag_test_root <- normalizePath(file.path(.here, "..", "..", ".."), mustWork = TRUE)
ag_test_module <- file.path(ag_test_root, "skills", "omicstat-agreement")
ag_test_require_native <- function() {
  if (as.character(getRversion()) != "4.6.1") stop("OS_ENVIRONMENT_MISMATCH: agreement acceptance requires R 4.6.1; another R does not substitute", call. = FALSE)
  for (pkg in c("vcd", "irr", "epiR", "jsonlite", "digest", "ggplot2"))
    if (!requireNamespace(pkg, quietly = TRUE)) stop(paste0("OS_MISSING_PACKAGE: ", pkg, " absent in independent OmicStat library"), call. = FALSE)
}
ag_test_args <- function(route, fixtures) {
  a <- jsonlite::fromJSON(file.path(ag_test_module, "tests", "route_parameters.json"), simplifyVector = FALSE)[[route]]
  lapply(a, function(x) gsub("{fixtures}", fixtures, x, fixed = TRUE))
}
ag_test_argv <- function(a) c(unlist(lapply(names(a), function(k) if (!is.null(a[[k]])) c(paste0("--", k), as.character(a[[k]]))), use.names = FALSE), "--development-mode")
ag_test_run <- function(a, label, root_out, expect_ok = TRUE, argv = NULL) {
  a$outdir <- file.path(root_out, label)
  if (is.null(argv)) argv <- ag_test_argv(a)
  logfile <- file.path(root_out, paste0(label, ".log")); dir.create(root_out, recursive = TRUE, showWarnings = FALSE)
  status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(c(file.path(ag_test_module, "scripts", "run_omicstat_agreement.R"), argv)), stdout = logfile, stderr = logfile)
  if (expect_ok && status != 0) stop(paste(c(paste("Native CLI failed", label, status), readLines(logfile, warn = FALSE)), collapse = "\n"), call. = FALSE)
  list(out = a$outdir, status = status, log = logfile)
}
ag_test_table <- function(run, name) utils::read.csv(file.path(run$out, "tables", paste0(name, ".csv")), check.names = FALSE, stringsAsFactors = FALSE)
ag_test_metadata <- function(run) readRDS(file.path(run$out, "objects", "metadata.rds"))

# Independent original-source FCE formula. This oracle never calls vcd/irr/epiR.
ag_oracle_fce <- function(counts, w) {
  n <- sum(counts); pij <- counts / n; k <- nrow(pij)
  pr <- rowSums(pij); pc <- colSums(pij); po <- sum(w * pij); pe <- sum(w * outer(pr, pc)); kap <- (po - pe)/(1-pe)
  wi <- as.vector(w %*% pc); wj <- as.vector(t(w) %*% pr); term <- 0
  for (i in seq_len(k)) for (j in seq_len(k)) term <- term + pij[i,j]*(w[i,j]-(wi[i]+wj[j])*(1-kap))^2
  variance <- (term-(kap-pe*(1-kap))^2)/((1-pe)^2*n)
  list(kappa=kap,ase=sqrt(variance))
}
ag_oracle_ba <- function(a, b, conf = .95) {
  d <- a-b; n <- length(d); s <- stats::sd(d); bias <- mean(d); t <- stats::qt((1+conf)/2,n-1)
  se <- s*sqrt(1/n+1.96^2/(2*(n-1))); lo <- bias-1.96*s; hi <- bias+1.96*s
  c(bias=bias,bias_low=bias-t*s/sqrt(n),bias_high=bias+t*s/sqrt(n),loa_lower=lo,loa_upper=hi,
    loa_lower_low=lo-t*se,loa_lower_high=lo+t*se,loa_upper_low=hi-t*se,loa_upper_high=hi+t*se)
}
ag_ba_values <- function(e) c(bias=e$estimate[1],bias_low=e$ci_low[1],bias_high=e$ci_high[1],
  loa_lower=e$estimate[2],loa_upper=e$estimate[3],loa_lower_low=e$ci_low[2],loa_lower_high=e$ci_high[2],loa_upper_low=e$ci_low[3],loa_upper_high=e$ci_high[3])
ag_oracle_icc <- function(x, conf = .95) {
  n <- nrow(x); k <- ncol(x); gm <- mean(x)
  sr <- k*sum((rowMeans(x)-gm)^2); sc <- n*sum((colMeans(x)-gm)^2); st <- sum((x-gm)^2)
  bms <- sr/(n-1); jms <- sc/(k-1); ems <- (st-sr-sc)/((n-1)*(k-1))
  f <- bms/ems; fl <- f/stats::qf((1+conf)/2,n-1,(n-1)*(k-1)); fu <- f*stats::qf((1+conf)/2,(n-1)*(k-1),n-1)
  c(icc21=(bms-ems)/(bms+(k-1)*ems+k*(jms-ems)/n),icc31=(bms-ems)/(bms+(k-1)*ems),
    icc31_low=(fl-1)/(fl+k-1),icc31_high=(fu-1)/(fu+k-1))
}
