# requires: proDA ggplot2 jsonlite digest
# Run in the new rebuilt environment. This test does not create a golden or seal.
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this)); .suite <- dirname(dirname(.module))
source(file.path(.suite, "skills/_shared/scripts/module_kit.R"))
source(file.path(.suite, "skills/_shared/scripts/feature_table.R"))
source(file.path(.module, "scripts/proda_diff_core.R"))
stopifnot(requireNamespace("proDA", quietly = TRUE))
seed <- 20261015L; set.seed(seed)
syn <- proDA::generate_synthetic_data(n_proteins = 500, n_conditions = 2)
mat <- syn$Y
st <- data.frame(sample = colnames(mat), biological_id = colnames(mat), condition = as.character(syn$groups))
g <- unique(st$condition)
a <- list(seed = seed, "sample-col" = "sample", "bio-col" = "biological_id", condition = "condition", reference = g[1], target = g[2],
          "input-scale" = "log2", "zero-policy" = "observed", normalization = "none")
prep <- pd_prepare(mat, st, a)
res <- proda_diff_compute(prep, a)
set.seed(seed)
fit <- proDA::proDA(data = prep$matrix, design = prep$design, data_is_log_transformed = TRUE,
  moderate_location = TRUE, moderate_variance = TRUE, location_prior_df = 3, n_subsample = nrow(prep$matrix),
  max_iter = 20, epsilon = 0.001, verbose = FALSE)
direct <- as.data.frame(proDA::test_diff(fit, contrast = "target - reference", alternative = "two.sided",
  pval_adjust_method = "BH", sort_by = NULL, n_max = Inf, verbose = FALSE))
stopifnot(isTRUE(all.equal(res$full, direct, tolerance = 1e-10, check.attributes = FALSE)))
a2 <- a; a2$reference <- a$target; a2$target <- a$reference
rev <- proda_diff_compute(pd_prepare(mat, st, a2), a2)$full
ix <- match(direct$name, rev$name)
stopifnot(isTRUE(all.equal(direct$diff, -rev$diff[ix], tolerance = 1e-6)),
          isTRUE(all.equal(direct$pval, rev$pval[ix], tolerance = 1e-6)))
expect_error <- function(expr) stopifnot(inherits(tryCatch({force(expr); NULL}, error = identity), "error"))
st_bad <- st; st_bad$biological_id[2] <- st_bad$biological_id[1]
expect_error(pd_prepare(mat, st_bad, a))
mat_bad <- mat; mat_bad[, 1] <- NA_real_
expect_error(pd_prepare(mat_bad, st, a))
# Reader must preserve NA rather than relying on the NA-rejecting common reader.
f <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(feature_id = rownames(mat), mat, check.names = FALSE), f, row.names = FALSE, na = "NA")
readback <- pd_read_matrix(f)
stopifnot(identical(is.na(readback), is.na(mat)))
unlink(f)
# Real official package fixture. Inspect exactly two 3-replicate DHHC groups;
# remaining groups are explicitly excluded for this initial two-group module.
f <- system.file("extdata/proteinGroups.txt", package = "proDA", mustWork = TRUE)
mq <- utils::read.delim(f, check.names = FALSE)
cols <- grep("^LFQ intensity\\.(CG1407|CG4676)\\.", names(mq), value = TRUE)
if (length(cols) != 6L) cols <- grep("^LFQ.intensity.(CG1407|CG4676).", names(mq), value = TRUE)
if (length(cols) != 6L) stop("Official fixture column contract changed; review instead of silently substituting data.")
x <- as.matrix(mq[cols]); storage.mode(x) <- "double"; rownames(x) <- mq[[if ("Protein IDs" %in% names(mq)) "Protein IDs" else "Protein.IDs"]]
if (is.null(rownames(x))) stop("Official fixture Protein IDs field absent.")
s <- data.frame(sample = cols, biological_id = cols, condition = ifelse(grepl("CG1407", cols), "CG1407", "CG4676"))
a$reference <- "CG1407"; a$target <- "CG4676"; a[["input-scale"]] <- "linear"; a[["zero-policy"]] <- "missing"; a$normalization <- "median"
r <- proda_diff_compute(pd_prepare(x, s, a), a)
stopifnot(nrow(r$ft) == nrow(x), all(r$ft$n_group1 == 3L), all(r$ft$n_group2 == 3L))
cat("PASS: proDA direct replay, sign, input errors and official fixture; no golden generated.\n")
