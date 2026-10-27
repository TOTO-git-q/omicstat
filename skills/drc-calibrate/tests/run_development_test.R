# Standalone candidate smoke test; numerical/CLI evidence is separate.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module <- dirname(here); shared <- file.path(module, "..", "_shared", "scripts")
for (f in c("module_kit.R", "effect_table.R", "dose_scope_support.R")) source(file.path(shared, f))
source(file.path(module, "scripts", "drc_calibrate_core.R"))
run <- function() {
 set.seed(17); x <- rep(c(.02, .05, .15, .5, 1.5, 5, 15, 50), each = 3)
 d <- data.frame(plate_id = "p", well = paste0("w", seq_along(x)), role = "standard",
  sample_id = paste0("std", x), concentration = x, dilution = 1,
  response = .05 + 2.5 / (1 + exp(-1.3 * (log(x) - log(3)))) + stats::rnorm(length(x), 0, .002))
 blanks <- data.frame(plate_id = "p", well = c("b1", "b2"), role = "blank", sample_id = "blank", concentration = NA, dilution = 1, response = c(.049, .051))
 unknown <- data.frame(plate_id = "p", well = c("u1", "u2", "u3"), role = "unknown", sample_id = "01", concentration = NA, dilution = 10, response = c(1.29, 1.30, 1.31))
 d <- rbind(d, blanks, unknown); path <- tempfile(fileext = ".csv"); on.exit(unlink(path))
 utils::write.csv(d, path, row.names = FALSE, na = "")
 a <- list(input = path, `unit-col` = "sample_id", mode = "calibration", model = "LL4", `blank-policy` = "subtract-mean", `max-cv` = 30,
  lloq = .05, uloq = 50, `dose-unit` = "ng/mL", `ci-level` = .95, `study-contract-sha256` = paste(rep("0", 64), collapse = ""))
 r <- drc_calibrate_compute(a); z <- r$tables$results
 stopifnot(nrow(z) == 1, !z$withheld, z$sample_id == "01", abs(z$concentration - 30) < .3,
  abs(z$concentration / z$well_concentration - 10) < 1e-12, r$tables$effect_table$n_unweighted == 1,
  !r$metadata$technical_wells_are_biological_replicates)
 assert_effect_table(r$tables$effect_table)
 d$well[2] <- d$well[1]; utils::write.csv(d, path, row.names = FALSE, na = "")
 msg <- tryCatch({drc_calibrate_compute(a); ""}, error = conditionMessage)
 stopifnot(grepl("OS_INVALID_DESIGN", msg, fixed = TRUE), !file.exists("Rplots.pdf"))
 cat("drc-calibrate standalone candidate smoke PASS\n")
}
run()
