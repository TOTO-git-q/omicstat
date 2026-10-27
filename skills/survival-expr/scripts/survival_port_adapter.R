# P0-13 B3: independently maintained source-copy adapter, no MedStat runtime.
.os_survival_ports <- local({
  if (!requireNamespace("survival", quietly = TRUE)) stop("OS_MISSING_PACKAGE: survival is required for this independent source port", call. = FALSE)
  files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
  here <- dirname(normalizePath(tail(files[nzchar(files)], 1), mustWork = TRUE))
  load_one <- function(name) {
    e <- new.env(parent = baseenv())
    e$Surv <- survival::Surv
    e$strata <- survival::strata
    e$tail <- utils::tail
    sys.source(file.path(here, paste0("survival_ported_", name, ".R")), envir = e)
    e
  }
  list(nonph = load_one("nonph"), cr = load_one("cr"))
})

os_srv_present <- function(x) !is.null(x) && length(x) > 0L
os_srv_require <- function(a, flags) {
  missing <- flags[!vapply(flags, function(n) os_srv_present(a[[n]]), logical(1))]
  if (length(missing)) stop(paste0("OS_MISSING_PARAMETER: explicitly declare ", paste(paste0("--", missing), collapse = ", ")), call. = FALSE)
  invisible(TRUE)
}
os_srv_numbers <- function(text, what, lower = 0, upper = Inf, max_n = 1000L) {
  values <- suppressWarnings(as.numeric(strsplit(text, ",", fixed = TRUE)[[1]]))
  if (!length(values) || length(values) > max_n || any(!is.finite(values)) ||
      any(values < lower | values > upper) || anyDuplicated(values) || is.unsorted(values, strictly = TRUE))
    stop(paste("OS_INVALID_PARAMETER: sorted unique finite", what, "within the declared bounds required; no silent sorting or truncation"), call. = FALSE)
  values
}
os_srv_extension_contract <- function(a, mode) {
  if (!mode %in% c("nonph", "competing-risks")) stop("OS_INVALID_PARAMETER: unknown survival extension", call. = FALSE)
  os_srv_require(a, "dataset-name")
  if (!is.character(a[["dataset-name"]]) || length(a[["dataset-name"]]) != 1L ||
      !nzchar(trimws(a[["dataset-name"]])) || nchar(a[["dataset-name"]]) > 160L ||
      grepl("[\r\n]", a[["dataset-name"]])) stop("OS_INVALID_PARAMETER: one nonempty dataset label of at most 160 characters is required", call. = FALSE)
  nonph <- c("nonph-primary", "nonph-transforms", "nonph-magnitude", "piecewise-cuts", "piecewise-gene", "piecewise-fit", "piecewise-adjust", "piecewise-family-size")
  cr <- c("competing-status-col", "event-of-interest", "cif-estimator", "cif-interval")
  foreign <- if (mode == "nonph") cr else nonph
  if (any(vapply(foreign, function(n) os_srv_present(a[[n]]), logical(1))))
    stop("OS_INVALID_PARAMETER: flags for the inactive survival extension must not be supplied", call. = FALSE)
  if (mode == "nonph") {
    os_srv_require(a, c("nonph-primary", "nonph-transforms", "nonph-magnitude"))
    if (!a[["nonph-primary"]] %in% c("cox", "piecewise")) stop("OS_INVALID_PARAMETER: prespecify the primary summary; automatic model selection is forbidden", call. = FALSE)
    tr <- strsplit(a[["nonph-transforms"]], ",", fixed = TRUE)[[1]]
    if (!length(tr) || anyDuplicated(tr) || !all(tr %in% c("km", "rank", "identity", "log")) || !a[["ph-transform"]] %in% tr)
      stop("OS_INVALID_PARAMETER: unique declared PH transforms must include the original primary transform", call. = FALSE)
    mag <- a[["nonph-magnitude"]]
    if (length(mag) != 1L || !is.numeric(mag) || !is.finite(mag) || mag < 0.000001)
      stop("OS_INVALID_PARAMETER: a positive prespecified engineering magnitude threshold is required", call. = FALSE)
    piece <- nonph[startsWith(nonph, "piecewise-")]
    if (a[["nonph-primary"]] == "piecewise") os_srv_require(a, piece)
    else if (any(vapply(piece, function(n) os_srv_present(a[[n]]), logical(1))))
      stop("OS_INVALID_PARAMETER: piecewise parameters require the prespecified piecewise primary summary", call. = FALSE)
    if (a[["nonph-primary"]] == "piecewise") {
      if (!identical(a[["piecewise-fit"]], "source-native")) stop("OS_INVALID_PARAMETER: acknowledge source-native piecewise Cox defaults separately from the original continuous-model controls", call. = FALSE)
      if (!a[["piecewise-adjust"]] %in% c("none", "holm", "bonferroni", "BH", "BY")) stop("OS_INVALID_PARAMETER: explicitly declare period-test adjustment", call. = FALSE)
      n <- a[["piecewise-family-size"]]
      if (length(n) != 1L || !is.numeric(n) || !is.finite(n) || n < 2 || n != floor(n)) stop("OS_INVALID_PARAMETER: integer planned piecewise family size is required", call. = FALSE)
    }
  } else {
    os_srv_require(a, cr)
    if (!identical(a[["cif-estimator"]], "aalen-johansen")) stop("OS_INVALID_PARAMETER: competing-risk cumulative incidence must use Aalen-Johansen, never one-minus-KM", call. = FALSE)
    if (!identical(a[["cif-interval"]], "none")) stop("OS_INVALID_PARAMETER: the copied AJ primitive provides point estimates only; no CI or Gray test is available in this port", call. = FALSE)
    if (!identical(a$covariates, "none") || !identical(a$scaling, "none")) stop("OS_INVALID_PARAMETER: unadjusted descriptive CIF requires covariates=none and scaling=none; no adjusted model is fitted", call. = FALSE)
    if (!a$cutoff %in% c("median", "prespecified") || isTRUE(a$exploratory) || os_srv_present(a[["min-group-fraction"]]))
      stop("OS_INVALID_PARAMETER: CIF display permits only an outcome-independent declared split; optimal cutpoint search is unavailable", call. = FALSE)
    if (a$cutoff == "prespecified") os_srv_require(a, "cutpoint")
    else if (os_srv_present(a$cutpoint)) stop("OS_INVALID_PARAMETER: cutpoint is only valid with a prespecified split", call. = FALSE)
    if (length(a[["event-of-interest"]]) != 1L || !is.numeric(a[["event-of-interest"]]) ||
        !is.finite(a[["event-of-interest"]]) || a[["event-of-interest"]] < 1 || a[["event-of-interest"]] > .Machine$integer.max || a[["event-of-interest"]] != floor(a[["event-of-interest"]]))
      stop("OS_INVALID_PARAMETER: nominate one positive integer event code", call. = FALSE)
  }
  invisible(TRUE)
}

os_srv_nonph_compute <- function(a) {
  os_srv_extension_contract(a, "nonph")
  # Same existing model objects, same scientific parameters and legacy tables.
  res <- survival_expr_compute_legacy(a)
  port <- .os_survival_ports$nonph
  transforms <- strsplit(a[["nonph-transforms"]], ",", fixed = TRUE)[[1]]
  diagnostics <- list(); severity <- list()
  for (gene in names(res$object)) {
    d <- port$zph_diagnostics(res$object[[gene]], transforms = transforms)
    if (any(!is.finite(d$chisq)) || any(!is.finite(d$p)) || any(d$p < 0 | d$p > 1))
      stop("OS_INVALID_RESULT: nonfinite or invalid PH diagnostic; do not classify a missing test", call. = FALSE)
    c <- port$zph_classify(d, "expression", primary_transform = a[["ph-transform"]], magnitude_threshold = a[["nonph-magnitude"]])
    d$gene <- gene; diagnostics[[gene]] <- d
    severity[[gene]] <- data.frame(gene = gene, severity = c$severity, p_global = c$p_global,
      p_term = c$p_term, delta_loghr = c$delta_loghr, reason = c$reason, source_significance_threshold = 0.05,
      engineering_magnitude_threshold = a[["nonph-magnitude"]], stringsAsFactors = FALSE)
  }
  res$tables$nonph_diagnostics <- do.call(rbind, diagnostics)
  res$tables$nonph_severity <- do.call(rbind, severity)
  res$metadata$survival_extension <- "nonph"
  res$metadata$dataset_name <- a[["dataset-name"]]
  res$metadata$nonph <- list(primary = a[["nonph-primary"]], automatic_model_selection = FALSE,
    transforms = transforms, primary_transform = a[["ph-transform"]], source_significance_threshold = 0.05,
    legacy_diagnostic_threshold = a[["ph-alpha"]], magnitude_threshold = a[["nonph-magnitude"]],
    magnitude_basis = "User-prespecified engineering threshold; source suggested 0.20 is not a universal literature cutoff",
    missing_slope_policy = "Copied source classification may label low when magnitude is missing; consult the explicit NA and reason, never interpret as proof of proportional hazards",
    crossing_assessment = "not_assessed", source_native_equivalence = "pending_native_same_input_tests")
  if (a[["nonph-primary"]] == "piecewise") {
    inp <- os_survival_input(a); dat <- inp$clinical
    gene <- a[["piecewise-gene"]]
    if (!gene %in% rownames(inp$E)) stop("OS_INVALID_PARAMETER: piecewise gene must be one of the prespecified genes", call. = FALSE)
    cuts <- os_srv_numbers(a[["piecewise-cuts"]], "piecewise cuts", lower = 0, upper = max(dat$time), max_n = 10L)
    if (any(cuts <= 0 | cuts >= max(dat$time))) stop("OS_INVALID_PARAMETER: each cut must lie strictly inside observed follow-up", call. = FALSE)
    if (a[["piecewise-family-size"]] < length(cuts) + 1L) stop("OS_INVALID_PARAMETER: planned period-test family must cover all periods, including non-estimable periods", call. = FALSE)
    x <- as.numeric(inp$E[gene, ])
    if (identical(a$scaling, "zscore")) x <- (x - mean(x)) / stats::sd(x)
    dat$expression <- x
    ds <- port$piecewise_split(dat, "time", "event", cuts = cuts)
    hr <- port$piecewise_hr(ds, "expression", covars = if (length(inp$covariates)) paste0("c", seq_along(inp$covariates)) else character(), alpha = 1 - a[["ci-level"]])
    bounds <- c(0, cuts, Inf)
    hr$source_period_label <- as.character(hr$period)
    hr$interval_start <- head(bounds, -1L); hr$interval_end <- tail(bounds, -1L)
    hr$period <- vapply(seq_len(nrow(hr)), function(i) paste0("(", format(hr$interval_start[i], trim = TRUE), ",", if (is.infinite(hr$interval_end[i])) "Inf" else format(hr$interval_end[i], trim = TRUE), "]"), "")
    hr$interval_convention <- "counting-process (start, stop]; an event exactly at a cut belongs to the earlier period"
    hr$gene <- gene
    hr$p_adjusted <- stats::p.adjust(p = hr$p_value, method = a[["piecewise-adjust"]], n = a[["piecewise-family-size"]])
    res$tables$piecewise_hr <- hr
    res$metadata$piecewise <- list(gene = gene, cuts = cuts, source_labels = attr(ds, "period_labels"),
      interval_convention = "(start, stop]", formula = "Surv(tstart, time, event) ~ expression:strata(period) + prespecified numeric covariates",
      n_original_subjects = nrow(dat), n_split_rows = nrow(ds), n_zero_time_nudged = attr(ds, "n_zero_time"),
      fit_policy = "source-native", native_package_version = as.character(utils::packageVersion("survival")),
      coxph_formals = paste(deparse(formals(survival::coxph)), collapse = "\n"),
      coxph_control_formals = paste(deparse(formals(survival::coxph.control)), collapse = "\n"),
      original_continuous_model_controls_apply_to_piecewise = FALSE,
      ci_level = a[["ci-level"]], adjustment = a[["piecewise-adjust"]], planned_family_size = a[["piecewise-family-size"]],
      n_nonestimable = sum(!is.finite(hr$hr) | !is.finite(hr$ci_low) | !is.finite(hr$ci_high)),
      native_warnings = attr(hr, "coxph_warnings"), source_event_support_guard = "two-level exposure: event in each arm; otherwise at least two distinct observed expression values with events per period")
  }
  res$method <- c(res$method, "P0-13B3 copied non-PH diagnostics reuse the same fitted Cox objects; severity never selects or refits an analysis.",
    "Source classification uses fixed P=0.05, independently of the existing --ph-alpha. The declared magnitude is an engineering threshold, not a literature recommendation.",
    if (a[["nonph-primary"]] == "piecewise") "Prespecified piecewise HR uses copied unweighted source-native Cox defaults. Existing --ties/--max-iter/--cox-eps affect the original continuous fits only; inspect captured native formals. Complete period rows and non-estimable results remain visible. No landmark, RMST or survey model is substituted.")
  res
}

os_srv_competing_compute <- function(a) {
  os_srv_extension_contract(a, "competing-risks")
  inp <- os_survival_input(a); d <- inp$clinical; E <- inp$E
  if (!a[["km-gene"]] %in% rownames(E)) stop("OS_INVALID_PARAMETER: display gene must be prespecified", call. = FALSE)
  status_col <- a[["competing-status-col"]]
  if (status_col %in% c(a[["unit-col"]], a[["time-col"]], a[["event-col"]])) stop("OS_INVALID_DESIGN: competing status must be a distinct column; the binary event declaration is not silently recoded", call. = FALSE)
  raw <- utils::read.csv(a$clinical, check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character")
  os_check_columns(raw, status_col)
  status <- os_as_finite(raw[[status_col]][match(d$unit, raw[[a[["unit-col"]]]])], "competing event status")
  if (any(status > .Machine$integer.max)) stop("OS_INVALID_INPUT: status exceeds the supported integer representation", call. = FALSE)
  port <- .os_survival_ports$cr
  cr <- port$cr_status(status)
  if (cr$k < 2L) stop("OS_INVALID_DESIGN: the competing-risk branch requires at least two declared event types", call. = FALSE)
  if (cr$k > 20L) stop("OS_RESOURCE_LIMIT: at most20 mutually exclusive causes with the inherited5000-subject limit; the all-cause observed-time table must remain bounded. Use a separately validated workflow retaining every cause; no implicit recoding or cause truncation", call. = FALSE)
  interest <- as.integer(a[["event-of-interest"]]); triage <- port$cr_triage(cr, interest)
  if (!identical(as.numeric(d$event), as.numeric(status == interest))) stop("OS_INVALID_DESIGN: binary event column must equal the nominated cause indicator in every aligned subject", call. = FALSE)
  x <- as.numeric(E[a[["km-gene"]], ])
  cut <- if (a$cutoff == "median") stats::median(x) else a$cutpoint
  if (length(cut) != 1L || !is.finite(cut)) stop("OS_INVALID_PARAMETER: finite prespecified cutpoint required", call. = FALSE)
  group <- factor(ifelse(x <= cut, "low", "high"), levels = c("low", "high"))
  if (any(table(group) < 2L) || any(tapply(d$event, group, sum) == 0L)) stop("OS_INVALID_DESIGN: each displayed group needs at least two subjects and a nominated event", call. = FALSE)
  times <- os_srv_numbers(a[["risk-times"]], "CIF/risk times", upper = min(vapply(levels(group), function(g) max(d$time[group == g]), 0)))
  curves <- list(); milestones <- list(); risks <- list(); counts <- list(); checks <- list()
  for (g in levels(group)) {
    keep <- group == g; t <- d$time[keep]; st <- status[keep]
    # Preserve every global state including censoring, even if absent in this group.
    fac <- factor(st, levels = c(0L, cr$codes))
    grid <- sort(unique(c(0, t)))
    current <- port$aalen_johansen(t, fac, grid)
    at <- port$aalen_johansen(t, fac, times)
    for (tab in list(current, at)) {
      if (any(!is.finite(tab$cif)) || any(tab$cif < 0 | tab$cif > 1)) stop("OS_INVALID_RESULT: invalid AJ probability", call. = FALSE)
      sums <- stats::aggregate(cif ~ time, tab, sum)
      if (any(sums$cif > 1 + 1e-12)) stop("OS_INVALID_RESULT: AJ cause probabilities sum above one", call. = FALSE)
    }
    current$group <- g; at$group <- g; curves[[g]] <- current; milestones[[g]] <- at
    risks[[g]] <- data.frame(group = g, time = times, n_risk = vapply(times, function(tt) sum(t >= tt), 0L))
    counts[[g]] <- data.frame(group = g, code = c(0L, cr$codes), n = as.integer(table(factor(st, levels = c(0L, cr$codes)))))
    subcr <- cr; subcr$status_num <- as.integer(st); subcr$status_fac <- fac
    # The forbidden estimator is evaluated only in a clearly labelled diagnostic table.
    diagnostic <- port$km_vs_cif_table(subcr, data.frame(time = t), "time", times)
    diagnostic$group <- g; diagnostic$diagnostic_only <- TRUE; checks[[g]] <- diagnostic
    port$guard_cif_estimator(a[["cif-estimator"]], paste("Event", interest), subcr, data.frame(time = t), "time", interest, tail(times, 1))
  }
  tables <- list(cif_curves = do.call(rbind, curves), cif_timepoints = do.call(rbind, milestones),
    cif_risk = do.call(rbind, risks), cif_group_counts = do.call(rbind, counts),
    cif_forbidden_km_diagnostic = do.call(rbind, checks))
  meta <- list(survival_extension = "competing-risks", dataset_name = a[["dataset-name"]],
    n_biological = nrow(d), n_events = triage$n_event, n_competing = triage$n_compete,
    n_outcomes = triage$n_outcomes, competing_share_of_outcomes_pct = triage$pct_compete,
    source_triage_tier = triage$tier, event_of_interest = interest, event_codes = cr$codes,
    estimator = "Aalen-Johansen", interval = "none", uncertainty_available = FALSE,
    confidence_level_applies_to_cif = FALSE, gray_test = "not_computed", regression_model = "not_fitted",
    km_gene = a[["km-gene"]], cutoff_rule = a$cutoff, cutpoint = cut,
    split = "low <= cutpoint; high > cutpoint", time_unit = a[["time-unit"]], journal = a$journal,
    covariates = "none", interpretation = "Unadjusted descriptive CIF; no causal or adjusted gene association",
    risk_definition = "Original subjects still in the initial state just before t; all causes and censoring remove them after their observed time",
    event_status_mapping = "0=censored; consecutive 1..k mutually exclusive first events; binary event column must match nominated cause",
    legacy_controls_inactive = c("ties", "max-iter", "cox-eps", "ph-transform", "ph-alpha", "adjust", "family-size", "ci-level"),
    full_observed_time_grid = TRUE, no_extrapolated_milestones = TRUE, native_acceptance_pending = TRUE)
  list(tables = tables, object = list(estimator = "Aalen-Johansen", aggregated_curves = tables$cif_curves),
    handoff_type = "development_expression_survival", metadata = meta, upstream = inp$upstream,
    input_files = inp$input_files, ready = TRUE, packages = "survival",
    method = c("P0-13B3 copied Aalen-Johansen product-integral via survival::survfit on explicit multistate status; zero remains the censoring level even with no censored observations.",
      "The source AJ primitive supplies point estimates only. No CIF CI, Gray, Cox, Fine-Gray or adjusted risk is fitted. Existing required legacy model flags are recorded as inactive on this opt-in branch.",
      "Curves include every observed group time; reported milestones are bounded by both groups' observed support. Risk counts use independent subjects, never split rows.",
      "One-minus-KM occurs only in a named forbidden-estimator diagnostic table and never supplies the CIF table or figure. No patient rows are included in the exported CIF aggregate object."))
}
