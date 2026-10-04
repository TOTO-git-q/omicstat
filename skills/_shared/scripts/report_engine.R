# report_engine.R -- shared "numbers-drive-text" prose generator for the
# omicstat skill suite. ASCII only (Windows R with a non-UTF8 locale mangles
# non-ASCII source).
#
# This file generalises two things that rcs-analysis/scripts/rcs_report.R
# proved out for restricted cubic splines:
#
#   1. A set of formatting primitives that fix the specific mistakes that show
#      up in submitted manuscripts: "P = <0.001", "-2.80--1.32", "an U-shaped",
#      a 35% change reported next to a ratio on the wrong side of 1, a knot
#      count that disagrees with its own percentile list, a cut-point printed
#      to more decimal places than the instrument that measured it.
#
#   2. A slot-fill template mechanism so that a sentence's wording and its
#      numbers cannot drift apart: the template is declared once, and every
#      later fill() call is type-checked against the slot's declared type
#      (a "direction" slot is computed from a numeric estimate; it cannot be
#      handed a hand-typed word).
#
# Every other skill in the suite sources this file and registers its own
# templates on top of the small built-in skeleton at the bottom. See
# docs/report_engine.md for the registration convention.
#
# Design rule (see the project brief): where the applied literature expects a
# plain number, produce a plain number -- never "not computable". Rigour that
# the field does not routinely report becomes an opt-in argument, not a
# silent omission.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# =============================================================================
# 1. Formatting primitives
#
# These are deliberately the same functions rcs_report.R used privately
# (there as .peq/.ci/.an/.smart_round/.oxford/.ordinal/pct_phrase), pulled out
# so every skill gets the same behaviour instead of five slightly different
# reimplementations. tests/test_primitives.R diffs this file's output against
# rcs_report.R's for the same inputs.
# =============================================================================

#' Format a P value.
#'
#' style = "full" -> "P = 0.032" / "P < 0.001" / "P not estimable"
#' style = "eq"   -> "= 0.032"   / "< 0.001"   / "not estimable"
#' style = "bare" -> "0.032"     / "<0.001"    / "NA"          (table cells)
#'
#' "P = <0.001" is a real, recurring formatting bug in submitted manuscripts:
#' the comparison operator and the equals sign end up on the same number.
#' These three styles are the only three that appear in the applied
#' literature; producing a fourth (e.g. "P=0.032" with no space) is a
#' template-authoring bug, not a legitimate style, so it is not offered here.
#'
#' By default (journal = NULL) this rounds to a FIXED number of decimals
#' derived from `eps` (3 decimals for the default eps=0.001), matching
#' rcs_report.R's .peq()/.pfmt()/.pbare() exactly (see test_primitives.R
#' sec 1's parity check against those functions) -- this is deliberately
#' NOT the same rounding rule render_md.R::format_p() uses for a results
#' TABLE cell (which rounds to 2 decimals above p=0.01, per journal style),
#' so the same P value can legitimately show more decimal places in prose
#' than in a table by default. Pass journal= (one of THREE_LINE_STYLES:
#' generic/ama/jama/nejm/lancet) to instead use render_md.R's own
#' journal-style digit rule here, so a Methods sentence and its
#' companion table cell can be made to agree exactly when that matters more
#' than this file's own default precision. The digit RULE is duplicated
#' here rather than sourcing render_md.R, to keep this file's documented
#' zero-dependency property (docs/phase0-integration-report.md sec 4.2);
#' if the two ever need to be kept in exact sync going forward, that is the
#' one place to look.
fmt_p <- function(p, style = c("full", "eq", "bare"), prefix = "P", eps = 0.001, journal = NULL) {
  if (!style[1] %in% c("full", "eq", "bare")) {
    stop(sprintf("OS_INVALID_PARAMETER: fmt_p style must be one of full/eq/bare, got '%s'.", style[1]),
         call. = FALSE)
  }
  style <- style[1]
  if (is.null(p) || length(p) == 0 || is.na(p)) {
    return(switch(style, full = sprintf("%s not estimable", prefix), eq = "not estimable", bare = "NA"))
  }
  if (!is.numeric(p)) {
    stop(sprintf("OS_INVALID_PARAMETER: fmt_p expects a numeric P value, got class '%s'.", class(p)[1]),
         call. = FALSE)
  }
  if (!is.null(journal)) {
    return(.ms_fmt_p_journal(p, style = style, prefix = prefix, journal = journal))
  }
  digits <- max(0L, as.integer(round(-log10(eps))))
  if (p < eps) {
    epstxt <- format(eps, scientific = FALSE)
    return(switch(style,
      full = sprintf("%s < %s", prefix, epstxt),
      eq   = sprintf("< %s", epstxt),
      bare = sprintf("<%s", epstxt)))
  }
  switch(style,
    full = sprintf("%s = %.*f", prefix, digits, p),
    eq   = sprintf("= %.*f", digits, p),
    bare = sprintf("%.*f", digits, p))
}

# Journal-consistent numeric rounding for fmt_p(..., journal=), matching
# render_md.R::format_p()'s digit rules exactly (see that function's own
# comments for the per-journal rationale); only the surrounding "P
# label/operator" assembly differs, and that assembly stays fmt_p()'s own
# job (prefix=/style= are prose-oriented, format_p() is table-cell-only).
.ms_fmt_p_journal <- function(p, style, prefix, journal) {
  valid_journals <- c("generic", "ama", "jama", "nejm", "lancet")
  if (!is.character(journal) || length(journal) != 1 || !journal %in% valid_journals) {
    stop(sprintf("OS_INVALID_PARAMETER: fmt_p journal must be one of %s, got '%s'.",
                 paste(valid_journals, collapse = "/"), format(journal)), call. = FALSE)
  }
  canon <- if (journal == "jama") "ama" else journal
  if (canon %in% c("ama", "nejm")) {
    numeric_part <- if (p < 0.001) "<.001" else sub("^0", "", if (p < 0.01) sprintf("%.3f", p) else sprintf("%.2f", p))
  } else if (canon == "lancet") {
    if (p < 0.0001) {
      numeric_part <- "<0.0001"
    } else {
      xr <- signif(p, 2)
      dec <- if (xr == 0) 2 else max(0, 2 - floor(log10(abs(xr))) - 1)
      numeric_part <- formatC(xr, format = "f", digits = dec)
    }
  } else {
    numeric_part <- if (p < 0.001) "<0.001" else if (p < 0.01) sprintf("%.3f", p) else sprintf("%.2f", p)
  }
  is_lt <- startsWith(numeric_part, "<")
  op <- if (is_lt) "<" else "="
  num_only <- sub("^<", "", numeric_part)
  switch(style,
    full = sprintf("%s %s %s", prefix, op, num_only),
    eq   = sprintf("%s %s", op, num_only),
    bare = numeric_part)
}

#' Format a confidence interval. "-2.80--1.32" is unreadable: an en-dash
#' range is used only when both bounds are non-negative, otherwise the range
#' is spelled out with "to".
fmt_ci <- function(lo, hi, digits = 2) {
  if (!is.numeric(lo) || !is.numeric(hi) || length(lo) != 1 || length(hi) != 1) {
    stop("OS_INVALID_PARAMETER: fmt_ci expects two numeric scalars (lower, upper).", call. = FALSE)
  }
  if (is.na(lo) || is.na(hi)) return("not estimable")
  if (lo < 0 || hi < 0) sprintf("%.*f to %.*f", digits, lo, digits, hi)
  else sprintf("%.*f-%.*f", digits, lo, digits, hi)
}

#' Direction phrased as a percentage, derived from a ratio estimate. Never
#' write the percentage and the ratio separately: "decreased by 35% (HR
#' 1.35)" is a real error pattern (percentage on the wrong side of the null).
fmt_pct_direction <- function(ratio_est) {
  if (!is.numeric(ratio_est) || length(ratio_est) != 1) {
    stop("OS_INVALID_PARAMETER: fmt_pct_direction expects a single numeric ratio estimate.", call. = FALSE)
  }
  if (!is.finite(ratio_est)) return("NA")
  if (ratio_est < 1) sprintf("%.0f%% lower", (1 - ratio_est) * 100)
  else sprintf("%.0f%% higher", (ratio_est - 1) * 100)
}

#' Plain direction word, derived from an estimate versus its null value.
#' null_value defaults to 1 (ratio scale) unless overridden; pass 0 for a
#' difference scale. Ties go to the "higher" side, matching fmt_pct_direction.
fmt_direction_word <- function(estimate, null_value = 1, higher = "higher", lower = "lower") {
  if (!is.numeric(estimate) || length(estimate) != 1) {
    stop("OS_INVALID_PARAMETER: fmt_direction_word expects a single numeric estimate.", call. = FALSE)
  }
  if (!is.finite(estimate)) return(NA_character_)
  if (estimate < null_value) lower else higher
}

#' Round a value to the precision the underlying measurement actually has,
#' instead of printing 9.104 for something measured to one decimal place.
#' Digit count is read off the spread of the raw variable x.
smart_round <- function(v, x) {
  digits <- smart_round_digits(x)
  round(v, digits)
}
smart_round_digits <- function(x) {
  spread <- diff(range(x, na.rm = TRUE))
  if (spread > 500) 0L else if (spread > 50) 1L else if (spread > 5) 2L else 3L
}

#' Indefinite article by pronunciation, not spelling: "a U-shaped" is correct
#' because "U" is said "you"; same family for "uni-"/"eu-" words.
an <- function(word) {
  if (grepl("^[Uu]-", word) || grepl("^(uni|use|eu)", word, ignore.case = TRUE)) return("a")
  if (grepl("^[aeiouAEIOU]", word)) "an" else "a"
}

#' Upper-case the first letter only. Used at the start of a sentence built
#' from a lower-case term.
ucfirst <- function(s) if (!nzchar(s)) s else paste0(toupper(substring(s, 1, 1)), substring(s, 2))

#' Oxford-comma join: "a", "a and b", "a, b, and c".
oxford <- function(v) {
  v <- as.character(v)
  if (length(v) == 0) return("")
  if (length(v) == 1) return(v)
  if (length(v) == 2) return(paste(v, collapse = " and "))
  paste0(paste(v[-length(v)], collapse = ", "), ", and ", v[length(v)])
}

#' Ordinal string for a percentile: 5 -> "5th", 97.5 -> "97.5th", 2 -> "2nd".
ordinal <- function(p) {
  s <- ifelse(abs(p - round(p)) < 1e-8, sprintf("%d", round(p)), sprintf("%.1f", p))
  n <- suppressWarnings(as.integer(round(p)))
  suf <- ifelse(n %% 100 %in% 11:13, "th",
         ifelse(n %% 10 == 1, "st", ifelse(n %% 10 == 2, "nd", ifelse(n %% 10 == 3, "rd", "th"))))
  paste0(s, suf)
}

#' Effect-size vocabulary for the four regression families the suite covers.
#' word/abbr/null mirror rcs_report.R's private .effect_word/.effect_abbr/
#' .null_value, merged into one lookup so a new module does not re-derive it.
#' null is a *string* (as printed in prose), ratio is a logical for callers
#' that need to pick a ratio- vs difference-scale sentence template.
effect_label <- function(model) {
  model <- match.arg(model, c("cox", "logistic", "poisson", "linear"))
  switch(model,
    cox      = list(word = "hazard ratio", abbr = "HR", null = "1.00", ratio = TRUE),
    logistic = list(word = "odds ratio",   abbr = "OR", null = "1.00", ratio = TRUE),
    poisson  = list(word = "rate ratio",   abbr = "RR", null = "1.00", ratio = TRUE),
    linear   = list(word = "mean difference", abbr = "beta", null = "0", ratio = FALSE))
}

#' "the survival package" / "the Hmisc, survival, and ggplot2 packages".
#' Small grammar helper for the built-in software-statement template.
pkg_phrase <- function(pkgs) {
  pkgs <- as.character(pkgs)
  if (!length(pkgs)) stop("OS_INVALID_PARAMETER: pkg_phrase needs at least one package name.", call. = FALSE)
  noun <- if (length(pkgs) == 1) "package" else "packages"
  sprintf("the %s %s", oxford(pkgs), noun)
}

#' "P < 0.05" phrasing for a pre-specified alpha (not a fitted P value, so
#' this is a plain formatter, not fmt_p). Formats at whatever precision
#' alpha actually carries, not a fixed 2 decimals -- a fixed %.2f used to
#' print alpha_phrase(0.001) as "P < 0.00" (meaningless) and
#' alpha_phrase(0.005) (a common Bonferroni-adjusted threshold, e.g. 0.05/10
#' comparisons) as "P < 0.01", silently reporting the wrong significance
#' threshold as a plausible-looking number.
alpha_phrase <- function(alpha = 0.05) {
  if (!is.numeric(alpha) || length(alpha) != 1 || !is.finite(alpha) || alpha <= 0 || alpha >= 1) {
    stop("OS_INVALID_PARAMETER: alpha_phrase expects a single finite numeric alpha strictly between 0 and 1.", call. = FALSE)
  }
  sprintf("P < %s", format(alpha, scientific = FALSE, trim = TRUE))
}

# =============================================================================
# 2. Slot-fill template engine
# =============================================================================

# Reuse an existing registry if this file has already been sourced once in
# this R session (several skill scripts source _shared/report_engine.R
# independently); otherwise a re-source would wipe out templates another
# module already registered.
if (!exists(".ms_template_registry", inherits = TRUE) ||
    !is.environment(get(".ms_template_registry", inherits = TRUE))) {
  .ms_template_registry <- new.env(parent = emptyenv())
}

.ms_slot_types <- c("text", "list", "number", "p", "p_bare", "ci", "effect_ci", "direction", "pct_direction")

.ms_valid_id <- function(id) grepl("^[a-zA-Z][a-zA-Z0-9_.]*$", id)
.ms_valid_slot_name <- function(nm) grepl("^[a-zA-Z][a-zA-Z0-9_]*$", nm)

.ms_normalize_slots <- function(id, slots) {
  if (!length(slots)) return(list())
  nms <- names(slots)
  if (is.null(nms) || any(!nzchar(nms))) {
    stop(sprintf("OS_INVALID_PARAMETER: template '%s' slot list must be a named list.", id), call. = FALSE)
  }
  out <- list()
  for (nm in nms) {
    if (!.ms_valid_slot_name(nm)) {
      stop(sprintf("OS_INVALID_PARAMETER: slot name '%s' in template '%s' is not a valid identifier.", nm, id),
           call. = FALSE)
    }
    spec <- slots[[nm]]
    if (is.character(spec) && length(spec) == 1) spec <- list(type = spec)
    if (!is.list(spec) || is.null(spec$type)) {
      stop(sprintf("OS_INVALID_PARAMETER: slot '%s' in template '%s' needs a type (one of: %s).",
                   nm, id, paste(.ms_slot_types, collapse = ", ")), call. = FALSE)
    }
    if (!spec$type %in% .ms_slot_types) {
      stop(sprintf("OS_INVALID_PARAMETER: slot '%s' in template '%s' has unknown type '%s'. Known types: %s.",
                   nm, id, spec$type, paste(.ms_slot_types, collapse = ", ")), call. = FALSE)
    }
    out[[nm]] <- spec
  }
  out
}

#' Register a slot-fill template.
#'
#' text     A single string containing "{{slot_name}}" placeholders.
#' slots    Named list mapping each placeholder to a type, e.g.
#'          list(exposure = "text", p_value = "p", effect = "effect_ci").
#'          A slot spec may instead be a list with extra config, e.g.
#'          list(p_value = list(type = "p", prefix = "P-overall")).
#'          See docs/report_engine.md for the full type/config reference.
#' overwrite  Set TRUE to replace an already-registered id (used when a
#'            module is re-sourced during development).
#'
#' Every {{name}} in text must have a matching slot, and every declared slot
#' must be used at least once -- an unused slot or an undeclared placeholder
#' is a template bug caught at registration time, not at fill() time deep in
#' a pipeline.
declare_template <- function(id, text, slots = list(), overwrite = FALSE) {
  if (!is.character(id) || length(id) != 1 || !nzchar(id) || !.ms_valid_id(id)) {
    stop("OS_INVALID_PARAMETER: template id must be a single string like 'skill.section.name'.", call. = FALSE)
  }
  if (!is.character(text) || length(text) != 1 || is.na(text)) {
    stop(sprintf("OS_INVALID_PARAMETER: template '%s' text must be a single string.", id), call. = FALSE)
  }
  if (exists(id, envir = .ms_template_registry, inherits = FALSE) && !isTRUE(overwrite)) {
    stop(sprintf("OS_TEMPLATE_ALREADY_EXISTS: '%s' is already registered; pass overwrite = TRUE to replace it.",
                 id), call. = FALSE)
  }
  slot_spec <- .ms_normalize_slots(id, slots)

  found <- regmatches(text, gregexpr("\\{\\{[a-zA-Z][a-zA-Z0-9_]*\\}\\}", text))[[1]]
  found_names <- unique(sub("^\\{\\{", "", sub("\\}\\}$", "", found)))
  declared_names <- names(slot_spec)
  undeclared <- setdiff(found_names, declared_names)
  unused <- setdiff(declared_names, found_names)
  if (length(undeclared)) {
    stop(sprintf("OS_TEMPLATE_UNFILLED_SLOT: template '%s' text references undeclared slot(s): %s",
                 id, paste(undeclared, collapse = ", ")), call. = FALSE)
  }
  if (length(unused)) {
    stop(sprintf("OS_INVALID_PARAMETER: template '%s' declares slot(s) never used in its text: %s",
                 id, paste(unused, collapse = ", ")), call. = FALSE)
  }

  assign(id, list(id = id, text = text, slots = slot_spec), envir = .ms_template_registry)
  invisible(id)
}

#' List registered template ids, optionally filtered by a prefix
#' (e.g. list_templates("rcs.") for one skill's own templates).
list_templates <- function(prefix = NULL) {
  ids <- sort(ls(envir = .ms_template_registry, all.names = FALSE))
  if (!is.null(prefix)) ids <- ids[startsWith(ids, prefix)]
  ids
}

#' Fetch a template's definition (id/text/slots) for inspection or docs.
get_template <- function(id) {
  tpl <- get0(id, envir = .ms_template_registry, inherits = FALSE)
  if (is.null(tpl)) {
    stop(sprintf("OS_TEMPLATE_NOT_FOUND: '%s' is not registered. See list_templates().", id), call. = FALSE)
  }
  tpl
}

#' Remove templates from the registry. ids = NULL clears everything; mainly
#' useful for test isolation.
clear_templates <- function(ids = NULL) {
  all_ids <- ls(envir = .ms_template_registry, all.names = FALSE)
  target <- if (is.null(ids)) all_ids else intersect(ids, all_ids)
  if (length(target)) rm(list = target, envir = .ms_template_registry)
  invisible(target)
}

# --- slot -> string -----------------------------------------------------

.ms_slot_err <- function(tpl_id, slot_name, code, msg) {
  stop(sprintf("%s: template '%s' slot '%s': %s", code, tpl_id, slot_name, msg), call. = FALSE)
}

.ms_format_slot <- function(tpl_id, slot_name, spec, value, validate) {
  type <- spec$type
  err <- function(code, msg) .ms_slot_err(tpl_id, slot_name, code, msg)
  body <- function() switch(type,
    text = {
      if (!is.character(value) || length(value) != 1) err("OS_SLOT_TYPE_MISMATCH", "expected a single character string.")
      if (!isTRUE(spec$allow_empty) && !nzchar(value)) {
        err("OS_SLOT_INVALID_VALUE", "empty string not allowed for this slot (set allow_empty=TRUE if intended).")
      }
      as.character(value)
    },
    list = {
      if (!length(value)) {
        if (!is.null(spec$empty_text)) return(spec$empty_text)
        err("OS_SLOT_INVALID_VALUE", "empty list and no empty_text fallback was configured for this slot.")
      }
      if (!is.character(value)) err("OS_SLOT_TYPE_MISMATCH", "expected a character vector.")
      oxford(value)
    },
    number = {
      if (!is.numeric(value) || length(value) != 1) err("OS_SLOT_TYPE_MISMATCH", "expected a single numeric value.")
      if (!is.null(spec$round_to)) return(as.character(smart_round(value, spec$round_to)))
      fmt <- spec$fmt %||% "%.4g"
      sprintf(fmt, value)
    },
    p = {
      if (!(is.null(value) || (is.numeric(value) && length(value) <= 1))) {
        err("OS_SLOT_TYPE_MISMATCH", "expected a single numeric P value (NA/NULL allowed for 'not estimable').")
      }
      fmt_p(if (length(value)) value else NA_real_, style = spec$style %||% "full",
            prefix = spec$prefix %||% "P", eps = spec$eps %||% 0.001)
    },
    p_bare = {
      if (!(is.null(value) || (is.numeric(value) && length(value) <= 1))) {
        err("OS_SLOT_TYPE_MISMATCH", "expected a single numeric P value (NA/NULL allowed).")
      }
      fmt_p(if (length(value)) value else NA_real_, style = "bare", eps = spec$eps %||% 0.001)
    },
    ci = {
      if (!is.numeric(value) || length(value) != 2) err("OS_SLOT_TYPE_MISMATCH", "expected c(lower, upper).")
      fmt_ci(value[1], value[2], digits = spec$digits %||% 2)
    },
    effect_ci = {
      if (!is.numeric(value) || length(value) != 3) err("OS_SLOT_TYPE_MISMATCH", "expected c(estimate, lower, upper).")
      digits <- spec$digits %||% 2
      lbl <- if (!is.null(spec$label)) paste0(spec$label, " ") else ""
      # conf_level (2026-08-14 addition): percent form (95, 90, 99, ...), NOT
      # a 0-1 proportion -- matches how this sentence has always been written
      # ("95% CI"), and matches the commissioned default of 95. Absent
      # spec$conf_level reproduces the exact pre-existing literal "95%% CI"
      # text byte for byte.
      conf_level <- spec$conf_level %||% 95
      if (!is.numeric(conf_level) || length(conf_level) != 1 || !is.finite(conf_level) ||
          conf_level <= 0 || conf_level >= 100) {
        err("OS_SLOT_INVALID_VALUE",
            "conf_level must be a single number strictly between 0 and 100 (percent form, e.g. 95, 90, 99).")
      }
      conf_txt <- format(conf_level, scientific = FALSE, trim = TRUE)
      sprintf("%s%.*f (%s%% CI %s)", lbl, digits, value[1], conf_txt, fmt_ci(value[2], value[3], digits))
    },
    direction = {
      if (!is.numeric(value) || length(value) != 1) {
        err("OS_SLOT_TYPE_MISMATCH",
            "direction slots are derived from a numeric estimate, not filled with a word by hand.")
      }
      null_v <- spec$null_value %||% (if (identical(spec$scale, "diff")) 0 else 1)
      words <- spec$words %||% c("higher", "lower")
      fmt_direction_word(value, null_value = null_v, higher = words[1], lower = words[2])
    },
    pct_direction = {
      if (!is.numeric(value) || length(value) != 1) {
        err("OS_SLOT_TYPE_MISMATCH",
            "pct_direction slots are derived from a numeric ratio estimate, not filled with text by hand.")
      }
      fmt_pct_direction(value)
    })
  if (validate) return(body())
  # validate = FALSE: best-effort formatting, but never a hard stop -- a
  # template slot is exactly the place the project brief forbids "refuse to
  # compute". Fall back to a raw, clearly-a-fallback rendering.
  tryCatch(body(), error = function(e) paste(format(value), collapse = ", "))
}

#' Fill a registered template's slots and return the finished sentence(s).
#'
#' values    Named list, one entry per declared slot. See docs/
#'           report_engine.md for what shape each slot type expects
#'           (a "ci" slot wants c(lo, hi); "effect_ci" wants
#'           c(estimate, lo, hi); "direction"/"pct_direction" want a single
#'           numeric estimate, never a string).
#' validate  TRUE (default) type-checks every slot and raises OS_SLOT_* on
#'           mismatch. FALSE trades that safety for best-effort output.
fill <- function(id, values = list(), validate = TRUE) {
  tpl <- get_template(id)
  vnames <- names(values) %||% character(0)
  declared <- names(tpl$slots)

  unknown <- setdiff(vnames, declared)
  if (length(unknown)) {
    stop(sprintf("OS_SLOT_UNKNOWN: fill('%s', ...) got value(s) for undeclared slot(s): %s",
                 id, paste(unknown, collapse = ", ")), call. = FALSE)
  }
  missing_slots <- setdiff(declared, vnames)
  if (length(missing_slots)) {
    stop(sprintf("OS_SLOT_MISSING: fill('%s', ...) is missing required slot(s): %s",
                 id, paste(missing_slots, collapse = ", ")), call. = FALSE)
  }

  out <- tpl$text
  for (nm in declared) {
    txt <- .ms_format_slot(id, nm, tpl$slots[[nm]], values[[nm]], validate = validate)
    out <- gsub(sprintf("{{%s}}", nm), txt, out, fixed = TRUE)
  }
  if (grepl("{{", out, fixed = TRUE)) {
    # Should be unreachable given declare_template's checks; guarded anyway
    # because a silently half-filled sentence is worse than a loud error.
    stop(sprintf("OS_TEMPLATE_UNFILLED_SLOT: fill('%s', ...) left an unfilled placeholder in the output.", id),
         call. = FALSE)
  }
  out
}

# =============================================================================
# 3. Built-in sentence skeleton shared by every module
#
# These four cover the sentences that recur in every Methods section
# regardless of which analysis produced the numbers: what software was used,
# whether the estimates are survey-weighted, how missing data was handled,
# and what alpha was pre-specified. Modules register everything
# analysis-specific themselves, under their own id prefix (e.g. "rcs.").
# =============================================================================

.ms_declare_builtin <- function(id, text, slots) declare_template(id, text, slots, overwrite = TRUE)

.ms_declare_builtin("ms.methods.software",
  "Analyses were performed in R {{r_version}} using {{pkg_phrase}}; a two-sided {{alpha_phrase}} was considered statistically significant.",
  list(r_version = "text", pkg_phrase = "text", alpha_phrase = "text"))

.ms_declare_builtin("ms.methods.survey_weighting",
  "All estimates{{scope}} incorporate the complex survey design (sampling weights, strata, and primary sampling units), so that {{artifacts}} come from the same weighted model.",
  list(scope = list(type = "text", allow_empty = TRUE), artifacts = "text"))

.ms_declare_builtin("ms.methods.missing_data_cc",
  "Participants with missing data on {{variables}} were excluded under a complete-case approach ({{n_excluded}} of {{n_total}} participants excluded, {{pct_excluded}}).",
  list(variables = "list", n_excluded = list(type = "number", fmt = "%d"),
       n_total = list(type = "number", fmt = "%d"), pct_excluded = list(type = "number", fmt = "%.1f%%")))

.ms_declare_builtin("ms.methods.alpha",
  "A two-sided {{alpha_phrase}} was considered statistically significant.",
  list(alpha_phrase = "text"))

#' Convenience wrapper for ms.methods.software: computes r_version and
#' pkg_phrase for you so callers don't hand-format them (and risk the R
#' version string drifting from R.version at the point of writing).
software_statement <- function(packages, alpha = 0.05, r_version = NULL) {
  rv <- r_version %||% sprintf("%s.%s", R.version$major, R.version$minor)
  fill("ms.methods.software",
       list(r_version = rv, pkg_phrase = pkg_phrase(packages), alpha_phrase = alpha_phrase(alpha)))
}

#' Convenience wrapper for ms.methods.alpha.
alpha_statement <- function(alpha = 0.05) {
  fill("ms.methods.alpha", list(alpha_phrase = alpha_phrase(alpha)))
}

#' Convenience wrapper for ms.methods.missing_data_cc. n_total is the
#' pre-exclusion sample size; the excluded percentage is derived, never typed.
missing_data_statement <- function(variables, n_excluded, n_total) {
  if (!is.numeric(n_total) || length(n_total) != 1 || n_total <= 0) {
    stop("OS_INVALID_PARAMETER: missing_data_statement needs a single positive n_total.", call. = FALSE)
  }
  fill("ms.methods.missing_data_cc",
       list(variables = variables, n_excluded = n_excluded, n_total = n_total,
            pct_excluded = 100 * n_excluded / n_total))
}

#' Convenience wrapper for ms.methods.survey_weighting.
survey_weighting_statement <- function(artifacts = "the tables and figures", scope = "") {
  fill("ms.methods.survey_weighting", list(scope = scope, artifacts = artifacts))
}
