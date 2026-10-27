# Plate wells estimate assay precision, never biological replication.
drc_calibrate_compute <- function(a) {
 if (is.null(a[["unit-col"]]) || !nzchar(trimws(a[["unit-col"]]))) sc_stop("MISSING_PARAMETER", "unit-col must declare biological identities")
 d <- sc_read(a$input, c(a[["unit-col"]], "plate_id", "well", "role", "sample_id", "concentration", "dilution", "response"))
 sc_ids(d, c("plate_id", "well", "role", "sample_id"))
 if (length(unique(d$plate_id)) != 1L || anyDuplicated(d$well)) sc_stop("INVALID_DESIGN", "one plate per run and unique well identities required")
 if (any(!d$role %in% c("blank", "standard", "unknown"))) sc_stop("INVALID_INPUT", "role must be blank, standard or unknown")
 unknown_rows <- d$role == "unknown"
 if (!any(unknown_rows)) sc_stop("INVALID_DESIGN", "unknown assay samples are required")
 sc_ids(d[unknown_rows, , drop = FALSE], a[["unit-col"]])
 unit_values <- d[[a[["unit-col"]]]]
 d$biological_unit <- NA_character_
 d$biological_unit[unknown_rows] <- unit_values[unknown_rows]
 unit_map <- unique(d[unknown_rows, c("sample_id", "biological_unit"), drop = FALSE])
 if (anyDuplicated(unit_map$sample_id)) sc_stop("INVALID_DESIGN", "one assay sample cannot map to multiple biological units")
 d$response <- sc_num(d$response, "response"); d$dilution <- sc_num(d$dilution, "dilution")
 if (any(d$dilution < 1)) sc_stop("INVALID_INPUT", "dilution is a factor >= 1")
 blank <- d$role == "blank"
 if (any(d$dilution[blank] != 1)) sc_stop("INVALID_INPUT", "blank dilution must be 1")
 if (a[["blank-policy"]] == "subtract-mean" && sum(blank) < 2L) sc_stop("INVALID_DESIGN", "subtract-mean needs at least two blank wells")
 offset <- if (a[["blank-policy"]] == "subtract-mean") mean(d$response[blank]) else 0
 d$corrected <- d$response - offset
 if (any(!is.na(d$concentration[d$role != "standard"]))) sc_stop("INVALID_INPUT", "only standard wells may declare concentration")
 if (length(intersect(d$sample_id[blank], d$sample_id[!blank]))) sc_stop("INVALID_DESIGN", "blank identities cannot label assay samples")
 if (!nzchar(trimws(a[["dose-unit"]]))) sc_stop("INVALID_INPUT", "dose unit must be nonempty")
 wells <- d[!blank, , drop = FALSE]
 if (!nrow(wells)) sc_stop("INVALID_DESIGN", "no assay wells")
 key <- interaction(match(wells$role, unique(wells$role)), match(wells$sample_id, unique(wells$sample_id)), match(wells$dilution, unique(wells$dilution)), drop = TRUE)
 summaries <- lapply(split(wells, key), function(z) {
  if (nrow(z) < 2L) sc_stop("INVALID_DESIGN", "each sample/dilution requires >=2 technical wells")
  m <- mean(z$corrected); s <- stats::sd(z$corrected)
  data.frame(role = z$role[1], sample_id = z$sample_id[1], dilution = z$dilution[1],
   response = m, sd = s, n_wells = nrow(z), cv_percent = if (m > 0) 100 * s / m else NA_real_,
   cv_flag = if (m <= 0) "nonpositive_mean" else if (100 * s / m > a[["max-cv"]]) "high_cv" else "ok")
 })
 tech <- do.call(rbind, summaries); rownames(tech) <- NULL
 curves <- list(); objects <- list(); inv <- list()
 standards <- data.frame(well = character(0), sample_id = character(0), dose = numeric(0), response = numeric(0),
  back_calculated = numeric(0), recovery_percent = numeric(0), status = character(0))
 ci <- a[["ci-level"]]
 if (a$mode == "calibration") {
  if (!is.null(a[["titer-definition"]]) || !is.null(a[["endpoint-response"]])) sc_stop("INVALID_PARAMETER", "titer flags require titer mode")
  if (is.null(a$lloq) || is.null(a$uloq) || a$lloq <= 0 || a$lloq >= a$uloq) sc_stop("INVALID_PARAMETER", "declare 0 < lloq < uloq in diluted-well concentration units")
  std <- d[d$role == "standard", , drop = FALSE]; unk <- tech[tech$role == "unknown", , drop = FALSE]
  if (!nrow(std) || !nrow(unk)) sc_stop("INVALID_DESIGN", "calibration requires standards and unknown samples")
  std$dose <- sc_num(std$concentration, "standard concentration")
  if (any(std$dose <= 0) || any(std$dilution != 1)) sc_stop("INVALID_INPUT", "standards need positive known concentrations and dilution 1")
  if (a$lloq < min(std$dose) || a$uloq > max(std$dose)) sc_stop("INVALID_PARAMETER", "LLOQ/ULOQ must lie inside tested standards")
  for (z in split(std, std$sample_id)) if (length(unique(z$dose)) != 1L) sc_stop("INVALID_DESIGN", "standard identity has inconsistent concentrations")
  if (length(intersect(std$sample_id, unk$sample_id)) || anyDuplicated(unk$sample_id)) sc_stop("INVALID_DESIGN", "unknown identity must have exactly one dilution and cannot also be a standard")
  std$response <- std$corrected
  fit <- sc_fit_drc(std, a$model); objects$standard_curve <- fit
  curves[[1]] <- transform(sc_grid(fit, std$dose), curve = "Standards")
  p <- as.numeric(stats::coef(fit))
  for (i in seq_len(nrow(unk))) {
   z <- unk[i, ]; val <- lo <- hi <- se <- NA_real_; flags <- character(0)
   if (z$response <= p[2] || z$response >= p[3]) flags <- "outside_asymptotes" else {
    ed <- sc_inverse(fit, z$response, "absolute", ci, mean_se = z$sd / sqrt(z$n_wells))
    x <- ed[1]; se <- ed[2]; lo <- ed[3]; hi <- ed[4]
    if (x < min(std$dose) || x > max(std$dose)) flags <- c(flags, "outside_standards")
    if (x < a$lloq) flags <- c(flags, "below_LLOQ")
    if (x > a$uloq) flags <- c(flags, "above_ULOQ")
    if (!length(flags)) val <- x
    if (lo < a$lloq || hi > a$uloq) flags <- c(flags, "interval_crosses_limits")
   }
   # Never export extrapolated concentrations or their limits as quantitative results.
   withheld <- is.na(val)
   if (withheld) lo <- hi <- se <- NA_real_
   inv[[i]] <- data.frame(sample_id = z$sample_id, dilution = z$dilution, n_technical_wells = z$n_wells,
    response = z$response, cv_percent = z$cv_percent, cv_flag = z$cv_flag,
    well_concentration = val, well_se = se, well_ci_low = lo, well_ci_high = hi,
    concentration = val * z$dilution, ci_low = lo * z$dilution, ci_high = hi * z$dilution,
    lloq_original = a$lloq * z$dilution, uloq_original = a$uloq * z$dilution,
    status = if (length(flags)) paste(flags, collapse = ";") else "in_range", withheld = withheld)
  }
  for (i in seq_len(nrow(std))) {
   z <- std[i, ]; b <- if (z$response > p[2] && z$response < p[3]) sc_ed(fit, z$response, "absolute", ci)[1] else NA_real_
   standards <- rbind(standards, data.frame(well = z$well, sample_id = z$sample_id, dose = z$dose, response = z$response,
    back_calculated = b, recovery_percent = 100 * b / z$dose,
    status = if (!is.finite(b)) "outside_asymptotes" else if (b < min(std$dose) || b > max(std$dose)) "outside_standards_diagnostic_only" else if (b < a$lloq || b > a$uloq) "outside_quantification_limits_diagnostic_only" else "in_range"))
  }
  results <- do.call(rbind, inv)
  valid <- results[!results$withheld, , drop = FALSE]
  et <- if (!nrow(valid)) new_effect_table() else add_effect_rows(term = valid$sample_id, analysis_id = "drc-calibrate", effect_type = "other",
   estimate = valid$concentration, ci_low = valid$ci_low, ci_high = valid$ci_high, ci_level = ci, n_unweighted = 1L,
   test_name = "Inverse delta with technical-mean variance", notes = "Assay concentration; technical wells are not biological n; intervals conditional on blank correction")
  obs <- data.frame(dose = std$dose, response = std$response, curve = "Standards")
 } else {
  if (!is.null(a$lloq) || !is.null(a$uloq)) sc_stop("INVALID_PARAMETER", "LLOQ/ULOQ flags require calibration mode")
  if (any(d$role == "standard") || !any(d$role == "unknown")) sc_stop("INVALID_DESIGN", "titer input uses unknown serial-dilution wells and optional blanks only")
  if (is.null(a[["titer-definition"]])) sc_stop("INVALID_PARAMETER", "declare titer-definition")
  if (a[["titer-definition"]] == "endpoint" && is.null(a[["endpoint-response"]])) sc_stop("INVALID_PARAMETER", "endpoint requires corrected-scale endpoint-response")
  if (a[["titer-definition"]] == "halfmax" && !is.null(a[["endpoint-response"]])) sc_stop("INVALID_PARAMETER", "halfmax does not accept endpoint-response")
  obs <- data.frame(dose = wells$dilution, response = wells$corrected, curve = wells$sample_id)
  for (id in unique(wells$sample_id)) {
   z <- obs[obs$curve == id, ]; fit <- sc_fit_drc(z, a$model); objects[[id]] <- fit
   p <- as.numeric(stats::coef(fit))
   if (p[1] <= 0) sc_stop("INVALID_DESIGN", "titer response must decline with increasing reciprocal dilution")
   level <- if (a[["titer-definition"]] == "halfmax") 50 else a[["endpoint-response"]]
   if (a[["titer-definition"]] == "endpoint" && (level <= p[2] || level >= p[3])) sc_stop("INVALID_PARAMETER", "endpoint is outside fitted asymptotes")
   ed <- sc_inverse(fit, level, if (a[["titer-definition"]] == "halfmax") "relative" else "absolute", ci)
   outside <- ed[1] < min(z$dose) || ed[1] > max(z$dose)
   inv[[id]] <- data.frame(sample_id = id, titer = if (outside) NA_real_ else ed[1],
    ci_low = if (outside) NA_real_ else ed[3], ci_high = if (outside) NA_real_ else ed[4],
    status = if (outside) "outside_dilutions" else if (ed[3] < min(z$dose) || ed[4] > max(z$dose)) "interval_crosses_dilutions" else "in_range",
    withheld = outside, n_technical_wells = nrow(z), n_dilutions = length(unique(z$dose)))
   curves[[id]] <- transform(sc_grid(fit, z$dose), curve = id)
  }
  results <- do.call(rbind, inv); rownames(results) <- NULL
  valid <- results[!results$withheld, , drop = FALSE]
  et <- if (!nrow(valid)) new_effect_table() else add_effect_rows(term = valid$sample_id, analysis_id = "drc-calibrate", effect_type = "other",
   estimate = valid$titer, ci_low = valid$ci_low, ci_high = valid$ci_high, ci_level = ci, n_unweighted = 1L,
   test_name = "drc titer delta", notes = "Reciprocal dilution at declared response; one assay curve per sample, no biological-group inference")
 }
 results$biological_unit <- unit_map$biological_unit[match(results$sample_id, unit_map$sample_id)]
 unit_map <- unit_map[order(unit_map$sample_id), , drop = FALSE]; rownames(unit_map) <- NULL
 meta <- list(unit_column = a[["unit-col"]], n_biological_units = length(unique(unit_map$biological_unit)), mode = a$mode, model = a$model, blank_policy = a[["blank-policy"]], blank_offset = offset,
  n_blank_wells = sum(blank), n_technical_wells = sum(!blank), n_samples = length(unique(wells$sample_id[wells$role == "unknown"])),
  technical_wells_are_biological_replicates = FALSE, interval = "delta; pointwise; conditional on observed blank mean",
  dose_unit = a[["dose-unit"]], ci_level = ci, lloq = a$lloq, uloq = a$uloq, max_cv = a[["max-cv"]],
  titer_definition = a[["titer-definition"]], endpoint_response = a[["endpoint-response"]], study_contract_sha256 = a[["study-contract-sha256"]])
 list(object = objects, metadata = meta, packages = c("drc", "jsonlite", "digest"), ready = !any(results$withheld),
  method = "Unweighted continuous drc LL4/LL5 measurement-error fit. Technical wells estimate assay precision only. Delta intervals are conditional on fixed blank correction and do not cover matrix effects or biological variability. LLOQ/ULOQ are supplied assay-validation limits, not inferred validation claims.",
  tables = list(effect_table = et, results = results, biological_units = unit_map, technical_precision = tech, observations = obs,
   curve_predictions = do.call(rbind, curves), standards = standards, plate_wells = d),
  qc = list(os_qc_rule("CAL-01", "Range", any(results$withheld), "blocker", "Out-of-range samples withheld.", "Redilute and remeasure."),
   os_qc_rule("CAL-02", "Technical precision", any(tech$cv_flag != "ok"), "blocker", "Technical CV exceeds declared limit or is undefined.", "Review replicate wells.")))
}
