# limma-array S2 estimator; PACK S1 appendix P-1/P-2.
LA_MODULE <- "limma-array"
LA_MODULE_VERSION <- "1.1.0"

la_read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character", na.strings = c("NA", ""), check.names = FALSE)
}

# Explicit probe annotation (S3 F3): CSV feature_id, symbol, entrez[, more].
# One row per TESTED feature: after technical averaging the member probes of a
# technical ID are listed in probe_ids and their annotation merged (one value
# -> mapped; none -> unmapped, symbol ""; several -> conflicting, values joined
# with ";"). Original probe IDs are never renamed.
la_probe_annotation <- function(path, probe_map, tested) {
  an <- la_read_csv(path)
  if (!all(c("feature_id", "symbol", "entrez") %in% names(an)))
    stop("OS_MISSING_COLUMN: --probe-annotation needs feature_id, symbol and entrez columns.", call. = FALSE)
  if (any(c("annotation_status", "probe_ids", "n_probes") %in% names(an)))
    stop("OS_INVALID_INPUT: --probe-annotation must not contain the reserved columns annotation_status, probe_ids, n_probes.", call. = FALSE)
  if (anyNA(an$feature_id) || anyDuplicated(an$feature_id))
    stop("OS_INVALID_INPUT: probe annotation feature_id must be unique and nonempty.", call. = FALSE)
  ix <- match(probe_map$feature_id, an$feature_id)
  if (all(is.na(ix)))
    stop("OS_INVALID_INPUT: no retained probe ID occurs in the probe annotation feature_id column; check the ID type.", call. = FALSE)
  grp <- factor(probe_map$technical_id, levels = tested)
  merge_col <- function(v) {
    vapply(split(v, grp), function(z) {
      u <- sort(unique(z[!is.na(z) & nzchar(z)]), method = "radix")
      if (length(u)) paste(u, collapse = ";") else NA_character_
    }, "")
  }
  sym <- vapply(split(an$symbol[ix], grp), function(z) length(unique(z[!is.na(z) & nzchar(z)])), 0L)
  out <- data.frame(feature_id = tested, stringsAsFactors = FALSE)
  out$symbol <- unname(merge_col(an$symbol[ix]))
  out$entrez <- unname(merge_col(an$entrez[ix]))
  out$annotation_status <- ifelse(sym == 0L, "unmapped", ifelse(sym == 1L, "mapped", "conflicting"))
  out$symbol[is.na(out$symbol)] <- ""
  out$probe_ids <- unname(vapply(split(probe_map$feature_id, grp), paste, "", collapse = ";"))
  out$n_probes <- unname(as.integer(table(grp)))
  for (k in setdiff(names(an), c("feature_id", "symbol", "entrez"))) out[[k]] <- unname(merge_col(an[[k]][ix]))
  out
}

limma_array_compute <- function(mat, model, a) {
  if (any(!is.finite(mat))) stop("OS_INVALID_INPUT: normalized array matrix must be finite.", call. = FALSE)
  if (is.null(a[["control-ids"]]) && !a[["controls-removed"]])
    stop("OS_MISSING_PARAMETER: supply --control-ids or declare --controls-removed.", call. = FALSE)
  if (!is.null(a[["control-ids"]]) && a[["controls-removed"]])
    stop("OS_CONFLICTING_PARAMETERS: choose --control-ids or --controls-removed.", call. = FALSE)
  if (xor(is.null(a[["above-background"]]), is.null(a[["background-k"]])))
    stop("OS_MISSING_PARAMETER: --above-background and --background-k must be given together.", call. = FALSE)
  if (!is.null(a[["technical-ids"]]) && !a[["verified-technical-ids"]])
    stop("OS_MISSING_PARAMETER: --technical-ids requires --verified-technical-ids (same technical probe identity).", call. = FALSE)
  if (!is.null(a$preprocessing) && !nzchar(trimws(a$preprocessing)))
    stop("OS_INVALID_PARAMETER: --preprocessing must be a nonempty description.", call. = FALSE)
  if (a$platform != "agilent" && (a$trend == "auto" || a$robust == "auto"))
    stop("OS_MISSING_PARAMETER: non-Agilent platforms require explicit --trend and --robust until the platform preset is approved.", call. = FALSE)
  trend <- if (a$trend == "auto") TRUE else a$trend == "true"
  robust <- if (a$robust == "auto") TRUE else a$robust == "true"
  keep <- rep(TRUE, nrow(mat)); names(keep) <- rownames(mat)
  n_ctrl <- 0L
  if (!is.null(a[["control-ids"]])) {
    ids <- utils::read.csv(a[["control-ids"]], stringsAsFactors = FALSE)
    if (!"feature_id" %in% names(ids)) stop("OS_MISSING_COLUMN: control IDs need feature_id.", call. = FALSE)
    if (!all(ids$feature_id %in% rownames(mat))) stop("OS_INVALID_INPUT: a control ID is absent from the matrix.", call. = FALSE)
    keep[ids$feature_id] <- FALSE
    n_ctrl <- sum(!keep)
  }
  n_noncontrol <- sum(keep)
  bg_pass <- NA_integer_
  if (!is.null(a[["above-background"]])) {
    bg <- os_read_matrix(a[["above-background"]], "above-background indicator matrix")
    if (!identical(dimnames(bg), dimnames(mat)) || any(!bg %in% c(0, 1)))
      stop("OS_INVALID_INPUT: above-background data must be 0/1 with exactly the matrix probe and array IDs.", call. = FALSE)
    if (a[["background-k"]] > ncol(mat)) stop("OS_INVALID_PARAMETER: --background-k exceeds the number of arrays.", call. = FALSE)
    keep <- keep & rowSums(bg > 0) >= a[["background-k"]]
    bg_pass <- sum(keep)
  }
  if (sum(keep) < 100L) stop("OS_QC_BLOCKER: fewer than 100 probes remain after filtering.", call. = FALSE)
  mat2 <- mat[keep, , drop = FALSE]
  probe_map <- data.frame(feature_id = rownames(mat2), technical_id = rownames(mat2), stringsAsFactors = FALSE)
  if (!is.null(a[["technical-ids"]])) {
    ids <- utils::read.csv(a[["technical-ids"]], stringsAsFactors = FALSE)
    if (!all(c("feature_id", "technical_id") %in% names(ids)) || anyDuplicated(ids$feature_id) ||
        anyNA(ids$technical_id) || any(!nzchar(ids$technical_id)))
      stop("OS_INVALID_INPUT: technical IDs need unique feature_id rows and nonempty technical_id.", call. = FALSE)
    ix <- match(rownames(mat2), ids$feature_id)
    if (anyNA(ix)) stop("OS_INVALID_INPUT: technical ID mapping does not cover every retained probe.", call. = FALSE)
    probe_map$technical_id <- ids$technical_id[ix]
    mat2 <- limma::avereps(x = mat2, ID = probe_map$technical_id)
  }
  n_multi <- sum(table(probe_map$technical_id) > 1L)
  annotation <- NULL
  if (!is.null(a[["probe-annotation"]])) annotation <- la_probe_annotation(a[["probe-annotation"]], probe_map, rownames(mat2))
  fit <- limma::lmFit(object = mat2, design = model$design, ndups = NULL,
                      spacing = NULL, block = NULL, correlation = NULL,
                      weights = NULL, method = "ls")
  if (a[["min-effect-fc"]] > 1) {
    fit <- limma::treat(fit = fit, fc = a[["min-effect-fc"]],
                        lfc = log2(a[["min-effect-fc"]]), trend = trend,
                        robust = robust, winsor.tail.p = c(0.05, 0.1),
                        legacy = NULL, upshot = FALSE)
  } else {
    fit <- limma::eBayes(fit = fit, proportion = 0.01,
                         stdev.coef.lim = c(0.1, 4), trend = trend,
                         span = NULL, robust = robust,
                         winsor.tail.p = c(0.05, 0.1), legacy = NULL)
  }
  tt <- limma::topTable(fit = fit, coef = model$coef, number = Inf,
                        genelist = fit$genes, adjust.method = "BH", sort.by = "P",
                        resort.by = NULL, p.value = 1, fc = NULL, lfc = NULL,
                        confint = FALSE)
  dsum <- os_limma_direction_summary(tt, a$alpha, model$coef)
  st <- model$samples[[a$condition]]
  lv <- levels(st)
  preset <- a$trend == "auto" && a$robust == "auto"
  tv <- list(
    platform_label = if (a$platform == "agilent") "Agilent platform" else "platform declared as other (no registered preset)",
    preprocessing_sentence = if (is.null(a$preprocessing))
      "The upstream background correction and normalization were not stated to this module and are therefore not reported; the input was used as supplied."
    else sprintf("Input preprocessing, as declared by the user (performed upstream, not verified by this module): %s.", sub("[.]\\s*$", "", trimws(a$preprocessing))),
    control_sentence = if (!is.null(a[["control-ids"]]))
      sprintf("%s control probes listed in the control-ID file (%s) were removed.", format(n_ctrl, big.mark = ","), basename(a[["control-ids"]]))
    else "The input was declared free of control probes (--controls-removed); no control probes were removed by this module.",
    background_sentence = if (!is.null(a[["above-background"]]))
      sprintf("Non-control probes were kept when the supplied 0/1 above-background indicator (%s) was 1 on at least k = %d of %d arrays (%s of %s passed); the rule was applied to the normalized matrix before model fitting.",
              basename(a[["above-background"]]), a[["background-k"]], ncol(mat), format(bg_pass, big.mark = ","), format(n_noncontrol, big.mark = ","))
    else "No above-background data were supplied, so no expression filter was applied.",
    retained_sentence = sprintf("%s of %s input probes were retained for testing.", format(sum(keep), big.mark = ","), format(nrow(mat), big.mark = ",")),
    averaging_sentence = if (!is.null(a[["technical-ids"]]))
      sprintf("Probes sharing a user-supplied technical ID (%s), declared verified as the same technical probe, were averaged with avereps: %s retained probes gave %s tested features, %s of which combined two or more probes (probe-to-feature mapping in tables/probe_mapping.csv).",
              basename(a[["technical-ids"]]), format(sum(keep), big.mark = ","), format(nrow(mat2), big.mark = ","), format(n_multi, big.mark = ","))
    else "No technical averaging was applied; every retained probe was tested as a separate feature.",
    design_sentence = if (length(lv) > 2L)
      sprintf("The design (%s) contained all %d levels of %s (%s); arrays of the other levels contributed to the residual variance and only the %s versus %s coefficient was tested.",
              model$formula, length(lv), a$condition, paste(lv, collapse = ", "), a$target, a$reference)
    else sprintf("The design was %s.", model$formula),
    moderation_sentence = sprintf("empirical Bayes moderation used trend = %s and robust = %s (%s).", trend, robust,
                                  if (preset) "registered Agilent preset" else "chosen explicitly by the user"),
    annotation_sentence = if (is.null(annotation)) "No probe annotation was supplied; features are reported by probe ID only."
    else sprintf("Gene symbols and Entrez IDs were attached from the supplied probe annotation (%s): %s of %s tested features mapped to one symbol, %s unmapped%s (tables/feature_annotation.csv).",
                 basename(a[["probe-annotation"]]), format(sum(annotation$annotation_status == "mapped"), big.mark = ","), format(nrow(annotation), big.mark = ","),
                 format(sum(annotation$annotation_status == "unmapped"), big.mark = ","),
                 if (any(annotation$annotation_status == "conflicting")) sprintf(", %d with conflicting symbols across averaged probes", sum(annotation$annotation_status == "conflicting")) else ""),
    n_notsig = dsum$NotSig)
  list(fit = fit, tt = tt, probe_map = probe_map, sa = a$platform != "agilent", annotation = annotation,
       expr = mat2, expr_scale = "normalized log2 intensity", template_values = tv, detail = "",
       details = list(platform = a$platform, n_input = nrow(mat), n_arrays = ncol(mat),
                      condition_levels = lv, other_levels_in_design = length(lv) > 2L,
                      controls = if (!is.null(a[["control-ids"]])) "removed by control-ID file" else "declared removed upstream",
                      n_controls_removed = n_ctrl, background_k = a[["background-k"]],
                      n_above_background_pass = if (is.na(bg_pass)) NULL else bg_pass,
                      n_retained_before_avereps = sum(keep), n_tested = nrow(mat2),
                      technical_ids_averaged = !is.null(a[["technical-ids"]]), n_technical_ids_multi = n_multi,
                      trend = trend, robust = robust, moderation_source = if (preset) "agilent_preset" else "user",
                      preprocessing_declared = a$preprocessing %||% "not stated",
                      annotation_mapped = if (is.null(annotation)) NULL else sum(annotation$annotation_status == "mapped"),
                      annotation_unmapped = if (is.null(annotation)) NULL else sum(annotation$annotation_status == "unmapped"),
                      annotation_conflicting = if (is.null(annotation)) NULL else sum(annotation$annotation_status == "conflicting")))
}
