a <- commandArgs(trailingOnly = TRUE); d <- read.csv(file.path(a[2], "tables/biological_units.csv")); b <- d[d$group == "Brain", ]; k <- d[d$group == "Kidney", ]
jsonlite::write_json(list(brain_target_ct=b$mean_target_ct,brain_reference_ct=b$mean_reference_ct,kidney_target_ct=k$mean_target_ct,
 kidney_reference_ct=k$mean_reference_ct,brain_delta_ct=b$delta_ct,kidney_delta_ct=k$delta_ct,kidney_delta_delta_ct=k$delta_delta_ct,
 kidney_fold=k$fold_change,brain_technical_sd=b$technical_delta_ct_sd,kidney_technical_sd=k$technical_delta_ct_sd,brain_fold=b$fold_change),a[1],auto_unbox=TRUE,digits=NA)
