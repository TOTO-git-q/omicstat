args <- commandArgs(trailingOnly = TRUE)
x <- read.csv(file.path(args[2], "tables/tests.csv")); e <- read.csv(file.path(args[2], "tables/effect_table.csv"))
values <- list(sleep_t = x$statistic[1], sleep_df = x$df1[1], sleep_p = x$p_value[1],
 sleep_difference = e$estimate[1], sleep_ci_low = e$ci_low[1], sleep_ci_high = e$ci_high[1])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(here, "distribution_test_helpers.R"))
values <- c(values, gpc_anchor_values(here))
jsonlite::write_json(values, args[1], auto_unbox = TRUE, digits = NA)
