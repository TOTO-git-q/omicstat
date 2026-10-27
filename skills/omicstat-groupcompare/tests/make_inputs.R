args <- commandArgs(trailingOnly = TRUE); dir.create(args[1], recursive = TRUE, showWarnings = FALSE)
d <- datasets::sleep
write.csv(d, file.path(args[1], "sleep.csv"), row.names = FALSE)
write.csv(d[-1, ], file.path(args[1], "missing_pair.csv"), row.names = FALSE)
write.csv(rbind(d, d[1, ]), file.path(args[1], "duplicate.csv"), row.names = FALSE)
d$extra[1] <- NA; write.csv(d, file.path(args[1], "missing_value.csv"), row.names = FALSE)
write.csv(data.frame(contrast = "drug1_minus_drug2", group1 = "1", group2 = "2"), file.path(args[1], "comparisons.csv"), row.names = FALSE)
