omicstat_ddct_compute <- function(a) {
 raw <- .os_read_delim(a$input)
 cols <- c(a[["ct-col"]], a[["gene-col"]], a[["group-col"]], a[["unit-col"]], a[["well-col"]])
 if (anyDuplicated(cols)) stop("OS_INVALID_DESIGN: Ct, gene, group, unit and well must be distinct columns", call. = FALSE)
 os_check_columns(raw, cols)
 d <- data.frame(ct = os_as_finite(raw[[cols[1]]], "Ct"), gene = raw[[cols[2]]], group = raw[[cols[3]]], unit = raw[[cols[4]]], well = raw[[cols[5]]], stringsAsFactors = FALSE)
 if (any(d$ct <= 0 | d$ct > a[["ct-max"]])) stop("OS_INVALID_INPUT: nonpositive or over-limit Ct; no imputation of undetermined values", call. = FALSE)
 for (k in c("gene", "group", "unit", "well")) if (anyNA(d[[k]]) || any(!nzchar(trimws(d[[k]]))))
  stop("OS_INVALID_DESIGN: gene/group/biological unit/well identities cannot be missing", call. = FALSE)
 if (anyDuplicated(d[c("gene", "group", "unit", "well")])) stop("OS_INVALID_DESIGN: duplicate technical well identity", call. = FALSE)
 targets <- strsplit(a[["target-genes"]], ",", fixed = TRUE)[[1]]; ref <- a[["reference-gene"]]
 lv <- strsplit(a[["group-order"]], ",", fixed = TRUE)[[1]]; cal <- a[["reference-group"]]
 if (!length(targets) || any(!nzchar(targets)) || anyDuplicated(targets) || ref %in% targets || !setequal(c(targets, ref), unique(d$gene)))
  stop("OS_INVALID_DESIGN: exact target/reference gene set required; no silent gene filtering", call. = FALSE)
 if (length(lv) < 2 || anyDuplicated(lv) || !setequal(lv, unique(d$group)) || !cal %in% lv)
  stop("OS_INVALID_DESIGN: complete group-order and observed calibrator required", call. = FALSE)
 if (file.info(a[["assay-validation"]])$size > 1024^2) stop("OS_INVALID_INPUT: assay-validation exceeds one MiB", call. = FALSE)
 v <- tryCatch(jsonlite::fromJSON(a[["assay-validation"]], simplifyVector = FALSE), error = function(e) stop("OS_INVALID_INPUT: assay-validation must be JSON", call. = FALSE))
 required <- c("schema", "target_genes", "reference_gene", "equal_efficiency_confirmed", "near_two_amplification_confirmed", "reference_stability_confirmed", "source", "basis")
 if (!all(required %in% names(v)) || !identical(v$schema, "omicstat.qpcr-assay.v1") || !identical(v$reference_gene, ref) ||
     !is.list(v$target_genes) || !all(vapply(v$target_genes, function(x) is.character(x) && length(x) == 1 && !is.na(x), logical(1))) || anyDuplicated(unlist(v$target_genes)) || !setequal(unlist(v$target_genes), targets) || !isTRUE(v$equal_efficiency_confirmed) || !isTRUE(v$near_two_amplification_confirmed) ||
     !isTRUE(v$reference_stability_confirmed) || !is.character(v$source) || length(v$source) != 1 || !nzchar(trimws(v$source)) ||
     !is.character(v$basis) || length(v$basis) != 1 || !nzchar(trimws(v$basis)))
  stop("OS_INVALID_DESIGN: delta-delta-Ct requires explicit matched assay validation; declarations do not measure efficiency", call. = FALSE)
 keys <- unique(d[c("group", "unit")]); keys <- keys[order(match(keys$group, lv), keys$unit), ]
 if (a$design == "independent" && anyDuplicated(keys$unit)) stop("OS_INVALID_DESIGN: independent groups must have disjoint biological units", call. = FALSE)
 if (a$design == "paired") {
  ss <- lapply(lv, function(g) sort(keys$unit[keys$group == g]))
  if (!all(vapply(ss, identical, logical(1), ss[[1]]))) stop("OS_INVALID_DESIGN: paired design requires complete subject sets", call. = FALSE)
 }
 if ((a$inference == "welch" && a$design != "independent") || (a$inference == "paired-t" && a$design != "paired"))
  stop("OS_INVALID_DESIGN: inference method and biological design disagree", call. = FALSE)
 if (a$inference != "descriptive" && any(table(keys$group) < 2)) stop("OS_INVALID_DESIGN: biological inference needs at least two units per group; technical wells never substitute", call. = FALSE)
 family <- length(targets) * (length(lv) - 1L)
 if (a[["family-size"]] < family) stop("OS_INVALID_DESIGN: family-size must cover all target/calibrator comparisons", call. = FALSE)
 rows <- list()
 for (i in seq_len(nrow(keys))) {
  z <- d[d$unit == keys$unit[i] & d$group == keys$group[i], ]
  rr <- z[z$gene == ref, ]; if (!nrow(rr)) stop("OS_INVALID_DESIGN: reference missing within biological unit/group", call. = FALSE)
  for (gene in targets) {
   tt <- z[z$gene == gene, ]; if (!nrow(tt)) stop("OS_INVALID_DESIGN: target missing within biological unit/group", call. = FALSE)
   if (a[["well-layout"]] == "same") {
    if (!setequal(tt$well, rr$well)) stop("OS_INVALID_DESIGN: same-well assay needs exact target/reference well matching", call. = FALSE)
    rr_match <- rr[match(tt$well, rr$well), ]; delta <- tt$ct - rr_match$ct
    delta_mean <- mean(delta); technical_sd <- if (length(delta) > 1) stats::sd(delta) else NA_real_
   } else {
    delta_mean <- mean(tt$ct) - mean(rr$ct)
    technical_sd <- if (nrow(tt) > 1 && nrow(rr) > 1) sqrt(stats::var(tt$ct) + stats::var(rr$ct)) else NA_real_
   }
   rows[[length(rows) + 1L]] <- data.frame(unit = keys$unit[i], group = keys$group[i], target = gene,
    mean_target_ct = mean(tt$ct), mean_reference_ct = mean(rr$ct), n_target_technical = nrow(tt), n_reference_technical = nrow(rr),
    delta_ct = delta_mean, technical_delta_ct_sd = technical_sd, stringsAsFactors = FALSE)
  }
 }
 units <- do.call(rbind, rows); units$delta_delta_ct <- NA_real_; units$fold_change <- NA_real_
 sums <- list(); tests <- list(); effects <- list()
 for (gene in targets) {
  z <- units[units$target == gene, ]; cc <- z[z$group == cal, ]; calibrator <- mean(cc$delta_ct)
  idx <- units$target == gene; units$delta_delta_ct[idx] <- units$delta_ct[idx] - calibrator
  units$fold_change[idx] <- 2^(-units$delta_delta_ct[idx])
  for (g in lv) {
   xx <- z[z$group == g, ]; dd <- mean(xx$delta_ct) - calibrator
   sums[[length(sums) + 1L]] <- data.frame(target = gene, group = g, reference_group = cal,
    n_biological = nrow(xx), mean_delta_ct = mean(xx$delta_ct), delta_delta_ct = dd, fold_geometric = 2^(-dd),
    fold_arithmetic = mean(2^(-(xx$delta_ct - calibrator))), biological_delta_ct_sd = if (nrow(xx) > 1) stats::sd(xx$delta_ct) else NA_real_)
   if (g != cal && a$inference != "descriptive") {
    yy <- if (a$design == "paired") cc[match(xx$unit, cc$unit), ] else cc
    fit <- os_basic_test(stats::t.test(x = xx$delta_ct, y = yy$delta_ct, alternative = "two.sided", mu = 0,
     paired = a$design == "paired", var.equal = FALSE, conf.level = a[["ci-level"]]))
    if (!is.finite(fit$p.value)) stop("OS_INVALID_DESIGN: biological delta-Ct test is undefined", call. = FALSE)
    tests[[length(tests) + 1L]] <- data.frame(target = gene, group = g, reference_group = cal, test = a$inference,
     statistic = unname(fit$statistic), df = unname(fit$parameter), p_value = fit$p.value,
     n_treatment_biological = nrow(xx), n_calibrator_biological = nrow(yy))
    effects[[length(effects) + 1L]] <- data.frame(term = paste(gene, g, "vs", cal), target = gene, group = g, reference_group = cal,
     estimate = dd, ci_low = fit$conf.int[1], ci_high = fit$conf.int[2], effect_scale = "delta_delta_ct_treatment_minus_calibrator",
     fold_change = 2^(-dd), fold_ci_low = 2^(-fit$conf.int[2]), fold_ci_high = 2^(-fit$conf.int[1]),
     ci_level = a[["ci-level"]], ci_adjustment = "none_marginal")
   }
  }
 }
 # These optional ranges reproduce Livak Table 1 technical-SD convention,
 # treating the calibrator mean as a constant. They are not biological CIs/SEs.
 units$technical_fold_lower <- 2^(-(units$delta_delta_ct + units$technical_delta_ct_sd))
 units$technical_fold_upper <- 2^(-(units$delta_delta_ct - units$technical_delta_ct_sd))
 if (any(!is.finite(units$fold_change)) || any(units$fold_change <= 0)) stop("OS_INVALID_INPUT: fold transform overflow/underflow", call. = FALSE)
 tables <- list(biological_units = units, summary = do.call(rbind, sums))
 if (length(tests)) {
  tt <- do.call(rbind, tests); tt$p_adjusted <- stats::p.adjust(p = tt$p_value, method = a$adjust, n = a[["family-size"]])
  tt$adjustment <- a$adjust; tt$family_size <- a[["family-size"]]
  tables$tests <- tt; tables$effect_table <- do.call(rbind, effects)
 }
 metadata <- list(design = a$design, inference = a$inference, well_layout = a[["well-layout"]], reference_gene = ref,
  reference_group = cal, targets = targets, group_order = lv, ct_max = a[["ct-max"]], input_wells = nrow(d),
  n_units = length(unique(keys$unit)), unit_column = a[["unit-col"]], technical_policy = "mean_within_biological_unit_gene",
  assay_validation = v, assay_validation_is_user_declaration = TRUE, adjustment = a$adjust, family_size = a[["family-size"]],
  ci_level = a[["ci-level"]], ci_adjustment = "none_marginal", display = a$display, journal = a$journal,
  technical_range = "delta-Ct plus/minus technical SD; calibrator mean held constant; NOT biological CI")
 list(tables = tables, metadata = metadata, object = list(units = units, summary = tables$summary), handoff_type = "development_ddct",
  input_files = list(assay_validation = a[["assay-validation"]]), ready = FALSE, packages = c("stats", "jsonlite"),
  method = "Within-unit technical Ct normalization; fold=2^(-delta-delta-Ct). Inference, when declared, tests biological delta-Ct; fold CI reverses transformed endpoints. Assay assumptions are user declarations, not measured by this module.")
}
