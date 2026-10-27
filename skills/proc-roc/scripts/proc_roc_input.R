# Explicit OmicStat inputs around the copied diagnostic-accuracy engine.
.os_roc_module <- local({
  f <- vapply(sys.frames(), function(x) if (is.null(x$ofile)) "" else x$ofile, "")
  dirname(dirname(normalizePath(tail(f[nzchar(f)], 1), mustWork = TRUE)))
})
os_roc_port <- function() {
  e <- new.env(parent = baseenv())
  sys.source(file.path(.os_roc_module, "scripts", "roc_ported_core.R"), envir = e)
  sys.source(file.path(.os_roc_module, "scripts", "roc_ported_qc.R"), envir = e)
  e
}
.os_roc_stop <- function(message, code = "OS_INVALID_PARAMETER") stop(paste0(code, ": ", message), call. = FALSE)
.os_roc_need <- function(a, keys) {
  absent <- keys[vapply(keys, function(k) is.null(a[[k]]), logical(1))]
  if (length(absent)) .os_roc_stop(paste("required:", paste0("--", absent, collapse = ", ")), "OS_MISSING_PARAMETER")
}
.os_roc_text <- function(x, key) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) .os_roc_stop(paste("nonblank string required:", key))
}
.os_roc_num <- function(x, key, lo = -Inf, hi = Inf, integer = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lo || x > hi || (integer && x != floor(x)))
    .os_roc_stop(paste("finite", if (integer) "integer" else "number", "outside allowed range:", key))
}
.os_roc_csv <- function(x, key, numeric = FALSE) {
  .os_roc_text(x, key); z <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  if (grepl(",$", x) || any(!nzchar(z)) || anyDuplicated(z)) .os_roc_stop(paste("distinct nonblank comma-separated values required:", key))
  if (numeric) { z <- suppressWarnings(as.numeric(z)); if (any(!is.finite(z)) || anyDuplicated(z)) .os_roc_stop(paste("distinct finite numbers required:", key)) }
  z
}
.os_roc_ids <- function(x, role) {
  x <- as.character(x)
  if (!length(x) || anyNA(x) || any(!nzchar(trimws(x))) || anyDuplicated(x))
    .os_roc_stop(paste("ROC-04: unique nonblank independent-unit IDs required in", role), "OS_INVALID_DESIGN")
  x
}
.os_roc_table <- function(path) {
  if (!file.exists(path)) .os_roc_stop("missing input", "OS_MISSING_FILE")
  if (tolower(tools::file_ext(path)) == "rds") d <- readRDS(path) else if (tolower(tools::file_ext(path)) %in% c("csv", "tsv", "txt")) d <- .os_read_delim(path) else
    .os_roc_stop("only declared CSV/TSV or RDS carriers are supported; JSON/other carriers require an explicit adapter", "OS_INVALID_INPUT")
  if (!is.data.frame(d) || !nrow(d) || anyDuplicated(names(d)) || any(!nzchar(names(d))))
    .os_roc_stop("nonempty data frame with distinct column names required", "OS_INVALID_INPUT")
  d
}
.os_roc_numeric <- function(z, name) {
  if (is.factor(z)) z <- as.character(z)
  if (!is.atomic(z) || is.logical(z)) .os_roc_stop(paste("numeric marker required:", name), "OS_INVALID_INPUT")
  val <- suppressWarnings(as.numeric(z))
  if (any(is.na(val) & !is.na(z)) || any(is.infinite(val)))
    .os_roc_stop(paste("non-numeric or infinite marker:", name), "OS_INVALID_INPUT")
  val
}
os_proc_roc_validate <- function(a) {
  .os_roc_need(a, c("input-kind", "sample-sheet", "id-col", "reference-col", "markers", "labels", "positive-class", "negative-class",
    "direction", "cutpoint", "confidence-level", "ci-method", "missing", "indeterminate", "independent-unit", "unit-description",
    "repeated-measures", "dataset-name", "score-unit", "bootstrap-reps", "seed", "study-contract"))
  for (k in c("id-col", "reference-col", "positive-class", "negative-class", "unit-description", "dataset-name", "score-unit")) .os_roc_text(a[[k]], k)
  if (a[["positive-class"]] == a[["negative-class"]]) .os_roc_stop("ROC-03: positive and negative classes must differ", "OS_INVALID_DESIGN")
  if (!a[["input-kind"]] %in% c("feature_table", "expression_matrix")) .os_roc_stop("explicit feature_table or expression_matrix required")
  if (!a$direction %in% c("higher-is-positive", "lower-is-positive")) .os_roc_stop("direction auto is forbidden; declare one common direction before looking at AUC")
  if (!a$missing %in% c("fail", "complete-case") || !a$indeterminate %in% c("exclude", "positive", "negative")) .os_roc_stop("unknown missing/indeterminate policy")
  if (!a[["ci-method"]] %in% c("exact", "wilson")) .os_roc_stop("accuracy interval must be exact or wilson; AUC remains DeLong")
  if (a[["repeated-measures"]] != "false") .os_roc_stop("ROC-04: clustered, longitudinal, per-image and repeated records require a reviewed different estimator", "OS_INVALID_DESIGN")
  if (!a[["independent-unit"]] %in% c("animal", "donor", "biological-sample", "independent-culture", "physical-test-item")) .os_roc_stop("declare actual independent units; cells/technical replicates are not independent subjects", "OS_INVALID_DESIGN")
  .os_roc_num(a[["confidence-level"]], "confidence-level", 0, 1)
  if (a[["confidence-level"]] %in% c(0, 1)) .os_roc_stop("confidence-level must be strictly inside (0,1)")
  .os_roc_num(a[["bootstrap-reps"]], "bootstrap-reps", 100, .Machine$integer.max, TRUE)
  .os_roc_num(a$seed, "seed", 0, .Machine$integer.max, TRUE)
  markers <- .os_roc_csv(a$markers, "markers"); primary <- markers[1]
  if (any(markers %in% c(a[["id-col"]], a[["reference-col"]]))) .os_roc_stop("marker keys must differ from ID and reference columns", "OS_INVALID_DESIGN")
  if (length(markers) > 1L) {
    .os_roc_need(a, c("p-adjust", "comparison-family"))
    if (!a[["p-adjust"]] %in% c("holm", "bonferroni", "BH", "BY", "hochberg", "hommel") || a[["comparison-family"]] != "primary-versus-rest")
      .os_roc_stop("P0-13 requires explicit multiplicity adjustment of the original primary-versus-rest paired DeLong family")
  } else if (!is.null(a[["p-adjust"]]) || !is.null(a[["comparison-family"]])) .os_roc_stop("comparison settings supplied for a single marker", "OS_CONFLICTING_PARAMETERS")
  kind <- a$cutpoint
  if (!kind %in% c("none", "youden", "closest.topleft")) {
    threshold <- suppressWarnings(as.numeric(kind)); .os_roc_num(threshold, "cutpoint")
    .os_roc_need(a, c("cutpoint-source", "cutpoint-rationale"))
    if (!a[["cutpoint-source"]] %in% c("prespecified", "published", "guideline")) .os_roc_stop("numeric cutpoint requires its prespecified source")
    .os_roc_text(a[["cutpoint-rationale"]], "cutpoint-rationale"); kind <- "prespecified"
  } else {
    threshold <- NULL
    if (!is.null(a[["cutpoint-source"]]) || !is.null(a[["cutpoint-rationale"]])) .os_roc_stop("cutpoint source applies only to a numeric prespecified threshold", "OS_CONFLICTING_PARAMETERS")
  }
  exploratory <- kind %in% c("youden", "closest.topleft")
  if (exploratory) {
    .os_roc_need(a, "internal-validation")
    if (!a[["internal-validation"]] %in% c("loo", "bootstrap", "none")) .os_roc_stop("unknown internal validation")
    if (a[["internal-validation"]] == "none" && !isTRUE(a[["allow-optimistic-cutpoint"]]))
      .os_roc_stop("ROC-12: exploratory cutoff requires internal validation; the original explicit override remains visible and cannot confer acceptance", "OS_INVALID_DESIGN")
  } else if (!is.null(a[["internal-validation"]]) || isTRUE(a[["allow-optimistic-cutpoint"]])) .os_roc_stop("internal-validation/optimistic override belongs only to exploratory cutoff selection", "OS_CONFLICTING_PARAMETERS")
  pauc <- if (is.null(a$pauc)) NULL else sort(.os_roc_csv(a$pauc, "pauc", TRUE), decreasing = TRUE)
  if (!is.null(pauc)) {
    .os_roc_need(a, "pauc-focus")
    if (length(pauc) != 2L || any(pauc < 0 | pauc > 1) || !a[["pauc-focus"]] %in% c("specificity", "sensitivity")) .os_roc_stop("two distinct pAUC bounds in [0,1] and explicit focus required")
  } else if (!is.null(a[["pauc-focus"]])) .os_roc_stop("pauc-focus without a pAUC range", "OS_CONFLICTING_PARAMETERS")
  grid <- if (is.null(a$cutpoints)) NULL else .os_roc_csv(a$cutpoints, "cutpoints", TRUE)
  if (kind == "none" && !is.null(grid)) .os_roc_stop("multi-cutpoint accuracy requires an explicitly selected primary cutoff in this adapter", "OS_CONFLICTING_PARAMETERS")
  prevalence <- if (is.null(a[["prevalence-grid"]])) NULL else .os_roc_csv(a[["prevalence-grid"]], "prevalence-grid", TRUE)
  if (!is.null(prevalence) && (kind == "none" || any(prevalence <= 0 | prevalence >= 1))) .os_roc_stop("prevalence-grid requires a primary cutoff and assumed probabilities inside (0,1)")
  if (xor(is.null(a$input), is.null(a[["from-run"]])) == FALSE) .os_roc_stop("choose input or from-run exclusively", "OS_CONFLICTING_PARAMETERS")
  upstream <- NULL; path <- a$input
  if (!is.null(a[["from-run"]])) {
    .os_roc_need(a, "object")
    upstream <- read_handoff(a[["from-run"]], expect = stats::setNames(list(a[["input-kind"]]), a$object))
    os_handoff_assert_uncorrected(upstream, a$object, "ROC/AUC inference")
    if (!is.null(a[["study-contract"]])) os_study_contract_read(a[["study-contract"]], upstream = upstream)
    path <- upstream$objects[[a$object]]$path
  } else if (!is.null(a$object)) .os_roc_stop("object requires from-run", "OS_CONFLICTING_PARAMETERS")
  sheet <- .os_roc_table(a[["sample-sheet"]])
  if (!all(c(a[["id-col"]], a[["reference-col"]]) %in% names(sheet))) .os_roc_stop("sample sheet requires declared ID and binary reference columns", "OS_MISSING_COLUMN")
  sheet_ids <- .os_roc_ids(sheet[[a[["id-col"]]]], "sample sheet")
  if (a[["input-kind"]] == "feature_table") {
    d <- .os_roc_table(path)
    if (!all(c(a[["id-col"]], markers) %in% names(d))) .os_roc_stop("subject-wide feature table requires independent ID plus every selected marker; aggregate DE tables are not this input", "OS_MISSING_COLUMN")
    ids <- .os_roc_ids(d[[a[["id-col"]]]], "feature table")
    scores <- stats::setNames(lapply(markers, function(k) .os_roc_numeric(d[[k]], k)), markers)
  } else {
    if (tolower(tools::file_ext(path)) == "rds") {
      mat <- readRDS(path)
      if (!is.matrix(mat) || !is.numeric(mat)) .os_roc_stop("RDS expression carrier must be an explicit numeric feature-by-sample matrix", "OS_INVALID_INPUT")
    } else {
      d <- .os_roc_table(path)
      if (ncol(d) < 2L) .os_roc_stop("expression matrix needs feature ID and sample columns", "OS_INVALID_INPUT")
      features <- .os_roc_ids(d[[1]], "matrix features")
      mat <- vapply(names(d)[-1], function(k) .os_roc_numeric(d[[k]], k), numeric(nrow(d)))
      dimnames(mat) <- list(features, names(d)[-1])
    }
    if (is.null(rownames(mat)) || is.null(colnames(mat))) .os_roc_stop("expression axes must be named", "OS_INVALID_INPUT")
    .os_roc_ids(rownames(mat), "matrix features"); ids <- .os_roc_ids(colnames(mat), "matrix samples")
    if (!all(markers %in% rownames(mat))) .os_roc_stop("selected features are absent; no data-driven substitution or feature selection", "OS_MISSING_COLUMN")
    scores <- stats::setNames(lapply(markers, function(k) .os_roc_numeric(mat[k, ], k)), markers)
  }
  if (!setequal(ids, sheet_ids)) .os_roc_stop("sample sheet and measurement IDs must match exactly; no positional or intersect-only alignment", "OS_INVALID_DESIGN")
  sheet <- sheet[match(ids, sheet_ids), , drop = FALSE]
  raw <- as.character(sheet[[a[["reference-col"]]]]); ref_missing <- is.na(raw) | !nzchar(trimws(raw))
  sentinel <- a[["indeterminate-value"]]; indet <- rep(FALSE, length(raw))
  if (!is.null(sentinel)) {
    .os_roc_text(sentinel, "indeterminate-value")
    if (tolower(trimws(sentinel)) %in% tolower(trimws(c(a[["positive-class"]], a[["negative-class"]])))) .os_roc_stop("indeterminate sentinel conflicts with a declared real class")
    indet <- !ref_missing & tolower(trimws(raw)) == tolower(trimws(sentinel))
  } else if (a$indeterminate != "exclude") .os_roc_stop("substitution policy requires an indeterminate-value declaration")
  levels <- c(a[["negative-class"]], a[["positive-class"]])
  if (any(!raw[!ref_missing & !indet] %in% levels) || !setequal(unique(raw[!ref_missing & !indet]), levels))
    .os_roc_stop("ROC-03: reference must contain exactly the two declared real classes", "OS_INVALID_DESIGN")
  effective <- raw
  if (a$indeterminate != "exclude") effective[indet] <- if (a$indeterminate == "positive") levels[2] else levels[1]
  masks <- lapply(scores, function(z) !is.na(z) & !ref_missing & !(indet & a$indeterminate == "exclude"))
  if (a$missing == "fail" && (any(ref_missing) || any(vapply(scores, anyNA, logical(1))))) .os_roc_stop("ROC-01: missing values require explicit complete-case policy; no implicit drop", "OS_INVALID_INPUT")
  p <- os_roc_port(); idx <- which(masks[[1]])
  for (k in markers[-1]) p$assert_paired_sets(idx, which(masks[[k]]))
  response <- factor(effective[idx], levels = levels)
  if (any(table(response) < 2L)) .os_roc_stop("at least two independent units per class are required for finite DeLong variance", "OS_INVALID_DESIGN")
  if (exploratory && a[["internal-validation"]] == "loo" && any(table(response) < 3L)) .os_roc_stop("LOO requires both training classes and at least two observations in each training class", "OS_INVALID_DESIGN")
  if (exploratory && a[["internal-validation"]] == "loo" && length(idx) > 10000L) .os_roc_stop("LOO exceeds this implementation's 10000-unit resource guard. Keep the full input; use a reviewed larger-resource implementation or explicitly choose another justified method. No automatic subsampling or switch.", "OS_RESOURCE_LIMIT")
  labels <- jsonlite::fromJSON(a$labels, simplifyVector = TRUE)
  if (is.list(labels)) {
    if (any(!vapply(labels, function(z) is.character(z) && length(z) == 1L && !is.na(z), logical(1))))
      .os_roc_stop("ROC-05: label map must be flat strings, not nested objects or arrays", "OS_INVALID_INPUT")
    labels <- unlist(labels, use.names = TRUE)
  }
  keys <- c("population", a[["reference-col"]], levels, markers)
  if (!is.character(labels) || anyDuplicated(names(labels)) || anyNA(labels) || any(!nzchar(trimws(labels))) || !all(keys %in% names(labels))) .os_roc_stop("ROC-05: every marker, class, reference and population requires a unique-key nonblank reader label", "OS_INVALID_INPUT")
  if (anyDuplicated(unname(labels[markers])) || anyDuplicated(unname(labels[levels]))) .os_roc_stop("ROC-05: marker and class labels must remain distinguishable", "OS_INVALID_INPUT")
  subgroup <- if (is.null(a$subgroups)) NULL else .os_roc_csv(a$subgroups, "subgroups")
  if (!is.null(subgroup) && (kind == "none" || !all(subgroup %in% names(sheet)) || !all(subgroup %in% names(labels)))) .os_roc_stop("subgroups need sheet columns, reader labels and a primary cutoff", "OS_MISSING_COLUMN")
  # Disjoint exclusions preserve the original four flow identities when missingness overlaps.
  excl_indet <- indet & a$indeterminate == "exclude"
  excl_index <- !excl_indet & is.na(scores[[1]])
  excl_reference <- !excl_indet & !excl_index & ref_missing
  list(port = p, path = path, upstream = upstream, markers = markers, primary = primary, ids = ids,
    scores = scores, sheet = sheet, levels = levels, response = response, effective_reference = effective,
    reference_raw = raw, reference_missing = ref_missing, indeterminate = indet, idx = idx,
    direction = if (a$direction == "higher-is-positive") "<" else ">", labels = labels,
    cutpoint_kind = kind, threshold = threshold, exploratory = exploratory, pauc = pauc, cutpoints = grid, prevalence = prevalence,
    subgroups = subgroup, exclusions = c(indeterminate = sum(excl_indet), index = sum(excl_index), reference = sum(excl_reference)))
}
