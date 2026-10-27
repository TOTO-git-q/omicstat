# Independent source port from TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa
# skills/descriptive-distribution/scripts/descdist_core.R; source numerical equivalence awaits native R4.6.1.
# See PORT_ADAPTATIONS.json. Loaded only into an isolated private environment.
# descriptive-distribution 0.2.0 (MedStat module 34, ported from the B2 review). Base-R numerical core.
# One independent person per row; no IO, fitting, row-level export, or eval(spec).

`%||%` <- function(x, y) if (is.null(x)) y else x

dd_fail <- function(code, message) {
  stop(structure(list(message = paste0(code, ": ", message), call = NULL, code = code),
                 class = c("descdist_error", "error", "condition")))
}

dd_names <- function(x, allowed, where) {
  if (!is.list(x) || is.null(names(x)) || anyDuplicated(names(x)) ||
      any(!names(x) %in% allowed))
    dd_fail("OS_GPC_INVALID_SPEC", paste("Unknown/duplicate keys or non-object at", where))
}

dd_string <- function(x, label) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x))
    dd_fail("OS_GPC_INVALID_SPEC", paste(label, "must be a nonempty string"))
  x
}

dd_numeric_vector <- function(x, label, empty = FALSE) {
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  if (!is.numeric(x) || any(!is.finite(x)) || (!empty && !length(x)))
    dd_fail("OS_GPC_INVALID_SPEC", paste(label, "must contain finite numbers"))
  as.numeric(x)
}

dd_integer <- function(x, label, lower, upper) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
      x != floor(x) || x < lower || x > upper)
    dd_fail("OS_GPC_INVALID_SPEC", paste(label, "is outside its integer range"))
  as.integer(x)
}

dd_validate_spec <- function(spec) {
  allowed <- c("spec_version", "analysis", "id", "outcome", "group", "group_levels",
    "reference_group", "strata", "standard_population", "weight", "estimand",
    "quantile_grid", "cdf_grid", "inference", "min_cell_n", "make_figures", "unit")
  dd_names(spec, allowed, "spec")
  if (!identical(spec$spec_version, "descdist.v1"))
    dd_fail("OS_GPC_INVALID_SPEC", "spec_version must be descdist.v1")
  spec$analysis <- dd_string(spec$analysis, "analysis")
  modes <- c("distribution_comparison", "direct_standardization",
             "joint_standardization", "weighted_quantiles")
  if (!spec$analysis %in% modes) dd_fail("OS_GPC_INVALID_SPEC", "Unsupported analysis")
  spec$id <- dd_string(spec$id %||% "row_key", "id")
  spec$outcome <- dd_string(spec$outcome, "outcome")
  spec[["group"]] <- if (is.null(spec[["group"]])) NULL else dd_string(spec[["group"]], "group")
  if (!is.null(spec[["group"]])) {
    levels <- unlist(spec$group_levels, use.names = FALSE)
    if (!is.character(levels) || !length(levels) || anyNA(levels) ||
        any(!nzchar(levels)) || anyDuplicated(levels))
      dd_fail("OS_GPC_INVALID_SPEC", "Explicit unique group_levels are required")
    spec$group_levels <- levels
    if (!is.null(spec$reference_group)) {
      spec$reference_group <- dd_string(spec$reference_group, "reference_group")
      if (!spec$reference_group %in% levels)
        dd_fail("OS_GPC_INVALID_SPEC", "reference_group is not a declared group")
    }
  } else {
    if (!is.null(spec$group_levels) || !is.null(spec$reference_group))
      dd_fail("OS_GPC_INVALID_SPEC", "group_levels/reference_group require group")
    spec$group_levels <- "all"
  }
  if (spec$analysis == "distribution_comparison" &&
      (is.null(spec[["group"]]) || length(spec$group_levels) < 2L || is.null(spec$reference_group)))
    dd_fail("OS_GPC_INVALID_SPEC", "Distribution comparison needs groups and a fixed reference")
  spec$estimand <- dd_string(spec$estimand %||% "mean", "estimand")
  if (!identical(spec$estimand, "mean") && !identical(spec$estimand, "proportion"))
    dd_fail("OS_GPC_INVALID_SPEC", "estimand must be mean or proportion")
  if (spec$estimand == "proportion" && spec$analysis != "direct_standardization")
    dd_fail("OS_GPC_INVALID_SPEC", "Binary proportion is implemented only for direct standardization")
  standard <- spec$analysis %in% c("direct_standardization", "joint_standardization")
  if (standard) {
    spec$strata <- unlist(spec$strata, use.names = FALSE)
    if (!is.character(spec$strata) || !length(spec$strata) || anyNA(spec$strata) ||
        any(!nzchar(spec$strata)) || anyDuplicated(spec$strata) ||
        any(spec$strata %in% c("weight", ".id", ".y", ".w", ".g", ".cell")))
      dd_fail("OS_GPC_INVALID_SPEC", "Unique strata column names are required; weight is reserved")
    if (spec$analysis == "joint_standardization" && length(spec$strata) < 2L)
      dd_fail("OS_GPC_INVALID_SPEC", "joint_standardization needs at least two stratifiers")
    target <- spec$standard_population
    if (!is.list(target) || !length(target))
      dd_fail("OS_GPC_INVALID_SPEC", "A fixed standard_population is required")
    target <- lapply(target, function(row) {
      dd_names(row, c(spec$strata, "weight"), "standard_population row")
      if (!setequal(names(row), c(spec$strata, "weight")))
        dd_fail("OS_GPC_INVALID_SPEC", "Every target row needs all strata and weight")
      for (v in spec$strata) row[[v]] <- dd_string(row[[v]], "target stratum level")
      w <- dd_numeric_vector(row$weight, "target weight")
      if (length(w) != 1L || w < 0) dd_fail("OS_GPC_INVALID_WEIGHTS", "Target weights must be nonnegative")
      row$weight <- w
      as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
    })
    target <- do.call(rbind, target)
    target$.cell <- dd_cell_key(target, spec$strata)
    if (anyDuplicated(target$.cell)) dd_fail("OS_GPC_DUPLICATE_TARGET_CELL", "Target cells must be unique")
    if (!is.finite(sum(target$weight)) || abs(sum(target$weight) - 1) > 1e-10)
      dd_fail("OS_GPC_INVALID_WEIGHTS", "Fixed target weights must sum to one within 1e-10")
    # Correct only floating-point sum roundoff, never renormalize missing support.
    target$weight <- target$weight / sum(target$weight)
    spec$target <- target[target$weight > 0, , drop = FALSE]
    spec$standard_population <- NULL
    if (!nrow(spec$target)) dd_fail("OS_GPC_INVALID_WEIGHTS", "No positive target weight")
  } else if (!is.null(spec$strata) || !is.null(spec$standard_population)) {
    dd_fail("OS_GPC_INVALID_SPEC", "strata/standard_population belong to standardization modes")
  }
  if (spec$analysis == "weighted_quantiles") {
    spec$weight <- dd_string(spec$weight, "weight")
  } else if (!is.null(spec$weight)) {
    dd_fail("OS_GPC_INVALID_SPEC", "Individual weights are accepted only in weighted_quantiles")
  }
  columns <- c(spec$id, spec$outcome, spec[["group"]], spec$strata, spec$weight)
  if (anyDuplicated(columns)) dd_fail("OS_GPC_INVALID_SPEC", "Column roles must be distinct")
  spec$quantile_grid <- dd_numeric_vector(spec$quantile_grid %||% ((1:19) / 20), "quantile_grid")
  if (any(spec$quantile_grid <= 0 | spec$quantile_grid >= 1) ||
      is.unsorted(spec$quantile_grid, strictly = TRUE) || length(spec$quantile_grid) > 101L)
    dd_fail("OS_GPC_INVALID_SPEC", "Quantile grid must be increasing, unique, inside (0,1), at most 101 points")
  if (!is.null(spec$cdf_grid)) {
    spec$cdf_grid <- dd_numeric_vector(spec$cdf_grid, "cdf_grid")
    if (is.unsorted(spec$cdf_grid, strictly = TRUE) || length(spec$cdf_grid) > 101L)
      dd_fail("OS_GPC_INVALID_SPEC", "CDF grid must be fixed, increasing and at most 101 points")
  }
  if (spec$analysis == "weighted_quantiles" && is.null(spec$cdf_grid))
    dd_fail("OS_GPC_INVALID_SPEC", "weighted_quantiles requires a fixed cdf_grid")
  if (!is.null(spec$cdf_grid) && spec$analysis %in% c("direct_standardization", "distribution_comparison"))
    dd_fail("OS_GPC_INVALID_SPEC", "CDF grids belong to joint_standardization or weighted_quantiles")
  spec$min_cell_n <- dd_integer(spec$min_cell_n %||% 10L, "min_cell_n", 10L, 1000000L)
  spec$make_figures <- spec$make_figures %||% TRUE
  if (!is.logical(spec$make_figures) || length(spec$make_figures) != 1L || is.na(spec$make_figures))
    dd_fail("OS_GPC_INVALID_SPEC", "make_figures must be boolean")
  spec$unit <- dd_string(spec$unit %||% "native units", "unit")
  default_method <- if (spec$analysis %in% c("distribution_comparison", "direct_standardization"))
    "iid_stratified_bootstrap" else "none"
  inf <- spec$inference %||% list(method = default_method)
  dd_names(inf, c("method", "replicates", "seed", "confidence_level", "min_success_fraction"), "inference")
  inf$method <- dd_string(inf$method %||% default_method, "inference.method")
  if (!inf$method %in% c("none", "iid_stratified_bootstrap"))
    dd_fail("OS_GPC_INVALID_SPEC", "Unsupported inference method")
  if (spec$analysis == "weighted_quantiles" && inf$method != "none")
    dd_fail("OS_GPC_UNSUPPORTED_INFERENCE", "weighted_quantiles has no design-based or survey CI")
  inf$replicates <- dd_integer(inf$replicates %||% 2000L, "replicates", 200L, 100000L)
  inf$seed <- dd_integer(inf$seed %||% 20261010L, "seed", 0L, .Machine$integer.max)
  inf$confidence_level <- inf$confidence_level %||% 0.95
  if (!is.numeric(inf$confidence_level) || length(inf$confidence_level) != 1L ||
      !is.finite(inf$confidence_level) || inf$confidence_level != 0.95)
    dd_fail("OS_GPC_INVALID_SPEC", "Only prespecified pointwise 95% intervals are supported")
  inf$min_success_fraction <- inf$min_success_fraction %||% 0.95
  if (!is.numeric(inf$min_success_fraction) || length(inf$min_success_fraction) != 1L ||
      !is.finite(inf$min_success_fraction) || inf$min_success_fraction < 0.95 || inf$min_success_fraction > 1)
    dd_fail("OS_GPC_INVALID_SPEC", "min_success_fraction must be in [0.95,1]")
  spec$inference <- inf
  spec
}

dd_cell_key <- function(data, columns) {
  if (!nrow(data)) return(character())
  # Length-prefix encoding prevents separator collisions in categorical labels.
  pieces <- lapply(columns, function(v) {
    x <- as.character(data[[v]])
    paste0(nchar(x, type = "bytes"), ":", x)
  })
  do.call(paste, c(pieces, sep = "|"))
}

dd_num_column <- function(x, label) {
  if (is.factor(x)) x <- as.character(x)
  if (is.logical(x)) dd_fail("OS_GPC_INVALID_COLUMN", paste(label, "must be numeric, not logical"))
  if (is.character(x)) {
    absent <- is.na(x) | trimws(x) == ""
    ans <- suppressWarnings(as.numeric(x))
    if (any(!absent & !is.finite(ans)))
      dd_fail("OS_GPC_INVALID_COLUMN", paste(label, "has unparseable or nonfinite values"))
    ans[absent] <- NA_real_
  } else if (is.numeric(x)) {
    ans <- as.numeric(x)
    if (any(is.nan(ans) | is.infinite(ans)))
      dd_fail("OS_GPC_INVALID_COLUMN", paste(label, "has nonfinite values"))
  } else dd_fail("OS_GPC_INVALID_COLUMN", paste(label, "must be a numeric column"))
  ans
}

dd_prepare <- function(data, spec) {
  cols <- c(spec$id, spec$outcome, spec[["group"]], spec$strata, spec$weight)
  if (!is.data.frame(data) || !nrow(data) || anyDuplicated(names(data)) || any(!cols %in% names(data)))
    dd_fail("OS_GPC_INVALID_DATA", "Nonempty data with unique, required column names is required")
  id <- as.character(data[[spec$id]])
  if (anyNA(id) || any(!nzchar(trimws(id))) || anyDuplicated(id))
    dd_fail("OS_GPC_NON_UNIQUE_PERSON", "IDs must be complete and unique before any exclusions")
  d <- data.frame(.id = id, .y = dd_num_column(data[[spec$outcome]], "outcome"),
                  .g = if (is.null(spec[["group"]])) "all" else as.character(data[[spec[["group"]]]]),
                  stringsAsFactors = FALSE)
  for (v in spec$strata) d[[v]] <- as.character(data[[v]])
  d$.w <- if (is.null(spec$weight)) rep(1, nrow(d)) else dd_num_column(data[[spec$weight]], "weight")
  if (any(d$.w < 0, na.rm = TRUE)) dd_fail("OS_GPC_INVALID_WEIGHTS", "Negative weights are forbidden")
  category_columns <- c(".g", spec$strata)
  for (v in category_columns) d[[v]][!is.na(d[[v]]) & !nzchar(trimws(d[[v]]))] <- NA_character_
  known_group <- !is.na(d$.g)
  if (any(!d$.g[known_group] %in% spec$group_levels))
    dd_fail("OS_GPC_UNDECLARED_GROUP", "Input contains a nonmissing group outside group_levels")
  required <- c(".y", ".g", ".w", spec$strata)
  complete <- stats::complete.cases(d[, required, drop = FALSE])
  flags <- character()
  if (any(!complete)) flags <- c(flags, "OS_GPC_COMPLETE_CASE_EXCLUSIONS")
  d <- d[complete, , drop = FALSE]
  if (any(d$.w == 0)) flags <- c(flags, "OS_GPC_ZERO_WEIGHT_EXCLUSIONS")
  d <- d[d$.w > 0, , drop = FALSE]
  if (!nrow(d)) dd_fail("OS_GPC_NO_ANALYZABLE_ROWS", "No positive-weight complete records")
  if (spec$estimand == "proportion" && any(!d$.y %in% c(0, 1)))
    dd_fail("OS_GPC_INVALID_BINARY_OUTCOME", "Proportion requires literal numeric 0/1 values")
  if (!is.null(spec$target)) {
    d$.cell <- dd_cell_key(d, spec$strata)
    keep <- d$.cell %in% spec$target$.cell
    if (any(!keep)) flags <- c(flags, "OS_GPC_OUTSIDE_FIXED_TARGET_EXCLUSIONS")
    d <- d[keep, , drop = FALSE]
  } else d$.cell <- "all"
  # Stable ordering makes seeded bootstrap independent of input row order.
  d <- d[order(match(d$.g, spec$group_levels), d$.cell, d$.id, method = "radix"), , drop = FALSE]
  rownames(d) <- NULL
  list(data = d, flags = flags)
}

dd_weighted <- function(y, w, probabilities = numeric(), thresholds = numeric()) {
  if (!length(y) || length(y) != length(w) || any(!is.finite(y)) ||
      any(!is.finite(w)) || any(w < 0) || !any(w > 0))
    dd_fail("OS_GPC_INVALID_WEIGHTS", "A nonempty finite outcome and valid positive-sum weights are required")
  keep <- w > 0
  y <- y[keep]; w <- w[keep]
  w <- w / max(w) # Prevent overflow under a harmless global rescaling.
  w <- w / sum(w)
  o <- order(y, method = "radix"); yy <- y[o]; ww <- w[o]
  cumulative <- cumsum(ww); cumulative[length(cumulative)] <- 1
  tolerance <- 8 * .Machine$double.eps
  q <- vapply(probabilities, function(p) yy[which(cumulative + tolerance >= p)[1L]], numeric(1))
  cdf <- vapply(thresholds, function(t) sum(w[y <= t]), numeric(1))
  list(mean = sum(w * y), quantile = q, cdf = cdf, effective_n = 1 / sum(w * w))
}

dd_groups <- function(d, spec) {
  lapply(spec$group_levels, function(g) {
    x <- d[d$.g == g, , drop = FALSE]
    why <- character()
    if (nrow(x) < spec$min_cell_n) why <- c(why, "OS_GPC_GROUP_N_BELOW_MINIMUM")
    if (!is.null(spec$target)) {
      n <- vapply(spec$target$.cell, function(k) sum(x$.cell == k), integer(1))
      if (any(n == 0)) why <- c(why, "OS_GPC_MISSING_POSITIVE_TARGET_CELL")
      if (any(n < spec$min_cell_n)) why <- c(why, "OS_GPC_TARGET_CELL_N_BELOW_MINIMUM")
      if (spec$estimand == "proportion") {
        rare <- vapply(spec$target$.cell, function(k) {
          z <- x$.y[x$.cell == k]
          sum(z == 1) < spec$min_cell_n || sum(z == 0) < spec$min_cell_n
        }, logical(1))
        if (any(rare)) why <- c(why, "OS_GPC_BINARY_COMPONENT_BELOW_MINIMUM")
      }
      if (nrow(x)) {
        j <- match(x$.cell, spec$target$.cell)
        x$.w <- spec$target$weight[j] / n[j]
      }
    }
    missing_target <- "OS_GPC_MISSING_POSITIVE_TARGET_CELL" %in% why
    value <- if (nrow(x) && !missing_target) dd_weighted(x$.y, x$.w, spec$quantile_grid, spec$cdf_grid %||% numeric()) else NULL
    if (!is.null(value) && value$effective_n + 1e-10 < spec$min_cell_n)
      why <- c(why, "OS_GPC_EFFECTIVE_N_BELOW_MINIMUM")
    list(group = g, data = x, value = value, eligible = !length(why), suppression = paste(unique(why), collapse = ";"))
  })
}

dd_empty_metrics <- function() data.frame(
  key = character(), group = character(), reference_group = character(), statistic = character(),
  grid = numeric(), estimate = numeric(), n = numeric(), effective_n = numeric(),
  suppression = character(), stringsAsFactors = FALSE)

dd_metrics <- function(d, spec, disclosure = TRUE) {
  groups <- dd_groups(d, spec)
  rows <- list()
  add <- function(g, ref, statistic, grid, estimate, n, ess, why = "") {
    if (!is.finite(ess)) ess <- 0
    if (disclosure && nzchar(why)) estimate <- NA_real_
    # ESS plus fixed target weights can algebraically reveal a small cell size.
    # Never release that auxiliary diagnostic when its associated estimate is withheld.
    release_ess <- !(disclosure && nzchar(why)) && ess >= spec$min_cell_n
    rows[[length(rows) + 1L]] <<- data.frame(
      key = paste(length(rows) + 1L, statistic, sep = ":"), group = g, reference_group = ref,
      statistic = statistic, grid = grid, estimate = estimate,
      n = if (n >= spec$min_cell_n) n else NA_real_,
      effective_n = if (release_ess) ess else NA_real_,
      suppression = if (disclosure) why else "", stringsAsFactors = FALSE)
  }
  for (g in groups) {
    v <- g$value; n <- nrow(g$data); ess <- if (is.null(v)) 0 else v$effective_n
    add(g$group, "", if (spec$estimand == "proportion") "proportion" else "mean", NA_real_,
        if (is.null(v)) NA_real_ else v$mean, n, ess, g$suppression)
    last_quantile_count <- 0L
    if (spec$analysis != "direct_standardization") for (i in seq_along(spec$quantile_grid)) {
      q <- if (is.null(v)) NA_real_ else v$quantile[i]
      why <- g$suppression
      if (is.finite(q) && (sum(g$data$.y <= q) < spec$min_cell_n || sum(g$data$.y >= q) < spec$min_cell_n))
        why <- paste(c(why[nzchar(why)], "OS_GPC_QUANTILE_TAIL_BELOW_MINIMUM"), collapse = ";")
      if (is.finite(q)) {
        cumulative_count <- sum(g$data$.y <= q)
        if (cumulative_count > last_quantile_count && cumulative_count - last_quantile_count < spec$min_cell_n)
          why <- paste(c(why[nzchar(why)], "OS_GPC_QUANTILE_INCREMENT_BELOW_MINIMUM"), collapse = ";")
        if (!nzchar(why)) last_quantile_count <- cumulative_count
      }
      add(g$group, "", "quantile", spec$quantile_grid[i], q, n, ess, why)
    }
    if (!is.null(spec$cdf_grid)) {
      last_released_count <- 0L
      for (i in seq_along(spec$cdf_grid)) {
        below <- sum(g$data$.y <= spec$cdf_grid[i]); above <- n - below
        why <- g$suppression
        if (min(below, above) < spec$min_cell_n)
          why <- paste(c(why[nzchar(why)], "OS_GPC_CDF_TAIL_BELOW_MINIMUM"), collapse = ";")
        # No two released cumulative cells may isolate a 1..k-1-person increment.
        if (below > last_released_count && below - last_released_count < spec$min_cell_n)
          why <- paste(c(why[nzchar(why)], "OS_GPC_CDF_INCREMENT_BELOW_MINIMUM"), collapse = ";")
        if (!nzchar(why)) last_released_count <- below
        add(g$group, "", "cdf", spec$cdf_grid[i], if (is.null(v)) NA_real_ else v$cdf[i], n, ess, why)
      }
    }
  }
  out <- if (length(rows)) do.call(rbind, rows) else dd_empty_metrics()
  if (!is.null(spec$reference_group)) {
    ref <- groups[[match(spec$reference_group, spec$group_levels)]]
    for (g in groups[spec$group_levels != spec$reference_group]) {
      stats <- if (spec$analysis == "direct_standardization") c(spec$estimand) else c("mean", "quantile")
      for (stat in stats) {
        a <- out[out$group == g$group & out$statistic == stat, , drop = FALSE]
        b <- out[out$group == ref$group & out$statistic == stat, , drop = FALSE]
        for (j in seq_len(nrow(a))) {
          why <- paste(unique(c(a$suppression[j], b$suppression[j])[nzchar(c(a$suppression[j], b$suppression[j]))]), collapse = ";")
          add(g$group, ref$group, paste0(stat, "_difference"), a$grid[j], a$estimate[j] - b$estimate[j],
              min(nrow(g$data), nrow(ref$data)),
              if (all(is.finite(c(a$effective_n[j], b$effective_n[j])))) min(a$effective_n[j], b$effective_n[j]) else 0, why)
        }
      }
      if (spec$analysis == "distribution_comparison") {
        scale <- sqrt((stats::var(x = g$data$.y) + stats::var(x = ref$data$.y)) / 2)
        why <- paste(c(g$suppression, ref$suppression)[nzchar(c(g$suppression, ref$suppression))], collapse = ";")
        if (!is.finite(scale) || scale <= 0) {
          smd <- NA_real_
          why <- paste(c(why[nzchar(why)], "OS_GPC_SMD_ZERO_OR_UNDEFINED_SCALE"), collapse = ";")
        } else smd <- (g$value$mean - ref$value$mean) / scale
        add(g$group, ref$group, "smd", NA_real_, smd, min(nrow(g$data), nrow(ref$data)),
            min(nrow(g$data), nrow(ref$data)), why)
      }
    }
  }
  if (length(rows)) do.call(rbind, rows) else out
}

dd_bootstrap <- function(d, spec, main) {
  B <- spec$inference$replicates
  if (spec$inference$method == "none") return(NULL)
  old_kind <- RNGkind()
  old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_seed_exists) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (old_seed_exists) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(spec$inference$seed)
  strata <- split(seq_len(nrow(d)), paste(match(d$.g, spec$group_levels), d$.cell, sep = ":"))
  draws <- matrix(NA_real_, nrow = B, ncol = nrow(main))
  for (b in seq_len(B)) {
    idx <- unlist(lapply(strata, function(i) i[sample.int(length(i), length(i), replace = TRUE)]), use.names = FALSE)
    result <- dd_metrics(d[idx, , drop = FALSE], spec, disclosure = FALSE)
    if (nrow(result) != nrow(main) || !identical(result$key, main$key))
      dd_fail("OS_GPC_BOOTSTRAP_ALIGNMENT", "Bootstrap metric identity changed")
    draws[b, ] <- result$estimate
  }
  draws
}

# Reader-safe condition text. Messages are fixed strings: no counts, values, paths
# or original condition messages ever enter a finding.
DD_CONDITION_TEXT <- c(
  OS_GPC_GROUP_N_BELOW_MINIMUM = "The group has fewer biological units than the minimum cell size; its estimates are withheld.",
  OS_GPC_MISSING_POSITIVE_TARGET_CELL = "A fixed target cell with positive weight has no biological units in this group; its estimates are withheld.",
  OS_GPC_TARGET_CELL_N_BELOW_MINIMUM = "A fixed target cell has fewer biological units than the minimum cell size in this group; its estimates are withheld.",
  OS_GPC_BINARY_COMPONENT_BELOW_MINIMUM = "A binary outcome component (events or non-events) is below the minimum cell size in a target cell; the estimates are withheld.",
  OS_GPC_EFFECTIVE_N_BELOW_MINIMUM = "The effective sample size under the target weights is below the minimum cell size; the estimates are withheld.",
  OS_GPC_QUANTILE_TAIL_BELOW_MINIMUM = "Fewer biological units than the minimum cell size lie at or beyond this quantile; the estimate is withheld.",
  OS_GPC_QUANTILE_INCREMENT_BELOW_MINIMUM = "Fewer biological units than the minimum cell size separate this quantile from the previous released one; the estimate is withheld.",
  OS_GPC_CDF_TAIL_BELOW_MINIMUM = "Fewer biological units than the minimum cell size lie on one side of this threshold; the CDF value is withheld.",
  OS_GPC_CDF_INCREMENT_BELOW_MINIMUM = "Fewer biological units than the minimum cell size separate this threshold from the previous released one; the CDF value is withheld.",
  OS_GPC_SMD_ZERO_OR_UNDEFINED_SCALE = "The pooled standard deviation is zero or undefined; the standardized mean difference is withheld.",
  OS_GPC_COMPLETE_CASE_EXCLUSIONS = "Records with missing analysis variables were excluded (complete-case analysis); counts are not exported.",
  OS_GPC_ZERO_WEIGHT_EXCLUSIONS = "Records with zero weight were excluded; counts are not exported.",
  OS_GPC_OUTSIDE_FIXED_TARGET_EXCLUSIONS = "Records outside the fixed target strata were excluded; counts are not exported.",
  OS_GPC_BOOTSTRAP_INSUFFICIENT_VALID_REPLICATES = "Too few valid bootstrap replicates; the interval is withheld.",
  OS_GPC_DEGENERATE_BOOTSTRAP = "The bootstrap resamples were constant; no precision claim is made and the interval is withheld.",
  OS_GPC_NO_RELEASABLE_ESTIMATES = "No estimate could be released: every estimate was withheld by disclosure control.")

# One finding per condition code and group, so that any status other than a
# plain "completed" is always explained: code, message, severity, blocking flag
# and the affected group / statistic / grid value(s). Only prespecified labels
# and grid values (already public in the estimates table) are named.
dd_findings <- function(main, flags) {
  out <- list()
  text <- function(code) {
    t <- unname(DD_CONDITION_TEXT[code])
    if (is.na(t)) "A guardrail condition was raised; see the code." else t
  }
  add <- function(code, group = NA_character_, reference_group = NA_character_, statistics = character(),
                  grid = numeric(), blocking = FALSE, severity = "warning") {
    out[[length(out) + 1L]] <<- list(code = code, severity = severity, blocking = blocking, message = text(code),
      group = group, reference_group = reference_group, statistics = as.list(unique(statistics)),
      grid = as.list(unique(grid[is.finite(grid)])))
  }
  for (f in unique(flags)) {
    if (f %in% c("OS_GPC_BOOTSTRAP_INSUFFICIENT_VALID_REPLICATES", "OS_GPC_DEGENERATE_BOOTSTRAP")) next
    add(f)
  }
  if (nrow(main)) {
    flagged <- nzchar(main$suppression) |
      main$ci_status %in% c("insufficient_valid_replicates", "degenerate_resamples_no_precision_claim")
    for (k in which(flagged)) {
      codes <- strsplit(main$suppression[k], ";", fixed = TRUE)[[1L]]
      codes <- codes[nzchar(codes)]
      if (main$ci_status[k] == "insufficient_valid_replicates") codes <- c(codes, "OS_GPC_BOOTSTRAP_INSUFFICIENT_VALID_REPLICATES")
      if (main$ci_status[k] == "degenerate_resamples_no_precision_claim") codes <- c(codes, "OS_GPC_DEGENERATE_BOOTSTRAP")
      ref <- if (nzchar(main$reference_group[k])) main$reference_group[k] else NA_character_
      for (code in codes) {
        slot <- NULL
        for (i in seq_along(out)) {
          o <- out[[i]]
          if (identical(o$code, code) && identical(o$group, main$group[k]) && identical(o$reference_group, ref)) { slot <- i; break }
        }
        stat <- main$statistic[k]; gr <- main$grid[k]
        if (is.null(slot)) add(code, main$group[k], ref, stat, gr)
        else {
          out[[slot]]$statistics <- as.list(unique(c(unlist(out[[slot]]$statistics), stat)))
          out[[slot]]$grid <- as.list(unique(c(unlist(out[[slot]]$grid), gr[is.finite(gr)])))
        }
      }
    }
    if (!any(is.finite(main$estimate)))
      add("OS_GPC_NO_RELEASABLE_ESTIMATES", statistics = unique(main$statistic), blocking = TRUE, severity = "error")
  }
  out
}

dd_analyze <- function(data, spec) {
  spec <- dd_validate_spec(spec)
  prepared <- dd_prepare(data, spec)
  main <- dd_metrics(prepared$data, spec)
  main$ci_lower <- NA_real_
  main$ci_upper <- NA_real_
  main$bootstrap_valid <- NA_integer_
  main$ci_status <- if (spec$inference$method == "none") "not_requested" else "not_estimable"
  draws <- dd_bootstrap(prepared$data, spec, main)
  flags <- prepared$flags
  if (!is.null(draws)) for (j in seq_len(nrow(main))) {
    if (nzchar(main$suppression[j]) || !is.finite(main$estimate[j])) next
    z <- draws[, j]; valid <- is.finite(z)
    main$bootstrap_valid[j] <- sum(valid)
    if (mean(valid) < spec$inference$min_success_fraction) {
      main$ci_status[j] <- "insufficient_valid_replicates"
      flags <- c(flags, "OS_GPC_BOOTSTRAP_INSUFFICIENT_VALID_REPLICATES")
    } else if (length(unique(z[valid])) < 2L) {
      main$ci_status[j] <- "degenerate_resamples_no_precision_claim"
      flags <- c(flags, "OS_GPC_DEGENERATE_BOOTSTRAP")
    } else {
      ci <- as.numeric(stats::quantile(x = z[valid], probs = c(0.025, 0.975), names = FALSE, type = 7))
      main$ci_lower[j] <- ci[1]; main$ci_upper[j] <- ci[2]
      main$ci_status[j] <- "pointwise_percentile_95"
    }
  }
  # No record IDs, row weights, or raw outcomes escape the internal core.
  main$key <- NULL
  main$unit <- ifelse(main$statistic %in% c("cdf", "smd", "proportion", "proportion_difference"),
                      "dimensionless", spec$unit)
  main$grid_unit <- ifelse(grepl("quantile", main$statistic), "probability",
                           ifelse(main$statistic == "cdf", spec$unit, ""))
  findings <- dd_findings(main, flags)
  guard <- list(status = if (any(nzchar(main$suppression))) "completed_with_suppression" else "completed",
    warnings = as.list(unique(c(flags, main$suppression[nzchar(main$suppression)]))),
    findings = findings, blocking = sum(vapply(findings, function(z) isTRUE(z$blocking), logical(1))),
    min_cell_n = spec$min_cell_n,
    rows_exported = FALSE,
    inference = spec$inference,
    inference_scope = if (spec$inference$method == "none") "fixed_record_descriptions_no_sampling_ci" else
      "pointwise_iid_within_fixed_group_by_stratum_bootstrap_conditional_on_fixed_support_and_target_weights",
    no_renormalization_after_missing_target_support = TRUE,
    no_simultaneous_band_or_multiplicity_adjustment = TRUE)
  list(metrics = main, guardrails = guard, spec = spec)
}
