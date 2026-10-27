# fig_style.R -- omicstat shared figure style layer (tokens, theme, palettes,
# colour registry, number formatting, device/save + figure_spec.json).
# ASCII only on purpose (see docs/CONVENTIONS.md sec 2): every non-ASCII glyph
# that must appear in a figure (true minus sign, multiplication sign, en dash)
# is written as a \u escape.
#
# THIS FILE IS THE SINGLE SOURCE OF TRUTH FOR FIGURE APPEARANCE. Every omicstat
# figure function (fig_bulk.R, fig_enrich.R, fig_sc.R, fig_network.R,
# fig_heatmap.R, fig_compose.R) reads its colours, font sizes, line widths,
# point shapes, sizes and text positions from OS_FIG / os_* helpers defined
# here and NEVER hard-codes a visual constant of its own. The human-readable
# twin of this file is docs/FIGURE_STYLE.md; the two must agree (a test in
# tests/test_figures.R checks the token table in the doc against OS_FIG).
#
# Changing any token below changes every figure of every module: bump
# OS_FIG_STYLE_VERSION and follow ENGINEERING_PLAN lock 7 (render-only change:
# numeric golden tables must stay byte-identical, figures are re-registered).

suppressPackageStartupMessages({
  for (.p in c("ggplot2", "jsonlite", "digest", "grid")) {
    if (!requireNamespace(.p, quietly = TRUE)) {
      stop(sprintf("OS_MISSING_PACKAGE: fig_style.R needs the '%s' package.", .p), call. = FALSE)
    }
  }
  rm(.p)
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

OS_FIG_STYLE_VERSION <- "1.3.0"

# Figure text needs a UTF-8 character locale: under C/POSIX (the default in
# minimal containers) a true minus sign is rendered as "..." by the graphics
# devices. Switch LC_CTYPE only (collation and numbers are unaffected).
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  for (.loc in c("C.UTF-8", "en_US.UTF-8", "English_United States.utf8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", .loc)))) break
  }
  rm(.loc)
  if (!isTRUE(l10n_info()[["UTF-8"]])) {
    warning("OS_FIG_LOCALE: no UTF-8 locale available; minus signs fall back to ASCII hyphen.", call. = FALSE)
  }
}

# ---------------------------------------------------------------------------
# 1. Unit helpers
# ---------------------------------------------------------------------------
# ggplot2 linewidth is in "ggplot mm" such that lwd = linewidth * .pt and
# grid lwd 1 = 1/96 inch. os_lw(pt) converts a stroke width given in
# typographic points (1/72 inch) to a ggplot2 linewidth.
os_lw <- function(pt) pt * (96 / 72) / ggplot2::.pt
# ggplot2 geom_text/geom_label size is in mm; os_fs(pt) converts font points.
os_fs <- function(pt) pt / ggplot2::.pt
# geom_point size: ggplot2 point size is (approximately) diameter in mm for
# solid shapes 16/19/21. Kept as a named helper so every call site reads as a
# physical size.
os_pt_mm <- function(mm) mm
MM_PER_IN <- 25.4

# Characters used in figure text (ASCII source, Unicode output).
OS_MINUS <- "\u2212"   # true minus sign
OS_TIMES <- "\u00d7"   # multiplication sign
OS_NDASH <- "\u2013"   # en dash for ranges

# ---------------------------------------------------------------------------
# 2. Journal presets (physical size + label case)
# ---------------------------------------------------------------------------
# Column widths are the commonly published author-guideline values; they are
# NOT fetched at runtime. docs/FIGURE_STYLE.md sec 2 marks them "verify at
# submission". Heights are maxima for a full-page figure including panel
# labels (legend text is outside the figure).
OS_JOURNAL_PRESETS <- list(
  nature  = list(single = 89,  onehalf = 120, double = 183, max_height = 170,
                 tag_case = "lower", tag_face = "bold",
                 base_pt = 7, tick_pt = 6, min_pt = 5),
  cell    = list(single = 85,  onehalf = 114, double = 174, max_height = 225,
                 tag_case = "upper", tag_face = "bold",
                 base_pt = 7, tick_pt = 6, min_pt = 6),
  science = list(single = 57,  onehalf = 121, double = 184, max_height = 220,
                 tag_case = "upper", tag_face = "bold",
                 base_pt = 7, tick_pt = 6, min_pt = 5),
  generic = list(single = 85,  onehalf = 120, double = 180, max_height = 220,
                 tag_case = "upper", tag_face = "bold",
                 base_pt = 7, tick_pt = 6, min_pt = 5)
)
OS_DEFAULT_JOURNAL <- "nature"

os_journal <- function(journal = NULL) {
  j <- journal %||% getOption("omicstat.journal", OS_DEFAULT_JOURNAL)
  if (!j %in% names(OS_JOURNAL_PRESETS)) {
    stop(sprintf("OS_INVALID_PARAMETER: unknown journal preset '%s' (known: %s).",
                 j, paste(names(OS_JOURNAL_PRESETS), collapse = ", ")), call. = FALSE)
  }
  c(list(name = j), OS_JOURNAL_PRESETS[[j]])
}

# Resolve a width given as "single"/"onehalf"/"double" or a number in mm.
os_width_mm <- function(width, journal = NULL) {
  jp <- os_journal(journal)
  if (is.numeric(width)) return(as.numeric(width))
  if (!width %in% c("single", "onehalf", "double")) {
    stop("OS_INVALID_PARAMETER: width must be 'single', 'onehalf', 'double' or a number in mm.",
         call. = FALSE)
  }
  jp[[width]]
}

# ---------------------------------------------------------------------------
# 3. The token table (every visual constant lives here)
# ---------------------------------------------------------------------------
OS_FIG <- list(
  # --- typography (points) ---
  font_family_preference = c("Liberation Sans", "Arial", "Helvetica", "sans"),
  size_tag        = 8,    # panel letter, bold, top-left outside the panel
  size_title      = 7,    # optional panel title, plain, centred over panel
  size_axis_title = 7,    # axis titles
  size_axis_text  = 6,    # tick labels
  size_legend_title = 7,
  size_legend_text  = 6,
  size_strip      = 7,    # facet strip text (no strip background)
  size_annot      = 6,    # in-panel annotation (counts, NES/padj text)
  size_label      = 5.5,  # data labels (gene symbols, term labels in-plot)
  size_min        = 5,    # nothing may be rendered smaller than this

  # --- strokes (points) ---
  lw_axis      = 0.5,     # axis lines and tick marks
  lw_data      = 0.75,    # data lines (curves, running ES)
  lw_ref       = 0.5,     # reference / threshold lines
  lw_segment   = 0.25,    # label leader lines, heatmap cell borders, hit ticks
  lw_point_edge = 0.25,   # outline of fillable sample-level points
  lw_box       = 0.5,     # box / violin outline
  ref_linetype = "22",    # dashed: 2 units on, 2 off
  tick_len_mm  = 1.0,     # outward ticks

  # --- points ---
  pt_dense_mm   = 0.6,    # per-feature points (volcano, MA): shape 16, no edge
  pt_cell_mm    = 0.3,    # per-cell points on embeddings: shape 16, no edge
  pt_sample_mm  = 2.2,    # per-sample points (PCA, dot-strip): shape 21 + edge
  pt_highlight_mm = 0.9,  # labelled/highlighted features
  shape_dense   = 16,
  shape_sample_sequence = c(21, 24, 22, 23, 25),  # circle, triangle-up, square, diamond, triangle-down
  shape_capped  = 17,     # value beyond axis limit, drawn at the limit

  # --- neutral colours ---
  col_ink       = "#000000",  # all text, axis lines, ticks
  col_ref       = "#7F7F7F",  # reference / threshold lines
  col_ns        = "#BDBDBD",  # not significant / background features
  col_na        = "#D9D9D9",  # missing / unassigned
  col_reference_group = "#666666", # reference (control) level of a condition
  col_point_edge = "#FFFFFF", # outline of fillable points
  col_segment   = "#4D4D4D",  # label leader lines
  col_bg        = "#FFFFFF",

  # --- direction semantics (fixed across ALL figures) ---
  col_up        = "#B2182B",  # up-regulated / positive NES / positive correlation
  col_down      = "#2166AC",  # down-regulated / negative NES / negative correlation

  # --- layout ---
  legend_key_mm = 3,
  plot_margin_mm = c(2, 2, 2, 2),     # t, r, b, l
  label_wrap_chars = 40,              # wrap long term names
  max_categories = 23,                # hard ceiling for a categorical palette
  max_semantic_colours_panel = 6,     # lint threshold per panel (excl. neutrals)
  png_dpi = 600,
  raster_threshold_points = 50000,    # above this, point layers are rasterised (ggrastr)
  raster_dpi = 600,                   # resolution of a rasterised point layer

  # --- P value display (sec 15; docs/FIGURE_STYLE.md sec 16) ---
  # Stars: p < 0.05 "*", p < 0.01 "**", p < 0.001 "***", p < 0.0001 "****",
  # otherwise "ns". Intervals are STRICT (p exactly 0.05 is "ns"), the
  # ggsignif convention, not the right-closed symnum convention of rstatix.
  p_star_cutpoints  = c(0.05, 0.01, 0.001, 0.0001),
  p_star_symbols    = c("*", "**", "***", "****"),
  p_star_ns         = "ns",
  p_star_rule       = "p < cutpoint",
  p_display_default = "adjusted",     # figures show multiplicity-adjusted P unless told otherwise

  # --- n on figures (sec 16) ---
  n_units = c("samples", "cells", "features", "gene sets"),

  # --- colour-vision lint FIG-03 (sec 17) ---
  cvd_simulations    = c("deutan", "protan", "tritan"),  # Machado et al. 2009
  cvd_severity       = 1,
  cvd_delta_e_metric = "CIEDE2000",
  cvd_delta_e_min    = 10             # pairs of category colours closer than this are flagged
)

# ---------------------------------------------------------------------------
# 4. Palettes
# ---------------------------------------------------------------------------
# Condition / group levels (<= 8): Okabe-Ito order, colour-blind safe. The
# reference (control) level ALWAYS takes col_reference_group (dark grey) so the
# treated levels carry the colour -- "colour what matters, grey the rest".
OS_PAL_GROUP <- c("#D55E00", "#0072B2", "#009E73", "#E69F00", "#CC79A7", "#56B4E9", "#F0E442")

# Clusters / cell types / modules (<= 23): Okabe-Ito, then Paul Tol muted,
# then Kelly contrast colours; greys excluded (reserved for NS / NA).
OS_PAL_CATEGORY <- c(
  "#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9",
  "#882255", "#44AA99", "#332288", "#999933", "#AA4499", "#117733",
  "#CC6677", "#DDCC77", "#88CCEE", "#BE0032", "#8DB600", "#654522",
  "#F99379", "#604E97", "#C2B280", "#2B3D26", "#F0E442"
)

# Diverging (z-score, correlation, NES, log2FC colour scales): ColorBrewer
# RdBu, blue = low / negative, white = 0, red = high / positive. Endpoints
# equal col_down / col_up so a "blue" gene is the same blue everywhere.
OS_PAL_DIVERGING <- c("#2166AC", "#4393C3", "#92C5DE", "#D1E5F0", "#F7F7F7",
                      "#FDDBC7", "#F4A582", "#D6604D", "#B2182B")

# Sequential magnitude (-log10 adjusted P, AUC, density): viridis, stored as
# literal hex so the palette cannot drift with the viridisLite version.
OS_PAL_SEQUENTIAL <- c("#440154", "#482878", "#3E4A89", "#31688E", "#26828E",
                       "#1F9E89", "#35B779", "#6DCD59", "#B4DE2C", "#FDE725")

# Expression on embeddings / dot plots: light grey -> deep purple, so cells
# with zero expression recede into the background.
OS_PAL_EXPRESSION <- c("#E5E5E5", "#CBC9E2", "#9E9AC8", "#756BB1", "#54278F", "#3F007D")

# Sample-distance heatmap (DESeq2 vignette convention): dark blue = close.
OS_PAL_DISTANCE <- c("#08306B", "#08519C", "#2171B5", "#4292C6", "#6BAED6",
                     "#9ECAE1", "#C6DBEF", "#DEEBF7", "#F7FBFF")

# Mutation classes (oncoplot). Fixed mapping; unknown classes -> col_na.
OS_PAL_MUTATION <- c(
  Missense_Mutation      = "#1B9E77",
  Nonsense_Mutation      = "#D95F02",
  Frame_Shift_Del        = "#7570B3",
  Frame_Shift_Ins        = "#E7298A",
  In_Frame_Del           = "#66A61E",
  In_Frame_Ins           = "#E6AB02",
  Splice_Site            = "#A6761D",
  Translation_Start_Site = "#666666",
  Nonstop_Mutation       = "#1F78B4",
  Multi_Hit              = "#000000"
)

# Condition colours: reference level grey, others Okabe-Ito in level order.
os_group_colours <- function(levels, reference = NULL) {
  levels <- as.character(levels)
  if (anyDuplicated(levels)) stop("OS_INVALID_PARAMETER: duplicated group levels.", call. = FALSE)
  others <- setdiff(levels, reference %||% character(0))
  if (length(others) > length(OS_PAL_GROUP)) {
    stop(sprintf("OS_TOO_MANY_CATEGORIES: %d non-reference groups; the group palette holds %d. ",
                 length(others), length(OS_PAL_GROUP)),
         "Use facets or the category palette.", call. = FALSE)
  }
  out <- stats::setNames(OS_PAL_GROUP[seq_along(others)], others)
  if (!is.null(reference)) {
    if (!reference %in% levels) {
      stop(sprintf("OS_INVALID_PARAMETER: reference level '%s' not among groups.", reference), call. = FALSE)
    }
    out <- c(stats::setNames(OS_FIG$col_reference_group, reference), out)
  }
  out[levels]
}

# ---------------------------------------------------------------------------
# 5. Colour registry -- the same entity keeps the same colour in every figure
#    of an analysis chain (clusters, cell types, conditions, modules).
# ---------------------------------------------------------------------------
# The registry is a JSON file {"schema":"omicstat.colour-registry.v1",
# "families": {"celltype": {"B cell":"#0072B2", ...}, ...}}. Modules write it
# to objects/colour_registry.json and downstream modules read it via
# --from-run, so a "B cell" that was blue in the UMAP is blue in the
# proportion bar, the marker dot plot and the pseudobulk heatmap annotation.
# Assignment rule for new values: sorted (C-locale) new values take the
# next unused palette colours in palette order. Existing entries never move.
os_colour_registry_new <- function() {
  list(schema = "omicstat.colour-registry.v1", families = list())
}

os_colour_registry_read <- function(path) {
  if (is.null(path) || !file.exists(path)) return(os_colour_registry_new())
  reg <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(reg$schema, "omicstat.colour-registry.v1")) {
    stop("OS_SCHEMA_INVALID: colour registry has an unknown schema tag.", call. = FALSE)
  }
  reg$families <- lapply(reg$families, function(f) unlist(f))
  reg
}

os_colour_registry_write <- function(reg, path) {
  fam <- lapply(reg$families, function(f) as.list(f[order(names(f), method = "radix")]))
  fam <- fam[order(names(fam), method = "radix")]
  out <- list(schema = reg$schema, families = fam)
  if (!is.null(reg$styles)) out$styles <- reg$styles
  writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, pretty = TRUE), path, useBytes = TRUE)
  invisible(path)
}

# Returns list(colours = named chr, registry = updated registry).
os_colours_for <- function(values, family = "category", registry = NULL,
                           palette = NULL, reference = NULL) {
  registry <- registry %||% os_colour_registry_new()
  vals <- unique(as.character(values[!is.na(values)]))
  have <- registry$families[[family]] %||% stats::setNames(character(0), character(0))
  if (identical(family, "group")) {
    if (length(have) == 0) {
      lv <- if (!is.null(reference)) c(reference, sort(setdiff(vals, reference), method = "radix")) else vals
      have <- os_group_colours(lv, reference = reference)
    }
    palette <- palette %||% OS_PAL_GROUP
  } else {
    palette <- palette %||% OS_PAL_CATEGORY
  }
  new_vals <- sort(setdiff(vals, names(have)), method = "radix")
  if (length(new_vals)) {
    free <- setdiff(palette, unname(have))
    if (length(new_vals) > length(free)) {
      stop(sprintf(paste0("OS_TOO_MANY_CATEGORIES: family '%s' needs %d more colours but only %d ",
                          "remain in a %d-colour palette. Merge small categories or facet."),
                   family, length(new_vals), length(free), length(palette)), call. = FALSE)
    }
    have <- c(have, stats::setNames(free[seq_along(new_vals)], new_vals))
  }
  registry$families[[family]] <- have
  list(colours = have[vals], registry = registry)
}

# ---------------------------------------------------------------------------
# 6. Fonts
# ---------------------------------------------------------------------------
os_font_family <- function() {
  forced <- getOption("omicstat.font")
  if (!is.null(forced)) return(forced)
  have <- tryCatch(unique(systemfonts::system_fonts()$family), error = function(e) character(0))
  for (f in OS_FIG$font_family_preference) if (f %in% have) return(f)
  "sans"
}

# ---------------------------------------------------------------------------
# 7. Number / label formatting (true minus, no trailing zeros, P values)
# ---------------------------------------------------------------------------
os_num <- function(x, digits = NULL, big.mark = ",") {
  vapply(seq_along(x), function(i) {
    if (is.na(x[i])) return("")
    s <- if (is.null(digits)) format(x[i], trim = TRUE, big.mark = big.mark, scientific = FALSE, drop0trailing = TRUE)
         else formatC(x[i], format = "f", digits = digits, big.mark = big.mark)
    if (isTRUE(l10n_info()[["UTF-8"]])) sub("^-", OS_MINUS, s) else s
  }, character(1))
}
# Axis label function for ggplot scales: true minus sign, no trailing zeros.
os_axis_labels <- function(x) os_num(signif(x, 6))
os_axis_labels_pct <- function(x) paste0(os_num(signif(100 * x, 6)))

# P value text for in-figure annotation (plotmath string). <1e-3 uses
# a x 10^b notation with 2 significant digits; otherwise 2 significant digits.
os_p_plotmath <- function(p, symbol = "italic(P)", adjusted = FALSE) {
  lab <- if (adjusted) paste0("\"adj. \"*", symbol) else symbol
  if (is.na(p)) return(paste0(lab, "~\"= NA\""))
  if (p < 1e-300) return(paste0(lab, "<", "10^-300"))
  if (p < 1e-3) {
    e <- floor(log10(p)); m <- signif(p / 10^e, 2)
    if (m >= 10) { m <- m / 10; e <- e + 1 }
    return(sprintf("%s==\"%s \u00d7 \"*10^%d", lab, format(m, nsmall = 1), e))
  }
  sprintf("%s==\"%s\"", lab, formatC(signif(p, 2), format = "fg", digits = 2, flag = "#"))
}
# Plain-text version for captions.
os_p_text <- function(p) {
  if (is.na(p)) return("NA")
  if (p < 1e-300) return("< 1e-300")
  if (p < 1e-3) {
    e <- floor(log10(p)); m <- signif(p / 10^e, 2)
    if (m >= 10) { m <- m / 10; e <- e + 1 }
    return(sprintf("%s %s 10^%s", format(m, nsmall = 1), OS_TIMES, sub("^-", OS_MINUS, as.character(e))))
  }
  formatC(signif(p, 2), format = "fg", digits = 2, flag = "#")
}

# Canonical axis titles (plotmath). Every module uses these, never its own.
OS_AXIS <- list(
  log2fc      = quote(log[2]*" fold change"),
  log2cpm     = quote(log[2]*" counts per million"),
  neglog10padj = quote("\u2212"*log[10]*"(adjusted "*italic(P)*")"),
  neglog10p   = quote("\u2212"*log[10]*italic(P)),
  log10mean   = quote(log[10]*"(mean normalized count)"),
  generatio   = "Gene ratio",
  nes         = "Normalized enrichment score",
  running_es  = "Enrichment score",
  ranked_metric = "Ranked list metric",
  umap1 = "UMAP 1", umap2 = "UMAP 2",
  tsne1 = "t-SNE 1", tsne2 = "t-SNE 2",
  prop_cells = "Proportion of cells (%)",
  zscore     = "Row z-score",
  correlation = "Pearson r"
)

# Wrap long labels (pathway terms) at word boundaries.
os_wrap <- function(x, width = OS_FIG$label_wrap_chars) {
  vapply(as.character(x), function(s) paste(strwrap(s, width = width), collapse = "\n"), character(1),
         USE.NAMES = FALSE)
}

# Reject non-Latin text inside figures (CJK etc. render as empty boxes with
# the journal fonts). Latin-1 supplement and a few typographic symbols pass.
os_assert_latin <- function(x, where = "figure text") {
  x <- enc2utf8(as.character(x[!is.na(x)]))
  bad <- x[grepl("(*UTF8)[^\\x{0009}-\\x{024F}\\x{2012}-\\x{2015}\\x{2212}\\x{2264}\\x{2265}\\x{00B1}\\x{00D7}\\x{03B1}-\\x{03C9}\\x{0391}-\\x{03A9}\\x{2070}-\\x{209F}]",
                 x, perl = TRUE)]
  if (length(bad)) {
    stop(sprintf("OS_FIG_NON_LATIN_TEXT: %s contains characters the figure font cannot render: %s. ",
                 where, paste(utils::head(unique(bad), 3), collapse = " | ")),
         "Text inside figures must be English.", call. = FALSE)
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# 8. ggplot2 theme
# ---------------------------------------------------------------------------
theme_omicstat <- function(journal = NULL, family = NULL, legend = c("right", "top", "bottom", "none"),
                           axes = c("L", "none", "box", "track")) {
  legend <- match.arg(legend); axes <- match.arg(axes)
  jp <- os_journal(journal)
  fam <- family %||% os_font_family()
  ink <- OS_FIG$col_ink
  el_line <- ggplot2::element_line(colour = ink, linewidth = os_lw(OS_FIG$lw_axis), lineend = "square")
  th <- ggplot2::theme_classic(base_size = jp$base_pt, base_family = fam) +
    ggplot2::theme(
      text              = ggplot2::element_text(colour = ink, size = jp$base_pt, family = fam),
      plot.background   = ggplot2::element_rect(fill = OS_FIG$col_bg, colour = NA),
      panel.background  = ggplot2::element_rect(fill = OS_FIG$col_bg, colour = NA),
      panel.grid        = ggplot2::element_blank(),
      axis.line         = el_line,
      axis.ticks        = el_line,
      axis.ticks.length = grid::unit(OS_FIG$tick_len_mm, "mm"),
      axis.title        = ggplot2::element_text(size = OS_FIG$size_axis_title, colour = ink),
      axis.title.x      = ggplot2::element_text(margin = ggplot2::margin(t = 1.5, unit = "mm")),
      axis.title.y      = ggplot2::element_text(angle = 90, margin = ggplot2::margin(r = 1.5, unit = "mm")),
      axis.text         = ggplot2::element_text(size = OS_FIG$size_axis_text, colour = ink),
      axis.text.x       = ggplot2::element_text(margin = ggplot2::margin(t = 0.8, unit = "mm")),
      axis.text.y       = ggplot2::element_text(margin = ggplot2::margin(r = 0.8, unit = "mm")),
      legend.position   = legend,
      legend.justification = "top",
      legend.background = ggplot2::element_blank(),
      legend.key        = ggplot2::element_blank(),
      legend.key.size   = grid::unit(OS_FIG$legend_key_mm, "mm"),
      legend.title      = ggplot2::element_text(size = OS_FIG$size_legend_title),
      legend.text       = ggplot2::element_text(size = OS_FIG$size_legend_text),
      legend.spacing    = grid::unit(1.5, "mm"),
      legend.margin     = ggplot2::margin(0, 0, 0, 0),
      legend.box.spacing = grid::unit(1.5, "mm"),
      strip.background  = ggplot2::element_blank(),
      strip.text        = ggplot2::element_text(size = OS_FIG$size_strip, colour = ink,
                                                margin = ggplot2::margin(b = 1, t = 1, unit = "mm")),
      plot.title        = ggplot2::element_text(size = OS_FIG$size_title, face = "plain", hjust = 0.5,
                                                margin = ggplot2::margin(b = 1.5, unit = "mm")),
      plot.title.position = "panel",
      plot.tag          = ggplot2::element_text(size = OS_FIG$size_tag, face = jp$tag_face,
                                                hjust = 0, vjust = 1),
      plot.tag.position = c(0, 1),
      plot.margin       = ggplot2::margin(OS_FIG$plot_margin_mm[1], OS_FIG$plot_margin_mm[2],
                                          OS_FIG$plot_margin_mm[3], OS_FIG$plot_margin_mm[4], unit = "mm")
    )
  if (axes == "none") {
    blank <- ggplot2::element_blank()
    th <- th + ggplot2::theme(axis.line = blank, axis.ticks = blank, axis.text = blank,
                              axis.text.x = blank, axis.text.y = blank, axis.title = blank,
                              axis.title.x = blank, axis.title.y = blank)
  } else if (axes == "track") {
    # a bare framed strip (GSEA hit track): frame only, no text, no ticks
    blank <- ggplot2::element_blank()
    th <- th + ggplot2::theme(axis.line = blank, axis.ticks = blank, axis.text = blank,
                              axis.text.x = blank, axis.text.y = blank, axis.title = blank,
                              axis.title.x = blank, axis.title.y = blank,
                              panel.border = ggplot2::element_rect(fill = NA, colour = ink,
                                                                   linewidth = os_lw(OS_FIG$lw_axis)))
  } else if (axes == "box") {
    th <- th + ggplot2::theme(axis.line = ggplot2::element_blank(),
                              panel.border = ggplot2::element_rect(fill = NA, colour = ink,
                                                                   linewidth = os_lw(OS_FIG$lw_axis)))
  }
  th
}

# Standard legend guides (shared so key sizes / title positions never differ).
os_guide_colourbar <- function(title) {
  ggplot2::guide_colourbar(title = title, title.position = "top", title.hjust = 0,
                           barwidth = grid::unit(OS_FIG$legend_key_mm * 0.8, "mm"),
                           barheight = grid::unit(OS_FIG$legend_key_mm * 5, "mm"),
                           ticks.colour = OS_FIG$col_ink, frame.colour = OS_FIG$col_ink,
                           frame.linewidth = os_lw(OS_FIG$lw_segment), ticks.linewidth = os_lw(OS_FIG$lw_segment))
}
os_guide_legend <- function(title, ncol = 1, override = NULL) {
  ggplot2::guide_legend(title = title, title.position = "top", title.hjust = 0, ncol = ncol,
                        override.aes = override %||% list())
}

# ---------------------------------------------------------------------------
# 9. Reference / threshold line layers (always drawn UNDER the data)
# ---------------------------------------------------------------------------
os_vline <- function(x) ggplot2::geom_vline(xintercept = x, colour = OS_FIG$col_ref,
                                            linewidth = os_lw(OS_FIG$lw_ref), linetype = OS_FIG$ref_linetype)
os_hline <- function(y) ggplot2::geom_hline(yintercept = y, colour = OS_FIG$col_ref,
                                            linewidth = os_lw(OS_FIG$lw_ref), linetype = OS_FIG$ref_linetype)

# Symmetric "nice" limit for a signed quantity (log2FC, NES, z).
os_sym_limit <- function(x, min_abs = 1) {
  m <- max(abs(x[is.finite(x)]), min_abs, na.rm = TRUE)
  step <- if (m <= 2) 0.5 else if (m <= 5) 1 else if (m <= 12) 2 else 5
  ceiling(m / step) * step
}

# ---------------------------------------------------------------------------
# 10. Save: PDF (vector, fonts embedded) + PNG (600 dpi) [+ SVG] + figure_spec
# ---------------------------------------------------------------------------
# figure_spec.json records exactly what was drawn: style version, preset,
# physical size, resolved font, every colour mapping used, thresholds, the
# source table and the rows used, counts, capped points and the generated
# legend text. It contains NO timestamps and NO absolute paths so it is
# byte-identical across reruns (golden tier "byte").
.os_sha256_file <- function(path) digest::digest(file = path, algo = "sha256")

# cairo PDF writes /CreationDate and /ModDate. Overwrite them in place with a
# fixed string of identical length so xref offsets stay valid and the PDF is
# byte-reproducible.
.os_pdf_normalize_dates <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  for (key in c("/CreationDate", "/ModDate")) {
    prefix <- charToRaw(paste0(key, " (D:"))
    starts <- grepRaw(prefix, raw, fixed = TRUE, all = TRUE)
    for (st in starts) {
      body_start <- st + length(prefix)
      close_rel <- which(raw[body_start:min(length(raw), body_start + 64)] == charToRaw(")"))[1]
      if (is.na(close_rel) || close_rel <= 1) next
      body_len <- close_rel - 1
      fixed <- substr(paste0("20000101000000Z", strrep("0", 64)), 1, body_len)
      raw[body_start:(body_start + body_len - 1)] <- charToRaw(fixed)
    }
  }
  writeBin(raw, path)
  invisible(path)
}

# Canonical PDF content hash. cairo >= 1.17 writes /CreationDate inside a
# COMPRESSED object stream (so it cannot be patched in place) and ignores
# SOURCE_DATE_EPOCH. ENGINEERING_PLAN 3.5 declares PDF timestamps an exempt
# non-deterministic field; we therefore record, for PDFs, the sha256 of all
# inflated stream contents (fonts, drawing operators, object streams) with
# the dates masked and the xref stream (byte offsets) excluded. Two PDFs with
# the same content_sha256 draw exactly the same page.
os_pdf_content_sha256 <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  st <- grepRaw("stream\n", raw, fixed = TRUE, all = TRUE)
  en <- grepRaw("endstream", raw, fixed = TRUE, all = TRUE)
  parts <- list()
  for (s in st) {
    if (s > 3 && identical(rawToChar(raw[(s - 3):(s - 1)]), "end")) next
    dict <- rawToChar(raw[max(1, s - 400):(s - 1)][raw[max(1, s - 400):(s - 1)] != as.raw(0)])
    dict <- sub("^.*<<", "<<", dict, useBytes = TRUE)
    if (grepl("/XRef", dict, fixed = TRUE, useBytes = TRUE)) next
    b <- s + 7; e <- en[en > b][1]
    if (is.na(e)) next
    seg <- raw[b:(e - 1)]
    dec <- tryCatch(memDecompress(seg, type = "gzip"), error = function(err) seg)
    if (length(grepRaw("Date (D:", dec, fixed = TRUE))) {
      txt <- rawToChar(dec[dec != as.raw(0)])
      txt <- gsub("/(CreationDate|ModDate) \\(D:[^)]*\\)", "/\\1 (masked)", txt, useBytes = TRUE)
      dec <- charToRaw(txt)
    }
    parts[[length(parts) + 1]] <- dec
  }
  digest::digest(unlist(parts), algo = "sha256", serialize = FALSE)
}

.os_rel <- function(path, root) {
  if (is.null(root) || is.null(path)) return(basename(path %||% ""))
  p <- normalizePath(path, winslash = "/", mustWork = FALSE)
  r <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (startsWith(p, paste0(r, "/"))) substring(p, nchar(r) + 2) else basename(p)
}

# Deterministic JSON (sorted keys at every level, fixed digits).
.os_sort_keys <- function(x) {
  if (is.list(x) && !is.null(names(x)) && all(nzchar(names(x)))) {
    x <- x[order(names(x), method = "radix")]
    lapply(x, .os_sort_keys)
  } else if (is.list(x)) {
    lapply(x, .os_sort_keys)
  } else x
}
os_write_json <- function(x, path, digits = I(10)) {
  js <- jsonlite::toJSON(.os_sort_keys(x), auto_unbox = TRUE, pretty = TRUE, digits = digits,
                         null = "null", na = "null")
  con <- file(path, open = "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(js, "\n"))), con)
  invisible(path)
}

# A typed definition is a complete validated value, never a recursive patch.
# modifyList's default NULL deletion would otherwise erase explicit unknowns.
.os_merge_figure_meta <- function(old, incoming) {
  old_typed <- !is.null(old$definition$semantic_version)
  replaces_definition <- "definition" %in% names(incoming)
  new_typed <- !is.null(incoming$definition$semantic_version)
  if (old_typed && replaces_definition && !new_typed)
    stop("OS_INVALID_INPUT: metadata cannot erase or partially replace a typed semantic contract.", call. = FALSE)
  if (new_typed) {
    if (!exists("os_validate_figure_definition", mode = "function"))
      stop("OS_MISSING_DEPENDENCY: load fig_semantics.R for typed figure metadata.", call. = FALSE)
    os_validate_figure_definition(incoming$definition)
    definition <- incoming$definition
    incoming$definition <- NULL
    result <- utils::modifyList(old, incoming)
    result["definition"] <- list(definition)
    return(result)
  }
  matrix_contract <- incoming$definition$matrix_contract
  de_contract <- incoming$definition$de_contract
  panel_contract <- incoming$notes$panel_contract
  if (!is.null(old$definition$de_contract) && replaces_definition &&
      (is.null(incoming$definition) || ("de_contract" %in% names(incoming$definition) && is.null(de_contract))))
    stop("OS_INVALID_INPUT: metadata cannot erase a DE contract.", call. = FALSE)
  if (!is.null(de_contract)) {
    if (!identical(de_contract$version, "omicstat.de-semantics.v1") ||
        !all(c("source_sha256", "source_ids", "test", "effect", "statistic", "thresholds", "colour_decision", "source_values", "decisions") %in% names(de_contract)))
      stop("OS_INVALID_INPUT: a DE contract replacement must be complete.", call. = FALSE)
    if (exists(".os_de_validate_test", mode = "function")) .os_de_validate_test(de_contract$test)
    incoming$definition$de_contract <- NULL
  }
  if (!is.null(old$definition$matrix_contract) && replaces_definition &&
      (is.null(incoming$definition) || ("matrix_contract" %in% names(incoming$definition) && is.null(matrix_contract))))
    stop("OS_INVALID_INPUT: metadata cannot erase a matrix contract.", call. = FALSE)
  if (!is.null(matrix_contract)) {
    if (!identical(matrix_contract$version, "omicstat.matrix-semantics.v1") ||
        !all(c("source_sha256", "normalization", "original_row_ids", "original_col_ids", "matrix_kind", "quantity", "unit") %in% names(matrix_contract)))
      stop("OS_INVALID_INPUT: a matrix contract replacement must be complete.", call. = FALSE)
    incoming$definition$matrix_contract <- NULL
  }
  if (!is.null(panel_contract)) {
    if (exists(".os_validate_panel_contract", mode = "function")) .os_validate_panel_contract(panel_contract)
    incoming$notes$panel_contract <- NULL
  }
  result <- utils::modifyList(old, incoming)
  if (!is.null(matrix_contract)) result$definition["matrix_contract"] <- list(matrix_contract)
  if (!is.null(de_contract)) result$definition["de_contract"] <- list(de_contract)
  if (!is.null(panel_contract)) result$notes["panel_contract"] <- list(panel_contract)
  result
}

# plot: a ggplot / patchwork object carrying attr "os_meta" (set by every
# fig_* builder) -- a list with at least figure_type and caption.
# out_stem: path without extension. width: "single"/"onehalf"/"double"/mm.
os_save_figure <- function(plot, out_stem, width = "single", height_mm = NULL, journal = NULL,
                           formats = c("pdf", "png"), root = NULL, extra_meta = NULL) {
  jp <- os_journal(journal)
  w <- os_width_mm(width, jp$name)
  meta <- attr(plot, "os_meta") %||% list()
  candidate_meta <- if (is.null(extra_meta)) meta else .os_merge_figure_meta(meta, extra_meta)
  if (!is.null(meta$definition$semantic_version) && is.null(candidate_meta$definition$semantic_version))
    stop("OS_INVALID_INPUT: extra_meta cannot erase a typed semantic contract.", call. = FALSE)
  if (!is.null(candidate_meta$definition$semantic_version)) {
    if (!exists("os_semantic_metadata", mode = "function")) stop("OS_MISSING_DEPENDENCY: load fig_semantics.R for typed figure metadata.", call. = FALSE)
    meta <- os_semantic_metadata(candidate_meta)
  }
  h <- height_mm %||% meta$default_height_mm %||% round(w * 0.8)
  if (h > jp$max_height) {
    stop(sprintf("OS_FIG_TOO_TALL: %.0f mm exceeds the %s maximum figure height of %d mm; split the figure.",
                 h, jp$name, jp$max_height), call. = FALSE)
  }
  fam <- os_font_family()
  # Row-label legibility: a labelled heatmap needs >= 1 label height per row.
  if (isTRUE(meta$data$show_row_labels) && is.numeric(meta$data$n_rows)) {
    mm_per_row <- (h - 25) / meta$data$n_rows
    need <- os_journal(journal)$min_pt * 25.4 / 72 * 1.1
    if (mm_per_row < need) {
      warning(sprintf(paste0("OS_FIG_ROW_LABELS_CROWDED: %d labelled rows in %.0f mm (%.2f mm per row, %.2f needed). ",
                             "Increase height_mm, show fewer rows, or hide row labels."),
                      meta$data$n_rows, h, mm_per_row, need), call. = FALSE)
    }
  }
  if (isTRUE(meta$data$show_col_labels) && is.numeric(meta$data$n_cols)) {
    mm_per_col <- (w - 45) / meta$data$n_cols
    need <- os_journal(journal)$min_pt * 25.4 / 72 * 1.1
    if (mm_per_col < need) {
      warning(sprintf("OS_FIG_COL_LABELS_CROWDED: %d labelled columns in %.0f mm; widen the figure or hide column labels.",
                      meta$data$n_cols, w), call. = FALSE)
    }
  }
  dir.create(dirname(out_stem), recursive = TRUE, showWarnings = FALSE)
  prepared_draw <- if (exists(".os_restyle_export",mode="function")) .os_restyle_export(plot,out_stem,root,candidate_meta) else NULL
  files <- list()
  # Render on an opened device; always close it, and delete the partial file
  # if drawing failed (a half-written PDF must never look like an output).
  .render <- function(f, open_dev) {
    open_dev()
    dev <- grDevices::dev.cur()
    ok <- FALSE
    tryCatch({ print(plot); ok <- TRUE }, finally = {
      if (grDevices::dev.cur() == dev) grDevices::dev.off()
      if (!ok && file.exists(f)) unlink(f)
    })
    f
  }
  if ("pdf" %in% formats) {
    f <- paste0(out_stem, ".pdf")
    .render(f, function() grDevices::cairo_pdf(f, width = w / MM_PER_IN, height = h / MM_PER_IN, family = fam, bg = "white"))
    .os_pdf_normalize_dates(f)
    files$pdf <- f
  }
  if ("png" %in% formats) {
    f <- paste0(out_stem, ".png")
    .render(f, function() {
      if (requireNamespace("ragg", quietly = TRUE)) {
        ragg::agg_png(f, width = w, height = h, units = "mm", res = OS_FIG$png_dpi, background = "white")
      } else {
        grDevices::png(f, width = w, height = h, units = "mm", res = OS_FIG$png_dpi, type = "cairo", bg = "white")
      }
    })
    files$png <- f
  }
  if ("svg" %in% formats) {
    if (!requireNamespace("svglite", quietly = TRUE)) stop("OS_MISSING_PACKAGE: svglite needed for svg output.", call. = FALSE)
    f <- paste0(out_stem, ".svg")
    .render(f, function() svglite::svglite(f, width = w / MM_PER_IN, height = h / MM_PER_IN, bg = "white"))
    files$svg <- f
  }
  spec <- list(
    schema = "omicstat.figure-spec.v1",
    style_version = OS_FIG_STYLE_VERSION,
    figure_type = meta$figure_type %||% "unknown",
    journal = jp$name,
    width_mm = w, height_mm = h,
    font_family = fam,
    png_dpi = OS_FIG$png_dpi,
    files = lapply(files, function(f) {
      if (grepl("\\.pdf$", f)) list(path = .os_rel(f, root), content_sha256 = os_pdf_content_sha256(f),
                                    exempt = "CreationDate (ENGINEERING_PLAN 3.5)")
      else list(path = .os_rel(f, root), sha256 = .os_sha256_file(f))
    }),
    caption = meta$caption %||% "",
    encodings = meta$encodings %||% list(),
    data = meta$data %||% list(),
    thresholds = meta$thresholds %||% list(),
    counts = meta$counts %||% list(),
    notes = meta$notes %||% list()
  )
  # Optional: written definitions of what is drawn (selection rule, ordering,
  # gene ratio, mean expression, ...). Present only when a builder sets it.
  if (!is.null(meta$definition)) spec$definition <- meta$definition
  if (!is.null(meta$evidence_refs)) spec$evidence_refs <- meta$evidence_refs
  if (!is.null(extra_meta)) spec <- .os_merge_figure_meta(spec, extra_meta)
  if (!is.null(spec$definition$semantic_version)) spec <- os_semantic_metadata(spec)
  if (!is.null(prepared_draw)) spec$restyle <- prepared_draw
  spec_path <- paste0(out_stem, ".figure_spec.json")
  os_write_json(spec, spec_path, digits = if (.os_figure_lossless(spec)) I(17) else I(10))
  invisible(list(files = files, spec = spec_path, spec_obj = spec))
}


.os_figure_lossless <- function(meta) {
  if(!is.null(meta$definition$semantic_version) || identical(meta$notes$numeric_precision,"binary64_roundtrip"))return(TRUE)
  panels<-meta$data$panels
  is.list(panels) && length(panels)>0L && any(vapply(panels,.os_figure_lossless,logical(1)))
}

# Attach metadata to a ggplot (used by every builder).
os_with_meta <- function(p, ...) {
  m <- list(...)
  old <- attr(p, "os_meta") %||% list()
  meta <- .os_merge_figure_meta(old, m)
  if(!is.null(old$definition$semantic_version) && is.null(meta$definition$semantic_version))
    stop("OS_INVALID_INPUT: metadata cannot erase a typed semantic contract.",call.=FALSE)
  if (!is.null(meta$definition$semantic_version)) {
    if (!exists("os_semantic_metadata", mode = "function")) stop("OS_MISSING_DEPENDENCY: load fig_semantics.R for typed figure metadata.", call. = FALSE)
    meta <- os_semantic_metadata(meta)
  }
  attr(p, "os_meta") <- meta
  p
}

# sha256 of a data.frame's canonical CSV serialization (for figure_spec).
os_table_sha256 <- function(df) {
  tf <- tempfile(fileext = ".csv"); on.exit(unlink(tf))
  utils::write.csv(df, tf, row.names = FALSE, fileEncoding = "UTF-8")
  .os_sha256_file(tf)
}

# ---------------------------------------------------------------------------
# 11. Lint: mechanical checks on a built plot before it is saved
# ---------------------------------------------------------------------------
# Returns a data.frame(rule, severity, message); empty when clean.
os_fig_lint <- function(plot, journal = NULL, width_mm = NULL, height_mm = NULL, text_contrast_min = 4.5) {
  jp <- os_journal(journal)
  out <- list()
  add <- function(rule, sev, msg) out[[length(out) + 1]] <<- data.frame(rule = rule, severity = sev, message = msg)
  plots <- if (inherits(plot, "patchwork")) c(list(plot), plot$patches$plots) else list(plot)
  for (p in plots) {
    if (!inherits(p, "ggplot")) next
    b <- tryCatch(ggplot2::ggplot_build(p), error = function(e) NULL)
    if (is.null(b)) { add("FIG-BUILD", "blocker", "ggplot layer could not be built; no successful visual lint claim is possible"); next }
    # text sizes in layers
    for (ld in b$data) {
      if ("size" %in% names(ld) && any(c("label") %in% names(ld))) {
        pts <- ld$size * ggplot2::.pt
        if (any(pts < jp$min_pt - 1e-6, na.rm = TRUE)) {
          add("FIG-01", "blocker", sprintf("in-plot text at %.1f pt < %s minimum %d pt", min(pts, na.rm = TRUE), jp$name, jp$min_pt))
        }
        os_assert_latin(ld$label, "in-plot labels")
        if (exists("os_figure_glyph_audit",mode="function")) {
          family <- if("family" %in% names(ld) && length(unique(ld$family))==1 && nzchar(ld$family[1])) ld$family[1] else os_font_family()
          glyphs <- os_figure_glyph_audit(ld$label,family)
          if(any(!glyphs$available)) add("FIG-GLYPH","blocker",paste("font lacks glyphs:",paste(glyphs$glyph[!glyphs$available],collapse=" ")))
        }
        if(all(c("colour","fill") %in% names(ld)) && exists("os_text_contrast_ratio",mode="function")) {
          keep<-!is.na(ld$colour)&!is.na(ld$fill)&ld$fill!="transparent"
          if(any(keep) && any(os_text_contrast_ratio(ld$colour[keep],ld$fill[keep])<text_contrast_min))
            add("FIG-TEXT-CONTRAST","warning",sprintf("text/background contrast below declared %.1f:1 threshold",text_contrast_min))
        }
      }
    }
    # semantic colours per panel: only DISCRETE colour/fill scales count
    # (continuous scales are one encoding, not many colours); greys excluded.
    used <- character(0)
    for (sc in b$plot$scales$scales) {
      if (!inherits(sc, "ScaleDiscrete")) next
      aes_hit <- intersect(sc$aesthetics, c("colour", "fill"))
      if (!length(aes_hit)) next
      for (ld in b$data) for (a in aes_hit) if (a %in% names(ld)) used <- c(used, ld[[a]])
    }
    used <- unique(toupper(substr(used[!is.na(used) & grepl("^#", used)], 1, 7)))
    n_sem <- 0
    if (length(used)) {
      rgbm <- grDevices::col2rgb(used)
      n_sem <- sum(apply(rgbm, 2, function(v) diff(range(v)) >= 16))
    }
    fig_type <- (attr(p, "os_meta") %||% list())$figure_type %||% ""
    if (identical(fig_type, "composite")) {
      pm <- attr(p, "os_meta")$data$panels
      fig_type <- pm[[length(pm)]]$figure_type %||% ""
    }
    many_ok <- fig_type %in% c("embedding", "proportion_bar", "oncoplot", "score_violin")
    if (!many_ok && n_sem > OS_FIG$max_semantic_colours_panel) {
      add("FIG-02", "warning", sprintf("%d semantic colours in one panel (> %d)", n_sem, OS_FIG$max_semantic_colours_panel))
    }
    # FIG-03: colours of DIFFERENT categories that become indistinguishable
    # under colour-vision-deficiency simulation (warning) or in grayscale
    # (info). Only colours that a discrete scale maps to a category count
    # (constant ink / reference-line colours are not categories).
    cat_cols <- .os_discrete_mapped_colours(b)
    if (length(cat_cols) >= 2) {
      cv <- os_cvd_collisions(cat_cols)
      bad <- cv[cv$mode != "grayscale", , drop = FALSE]
      if (nrow(bad)) {
        add("FIG-03", "warning", sprintf("%d colour pair(s) of different categories closer than %s %s under colour-vision simulation: %s",
                                         nrow(bad), OS_FIG$cvd_delta_e_metric, OS_FIG$cvd_delta_e_min, .os_cvd_pairs_text(bad)))
      }
      gr <- cv[cv$mode == "grayscale", , drop = FALSE]
      if (nrow(gr)) {
        add("FIG-03", "info", sprintf("%d colour pair(s) of different categories closer than %s %s in grayscale: %s",
                                      nrow(gr), OS_FIG$cvd_delta_e_metric, OS_FIG$cvd_delta_e_min, .os_cvd_pairs_text(gr)))
      }
    }
    # titles / labels language
    labs <- unlist(lapply(p$labels, function(l) if (is.character(l)) l else NULL))
    if (length(labs)) {
      os_assert_latin(labs, "axis/legend titles")
      if(exists("os_figure_glyph_audit",mode="function")) {
        glyphs<-os_figure_glyph_audit(labs)
        if(any(!glyphs$available)) add("FIG-GLYPH","blocker",paste("axis/legend font lacks glyphs:",paste(glyphs$glyph[!glyphs$available],collapse=" ")))
      }
    }
    layout <- (attr(p,"os_meta") %||% list())$notes$layout_budget
    if(!is.null(layout) && isTRUE(layout$crowded)) add("FIG-LAYOUT-BUDGET","warning","declared panel/row budget is below its readable physical size; split or paginate without dropping source IDs")
  }
  if (!length(out)) return(data.frame(rule = character(0), severity = character(0), message = character(0)))
  do.call(rbind, out)
}

# ---------------------------------------------------------------------------
# 12. Data labels (gene symbols, sample names): ONE definition for all figures
# ---------------------------------------------------------------------------
# ggrepel with a fixed seed (deterministic placement), 5.5 pt, italic for
# gene symbols, 0.25 pt dark-grey leader lines that always start at the
# point (min.segment.length = 0), and a thin white halo so a label stays
# legible over dense points.
OS_REPEL_SEED <- 20260925L
# Placement stops after a FIXED number of iterations, never after a wall-clock
# budget: a time limit would make the layout depend on CPU speed. 100,000
# iterations resolve the 20-label volcano of an ~8,000-gene run without
# label-label overlap (deseq2-wald pasilla anchor); max.time is set far above
# any real run so it never binds.
OS_REPEL_MAX_ITER <- 100000L
OS_REPEL_MAX_TIME <- 3600
# In-plot text size for a journal: the token, raised to that journal's
# minimum (Cell requires >= 6 pt, so 5.5 pt data labels become 6 pt there).
os_text_pt <- function(pt, journal = NULL) max(pt, os_journal(journal)$min_pt)

os_label_repel <- function(data, mapping, italic = TRUE, size_pt = OS_FIG$size_label, journal = NULL, ...) {
  size_pt <- os_text_pt(size_pt, journal)
  if (!requireNamespace("ggrepel", quietly = TRUE)) stop("OS_MISSING_PACKAGE: ggrepel is required for data labels.", call. = FALSE)
  args <- list(data = data, mapping = mapping, size = os_fs(size_pt), family = os_font_family(),
               fontface = if (italic) "italic" else "plain", colour = OS_FIG$col_ink,
               segment.colour = OS_FIG$col_segment, segment.size = os_lw(OS_FIG$lw_segment),
               min.segment.length = 0, box.padding = 0.25, point.padding = 0.1,
               max.overlaps = Inf, seed = OS_REPEL_SEED, max.iter = OS_REPEL_MAX_ITER, max.time = OS_REPEL_MAX_TIME,
               bg.colour = OS_FIG$col_bg, bg.r = 0.12)
  do.call(ggrepel::geom_text_repel, utils::modifyList(args, list(...)))
}

# ---------------------------------------------------------------------------
# 12b. Deterministic label placement for scatter labels (volcano, MA)
# ---------------------------------------------------------------------------
# Added 2026-09-27 (container build, pasilla anchor of deseq2-wald): ggrepel
# 0.9.8 left label-label overlaps on the volcano / MA plots (its forces decay
# before every overlap is resolved: 1,000 and 100,000 iterations gave the same
# layout), and a fixed theme(aspect.ratio) made it worse. os_label_place()
# places labels greedily at DRAW time, in millimetres of the real panel, with
# exact text widths from the device: labels in priority order (row order of
# `data`), each at the first candidate position (distance rings of
# OS_LABEL_STEP_MM, 16 directions ordered from the point's outward direction)
# whose box stays inside the panel, keeps OS_LABEL_PAD_MM from every placed
# label and does not cover any point (labelled points and the unlabelled
# repeller rows, label ""). No randomness, no iteration budget: the same input
# gives the same layout on every device. A label with no free position takes
# the candidate with the least overlap (never dropped).
OS_LABEL_PAD_MM <- 0.7
OS_LABEL_STEP_MM <- 0.6
OS_LABEL_POINT_R_MM <- c(labelled = 0.7, other = 0.45)
OS_LABEL_MAX_LEADER_MM <- 12

# TRUE where segment (x0,y0)-(x1,y1) meets rectangle (xmin,xmax,ymin,ymax);
# vectorised over rows of rect (Liang-Barsky clipping).
.os_seg_hits_rect <- function(x0, y0, x1, y1, rect) {
  if (!nrow(rect)) return(logical(0))
  dx <- x1 - x0; dy <- y1 - y0
  t0 <- rep(0, nrow(rect)); t1 <- rep(1, nrow(rect)); ok <- rep(TRUE, nrow(rect))
  clip <- function(pp, qq) {
    for (j in seq_along(qq)) {
      if (!ok[j]) next
      if (pp == 0) { if (qq[j] < 0) ok[j] <<- FALSE; next }
      rr <- qq[j] / pp
      if (pp < 0) { if (rr > t1[j]) ok[j] <<- FALSE else if (rr > t0[j]) t0[j] <<- rr }
      else { if (rr < t0[j]) ok[j] <<- FALSE else if (rr < t1[j]) t1[j] <<- rr }
    }
  }
  clip(-dx, x0 - rect[, 1]); clip(dx, rect[, 2] - x0); clip(-dy, y0 - rect[, 3]); clip(dy, rect[, 4] - y0)
  ok
}

# TRUE where segment a (x0,y0)-(x1,y1) properly crosses segments in rows of
# m (x0, y0, x1, y1); segments sharing an end point do not count.
.os_seg_cross <- function(x0, y0, x1, y1, m) {
  if (!nrow(m)) return(logical(0))
  orient <- function(ax, ay, bx, by, cx, cy) sign((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
  o1 <- orient(x0, y0, x1, y1, m[, 1], m[, 2]); o2 <- orient(x0, y0, x1, y1, m[, 3], m[, 4])
  o3 <- orient(m[, 1], m[, 2], m[, 3], m[, 4], x0, y0); o4 <- orient(m[, 1], m[, 2], m[, 3], m[, 4], x1, y1)
  o1 * o2 < 0 & o3 * o4 < 0
}

.os_place_labels_mm <- function(px, py, w, h, is_lab, W, H, ymax) {
  n <- length(px)
  pad <- OS_LABEL_PAD_MM
  # labelled points are hard obstacles (their radius + pad), other points soft
  r <- ifelse(is_lab, OS_LABEL_POINT_R_MM[["labelled"]] + pad, OS_LABEL_POINT_R_MM[["other"]])
  ob <- cbind(px - r, px + r, py - r, py + r)
  hard_ob <- ob[is_lab, , drop = FALSE]; hard_id <- which(is_lab)
  soft_ob <- ob[!is_lab, , drop = FALSE]
  placed <- matrix(numeric(0), ncol = 4)
  segs <- matrix(numeric(0), ncol = 4)    # leader lines of placed labels
  out <- matrix(NA_real_, nrow = n, ncol = 2)
  ang_base <- seq(0, 2 * pi, length.out = 17)[-17]
  max_d <- max(W, H)
  area <- function(b, m) if (!nrow(m)) 0 else
    pmax(0, pmin(b[2], m[, 2]) - pmax(b[1], m[, 1])) * pmax(0, pmin(b[4], m[, 4]) - pmax(b[3], m[, 3]))
  for (i in which(is_lab)) {
    out_dir <- atan2(py[i] - H / 2, px[i] - W / 2)
    dd <- abs(((ang_base - out_dir + pi) %% (2 * pi)) - pi)
    ang <- ang_base[order(dd, ang_base, method = "radix")]
    others <- hard_ob[hard_id != i, , drop = FALSE]
    # candidates are ranked by tier 1 first (must be 0 whenever possible:
    # overlap with a placed label, leader through a placed label, box over a
    # placed leader), then by a score = 10 x tier 2 (box on another labelled
    # point, leader through another labelled point, crossing leaders) +
    # unlabelled points under the label + 0.25 x leader length (mm). Search
    # stops at the first clean spot, or beyond OS_LABEL_MAX_LEADER_MM.
    best <- NULL; best_key <- c(Inf, Inf, Inf)
    better <- function(k1, k2) k1[1] < k2[1] || (k1[1] == k2[1] && k1[3] < k2[3])
    for (dist in seq(OS_LABEL_POINT_R_MM[["labelled"]] + pad, max_d, by = OS_LABEL_STEP_MM)) {
      # leader end e on the ring; the label box touches e with one of 9
      # anchors (left/centre/right x bottom/middle/top), the anchor facing
      # away from the point tried first; boxes that would cover their own
      # point are dropped
      ex <- px[i] + cos(ang) * dist; ey <- py[i] + sin(ang) * dist
      hj <- rep(c(0, 0.5, 1), times = 3); vj <- rep(c(0, 0.5, 1), each = 3)
      cand <- do.call(rbind, lapply(seq_along(ang), function(a) {
        pref <- abs(hj - (1 - (sign(round(cos(ang[a]), 6)) + 1) / 2)) + abs(vj - (1 - (sign(round(sin(ang[a]), 6)) + 1) / 2))
        o <- order(pref, hj, vj, method = "radix")
        cbind(ex[a] - hj[o] * w[i], ex[a] + (1 - hj[o]) * w[i], ey[a] - vj[o] * h[i], ey[a] + (1 - vj[o]) * h[i])
      }))
      rr <- OS_LABEL_POINT_R_MM[["labelled"]]
      own <- cand[, 1] - rr < px[i] & cand[, 2] + rr > px[i] & cand[, 3] - rr < py[i] & cand[, 4] + rr > py[i]
      inside <- cand[, 1] >= pad & cand[, 2] <= W - pad & cand[, 3] >= pad & cand[, 4] <= ymax - pad & !own
      bx <- cand
      for (k in seq_len(nrow(bx))) {
        if (!inside[k]) next
        b <- bx[k, ]
        nx <- min(max(px[i], b[1]), b[2]); ny <- min(max(py[i], b[3]), b[4])
        t1 <- sum(area(b + c(-pad, pad, -pad, pad), placed)) +
          sum(.os_seg_hits_rect(px[i], py[i], nx, ny, if (nrow(placed)) placed + rep(c(-pad, pad, -pad, pad), each = nrow(placed)) else placed))
        if (nrow(segs)) {
          for (sg in seq_len(nrow(segs))) t1 <- t1 + .os_seg_hits_rect(segs[sg, 1], segs[sg, 2], segs[sg, 3], segs[sg, 4], matrix(b, nrow = 1))
        }
        if (t1 > best_key[1]) next
        t2 <- (sum(area(b, others)) > 0) + sum(.os_seg_hits_rect(px[i], py[i], nx, ny, others)) + sum(.os_seg_cross(px[i], py[i], nx, ny, segs))
        t3 <- 10 * t2 + sum(area(b, soft_ob) > 0) + 0.25 * dist
        key <- c(t1, t2, t3)
        if (better(key, best_key)) { best <- b; best_key <- key }
      }
      # stop at a free spot, or once a clean spot exists and leaders get long
      if (!is.null(best) && best_key[1] == 0 &&
          ((best_key[2] == 0 && best_key[3] <= 0.25 * dist + 1e-9) || dist > OS_LABEL_MAX_LEADER_MM)) break
    }
    if (is.null(best)) best <- c(px[i], px[i] + w[i], py[i], py[i] + h[i])
    placed <- rbind(placed, best)
    segs <- rbind(segs, c(px[i], py[i], min(max(px[i], best[1]), best[2]), min(max(py[i], best[3]), best[4])))
    out[i, ] <- c((best[1] + best[2]) / 2, (best[3] + best[4]) / 2)
  }
  out
}

makeContent.os_placed_labels <- function(x) {
  W <- grid::convertWidth(grid::unit(1, "npc"), "mm", valueOnly = TRUE)
  H <- grid::convertHeight(grid::unit(1, "npc"), "mm", valueOnly = TRUE)
  px <- x$x_npc * W; py <- x$y_npc * H
  is_lab <- nzchar(x$label)
  gp <- grid::gpar(fontfamily = x$family, fontface = x$fontface, fontsize = x$fontsize, col = x$ink)
  w <- h <- numeric(length(px))
  h_line <- grid::convertHeight(grid::grobHeight(grid::textGrob("FGgy", gp = gp)), "mm", valueOnly = TRUE)
  for (i in which(is_lab)) {
    w[i] <- grid::convertWidth(grid::grobWidth(grid::textGrob(x$label[i], gp = gp)), "mm", valueOnly = TRUE)
    h[i] <- h_line
  }
  pos <- .os_place_labels_mm(px, py, w, h, is_lab, W, H, ymax = min(H, x$ymax_npc * H))
  kids <- list()
  li <- which(is_lab)
  if (length(li)) {
    # leader lines from the point edge to the nearest point of the label box
    sx <- sy <- ex <- ey <- numeric(0)
    for (i in li) {
      bx <- c(pos[i, 1] - w[i] / 2, pos[i, 1] + w[i] / 2, pos[i, 2] - h[i] / 2, pos[i, 2] + h[i] / 2)
      nx <- min(max(px[i], bx[1]), bx[2]); ny <- min(max(py[i], bx[3]), bx[4])
      d <- sqrt((nx - px[i])^2 + (ny - py[i])^2)
      rr <- OS_LABEL_POINT_R_MM[["labelled"]]
      if (d > rr + x$min_segment_mm) {
        sx <- c(sx, px[i] + (nx - px[i]) * rr / d); sy <- c(sy, py[i] + (ny - py[i]) * rr / d)
        ex <- c(ex, nx); ey <- c(ey, ny)
      }
    }
    if (length(sx)) {
      kids[[length(kids) + 1]] <- grid::segmentsGrob(grid::unit(sx, "mm"), grid::unit(sy, "mm"), grid::unit(ex, "mm"), grid::unit(ey, "mm"),
                                                    gp = grid::gpar(col = x$seg_col, lwd = x$seg_lwd, lineend = "butt"))
    }
    # halo: the label in the background colour at 8 offsets, then the label
    hr <- x$halo_r * x$fontsize * 25.4 / 72
    if (hr > 0) {
      for (a in seq(0, 2 * pi, length.out = 9)[-9]) {
        kids[[length(kids) + 1]] <- grid::textGrob(x$label[li], grid::unit(pos[li, 1] + hr * cos(a), "mm"), grid::unit(pos[li, 2] + hr * sin(a), "mm"),
                                                   gp = grid::gpar(fontfamily = x$family, fontface = x$fontface, fontsize = x$fontsize, col = x$halo_col))
      }
    }
    kids[[length(kids) + 1]] <- grid::textGrob(x$label[li], grid::unit(pos[li, 1], "mm"), grid::unit(pos[li, 2], "mm"), gp = gp)
  }
  grid::setChildren(x, do.call(grid::gList, kids))
}
if (requireNamespace("grid", quietly = TRUE)) registerS3method("makeContent", "os_placed_labels", makeContent.os_placed_labels, envir = asNamespace("grid"))

GeomOsPlacedLabel <- ggplot2::ggproto("GeomOsPlacedLabel", ggplot2::Geom,
  required_aes = c("x", "y", "label"),
  default_aes = ggplot2::aes(colour = "black", size = 1.94, family = "", fontface = 1),
  draw_key = ggplot2::draw_key_blank,
  draw_panel = function(data, panel_params, coord, ymax = NULL, seg_col = "grey30", seg_lwd = 0.5, halo_col = "white",
                        halo_r = 0.12, min_segment_mm = 1) {
    d <- coord$transform(data, panel_params)
    ymax_npc <- if (is.null(ymax)) 1 else coord$transform(data.frame(x = data$x[1], y = ymax), panel_params)$y
    grid::gTree(x_npc = d$x, y_npc = d$y, label = as.character(d$label),
                family = d$family[1], fontface = d$fontface[1], fontsize = d$size[1] * ggplot2::.pt, ink = d$colour[1],
                seg_col = seg_col, seg_lwd = seg_lwd, halo_col = halo_col, halo_r = halo_r, min_segment_mm = min_segment_mm,
                ymax_npc = ymax_npc, cl = "os_placed_labels")
  })

# data: labelled rows first in priority order (most important first), then
# optional repeller rows with label "" (points the labels must not cover).
# ymax: optional upper data-y bound for label boxes (volcano header band).
os_label_place <- function(data, mapping, italic = TRUE, size_pt = OS_FIG$size_label, journal = NULL, ymax = NULL) {
  size_pt <- os_text_pt(size_pt, journal)
  ggplot2::layer(geom = GeomOsPlacedLabel, stat = "identity", position = "identity", data = data, mapping = mapping,
                 inherit.aes = TRUE, show.legend = FALSE,
                 params = list(size = os_fs(size_pt), family = os_font_family(), fontface = if (italic) "italic" else "plain",
                               colour = OS_FIG$col_ink, ymax = ymax, seg_col = OS_FIG$col_segment,
                               seg_lwd = OS_FIG$lw_segment * 96 / 72, halo_col = OS_FIG$col_bg, halo_r = 0.12))
}

# ---------------------------------------------------------------------------
# 13. Large point layers: rasterise ONLY the points (decision 2026-09-26)
# ---------------------------------------------------------------------------
# A vector PDF with > 50,000 points (large single-cell embeddings) is tens of
# MB and slow to open in Illustrator/journal systems. Above
# OS_FIG$raster_threshold_points the point layer is rendered as a 600 dpi
# bitmap inside the otherwise vector figure (text, axes, legends, labels stay
# editable vectors) with ggrastr::rasterise(dev = "ragg"). The decision is
# recorded in figure_spec (notes$rasterised_points) and the caption says so.
# Without ggrastr the layer stays vector and a warning is raised.
os_points_layer <- function(layer, n_points) {
  if (n_points <= OS_FIG$raster_threshold_points) return(list(layer = layer, rasterised = FALSE))
  if (!requireNamespace("ggrastr", quietly = TRUE)) {
    warning(sprintf("OS_FIG_RASTER_UNAVAILABLE: %s points drawn as vectors because ggrastr is not installed.",
                    format(n_points, big.mark = ",")), call. = FALSE)
    return(list(layer = layer, rasterised = FALSE))
  }
  list(layer = ggrastr::rasterise(layer, dpi = OS_FIG$raster_dpi, dev = "ragg"), rasterised = TRUE)
}

# ---------------------------------------------------------------------------
# 14. Clipped colour scales: say so on the colour bar itself
# ---------------------------------------------------------------------------
# When values are clipped at +/- clip (z-scores, scaled expression), the end
# labels of the colour bar read "<= -2" and ">= 2" (true minus, <=/>= signs)
# so a reader never mistakes the clip value for the data range.
os_clipped_labels <- function(lo, hi) {
  force(lo); force(hi)
  function(x) {
    out <- os_axis_labels(x)
    tol <- 1e-9 * max(1, abs(hi - lo))
    out[!is.na(x) & abs(x - lo) < tol] <- paste0("\u2264", os_num(lo))
    out[!is.na(x) & abs(x - hi) < tol] <- paste0("\u2265", os_num(hi))
    out
  }
}

# Caption / QC sentence for a clipped scale: "values beyond +/-2 shown at the
# limit (k of N dots)". n_total counts the drawn elements (cells, dots) and
# `what` names them.
os_clip_note <- function(n_clipped, n_total, clip, what = NULL) {
  sprintf("values beyond %s%s shown at the limit (%s of %s%s)", "\u00b1", os_num(clip), os_num(n_clipped),
          os_num(n_total), if (is.null(what)) "" else paste0(" ", what))
}

# ---------------------------------------------------------------------------
# 15. P value display rules (docs/FIGURE_STYLE.md sec 16)
# ---------------------------------------------------------------------------
# The shared contract for any figure that prints a test result. Modules do
# NOT choose star cut-points or wording themselves.
#   * stars: OS_FIG$p_star_cutpoints / p_star_symbols, STRICT intervals
#     ("p < cutpoint"): p = 0.05 -> "ns", p = 0.0499 -> "*";
#   * default display is the multiplicity-ADJUSTED P (p_display_default);
#     an unadjusted P is always labelled "unadjusted";
#   * captions name the test, the adjustment and the family size.
if (!identical(OS_FIG$p_star_rule, "p < cutpoint")) {
  stop("OS_INVALID_PARAMETER: only the strict 'p < cutpoint' star rule is implemented.", call. = FALSE)
}
.os_check_p <- function(p, fn) {
  if (!is.numeric(p) && !all(is.na(p))) stop(sprintf("OS_INVALID_PARAMETER: %s needs numeric P values.", fn), call. = FALSE)
  p <- as.numeric(p)
  if (any(!is.na(p) & (p < 0 | p > 1))) stop(sprintf("OS_INVALID_PARAMETER: %s: P values must lie in [0, 1].", fn), call. = FALSE)
  p
}

# Star symbol per P value; NA in -> NA out (callers draw nothing).
os_p_stars <- function(p) {
  p <- .os_check_p(p, "os_p_stars")
  cut <- sort(OS_FIG$p_star_cutpoints, decreasing = TRUE)
  vapply(p, function(x) {
    if (is.na(x)) return(NA_character_)
    k <- sum(x < cut)                      # strict: p exactly at a cut-point is NOT below it
    if (k == 0) OS_FIG$p_star_ns else OS_FIG$p_star_symbols[k]
  }, character(1), USE.NAMES = FALSE)
}

# Adjustment method names as printed.
OS_P_ADJUST_NAMES <- c(holm = "Holm", bonferroni = "Bonferroni", hochberg = "Hochberg", hommel = "Hommel",
                       bh = "Benjamini\u2013Hochberg", fdr = "Benjamini\u2013Hochberg", by = "Benjamini\u2013Yekutieli",
                       tukey = "Tukey", dunnett = "Dunnett")

# "= 0.012", "= 3.2 x 10^-6", "< 10^-300", "= NA"
.os_p_value_text <- function(p) {
  if (is.na(p)) return("= NA")
  if (p == 0) return("below reported numerical precision (bound unknown)")
  if (p < 1e-300) return(paste0("< 10^", OS_MINUS, "300"))
  paste0("= ", os_p_text(p))
}

# P value label.
#   form = "caption": "Wilcoxon rank-sum test; Holm-adjusted P = 0.012
#                      (family of 6 comparisons)"
#   form = "short"  : on-plot text, "adj. P = 0.012" / "unadjusted P = 0.012"
# test: name of the test (required). adjustment: method (required when
# adjusted = TRUE; "holm", "BH", ... or free text). family_size: number of
# comparisons in the multiplicity family (required when adjusted = TRUE,
# printed whenever given). adjusted = FALSE always prints "unadjusted".
os_p_label <- function(p, test, adjustment = NULL, family_size = NULL,
                       adjusted = identical(OS_FIG$p_display_default, "adjusted"),
                       form = c("caption", "short"), statistic_kind = NULL) {
  form <- match.arg(form)
  if (!is.null(statistic_kind) && !identical(statistic_kind, if (adjusted) "adjusted_p" else "raw_p"))
    stop("OS_INVALID_INPUT: os_p_label only labels actual raw or adjusted P; q/local FDR/posterior values need their own typed labels.", call.=FALSE)
  p <- .os_check_p(p, "os_p_label")
  if (missing(test) || is.null(test) || !nzchar(test)) {
    stop("OS_MISSING_PARAMETER: os_p_label needs the name of the test.", call. = FALSE)
  }
  if (adjusted) {
    if (is.null(adjustment) || !nzchar(adjustment) || tolower(adjustment) == "none") {
      stop("OS_MISSING_PARAMETER: an adjusted P needs the adjustment method; use adjusted = FALSE for an unadjusted P.",
           call. = FALSE)
    }
    if (is.null(family_size)) {
      stop("OS_MISSING_PARAMETER: an adjusted P needs family_size (number of comparisons adjusted together).", call. = FALSE)
    }
  }
  if (!is.null(family_size) && (!is.numeric(family_size) || length(family_size) != 1 || is.na(family_size) ||
                                family_size < 1 || family_size != round(family_size))) {
    stop("OS_INVALID_PARAMETER: family_size must be one positive integer.", call. = FALSE)
  }
  adj_name <- if (adjusted) { a <- OS_P_ADJUST_NAMES[tolower(adjustment)]; if (is.na(a)) adjustment else unname(a) } else NULL
  fam <- if (is.null(family_size)) "" else
    sprintf(" (family of %s comparison%s%s)", os_num(family_size), if (family_size == 1) "" else "s",
            if (adjusted) "" else "; no multiplicity adjustment")
  vapply(p, function(x) {
    if (form == "short") return(paste0(if (adjusted) "adj. P " else "unadjusted P ", .os_p_value_text(x)))
    paste0(test, "; ", if (adjusted) paste0(adj_name, "-adjusted P ") else "unadjusted P ", .os_p_value_text(x), fam)
  }, character(1), USE.NAMES = FALSE)
}

# In-plot plotmath version of an os_p_label(form = "short") string: the
# literal "m x 10^e" becomes a true superscript, "P" is italic. Strings that
# carry no power of ten are returned as quoted plotmath text. Caption text is
# never passed through here; it stays plain text.
os_p_label_plotmath <- function(label) {
  q <- function(z) paste0("\"", gsub("([\"\\\\])", "\\\\\\1", z), "\"")
  txt <- function(z) {
    if (!nzchar(z)) return("")
    parts <- strsplit(z, "P", fixed = TRUE)[[1]]
    if (grepl("P$", z)) parts <- c(parts, "")
    out <- character()
    for (i in seq_along(parts)) {
      if (nzchar(parts[i])) out <- c(out, q(parts[i]))
      if (i < length(parts)) out <- c(out, "italic(P)")
    }
    paste(out, collapse = "*")
  }
  vapply(as.character(label), function(s) {
    if (is.na(s)) return(q("NA"))
    m <- regmatches(s, regexec("^(.*?)([0-9.]+ \u00d7 )?10\\^([\u2212-]?[0-9]+)$", s, perl = TRUE))[[1]]
    if (!length(m)) return(txt(s))
    head <- paste0(m[2], m[3])
    sup <- q(m[4])
    paste0(if (nzchar(head)) paste0(txt(head), "*") else "", "10^", sup)
  }, character(1), USE.NAMES = FALSE)
}

# ---------------------------------------------------------------------------
# 16. n and its unit (docs/FIGURE_STYLE.md sec 16.3)
# ---------------------------------------------------------------------------
# Every figure that compares groups states n WITH its unit, because "n" in a
# single-cell figure can mean cells or samples and only samples are
# independent replicates. Units are explicit words from OS_FIG$n_units.
#   os_n_label(3, "samples")                          -> "n = 3 samples"
#   os_n_label(1, "samples")                          -> "n = 1 sample"
#   os_n_label(c(120, 2400, 800), "cells", "sample")  -> "n = 120-2,400 cells per sample" (en dash)
os_n_label <- function(n, unit, per = NULL) {
  if (missing(unit) || length(unit) != 1 || !unit %in% OS_FIG$n_units) {
    stop(sprintf("OS_INVALID_PARAMETER: os_n_label unit must be one of: %s.", paste(OS_FIG$n_units, collapse = ", ")),
         call. = FALSE)
  }
  n <- n[!is.na(n)]
  if (!length(n) || !is.numeric(n) || any(n < 0) || any(n != round(n))) {
    stop("OS_INVALID_PARAMETER: os_n_label needs non-negative whole counts.", call. = FALSE)
  }
  lo <- min(n); hi <- max(n)
  u <- if (lo == hi && lo == 1) sub("s$", "", unit) else unit
  num <- if (lo == hi) os_num(lo) else paste0(os_num(lo), OS_NDASH, os_num(hi))
  paste0("n = ", num, " ", u, if (!is.null(per)) paste0(" per ", per) else "")
}

# ---------------------------------------------------------------------------
# 17. Colour-vision-deficiency simulation and colour distance (lint FIG-03)
# ---------------------------------------------------------------------------
# Simulation: Machado GM, Oliveira MM, Fernandes LAF (2009). A
# physiologically-based model for simulation of color vision deficiency.
# IEEE Trans Vis Comput Graph 15(6):1291-1298. The 3x3 matrices below are
# the paper's severity-1.0 matrices for protanopia, deuteranopia and
# tritanopia (the same values colorspace::simulate_cvd uses); they are
# applied to LINEAR sRGB (gamma removed), the result is clipped to [0, 1]
# and gamma-encoded again. Grayscale uses the Rec. 709 relative luminance
# Y = 0.2126 R + 0.7152 G + 0.0722 B on linear RGB.
# Distance: CIEDE2000 (Sharma, Wu & Dalal 2005, Color Res Appl 30:21-30)
# between CIE L*a*b* (D65 white) coordinates -- NOT the older Delta E 1976.
# The implementation reproduces the Sharma et al. test pairs (T9).
OS_CVD_MACHADO <- list(
  protan = matrix(c( 0.152286,  1.052583, -0.204868,
                     0.114503,  0.786281,  0.099216,
                    -0.003882, -0.048116,  1.051998), 3, byrow = TRUE),
  deutan = matrix(c( 0.367322,  0.860646, -0.227968,
                     0.280085,  0.672501,  0.047413,
                    -0.011820,  0.042940,  0.968881), 3, byrow = TRUE),
  tritan = matrix(c( 1.255528, -0.076749, -0.178779,
                    -0.078411,  0.930809,  0.147602,
                     0.004733,  0.691367,  0.303900), 3, byrow = TRUE)
)
if (!identical(OS_FIG$cvd_severity, 1)) stop("OS_INVALID_PARAMETER: only severity-1 CVD matrices are implemented.", call. = FALSE)

.os_srgb_to_linear <- function(v) ifelse(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055)^2.4)
.os_linear_to_srgb <- function(v) ifelse(v <= 0.0031308, 12.92 * v, 1.055 * v^(1 / 2.4) - 0.055)
.os_hex_linear <- function(hex) .os_srgb_to_linear(grDevices::col2rgb(hex) / 255)   # 3 x n

# Simulated colours (hex) for mode "deutan", "protan", "tritan", "grayscale"
# or "normal" (unchanged).
os_cvd_simulate <- function(hex, mode = c("deutan", "protan", "tritan", "grayscale", "normal")) {
  mode <- match.arg(mode)
  L <- .os_hex_linear(hex)
  S <- switch(mode,
              normal = L,
              grayscale = { y <- colSums(c(0.2126, 0.7152, 0.0722) * L); rbind(y, y, y) },
              OS_CVD_MACHADO[[mode]] %*% L)
  S <- pmin(pmax(S, 0), 1)
  G <- round(.os_linear_to_srgb(S) * 255)
  grDevices::rgb(G[1, ], G[2, ], G[3, ], maxColorValue = 255)
}

# sRGB hex -> CIE L*a*b* (D65 white), n x 3 matrix.
os_hex_to_lab <- function(hex) {
  L <- .os_hex_linear(hex)
  M <- matrix(c(0.4124564, 0.3575761, 0.1804375,
                0.2126729, 0.7151522, 0.0721750,
                0.0193339, 0.1191920, 0.9503041), 3, byrow = TRUE)
  X <- M %*% L
  wp <- c(0.95047, 1, 1.08883)
  f <- function(t) ifelse(t > (6 / 29)^3, t^(1 / 3), t / (3 * (6 / 29)^2) + 4 / 29)
  fx <- f(X[1, ] / wp[1]); fy <- f(X[2, ] / wp[2]); fz <- f(X[3, ] / wp[3])
  cbind(L = 116 * fy - 16, a = 500 * (fx - fy), b = 200 * (fy - fz))
}

# CIEDE2000 colour difference between rows of two L*a*b* matrices
# (parametric factors kL = kC = kH = 1).
os_delta_e2000 <- function(lab1, lab2) {
  lab1 <- matrix(lab1, ncol = 3); lab2 <- matrix(lab2, ncol = 3)
  L1 <- lab1[, 1]; a1 <- lab1[, 2]; b1 <- lab1[, 3]
  L2 <- lab2[, 1]; a2 <- lab2[, 2]; b2 <- lab2[, 3]
  rad <- pi / 180
  Cb <- (sqrt(a1^2 + b1^2) + sqrt(a2^2 + b2^2)) / 2
  G <- 0.5 * (1 - sqrt(Cb^7 / (Cb^7 + 25^7)))
  a1p <- (1 + G) * a1; a2p <- (1 + G) * a2
  C1p <- sqrt(a1p^2 + b1^2); C2p <- sqrt(a2p^2 + b2^2)
  hue <- function(b, a) ifelse(b == 0 & a == 0, 0, (atan2(b, a) / rad) %% 360)
  h1p <- hue(b1, a1p); h2p <- hue(b2, a2p)
  dLp <- L2 - L1; dCp <- C2p - C1p
  dh <- h2p - h1p
  dh <- ifelse(C1p * C2p == 0, 0, ifelse(abs(dh) <= 180, dh, ifelse(dh > 180, dh - 360, dh + 360)))
  dHp <- 2 * sqrt(C1p * C2p) * sin(dh / 2 * rad)
  Lbp <- (L1 + L2) / 2; Cbp <- (C1p + C2p) / 2
  hbp <- ifelse(C1p * C2p == 0, h1p + h2p,
                ifelse(abs(h1p - h2p) <= 180, (h1p + h2p) / 2,
                       ifelse(h1p + h2p < 360, (h1p + h2p + 360) / 2, (h1p + h2p - 360) / 2)))
  Tt <- 1 - 0.17 * cos((hbp - 30) * rad) + 0.24 * cos(2 * hbp * rad) + 0.32 * cos((3 * hbp + 6) * rad) -
    0.20 * cos((4 * hbp - 63) * rad)
  dtheta <- 30 * exp(-((hbp - 275) / 25)^2)
  RC <- 2 * sqrt(Cbp^7 / (Cbp^7 + 25^7))
  SL <- 1 + 0.015 * (Lbp - 50)^2 / sqrt(20 + (Lbp - 50)^2)
  SC <- 1 + 0.045 * Cbp
  SH <- 1 + 0.015 * Cbp * Tt
  RT <- -sin(2 * dtheta * rad) * RC
  sqrt((dLp / SL)^2 + (dCp / SC)^2 + (dHp / SH)^2 + RT * (dCp / SC) * (dHp / SH))
}

# Every pair of distinct colours under every mode: data.frame(colour_a,
# colour_b, mode, delta_e) in a deterministic order (mode, then pair).
os_cvd_pairs <- function(cols, modes = c("normal", OS_FIG$cvd_simulations, "grayscale")) {
  cols <- sort(unique(toupper(cols)), method = "radix")
  if (length(cols) < 2) {
    return(data.frame(colour_a = character(0), colour_b = character(0), mode = character(0), delta_e = numeric(0)))
  }
  ij <- utils::combn(length(cols), 2)
  do.call(rbind, lapply(modes, function(m) {
    lab <- os_hex_to_lab(os_cvd_simulate(cols, m))
    data.frame(colour_a = cols[ij[1, ]], colour_b = cols[ij[2, ]], mode = m,
               delta_e = os_delta_e2000(lab[ij[1, ], , drop = FALSE], lab[ij[2, ], , drop = FALSE]),
               stringsAsFactors = FALSE)
  }))
}

# Pairs closer than the FIG-03 threshold (in any mode), worst first.
os_cvd_collisions <- function(cols, threshold = OS_FIG$cvd_delta_e_min,
                              modes = c("normal", OS_FIG$cvd_simulations, "grayscale")) {
  pr <- os_cvd_pairs(cols, modes)
  pr <- pr[pr$delta_e < threshold, , drop = FALSE]
  pr <- pr[order(pr$delta_e, pr$colour_a, pr$colour_b, pr$mode, method = "radix"), , drop = FALSE]
  rownames(pr) <- NULL
  pr
}

.os_cvd_pairs_text <- function(pr, max_pairs = 5) {
  s <- utils::head(pr, max_pairs)
  txt <- paste(sprintf("%s/%s (%s %.1f)", s$colour_a, s$colour_b, s$mode, s$delta_e), collapse = ", ")
  if (nrow(pr) > max_pairs) paste0(txt, ", ...") else txt
}

# Colours that a DISCRETE colour/fill scale maps to categories in a built
# ggplot (constant colours of annotations and reference lines excluded).
.os_discrete_mapped_colours <- function(b) {
  aes_disc <- character(0)
  for (sc in b$plot$scales$scales) {
    if (inherits(sc, "ScaleDiscrete")) aes_disc <- c(aes_disc, intersect(sc$aesthetics, c("colour", "fill")))
  }
  aes_disc <- unique(aes_disc)
  if (!length(aes_disc)) return(character(0))
  out <- character(0)
  for (i in seq_along(b$data)) {
    mapped <- names(b$plot$layers[[i]]$computed_mapping %||% list())
    for (a in intersect(aes_disc, mapped)) if (a %in% names(b$data[[i]])) out <- c(out, as.character(b$data[[i]][[a]]))
  }
  out <- out[!is.na(out) & grepl("^#[0-9A-Fa-f]{6}", out)]
  sort(unique(toupper(substr(out, 1, 7))), method = "radix")
}

# Stable entity keys for scientific joins; positional recycling is never a join.
.os_require_ids <- function(ids, what = "entity IDs") {
  if (is.null(ids) || !length(ids) || anyNA(ids) || any(!nzchar(as.character(ids))) || anyDuplicated(as.character(ids)))
    stop(sprintf("OS_INVALID_INPUT: %s must be nonmissing, nonempty and unique.", what), call. = FALSE)
  as.character(ids)
}
