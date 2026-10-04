# fig_heatmap.R -- the one heatmap engine behind every omicstat heatmap
# (top-gene z-score, sample distance, GSVA scores, module-trait, marker heat).
# ASCII only on purpose. Requires fig_style.R to be source()'d first.
#
# Layout (fixed; see docs/FIGURE_STYLE.md sec 8.4 and sec 18.1):
#
#                    [ column slice titles (strips)  ]
#                    [ column dendrogram             ]             <- only when columns clustered
#                    [ annotation track 1            ] name        <- column-track names on the RIGHT
#                    [ annotation track k            ] name
#   [slice [row    ] [r1][rk] [ heatmap body          ] row labels  <- row labels on the RIGHT
#    title][dendro ] [  ][  ] [ (1 mm gaps between     ]  or marks   <- mark_rows: labels + leader lines
#                    name name[  row / column slices) ]
#                    (bottom) [ column labels (90 deg) ]             <- column labels BELOW
#                                                    legends collected on the far right
#
# Clustering: stats::dist(method = "euclidean") + stats::hclust(method =
# "complete") -- the pheatmap/ComplexHeatmap default, stated in the caption.
# With row_split / col_split the clustering is done WITHIN each slice (slices
# keep the caller's level order; ComplexHeatmap cluster_row_slices = FALSE).
# Every call is deterministic (hclust is deterministic; ties in leaf order are
# resolved by the input order, which callers sort by feature_id first).

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_heatmap.R.", call. = FALSE)
if (!requireNamespace("patchwork", quietly = TRUE)) stop("OS_MISSING_PACKAGE: patchwork is required by fig_heatmap.R.", call. = FALSE)

# Extension constants (documented in docs/FIGURE_STYLE.md sec 18; NOT part
# of the machine-checked sec 14 table). Each extension file adds its own
# entries, so the list is merged rather than overwritten.
OS_FIG_EXT <- utils::modifyList(if (exists("OS_FIG_EXT", inherits = TRUE)) OS_FIG_EXT else list(), list(
  split_gap_mm   = 1,     # gap between heatmap row / column slices
  annot_track_mm = 2.5,   # width of one row-annotation track
  mark_lead_mm   = 3.5    # horizontal room for the anno_mark leader lines
))

# Dendrogram segments from an hclust object in leaf-position coordinates.
.os_dendro_segments <- function(hc) {
  n <- length(hc$order)
  pos <- numeric(n); pos[hc$order] <- seq_len(n)
  merge <- hc$merge; h <- hc$height
  node_x <- numeric(nrow(merge)); node_h <- h
  seg <- list()
  get_xy <- function(k) if (k < 0) c(pos[-k], 0) else c(node_x[k], node_h[k])
  for (i in seq_len(nrow(merge))) {
    a <- get_xy(merge[i, 1]); b <- get_xy(merge[i, 2])
    node_x[i] <- (a[1] + b[1]) / 2
    seg[[length(seg) + 1]] <- c(a[1], a[2], a[1], h[i])
    seg[[length(seg) + 1]] <- c(b[1], b[2], b[1], h[i])
    seg[[length(seg) + 1]] <- c(a[1], h[i], b[1], h[i])
  }
  s <- do.call(rbind, seg)
  data.frame(x = s[, 1], y = s[, 2], xend = s[, 3], yend = s[, 4])
}

.os_cluster <- function(m, by = c("rows", "cols")) {
  by <- match.arg(by)
  x <- if (by == "rows") m else t(m)
  if (nrow(x) < 3) return(NULL)
  x[!is.finite(x)] <- 0
  stats::hclust(stats::dist(x, method = "euclidean"), method = "complete")
}

# Resolve a split specification into a factor aligned with `ids` (level order
# = slice order: factor levels when a factor is given, else sorted C-locale).
.os_slices <- function(split, ids, what) {
  if (is.null(split)) return(NULL)
  if (!is.null(names(split)) && all(ids %in% names(split))) {
    s <- split[ids]
  } else if (length(split) == length(ids) && is.null(names(split))) {
    s <- split
  } else {
    stop(sprintf("OS_INVALID_PARAMETER: %s must be named by the matrix %s names or have one unnamed entry per %s.",
                 what, if (what == "row_split") "row" else "column", if (what == "row_split") "row" else "column"),
         call. = FALSE)
  }
  if (anyNA(s)) stop(sprintf("OS_INVALID_PARAMETER: %s contains missing values.", what), call. = FALSE)
  lv <- if (is.factor(split)) intersect(levels(split), as.character(s)) else sort(unique(as.character(s)), method = "radix")
  os_assert_latin(lv, paste(what, "titles"))
  factor(as.character(s), levels = lv)
}

# Display order (and per-slice hclust objects) along one dimension.
.os_slice_order <- function(m, slices, cluster, by) {
  n <- if (by == "rows") nrow(m) else ncol(m)
  if (is.null(slices)) {
    hc <- if (cluster) .os_cluster(m, by) else NULL
    return(list(order = if (!is.null(hc)) hc$order else seq_len(n), hcs = list(all = hc)))
  }
  ord <- integer(0); hcs <- list()
  for (lv in levels(slices)) {
    idx <- which(slices == lv)
    sub <- if (by == "rows") m[idx, , drop = FALSE] else m[, idx, drop = FALSE]
    hc <- if (cluster) .os_cluster(sub, by) else NULL
    ord <- c(ord, if (!is.null(hc)) idx[hc$order] else idx)
    hcs[lv] <- list(hc)
  }
  list(order = ord, hcs = hcs)
}

# Display coordinate of the i-th item in display order: rows are drawn top to
# bottom (y = n .. 1), columns left to right (x = 1 .. n).
.os_disp <- function(i, n, side) if (side == "left") n + 1 - i else i

# Dendrogram panel(s): one hclust per slice, all on ONE height scale.
# sizes: slice sizes in display order; slice_lv: slice names (NULL = unsplit).
.os_dendro_panel <- function(hcs, sizes, slice_lv, side = c("top", "left")) {
  side <- match.arg(side)
  n <- sum(sizes)
  offs <- c(0, cumsum(sizes))[seq_along(sizes)]
  seg <- list(); blank <- list()
  for (k in seq_along(sizes)) {
    s_lab <- if (is.null(slice_lv)) "all" else slice_lv[k]
    blank[[k]] <- data.frame(pos = .os_disp(c(offs[k] + 0.5, offs[k] + sizes[k] + 0.5), n, side), h = 0, .s = s_lab)
    hc <- hcs[[k]]
    if (is.null(hc)) next
    d <- .os_dendro_segments(hc)
    seg[[length(seg) + 1]] <- data.frame(pos = .os_disp(offs[k] + d$x, n, side), h = d$y,
                                         pos_end = .os_disp(offs[k] + d$xend, n, side), h_end = d$yend, .s = s_lab)
  }
  if (!length(seg)) return(NULL)
  seg <- do.call(rbind, seg); blank <- do.call(rbind, blank)
  lv <- slice_lv %||% "all"
  seg$.s <- factor(seg$.s, levels = lv); blank$.s <- factor(blank$.s, levels = lv)
  # facet variable name used by .os_split_layer: .cs (columns) / .rs (rows)
  fv <- if (side == "top") ".cs" else ".rs"
  seg[[fv]] <- seg$.s; blank[[fv]] <- blank$.s
  lw <- os_lw(OS_FIG$lw_segment)
  if (side == "top") {
    p <- ggplot2::ggplot(seg) +
      ggplot2::geom_blank(data = blank, ggplot2::aes(x = pos, y = h)) +
      ggplot2::geom_segment(ggplot2::aes(x = pos, y = h, xend = pos_end, yend = h_end), linewidth = lw,
                            colour = OS_FIG$col_ink, lineend = "square") +
      ggplot2::scale_x_continuous(expand = c(0, 0)) +
      ggplot2::scale_y_continuous(expand = c(0, 0))
  } else {
    p <- ggplot2::ggplot(seg) +
      ggplot2::geom_blank(data = blank, ggplot2::aes(x = -h, y = pos)) +
      ggplot2::geom_segment(ggplot2::aes(x = -h, y = pos, xend = -h_end, yend = pos_end), linewidth = lw,
                            colour = OS_FIG$col_ink, lineend = "square") +
      ggplot2::scale_y_continuous(expand = c(0, 0)) +
      ggplot2::scale_x_continuous(expand = c(0, 0))
  }
  p + ggplot2::theme_void() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))
}

# Kept for callers of the pre-split engine: one unsplit dendrogram. Rows are
# drawn top-to-bottom in leaf order, matching the heatmap body.
.os_dendro_plot <- function(hc, side = c("top", "left")) {
  side <- match.arg(side)
  .os_dendro_panel(list(hc), length(hc$order), NULL, side)
}

# Facets + strip theme for a split layout. rs / cs: add row / column facets;
# row_strip / col_strip: this panel carries the slice titles (row titles on
# the LEFT, rotated; column titles on TOP).
.os_split_layer <- function(rs, cs, row_strip = FALSE, col_strip = FALSE) {
  if (!rs && !cs) return(list())
  fam <- os_font_family()
  blank <- ggplot2::element_blank()
  txt <- function(...) ggplot2::element_text(size = OS_FIG$size_strip, colour = OS_FIG$col_ink, family = fam, ...)
  list(
    ggplot2::facet_grid(rows = if (rs) ggplot2::vars(.rs) else NULL, cols = if (cs) ggplot2::vars(.cs) else NULL,
                        scales = "free", space = "free", switch = if (rs && row_strip) "y" else NULL),
    ggplot2::theme(panel.spacing = grid::unit(OS_FIG_EXT$split_gap_mm, "mm"),
                   strip.background = blank, strip.placement = "outside",
                   strip.text.x.top = if (cs && col_strip) txt(margin = ggplot2::margin(b = 1, unit = "mm")) else blank,
                   strip.text.x.bottom = blank, strip.text.y.right = blank,
                   strip.text.y.left = if (rs && row_strip) txt(angle = 90, margin = ggplot2::margin(r = 1, unit = "mm")) else blank)
  )
}

# A text-only cell (column-track name, left-aligned, vertically centred).
.os_track_name_cell <- function(label, x0 = 0, journal = NULL) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = x0, y = 0.5, label = label, hjust = 0, vjust = 0.5,
                      size = os_fs(os_text_pt(OS_FIG$size_axis_text, journal)), family = os_font_family(),
                      colour = OS_FIG$col_ink) +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))
}

# mat: numeric matrix, rownames = row ids, colnames = column ids.
# row_labels: display labels for rows (named by rownames) or NULL.
# col_annot: data.frame, rownames = colnames(mat), one column per track.
# row_annot: data.frame, rownames = rownames(mat), one column per track
#            (drawn LEFT of the body, track names at the bottom).
# annot_colours: list(track = named chr of colours) for row AND column tracks;
#            tracks without an entry take colour-registry colours (family =
#            track name, registry = colour_registry).
# scale_type: "diverging" (symmetric around 0, clip at +/- clip) |
#             "sequential" | "distance" | "expression".
# row_split / col_split: slice labels (named by row / column ids, or one per
#            row / column in matrix order); a factor fixes the slice order.
# mark_rows: row ids to label on the right with leader lines (anno_mark);
#            when given, the full row-label axis is not drawn.
os_heatmap <- function(mat, value_title, scale_type = c("diverging", "sequential", "distance", "expression"),
                       clip = NULL, cluster_rows = TRUE, cluster_cols = TRUE,
                       show_row_dendro = cluster_rows, show_col_dendro = cluster_cols,
                       row_labels = NULL, show_row_labels = NULL, italic_rows = TRUE,
                       show_col_labels = TRUE, col_annot = NULL, annot_colours = NULL,
                       cell_text = NULL, limits = NULL, journal = NULL,
                       row_annot = NULL, row_split = NULL, col_split = NULL, mark_rows = NULL,
                       colour_registry = NULL) {
  scale_type <- match.arg(scale_type)
  if (!is.matrix(mat) || !is.numeric(mat)) stop("OS_INVALID_INPUT: os_heatmap needs a numeric matrix.", call. = FALSE)
  if (is.null(rownames(mat)) || is.null(colnames(mat))) stop("OS_INVALID_INPUT: heatmap matrix needs row and column names.", call. = FALSE)
  nr <- nrow(mat); nc <- ncol(mat)
  if (!is.null(mark_rows)) {
    mark_rows <- unique(as.character(mark_rows))
    bad <- setdiff(mark_rows, rownames(mat))
    if (length(bad)) stop(sprintf("OS_INVALID_PARAMETER: mark_rows not in the matrix: %s.", paste(utils::head(bad, 5), collapse = ", ")), call. = FALSE)
    if (isTRUE(show_row_labels)) warning("OS_INVALID_PARAMETER: show_row_labels is ignored when mark_rows is given.", call. = FALSE)
    show_row_labels <- FALSE
  }
  show_row_labels <- show_row_labels %||% (nr <= 60)
  fam <- os_font_family()

  rsl <- .os_slices(row_split, rownames(mat), "row_split")
  csl <- .os_slices(col_split, colnames(mat), "col_split")
  split_r <- !is.null(rsl); split_c <- !is.null(csl)
  ro <- .os_slice_order(mat, rsl, cluster_rows, "rows")
  co <- .os_slice_order(mat, csl, cluster_cols, "cols")
  row_ord <- ro$order; col_ord <- co$order
  any_hr <- any(!vapply(ro$hcs, is.null, logical(1)))
  any_hc <- any(!vapply(co$hcs, is.null, logical(1)))
  rn <- rownames(mat)[row_ord]; cn <- colnames(mat)[col_ord]
  rs_disp <- if (split_r) rsl[row_ord] else NULL
  cs_disp <- if (split_c) csl[col_ord] else NULL
  r_sizes <- if (split_r) as.integer(table(rs_disp)) else nr
  c_sizes <- if (split_c) as.integer(table(cs_disp)) else nc

  v <- mat[row_ord, col_ord, drop = FALSE]
  clipped_n <- 0L
  if (!is.null(clip)) {
    clipped_n <- sum(abs(v) > clip, na.rm = TRUE)
    v[v > clip] <- clip; v[v < -clip] <- -clip
  }
  # rows drawn top-to-bottom in dendrogram order: y = nr .. 1
  df <- data.frame(col = rep(seq_len(nc), each = nr), row = rep(rev(seq_len(nr)), times = nc),
                   value = as.vector(v))
  if (split_r) df$.rs <- rep(rs_disp, times = nc)
  if (split_c) df$.cs <- rep(cs_disp, each = nr)
  lab_rows <- if (is.null(row_labels)) rn else unname(row_labels[rn])
  lab_rows[is.na(lab_rows)] <- rn[is.na(lab_rows)]
  os_assert_latin(c(lab_rows, cn), "heatmap labels")

  pal <- switch(scale_type, diverging = OS_PAL_DIVERGING, sequential = OS_PAL_SEQUENTIAL,
                distance = OS_PAL_DISTANCE, expression = OS_PAL_EXPRESSION)
  clipped_ends <- FALSE
  if (scale_type == "diverging") {
    lim <- limits %||% { m <- clip %||% os_sym_limit(v); c(-m, m) }
    # a clipped colour bar says so at its ends ("<= -2", ">= 2")
    clipped_ends <- !is.null(clip) && isTRUE(all.equal(as.numeric(lim), c(-clip, clip)))
    fill_scale <- ggplot2::scale_fill_gradientn(colours = pal, limits = lim, oob = scales::squish,
                                                labels = if (clipped_ends) os_clipped_labels(-clip, clip) else os_axis_labels,
                                                guide = os_guide_colourbar(value_title))
  } else {
    lim <- limits %||% range(v, finite = TRUE)
    fill_scale <- ggplot2::scale_fill_gradientn(colours = pal, limits = lim, oob = scales::squish,
                                                labels = os_axis_labels, guide = os_guide_colourbar(value_title))
  }

  # --- which panel carries the slice titles -------------------------------
  has_rd <- any_hr && show_row_dendro
  has_cd <- any_hc && show_col_dendro
  has_ra <- !is.null(row_annot) && ncol(row_annot) > 0
  has_ca <- !is.null(col_annot) && ncol(col_annot) > 0
  row_strip_on <- if (has_rd) "dend" else if (has_ra) "rannot1" else "body"
  col_strip_on <- if (has_cd) "dend" else if (has_ca) "cannot1" else "body"

  border <- if (nr <= 40 && nc <= 40) OS_FIG$col_bg else NA
  x_lab_fun <- function(b) { i <- round(b); out <- rep("", length(b)); ok <- !is.na(i) & i >= 1 & i <= nc; out[ok] <- cn[i[ok]]; out }
  y_lab_fun <- function(b) { i <- nr + 1 - round(b); out <- rep("", length(b)); ok <- !is.na(i) & i >= 1 & i <= nr; out[ok] <- lab_rows[i[ok]]; out }
  body <- ggplot2::ggplot(df, ggplot2::aes(x = col, y = row, fill = value)) +
    ggplot2::geom_tile(colour = border, linewidth = os_lw(OS_FIG$lw_segment)) +
    fill_scale +
    ggplot2::scale_x_continuous(breaks = seq_len(nc), labels = if (show_col_labels) x_lab_fun else NULL,
                                expand = c(0, 0), position = "bottom") +
    ggplot2::scale_y_continuous(breaks = rev(seq_len(nr)), labels = if (show_row_labels) y_lab_fun else NULL,
                                expand = c(0, 0), position = "right") +
    theme_omicstat(journal = journal, axes = "none") +
    ggplot2::theme(axis.title = ggplot2::element_blank(),
                   axis.text.x = if (show_col_labels) ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5,
                                                                             size = OS_FIG$size_axis_text) else ggplot2::element_blank(),
                   axis.text.y.right = if (show_row_labels) ggplot2::element_text(size = max(os_journal(journal)$min_pt, min(OS_FIG$size_axis_text, 250 / max(nr, 1))),
                                                                                  face = if (italic_rows) "italic" else "plain", hjust = 0) else ggplot2::element_blank(),
                   plot.margin = ggplot2::margin(0, 0, 0, 0)) +
    (if (!show_row_labels) ggplot2::theme(axis.ticks.length.y = grid::unit(0, "mm"))) +
    .os_split_layer(split_r, split_c, row_strip = row_strip_on == "body", col_strip = col_strip_on == "body")
  if (!is.null(cell_text)) {
    ct <- cell_text[row_ord, col_ord, drop = FALSE]
    df$label <- as.vector(ct)
    # black text on light cells, white on dark cells (luminance of the fill)
    cols <- scales::gradient_n_pal(pal)(scales::rescale(pmin(pmax(df$value, lim[1]), lim[2]), from = lim))
    rgbm <- grDevices::col2rgb(cols) / 255
    lum <- 0.2126 * rgbm[1, ] + 0.7152 * rgbm[2, ] + 0.0722 * rgbm[3, ]
    df$tcol <- ifelse(lum < 0.45, "#FFFFFF", "#000000")
    body <- body + ggplot2::geom_text(data = df, ggplot2::aes(label = label, colour = I(tcol)),
                                      size = os_fs(os_text_pt(OS_FIG$size_label, journal)), family = fam, lineheight = 0.9)
  }

  # --- column stack (top) --------------------------------------------------
  top <- list(); top_names <- list(); heights <- numeric(0)
  if (has_cd) {
    top$dend <- .os_dendro_panel(co$hcs, c_sizes, if (split_c) levels(csl) else NULL, "top") +
      .os_split_layer(FALSE, split_c, col_strip = col_strip_on == "dend")
    heights <- c(heights, max(3, nr * 0.08))
  }
  annot_used <- list()
  reg <- colour_registry
  # Track colours: caller's map, else the colour registry (family = track
  # name). Registry-derived legends list factor levels in level order, other
  # values in C-locale order (never in order of appearance).
  .track_colours <- function(tr, raw) {
    if (!is.null(annot_colours[[tr]])) return(annot_colours[[tr]])
    vals <- as.character(raw)
    lv <- if (is.factor(raw)) intersect(levels(raw), vals) else sort(unique(vals[!is.na(vals)]), method = "radix")
    cr <- os_colours_for(lv, family = tr, registry = reg)
    reg <<- cr$registry
    cr$colours[lv]
  }
  if (has_ca) {
    for (k in seq_along(names(col_annot))) {
      tr <- names(col_annot)[k]
      vals <- as.character(col_annot[cn, tr])
      cmap <- .track_colours(tr, col_annot[cn, tr])
      annot_used[[tr]] <- as.list(cmap)
      adf <- data.frame(col = seq_len(nc), row = 1, value = factor(vals, levels = names(cmap)))
      if (split_c) adf$.cs <- cs_disp
      pa <- ggplot2::ggplot(adf, ggplot2::aes(x = col, y = row, fill = value)) +
        ggplot2::geom_tile(colour = OS_FIG$col_bg, linewidth = os_lw(OS_FIG$lw_segment), height = 1) +
        ggplot2::scale_fill_manual(values = cmap, breaks = names(cmap), guide = os_guide_legend(tr), drop = TRUE,
                                   na.value = OS_FIG$col_na) +
        ggplot2::scale_x_continuous(expand = c(0, 0), limits = if (split_c) NULL else c(0.5, nc + 0.5)) +
        ggplot2::scale_y_continuous(expand = c(0, 0), breaks = 1, labels = tr, position = "right") +
        theme_omicstat(journal = journal, axes = "none") +
        ggplot2::theme(axis.title = ggplot2::element_blank(),
                       axis.text.y.right = ggplot2::element_text(size = OS_FIG$size_axis_text, hjust = 0),
                       plot.margin = ggplot2::margin(0, 0, 0.4, 0, unit = "mm")) +
        .os_split_layer(FALSE, split_c, col_strip = col_strip_on == "cannot1" && k == 1)
      if (!is.null(mark_rows)) {
        pa <- pa + ggplot2::theme(axis.text.y.right = ggplot2::element_blank(), axis.ticks.length.y = grid::unit(0, "mm"))
      }
      top[[paste0("annot_", tr)]] <- pa
      top_names[[paste0("annot_", tr)]] <- tr
      heights <- c(heights, max(1, nr * 0.025))
    }
  }

  # --- body row (left to right) -------------------------------------------
  row_blank <- function() {
    offs <- c(0, cumsum(r_sizes))[seq_along(r_sizes)]
    b <- data.frame(y = .os_disp(c(offs + 0.5, offs + r_sizes + 0.5), nr, "left"), x = 0)
    if (split_r) b$.rs <- factor(rep(levels(rsl), 2), levels = levels(rsl))
    b
  }
  left <- list(); widths <- numeric(0); width_units <- character(0)
  if (has_rd) {
    left$dend <- .os_dendro_panel(ro$hcs, r_sizes, if (split_r) levels(rsl) else NULL, "left") +
      .os_split_layer(split_r, FALSE, row_strip = row_strip_on == "dend")
    widths <- c(widths, 0.12); width_units <- c(width_units, "null")
  }
  row_annot_used <- list()
  if (has_ra) {
    miss <- setdiff(rownames(mat), rownames(row_annot))
    if (length(miss)) stop(sprintf("OS_INVALID_PARAMETER: row_annot has no row for: %s.", paste(utils::head(miss, 5), collapse = ", ")), call. = FALSE)
    for (k in seq_along(names(row_annot))) {
      tr <- names(row_annot)[k]
      os_assert_latin(tr, "row annotation names")
      vals <- as.character(row_annot[rn, tr])
      cmap <- .track_colours(tr, row_annot[rn, tr])
      row_annot_used[[tr]] <- as.list(cmap)
      adf <- data.frame(x = 1, y = rev(seq_len(nr)), value = factor(vals, levels = names(cmap)))
      if (split_r) adf$.rs <- rs_disp
      pr <- ggplot2::ggplot(adf, ggplot2::aes(x = x, y = y, fill = value)) +
        ggplot2::geom_tile(colour = if (nr <= 40) OS_FIG$col_bg else NA, linewidth = os_lw(OS_FIG$lw_segment), width = 1) +
        ggplot2::scale_fill_manual(values = cmap, breaks = names(cmap), guide = os_guide_legend(tr), drop = TRUE,
                                   na.value = OS_FIG$col_na) +
        ggplot2::scale_x_continuous(expand = c(0, 0), breaks = 1, labels = tr, position = "bottom") +
        ggplot2::scale_y_continuous(expand = c(0, 0)) +
        theme_omicstat(journal = journal, axes = "none") +
        ggplot2::theme(axis.title = ggplot2::element_blank(),
                       axis.text.x.bottom = ggplot2::element_text(size = OS_FIG$size_axis_text, angle = 90, hjust = 1, vjust = 0.5,
                                                                  margin = ggplot2::margin(t = 0.8, unit = "mm")),
                       axis.ticks.length.y = grid::unit(0, "mm"),
                       plot.margin = ggplot2::margin(0, 0.4, 0, 0, unit = "mm")) +
        .os_split_layer(split_r, FALSE, row_strip = row_strip_on == "rannot1" && k == 1)
      left[[paste0("rannot_", tr)]] <- pr
      widths <- c(widths, OS_FIG_EXT$annot_track_mm); width_units <- c(width_units, "mm")
    }
  }
  left$body <- body; widths <- c(widths, 1); width_units <- c(width_units, "null")
  body_col <- length(left)
  mark_df <- NULL
  if (!is.null(mark_rows)) {
    pos <- match(mark_rows, rn)
    mark_df <- data.frame(id = rn[sort(pos)], y = nr + 1 - sort(pos), lab = lab_rows[sort(pos)], stringsAsFactors = FALSE)
    if (split_r) mark_df$.rs <- rs_disp[sort(pos)]
    lab_pt <- os_text_pt(OS_FIG$size_label, journal)
    text_mm <- max(nchar(mark_df$lab)) * 0.6 * lab_pt * MM_PER_IN / 72
    name_mm <- if (has_ca) max(nchar(names(col_annot))) * 0.6 * OS_FIG$size_axis_text * MM_PER_IN / 72 + 2.8 else 0
    w_mm <- max(OS_FIG_EXT$mark_lead_mm + text_mm + 1, name_mm)
    lead_frac <- OS_FIG_EXT$mark_lead_mm / w_mm
    pm <- ggplot2::ggplot(mark_df, ggplot2::aes(x = 0, y = y)) +
      ggplot2::geom_blank(data = row_blank(), ggplot2::aes(x = x, y = y)) +
      os_label_repel(mark_df, ggplot2::aes(x = 0, y = y, label = lab), italic = italic_rows, journal = journal,
                     nudge_x = lead_frac, direction = "y", hjust = 0, box.padding = 0.08, point.padding = 0,
                     inherit.aes = FALSE) +
      ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(expand = c(0, 0)) +
      ggplot2::coord_cartesian(clip = "off") +
      ggplot2::theme_void() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0)) +
      .os_split_layer(split_r, FALSE)
    left$mark <- pm; widths <- c(widths, w_mm); width_units <- c(width_units, "mm")
  }

  # --- assemble --------------------------------------------------------------
  ncol_grid <- length(left)
  # spacers must not carry the default 5.5 pt plot margin (it would open a
  # ~2 mm gap between the dendrogram / tracks and the body)
  spacer <- function() patchwork::plot_spacer() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))
  cells <- list()
  for (key in names(top)) {
    row_cells <- rep(list(spacer()), ncol_grid)
    row_cells[[body_col]] <- top[[key]]
    if (!is.null(top_names[[key]]) && !is.null(mark_df)) {
      # with mark_rows, a column-track name sits in the mark column so the
      # leader lines can start right at the heatmap edge
      row_cells[[ncol_grid]] <- .os_track_name_cell(top_names[[key]], x0 = 1.8 / widths[ncol_grid], journal = journal)
    }
    cells <- c(cells, row_cells)
  }
  cells <- c(cells, unname(left))
  heights <- c(heights, nr)
  p <- patchwork::wrap_plots(cells, ncol = ncol_grid, widths = grid::unit(widths, width_units),
                             heights = heights, guides = "collect")
  p <- p & ggplot2::theme(legend.position = "right", legend.justification = "top")

  clus_desc <- function(any_h, split) if (!any_h) "none" else if (split) "euclidean/complete within slices" else "euclidean/complete"
  fill_enc <- list(scale = scale_type, palette = as.list(pal), limits = as.list(lim), clip = clip %||% NA, title = value_title)
  if (clipped_ends) fill_enc$clipped_end_labels <- TRUE
  enc <- list(fill = fill_enc, annotation = annot_used)
  if (length(row_annot_used)) enc$row_annotation <- row_annot_used
  dat <- list(n_rows = nr, n_cols = nc, show_row_labels = show_row_labels, show_col_labels = show_col_labels,
              row_order = as.list(rn), col_order = as.list(cn),
              clustering = list(rows = clus_desc(any_hr, split_r), cols = clus_desc(any_hc, split_c)))
  if (split_r) dat$row_slices <- stats::setNames(as.list(r_sizes), levels(rsl))
  if (split_c) dat$col_slices <- stats::setNames(as.list(c_sizes), levels(csl))
  if (!is.null(mark_df)) dat$marked_rows <- as.list(mark_df$id)
  # generic auto caption (callers such as os_top_heatmap() replace it with
  # their own); every number comes from what is drawn
  vt <- if (is.character(value_title)) gsub("\n", " ", value_title) else "value"
  slice_txt <- function(sl, what) sprintf("%s are split into %d groups (%s) separated by gaps", what, nlevels(sl), paste(levels(sl), collapse = ", "))
  cap <- paste0("Heatmap of ", os_num(nr), " rows and ", os_num(nc), " columns; colour, ", vt, ". ",
                if (any_hr || any_hc) paste0(paste(c(if (any_hr) "rows", if (any_hc) "columns"), collapse = " and "),
                                             " are ordered by hierarchical clustering (Euclidean distance, complete linkage",
                                             if (split_r || split_c) ", within each group" else "", "). ") else "",
                if (split_r) paste0(slice_txt(rsl, "Rows"), ". ") else "",
                if (split_c) paste0(slice_txt(csl, "Columns"), ". ") else "",
                if (length(row_annot_used)) paste0("Left bars: ", paste(names(row_annot_used), collapse = ", "), ". ") else "",
                if (length(annot_used)) paste0("Top bars: ", paste(names(annot_used), collapse = ", "), ". ") else "",
                if (!is.null(mark_df)) paste0(nrow(mark_df), " selected rows are labelled. ") else "",
                if (!is.null(clip)) sprintf("Values are clipped at %s%s (%s cells).", "\u00b1", os_num(clip), os_num(clipped_n)) else "")
  meta <- list(p, figure_type = "heatmap", caption = trimws(cap), encodings = enc, data = dat, counts = list(clipped_cells = clipped_n))
  if (!is.null(colour_registry) || (length(row_annot_used) + length(annot_used) > 0 && !identical(reg, colour_registry))) {
    meta$colour_registry <- reg
  }
  do.call(os_with_meta, meta)
}

# Stacked heatmaps (ComplexHeatmap "ht1 + ht2") share one row axis: every
# matrix must have the SAME row ids in the SAME order, otherwise rows of
# different panels silently disagree. Stops with OS_FIG_ROW_MISMATCH.
# mats: list of matrices / data.frames with row names (names used in the
# message). Returns the shared row ids invisibly.
os_heatmap_check_rows <- function(mats) {
  if (!is.list(mats) || length(mats) < 1) stop("OS_INVALID_INPUT: os_heatmap_check_rows needs a list of matrices.", call. = FALSE)
  nm <- names(mats) %||% rep("", length(mats))
  nm[!nzchar(nm)] <- paste0("#", which(!nzchar(nm)))
  ids <- lapply(mats, rownames)
  if (any(vapply(ids, is.null, logical(1)))) {
    stop(sprintf("OS_FIG_ROW_MISMATCH: matrix %s has no row names; stacked heatmaps are aligned by row id.",
                 nm[which(vapply(ids, is.null, logical(1)))[1]]), call. = FALSE)
  }
  ref <- ids[[1]]
  for (i in seq_along(ids)[-1]) {
    cur <- ids[[i]]
    miss <- setdiff(ref, cur); extra <- setdiff(cur, ref)
    if (length(miss) || length(extra) || length(cur) != length(ref)) {
      stop(sprintf(paste0("OS_FIG_ROW_MISMATCH: row sets differ between %s and %s (%d missing, %d extra%s). ",
                          "Stacked heatmaps must show the same rows."),
                   nm[1], nm[i], length(miss), length(extra),
                   if (length(miss) + length(extra)) paste0("; e.g. ", paste(utils::head(c(miss, extra), 3), collapse = ", ")) else "; duplicated ids"),
           call. = FALSE)
    }
    if (!identical(cur, ref)) {
      k <- which(cur != ref)[1]
      stop(sprintf(paste0("OS_FIG_ROW_MISMATCH: row order differs between %s and %s (first difference at row %d: '%s' vs '%s'). ",
                          "Reorder every matrix to one shared row order before stacking."),
                   nm[1], nm[i], k, ref[k], cur[k]), call. = FALSE)
    }
  }
  invisible(ref)
}
