# Standalone candidate smoke test; published anchors are separate.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module <- dirname(here); shared <- file.path(module, "..", "_shared", "scripts")
for (f in c("module_kit.R", "effect_table.R", "dose_scope_support.R")) source(file.path(shared, f))
source(file.path(module, "scripts", "nlme_dose_core.R"))
run <- function() {
 set.seed(713); ids <- c("01", "1", sprintf("D%02d", 3:16))
 d <- expand.grid(dose = c(.01, .03, .1, .3, 1, 3, 10, 30), subject = ids)
 shift <- stats::rnorm(16, 0, .5)
 d$response <- 100 / (1 + exp(-(log(d$dose) - log(1.6) - shift[match(d$subject, ids)]) / .7)) + stats::rnorm(nrow(d), 0, 2)
 path <- tempfile(fileext = ".csv"); on.exit(unlink(path)); utils::write.csv(d, path, row.names = FALSE)
 a <- list(`unit-col` = "subject", `technical-policy` = "reject", input = path, response = "response", dose = "dose", subject = "subject", `dose-unit` = "ng/mL",
  direction = "increasing", `random-parameter` = "logED50", method = "ML", residual = "independent",
  `singular-tol` = .0001, `max-iter` = 100, `ci-level` = .95, `study-contract-sha256` = paste(rep("0", 64), collapse = ""))
 r <- nlme_dose_compute(a)
 stopifnot(r$metadata$n_subjects == 16, r$metadata$n_observations == 128,
  r$tables$effect_table$n_unweighted == 16, all(r$tables$variance_components$variance > 0),
  all(c("01", "1") %in% r$tables$subject_parameters$subject))
 assert_effect_table(r$tables$effect_table)
 d <- rbind(d, d[1, ]); utils::write.csv(d, path, row.names = FALSE)
 msg <- tryCatch({nlme_dose_compute(a); ""}, error = conditionMessage)
 stopifnot(grepl("OS_INVALID_DESIGN", msg, fixed = TRUE), !file.exists("Rplots.pdf"))
 cat("nlme-dose standalone candidate smoke PASS\n")
}
run()
