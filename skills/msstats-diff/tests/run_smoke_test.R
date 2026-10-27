# requires: MSstats ggplot2 jsonlite digest
# Execute in the new rebuilt environment; never creates golden hashes or a seal.
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
.module <- dirname(dirname(.this)); .suite <- dirname(dirname(.module))
source(file.path(.suite, "skills/_shared/scripts/module_kit.R"))
source(file.path(.suite, "skills/_shared/scripts/feature_table.R"))
source(file.path(.module, "scripts/msstats_diff_core.R"))
stopifnot(requireNamespace("MSstats", quietly = TRUE))
a <- list(reference = "A", target = "B", design = "independent", normalization = "none", "censored-int" = "NA", "mb-impute" = "false")
# Construct a deterministic feature-level fixture, not a counterfeit protein matrix.
seed <- 20261015L; set.seed(seed)
x <- expand.grid(ProteinName = paste0("p", 1:30), PeptideModifiedSequence = paste0("peptide", 1:3), Run = paste0("run", 1:6), stringsAsFactors = FALSE)
x$PeptideModifiedSequence <- paste(x$ProteinName, x$PeptideModifiedSequence, sep = "_")
x$Condition <- ifelse(as.integer(sub("run", "", x$Run)) <= 3, "A", "B")
x$BioReplicate <- x$Run; x$PrecursorCharge <- 2L; x$FragmentIon <- NA_character_; x$ProductCharge <- NA_integer_
x$IsotopeLabelType <- "L"; x$Fraction <- 1L
x$Intensity <- 2^(20 + as.integer(sub("p", "", x$ProteinName))/10 + as.integer(sub(".*peptide", "", x$PeptideModifiedSequence))/5 +
                    ifelse(x$Condition == "B" & x$ProteinName %in% paste0("p", 1:5), 2, 0) + stats::rnorm(nrow(x), sd = 0.2))
p <- ms_prepare(x, a); r <- msstats_diff_compute(p, a)
processed <- MSstats::dataProcess(x, logTrans = 2, normalization = FALSE, nameStandards = NULL, featureSubset = "all",
 remove_uninformative_feature_outlier = FALSE, min_feature_count = 2, n_top_feature = 3, summaryMethod = "TMP",
 equalFeatureVar = TRUE, censoredInt = "NA", MBimpute = FALSE, remove50missing = FALSE, fix_missing = NULL,
 maxQuantileforCensored = 0.999, use_log_file = FALSE, append = FALSE, verbose = FALSE)
g <- unique(as.character(processed$ProteinLevelData$GROUP))
cm <- matrix(ifelse(g == "B", 1, -1), nrow = 1, dimnames = list("target_vs_reference", g))
direct <- MSstats::groupComparison(cm, processed, save_fitted_models = TRUE, log_base = 2, use_log_file = FALSE, append = FALSE, verbose = FALSE)
stopifnot(isTRUE(all.equal(r$full, as.data.frame(direct$ComparisonResult), tolerance = 1e-10, check.attributes = FALSE)))
a2 <- a; a2$target <- "A"; a2$reference <- "B"
rr <- msstats_diff_compute(ms_prepare(x, a2), a2)$full
ix <- match(r$full$Protein, rr$Protein)
stopifnot(isTRUE(all.equal(r$full$log2FC, -rr$log2FC[ix], tolerance = 1e-6)))
expect_error <- function(expr) stopifnot(inherits(tryCatch({force(expr); NULL}, error = identity), "error"))
expect_error(ms_prepare(rbind(x, x[1, ]), a))
bad <- x; bad$IsotopeLabelType[1] <- "H"; expect_error(ms_prepare(bad, a))
bad <- x; bad$BioReplicate <- "one"; expect_error(ms_prepare(bad, a))
# Official label-free demo must satisfy the declared schema and replicate contract.
# Fail loudly if a release changes it; never relabel isotope data or fabricate replicates.
env <- new.env(); utils::data("DDARawData", package = "MSstats", envir = env)
if (!exists("DDARawData", env, inherits = FALSE)) stop("Official DDARawData anchor unavailable; acceptance remains blocked.")
demo <- as.data.frame(env$DDARawData)
# Historical demo field spelling and unfractionated constant are explicit format translations.
if (!"PeptideModifiedSequence" %in% names(demo) && "PeptideSequence" %in% names(demo)) {
 names(demo)[names(demo) == "PeptideSequence"] <- "PeptideModifiedSequence"
}
if (!"Fraction" %in% names(demo)) demo$Fraction <- 1L
lev <- sort(unique(as.character(demo$Condition)))
if (length(lev) < 2L) stop("Official anchor needs at least two conditions.")
demo <- demo[demo$Condition %in% lev[1:2], , drop = FALSE]
a$reference <- lev[1]; a$target <- lev[2]
b0 <- unique(demo$BioReplicate[demo$Condition == a$reference]); b1 <- unique(demo$BioReplicate[demo$Condition == a$target])
a$design <- if (setequal(b0, b1)) "paired" else "independent"
# DDARawData has only ONE biological replicate/group (three technical runs).
# It must be refused; do not relabel the runs to make this fixture pass.
expect_error(ms_prepare(demo, a))
utils::data("DIARawData", package = "MSstats", envir = env)
demo <- as.data.frame(env$DIARawData)
names(demo)[names(demo) == "PeptideSequence"] <- "PeptideModifiedSequence"
demo$Fraction <- 1L
lev <- sort(unique(as.character(demo$Condition)))
a$reference <- lev[1]; a$target <- lev[2]; a$design <- "paired"
rd <- msstats_diff_compute(ms_prepare(demo, a), a)
stopifnot(nrow(rd$ft) == length(unique(demo$ProteinName)))
cat("PASS: MSstats direct replay, direction, rejection cases and DDARawData refusal and official DIARawData; no golden generated.\n")
