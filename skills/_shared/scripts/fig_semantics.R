# Typed scientific display semantics, additive to figure-spec.v1.
# No model fitting, significance estimation, imputation or independent-unit guessing.
OS_FIG_SEMANTIC_VERSION <- "omicstat.figure-semantics.v1"
.os_sem_error <- function(message) stop(paste0("OS_INVALID_INPUT: figure semantics: ", message), call. = FALSE)
.os_sem_string <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) .os_sem_error(paste(name, "must be one nonempty string; use explicit unknown when unresolved"))
  x
}
.os_sem_ids <- function(ids, what, empty = FALSE) {
  ids <- unlist(ids, use.names = FALSE)
  if (!length(ids) && empty) return(character())
  if(!is.character(ids) || any(!nzchar(trimws(ids)))) .os_sem_error(paste(what,"requires complete string IDs"))
  .os_require_ids(ids, what)
}
.os_sem_scalar <- function(x, name, lower = -Inf, upper = Inf) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < lower || x > upper) .os_sem_error(paste(name, "is not a finite scalar in its declared domain"))
  x
}
.os_sem_rows <- function(d, keys) {
  if (!is.data.frame(d) || !nrow(d) || !length(keys) || !all(keys %in% names(d))) .os_sem_error("source table needs rows and explicit key columns")
  if (anyDuplicated(names(d)) || any(!vapply(d[keys], function(x) is.character(x) || is.factor(x), logical(1)))) .os_sem_error("source keys must be explicit string IDs; numeric labels need an upstream ID conversion")
  if(any(vapply(d[keys],function(x)any(!nzchar(trimws(as.character(x)))),logical(1)))) .os_sem_error("source key components cannot be blank")
  if (anyNA(d[, keys, drop = FALSE]) || anyDuplicated(d[, keys, drop = FALSE])) .os_sem_error("source key must be complete and unique")
  # JSON tuple encoding avoids ambiguous composite-key delimiters.
  ids <- if (length(keys) == 1L) as.character(d[[keys]]) else vapply(seq_len(nrow(d)), function(i)
    jsonlite::toJSON(vapply(keys, function(k) as.character(d[[k]][i]), "", USE.NAMES=FALSE), auto_unbox = FALSE), "")
  .os_sem_ids(ids, "source row IDs")
}

# A typed layer retains its raw table and immutable row IDs. Independent IDs may
# repeat (e.g. repeated visits); row counts never become independent subject n.
os_semantic_layer <- function(id, source, source_key, data_role, quantity, unit,
                              independent_ids = NULL, independent_unit = "unknown",
                              states = NULL, uncertainty = NULL, transform = NULL,
                              provenance = list(), population_id = "unknown", value_columns = NULL) {
  .os_sem_string(id, "layer id"); .os_sem_string(quantity, "layer quantity"); .os_sem_string(unit, "layer unit")
  roles <- c("observed", "aggregate", "model_grid", "prediction", "partial_residual", "simulation_truth", "known_annotation", "fitted_cluster", "draw", "reference", "display_only")
  if (length(data_role) != 1L || !data_role %in% roles) .os_sem_error("unknown layer data_role")
  ids <- .os_sem_rows(source, source_key)
  if(!is.null(value_columns) && !all(.os_sem_ids(value_columns,"value columns") %in% names(source))) .os_sem_error("declared value column missing from source")
  .os_sem_string(independent_unit, "independent unit")
  if (!is.null(independent_ids)) {
    if(!is.character(independent_ids) && !is.factor(independent_ids)) .os_sem_error("independent IDs require explicit string labels")
    independent_ids <- as.character(independent_ids)
    if (length(independent_ids) != length(ids) || anyNA(independent_ids) || any(!nzchar(independent_ids))) .os_sem_error("independent IDs must map explicitly to every source row")
    if (independent_unit %in% c("unknown", "not_applicable")) .os_sem_error("independent IDs need a known independent unit")
  }
  if (is.null(states)) states <- data.frame(source_id = ids, state = if (data_role == "observed") "observed" else "available", reason = "provided", stringsAsFactors = FALSE)
  .os_validate_states(states, ids, source)
  if (!is.null(uncertainty)) .os_validate_uncertainty(uncertainty, ids)
  nonfinite <- list()
  for (column in names(source)) if (is.numeric(source[[column]])) for (i in which(is.infinite(source[[column]])))
    nonfinite[[length(nonfinite)+1L]] <- list(source_id=ids[i], column=column, kind=if(source[[column]][i]>0)"positive_infinity"else"negative_infinity")
  result <- list(id = id, data_role = data_role, quantity = quantity, unit = unit,
       source_key = as.list(source_key), source_ids = as.list(ids), value_columns=if(is.null(value_columns))NULL else as.list(value_columns),
       source_sha256 = os_semantic_table_sha256(source, ids), hash_algorithm = "omicstat.typed-table.sha256.v1", raw_source = source, nonfinite_cells = nonfinite,
       population_id = .os_sem_string(population_id, "population_id"),
       independent_unit = independent_unit,
       independent_ids = if (is.null(independent_ids)) NULL else as.list(stats::setNames(independent_ids, ids)),
       n_rows = nrow(source), n_observations = if (data_role == "observed") nrow(source) else 0L,
       n_independent = if (is.null(independent_ids)) NULL else length(unique(independent_ids)),
       states = states, uncertainty = uncertainty, transform = transform, provenance = provenance)
  os_figure_definition(quantity,"source_row",independent_unit,unit,
       list(status="unknown",rule="layer-only source; population specified by enclosing figure"),
       list(status="unknown",rule="layer-only source; subset specified by enclosing figure"),"unknown",list(result))
  result
}

.os_validate_states <- function(states, ids, raw = NULL) {
  if (!is.data.frame(states) || !all(c("source_id", "state", "reason") %in% names(states))) .os_sem_error("states need source_id, state and reason columns")
  if (!setequal(.os_sem_ids(states$source_id, "state IDs"), ids)) .os_sem_error("state IDs must match every eligible source ID")
  allowed <- c("available", "observed", "true_zero", "missing", "untested", "failed", "unknown", "reference", "nonsignificant", "nonestimable", "unreachable", "undefined_constant", "undefined_single_sample", "undefined_nonfinite_reference", "infinite", "excluded", "display_only", "out_of_domain")
  if (anyNA(states[, c("state", "reason")]) || any(!states$state %in% allowed) || any(!nzchar(states$reason))) .os_sem_error("every state requires a recognized type and explicit reason")
  if ("value" %in% names(states) && any(states$state == "true_zero" & (!is.finite(states$value) | states$value != 0))) .os_sem_error("true_zero state must correspond to actual numeric zero")
  if(any(states$state=="true_zero") && !is.null(raw)) {
    if(!"source_column" %in% names(states)) .os_sem_error("true_zero state must name its actual raw source column")
    for(i in which(states$state=="true_zero")) {
      col<-states$source_column[i]
      if(is.na(col) || !col %in% names(raw)) .os_sem_error("true_zero source column absent")
      value<-raw[[col]][match(states$source_id[i],ids)]
      if(!is.numeric(value) || !is.finite(value) || value!=0) .os_sem_error("true_zero state contradicts raw source value")
    }
  }
  invisible(TRUE)
}

# No interval is manufactured from a plotted line, marginal endpoints or P value.
os_uncertainty <- function(target, kind, method, coverage_scope, resampling_unit,
                           availability, rows = NULL, level = NULL,
                           reason = NULL, joint_source = NULL, inner_draws = NULL,
                           outer_repeats = NULL, conditioned_on = NULL,
                           summary_coverage_required = TRUE, domain = NULL, estimate_column = "estimate") {
  u <- list(target = target, kind = kind, method = method, coverage_scope = coverage_scope,
            resampling_unit = resampling_unit, availability = availability, rows = rows,
            level = level, reason = reason, joint_source = joint_source,
            inner_draws = inner_draws, outer_repeats = outer_repeats,
            conditioned_on = conditioned_on, summary_coverage_required = summary_coverage_required, domain = domain, estimate_column = estimate_column)
  .os_validate_uncertainty(u, if (is.null(rows)) character() else as.character(rows$source_id))
  if (!is.null(rows) && !is.null(domain)) u$out_of_domain_ids <- as.list(rows$source_id[is.finite(rows$lower) & (rows$lower < domain[1] | rows$upper > domain[2])])
  u
}
.os_validate_uncertainty <- function(u, source_ids) {
  for (n in c("target", "kind", "method", "coverage_scope", "resampling_unit", "availability")) .os_sem_string(u[[n]], paste("uncertainty", n))
  kinds <- c("none", "distribution", "observation_quantile", "IQR", "SD", "SE", "CI", "CrI", "PI", "baseline_range", "estimator_mapping")
  if (!u$kind %in% kinds) .os_sem_error("unrecognized uncertainty kind")
  if (!u$availability %in% c("available", "partial", "unavailable", "not_applicable")) .os_sem_error("unknown interval availability")
  if (!u$coverage_scope %in% c("pointwise", "simultaneous_grid", "simultaneous_continuous", "distribution", "not_applicable", "unknown")) .os_sem_error("unknown coverage scope")
  if (u$kind %in% c("CI", "CrI", "PI", "observation_quantile")) .os_sem_scalar(u$level, "interval level", .Machine$double.eps, 1 - .Machine$double.eps)
  else if (!is.null(u$level)) .os_sem_error("a distribution/SD/SE/range/mapping must not silently acquire a confidence level")
  if (startsWith(u$coverage_scope, "simultaneous") && is.null(u$joint_source)) .os_sem_error("simultaneous coverage needs a supplied joint source, not marginal intervals")
  if(!is.null(u$joint_source)) .os_validate_joint_source(u$joint_source)
  if (u$kind == "none" && u$availability %in% c("available", "partial")) .os_sem_error("no uncertainty cannot contain available interval rows")
  if (!is.logical(u$summary_coverage_required) || length(u$summary_coverage_required)!=1L || is.na(u$summary_coverage_required)) .os_sem_error("summary coverage policy must be explicit boolean")
  if (u$kind == "estimator_mapping" && (!is.null(u$rows) || u$coverage_scope != "not_applicable")) .os_sem_error("estimator mapping connectors are not uncertainty intervals")
  for (n in c("inner_draws", "outer_repeats")) if (!is.null(u[[n]])) {
    .os_sem_scalar(u[[n]], n, 1); if (u[[n]] != as.integer(u[[n]])) .os_sem_error("draw/repeat counts must be integers")
  }
  if (u$availability %in% c("unavailable", "not_applicable")) {
    .os_sem_string(u$reason, "unavailable interval reason")
    if (!is.null(u$rows) && nrow(u$rows)) .os_sem_error("unavailable uncertainty cannot contain interval rows")
    return(invisible(TRUE))
  }
  d <- u$rows
  if (!is.data.frame(d) || !all(c("source_id", "lower", "estimate", "upper") %in% names(d))) .os_sem_error("interval rows need source_id, lower, estimate and upper")
  ids <- .os_sem_ids(d$source_id, "interval IDs")
  if (!all(ids %in% source_ids)) .os_sem_error("intervals cannot attach to another source/grid")
  if (u$availability == "available" && !setequal(ids, source_ids)) .os_sem_error("available interval rows must cover the same source rows")
  if (u$availability == "partial") .os_sem_string(u$reason, "partial interval reason")
  if (any(!vapply(d[c("lower", "estimate", "upper")], is.numeric, logical(1))) || any(!is.finite(as.matrix(d[c("lower", "estimate", "upper")])))) .os_sem_error("unavailable/nonestimable intervals must be explicit states, never NA/zero-width intervals")
  if (any(d$lower > d$upper)) .os_sem_error("interval endpoints are reversed; source conflict must be resolved upstream")
  if (isTRUE(u$summary_coverage_required) && any(d$estimate < d$lower | d$estimate > d$upper)) .os_sem_error("source_conflict: estimate lies outside its declared enclosing interval")
  if (!is.null(u$domain) && (length(u$domain) != 2L || any(!is.finite(u$domain)) || u$domain[1] >= u$domain[2])) .os_sem_error("interval domain must have two increasing finite bounds")
  invisible(TRUE)
}

# A ratio has a named universe and independently addressable numerator and
# denominator IDs. Rate numerators can be events rather than people.
os_semantic_ratio <- function(quantity, numerator_ids, denominator_ids,
                              numerator_unit, denominator_unit, estimate,
                              kind = c("fraction", "rate"), tolerance = 1e-10) {
  kind <- match.arg(kind); .os_sem_string(quantity, "ratio quantity")
  ni <- .os_sem_ids(numerator_ids, "numerator IDs", empty = TRUE)
  di <- .os_sem_ids(denominator_ids, "denominator IDs", empty = TRUE)
  .os_sem_string(numerator_unit, "numerator unit"); .os_sem_string(denominator_unit, "denominator unit")
  .os_sem_scalar(tolerance, "ratio tolerance", 0)
  if (kind == "fraction" && (!all(ni %in% di) || numerator_unit != denominator_unit)) .os_sem_error("fraction numerator must be a subset of its denominator in the same units")
  if (!length(di)) {
    if (length(estimate) != 1L || !is.na(estimate)) .os_sem_error("zero denominator is undefined, not numeric zero")
    state <- "undefined_zero_denominator"; reconstructed <- NA_real_
  } else {
    .os_sem_scalar(estimate, "ratio estimate")
    reconstructed <- length(ni) / length(di)
    if (abs(estimate - reconstructed) > tolerance) .os_sem_error("ratio does not reconstruct from its exported ID sets")
    state <- "observed"
  }
  list(quantity = quantity, kind = kind, numerator = list(ids = as.list(ni), unit = numerator_unit, n = length(ni)),
       denominator = list(ids = as.list(di), unit = denominator_unit, n = length(di)),
       estimate = estimate, reconstructed = reconstructed, tolerance = tolerance, state = state)
}

os_statistic_contract <- function(id, values, source_ids, statistic_kind,
                                  method = "unknown", adjustment = "unknown",
                                  family_id = "unknown", family_size = NULL,
                                  null = "unknown", alternative = "unknown",
                                  threshold = NULL, zero_policy = "reported_zero_precision_unknown") {
  .os_sem_string(id, "statistic id"); ids <- .os_sem_ids(source_ids, "statistic source IDs")
  kinds <- c("raw_p", "adjusted_p", "qvalue", "local_fdr", "posterior_probability", "posterior_inclusion_probability")
  if (length(statistic_kind) != 1L || !statistic_kind %in% kinds) .os_sem_error("unrecognized statistic kind")
  if (!is.numeric(values) || length(values) != length(ids) || any(is.infinite(values)) || any(values < 0 | values > 1, na.rm = TRUE)) .os_sem_error("P/probability values must be in [0,1] or explicitly missing")
  for (v in list(method = method, adjustment = adjustment, family_id = family_id, null = null, alternative = alternative, zero_policy = zero_policy)) .os_sem_string(v, "statistic provenance")
  # Source rows may include prefiltered/missing results outside the actual test family.
  # Only finite reported statistics must fit; complete membership is supplied by adapters.
  if (!is.null(family_size)) { .os_sem_scalar(family_size, "family size", sum(is.finite(values))); if (family_size != as.integer(family_size)) .os_sem_error("family size must be an integer") }
  if (statistic_kind == "raw_p" && !adjustment %in% c("none", "unknown")) .os_sem_error("raw P cannot be labelled as adjusted")
  if (!is.null(threshold)) .os_sem_scalar(threshold, "decision threshold", 0, 1)
  list(id = id, statistic_kind = statistic_kind, values = as.list(stats::setNames(values, ids)),
       source_ids = as.list(ids), method = method, adjustment = adjustment, family_id = family_id,
       family_size = family_size, null = null, alternative = alternative, threshold = threshold,
       n_reported = length(values), n_finite = sum(is.finite(values)), n_missing = sum(is.na(values)),
       n_zero = sum(values == 0, na.rm = TRUE), zero_policy = zero_policy,
       decision = if (is.null(threshold)) NULL else as.list(stats::setNames(ifelse(is.na(values), "unknown", ifelse(values < threshold, "below_threshold", "not_below_threshold")), ids)))
}

# A display transform returns both copies; callers cannot mistake its sentinel
# or offset values for analysis inputs. Ticks and reference lines use this same map.
os_display_transform <- function(values, kind = c("identity", "log", "log2", "log10", "log1p", "sqrt", "exp", "inverse_logit", "folded_ratio"),
                                 source_scale = "raw", unit = "unknown", pseudocount = 0,
                                 invalid = c("error", "missing"), offset = 0,
                                 ticks = NULL, reference = NULL) {
  kind <- match.arg(kind); invalid <- match.arg(invalid)
  .os_sem_string(source_scale, "source scale"); .os_sem_string(unit, "source unit")
  .os_sem_scalar(pseudocount, "pseudocount", 0); .os_sem_scalar(offset, "display offset")
  if (!is.numeric(values)) .os_sem_error("display values must be numeric")
  if (pseudocount != 0 && !kind %in% c("log", "log2", "log10", "log1p")) .os_sem_error("this transformation does not apply a pseudocount")
  if (kind != "identity" && startsWith(source_scale, "display:")) .os_sem_error("a display transform cannot be applied twice")
  if (kind %in% c("log", "log2", "log10", "log1p", "folded_ratio") && grepl("log", source_scale, fixed = TRUE)) .os_sem_error("log input must not be logged again")
  if (kind == "inverse_logit" && source_scale != "logit") .os_sem_error("inverse logit requires explicit logit source; latent score is not sufficient")
  if (kind == "exp" && source_scale != "log_link") .os_sem_error("exp response conversion requires explicit log-link source")
  map <- function(x) switch(kind, identity=x, log=log(x+pseudocount), log2=log2(x+pseudocount), log10=log10(x+pseudocount), log1p=log1p(x+pseudocount), sqrt=sqrt(x), exp=exp(x), inverse_logit=stats::plogis(x), folded_ratio=exp(abs(log(x))))
  display <- suppressWarnings(map(values)); bad <- is.finite(values) & !is.finite(display)
  if (any(bad) && invalid == "error") .os_sem_error("display transform has nonfinite domain results; declare and account for missing display values")
  states <- ifelse(is.na(values), "missing", ifelse(is.infinite(values), "infinite", ifelse(bad, "out_of_domain", ifelse(values == 0, "true_zero", "observed"))))
  display[!is.finite(display)] <- NA_real_; display <- display + offset
  map_axis <- function(x) { if (is.null(x)) return(NULL); y <- suppressWarnings(map(x)); if (any(!is.finite(y))) .os_sem_error("tick/reference is outside the declared transform domain"); y+offset }
  list(raw = values, display = display, state = states,
       definition = list(source_scale = source_scale, display_scale = paste0("display:",kind), unit = unit,
                         transform = kind, base = switch(kind, log=exp(1),log2=2,log10=10,log1p=exp(1),folded_ratio=exp(1),NULL), direction_preserved=kind!="folded_ratio", pseudocount=pseudocount,
                         offset=offset, operation_order=as.list(c("source", "pseudocount_when_declared", "transform", "display_offset")),
                         invalid_policy=invalid, n_display_excluded=sum(!is.finite(display)), statistics_use="raw"),
       ticks_raw=ticks,ticks_display=map_axis(ticks),reference_raw=reference,reference_display=map_axis(reference),display_only=TRUE)
}
os_analysis_values <- function(x) {
  if (is.list(x) && isTRUE(x$display_only)) .os_sem_error("display-only values cannot enter an analysis; use the explicitly retained raw source")
  x
}

# Cross-language hash encoding: sorted UTF-8 column names and source row IDs;
# length-prefixed typed cells, canonical 17-significant-digit numeric strings.
# Integers and equal doubles share a numeric representation; NA is not numeric0.
os_semantic_table_sha256 <- function(d, ids) {
  if (!is.data.frame(d) || anyDuplicated(names(d)) || any(!nzchar(names(d)))) .os_sem_error("hash input requires a data frame with unique column names")
  ids <- .os_sem_ids(ids, "hash source IDs")
  if (nrow(d) != length(ids)) .os_sem_error("source IDs and table rows differ")
  columns <- sort(names(d), method = "radix"); order_rows <- order(ids, method = "radix")
  encode <- function(x) {
    if (is.factor(x)) x <- as.character(x)
    if (length(x) != 1L) .os_sem_error("nested source cells are not supported")
    if (is.na(x)) return("null")
    if (is.logical(x)) return(if (x) "b:1" else "b:0")
    if (is.numeric(x)) return(paste0("n:", if (is.infinite(x)) as.character(x) else if (x == 0) "0" else sprintf("%.17g", x)))
    paste0("s:", enc2utf8(as.character(x)))
  }
  token <- function(x) paste0(nchar(enc2utf8(x), type = "bytes"), ":", enc2utf8(x))
  # Preallocation preserves the v1 byte encoding without quadratic copying for
  # matrix source tables with many cells.
  contents <- character(1L + length(columns) + length(ids) * (length(columns) + 1L))
  contents[seq_len(1L + length(columns))] <- c("omicstat.typed-table.sha256.v1\n", vapply(columns, function(x) token(paste0("s:",x)), ""))
  at <- 2L + length(columns)
  for (i in order_rows) {
    contents[at:(at + length(columns))] <- c(token(paste0("s:",ids[i])), vapply(columns, function(n) token(encode(d[[n]][i])), ""))
    at <- at + length(columns) + 1L
  }
  digest::digest(charToRaw(paste0(contents, collapse = "")), algo = "sha256", serialize = FALSE)
}
.os_sem_frame <- function(x) {
  if (is.data.frame(x)) return(x)
  if (!is.list(x) || is.null(names(x))) .os_sem_error("source/state tables must be column-oriented objects")
  lens <- vapply(x, length, integer(1)); if (length(unique(lens)) > 1L) .os_sem_error("table columns have unequal lengths")
  as.data.frame(lapply(x, function(v) {
    if (!is.list(v)) return(v)
    if (!length(v)) return(character())
    unlist(lapply(v, function(y) if (is.null(y)) NA else y), use.names = FALSE)
  }), check.names = FALSE, stringsAsFactors = FALSE)
}

os_figure_definition <- function(quantity, observation_unit, independent_unit,
                                 unit, eligible_set, subset, aggregation,
                                 layers, numerator = NULL, denominator = NULL,
                                 ratios = list(), statistics = list(), comparisons = list(),
                                 source_conflicts = list(), notes = list()) {
  d <- list(semantic_version = OS_FIG_SEMANTIC_VERSION, quantity = quantity,
            observation_unit = observation_unit, independent_unit = independent_unit, unit = unit,
            numerator = numerator, denominator = denominator, eligible_set = eligible_set,
            subset = subset, aggregation = aggregation, layers = layers,
            ratios = ratios, statistics = statistics, comparisons = comparisons,
            source_conflicts = source_conflicts, notes = notes)
  os_validate_figure_definition(d)
  d
}

os_validate_figure_definition <- function(d) {
  if(!is.list(d)) .os_sem_error("definition must be an object")
  if (!identical(d$semantic_version, OS_FIG_SEMANTIC_VERSION)) .os_sem_error("unknown semantic schema version")
  for (n in c("quantity", "observation_unit", "independent_unit", "unit", "aggregation")) .os_sem_string(d[[n]], n)
  for (n in c("eligible_set", "subset")) {
    value <- d[[n]]
    if (!is.list(value) || is.null(value$status) || !value$status %in% c("known", "unknown", "not_applicable")) .os_sem_error(paste(n, "must declare known/unknown/not_applicable status"))
    .os_sem_string(value$rule, paste(n,"rule"))
    if (value$status == "known") .os_sem_ids(value$ids, paste(n,"IDs"), empty = TRUE)
    else if (length(value$ids)) .os_sem_error("unknown population cannot contain invented IDs")
  }
  if (d$eligible_set$status == "known" && d$subset$status == "known" &&
      !all(unlist(d$subset$ids) %in% unlist(d$eligible_set$ids))) .os_sem_error("display subset is not part of its declared eligible set")
  if (!is.list(d$layers) || !length(d$layers)) .os_sem_error("typed definition requires at least one explicit source layer")
  layer_ids <- vapply(d$layers, function(l) .os_sem_string(l$id, "layer id"), "")
  if (anyDuplicated(layer_ids)) .os_sem_error("layer IDs are duplicated")
  for (layer in d$layers) {
    raw <- .os_sem_frame(layer$raw_source); keys <- unlist(layer$source_key, use.names = FALSE)
    ids <- .os_sem_rows(raw, keys)
    raw <- .os_restore_nonfinite(raw,ids,layer$nonfinite_cells)
    if (!identical(ids, .os_sem_ids(layer$source_ids, "layer source IDs"))) .os_sem_error("source table and layer ID order differ")
    if (!identical(os_semantic_table_sha256(raw, ids), layer$source_sha256)) .os_sem_error("layer source hash differs from its raw table")
    if (!identical(layer$hash_algorithm, "omicstat.typed-table.sha256.v1")) .os_sem_error("unknown source hash algorithm")
    for (n in c("quantity", "unit", "data_role", "independent_unit", "population_id")) .os_sem_string(layer[[n]], paste("layer",n))
    if (!layer$data_role %in% c("observed", "aggregate", "model_grid", "prediction", "partial_residual", "simulation_truth", "known_annotation", "fitted_cluster", "draw", "reference", "display_only")) .os_sem_error("unknown layer role")
    if (layer$n_rows != nrow(raw) || layer$n_observations != if (layer$data_role == "observed") nrow(raw) else 0L) .os_sem_error("grid/aggregate/repeat count cannot be labelled observed sample n")
    if (is.null(layer$independent_ids)) {
      if (!is.null(layer$n_independent)) .os_sem_error("independent n cannot be inferred without explicit unit IDs")
    } else {
      ii <- unlist(layer$independent_ids)
      if (layer$independent_unit %in% c("unknown","not_applicable") || any(!nzchar(ii))) .os_sem_error("independent IDs require a known unit and nonblank values")
      if (length(ii) != length(ids) || !setequal(names(ii), ids) || anyNA(ii) || layer$n_independent != length(unique(ii))) .os_sem_error("independent-unit mapping/count is inconsistent")
    }
    if(!is.null(layer$value_columns)) {
      columns<-.os_sem_ids(layer$value_columns,"value columns")
      if(!all(columns %in% names(raw))) .os_sem_error("declared value column absent")
      if(layer$quantity %in% c("probability","posterior_probability","posterior_inclusion_probability"))
        for(col in columns) if(!is.numeric(raw[[col]]) || any(is.infinite(raw[[col]])) || any(raw[[col]]<0 | raw[[col]]>1,na.rm=TRUE)) .os_sem_error("explicit probability value column outside [0,1]")
    }
    .os_validate_states(.os_sem_frame(layer$states), ids, raw)
    .os_validate_layer_transform(layer$transform,raw)
    if (!is.null(layer$uncertainty)) {
      u <- layer$uncertainty
      if (!is.null(u$rows)) u$rows <- .os_sem_frame(u$rows)
      .os_validate_uncertainty(u, ids)
      if (u$target != layer$quantity) .os_sem_error("interval target is not the same layer estimand")
      if (!is.null(u$rows)) {
        .os_sem_string(u$estimate_column, "interval estimate_column")
        if (!u$estimate_column %in% names(raw)) .os_sem_error("interval estimate column is absent from its layer")
        expected <- raw[[u$estimate_column]][match(u$rows$source_id, ids)]
        if (!isTRUE(all.equal(as.numeric(u$rows$estimate),as.numeric(expected),tolerance=1e-12))) .os_sem_error("interval summaries do not match source row estimates")
      }
    }
  }
  observed<-Filter(function(l)l$data_role=="observed" && l$population_id!="unknown",d$layers)
  for(pop in unique(vapply(observed,`[[`,"","population_id"))) {
    ll<-Filter(function(l)l$population_id==pop,observed)
    if(length(unique(vapply(ll,`[[`,"","independent_unit")))>1L) .os_sem_error("one population has conflicting independent units")
    known<-Filter(function(l)!is.null(l$independent_ids),ll)
    mapping<-unlist(unname(lapply(known,`[[`,"independent_ids")),use.names=TRUE)
    if(length(mapping)) for(id in unique(names(mapping)))
      if(length(unique(mapping[names(mapping)==id]))>1L) .os_sem_error("one observation ID maps to conflicting independent IDs across layers")
  }
  for(n in c("numerator","denominator")) .os_validate_named_set(d[[n]],n)
  if (length(d$statistics)) {
    sids <- vapply(d$statistics, function(s) .os_sem_string(s$id,"statistic id"), "")
    if (anyDuplicated(sids)) .os_sem_error("statistic IDs are duplicated")
    for (s in d$statistics) {
      if(!all(unlist(s$source_ids,use.names=FALSE) %in% unlist(lapply(d$layers,`[[`,"source_ids"),use.names=FALSE))) .os_sem_error("statistic rows do not resolve to retained source layers")
      values <- unlist(lapply(s$values[unlist(s$source_ids,use.names=FALSE)], function(v) if (is.null(v)) NA_real_ else v))
      checked <- os_statistic_contract(s$id, values, unlist(s$source_ids), s$statistic_kind,
                 s$method,s$adjustment,s$family_id,s$family_size,s$null,s$alternative,s$threshold,s$zero_policy)
      if (!setequal(names(s$values),unlist(s$source_ids,use.names=FALSE))) .os_sem_error("statistic values must be keyed in source ID order")
      for (n in c("n_reported","n_finite","n_missing","n_zero")) if (s[[n]] != checked[[n]]) .os_sem_error("statistic state counts do not reconcile")
      if (!identical(s$decision[names(checked$decision)],checked$decision)) .os_sem_error("statistic decisions differ from supplied values and threshold")
    }
  }
  for (ratio in d$ratios) {
    checked <- os_semantic_ratio(ratio$quantity, ratio$numerator$ids, ratio$denominator$ids,
                      ratio$numerator$unit, ratio$denominator$unit,
                      ratio$estimate %||% NA_real_, ratio$kind, ratio$tolerance)
    if (ratio$numerator$n != checked$numerator$n || ratio$denominator$n != checked$denominator$n || ratio$state != checked$state || !isTRUE(all.equal(ratio$reconstructed %||% NA_real_,checked$reconstructed))) .os_sem_error("ratio counts/state/reconstruction do not reconcile")
  }
  if (length(d$comparisons)) {
    cids <- vapply(d$comparisons, function(x) .os_sem_string(x$id,"comparison id"), "")
    if (anyDuplicated(cids)) .os_sem_error("comparison IDs are duplicated")
    for (comparison in d$comparisons) {
      for (n in c("model_id","test_id","endpoint","source_result_id","statistic_id","family_id","paired_unit")) .os_sem_string(comparison[[n]],paste("comparison",n))
      if (!comparison$statistic_id %in% vapply(d$statistics, `[[`, "", "id")) .os_sem_error("comparison does not resolve to a declared statistic")
      st <- d$statistics[[match(comparison$statistic_id,vapply(d$statistics, `[[`, "", "id"))]]
      if (!comparison$source_result_id %in% unlist(st$source_ids) || comparison$family_id != st$family_id) .os_sem_error("comparison source result/family differs")
      endpoints <- .os_sem_ids(comparison$endpoint_ids, "comparison endpoint IDs")
      if (length(endpoints) < 2L) .os_sem_error("comparison requires at least two explicit endpoint IDs")
    }
  }
  invisible(TRUE)
}

os_semantic_counts <- function(d) {
  os_validate_figure_definition(d)
  layers <- lapply(d$layers,function(l) {
    raw<-.os_restore_nonfinite(.os_sem_frame(l$raw_source),unlist(l$source_ids),l$nonfinite_cells)
    list(layer_id=l$id,data_role=l$data_role,n_rows=l$n_rows,
      n_observations=l$n_observations,n_independent=l$n_independent,independent_unit=l$independent_unit,
      state_counts=as.list(table(.os_sem_frame(l$states)$state)),
      source_column_counts=lapply(raw,function(x) list(n_rows=length(x),n_missing=sum(is.na(x)),
          n_finite=if(is.numeric(x))sum(is.finite(x))else NULL,n_zero=if(is.numeric(x))sum(x==0,na.rm=TRUE)else NULL,
          n_infinite=if(is.numeric(x))sum(is.infinite(x))else NULL)))
  })
  observed <- Filter(function(l) l$data_role == "observed" && l$population_id != "unknown",d$layers)
  populations <- sort(unique(vapply(observed,`[[`,"","population_id")),method="radix")
  unique_counts <- lapply(populations,function(p) {
    ll <- Filter(function(l) l$population_id==p,observed)
    units <- unique(vapply(ll,`[[`,"","independent_unit"))
    if(length(units)>1L) .os_sem_error("one population has conflicting independent-unit definitions")
    have_ids <- all(vapply(ll,function(l)!is.null(l$independent_ids),logical(1)))
    list(population_id=p,n_observations=length(unique(unlist(lapply(ll,`[[`,"source_ids")))),
         n_independent=if(have_ids)length(unique(unlist(lapply(ll,`[[`,"independent_ids"),use.names=FALSE)))else NULL,
         independent_unit=units)
  })
  list(layers=layers,observed_populations=unique_counts)
}
os_semantic_caption <- function(d) {
  counts <- os_semantic_counts(d)
  n <- vapply(counts$observed_populations,function(p)paste0(p$n_observations," observations; ",
      if(is.null(p$n_independent))"independent n unknown"else paste(p$n_independent,p$independent_unit)," (",p$population_id,")"),"")
  interval <- unlist(lapply(d$layers,function(l){u<-l$uncertainty;if(is.null(u))return(paste0(l$id,": uncertainty not supplied"));
      paste0(l$id,": ",u$kind,if(!is.null(u$level))paste0(" level ",100*u$level,"%")else"",", ",u$coverage_scope,", ",u$method,
             "; ",u$availability,if(!is.null(u$reason))paste0(" (",u$reason,")")else"")}),use.names=FALSE)
  ratio_text<-vapply(d$ratios,function(r)paste0(r$quantity,": ",r$numerator$n," ",r$numerator$unit," / ",r$denominator$n," ",r$denominator$unit,"; ",r$state),"")
  stat_text<-vapply(d$statistics,function(s)paste0(s$id,": ",os_statistic_axis_label(s$statistic_kind),"; method=",s$method,"; adjustment=",s$adjustment,"; family=",s$family_id,"; family size=",s$family_size %||% "unknown","; missing=",s$n_missing),"")
  paste(paste0("Quantity: ",d$quantity,"; unit: ",d$unit,"; observation unit: ",d$observation_unit,
               "; independent unit: ",d$independent_unit,"; aggregation: ",d$aggregation,"."),
        paste(n,collapse="; "),paste(interval,collapse="; "),
        paste0("Eligible set: ",d$eligible_set$status," (",d$eligible_set$rule,"); subset: ",d$subset$status," (",d$subset$rule,")."),
        if(is.null(d$denominator))"Denominator not supplied; no ratio inferred."else paste0("Denominator: ",d$denominator$status,"; unit=",d$denominator$unit,"; ",d$denominator$rule,"."),
        paste(ratio_text,collapse="; "),paste(stat_text,collapse="; "),
        if(length(d$source_conflicts))"Unresolved source conflicts retained; no automatic conversion or correction."else"")
}

os_semantic_metadata <- function(meta) {
  d <- meta$definition
  if (is.null(d$semantic_version)) return(meta)
  d <- os_normalize_figure_definition(d)
  os_validate_figure_definition(d)
  meta$definition <- d
  generated <- os_semantic_caption(d)
  old <- meta$notes$semantic_caption
  caption <- meta$caption %||% ""
  if (!is.null(old) && !identical(old, generated)) caption <- trimws(gsub(old,"",caption,fixed=TRUE))
  if (!grepl(generated,caption,fixed=TRUE)) caption <- trimws(paste(caption,generated))
  meta$caption <- caption
  meta$counts$semantic <- os_semantic_counts(d)
  meta$notes$semantic_caption <- generated
  meta$notes$semantic_contract <- list(version=OS_FIG_SEMANTIC_VERSION,
      source_hash_algorithm="omicstat.typed-table.sha256.v1",independent_counts_guessed=FALSE,
      estimators_fitted_in_renderer=FALSE)
  meta
}

os_statistic_axis_label <- function(kind) {
  labels <- c(raw_p="P value",adjusted_p="Adjusted P value",qvalue="q value",local_fdr="Local false discovery rate",
              posterior_probability="Posterior probability",posterior_inclusion_probability="Posterior inclusion probability")
  if(length(kind)!=1L || !kind %in% names(labels)) .os_sem_error("unknown statistic axis kind")
  unname(labels[kind])
}

# Raw-P FDR display boundary is derived from the complete supplied family and
# already-computed adjusted values. It never refits or relabels a statistic.
os_raw_p_decision_boundary <- function(raw_p, adjusted_p, source_ids, family_size, alpha) {
  ids <- .os_sem_ids(source_ids,"full test-family IDs")
  os_statistic_contract("raw",raw_p,ids,"raw_p",adjustment="none",family_size=family_size)
  os_statistic_contract("adjusted",adjusted_p,ids,"adjusted_p",family_size=family_size)
  if(family_size!=length(ids)) .os_sem_error("raw-P FDR boundary requires the complete test family, including missing states")
  .os_sem_scalar(alpha,"FDR decision cutoff",0,1)
  rejected <- !is.na(adjusted_p) & adjusted_p < alpha
  if(any(rejected & is.na(raw_p))) .os_sem_error("rejected test lacks its raw P value")
  if(!any(rejected)) return(list(cutoff=NULL,rejected_ids=list(),alpha=alpha,family_size=family_size,rule="adjusted_p < alpha",boundary_available=FALSE))
  cutoff <- max(raw_p[rejected]);classified <- !is.na(raw_p) & raw_p<=cutoff
  if(!identical(classified,rejected)) .os_sem_error("one raw-P line cannot reproduce the supplied adjusted decisions (ties/nonmonotone adjustment); use explicit decision glyphs")
  list(cutoff=cutoff,rejected_ids=as.list(ids[rejected]),alpha=alpha,family_size=family_size,
       rule="adjusted_p < alpha; raw boundary includes tied raw P only when decisions agree",boundary_available=TRUE)
}

# Namespaces distinguish run-local cluster numbers from globally shared classes.
# Colour, shape and line mappings persist together when a registry is reused.
os_category_encodings <- function(values, namespace, role, registry=NULL, run_id=NULL,
                                  legend_ids=NULL, label_ids=NULL) {
  .os_sem_string(namespace,"category namespace")
  if(!role %in% c("biological_class","condition","run_cluster","model","role","unknown")) .os_sem_error("unknown category role")
  if(role=="run_cluster") .os_sem_string(run_id,"run-local cluster run_id")
  ids <- sort(unique(as.character(values)),method="radix")
  if(anyNA(ids) || any(!nzchar(ids))) .os_sem_error("missing categories need an explicit named state before encoding")
  key <- as.character(jsonlite::toJSON(list(namespace,role,if(role=="run_cluster")run_id else "shared"),auto_unbox=TRUE))
  for(other in list(legend_ids,label_ids)) if(!is.null(other) && !setequal(.os_sem_ids(other,"legend/label IDs"),ids)) .os_sem_error("legend/label and category ID sets disagree")
  colours <- os_colours_for(ids,family=key,registry=registry)
  registry <- colours$registry; mapping <- registry$styles[[key]] %||% list(shape=list(),linetype=list())
  have <- names(mapping$shape);new <- sort(setdiff(ids,have),method="radix")
  shapes <- c(16L,17L,15L,18L,3L,8L);lines<-c("solid","dashed","dotted","dotdash","longdash","twodash")
  for(id in new) {
    k<-length(mapping$shape)
    if(k>=length(shapes)*length(lines)) .os_sem_error("category shape/line capacity exceeded; facet or use an explicit ID-labelled table")
    mapping$shape[[id]]<-shapes[(k%%length(shapes))+1L]
    mapping$linetype[[id]]<-lines[(k%/%length(shapes))+1L]
  }
  registry$styles[[key]]<-mapping
  list(namespace=namespace,role=role,run_id=run_id,registry_key=key,ids=as.list(ids),
       colour=as.list(colours$colours[ids]),shape=mapping$shape[ids],linetype=mapping$linetype[ids],registry=registry,
       equivalence_claim=if(role=="run_cluster")"within_declared_run_only"else"within_declared_namespace")
}

os_text_contrast_ratio <- function(foreground, background) {
  if(length(foreground)!=length(background)) .os_sem_error("text/background colours must be paired")
  luminance<-function(col) {
    rgb<-grDevices::col2rgb(col)/255
    linear<-ifelse(rgb<=0.04045,rgb/12.92,((rgb+0.055)/1.055)^2.4)
    as.numeric(c(.2126,.7152,.0722)%*%linear)
  }
  f<-luminance(foreground);b<-luminance(background)
  (pmax(f,b)+.05)/(pmin(f,b)+.05)
}
os_figure_glyph_audit <- function(text, family=os_font_family()) {
  chars<-unique(unlist(strsplit(enc2utf8(paste(text,collapse="")),"",fixed=TRUE)))
  chars<-chars[!chars %in% c(" ","\n","\t","\r")]
  if(!length(chars))return(data.frame(glyph=character(),index=integer(),available=logical()))
  info<-systemfonts::glyph_info(chars,family=family)
  data.frame(glyph=chars,index=info$index,available=info$index!=0L,stringsAsFactors=FALSE)
}

.os_restore_nonfinite <- function(raw, ids, mask) {
  touched <- character()
  for (entry in mask %||% list()) {
    if (!entry$source_id %in% ids || !entry$column %in% names(raw) || !entry$kind %in% c("positive_infinity","negative_infinity")) .os_sem_error("invalid nonfinite source mask")
    key <- paste(entry$source_id,entry$column,sep="\r")
    if(key %in% touched) .os_sem_error("duplicate nonfinite source mask key")
    touched <- c(touched,key);i<-match(entry$source_id,ids);value<-raw[[entry$column]][i]
    if(!is.na(value) && !is.infinite(value)) .os_sem_error("nonfinite mask contradicts a finite source value")
    expected<-if(entry$kind=="positive_infinity")Inf else -Inf
    if(is.infinite(value) && value!=expected) .os_sem_error("nonfinite source sign changed")
    raw[[entry$column]][i]<-expected
  }
  for(column in names(raw)) if(is.numeric(raw[[column]])) for(i in which(is.infinite(raw[[column]])))
    if(!paste(ids[i],column,sep="\r") %in% touched) .os_sem_error("nonfinite raw values require a lossless serialization mask")
  raw
}

# Normalize only declared typed fields. Arrays stay arrays in saved native and
# Python-replayed specs; numeric Inf survives JSON's null via an explicit mask.
os_normalize_figure_definition <- function(d) {
  for(n in c("eligible_set","subset")) if(!is.null(d[[n]]$ids))d[[n]]$ids<-as.list(unlist(d[[n]]$ids,use.names=FALSE))
  d$layers<-lapply(d$layers,function(l) {
    l$source_key<-as.list(unlist(l$source_key,use.names=FALSE));l$source_ids<-as.list(unlist(l$source_ids,use.names=FALSE))
    if(!is.null(l$value_columns))l$value_columns<-as.list(unlist(l$value_columns,use.names=FALSE))
    l$raw_source<-.os_sem_frame(l$raw_source)
    l$raw_source<-.os_restore_nonfinite(l$raw_source,unlist(l$source_ids),l$nonfinite_cells)
    l$raw_source<-lapply(l$raw_source,as.list)
    l$states<-lapply(.os_sem_frame(l$states),as.list)
    if(!is.null(l$transform)) for(n in c("raw","display","state","ticks_raw","ticks_display","reference_raw","reference_display"))
      if(!is.null(l$transform$operation[[n]])) l$transform$operation[[n]]<-as.list(unlist(lapply(l$transform$operation[[n]],function(v)if(is.null(v))NA else v),use.names=FALSE))
    if(!is.null(l$uncertainty$rows))l$uncertainty$rows<-lapply(.os_sem_frame(l$uncertainty$rows),as.list)
    l
  })
  d$statistics<-lapply(d$statistics,function(s){s$source_ids<-as.list(unlist(s$source_ids,use.names=FALSE));s})
  d$ratios<-lapply(d$ratios,function(r){r$numerator$ids<-as.list(unlist(r$numerator$ids,use.names=FALSE));r$denominator$ids<-as.list(unlist(r$denominator$ids,use.names=FALSE));r})
  d$comparisons<-lapply(d$comparisons,function(c){c$endpoint_ids<-as.list(unlist(c$endpoint_ids,use.names=FALSE));c})
  for(n in c("layers","statistics","ratios","comparisons","source_conflicts"))d[[n]]<-unname(d[[n]])
  d
}

# Explicit contrasts must retain a joint source. Marginal CI endpoints are not
# joint uncertainty, even when their point estimates can be subtracted.
os_contrast_joint_source <- function(kind, parameter_ids, weights, source_sha256,
                                      covariance = NULL, paired_draws = NULL,
                                      draw_ids = NULL) {
  ids <- .os_sem_ids(parameter_ids,"contrast parameter IDs")
  if(!kind %in% c("covariance","paired_draws")) .os_sem_error("contrast uncertainty requires covariance or paired draws, not marginal intervals")
  if(!is.numeric(weights) || !setequal(names(weights),ids) || any(!is.finite(weights))) .os_sem_error("contrast weights must be finite and keyed to parameters")
  if(!is.character(source_sha256) || length(source_sha256)!=1L || !grepl("^[0-9a-f]{64}$",source_sha256)) .os_sem_error("joint source requires a pinned SHA256")
  variance<-NULL
  if(kind=="covariance") {
    if(!is.matrix(covariance) || !is.numeric(covariance) || !setequal(rownames(covariance),ids) || !setequal(colnames(covariance),ids) || any(!is.finite(covariance))) .os_sem_error("covariance must cover exactly the parameter IDs")
    cv<-covariance[ids,ids,drop=FALSE]
    if(!isTRUE(all.equal(cv,t(cv),tolerance=1e-12)) || min(eigen(cv,symmetric=TRUE,only.values=TRUE)$values)< -1e-10) .os_sem_error("supplied covariance is not symmetric positive semidefinite")
    variance<-as.numeric(t(weights[ids]) %*% cv %*% weights[ids])
  } else {
    di<-.os_sem_ids(draw_ids,"paired draw IDs")
    if(!is.matrix(paired_draws) || !is.numeric(paired_draws) || nrow(paired_draws)!=length(di) || !identical(rownames(paired_draws),di) || !setequal(colnames(paired_draws),ids) || any(!is.finite(paired_draws))) .os_sem_error("paired draw matrix must have complete unique draw and parameter IDs")
  }
  list(kind=kind,parameter_ids=as.list(ids),weights=as.list(weights[ids]),source_sha256=source_sha256,
       supplied_covariance=covariance,paired_draws=paired_draws,draw_ids=if(is.null(draw_ids))NULL else as.list(draw_ids),
       contrast_variance=variance,interval_computed=FALSE,method="supplied_joint_source_linear_contrast")
}

# The full table stays intact. A view budget is a reporting policy, never a
# statistical filter; it records every source ID outside the chosen viewport.
os_figure_view <- function(source_ids, values, limits) {
  ids<-.os_sem_ids(source_ids,"view source IDs")
  if(!is.numeric(values) || length(values)!=length(ids) || length(limits)!=2L || any(!is.finite(limits)) || limits[1]>=limits[2]) .os_sem_error("view needs aligned values and increasing finite bounds")
  missing<-!is.finite(values);inside<-!missing & values>=limits[1] & values<=limits[2]
  list(limits=limits,source_ids=as.list(ids),visible_ids=as.list(ids[inside]),excluded_view_ids=as.list(ids[!missing & !inside]),
       unavailable_ids=as.list(ids[missing]),n_total=length(ids),n_visible=sum(inside),n_excluded_view=sum(!missing & !inside),n_unavailable=sum(missing),
       full_values=values,display_only=TRUE)
}
os_figure_pages <- function(ids, height_mm, row_height_mm, header_mm, footer_mm=0) {
  ids<-.os_sem_ids(ids,"pagination IDs");for(n in c("height_mm","row_height_mm","header_mm","footer_mm")) .os_sem_scalar(get(n),n,0)
  if(row_height_mm<=0 || height_mm<=header_mm+footer_mm) .os_sem_error("physical row/header budget leaves no readable rows")
  n<-floor((height_mm-header_mm-footer_mm)/row_height_mm)
  if(n<1L).os_sem_error("physical page cannot hold one readable row")
  pages<-split(ids,ceiling(seq_along(ids)/n))
  list(pages=lapply(pages,as.list),capacity=n,row_height_mm=row_height_mm,header_mm=header_mm,footer_mm=footer_mm,
       repeated_headers=TRUE,source_ids=as.list(ids),n_rows=length(ids),n_pages=length(pages),clipped_rows=0L)
}

# A verified record is design evidence only. 0242 is a retained companion and
# never increases the independent target; repeated figure keys count once.
os_validate_evidence_refs <- function(refs, record_root=NULL) {
  for(entry in refs) {
    .os_sem_string(entry$family,"evidence family")
    if(!entry$status %in% c("pending","sufficient_design_evidence")) .os_sem_error("evidence status cannot imply numerical acceptance")
    records<-entry$records %||% list();keys<-character();verified<-!is.null(record_root)
    for(r in records) {
      for(n in c("record_id","path","independent_figure_key","sha256","source_ref","support")) .os_sem_string(r[[n]],paste("evidence",n))
      if(!grepl("^[0-9a-f]{64}$",r$sha256) || grepl("(^/|(^|/)\\.\\.(/|$))",r$path)) .os_sem_error("evidence needs a safe path and SHA256")
      if(!is.null(record_root)) {
        path<-file.path(record_root,r$path)
        if(file.exists(path) && !startsWith(normalizePath(path,mustWork=TRUE),paste0(normalizePath(record_root,mustWork=TRUE),"/"))) .os_sem_error("evidence symlink escapes its record root")
        if(!file.exists(path) || digest::digest(file=path,algo="sha256")!=r$sha256) .os_sem_error("evidence record missing or hash changed")
        source<-jsonlite::fromJSON(path,simplifyVector=FALSE)
        if(!identical(source$record_id %||% source$id,r$record_id) || !identical(source$independent_figure_key,r$independent_figure_key)) .os_sem_error("evidence ID/key does not resolve")
      }
      if(r$record_id!="0242" && isTRUE(r$eligible_for_family)) keys<-c(keys,r$independent_figure_key)
    }
    n<-length(unique(keys))
    if(!is.null(entry$independent_records) && entry$independent_records!=n) .os_sem_error("evidence count includes duplicates/companions/ineligible records")
    if(entry$status=="sufficient_design_evidence" && (!verified || n<20L)) .os_sem_error("family evidence remains pending below20 verified independent eligible records")
  }
  invisible(TRUE)
}

# One result ID is the source of each annotation, independent of bracket x order.
# Legacy global metadata is materialized per row, with unknown provenance stated.
os_comparison_labels <- function(comparisons, group_ids, test=NULL, adjustment=NULL,
                                 family_size=NULL, adjusted=FALSE) {
  if(!is.data.frame(comparisons) || !nrow(comparisons) || !all(c("group1","group2","p","y") %in% names(comparisons))) .os_sem_error("comparison rows need group1/group2/p/y")
  d<-comparisons; n<-nrow(d)
  groups<-.os_sem_ids(as.character(group_ids),"comparison group IDs")
  if(anyNA(d[c("group1","group2")]) || any(!as.character(d$group1) %in% groups) || any(!as.character(d$group2) %in% groups) || any(d$group1==d$group2)) .os_sem_error("bracket endpoints must resolve to two distinct actual group IDs")
  if(!is.numeric(d$p) || any(is.infinite(d$p)) || any(d$p<0 | d$p>1,na.rm=TRUE)) .os_sem_error("comparison P values must remain unrounded probabilities or missing")
  legacy<-!"comparison_id" %in% names(d)
  if(legacy) d$comparison_id<-vapply(seq_len(n),function(i)jsonlite::toJSON(c(as.character(d$group1[i]),as.character(d$group2[i]),i),auto_unbox=FALSE),"")
  .os_sem_ids(d$comparison_id,"comparison IDs")
  defaults<-list(test=test,adjustment=adjustment %||% if(adjusted)"unknown"else"none",family_size=family_size %||% NA_real_,
      statistic_kind=if(adjusted)"adjusted_p"else"raw_p",model_id="unknown",endpoint="unknown",family_id="unknown",paired_unit="unknown",
      source_result_id=if(legacy)d$comparison_id else NULL,comparison_type="pairwise")
  if(!legacy) {
    required<-c("test","adjustment","family_size","statistic_kind","model_id","endpoint","family_id","paired_unit","source_result_id","comparison_type")
    if(!all(required %in% names(d))) .os_sem_error("typed comparison rows require test/model/endpoint/family/paired-unit/result provenance")
  }
  for(name in names(defaults)) if(!name %in% names(d)) {
    if(is.null(defaults[[name]])) .os_sem_error(paste("comparison is missing",name))
    d[[name]]<-rep(defaults[[name]],length.out=n)
  }
  for(name in c("test","adjustment","statistic_kind","model_id","endpoint","family_id","paired_unit","source_result_id","comparison_type"))
    if(anyNA(d[[name]]) || any(!nzchar(as.character(d[[name]])))) .os_sem_error(paste("comparison provenance missing",name))
  if(any(d$comparison_type!="pairwise")) .os_sem_error("omnibus, interaction, trend and model-fit tests cannot be drawn on pairwise group brackets")
  if(any(!d$statistic_kind %in% c("raw_p","adjusted_p","qvalue"))) .os_sem_error("posterior/local FDR values are not frequentist comparison P labels")
  if(!is.numeric(d$family_size) || any(!is.na(d$family_size) & (!is.finite(d$family_size) | d$family_size<1 | d$family_size!=floor(d$family_size)))) .os_sem_error("comparison family_size must be positive integer or explicitly unknown")
  if(any(d$statistic_kind!="raw_p" & (is.na(d$family_size) | d$adjustment %in% c("none","unknown")))) .os_sem_error("adjusted P/q comparisons require actual adjustment method and full family size")
  if(any(d$statistic_kind=="raw_p" & !d$adjustment %in% c("none","unknown"))) .os_sem_error("raw comparison P cannot be labelled adjusted")
  for(kind in c("raw_p","adjusted_p")) if(kind %in% names(d)) {
    vv<-d[[kind]]; select<-d$statistic_kind==kind
    if(!is.numeric(vv) || any(is.infinite(vv)) || any(vv<0 | vv>1,na.rm=TRUE)) .os_sem_error("raw/adjusted comparison fields must be probabilities")
    if(any(select & xor(is.na(vv),is.na(d$p))) || any(select & abs(vv-d$p)>1e-15,na.rm=TRUE)) .os_sem_error("annotation differs from its unrounded source statistic")
  }
  for(family in setdiff(unique(d$family_id),"unknown")) {
    ii<-which(d$family_id==family);sizes<-unique(d$family_size[ii]);sizes<-sizes[!is.na(sizes)]
    if(length(sizes)>1L || (length(sizes)==1L && sizes<length(unique(d$source_result_id[ii])))) .os_sem_error("comparison family size is inconsistent or smaller than its supplied unique results")
  }
  d$state<-ifelse(is.na(d$p),"unavailable","tested")
  d$short_label<-vapply(seq_len(n),function(i) {
    kind<-d$statistic_kind[i]
    if(kind=="qvalue") paste0("q value ",.os_p_value_text(d$p[i]))
    else os_p_label(d$p[i],d$test[i],d$adjustment[i],if(is.na(d$family_size[i]))NULL else d$family_size[i],kind=="adjusted_p","short",kind)
  },"")
  d$caption<-vapply(seq_len(n),function(i)paste0(d$comparison_id[i],": ",d$group1[i]," versus ",d$group2[i],"; ",d$short_label[i],
      "; test=",d$test[i],"; model=",d$model_id[i],"; endpoint=",d$endpoint[i],"; adjustment=",d$adjustment[i],
      "; family=",d$family_id[i]," (",if(is.na(d$family_size[i]))"size unknown"else paste(d$family_size[i],"comparisons"),
      "); paired/cluster unit=",d$paired_unit[i],"; result=",d$source_result_id[i]),"")
  d$provenance_status<-if(legacy)"legacy_global_metadata_materialized_unknowns_retained"else"explicit_per_comparison"
  d
}

# Multiple supplied interval masses must be nested for the same source keys.
# This checks source intervals only; it never estimates or widens an interval.
os_validate_nested_uncertainty <- function(intervals) {
  if(length(intervals)<2L) .os_sem_error("nested uncertainty requires at least two interval layers")
  ref<-intervals[[1]];ids<-.os_sem_ids(.os_sem_frame(ref$rows)$source_id,"nested interval IDs")
  levels<-vapply(intervals,function(u){.os_validate_uncertainty(u,ids);.os_sem_scalar(u$level,"nested interval level",0,1)},numeric(1))
  if(anyDuplicated(levels)) .os_sem_error("nested interval levels must be distinct")
  intervals<-intervals[order(levels)]
  for(i in seq_along(intervals)) {
    u<-intervals[[i]]
    if(u$target!=ref$target || u$kind!=ref$kind || u$method!=ref$method || u$coverage_scope!=ref$coverage_scope || !setequal(.os_sem_frame(u$rows)$source_id,ids)) .os_sem_error("nested intervals require identical estimand/method/type/scope/source IDs")
    if(i>1L) {
      inner<-.os_sem_frame(intervals[[i-1L]]$rows);outer<-.os_sem_frame(u$rows);outer<-outer[match(inner$source_id,outer$source_id),]
      if(any(outer$lower>inner$lower | outer$upper<inner$upper) || !isTRUE(all.equal(outer$estimate,inner$estimate))) .os_sem_error("larger interval mass does not enclose the smaller supplied interval")
    }
  }
  invisible(TRUE)
}

# Compare partitions only on explicit common entity IDs, retaining every split
# and merge. Labels are run-local; no automatic one-to-one equivalence is claimed.
os_category_overlap <- function(reference, candidate, id_col, reference_col, candidate_col,
                                reference_run, candidate_run) {
  .os_sem_string(reference_run,"reference run");.os_sem_string(candidate_run,"candidate run")
  a<-.os_sem_rows(reference,id_col);b<-.os_sem_rows(candidate,id_col)
  if(!reference_col %in% names(reference) || !candidate_col %in% names(candidate)) .os_sem_error("partition columns missing")
  common<-sort(intersect(a,b),method="radix")
  if(!length(common)) .os_sem_error("partition comparison has no common IDs")
  aa<-as.character(reference[[reference_col]][match(common,a)]);bb<-as.character(candidate[[candidate_col]][match(common,b)])
  # An explicit NA label is reserved and cannot collide with a supplied category.
  missing_label<-"[missing partition]"
  if(missing_label %in% c(aa,bb)) .os_sem_error("reserved missing partition label collides")
  aa[is.na(aa)|!nzchar(aa)]<-missing_label;bb[is.na(bb)|!nzchar(bb)]<-missing_label
  tab<-as.data.frame(table(reference=factor(aa,levels=sort(unique(aa),method="radix")),candidate=factor(bb,levels=sort(unique(bb),method="radix"))),stringsAsFactors=FALSE)
  names(tab)[3]<-"n_intersection"
  ar<-table(aa);br<-table(bb)
  tab$n_reference<-as.integer(ar[as.character(tab$reference)]);tab$n_candidate<-as.integer(br[as.character(tab$candidate)])
  tab$row_fraction<-tab$n_intersection/tab$n_reference;tab$column_fraction<-tab$n_intersection/tab$n_candidate
  tab$jaccard<-tab$n_intersection/(tab$n_reference+tab$n_candidate-tab$n_intersection)
  list(reference_run=reference_run,candidate_run=candidate_run,mapping_rule="all_intersections_no_equivalence_inferred",table=tab,
       common_ids=as.list(common),removed_ids=as.list(sort(setdiff(a,b),method="radix")),new_ids=as.list(sort(setdiff(b,a),method="radix")),
       n_common=length(common),n_removed=length(setdiff(a,b)),n_new=length(setdiff(b,a)),
       source=list(reference_sha256=os_semantic_table_sha256(reference,a),candidate_sha256=os_semantic_table_sha256(candidate,b)),
       interpretation="Partition concordance, not ground-truth accuracy; row/column fractions and Jaccard are distinct.")
}

os_layout_budget <- function(panel_ids, width_mm, height_mm, ncol, min_panel_width_mm=35,
                             min_panel_height_mm=30, label_ids=NULL, shown_label_ids=NULL) {
  ids<-.os_sem_ids(panel_ids,"panel IDs")
  for(n in c("width_mm","height_mm","ncol","min_panel_width_mm","min_panel_height_mm")) .os_sem_scalar(get(n),n,.Machine$double.eps)
  if(ncol!=floor(ncol)) .os_sem_error("layout column count must be integral")
  rows<-ceiling(length(ids)/ncol)
  if(!is.null(label_ids)) {
    label_ids<-.os_sem_ids(label_ids,"full label IDs");shown_label_ids<-.os_sem_ids(shown_label_ids,"shown label IDs",TRUE)
    if(!all(shown_label_ids %in% label_ids)) .os_sem_error("shown labels are not in the full source ID set")
  }
  list(panel_ids=as.list(ids),n_panels=length(ids),ncol=ncol,nrow=rows,width_mm=width_mm,height_mm=height_mm,
       panel_width_mm=width_mm/ncol,panel_height_mm=height_mm/rows,min_panel_width_mm=min_panel_width_mm,min_panel_height_mm=min_panel_height_mm,
       crowded=width_mm/ncol<min_panel_width_mm || height_mm/rows<min_panel_height_mm,
       full_label_ids=as.list(label_ids),shown_label_ids=as.list(shown_label_ids),suppressed_label_ids=as.list(setdiff(label_ids,shown_label_ids)),
       suppressed_observations=0L,policy="Label budget changes labels only, never the source observations; crowded output requires splitting or an ID table.")
}

# Bind declarative source layers to the actual tables passed to a renderer.
# Full source key sets must match; extra renderer columns are allowed, but no
# source value or row can be invented by attaching an unrelated definition.
os_validate_render_sources <- function(definition, tables) {
  os_validate_figure_definition(definition)
  matches<-list()
  for(l in definition$layers) {
    columns<-names(.os_sem_frame(l$raw_source));keys<-unlist(l$source_key,use.names=FALSE)
    hits<-names(tables)[vapply(tables,function(tab) {
      if(!is.data.frame(tab) || !all(columns %in% names(tab)))return(FALSE)
      tryCatch(identical(os_semantic_table_sha256(tab[,columns,drop=FALSE],.os_sem_rows(tab,keys)),l$source_sha256),error=function(e)FALSE)
    },logical(1))]
    if(!length(hits)) .os_sem_error(paste("typed source layer does not bind to an actual renderer table:",l$id))
    matches[[l$id]]<-as.list(hits)
  }
  list(status="exact_source_hash_and_keys",layers=matches,selection_inferred=FALSE)
}

# A transform attached to a source layer must name its raw column and preserve
# the complete input vector. The renderer only validates/replays display math.
os_layer_transform <- function(source, column, ...) {
  .os_sem_string(column,"transform source column")
  if(!is.data.frame(source) || !column %in% names(source)) .os_sem_error("transform source column absent")
  list(source_column=column,operation=os_display_transform(source[[column]],...))
}
.os_validate_layer_transform <- function(transform, raw) {
  if(is.null(transform))return(invisible(TRUE))
  .os_sem_string(transform$source_column,"transform source column")
  if(!transform$source_column %in% names(raw)) .os_sem_error("transform column absent from source")
  op<-transform$operation;d<-op$definition
  restore_numeric<-function(x) if(is.null(x))NULL else as.numeric(unlist(lapply(x,function(v)if(is.null(v))NA_real_ else v),use.names=FALSE))
  if(any(is.infinite(raw[[transform$source_column]]))) .os_sem_error("attached display transforms require finite or missing raw values; infinite source remains explicit and untransformed")
  raw_values<-restore_numeric(op$raw)
  if(!isTRUE(all.equal(raw_values,as.numeric(raw[[transform$source_column]]),tolerance=0))) .os_sem_error("display transform raw values differ from source")
  checked<-os_display_transform(raw_values,d$transform,d$source_scale,d$unit,d$pseudocount,d$invalid_policy,d$offset,
                                restore_numeric(op$ticks_raw),restore_numeric(op$reference_raw))
  for(n in c("display","ticks_display","reference_display")) if(!isTRUE(all.equal(restore_numeric(op[[n]]),checked[[n]],tolerance=1e-12))) .os_sem_error(paste("display transform",n,"does not replay"))
  if(!identical(unlist(op$state,use.names=FALSE),checked$state) || !isTRUE(op$display_only) || d$statistics_use!="raw" || d$n_display_excluded!=checked$definition$n_display_excluded) .os_sem_error("display-only transform state/firewall changed")
  invisible(TRUE)
}

.os_validate_named_set <- function(x,name) {
  if(is.null(x))return(invisible(TRUE))
  if(!is.list(x) || !x$status %in% c("known","unknown","not_applicable")) .os_sem_error(paste(name,"requires explicit known/unknown/not_applicable status"))
  .os_sem_string(x$unit,paste(name,"unit"));.os_sem_string(x$rule,paste(name,"rule"))
  if(x$status=="known") {
    ids<-.os_sem_ids(x$ids,paste(name,"IDs"),TRUE)
    if(!is.null(x$n) && x$n!=length(ids)) .os_sem_error(paste(name,"count differs from IDs"))
  } else if(length(x$ids) || !is.null(x$n)) .os_sem_error(paste(name,"unknown/not applicable cannot invent IDs or counts"))
  invisible(TRUE)
}

# Upstream reference parameters are supplied, never estimated from a selected
# visit/display subset. A fixed reference makes the conversion reversible.
os_fixed_standardization <- function(values, center, scale, reference_ids, reference_sha256,
                                     source_unit, direction=c("higher_is_more","lower_is_more","unknown")) {
  direction<-match.arg(direction);.os_sem_scalar(center,"fixed reference center");.os_sem_scalar(scale,"fixed reference scale",.Machine$double.eps)
  ids<-.os_sem_ids(reference_ids,"standardization reference IDs");.os_sem_string(source_unit,"standardization source unit")
  if(!is.numeric(values) || any(is.infinite(values))) .os_sem_error("standardization needs numeric finite/missing raw values")
  if(!is.character(reference_sha256) || length(reference_sha256)!=1L || !grepl("^[a-f0-9]{64}$",reference_sha256)) .os_sem_error("fixed standardization needs pinned reference SHA256")
  list(raw=values,display=(values-center)/scale,display_only=TRUE,definition=list(transform="fixed_reference_standardization",center=center,scale=scale,
       reference_ids=as.list(ids),reference_sha256=reference_sha256,source_unit=source_unit,unit="fixed reference SD units",direction=direction,
       operation_order=as.list(c("supplied_fixed_reference","subtract_center","divide_scale")),reestimated_by_visit=FALSE),
       inverse_check=((values-center)/scale)*scale+center)
}

os_quantity_ratio <- function(numerator, denominator, source_ids, numerator_unit, denominator_unit,
                              quantity, denominator_zero_tolerance=0) {
  ids<-.os_sem_ids(source_ids,"quantity ratio source IDs")
  if(!is.numeric(numerator) || !is.numeric(denominator) || length(numerator)!=length(ids) || length(denominator)!=length(ids)) .os_sem_error("quantity ratio raw arrays must align with source IDs")
  .os_sem_string(numerator_unit,"numerator unit");.os_sem_string(denominator_unit,"denominator unit");.os_sem_string(quantity,"ratio quantity")
  .os_sem_scalar(denominator_zero_tolerance,"zero denominator tolerance",0)
  finite<-is.finite(numerator)&is.finite(denominator);zero<-finite&abs(denominator)<=denominator_zero_tolerance
  estimate<-rep(NA_real_,length(ids));estimate[finite&!zero]<-numerator[finite&!zero]/denominator[finite&!zero]
  state<-ifelse(!finite,"unavailable",ifelse(zero,"undefined_zero_denominator","available"))
  quad<-ifelse(!finite|zero,"undefined",paste0(ifelse(numerator<0,"negative","nonnegative"),"_numerator__",ifelse(denominator<0,"negative","positive"),"_denominator"))
  list(quantity=quantity,source_ids=as.list(ids),numerator=numerator,denominator=denominator,numerator_unit=numerator_unit,denominator_unit=denominator_unit,
       unit=paste(numerator_unit,"per",denominator_unit),estimate=estimate,state=state,quadrant=quad,quadrant_counts=as.list(table(quad)),
       denominator_crosses_zero=any(denominator[finite]<0)&&any(denominator[finite]>0),summary_ratio_inferred=FALSE,
       interpretation="Raw increment ratios only; no favorable/unfavorable or causal decision is inferred.")
}

.os_sem_matrix <- function(x,rows,columns) {
  if(is.matrix(x))return(x)
  if(!is.list(x) || length(x)!=length(rows) || any(vapply(x,length,integer(1))!=length(columns))) .os_sem_error("joint matrix dimensions do not match its IDs")
  m<-matrix(as.numeric(unlist(x,use.names=FALSE)),nrow=length(rows),byrow=TRUE,dimnames=list(rows,columns))
  m
}
.os_validate_joint_source <- function(joint) {
  if(!is.list(joint) || !joint$kind %in% c("covariance","paired_draws")) .os_sem_error("joint source requires actual supplied covariance or paired draws with identities")
  ids<-.os_sem_ids(joint$parameter_ids,"joint parameter IDs")
  covariance<-if(joint$kind=="covariance") .os_sem_matrix(joint$supplied_covariance,ids,ids) else NULL
  draws<-if(joint$kind=="paired_draws") .os_sem_matrix(joint$paired_draws,unlist(joint$draw_ids),ids) else NULL
  checked<-os_contrast_joint_source(joint$kind,ids,unlist(joint$weights),joint$source_sha256,covariance,draws,unlist(joint$draw_ids))
  if(!isTRUE(all.equal(joint$contrast_variance,checked$contrast_variance,tolerance=1e-12)) || !identical(joint$interval_computed,FALSE)) .os_sem_error("joint-source variance/interval claim changed")
  invisible(TRUE)
}
