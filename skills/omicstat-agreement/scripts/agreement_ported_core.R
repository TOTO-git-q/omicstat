# Copied and explicitly adapted from TOTO-git-q/medstat
# @12292d020ef4a8575a3a1db880b81786ee3547fa:skills/agreement/scripts/agreement_core.R.
# This independent OmicStat source has no MedStat runtime imports or paths.
# See PORT_SOURCE.json and PORT_ADAPTATIONS.json; native equivalence is unverified.
`%||%` <- function(a,b) if(is.null(a)||length(a)==0||(length(a)==1&&is.na(a))) b else a
AG_DEFAULTS <- list(paradox_agreement=.80, paradox_kappa=.60,
  paradox_prevalence_index=.50, paradox_bias_index=.20, marginal_tv_distance=.20,
  ba_spearman_rho=.40, ba_studentized=3)
AG_INTERPRETATION_CAVEAT <- paste("Interpretation bands are conventions, not universal acceptability thresholds;",
 "judge them against measurement purpose, category prevalence, disagreement consequences and the confidence interval.")
AG_YAML_BOOL_TOKENS <- c("y","Y","yes","Yes","YES","n","N","no","No","NO",
 "true","True","TRUE","false","False","FALSE","on","On","ON","off","Off","OFF")

ag_stop <- function(code, fmt, ...) {
  stop(sprintf(paste0(code, ": ", fmt), ...), call. = FALSE)
}

ag_is_blank <- function(x) is.null(x) || length(x) == 0 || all(is.na(x)) || all(!nzchar(trimws(as.character(x))))

ag_split_csv <- function(v, numeric = FALSE) {
  if (ag_is_blank(v)) return(NULL)
  p <- trimws(strsplit(as.character(v), ",", fixed = TRUE)[[1]])
  p <- p[nzchar(p)]
  if (!length(p)) return(NULL)
  if (numeric) {
    num <- suppressWarnings(as.numeric(p))
    if (any(is.na(num))) ag_stop("OS_INVALID_PARAMETER", "expected a comma-separated list of numbers, got '%s'.", v)
    return(num)
  }
  p
}

ag_as_bool <- function(v, key) {
  if (is.null(v)) return(NULL)
  s <- tolower(trimws(as.character(v)))
  if (identical(s, "true")) return(TRUE)
  if (identical(s, "false")) return(FALSE)
  ag_stop("OS_INVALID_PARAMETER", "--%s accepts only 'true' or 'false', got '%s'.", key, v)
}

ag_as_num <- function(v, key) {
  if (is.null(v)) return(NULL)
  x <- suppressWarnings(as.numeric(v))
  if (length(x) != 1 || is.na(x) || !is.finite(x)) {
    ag_stop("OS_INVALID_PARAMETER", "--%s must be a single finite number, got '%s'.", key, as.character(v))
  }
  x
}

ag_as_int <- function(v, key) {
  x <- ag_as_num(v, key)
  if (is.null(x)) return(NULL)
  if (abs(x - round(x)) > 1e-9) ag_stop("OS_INVALID_PARAMETER", "--%s must be an integer, got '%s'.", key, as.character(v))
  as.integer(round(x))
}

ag_fmt <- function(x, digits = 2) {
  if (length(x) == 0) return("NA")
  vapply(x, function(v) {
    if (is.na(v)) return("NA")
    if (!is.finite(v)) return("NA")
    formatC(round(v, digits), format = "f", digits = digits)
  }, character(1))
}

ag_fmt_pct <- function(x, digits = 1) {
  if (length(x) == 0) return("NA")
  vapply(x, function(v) {
    if (is.na(v) || !is.finite(v)) return("NA")
    formatC(round(100 * v, digits), format = "f", digits = digits)
  }, character(1), USE.NAMES = FALSE)
}

ag_fmt_p <- function(p) {
  # MUST-13: never "p = 0.000"; never "p = <0.001".
  if (is.null(p) || length(p) != 1 || is.na(p)) return("p not estimable")
  if (p < 0.0001) return("p < 0.0001")
  if (p < 0.001) return("p < 0.001")
  sprintf("p = %s", formatC(round(p, 3), format = "f", digits = 3))
}

ag_ascii_message <- function(x) {
  if (is.null(x) || length(x) != 1 || is.na(x)) return(NA_character_)
  x <- gsub("[[:space:]]+", " ", as.character(x))
  x <- iconv(x, from = "UTF-8", to = "ASCII", sub = "")
  if (is.na(x)) return(NA_character_)
  x <- trimws(gsub(" +", " ", x))
  if (!nzchar(x)) NA_character_ else x
}

ag_pkg_available <- function(pkg) {
  shim <- Sys.getenv("OMICSTAT_AGREEMENT_SIMULATE_MISSING", "")
  if (nzchar(shim) && pkg %in% trimws(strsplit(shim, ",", fixed = TRUE)[[1]])) return(FALSE)
  requireNamespace(pkg, quietly = TRUE)
}

ag_pkg_version <- function(pkg) {
  if (!ag_pkg_available(pkg)) return(NA_character_)
  tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
}

ag_require_pkg <- function(pkg, role, route) {
  if (!ag_pkg_available(pkg)) {
    ag_stop("OS_MISSING_PACKAGE",
            paste0("the %s route requires the '%s' package (%s) and it is not installed in this R library. ",
                   "This module never installs packages and never reimplements a package's estimator. ",
                   "Required action: use the independently authorized exact OmicStat closure containing '%s' and rerun; do not install a substitute."),
            route, pkg, role, pkg)
  }
  invisible(TRUE)
}

ag_read_labels <- function(path) {
  if (!file.exists(path)) ag_stop("OS_MISSING_FILE", "label file '%s' does not exist.", basename(path))
  ext <- tolower(tools::file_ext(path))
  raw <- NULL
  if (ext %in% c("yaml", "yml")) {
    if (!ag_pkg_available("yaml")) ag_stop("OS_MISSING_PACKAGE", "reading a YAML label map requires the 'yaml' package.")
    raw <- yaml::read_yaml(path)
  } else if (ext == "json") {
    if (!ag_pkg_available("jsonlite")) ag_stop("OS_MISSING_PACKAGE", "reading a JSON label map requires the 'jsonlite' package.")
    raw <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  } else if (ext == "csv") {
    df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    if (!all(c("key", "label") %in% names(df))) {
      ag_stop("OS_INVALID_PARAMETER", "a CSV label map needs columns 'key' and 'label'.")
    }
    raw <- as.list(stats::setNames(as.character(df$label), as.character(df$key)))
  } else {
    ag_stop("OS_INVALID_PARAMETER", "--labels must be .yaml/.yml, .json, or .csv, got '%s'.", basename(path))
  }
  if (!is.list(raw)) raw <- as.list(raw)
  # A nested 'labels:' block is accepted so a single YAML file can carry both
  # the map and other module-local settings.
  if (!is.null(raw$labels) && is.list(raw$labels)) raw <- raw$labels
  flat <- unlist(raw, recursive = TRUE, use.names = TRUE)
  if (is.null(flat) || !length(flat)) ag_stop("OS_INVALID_PARAMETER", "the label map is empty.")
  nms <- names(flat)
  if (ext %in% c("yaml", "yml") && any(nms %in% c("TRUE", "FALSE"))) {
    # YAML 1.1 coerces bare Yes:/No:/On:/Off:/Y:/N: KEYS to booleans, and
    # Yes/No are the most common binary category codes in this domain. Recover
    # the literal spelling from the file text rather than guessing which of the
    # many boolean spellings the author used.
    nms <- ag_recover_yaml_keys(path, nms)
  }
  stats::setNames(as.character(flat), nms)
}

ag_recover_yaml_keys <- function(path, nms) {
  lines <- readLines(path, warn = FALSE)
  keys <- character(0)
  for (ln in lines) {
    if (!grepl("^[^#[:space:]].*:", ln)) next
    k <- sub(":.*$", "", ln)
    k <- gsub("^\\s*[\"']?|[\"']?\\s*$", "", k)
    keys <- c(keys, k)
  }
  if (length(keys) != length(nms)) {
    ag_stop("OS_INVALID_PARAMETER",
            paste0("the YAML label map contains a key that YAML 1.1 reads as a boolean (Yes, No, On, Off, Y, N, ",
                   "True, False). Required action: quote those keys, for example \"Yes\": \"Pressure injury\"."))
  }
  for (i in seq_along(nms)) {
    if (nms[i] %in% c("TRUE", "FALSE") && keys[i] %in% AG_YAML_BOOL_TOKENS) nms[i] <- keys[i]
  }
  nms
}

ag_label <- function(map, key, fallback = NULL) {
  if (is.null(key) || is.na(key)) return(fallback %||% "the measurement")
  k <- as.character(key)
  if (!is.null(map) && k %in% names(map) && nzchar(map[[k]])) return(unname(map[[k]]))
  fallback
}

ag_require_labels <- function(map, keys, what) {
  keys <- unique(keys[!is.na(keys) & nzchar(keys)])
  missing <- keys[!keys %in% names(map)]
  if (length(missing)) {
    ag_stop("OS_INVALID_INPUT",
            paste0("the label map does not cover %s: %s. Every reader-facing %s must have an English label ",
                   "because raw column names and category codes must never reach a table, figure, or draft ",
                   "(OAG-03). Required action: add the missing key(s) to --labels and rerun."),
            what, paste(sprintf("'%s'", missing), collapse = ", "), what)
  }
  invisible(TRUE)
}

ag_read_csv <- function(path) {
  if (!file.exists(path)) ag_stop("OS_MISSING_FILE", "input file '%s' does not exist.", basename(path))
  df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(df)) ag_stop("OS_INVALID_INPUT", "input file '%s' has no rows.", basename(path))
  df
}

ag_need_cols <- function(df, cols, what) {
  missing <- cols[!cols %in% names(df)]
  if (length(missing)) {
    ag_stop("OS_MISSING_COLUMN", "%s not found in the input: %s. Available columns: %s.",
            what, paste(sprintf("'%s'", missing), collapse = ", "),
            paste(sprintf("'%s'", names(df)), collapse = ", "))
  }
  invisible(TRUE)
}

ag_build_ratings <- function(df, format, id_col, rater_cols, rater_col, rating_col,
                             count_col, levels_declared) {
  format <- match.arg(format, c("wide", "long", "counts"))

  if (format == "wide") {
    if (is.null(rater_cols) || length(rater_cols) < 2) {
      ag_stop("OS_INVALID_PARAMETER", "--rater-cols must name at least two columns for wide input.")
    }
    ag_need_cols(df, rater_cols, "the --rater-cols column(s)")
    if (is.null(id_col)) ag_stop("OS_INVALID_PARAMETER", "--id-col is required for wide input (MUST-01).")
    ag_need_cols(df, id_col, "the --id-col column")
    ids <- as.character(df[[id_col]])
    if (any(is.na(ids) | !nzchar(trimws(ids)))) {
      ag_stop("OS_INVALID_INPUT",
              "OAG-01: %d row(s) have a missing or blank subject ID in '%s'. Every subject needs a non-missing stable ID.",
              sum(is.na(ids) | !nzchar(trimws(ids))), id_col)
    }
    dup <- ids[duplicated(ids)]
    if (length(dup)) {
      ag_stop("OS_INVALID_DESIGN",
              "OAG-02: wide input must have one row per subject, but %d duplicate ID(s) were found (for example: %s).",
              length(unique(dup)), paste(utils::head(unique(dup), 3), collapse = ", "))
    }
    mat <- as.matrix(df[, rater_cols, drop = FALSE])
    mat <- apply(mat, 2, function(z) trimws(as.character(z)))
    if (is.null(dim(mat))) mat <- matrix(mat, nrow = 1, dimnames = list(NULL, rater_cols))
    rownames(mat) <- ids
    colnames(mat) <- rater_cols
    # MUST-01: a missing rating CELL is fatal on this route too. Without this
    # check the two-rater wide route complete-cased silently, because sort()
    # drops NA before level resolution and an NA matrix subscript makes the
    # contingency increment a no-op, so the subject vanished with no guardrail.
    gap <- is.na(mat) | !nzchar(mat)
    if (any(gap)) {
      pos <- which(gap, arr.ind = TRUE)
      first <- utils::head(seq_len(nrow(pos)), 3)
      ag_stop("OS_INVALID_INPUT",
              paste0("OAG-01: %d rating cell(s) are missing or blank (for example: %s). ",
                     "v1 uses --missing fail only; complete the ratings or drop the incomplete ",
                     "subjects yourself before this step, so the analysed count is your decision."),
              sum(gap),
              paste(sprintf("subject '%s' / rater '%s'",
                            ids[pos[first, 1]], rater_cols[pos[first, 2]]), collapse = "; "))
    }
    weights <- rep(1L, nrow(mat))
    return(list(ratings = mat, weights = weights, ids = ids, raters = rater_cols,
                n_input = nrow(df), has_ids = TRUE))
  }

  if (format == "long") {
    if (is.null(id_col) || is.null(rater_col) || is.null(rating_col)) {
      ag_stop("OS_INVALID_PARAMETER", "long input needs --id-col, --rater-col, and --rating-col.")
    }
    ag_need_cols(df, c(id_col, rater_col, rating_col), "the long-format column(s)")
    ids <- as.character(df[[id_col]])
    rr <- as.character(df[[rater_col]])
    vv <- trimws(as.character(df[[rating_col]]))
    if (any(is.na(ids) | !nzchar(trimws(ids)))) {
      ag_stop("OS_INVALID_INPUT", "OAG-01: %d long-format row(s) have a missing subject ID.",
              sum(is.na(ids) | !nzchar(trimws(ids))))
    }
    # Defect E13 (audit 2026-10): a blank or missing rating in long format used
    # to reach the contingency step and crash untyped. Same MUST-01 gap check
    # as the wide route.
    vgap <- is.na(vv) | !nzchar(vv)
    if (any(vgap)) {
      first <- utils::head(which(vgap), 3)
      ag_stop("OS_INVALID_INPUT",
              paste0("OAG-01: %d rating cell(s) are missing or blank (for example: %s). ",
                     "v1 uses --missing fail only; complete the ratings or drop the incomplete ",
                     "subjects yourself before this step, so the analysed count is your decision."),
              sum(vgap),
              paste(sprintf("subject '%s' / rater '%s'", ids[first], rr[first]), collapse = "; "))
    }
    pair <- paste(ids, rr, sep = "\r")
    if (anyDuplicated(pair)) {
      d <- unique(pair[duplicated(pair)])
      ag_stop("OS_INVALID_DESIGN",
              "OAG-02: long input must have one row per subject-rater pair, but %d duplicate pair(s) were found (for example: %s).",
              length(d), paste(sub("\r", " / ", utils::head(d, 3)), collapse = "; "))
    }
    raters <- if (!is.null(rater_cols)) rater_cols else unique(rr)
    unknown <- setdiff(unique(rr), raters)
    if (length(unknown)) {
      ag_stop("OS_INVALID_INPUT", "OAG-01: the long input contains rater value(s) not declared in --rater-cols: %s.",
              paste(sprintf("'%s'", unknown), collapse = ", "))
    }
    subj <- unique(ids)
    mat <- matrix(NA_character_, nrow = length(subj), ncol = length(raters),
                  dimnames = list(subj, raters))
    mat[cbind(match(ids, subj), match(rr, raters))] <- vv
    if (anyNA(mat)) {
      nmiss <- sum(is.na(mat))
      ag_stop("OS_INVALID_DESIGN",
              paste0("OAG-02: the subject-by-rater matrix is not rectangular -- %d subject-rater cell(s) have no row. ",
                     "v1 refuses silent listwise deletion; supply a complete matrix or drop the incomplete subjects yourself."),
              nmiss)
    }
    return(list(ratings = mat, weights = rep(1L, nrow(mat)), ids = subj, raters = raters,
                n_input = nrow(df), has_ids = TRUE))
  }

  # counts
  if (is.null(rater_cols) || length(rater_cols) != 2) {
    ag_stop("OS_INVALID_PARAMETER", "counts input needs exactly two --rater-cols (the row rater and the column rater).")
  }
  if (is.null(count_col)) ag_stop("OS_INVALID_PARAMETER", "counts input needs --count-col.")
  ag_need_cols(df, c(rater_cols, count_col), "the counts column(s)")
  a <- trimws(as.character(df[[rater_cols[1]]]))
  b <- trimws(as.character(df[[rater_cols[2]]]))
  # MUST-01, counts route: a blank category label would become its own silent
  # cell, so it is refused here for the same reason a missing rating is.
  cat_gap <- is.na(a) | !nzchar(a) | is.na(b) | !nzchar(b)
  if (any(cat_gap)) {
    ag_stop("OS_INVALID_INPUT",
            "OAG-01: %d counts row(s) have a missing or blank category in '%s' or '%s'.",
            sum(cat_gap), rater_cols[1], rater_cols[2])
  }
  n <- df[[count_col]]
  if (!is.numeric(n)) n <- suppressWarnings(as.numeric(n))
  if (any(is.na(n)) || any(!is.finite(n)) || any(n < 0) || any(abs(n - round(n)) > 1e-9)) {
    ag_stop("OS_INVALID_INPUT", "OAG-01: '%s' must contain non-negative integer counts.", count_col)
  }
  if (any(n > .Machine$integer.max) || sum(n) > .Machine$integer.max)
    ag_stop("OS_RESOURCE_LIMIT", "Count total exceeds the exact supported integer range; preserve the full table and use a reviewed larger-count implementation, not subsampling.")
  n <- as.integer(round(n))
  cell <- paste(a, b, sep = "\r")
  if (anyDuplicated(cell)) {
    d <- unique(cell[duplicated(cell)])
    ag_stop("OS_INVALID_DESIGN", "OAG-02: counts input must have exactly one row per cell, but %d cell(s) repeat (for example: %s).",
            length(d), paste(sub("\r", " x ", utils::head(d, 3)), collapse = "; "))
  }
  lv <- levels_declared %||% sort(unique(c(a, b)))
  extra <- setdiff(unique(c(a, b)), lv)
  if (length(extra)) ag_stop("OS_INVALID_INPUT", "OOAG-04: counts categories outside declared levels, including zero cells: %s", paste(extra, collapse = ", "))
  want <- expand.grid(r = lv, c = lv, stringsAsFactors = FALSE)
  want_cell <- paste(want$r, want$c, sep = "\r")
  gap <- setdiff(want_cell, cell)
  if (length(gap)) {
    ag_stop("OS_INVALID_INPUT",
            paste0("OAG-01: counts input must contain exactly one row per declared cell, but %d cell(s) are absent ",
                   "(for example: %s). Add the zero-count rows explicitly so the tabulation is auditable."),
            length(gap), paste(sub("\r", " x ", utils::head(gap, 3)), collapse = "; "))
  }
  keep <- n > 0
  mat <- cbind(a[keep], b[keep])
  colnames(mat) <- rater_cols
  rownames(mat) <- NULL
  list(ratings = mat, weights = n[keep], ids = NULL, raters = rater_cols,
       n_input = sum(n), has_ids = FALSE)
}

ag_resolve_levels <- function(ratings, scale, levels_declared) {
  observed <- sort(unique(as.vector(ratings)))
  if (scale == "ordinal") {
    if (is.null(levels_declared)) {
      ag_stop("OS_MISSING_PARAMETER",
              paste0("OAG-04: ordinal categories require an explicit ordered level vector via --levels. ",
                     "This module never infers or alphabetises an ordinal scale. Observed categories (alphabetical, ",
                     "NOT an implied order): %s."),
              paste(sprintf("'%s'", observed), collapse = ", "))
    }
  }
  lv <- levels_declared %||% observed
  if (anyDuplicated(lv)) {
    ag_stop("OS_INVALID_PARAMETER", "OAG-04: --levels contains duplicate entries: %s.",
            paste(sprintf("'%s'", unique(lv[duplicated(lv)])), collapse = ", "))
  }
  extra <- setdiff(observed, lv)
  if (length(extra)) {
    ag_stop("OS_INVALID_INPUT",
            "OAG-04: the data contain categories outside --levels. Declared: %s. Observed: %s. Unexpected: %s.",
            paste(sprintf("'%s'", lv), collapse = ", "),
            paste(sprintf("'%s'", observed), collapse = ", "),
            paste(sprintf("'%s'", extra), collapse = ", "))
  }
  lv
}

ag_contingency <- function(ratings, weights, levels) {
  a <- factor(ratings[, 1], levels = levels)
  b <- factor(ratings[, 2], levels = levels)
  tab <- matrix(0, nrow = length(levels), ncol = length(levels), dimnames = list(levels, levels))
  for (i in seq_along(a)) tab[as.integer(a[i]), as.integer(b[i])] <- tab[as.integer(a[i]), as.integer(b[i])] + weights[i]
  storage.mode(tab) <- "double"
  tab
}

ag_expand_pairs <- function(ratings, weights) {
  # Subject-level rows, used for the optional subject bootstrap (never a
  # cell-level bootstrap -- P3-agreement.md 1.2).
  idx <- rep(seq_len(nrow(ratings)), times = weights)
  ratings[idx, , drop = FALSE]
}

ag_interpret <- function(k, scheme) {
  if (is.na(k)) return(NA_character_)
  if (identical(scheme, "none")) return(NA_character_)
  if (k < 0) return("below chance expectation")
  if (identical(scheme, "mchugh")) {
    if (k <= 0.20) return("none")
    if (k <= 0.39) return("minimal")
    if (k <= 0.59) return("weak")
    if (k <= 0.79) return("moderate")
    if (k <= 0.90) return("strong")
    return("almost perfect")
  }
  # landis-koch (default)
  if (k <= 0.20) return("slight")
  if (k <= 0.40) return("fair")
  if (k <= 0.60) return("moderate")
  if (k <= 0.80) return("substantial")
  "almost perfect"
}

ag_scheme_label <- function(scheme) {
  switch(scheme,
         "landis-koch" = "Landis and Koch",
         "mchugh" = "McHugh",
         "none" = "no interpretation scheme",
         scheme)
}

ag_vcd_kappa <- function(tab, weights_kind, conf_level) {
  w <- switch(weights_kind,
              "none" = NULL,
              "linear" = "Equal-Spacing",
              "quadratic" = "Fleiss-Cohen",
              NULL)
  k <- if (is.null(w)) vcd::Kappa(x = tab) else vcd::Kappa(x = tab, weights = w)
  slot <- if (is.null(w)) k$Unweighted else k$Weighted
  est <- unname(slot[["value"]])
  se <- unname(slot[["ASE"]])
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  list(estimate = est, se = se,
       ci_lower = est - z * se, ci_upper = est + z * se,
       p_value = if (is.finite(se) && se > 0) 2 * stats::pnorm(-abs(est / se)) else NA_real_)
}

ag_bootstrap_kappa <- function(pairs, levels, weights_kind, conf_level, reps, seed) {
  set.seed(seed)
  n <- nrow(pairs)
  out <- rep(NA_real_, reps)
  for (i in seq_len(reps)) {
    idx <- sample.int(n, n, replace = TRUE)
    tb <- ag_contingency(pairs[idx, , drop = FALSE], rep(1L, n), levels)
    out[i] <- tryCatch(ag_vcd_kappa(tb, weights_kind, conf_level)$estimate,
                       error = function(e) NA_real_, warning = function(w) NA_real_)
  }
  ok <- out[is.finite(out)]
  alpha <- 1 - conf_level
  list(n_success = length(ok), n_fail = reps - length(ok),
       ci_lower = if (length(ok) > 1) unname(stats::quantile(ok, alpha / 2)) else NA_real_,
       ci_upper = if (length(ok) > 1) unname(stats::quantile(ok, 1 - alpha / 2)) else NA_real_)
}

ag_binary_companions <- function(tab, conf_level) {
  # Cell letters follow the DECLARED level order: a = [1,1], b = [1,2],
  # c = [2,1], d = [2,2] (P3-agreement.md 1.1). The first declared level plays
  # the algebraic role of "positive" in the specific-agreement formulas, so the
  # reader-facing tables name the level instead of saying "positive"/"negative"
  # -- a level vector declared as No,Yes would otherwise report "positive
  # agreement" for the category "No".
  a <- tab[1, 1]; b <- tab[1, 2]; c <- tab[2, 1]; d <- tab[2, 2]
  n <- a + b + c + d
  po <- (a + d) / n
  out <- list(
    n = n, a = a, b = b, c = c, d = d,
    observed_agreement = po,
    pabak = 2 * po - 1,
    prevalence_index = (a - d) / n,
    bias_index = (b - c) / n,
    specific_agreement_first = if ((2 * a + b + c) > 0) 2 * a / (2 * a + b + c) else NA_real_,
    specific_agreement_second = if ((2 * d + b + c) > 0) 2 * d / (2 * d + b + c) else NA_real_,
    engine = "epiR",
    engine_version = NA_character_,
    pabak_ci_lower = NA_real_, pabak_ci_upper = NA_real_,
    prevalence_index_ci = c(NA_real_, NA_real_),
    bias_index_ci = c(NA_real_, NA_real_)
  )
  ag_require_pkg("epiR", "binary sensitivity companions", "binary kappa")
  {
    e <- tryCatch(epiR::epi.kappa(dat = tab, method = "fleiss", alternative = "two.sided", conf.level = conf_level),
                  error = function(err) ag_stop("OS_INVALID_RESULT", "epiR binary companions failed: %s", conditionMessage(err)))
    if (!is.null(e)) {
      out$pabak <- e$pabak$est
      out$pabak_ci_lower <- e$pabak$lower
      out$pabak_ci_upper <- e$pabak$upper
      out$prevalence_index <- e$pindex$est
      out$prevalence_index_ci <- c(e$pindex$lower, e$pindex$upper)
      out$bias_index <- e$bindex$est
      out$bias_index_ci <- c(e$bindex$lower, e$bindex$upper)
      out$mcnemar_p <- e$mcnemar$p.value
      out$engine_version <- ag_pkg_version("epiR")
    }
  }
  out
}

ag_marginals <- function(tab, levels) {
  rs <- rowSums(tab); cs <- colSums(tab); n <- sum(tab)
  data.frame(
    category = levels,
    rater_1_n = as.integer(rs), rater_1_prop = rs / n,
    rater_2_n = as.integer(cs), rater_2_prop = cs / n,
    stringsAsFactors = FALSE
  )
}

ag_kappa_route <- function(ratings, weights, levels, scale, weights_kind, conf_level,
                           ci_method, boot_reps, seed, scheme, thresholds) {
  n_raters <- ncol(ratings)
  if (n_raters != 2) ag_stop("OS_INVALID_INPUT", "the Cohen kappa route needs exactly two raters, got %d.", n_raters)
  if (scale == "nominal" && !identical(weights_kind, "none")) {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-04: weighted kappa was requested for a nominal scale. Weights encode a distance between ",
                   "categories, which nominal categories do not have. Required action: declare --scale ordinal with ",
                   "an explicit --levels order, or use --weights none."))
  }
  tab <- ag_contingency(ratings, weights, levels)
  n <- sum(tab)
  if (n < 1) ag_stop("OS_INVALID_INPUT", "no rateable pairs remain.")
  eff_cat <- sum(rowSums(tab) > 0 | colSums(tab) > 0)
  if (eff_cat < 2) {
    ag_stop("OS_INVALID_RESULT",
            paste0("OAG-05: only one category is effectively in use, so the chance-agreement denominator degenerates ",
                   "and no chance-corrected coefficient is estimable. The statistic is withheld rather than reported ",
                   "as a number."))
  }
  po <- sum(diag(tab)) / n
  pe <- sum(rowSums(tab) * colSums(tab)) / n^2
  if (abs(1 - pe) < 1e-12) {
    ag_stop("OS_INVALID_RESULT",
            "OAG-05: expected agreement is 1, so the chance-corrected denominator (1 - Pe) is zero and kappa is not estimable.")
  }

  ag_require_pkg("vcd", "primary two-rater kappa coefficient and approximate large-sample SE", "categorical agreement")
  vcd_ver <- ag_pkg_version("vcd")

  wanted <- switch(weights_kind,
                   "none" = "none",
                   "linear" = c("none", "linear"),
                   "quadratic" = c("none", "quadratic"),
                   "both" = c("none", "linear", "quadratic"))
  pairs <- if (identical(ci_method, "bootstrap")) ag_expand_pairs(ratings, weights) else NULL
  rows <- list()
  for (w in wanted) {
    est <- ag_vcd_kappa(tab, w, conf_level)
    ci_lo <- est$ci_lower; ci_hi <- est$ci_upper
    ci_meth <- "analytic (normal approximation on the vcd large-sample SE)"
    boot_meta <- list(reps = NA_integer_, success = NA_integer_, fail = NA_integer_, seed = NA_integer_)
    if (identical(ci_method, "bootstrap")) {
      bs <- ag_bootstrap_kappa(pairs, levels, w, conf_level, boot_reps, seed)
      ci_lo <- bs$ci_lower; ci_hi <- bs$ci_upper
      # MUST-07 asks for the bootstrap metadata on EVERY interval row, not only
      # the Fleiss one: a percentile interval whose replicate count and seed are
      # not on the row is not reproducible from the row (gate 2026-08-23,
      # Minor 3).
      ci_meth <- sprintf("subject bootstrap (percentile), %d of %d replicates succeeded (seed %d)",
                         bs$n_success, boot_reps, seed)
      boot_meta <- list(reps = boot_reps, success = bs$n_success, fail = bs$n_fail, seed = seed)
    }
    # Primary/sensitivity ruling (P3-agreement.md 1.1): unweighted is primary
    # for nominal data; linear weighted is primary for ordinal data and
    # quadratic is a required sensitivity companion because it can be
    # materially larger; unweighted is retained as secondary for ordinal data.
    status <- if (scale == "nominal") {
      if (w == "none") "primary" else "sensitivity"
    } else {
      if (w == "linear") "primary" else "sensitivity"
    }
    rows[[length(rows) + 1L]] <- list(
      coefficient = if (w == "none") "Cohen's unweighted kappa" else sprintf("Cohen's %s weighted kappa", w),
      weights = w,
      estimate = est$estimate, se = est$se, ci_lower = ci_lo, ci_upper = ci_hi,
      p_value = est$p_value,
      # Defect E11 (audit 2026-10): this P value is a Wald z test that divides
      # kappa by vcd's NON-NULL asymptotic SE, not the null-variance test of
      # kappa = 0. The number is unchanged; its construction is now labelled.
      p_value_method = "Wald z test of kappa = 0 using the non-null asymptotic SE from vcd::Kappa (not the null-variance test)",
      ci_method = ci_meth, ci_level = conf_level,
      engine = "vcd::Kappa", engine_version = vcd_ver,
      bootstrap_reps = boot_meta$reps, bootstrap_success = boot_meta$success,
      bootstrap_failures = boot_meta$fail, bootstrap_seed = boot_meta$seed,
      interpretation_scheme = scheme,
      interpretation = ag_interpret(est$estimate, scheme),
      status = status
    )
  }

  binary <- NULL
  if (length(levels) == 2) {
    binary <- ag_binary_companions(tab, conf_level)
    binary$engine_version <- ag_pkg_version("epiR")
  }

  primary_k <- rows[[which(vapply(rows, function(r) r$status == "primary", logical(1)))[1]]]$estimate
  paradox <- list(triggered = FALSE, reasons = character(0))
  if (!is.null(binary)) {
    if (po >= thresholds$paradox_agreement && !is.na(primary_k) && primary_k < thresholds$paradox_kappa) {
      paradox$reasons <- c(paradox$reasons,
                           sprintf("observed agreement %s%% at or above %s%% while kappa %s is below %s",
                                   ag_fmt_pct(po), ag_fmt_pct(thresholds$paradox_agreement),
                                   ag_fmt(primary_k), ag_fmt(thresholds$paradox_kappa)))
    }
    if (abs(binary$prevalence_index) >= thresholds$paradox_prevalence_index) {
      paradox$reasons <- c(paradox$reasons,
                           sprintf("absolute prevalence index %s at or above %s",
                                   ag_fmt(abs(binary$prevalence_index)), ag_fmt(thresholds$paradox_prevalence_index)))
    }
    if (abs(binary$bias_index) >= thresholds$paradox_bias_index) {
      paradox$reasons <- c(paradox$reasons,
                           sprintf("absolute bias index %s at or above %s",
                                   ag_fmt(abs(binary$bias_index)), ag_fmt(thresholds$paradox_bias_index)))
    }
    paradox$triggered <- length(paradox$reasons) > 0
  }

  expected <- outer(rowSums(tab), colSums(tab)) / n
  list(
    n = n, n_agree = sum(diag(tab)),
    observed_agreement = po, expected_agreement = pe,
    contingency = tab, expected_counts = expected,
    diagonal_total = sum(diag(tab)), offdiagonal_total = n - sum(diag(tab)),
    levels = levels, scale = scale,
    coefficients = rows, binary = binary,
    marginals = ag_marginals(tab, levels),
    paradox = paradox,
    min_expected = min(expected)
  )
}

ag_fleiss_route <- function(ratings, levels, conf_level, boot_reps, seed, scheme) {
  n_raters <- ncol(ratings)
  if (n_raters < 3) {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-09: Fleiss' kappa needs at least three raters, got %d. Fleiss and Cohen use different ",
                   "chance models, so Fleiss is not a multi-rater drop-in for Cohen. Required action: use ",
                   "--analysis kappa with two raters, or supply a rectangular matrix with three or more raters."),
            n_raters)
  }
  if (anyNA(ratings) || any(!nzchar(ratings))) {
    ag_stop("OS_INVALID_DESIGN",
            "OAG-09: Fleiss' kappa needs a fixed rating count per subject; %d rating cell(s) are missing and v1 refuses silent listwise deletion.",
            sum(is.na(ratings) | !nzchar(ratings)))
  }
  ag_require_pkg("irr", "Fleiss' kappa for m raters", "Fleiss multi-rater")
  df <- as.data.frame(ratings, stringsAsFactors = FALSE)
  fit <- irr::kappam.fleiss(ratings = df, exact = FALSE, detail = FALSE)
  detail <- tryCatch(irr::kappam.fleiss(ratings = df, exact = FALSE, detail = TRUE)$detail, error = function(e) NULL)

  set.seed(seed)
  n <- nrow(df)
  boot <- rep(NA_real_, boot_reps)
  for (i in seq_len(boot_reps)) {
    idx <- sample.int(n, n, replace = TRUE)
    boot[i] <- tryCatch(irr::kappam.fleiss(ratings = df[idx, , drop = FALSE], exact = FALSE, detail = FALSE)$value,
                        error = function(e) NA_real_, warning = function(w) NA_real_)
  }
  ok <- boot[is.finite(boot)]
  alpha <- 1 - conf_level
  cat_rows <- NULL
  if (!is.null(detail)) {
    cat_rows <- data.frame(category = rownames(detail),
                           kappa = as.numeric(detail[, "Kappa"]),
                           z = as.numeric(detail[, "z"]),
                           p_value = as.numeric(detail[, "p.value"]),
                           stringsAsFactors = FALSE)
  }
  dist <- table(factor(as.vector(as.matrix(df)), levels = levels))
  list(
    n_subjects = fit$subjects, n_raters = fit$raters, levels = levels,
    estimate = fit$value, z = fit$statistic, p_value = fit$p.value,
    ci_lower = if (length(ok) > 1) unname(stats::quantile(ok, alpha / 2)) else NA_real_,
    ci_upper = if (length(ok) > 1) unname(stats::quantile(ok, 1 - alpha / 2)) else NA_real_,
    ci_method = "subject bootstrap (percentile)", ci_level = conf_level,
    bootstrap_reps = boot_reps, bootstrap_success = length(ok),
    bootstrap_failures = boot_reps - length(ok), bootstrap_seed = seed,
    engine = "irr::kappam.fleiss", engine_version = ag_pkg_version("irr"),
    category_results = cat_rows,
    category_distribution = data.frame(category = names(dist), n = as.integer(dist), stringsAsFactors = FALSE),
    interpretation_scheme = scheme,
    interpretation = ag_interpret(fit$value, scheme)
  )
}

ag_icc_design <- function(icc_model, definition, unit, rater_population, same_raters,
                          fixed_agreement_rationale = NULL) {
  miss <- character(0)
  if (is.null(unit)) miss <- c(miss, "--icc-unit")
  if (is.null(definition)) miss <- c(miss, "--icc-definition")
  if (is.null(rater_population)) miss <- c(miss, "--rater-population")
  if (is.null(same_raters)) miss <- c(miss, "--same-raters")
  if (length(miss)) {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-10: an ICC is uninterpretable without model, definition, and unit, and this run is missing %s. ",
                   "Required action: declare the sampling design before computation -- the ICC form is chosen from the ",
                   "design and purpose, never from the observed values."),
            paste(miss, collapse = ", "))
  }
  model <- icc_model %||% "auto"
  if (identical(model, "auto")) model <- if (isTRUE(same_raters)) "twoway" else "oneway"
  if (!model %in% c("oneway", "twoway")) {
    ag_stop("OS_INVALID_PARAMETER", "--icc-model must be auto, oneway, or twoway; got '%s'.", model)
  }
  if (identical(model, "twoway") && !isTRUE(same_raters)) {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-10: --icc-model twoway states that every subject was rated by the same raters, but ",
                   "--same-raters is false. Required action: resolve the contradiction before computation."))
  }
  if (identical(model, "oneway") && isTRUE(same_raters)) {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-10: --icc-model oneway states that each subject was rated by a different set of raters, but ",
                   "--same-raters is true. Required action: resolve the contradiction before computation."))
  }
  if (identical(model, "oneway") && !identical(definition, "agreement")) {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-10: a one-way random-effects design has no rater main effect to remove, so a consistency ",
                   "definition does not map to a permitted ICC form. Required action: use --icc-definition agreement, ",
                   "or change the design declaration."))
  }
  form <- NULL; model_desc <- NULL; def_desc <- NULL
  if (identical(model, "oneway")) {
    form <- "one-way"
    model_desc <- "one-way random-effects"
    def_desc <- "absolute agreement"
  } else if (identical(rater_population, "random") && identical(definition, "agreement")) {
    form <- "two-way-random"
    model_desc <- "two-way random-effects"
    def_desc <- "absolute agreement"
  } else if (identical(rater_population, "fixed") && identical(definition, "consistency")) {
    form <- "two-way-mixed"
    model_desc <- "two-way mixed-effects"
    def_desc <- "consistency"
  } else if (identical(rater_population, "fixed") && identical(definition, "agreement")) {
    if (is.null(fixed_agreement_rationale) || !nzchar(fixed_agreement_rationale)) {
      ag_stop("OS_INVALID_DESIGN",
              paste0("OAG-10: same fixed raters combined with an absolute-agreement definition is the one combination ",
                     "this module refuses as a shortcut, because a fixed rater set cannot support an absolute-agreement ",
                     "claim about raters outside the study. Required action: either change --rater-population to random ",
                     "(mapping to a two-way random-effects absolute-agreement form) or supply ",
                     "--icc-fixed-agreement-rationale explaining why the fixed set is the target population."))
    }
    form <- "two-way-mixed-agreement"
    model_desc <- "two-way mixed-effects"
    def_desc <- "absolute agreement"
  } else {
    ag_stop("OS_INVALID_DESIGN",
            paste0("OAG-10: rater population '%s' combined with definition '%s' does not map to one of the permitted ",
                   "ICC forms. Required action: declare one of -- different raters per subject (one-way); same raters ",
                   "drawn from a random rater population with an absolute-agreement definition; or same fixed raters ",
                   "with a consistency definition."),
            rater_population, definition)
  }
  # Shrout-Fleiss notation is stored alongside the semantic wording (MUST-09).
  sf_first <- switch(form, "one-way" = "1", "two-way-random" = "2", "two-way-mixed" = "3", "two-way-mixed-agreement" = "2")
  list(
    form = form,
    irr_model = model,
    irr_type = if (identical(model, "oneway")) "agreement" else definition,
    irr_unit = unit,
    definition = definition,
    definition_description = def_desc,
    model_description = model_desc,
    unit = unit,
    unit_description = if (identical(unit, "single")) "a single rater as the unit of measurement" else "the mean of the raters as the unit of measurement",
    rater_population = rater_population,
    same_raters = isTRUE(same_raters),
    shrout_fleiss_index = sf_first,
    fixed_agreement_rationale = fixed_agreement_rationale %||% NA_character_
  )
}

ag_icc_notation <- function(design, k) {
  unit_part <- if (identical(design$unit, "single")) "1" else "k"
  sprintf("ICC(%s,%s)", design$shrout_fleiss_index, unit_part)
}

ag_icc_route <- function(mat, design, conf_level) {
  if (nrow(mat) < 2 || ncol(mat) < 2) {
    ag_stop("OS_INVALID_RESULT",
            "OAG-11: an ICC needs at least two subjects and two raters, got %d subject(s) and %d rater(s).",
            nrow(mat), ncol(mat))
  }
  if (anyNA(mat)) {
    ag_stop("OS_INVALID_RESULT",
            paste0("OAG-11: the subject-by-rater matrix has %d missing value(s). v1 withholds the ICC rather than ",
                   "silently deleting subjects. Required action: supply a complete balanced matrix, or handle the ",
                   "missing ratings explicitly before this step."),
            sum(is.na(mat)))
  }
  if (any(!is.finite(mat))) {
    ag_stop("OS_INVALID_INPUT", "OAG-01: the rating matrix contains non-finite values.")
  }
  if (stats::var(as.vector(mat)) == 0) {
    ag_stop("OS_INVALID_RESULT", "OAG-05: all ratings are identical, so between-subject variance is zero and no ICC is estimable.")
  }
  notation <- ag_icc_notation(design, ncol(mat))
  fallback <- FALSE
  fallback_singular <- NA
  fallback_messages <- NA_character_
  engine <- NULL; est <- NA_real_; lo <- NA_real_; hi <- NA_real_; pval <- NA_real_; fstat <- NA_real_

  ag_require_pkg("irr", "primary declared ICC estimator; no substitute", "ICC")
  fit <- irr::icc(ratings = as.data.frame(mat), model = design$irr_model,
    type = design$irr_type, unit = design$irr_unit, r0 = 0, conf.level = conf_level)
  engine <- "irr::icc"; est <- fit$value; lo <- fit$lbound; hi <- fit$ubound
  pval <- fit$p.value; fstat <- fit$Fvalue
  engine_native_name <- fit$icc.name; engine_version <- ag_pkg_version("irr")
  if (!is.finite(est)) {
    ag_stop("OS_INVALID_RESULT", "OAG-11: the package reported a non-estimable %s for this matrix.", notation)
  }
  list(
    notation = notation, design = design,
    n_subjects = nrow(mat), n_raters = ncol(mat),
    estimate = est, ci_lower = lo, ci_upper = hi, ci_level = conf_level,
    p_value = pval, f_statistic = fstat,
    engine = engine, engine_version = engine_version,
    engine_native_name = engine_native_name,
    fallback_used = fallback,
    fallback_singular_fit = fallback_singular,
    fallback_engine_messages = fallback_messages,
    ci_method = sprintf("%s exact F-distribution interval", engine)
  )
}

ag_icc_band <- function(x) {
  if (is.na(x)) return(NA_character_)
  if (x < 0.50) return("poor")
  if (x < 0.75) return("moderate")
  if (x <= 0.90) return("good")
  "excellent"
}

ag_icc_band_phrase <- function(est, lo, hi) {
  b_est <- ag_icc_band(est)
  b_lo <- ag_icc_band(lo); b_hi <- ag_icc_band(hi)
  if (is.na(b_lo) || is.na(b_hi) || identical(b_lo, b_hi)) {
    return(sprintf("in the %s band", b_est))
  }
  sprintf("in the %s band, with a confidence interval that spans the %s and %s bands", b_est, b_lo, b_hi)
}

ag_bland_altman <- function(a, b, ids, direction, conf_level, clinical_lower, clinical_upper) {
  if (length(a) != length(b)) ag_stop("OS_INVALID_INPUT", "the two method columns have different lengths.")
  if (anyNA(a) || anyNA(b)) {
    ag_stop("OS_INVALID_INPUT",
            "OAG-01: %d measurement value(s) are missing. v1 uses --missing fail only; complete the pairs before this step.",
            sum(is.na(a)) + sum(is.na(b)))
  }
  if (any(!is.finite(a)) || any(!is.finite(b))) ag_stop("OS_INVALID_INPUT", "OAG-01: non-finite measurement values are not allowed.")
  n <- length(a)
  if (n < 3) ag_stop("OS_INVALID_RESULT", "OAG-05: at least three pairs are needed for limits of agreement, got %d.", n)
  diff <- if (identical(direction, "b-minus-a")) b - a else a - b
  mean_pair <- (a + b) / 2
  bias <- mean(diff)
  sd_diff <- stats::sd(diff)
  if (!is.finite(sd_diff) || sd_diff == 0) {
    ag_stop("OS_INVALID_RESULT",
            "OAG-05: the differences have zero variance, so limits of agreement and their uncertainty are not estimable.")
  }
  z <- 1.96  # Bland and Altman 1986/1999 use 1.96 for the 95% limits.
  tcrit <- stats::qt(1 - (1 - conf_level) / 2, df = n - 1)
  se_bias <- sd_diff / sqrt(n)
  se_loa <- sd_diff * sqrt(1 / n + z^2 / (2 * (n - 1)))
  loa_lower <- bias - z * sd_diff
  loa_upper <- bias + z * sd_diff

  # OAG-13 exploratory diagnostics -- they flag, they never define agreement and
  # never trigger an automatic transformation or proportional-bias adjustment.
  sp <- suppressWarnings(stats::cor.test(mean_pair, abs(diff), method = "spearman", exact = FALSE))
  trend <- suppressWarnings(stats::cor.test(mean_pair, diff, method = "spearman", exact = FALSE))
  resid_sd <- stats::sd(diff)
  studentized <- if (n > 2) {
    vapply(seq_len(n), function(i) {
      m <- mean(diff[-i]); s <- stats::sd(diff[-i])
      if (!is.finite(s) || s == 0) NA_real_ else (diff[i] - m) / s
    }, numeric(1))
  } else rep(NA_real_, n)
  shapiro_p <- if (n >= 3 && n <= 5000) tryCatch(stats::shapiro.test(diff)$p.value, error = function(e) NA_real_) else NA_real_

  compatible <- NA
  if (!is.null(clinical_lower) && !is.null(clinical_upper)) {
    compatible <- (loa_lower - tcrit * se_loa) >= clinical_lower && (loa_upper + tcrit * se_loa) <= clinical_upper
  }

  list(
    n = n, direction = direction,
    pairs = data.frame(subject_id = if (is.null(ids)) seq_len(n) else ids,
                       method_a = a, method_b = b, pair_mean = mean_pair, difference = diff,
                       studentized_difference = studentized, stringsAsFactors = FALSE),
    bias = bias, bias_ci_lower = bias - tcrit * se_bias, bias_ci_upper = bias + tcrit * se_bias,
    sd_difference = sd_diff, se_bias = se_bias, se_loa = se_loa,
    loa_lower = loa_lower, loa_lower_ci_lower = loa_lower - tcrit * se_loa, loa_lower_ci_upper = loa_lower + tcrit * se_loa,
    loa_upper = loa_upper, loa_upper_ci_lower = loa_upper - tcrit * se_loa, loa_upper_ci_upper = loa_upper + tcrit * se_loa,
    ci_level = conf_level, ci_method = "normal-theory (Bland and Altman 1986, 1999)",
    clinical_lower = clinical_lower %||% NA_real_, clinical_upper = clinical_upper %||% NA_real_,
    clinical_limits_supplied = !is.null(clinical_lower) && !is.null(clinical_upper),
    compatible = compatible,
    diagnostics = list(
      heteroscedastic_rho = unname(sp$estimate), heteroscedastic_p = sp$p.value,
      trend_rho = unname(trend$estimate), trend_p = trend$p.value,
      max_abs_studentized = if (all(is.na(studentized))) NA_real_ else max(abs(studentized), na.rm = TRUE),
      shapiro_p = shapiro_p, residual_sd = resid_sd
    )
  )
}

