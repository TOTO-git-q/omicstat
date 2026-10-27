# Draft implementation; canonical feature-level input only, never a fake peptide matrix.
MS_MODULE <- "msstats-diff"
MS_VERSION <- "0.1.0"
MS_PACKAGE_VERSION <- "4.20.0"

ms_prepare <- function(raw, a) {
  if (anyDuplicated(names(raw))) stop("OS_INVALID_INPUT: duplicate column names.", call. = FALSE)
  required <- c("ProteinName", "PeptideModifiedSequence", "PrecursorCharge", "FragmentIon", "ProductCharge",
                "IsotopeLabelType", "Condition", "BioReplicate", "Run", "Intensity", "Fraction")
  if (!nrow(raw) || !all(required %in% names(raw))) stop("OS_MISSING_COLUMN: supply canonical MSstats long data including Fraction (1 for unfractionated data).", call. = FALSE)
  for (nm in c("ProteinName", "PeptideModifiedSequence", "PrecursorCharge", "IsotopeLabelType", "Condition", "BioReplicate", "Run", "Fraction"))
    if (anyNA(raw[[nm]]) || any(!nzchar(trimws(as.character(raw[[nm]]))))) stop(paste("OS_INVALID_INPUT: missing", nm), call. = FALSE)
  if (!all(raw$IsotopeLabelType == "L")) stop("OS_UNSUPPORTED_INPUT: initial module accepts label-free L data only; TMT and isotope reference designs are separate contracts.", call. = FALSE)
  # The shared CSV reader preserves strings. MSstats quantile normalization
  # needs numeric canonical charge/fraction fields; passing character fields
  # reaches preprocessCore with incompatible types even for valid intensities.
  for (nm in c("PrecursorCharge", "ProductCharge", "Fraction")) {
    v <- suppressWarnings(as.numeric(raw[[nm]]))
    missing_ok <- nm == "ProductCharge"
    if (any(is.na(v) & !is.na(raw[[nm]])) || any(!is.finite(v) & !is.na(v)) ||
        (!missing_ok && anyNA(v)) || any(v < if (missing_ok) 0 else 1, na.rm = TRUE) ||
        any(v != trunc(v), na.rm = TRUE))
      stop(paste("OS_INVALID_INPUT:", nm, "must contain integer charges/fractions (ProductCharge may be NA)."), call. = FALSE)
    raw[[nm]] <- as.integer(v)
  }
  z <- suppressWarnings(as.numeric(raw$Intensity))
  if (any(is.na(z) & !is.na(raw$Intensity)) || any(is.infinite(z)) || any(z < 0, na.rm = TRUE))
    stop("OS_INVALID_INPUT: Intensity must be nonnegative finite raw linear values or NA.", call. = FALSE)
  raw$Intensity <- z
  if (a[["censored-int"]] == "none" && any(z == 0, na.rm = TRUE)) stop("OS_INVALID_INPUT: zeros require an explicit censoring policy.", call. = FALSE)
  if (a[["censored-int"]] == "none" && a[["mb-impute"]] == "true") stop("OS_INVALID_PARAMETER: imputation requires a censoring policy.", call. = FALSE)
  if (identical(a$reference, a$target) || !setequal(unique(raw$Condition), c(a$reference, a$target)))
    stop("OS_INVALID_DESIGN: exactly the declared reference and target groups are required.", call. = FALSE)
  ann <- unique(raw[c("Run", "Condition", "BioReplicate")])
  if (anyDuplicated(ann$Run)) stop("OS_INVALID_DESIGN: every Run must identify exactly one Condition and BioReplicate.", call. = FALSE)
  b1 <- unique(ann$BioReplicate[ann$Condition == a$target]); b0 <- unique(ann$BioReplicate[ann$Condition == a$reference])
  if (min(length(b1), length(b0)) < 2L) stop("OS_PSEUDOREPLICATION: two biological replicates per group required; technical runs do not count.", call. = FALSE)
  if (a$design == "independent" && length(intersect(b1, b0))) stop("OS_INVALID_DESIGN: independent groups require globally distinct BioReplicate IDs.", call. = FALSE)
  if (a$design == "paired" && !setequal(b1, b0)) stop("OS_INVALID_DESIGN: paired initial scope requires the same biological IDs in both groups.", call. = FALSE)
  # MSstats constructs FEATURE without ProteinName. A feature mapped to
  # multiple proteins can leak intensities between proteins in preprocessing.
  # Require a reviewed converter to resolve shared peptides/protein groups.
  feature_cols <- c("PeptideModifiedSequence", "PrecursorCharge", "FragmentIon", "ProductCharge", "IsotopeLabelType")
  mapping <- unique(raw[c(feature_cols, "ProteinName")])
  if (anyDuplicated(mapping[feature_cols]))
    stop("OS_AMBIGUOUS_FEATURE: peptide/transition maps to multiple ProteinName values; resolve shared peptides upstream.", call. = FALSE)
  key <- setdiff(required, c("Condition", "BioReplicate", "Intensity"))
  if (anyDuplicated(raw[key])) stop("OS_INVALID_INPUT: duplicate feature/run rows must be resolved by a documented converter upstream.", call. = FALSE)
  list(raw = raw, samples = ann, all_ids = unique(as.character(raw$ProteinName)), n_target = length(b1), n_reference = length(b0))
}

msstats_diff_compute <- function(prep, a) {
  if (!requireNamespace("MSstats", quietly = TRUE)) stop("OS_MISSING_PACKAGE: MSstats is required in a rebuilt environment.", call. = FALSE)
  if (as.character(utils::packageVersion("MSstats")) != MS_PACKAGE_VERSION)
    stop("OS_PACKAGE_VERSION: expected MSstats 4.20.0; review calls and rerun acceptance for a new version.", call. = FALSE)
  norm <- if (a$normalization == "none") FALSE else a$normalization
  cens <- if (a[["censored-int"]] == "none") NULL else a[["censored-int"]]
  processed <- MSstats::dataProcess(raw = prep$raw, logTrans = 2, normalization = norm,
       nameStandards = NULL, featureSubset = "all", remove_uninformative_feature_outlier = FALSE,
       min_feature_count = 2, n_top_feature = 3, summaryMethod = "TMP", equalFeatureVar = TRUE,
       censoredInt = cens, MBimpute = a[["mb-impute"]] == "true", remove50missing = FALSE,
       fix_missing = NULL, maxQuantileforCensored = 0.999, use_log_file = FALSE, append = FALSE, verbose = FALSE)
  if (is.null(processed$ProteinLevelData) || is.null(processed$FeatureLevelData))
    stop("OS_API_MISMATCH: expected MSstats 4 ProteinLevelData and FeatureLevelData.", call. = FALSE)
  groups <- unique(as.character(processed$ProteinLevelData$GROUP))
  if (!setequal(groups, c(a$reference, a$target))) stop("OS_API_MISMATCH: processed GROUP labels differ from requested conditions.", call. = FALSE)
  contrast <- matrix(ifelse(groups == a$target, 1, -1), nrow = 1L,
                     dimnames = list("target_vs_reference", groups))
  fit <- MSstats::groupComparison(contrast.matrix = contrast, data = processed, save_fitted_models = TRUE,
              log_base = 2, use_log_file = FALSE, append = FALSE, verbose = FALSE)
  tt <- as.data.frame(fit$ComparisonResult)
  needed <- c("Protein", "Label", "log2FC", "SE", "Tvalue", "pvalue", "adj.pvalue", "issue")
  if (!all(needed %in% names(tt)) || anyDuplicated(tt$Protein) || any(!tt$Protein %in% prep$all_ids))
    stop("OS_API_MISMATCH: unexpected MSstats comparison schema or identities.", call. = FALSE)
  ix <- match(prep$all_ids, tt$Protein)
  reason <- ifelse(is.na(ix), "removed_during_processing", ifelse(is.na(tt$adj.pvalue[ix]), "not_estimable", ""))
  issue <- !is.na(tt$issue[ix]) & nzchar(tt$issue[ix])
  reason[!is.na(ix) & issue] <- "engine_issue"
  ft <- as_feature_table(data.frame(feature_id = prep$all_ids, contrast = paste(a$target, "vs", a$reference),
       log2fc = tt$log2FC[ix], log2fc_se = tt$SE[ix], stat = tt$Tvalue[ix], pvalue = tt$pvalue[ix],
       padj = tt$adj.pvalue[ix], method = "MSstats groupComparison", shrinkage = "none",
       n_group1 = prep$n_target, n_group2 = prep$n_reference, filtered_reason = reason))
  list(ft = ft, full = tt, fit = fit, processed = processed, samples = prep$samples,
       details = list(input_scale = "linear feature intensity", normalization = a$normalization, design = a$design,
           censored_int = a[["censored-int"]], mb_impute = a[["mb-impute"]] == "true", summary_method = "TMP",
           contrast_columns = groups, contrast_weights = as.numeric(contrast),
           n_target = prep$n_target, n_reference = prep$n_reference,
           n_issue_rows = sum(!is.na(tt$issue) & nzchar(tt$issue)),
           n_removed_proteins = sum(is.na(ix))))
}
