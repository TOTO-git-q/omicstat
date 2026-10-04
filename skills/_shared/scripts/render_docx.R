# render_docx.R -- docx three-line-table renderer, the submission-ready path
# (render_md.R is the fast/default path; see that file for the P-value/CI
# formatting rules, which this file reuses rather than reimplementing).
# ASCII only on purpose: R on Windows with a GBK locale mangles UTF-8 source.
#
# Engine choice: gt::gtsave(x, "*.docx"), NOT the more commonly cited
# gtsummary -> as_flex_table() -> flextable::save_as_docx() route.
# P0-baseline-table.md section 4/5.2 tested both on this machine: gt 1.3.0
# writes a valid docx directly (11-11.2 KB test files, opens cleanly), and it
# is already a hard dependency of this suite (renderer parity with
# tableone's docx gap in that report), so building on it here avoids adding
# flextable/officer as a second table-writing stack. If gt ever regresses on
# docx export, flextable::flextable(df) |> flextable::save_as_docx() is the
# documented fallback (same report, section 4) -- swap it in inside
# render_docx_table() only; callers of this file's two public functions do
# not need to know which engine is underneath.

# This file does not self-locate and source render_md.R for you (that kind of
# commandArgs guessing breaks the moment this file is sourced from a script
# that lives in a different directory, e.g. a skill's own scripts/ folder).
# Callers must source render_md.R first:
#   source(file.path(shared_dir, "render_md.R"))
#   source(file.path(shared_dir, "render_docx.R"))
# run_rcs.R in rcs-analysis establishes the same convention for its own
# sibling scripts.
if (!exists("format_effect_table_for_display", mode = "function")) {
  stop("OS_MISSING_DEPENDENCY: render_docx.R requires render_md.R to be sourced first (source() render_md.R before render_docx.R -- they share the P-value/CI formatting logic).", call. = FALSE)
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

.require_gt <- function() {
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop("OS_MISSING_PACKAGE: the 'gt' package is required for docx rendering (install.packages('gt')).", call. = FALSE)
  }
}

# render_docx_table(): pure layout, gt-based, mirrors render_md_table()'s
# contract -- `df` should already hold display-ready values (character, or
# things format() prints sensibly); this function does not round numbers or
# reinterpret P values. Draws exactly three horizontal rules (top, below the
# column headers, bottom) and no vertical rules, per the AMA/NEJM/Lancet
# three-line convention shared across all three (P0-baseline-table.md 5.1);
# per-journal differences (comma vs "to", P italics) are already baked into
# `df` by format_effect_table_for_display() before it gets here.
#
# title:    e.g. "Table 1. Baseline characteristics by group." Rendered as a
#           bold heading row above the table (gt::tab_header title).
# footnote: character vector; each element becomes one source-note line
#           below the table.
# path:     output .docx path. Required (unlike render_md_table(), a gt
#           table object has no useful "just give me the lines" form).
render_docx_table <- function(df, title = NULL, footnote = NULL, path, na_string = "--") {
  .require_gt()
  if (!is.data.frame(df)) stop("OS_RENDER_INVALID_INPUT: render_docx_table() needs a data.frame.", call. = FALSE)
  if (missing(path) || !nzchar(path)) stop("OS_RENDER_INVALID_INPUT: render_docx_table() needs `path` (the output .docx file).", call. = FALSE)

  disp <- df
  for (cn in names(disp)) {
    col <- disp[[cn]]
    disp[[cn]] <- if (is.character(col)) ifelse(is.na(col), na_string, col)
                  else if (is.factor(col)) ifelse(is.na(col), na_string, as.character(col))
                  else ifelse(is.na(col), na_string, format(col, trim = TRUE))
  }

  g <- gt::gt(disp)
  if (!is.null(title)) g <- gt::tab_header(g, title = gt::md(paste0("**", title, "**")))
  g <- gt::tab_options(g,
    table.border.top.style = "solid", table.border.top.width = gt::px(2), table.border.top.color = "black",
    heading.border.bottom.style = "none",
    column_labels.border.top.style = "none",
    column_labels.border.bottom.style = "solid", column_labels.border.bottom.width = gt::px(1), column_labels.border.bottom.color = "black",
    table_body.border.bottom.style = "solid", table_body.border.bottom.width = gt::px(2), table_body.border.bottom.color = "black",
    table_body.hlines.style = "none",
    table.border.left.style = "none", table.border.right.style = "none",
    column_labels.vlines.style = "none", table_body.vlines.style = "none",
    table.font.size = gt::px(20), heading.title.font.size = gt::px(22)
  )
  if (!is.null(footnote) && length(footnote)) {
    for (fn in footnote) g <- gt::tab_source_note(g, source_note = gt::md(fn))
  }
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  gt::gtsave(g, path)
  invisible(path)
}

# render_effect_table_docx(): the one-call convenience path, mirroring
# render_effect_table_md() -- format_effect_table_for_display() then lay out.
# Uses the SAME formatting function render_effect_table_md() calls, so a
# Methods draft quoting a number from the .md table and the .docx table
# handed to a journal will never disagree.
render_effect_table_docx <- function(et, path, title = NULL, style = "generic", digits = 2,
                                      effect_label = NULL, footnote = NULL, auto_footnote = TRUE,
                                      display_names = NULL, reader_facing = FALSE) {
  disp <- format_effect_table_for_display(et, style = style, digits = digits, effect_label = effect_label,
                                          display_names = display_names, reader_facing = reader_facing)
  fn <- footnote
  if (isTRUE(auto_footnote)) {
    pl <- p_label(.canon_style(style))
    auto <- sprintf("CI = confidence interval. %s values are two-sided.", pl$header)
    fn <- if (is.null(fn)) auto else c(auto, fn)
  }
  render_docx_table(disp, title = title, footnote = fn, path = path)
}
