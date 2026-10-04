# render_md.R -- markdown three-line-table renderer, the fast/default path
# (docx is render_docx.R; see that file for when to reach for it instead).
# ASCII only on purpose: R on Windows with a GBK locale mangles UTF-8 source.
#
# Two layers, kept separate on purpose:
#   1. render_md_table(df, ...)   -- pure layout. Takes a data.frame whose
#      columns are already display-ready (character, or things that print
#      sensibly) and writes a GitHub-flavoured-markdown pipe table. Works on
#      ANY data.frame, not just an effect_table.R table -- this is the "any
#      data.frame" half of the brief.
#   2. format_effect_table_for_display(et, ...) -- the effect_table.R-aware
#      half. Turns the tidy numeric schema (term/level/analysis_id/estimate/
#      ci_low/ci_high/p_value/...; see effect_table.R's EFFECT_TABLE_SCHEMA)
#      into the display strings a journal table actually shows
#      ("1.02 (1.00 to 1.04)", "P = .03", "<0.001", ...), then hands the
#      result to render_md_table().
# render_docx.R sources this file for both layers rather than reimplementing
# P-value/CI formatting a second time -- the numbers must render identically
# in markdown and docx, so there is exactly one place that decides what "0.03"
# becomes.
#
# Three-line-table rules encoded here (P0-baseline-table.md section 5.1):
#   - AMA/JAMA:  italic P, no leading zero ("P = .03"); >0.01 -> 2 decimals;
#                0.01-0.001 -> 3 decimals; <0.001 -> "P < .001"; CI separated
#                by a comma.
#   - NEJM:      numerically identical to AMA (no leading zero, same decimal
#                breakpoints); differs only in the P label not being italic
#                and the CI separator being "to" instead of a comma.
#   - Lancet:    lowercase p, leading zero, 2 significant figures (not fixed
#                decimal places) above 0.01; <0.0001 -> "p < 0.0001"; CI
#                separated by "to".
#   - generic:   this suite's default when no journal is specified -- leading
#                zero, <0.001 -> "<0.001", else 2 decimals (3 when that would
#                otherwise round to 0.00), comma-separated CI. Matches the
#                common house convention used across most non-AMA biomedical
#                journals; always emits a number, never "NS" (house rule).

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

THREE_LINE_STYLES <- c("generic", "ama", "jama", "nejm", "lancet")

.canon_style <- function(style) {
  style <- match.arg(style, THREE_LINE_STYLES)
  if (style == "jama") "ama" else style
}

# ------------------------------------------------------------- P values -----

# .sigfig_str(): format x to `digits` significant figures as a fixed-point
# string with a leading zero, e.g. .sigfig_str(0.0421, 2) -> "0.042",
# .sigfig_str(0.26, 2) -> "0.26". Used for Lancet's "2 significant figures"
# rule, which is not the same thing as "2 decimal places".
.sigfig_str <- function(x, digits = 2) {
  if (!is.finite(x) || x == 0) return(formatC(0, format = "f", digits = digits))
  xr <- signif(x, digits)
  dec <- max(0, digits - floor(log10(abs(xr))) - 1)
  formatC(xr, format = "f", digits = dec)
}

# format_p(p, style): the numeric portion only, e.g. "0.03", "<0.001", ".03".
# The "P"/"p"/"*P*" label and whether it carries "=" is p_label()'s job, kept
# separate so a caller assembling a header ("P value" column) and a caller
# assembling an inline sentence ("P = .03") do not fight over the same string.
format_p <- function(p, style = "generic") {
  style <- .canon_style(style)
  vapply(p, function(pv) {
    if (is.null(pv) || is.na(pv)) return(NA_character_)
    if (pv < 0 || pv > 1) return(sprintf("%.3g (out of range)", pv))
    if (style %in% c("ama", "nejm")) {
      # NEJM is numerically identical to AMA (no leading zero, same decimal
      # breakpoints) per this file's own header comment, docs/
      # render_conventions.md's style table, and p_label("nejm")$leading_zero
      # == FALSE below -- it previously fell through to the generic branch
      # (WITH a leading zero) because .canon_style() only maps "jama" to
      # "ama", not "nejm", contradicting all three of those sources at once.
      if (pv < 0.001) return("<.001")
      s <- if (pv < 0.01) sprintf("%.3f", pv) else sprintf("%.2f", pv)
      return(sub("^0", "", s))
    }
    if (style == "lancet") {
      if (pv < 0.0001) return("<0.0001")
      return(.sigfig_str(pv, 2))
    }
    # generic: leading zero, <0.001 -> "<0.001" (see file header).
    if (pv < 0.001) return("<0.001")
    if (pv < 0.01) return(sprintf("%.3f", pv))
    sprintf("%.2f", pv)
  }, character(1))
}

# p_label(style): how the P-value COLUMN HEADER and inline label should read.
# `md` uses markdown emphasis for the styles that call for an italic P;
# render_docx.R applies the equivalent gt::md()/cell styling from the same
# table so the two outputs agree on which styles italicise it.
p_label <- function(style = "generic") {
  style <- .canon_style(style)
  switch(style,
    ama    = list(header = "*P*", inline = "*P*", leading_zero = FALSE),
    nejm   = list(header = "P",   inline = "P",   leading_zero = FALSE),
    lancet = list(header = "p",   inline = "p",   leading_zero = TRUE),
    list(header = "P", inline = "P", leading_zero = TRUE)   # generic
  )
}

ci_separator <- function(style = "generic") {
  style <- .canon_style(style)
  # AMA/JAMA and generic use a comma; NEJM and Lancet use "to" (see the style
  # table in this file's header comment and docs/render_conventions.md). Only
  # "ama" was special-cased here before -- "generic" (this suite's default
  # when no journal is specified) fell through to " to ", contradicting both
  # of those documented contracts. Fixed 2026-08-13 during Phase 0 integration
  # verification; see docs/render_conventions.md's style table for the source
  # of truth this now matches.
  if (style %in% c("ama", "generic")) ", " else " to "
}

# ------------------------------------------------------------- number fmt --

fmt_num <- function(x, digits = 2, na_string = "--") {
  vapply(x, function(v) if (is.null(v) || is.na(v)) na_string else formatC(v, format = "f", digits = digits),
        character(1))
}

# format_ci(): "1.02 (1.00 to 1.04)" style. Falls back gracefully when only
# some pieces are present (estimate alone if lower/upper are both NA;
# na_string if estimate itself is NA) rather than emitting a malformed cell.
format_ci <- function(estimate, lower = NA_real_, upper = NA_real_, digits = 2,
                       sep = ", ", na_string = "--") {
  n <- max(length(estimate), length(lower), length(upper))
  estimate <- rep_len(estimate, n); lower <- rep_len(lower, n); upper <- rep_len(upper, n)
  vapply(seq_len(n), function(i) {
    e <- estimate[i]; lo <- lower[i]; hi <- upper[i]
    if (is.na(e)) return(na_string)
    es <- formatC(e, format = "f", digits = digits)
    if (is.na(lo) || is.na(hi)) return(es)
    sprintf("%s (%s%s%s)", es, formatC(lo, format = "f", digits = digits), sep,
            formatC(hi, format = "f", digits = digits))
  }, character(1))
}

# --------------------------------------------------- generic md rendering --

# render_md_table(): pure layout. `df`'s columns should already be
# display-ready (character, or coercible sensibly by format()); this function
# does not round numbers or reinterpret P values -- that is exactly what the
# format_* functions above and format_effect_table_for_display() below are
# for. NA cells become `na_string`. Returns a character vector of lines
# (write with writeLines(), or pass `path` to have this function do it).
#
# GitHub-flavoured-markdown pipe tables are the deliberate target (route C in
# P0-baseline-table.md section 5.2: fast, diffable, no Word dependency) --
# not a literal three-rule typeset table, which markdown has no syntax for.
render_md_table <- function(df, title = NULL, footnote = NULL, na_string = "--", path = NULL) {
  if (!is.data.frame(df)) stop("OS_RENDER_INVALID_INPUT: render_md_table() needs a data.frame.", call. = FALSE)
  cells <- lapply(df, function(col) {
    if (is.character(col)) ifelse(is.na(col), na_string, col)
    else if (is.factor(col)) ifelse(is.na(col), na_string, as.character(col))
    else ifelse(is.na(col), na_string, format(col, trim = TRUE))
  })
  cells <- lapply(cells, function(v) gsub("|", "\\|", v, fixed = TRUE))  # pipe table escaping
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep(" --- ", ncol(df)), collapse = "|"), "|")
  if (nrow(df) == 0) {
    rows <- character(0)
  } else {
    rows <- vapply(seq_len(nrow(df)), function(i) {
      paste0("| ", paste(vapply(cells, `[`, character(1), i), collapse = " | "), " |")
    }, character(1))
  }
  out <- character(0)
  if (!is.null(title)) out <- c(out, paste0("**", title, "**"), "")
  out <- c(out, header, sep, rows)
  if (!is.null(footnote) && length(footnote)) out <- c(out, "", paste0(footnote, "  "))
  if (!is.null(path)) writeLines(enc2utf8(out), path, useBytes = TRUE)
  invisible(out)
}

# ------------------------------------------------- effect_table -> display --

# format_effect_table_for_display(): the effect_table.R-aware half. Builds a
# display data.frame (all character columns) from a table that passed
# validate_effect_table() -- callers that want the schema check enforced
# should call assert_effect_table() themselves first; this function trusts
# its input rather than re-validating, to keep the render layer from silently
# masking an upstream computation bug behind a formatting pass.
#
# et:           an effect_table.R-schema data.frame.
# style:        one of THREE_LINE_STYLES; controls P formatting/CI separator.
# digits:       decimal places for estimate/CI (default 2).
# effect_label: text for the estimate column header, e.g. "HR (95% CI)". When
#               NULL, inferred from et$effect_type if that column is constant
#               across all rows, else falls back to "Estimate (95% CI)".
# display_names: named character vector mapping schema columns to headers; an
#                NA entry suppresses that source column. With reader_facing,
#                supplied entries override the suite defaults.
# reader_facing: use EFFECT_TABLE_DISPLAY_NAMES when TRUE. Defaults preserve
#                the legacy display table byte-for-byte.
format_effect_table_for_display <- function(et, style = "generic", digits = 2, effect_label = NULL,
                                             display_names = NULL, reader_facing = FALSE) {
  style <- .canon_style(style)
  pl <- p_label(style); sep <- ci_separator(style)

  if (!is.null(display_names)) {
    if (!is.character(display_names) || is.null(names(display_names)) || any(!nzchar(names(display_names)))) {
      stop("OS_RENDER_INVALID_INPUT: display_names must be a named character vector.", call. = FALSE)
    }
  }
  if (isTRUE(reader_facing)) {
    if (!exists("EFFECT_TABLE_DISPLAY_NAMES", inherits = TRUE)) {
      stop("OS_MISSING_DEPENDENCY: reader_facing=TRUE requires effect_table.R to be sourced first.", call. = FALSE)
    }
    resolved_names <- EFFECT_TABLE_DISPLAY_NAMES
    if (!is.null(display_names)) resolved_names[names(display_names)] <- display_names
  } else {
    resolved_names <- display_names
  }
  display_name <- function(column, fallback) {
    if (is.null(resolved_names) || !column %in% names(resolved_names)) return(fallback)
    unname(resolved_names[[column]])
  }
  add_column <- function(df, column, fallback, value) {
    label <- display_name(column, fallback)
    if (!is.na(label)) df[[label]] <- value
    df
  }

  term_disp <- ifelse(is.na(et$level), et$term, paste0(et$term, ": ", et$level))

  ci_level_txt <- ifelse(is.na(et$ci_level), "95%", paste0(formatC(100 * et$ci_level, format = "f", digits = 0), "%"))
  if (is.null(effect_label)) {
    et_types <- unique(et$effect_type[!is.na(et$effect_type)])
    effect_label <- if (length(et_types) == 1) {
      cl <- unique(ci_level_txt); cl <- if (length(cl) == 1) cl else "95%"
      sprintf("%s (%s CI)", et_types, cl)
    } else "Estimate (95% CI)"
  }

  out <- data.frame(.display_row = term_disp, stringsAsFactors = FALSE)
  out <- add_column(out, "term", "Term", term_disp)
  out <- add_column(out, "analysis_id", "Model", et$analysis_id)
  out <- add_column(out, "estimate", effect_label,
                    format_ci(et$estimate, et$ci_low, et$ci_high, digits = digits, sep = sep))
  out <- add_column(out, "n_unweighted", "N",
                    ifelse(is.na(et$n_unweighted), "--", format(et$n_unweighted, trim = TRUE, big.mark = ",")))
  if (any(!is.na(et$n_events))) {
    out <- add_column(out, "n_events", "Events",
                      ifelse(is.na(et$n_events), "--", format(et$n_events, trim = TRUE)))
  }
  out <- add_column(out, "p_value", pl$header, format_p(et$p_value, style = style))
  if (any(!is.na(et$p_adjusted))) {
    meth <- unique(et$p_adj_method[!is.na(et$p_adj_method)])
    lbl <- if (length(meth) == 1) sprintf("%s-adjusted %s", meth, pl$header) else paste0("Adjusted ", pl$header)
    out <- add_column(out, "p_adjusted", lbl, format_p(et$p_adjusted, style = style))
  }
  if (any(!is.na(et$stratum))) out <- add_column(out, "stratum", "Stratum", ifelse(is.na(et$stratum), "--", et$stratum))
  if (any(!is.na(et$notes))) out <- add_column(out, "notes", "Notes", ifelse(is.na(et$notes), "", et$notes))
  out[[".display_row"]] <- NULL
  out
}

# render_effect_table_md(): the one-call convenience path -- format then lay
# out. `footnote` is prepended with the standard abbreviation/CI-level note
# unless `auto_footnote = FALSE`.
render_effect_table_md <- function(et, title = NULL, style = "generic", digits = 2,
                                    effect_label = NULL, footnote = NULL,
                                    auto_footnote = TRUE, path = NULL,
                                    display_names = NULL, reader_facing = FALSE) {
  disp <- format_effect_table_for_display(et, style = style, digits = digits, effect_label = effect_label,
                                          display_names = display_names, reader_facing = reader_facing)
  fn <- footnote
  if (isTRUE(auto_footnote)) {
    pl <- p_label(.canon_style(style))
    auto <- sprintf("CI = confidence interval. %s values are two-sided.", pl$header)
    fn <- if (is.null(fn)) auto else c(auto, fn)
  }
  render_md_table(disp, title = title, footnote = fn, path = path)
}
