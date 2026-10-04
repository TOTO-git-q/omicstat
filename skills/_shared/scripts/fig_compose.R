# fig_compose.R -- assemble panels into one journal figure.
# ASCII only on purpose. Requires fig_style.R.
#
# Rules enforced here (docs/FIGURE_STYLE.md sec 7):
#   * panel letters: journal case (nature a,b,c / cell & science A,B,C),
#     bold 8 pt, top-left corner OUTSIDE the panel, aligned across a row;
#   * one reading direction: panels are filled row by row;
#   * > 6 panels -> OS_FIG_TOO_MANY_PANELS warning (field median is 3-5);
#   * the combined legend text is "a, <caption a> b, <caption b> ..." built
#     from each panel's own generated caption, so the legend can never
#     disagree with what is drawn.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_compose.R.", call. = FALSE)

# Top margin (in tag lines) reserved above a wrapped patchwork sub-figure.
OS_FIG_TAG_MARGIN_LINES <- 1.5

os_compose <- function(plots, ncol = NULL, widths = NULL, heights = NULL, design = NULL, title = NULL,
                       journal = NULL, collect_guides = FALSE) {
  jp <- os_journal(journal)
  n <- length(plots)
  if (n > 6) warning(sprintf("OS_FIG_TOO_MANY_PANELS: %d panels; the field median is 3-5 and > 6 usually means the figure should be split.", n), call. = FALSE)
  tags <- if (jp$tag_case == "lower") letters[seq_len(n)] else LETTERS[seq_len(n)]
  wrapped <- lapply(seq_len(n), function(i) {
    p <- plots[[i]]
    # a patchwork sub-figure (heatmap, GSEA curve) is wrapped so it takes ONE tag;
    # the wrapper gets a top margin of one tag line, otherwise the letter is
    # drawn over the sub-figure's first row (e.g. a heatmap's annotation bar)
    if (inherits(p, "patchwork")) {
      patchwork::wrap_elements(full = p) +
        ggplot2::theme(plot.margin = ggplot2::margin(t = OS_FIG$size_tag * OS_FIG_TAG_MARGIN_LINES, unit = "pt"))
    } else p
  })
  comp <- patchwork::wrap_plots(wrapped, ncol = ncol, widths = widths, heights = heights, design = design,
                                guides = if (collect_guides) "collect" else "keep")
  comp <- comp + patchwork::plot_annotation(
    title = title, tag_levels = list(tags),
    theme = ggplot2::theme(plot.title = ggplot2::element_text(size = OS_FIG$size_title + 1, face = "bold", hjust = 0,
                                                              family = os_font_family()))
  ) & ggplot2::theme(plot.tag = ggplot2::element_text(size = OS_FIG$size_tag, face = jp$tag_face, hjust = 0, vjust = 1,
                                                       family = os_font_family(), colour = OS_FIG$col_ink),
                     plot.tag.position = c(0, 1))
  caps <- vapply(seq_len(n), function(i) (attr(plots[[i]], "os_meta") %||% list())$caption %||% "", character(1))
  legend <- paste(vapply(seq_len(n), function(i) paste0(if (jp$tag_case == "lower") paste0("**", tags[i], "**,") else paste0("(", tags[i], ")"), " ", caps[i]),
                         character(1)), collapse = " ")
  panel_meta <- lapply(seq_len(n), function(i) {
    m <- attr(plots[[i]], "os_meta") %||% list()
    m$colour_registry <- NULL
    c(list(tag = tags[i]), m[setdiff(names(m), "caption")])
  })
  # A composite's own default height, so os_save_figure() does not fall back
  # to a generic width-derived height (which left a large blank canvas above
  # a short row of small panels, e.g. two 70 mm-tall PCA panels under a
  # "double"-width preset): panels are filled row by row (patchwork::wrap_plots
  # default), so the height is (number of rows) x (tallest panel in a row).
  # NULL when no panel carries its own default_height_mm, so the width-derived
  # fallback in os_save_figure still applies exactly as before.
  panel_h <- vapply(plots, function(p) (attr(p, "os_meta") %||% list())$default_height_mm %||% NA_real_, numeric(1))
  default_h <- if (all(is.na(panel_h))) NULL else {
    eff_ncol <- ncol %||% n
    rows <- ceiling(n / eff_ncol)
    ph <- ifelse(is.na(panel_h), mean(panel_h, na.rm = TRUE), panel_h)
    row_max <- vapply(split(ph, ceiling(seq_len(n) / eff_ncol)), max, numeric(1))
    sum(row_max[seq_len(rows)])
  }
  attr(comp, "os_meta") <- list(figure_type = "composite", caption = legend, default_height_mm = default_h,
                                data = list(panels = panel_meta, n_panels = n))
  comp
}

# Convenience: build, lint and save in one call. Returns the save result
# plus the lint table; blocker lint findings stop the save.
os_finalize_figure <- function(plot, out_stem, width = "single", height_mm = NULL, journal = NULL,
                               formats = c("pdf", "png"), root = NULL) {
  lint <- os_fig_lint(plot, journal)
  if (any(lint$severity == "blocker")) {
    stop("OS_FIG_LINT_BLOCKER: ", paste(lint$rule[lint$severity == "blocker"], lint$message[lint$severity == "blocker"],
                                        sep = ": ", collapse = "; "), call. = FALSE)
  }
  res <- os_save_figure(plot, out_stem, width = width, height_mm = height_mm, journal = journal,
                        formats = formats, root = root,
                        extra_meta = list(lint = if (nrow(lint)) lapply(seq_len(nrow(lint)), function(i) as.list(lint[i, ])) else list()))
  res$lint <- lint
  invisible(res)
}
