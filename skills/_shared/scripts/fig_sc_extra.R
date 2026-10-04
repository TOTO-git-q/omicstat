# fig_sc_extra.R -- additional single-cell figures (FIGURE_STYLE.md sec 18.2):
# stacked violin, ridge plot, highlight-one-group embedding, alluvial
# (Sankey) plot of per-cell annotations, cluster tree + marker dot plot,
# expression-weighted density on the embedding.
# ASCII only on purpose. Requires fig_style.R and fig_sc.R (re-uses
# os_draw_order, os_cell_point_mm, .os_embedding_axes, os_marker_dotplot;
# fig_sc.R itself is not modified) and fig_heatmap.R (.os_dendro_segments).
#
# Implemented with ggplot2 / grid / patchwork / stats / MASS only (no
# ggridges, ggalluvial or Nebulosa): every density, stratum position and
# flow polygon is computed here, deterministically (no RNG).

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_sc_extra.R.", call. = FALSE)
if (!exists("os_marker_dotplot")) stop("OS_MISSING_DEPENDENCY: source fig_sc.R before fig_sc_extra.R.", call. = FALSE)
if (!exists(".os_dendro_segments")) stop("OS_MISSING_DEPENDENCY: source fig_heatmap.R before fig_sc_extra.R.", call. = FALSE)

OS_FIG_EXT <- utils::modifyList(if (exists("OS_FIG_EXT", inherits = TRUE)) OS_FIG_EXT else list(), list(
  violin_width       = 0.85,  # stacked violin: violin width (fraction of one cluster slot)
  ridge_height       = 1.6,   # ridge plot: tallest ridge, in row units (> 1 = ridges overlap)
  ridge_grid_n       = 512,   # ridge plot: density evaluation points
  alluvial_gap_frac  = 0.03,  # alluvial: gap between strata, fraction of all cells
  alluvial_box_width = 0.08,  # alluvial: stratum box width (axis spacing = 1)
  alluvial_curve_n   = 48,    # alluvial: points per flow edge (smoothstep curve)
  tree_width_mm      = 10,    # cluster tree left of the marker dot plot
  kde_grid_n         = 100    # density embedding: kernel density grid (n x n)
))

.os_need_cols <- function(df, cols, fn) {
  miss <- setdiff(cols, names(df))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMNS: %s needs column(s) %s.", fn, paste(miss, collapse = ", ")), call. = FALSE)
}
# Group levels: factor levels (present ones) or C-locale sorted values.
.os_levels <- function(x, order = NULL) {
  if (!is.null(order)) return(intersect(as.character(order), unique(as.character(x))))
  if (is.factor(x)) return(intersect(levels(x), unique(as.character(x))))
  sort(unique(as.character(x[!is.na(x)])), method = "radix")
}

# ---------------------------------------------------------------------------
# Stacked violin: genes as rows (own y scale each), clusters as columns
# ---------------------------------------------------------------------------
# expr: numeric matrix genes x cells; groups: one label per cell (column).
# fill = "median" (default): each violin filled by the median expression of
#   that gene in that cluster (grey -> purple expression palette, shared
#   limits 0..max) -- the cluster identity is already on the x axis, so
#   colour carries magnitude (scanpy stacked_violin convention).
# fill = "group": registry colour of the cluster (ties the panel to the
#   UMAP colours; > 6 clusters then raise the FIG-02 colour-count warning).
os_stacked_violin <- function(expr, groups, genes = NULL, group_order = NULL, fill = c("median", "group"),
                              colour_registry = NULL, family = "cluster", value_title = "Expression",
                              italic = TRUE, journal = NULL) {
  fill <- match.arg(fill)
  if (!is.matrix(expr) || !is.numeric(expr) || is.null(rownames(expr))) stop("OS_INVALID_INPUT: os_stacked_violin needs a numeric genes x cells matrix with row names.", call. = FALSE)
  if (length(groups) != ncol(expr)) stop("OS_INVALID_INPUT: groups must have one entry per cell (column of expr).", call. = FALSE)
  genes <- genes %||% rownames(expr)
  bad <- setdiff(genes, rownames(expr))
  if (length(bad)) stop(sprintf("OS_MISSING_COLUMNS: genes not in expr: %s.", paste(utils::head(bad, 5), collapse = ", ")), call. = FALSE)
  lv <- .os_levels(groups, group_order)
  os_assert_latin(c(genes, lv), "stacked violin labels")
  keep <- !is.na(groups) & as.character(groups) %in% lv
  g <- factor(as.character(groups[keep]), levels = lv)
  d <- data.frame(.gene = factor(rep(genes, each = sum(keep)), levels = genes),
                  .g = rep(g, times = length(genes)),
                  value = as.vector(t(expr[genes, keep, drop = FALSE])))
  med <- stats::aggregate(value ~ .gene + .g, data = d, FUN = stats::median)
  names(med)[3] <- ".med"
  d <- merge(d, med, by = c(".gene", ".g"), sort = FALSE)
  d <- d[order(d$.gene, d$.g, method = "radix"), , drop = FALSE]
  cr <- NULL
  if (fill == "group") {
    cr <- os_colours_for(lv, family = family, registry = colour_registry)
    fill_scale <- ggplot2::scale_fill_manual(values = cr$colours, breaks = lv, guide = "none")
    d$.f <- d$.g
  } else {
    mx <- max(med$.med, 0)
    fill_scale <- ggplot2::scale_fill_gradientn(colours = OS_PAL_EXPRESSION, limits = c(0, if (mx > 0) mx else 1),
                                                labels = os_axis_labels, guide = os_guide_colourbar("Median\nexpression"))
    d$.f <- d$.med
  }
  # one labelled tick per row: the largest "pretty" value <= 85% of the row maximum
  # (kept clear of the row boundary so it cannot be read as the next row's tick)
  top_break <- function(l) { u <- 0.85 * l[2]; b <- pretty(c(0, u), n = 3); b <- b[b > 0 & b <= u * (1 + 1e-9)]; if (length(b)) max(b) else numeric(0) }
  fam <- os_font_family()
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .g, y = value, fill = .f, group = .g)) +
    ggplot2::geom_violin(scale = "width", width = OS_FIG_EXT$violin_width, trim = TRUE, colour = OS_FIG$col_ink,
                         linewidth = os_lw(OS_FIG$lw_segment)) +
    fill_scale +
    # non-negative data: every row axis starts at exactly 0, so the single
    # labelled tick is read against a known base (stated in the caption)
    (if (min(d$value, na.rm = TRUE) >= 0) ggplot2::expand_limits(y = 0) else NULL) +
    ggplot2::facet_grid(.gene ~ ., scales = "free_y", switch = "y") +
    ggplot2::scale_y_continuous(breaks = top_break, labels = os_axis_labels, expand = ggplot2::expansion(mult = c(0, 0.05)),
                                position = "right") +
    ggplot2::labs(x = NULL, y = NULL) +
    theme_omicstat(journal = journal, legend = if (fill == "median") "right" else "none") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5),
                   axis.text.y.right = ggplot2::element_text(size = os_text_pt(OS_FIG$size_min, journal), margin = ggplot2::margin(l = 0.5, unit = "mm")),
                   axis.ticks.length.y = grid::unit(0.6, "mm"),
                   axis.line.y = ggplot2::element_blank(),
                   panel.border = ggplot2::element_rect(fill = NA, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment)),
                   axis.line.x = ggplot2::element_blank(),
                   panel.spacing.y = grid::unit(0, "mm"),
                   strip.placement = "outside",
                   strip.text.y.left = ggplot2::element_text(angle = 0, hjust = 1, size = OS_FIG$size_axis_text,
                                                             face = if (italic) "italic" else "plain", family = fam,
                                                             margin = ggplot2::margin(r = 1, unit = "mm")))
  n_cells <- sum(keep)
  cap <- paste0("Expression of ", length(genes), " genes (rows) across ", length(lv), " ", family, "s (columns; ",
                os_num(n_cells), " cells). Each violin shows the distribution of per-cell values of one gene in one ",
                family, " (kernel density, width scaled to be equal across violins); each row has its own axis (right, ",
                value_title, if (min(d$value, na.rm = TRUE) >= 0) "; starts at 0 at the row's lower edge, one labelled tick per row" else "; one labelled tick per row",
                "). ",
                if (fill == "median") "Violin colour, median expression of the gene in that group." else paste0("Violin colour, ", family, " (colour registry)."))
  os_with_meta(p, figure_type = "stacked_violin", default_height_mm = min(170, 18 + 6.5 * length(genes)), caption = cap,
               encodings = list(fill = if (fill == "group") as.list(cr$colours) else list(scale = "expression", palette = as.list(OS_PAL_EXPRESSION)),
                                violin_scale = "width"),
               data = list(genes = as.list(genes), groups = as.list(lv), n_cells = n_cells,
                           medians = lapply(split(med, med$.gene), function(x) stats::setNames(as.list(round(x$.med, 6)), as.character(x$.g)))),
               colour_registry = if (!is.null(cr)) cr$registry else colour_registry)
}

# ---------------------------------------------------------------------------
# Ridge plot (own densities; no ggridges)
# ---------------------------------------------------------------------------
# values: one number per cell; groups: one label per cell. Density: Gaussian
# kernel (stats::density) with ONE bandwidth for all groups = Silverman's
# rule of thumb (stats::bw.nrd0) on the pooled values, evaluated on a common
# grid of OS_FIG_EXT$ridge_grid_n points spanning the data range, so ridge
# shapes are comparable. Heights share one scale: the tallest ridge is
# OS_FIG_EXT$ridge_height rows high. First group on top; vertical line in each
# ridge, median. Groups with < 2 cells are listed in the caption, not drawn.
os_ridge <- function(values, groups, feature, group_order = NULL, fill = c("group", "none"),
                     colour_registry = NULL, family = "cluster", value_title = "Expression",
                     italic = TRUE, journal = NULL) {
  fill <- match.arg(fill)
  if (length(values) != length(groups)) stop("OS_INVALID_INPUT: values and groups must have the same length.", call. = FALSE)
  ok <- is.finite(values) & !is.na(groups)
  v <- as.numeric(values[ok]); g <- as.character(groups[ok])
  if (length(v) < 2) stop("OS_EMPTY_DATA: os_ridge needs at least 2 finite values.", call. = FALSE)
  lv <- .os_levels(g, group_order)
  os_assert_latin(c(feature, lv), "ridge plot labels")
  cnt <- table(factor(g, levels = lv))
  drawn <- lv[cnt[lv] >= 2]
  if (!length(drawn)) stop("OS_EMPTY_DATA: no group has at least 2 cells.", call. = FALSE)
  bw <- stats::bw.nrd0(v)
  from <- min(v); to <- max(v)
  if (to <= from) to <- from + 1
  dens <- lapply(drawn, function(k) {
    dd <- stats::density(v[g == k], bw = bw, kernel = "gaussian", n = OS_FIG_EXT$ridge_grid_n, from = from, to = to)
    data.frame(x = dd$x, dens = dd$y, .g = k)
  })
  names(dens) <- drawn
  dmax <- max(vapply(dens, function(x) max(x$dens), numeric(1)))
  nl <- length(lv)
  base <- stats::setNames(rev(seq_len(nl)) - 1, lv)      # first group at the top
  dd <- do.call(rbind, dens)
  dd$base <- unname(base[dd$.g])
  dd$top <- dd$base + dd$dens / dmax * OS_FIG_EXT$ridge_height
  dd$.g <- factor(dd$.g, levels = lv)
  med <- data.frame(.g = factor(drawn, levels = lv), m = vapply(drawn, function(k) stats::median(v[g == k]), numeric(1)))
  med$base <- unname(base[as.character(med$.g)])
  med$top <- med$base + vapply(drawn, function(k) stats::approx(dens[[k]]$x, dens[[k]]$dens, xout = med$m[med$.g == k])$y, numeric(1)) /
    dmax * OS_FIG_EXT$ridge_height
  cr <- if (fill == "group") os_colours_for(lv, family = family, registry = colour_registry) else NULL
  cols <- if (fill == "group") cr$colours else stats::setNames(rep(OS_FIG$col_ns, nl), lv)
  # one ribbon layer per ridge, top ridge first, so each lower ridge is drawn
  # over the one above it (deterministic overlap)
  layers <- lapply(drawn, function(k) {
    ggplot2::geom_ribbon(data = dd[dd$.g == k, ], ggplot2::aes(x = x, ymin = base, ymax = top, fill = .g),
                         colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment), outline.type = "upper")
  })
  med_layers <- lapply(drawn, function(k) {
    ggplot2::geom_segment(data = med[med$.g == k, ], ggplot2::aes(x = m, xend = m, y = base, yend = top),
                          colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment))
  })
  inter <- as.vector(rbind(layers, med_layers))
  p <- ggplot2::ggplot() + inter +
    ggplot2::geom_hline(yintercept = unname(base[drawn]), colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::scale_fill_manual(values = cols, breaks = lv, guide = "none") +
    ggplot2::scale_y_continuous(breaks = unname(base), labels = names(base), expand = ggplot2::expansion(add = c(0, 0.1)),
                                limits = c(0, max(dd$top, nl - 1 + 1))) +
    ggplot2::scale_x_continuous(labels = os_axis_labels, expand = c(0, 0)) +
    ggplot2::labs(x = value_title, y = NULL, title = feature) +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(axis.text.y = ggplot2::element_text(vjust = 0), axis.ticks.y = ggplot2::element_blank(),
                   axis.line.y = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = if (italic) "italic" else "plain"))
  skipped <- setdiff(lv, drawn)
  cap <- paste0(feature, " by ", family, " (", os_num(length(v)), " cells). Each ridge is a Gaussian kernel density of the per-cell values ",
                "(one bandwidth for all groups, ", format(signif(bw, 3)), ", Silverman's rule on the pooled values); ridge heights share one scale. ",
                "Vertical line, median.",
                if (length(skipped)) paste0(" Not drawn (fewer than 2 cells): ", paste(skipped, collapse = ", "), ".") else "")
  os_with_meta(p, figure_type = "ridge", default_height_mm = min(170, 22 + 7 * nl), caption = cap,
               encodings = list(fill = as.list(cols), bandwidth = signif(bw, 8), kernel = "gaussian", bw_rule = "bw.nrd0 (pooled)"),
               counts = as.list(cnt),
               data = list(groups = as.list(lv), medians = stats::setNames(as.list(round(med$m, 6)), drawn), skipped = as.list(skipped)),
               colour_registry = if (!is.null(cr)) cr$registry else colour_registry)
}

# ---------------------------------------------------------------------------
# Highlight one (or a few) groups on the embedding
# ---------------------------------------------------------------------------
# Target cells take their registry colour and are drawn ON TOP; every other
# cell is col_ns grey and drawn underneath (so the target is never hidden).
os_highlight_embedding <- function(emb, group_col, target, colour_registry = NULL, family = group_col,
                                   reduction = c("UMAP", "t-SNE"), label = TRUE, journal = NULL) {
  reduction <- match.arg(reduction)
  .os_need_cols(emb, c("x", "y", group_col), "os_highlight_embedding")
  g <- as.character(emb[[group_col]])
  target <- unique(as.character(target))
  miss <- setdiff(target, g)
  if (length(miss)) stop(sprintf("OS_INVALID_PARAMETER: target group(s) not in '%s': %s.", group_col, paste(miss, collapse = ", ")), call. = FALSE)
  lv <- .os_levels(emb[[group_col]])
  os_assert_latin(target, "highlighted group names")
  cr <- os_colours_for(lv, family = family, registry = colour_registry)
  cols <- cr$colours[target]
  ord <- os_draw_order(nrow(emb))
  d <- emb[ord, , drop = FALSE]; gd <- g[ord]
  is_t <- gd %in% target
  bg <- d[!is_t, , drop = FALSE]
  fg <- d[is_t, , drop = FALSE]; fg$.g <- factor(gd[is_t], levels = target)
  pt <- os_cell_point_mm(nrow(d))
  xr <- range(d$x); yr <- range(d$y)
  l_bg <- os_points_layer(ggplot2::geom_point(data = bg, ggplot2::aes(x = x, y = y), colour = OS_FIG$col_ns,
                                              shape = OS_FIG$shape_dense, size = pt, stroke = 0), nrow(d))
  l_fg <- os_points_layer(ggplot2::geom_point(data = fg, ggplot2::aes(x = x, y = y, colour = .g),
                                              shape = OS_FIG$shape_dense, size = pt, stroke = 0), nrow(d))
  p <- ggplot2::ggplot() + l_bg$layer + l_fg$layer +
    ggplot2::scale_colour_manual(values = cols, breaks = target,
                                 guide = if (label) "none" else ggplot2::guide_legend(title = group_col, title.position = "top",
                                                                                     override.aes = list(size = 2))) +
    ggplot2::coord_fixed(ratio = diff(xr) / diff(yr), clip = "off") +
    theme_omicstat(journal = journal, axes = "none", legend = if (label) "none" else "right") +
    ggplot2::theme(axis.title = ggplot2::element_blank())
  p <- .os_embedding_axes(p, xr, yr, paste(reduction, "1"), paste(reduction, "2"))
  if (label) {
    cen <- stats::aggregate(cbind(x, y) ~ .g, data = fg, FUN = stats::median)
    names(cen)[1] <- "lab"
    p <- p + os_label_repel(cen, ggplot2::aes(x = x, y = y, label = lab), italic = FALSE, journal = journal,
                            size_pt = OS_FIG$size_annot, inherit.aes = FALSE, segment.size = 0, box.padding = 0.05)
  }
  n_t <- as.integer(table(factor(gd[is_t], levels = target)))
  rast <- l_bg$rasterised || l_fg$rasterised
  cap <- sprintf("%s embedding of %s cells; %s highlighted in colour (%s), all other cells in grey and drawn underneath.%s",
                 reduction, os_num(nrow(d)), paste(target, collapse = ", "),
                 paste(sprintf("%s, n = %s, %s%%", target, os_num(n_t), formatC(100 * n_t / nrow(d), format = "f", digits = 1)), collapse = "; "),
                 if (rast) sprintf(" Cells are rendered as a %d dpi bitmap layer; text and axes are vector.", OS_FIG$raster_dpi) else "")
  os_with_meta(p, figure_type = "highlight_embedding", default_height_mm = 80, caption = cap,
               encodings = list(colour = as.list(cols), background = OS_FIG$col_ns, point_mm = pt),
               counts = stats::setNames(as.list(n_t), target), data = list(n_cells = nrow(d), target = as.list(target)),
               colour_registry = cr$registry, notes = list(rasterised_points = rast))
}

# ---------------------------------------------------------------------------
# Alluvial / Sankey plot of two or more per-cell annotations
# ---------------------------------------------------------------------------
# df: one row per cell; axes: column names in left-to-right order (e.g.
# c("cluster", "celltype")). Strata (boxes) are stacked top-to-bottom with
# gaps of OS_FIG_EXT$alluvial_gap_frac x cells; their heights are cell
# counts. Stratum order: axis 1 in level order (factor levels, else
# C-locale); later axes in level order when the column is a factor, else by
# BARYCENTRE -- descending mean position (in the previous axis) of their
# cells, ties by name -- which removes most avoidable crossings. A flow
# between neighbouring axes is one polygon per (first-axis category, left
# category, right category) combination whose width is its cell count; its
# edges are smoothstep curves (3t^2 - 2t^3). Flows are coloured by the FIRST
# axis ("source") category from the colour registry and keep that colour
# across all later axes; the first-axis strata carry the same colour, later
# strata are white boxes (two registry families never share a colour in one
# panel). Flows are opaque (no alpha) and drawn largest first, so small flows
# stay visible. Missing values become "Unassigned" (grey, last). Labels
# "name (n)": left of the first axis, right of the last axis (own label
# columns, leader lines), centred on middle axes.
os_alluvial <- function(df, axes, axis_labels = axes, colour_registry = NULL, family = axes[1],
                        label_min_frac = 0.01, journal = NULL) {
  if (length(axes) < 2) stop("OS_INVALID_PARAMETER: os_alluvial needs at least two annotation columns.", call. = FALSE)
  .os_need_cols(df, axes, "os_alluvial")
  N <- nrow(df)
  if (!N) stop("OS_EMPTY_DATA: os_alluvial got no cells.", call. = FALSE)
  K <- length(axes)
  na_lab <- "Unassigned"
  vals <- lapply(axes, function(a) { x <- as.character(df[[a]]); x[is.na(x)] <- na_lab; x })
  gap <- OS_FIG_EXT$alluvial_gap_frac * N
  bw <- OS_FIG_EXT$alluvial_box_width
  hk <- vapply(seq_len(K), function(k) N + gap * (length(unique(vals[[k]])) - 1), numeric(1))
  H <- max(hk)
  # strata of axis k given its level order (y grows upwards; all axes centred)
  .strata <- function(k, lv) {
    n <- as.integer(table(factor(vals[[k]], levels = lv)))
    tops <- (H + hk[k]) / 2 - c(0, cumsum(n + gap))[seq_along(n)]
    data.frame(axis = k, cat = lv, n = n, ymax = tops, ymin = tops - n, stringsAsFactors = FALSE)
  }
  levs <- vector("list", K); st <- vector("list", K); ordering <- character(K)
  for (k in seq_len(K)) {
    l <- .os_levels(df[[axes[k]]])
    if (k > 1 && !is.factor(df[[axes[k]]])) {
      prev <- st[[k - 1]]
      ymid <- (prev$ymin + prev$ymax)[match(vals[[k - 1]], prev$cat)] / 2
      bc <- tapply(ymid, factor(vals[[k]], levels = l), mean)
      l <- l[order(-bc, l, method = "radix")]
      ordering[k] <- "barycentre"
    } else ordering[k] <- "levels"
    l <- setdiff(l, na_lab)
    if (any(vals[[k]] == na_lab)) l <- c(l, na_lab)
    levs[[k]] <- l
    st[[k]] <- .strata(k, l)
  }
  os_assert_latin(c(unlist(levs), axis_labels), "alluvial labels")
  src_lv <- setdiff(levs[[1]], na_lab)
  cr <- os_colours_for(src_lv, family = family, registry = colour_registry)
  src_cols <- c(cr$colours[src_lv], if (na_lab %in% levs[[1]]) stats::setNames(OS_FIG$col_na, na_lab))
  strata <- do.call(rbind, st)
  st_key <- paste(strata$axis, strata$cat, sep = "\r")
  # flows
  src <- vals[[1]]
  flows <- list()
  for (k in seq_len(K - 1)) {
    tab <- as.data.frame(table(src = factor(src, levels = levs[[1]]), a = factor(vals[[k]], levels = levs[[k]]),
                               b = factor(vals[[k + 1]], levels = levs[[k + 1]])), stringsAsFactors = FALSE)
    tab <- tab[tab$Freq > 0, , drop = FALSE]
    si <- match(tab$src, levs[[1]]); ai <- match(tab$a, levs[[k]]); bi <- match(tab$b, levs[[k + 1]])
    # left side: within stratum a, ordered by (b, src); right side: within b, by (a, src)
    ol <- order(ai, bi, si, method = "radix"); orr <- order(bi, ai, si, method = "radix")
    tab$yl_top <- NA_real_; tab$yr_top <- NA_real_
    for (s in unique(tab$a)) {
      idx <- ol[tab$a[ol] == s]
      top <- strata$ymax[match(paste(k, s, sep = "\r"), st_key)]
      tab$yl_top[idx] <- top - c(0, cumsum(tab$Freq[idx]))[seq_along(idx)]
    }
    for (s in unique(tab$b)) {
      idx <- orr[tab$b[orr] == s]
      top <- strata$ymax[match(paste(k + 1, s, sep = "\r"), st_key)]
      tab$yr_top[idx] <- top - c(0, cumsum(tab$Freq[idx]))[seq_along(idx)]
    }
    tab$k <- k
    flows[[k]] <- tab
  }
  flows <- do.call(rbind, flows)
  flows <- flows[order(-flows$Freq, flows$k, match(flows$src, levs[[1]]), flows$a, flows$b, method = "radix"), , drop = FALSE]
  flows$id <- seq_len(nrow(flows))
  tt <- seq(0, 1, length.out = OS_FIG_EXT$alluvial_curve_n)
  ss <- 3 * tt^2 - 2 * tt^3
  poly <- do.call(rbind, lapply(seq_len(nrow(flows)), function(i) {
    f <- flows[i, ]
    x0 <- f$k + bw / 2; x1 <- f$k + 1 - bw / 2
    xs <- x0 + (x1 - x0) * tt
    top <- f$yl_top + (f$yr_top - f$yl_top) * ss
    data.frame(id = f$id, x = c(xs, rev(xs)), y = c(top, rev(top - f$Freq)), src = f$src)
  }))
  poly$id <- factor(poly$id, levels = flows$id)
  strata$fill <- ifelse(strata$axis == 1, unname(src_cols[strata$cat]), OS_FIG$col_bg)
  strata$lab <- sprintf("%s (%s)", strata$cat, os_num(strata$n))
  strata$ymid <- (strata$ymin + strata$ymax) / 2
  strata$labelled <- strata$n >= label_min_frac * N & strata$n > 0
  strata <- strata[strata$n > 0, , drop = FALSE]
  lab_pt <- os_text_pt(OS_FIG$size_annot, journal)
  lab_first <- strata[strata$axis == 1 & strata$labelled, ]
  lab_last <- strata[strata$axis == K & strata$labelled, ]
  lab_mid <- strata[strata$axis > 1 & strata$axis < K & strata$labelled, ]
  main <- ggplot2::ggplot() +
    ggplot2::geom_polygon(data = poly, ggplot2::aes(x = x, y = y, group = id, fill = src), colour = NA) +
    ggplot2::geom_rect(data = strata, ggplot2::aes(xmin = axis - bw / 2, xmax = axis + bw / 2, ymin = ymin, ymax = ymax),
                       fill = strata$fill, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::scale_fill_manual(values = src_cols, breaks = names(src_cols), guide = "none") +
    ggplot2::scale_x_continuous(breaks = seq_len(K), labels = axis_labels, position = "top", expand = c(0, 0)) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::coord_cartesian(xlim = c(1 - bw / 2, K + bw / 2), ylim = c(0, H), clip = "off") +
    theme_omicstat(journal = journal, axes = "none", legend = "none") +
    ggplot2::theme(axis.text.x.top = ggplot2::element_text(size = OS_FIG$size_axis_title, margin = ggplot2::margin(b = 1.5, unit = "mm")),
                   plot.margin = ggplot2::margin(OS_FIG$plot_margin_mm[1], 0, OS_FIG$plot_margin_mm[3], 0, unit = "mm"))
  if (nrow(lab_mid)) main <- main + os_label_repel(lab_mid, ggplot2::aes(x = axis, y = ymid, label = lab), italic = FALSE,
                                                   journal = journal, size_pt = OS_FIG$size_annot, direction = "y",
                                                   box.padding = 0.08, point.padding = 0, min.segment.length = 0.5)
  # side label columns: anchors on the edge that touches the boxes
  lead_mm <- 1.5
  .side <- function(lab, side) {
    text_mm <- max(nchar(lab$lab)) * 0.55 * lab_pt * MM_PER_IN / 72
    w <- lead_mm + text_mm + 1
    fr <- lead_mm / w
    lab$ax <- if (side == "left") 1 else 0
    pl <- ggplot2::ggplot(lab, ggplot2::aes(x = ax, y = ymid)) +
      os_label_repel(lab, ggplot2::aes(x = ax, y = ymid, label = lab), italic = FALSE, journal = journal,
                     size_pt = OS_FIG$size_annot, nudge_x = if (side == "left") -fr else fr, hjust = if (side == "left") 1 else 0,
                     direction = "y", box.padding = 0.08, point.padding = 0, inherit.aes = FALSE) +
      ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
      ggplot2::scale_y_continuous(limits = c(0, H), expand = c(0, 0)) +
      ggplot2::coord_cartesian(clip = "off") +
      ggplot2::theme_void() +
      ggplot2::theme(plot.margin = ggplot2::margin(OS_FIG$plot_margin_mm[1], if (side == "right") OS_FIG$plot_margin_mm[2] else 0,
                                                   OS_FIG$plot_margin_mm[3], if (side == "left") OS_FIG$plot_margin_mm[4] else 0, unit = "mm"))
    list(plot = pl, w = w + if (side == "left") OS_FIG$plot_margin_mm[4] else OS_FIG$plot_margin_mm[2])
  }
  cells <- list(); widths <- numeric(0); units <- character(0)
  if (nrow(lab_first)) { s <- .side(lab_first, "left"); cells <- c(cells, list(s$plot)); widths <- c(widths, s$w); units <- c(units, "mm") }
  cells <- c(cells, list(main)); widths <- c(widths, 1); units <- c(units, "null")
  if (nrow(lab_last)) { s <- .side(lab_last, "right"); cells <- c(cells, list(s$plot)); widths <- c(widths, s$w); units <- c(units, "mm") }
  p <- patchwork::wrap_plots(cells, nrow = 1, widths = grid::unit(widths, units))
  n_unlab <- sum(!strata$labelled)
  cap <- paste0("Correspondence between ", paste(axis_labels, collapse = " and "), " for ", os_num(N), " cells. ",
                "Boxes are categories (height proportional to the number of cells, given in parentheses); bands connect the same cells ",
                "across annotations, have widths proportional to their cell counts and are coloured by ", axis_labels[1], ".",
                if (any(ordering[-1] == "barycentre")) paste0(" Categories of ", paste(axis_labels[-1][ordering[-1] == "barycentre"], collapse = " and "),
                                                                 " are ordered to follow their cells' positions on the preceding axis.") else "",
                if (na_lab %in% unlist(levs)) " Cells without an annotation are shown as Unassigned (grey)." else "",
                if (n_unlab) sprintf(" %d categories with fewer than %s%% of cells are not labelled.", n_unlab, format(100 * label_min_frac)) else "")
  flow_list <- lapply(seq_len(nrow(flows)), function(i) list(axis = flows$k[i], source = flows$src[i], from = flows$a[i], to = flows$b[i], n = flows$Freq[i]))
  os_with_meta(p, figure_type = "alluvial", default_height_mm = 80, caption = cap,
               encodings = list(fill = as.list(src_cols), flow_colour_by = axes[1]),
               counts = list(cells = N, strata = lapply(split(strata, strata$axis), function(s) stats::setNames(as.list(s$n), s$cat))),
               data = list(axes = as.list(axes), strata_order = stats::setNames(lapply(levs, as.list), axes),
                           strata_ordering = as.list(stats::setNames(ordering, axes)), flows = flow_list),
               colour_registry = cr$registry)
}

# ---------------------------------------------------------------------------
# Cluster tree + marker dot plot
# ---------------------------------------------------------------------------
# md: as os_marker_dotplot (cluster, gene, avg_exp, pct_exp). profiles:
# numeric matrix clusters x features used for the tree (e.g. mean expression
# of variable genes); default = the avg_exp matrix of md. Tree: Euclidean
# distance + complete linkage (as the heatmap engine); clusters on the dot
# plot follow the leaf order (first leaf on top). The dot plot itself is
# os_marker_dotplot() unchanged; the tree is drawn to its left (patchwork).
os_cluster_tree_dotplot <- function(md, gene_order = NULL, profiles = NULL, scaled = TRUE, clip = 2,
                                    profile_label = NULL, mean_definition = NULL, journal = NULL) {
  .os_need_cols(md, c("cluster", "gene", "avg_exp", "pct_exp"), "os_cluster_tree_dotplot")
  cl <- sort(unique(as.character(md$cluster)), method = "radix")
  if (is.null(profiles)) {
    genes <- unique(as.character(md$gene))
    profiles <- matrix(NA_real_, length(cl), length(genes), dimnames = list(cl, genes))
    profiles[cbind(match(md$cluster, cl), match(md$gene, genes))] <- md$avg_exp
    profiles[is.na(profiles)] <- 0
    profile_label <- profile_label %||% "marker expression profiles (avg_exp of the plotted genes)"
  } else {
    if (!is.matrix(profiles) || is.null(rownames(profiles))) stop("OS_INVALID_INPUT: profiles must be a clusters x features matrix with row names.", call. = FALSE)
    miss <- setdiff(cl, rownames(profiles))
    if (length(miss)) stop(sprintf("OS_INVALID_PARAMETER: profiles has no row for cluster(s): %s.", paste(miss, collapse = ", ")), call. = FALSE)
    profiles <- profiles[cl, , drop = FALSE]
    profile_label <- profile_label %||% sprintf("mean profiles over %d features", ncol(profiles))
  }
  if (length(cl) < 3) stop("OS_EMPTY_DATA: a cluster tree needs at least 3 clusters.", call. = FALSE)
  hc <- stats::hclust(stats::dist(profiles, method = "euclidean"), method = "complete")
  c_ord <- cl[hc$order]
  # mean_definition is REQUIRED by os_marker_dotplot (FIGURE_STYLE sec 16);
  # passed through unchanged so the caption states it.
  dot <- os_marker_dotplot(md, gene_order = gene_order, cluster_order = c_ord, scaled = scaled, clip = clip,
                           mean_definition = mean_definition, journal = journal)
  n <- length(cl)
  seg <- .os_dendro_segments(hc)
  # leaf k (k-th in order) sits at y = n + 1 - k: first cluster on top, like the dot plot
  tree <- ggplot2::ggplot(seg) +
    ggplot2::geom_segment(ggplot2::aes(x = -y, xend = -yend, y = n + 1 - x, yend = n + 1 - xend),
                          linewidth = os_lw(OS_FIG$lw_segment), colour = OS_FIG$col_ink, lineend = "square") +
    ggplot2::scale_y_continuous(limits = c(0.4, n + 0.6), expand = c(0, 0)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0))) +
    ggplot2::theme_void() + ggplot2::theme(plot.margin = ggplot2::margin(0, 0, 0, 0))
  p <- patchwork::wrap_plots(tree, dot, ncol = 2, widths = grid::unit(c(OS_FIG_EXT$tree_width_mm, 1), c("mm", "null")))
  dm <- attr(dot, "os_meta")
  cap <- paste0("Clusters are ordered by hierarchical clustering (Euclidean distance, complete linkage) of their ", profile_label,
                "; the tree is drawn on the left. ", dm$caption)
  os_with_meta(p, figure_type = "cluster_tree_dotplot", default_height_mm = dm$default_height_mm, caption = cap,
               encodings = dm$encodings,
               data = utils::modifyList(dm$data, list(cluster_order = as.list(c_ord), tree = list(method = "euclidean/complete",
                                                                                                    heights = as.list(round(hc$height, 6))))))
}

# ---------------------------------------------------------------------------
# Expression-weighted kernel density on the embedding (Nebulosa-style)
# ---------------------------------------------------------------------------
# Weighted 2-D Gaussian kernel density on an n x n grid, computed exactly as
# MASS::kde2d (bandwidth h = MASS::bandwidth.nrd per axis, kernel sd = h/4,
# grid over the data range) but with each cell weighted by its expression
# (negative values count as 0). With values = NULL all weights are 1 and the
# grid equals MASS::kde2d. The density at each cell is bilinearly
# interpolated from the grid and shown relative to its maximum (0-1,
# viridis); cells are drawn in ascending density.
os_kde2d_weighted <- function(x, y, w = NULL, n = OS_FIG_EXT$kde_grid_n, h = NULL, lims = c(range(x), range(y))) {
  nx <- length(x)
  w <- if (is.null(w)) rep(1, nx) else pmax(as.numeric(w), 0)
  if (!is.finite(sum(w)) || sum(w) <= 0) stop("OS_EMPTY_DATA: all density weights are zero.", call. = FALSE)
  h <- h %||% c(MASS::bandwidth.nrd(x), MASS::bandwidth.nrd(y))
  h <- h / 4
  gx <- seq.int(lims[1L], lims[2L], length.out = n)
  gy <- seq.int(lims[3L], lims[4L], length.out = n)
  ax <- outer(gx, x, "-") / h[1L]
  ay <- outer(gy, y, "-") / h[2L]
  kx <- matrix(stats::dnorm(ax), n, nx)
  ky <- matrix(stats::dnorm(ay), n, nx)
  z <- tcrossprod(sweep(kx, 2, w, "*"), ky) / (sum(w) * h[1L] * h[2L])
  list(x = gx, y = gy, z = z, h = h * 4)
}

.os_bilinear <- function(g, x, y) {
  ix <- findInterval(x, g$x, all.inside = TRUE); iy <- findInterval(y, g$y, all.inside = TRUE)
  fx <- (x - g$x[ix]) / (g$x[ix + 1] - g$x[ix]); fy <- (y - g$y[iy]) / (g$y[iy + 1] - g$y[iy])
  z <- g$z
  (1 - fx) * (1 - fy) * z[cbind(ix, iy)] + fx * (1 - fy) * z[cbind(ix + 1, iy)] +
    (1 - fx) * fy * z[cbind(ix, iy + 1)] + fx * fy * z[cbind(ix + 1, iy + 1)]
}

os_density_embedding <- function(emb, values = NULL, feature = NULL, reduction = c("UMAP", "t-SNE"),
                                 italic = TRUE, journal = NULL) {
  reduction <- match.arg(reduction)
  .os_need_cols(emb, c("x", "y"), "os_density_embedding")
  if (!is.null(values) && length(values) != nrow(emb)) stop("OS_INVALID_INPUT: values must have one entry per cell.", call. = FALSE)
  title <- feature %||% (if (is.null(values)) "Cell density" else "Weighted density")
  os_assert_latin(title, "density title")
  g <- os_kde2d_weighted(emb$x, emb$y, values)
  dens <- .os_bilinear(g, emb$x, emb$y)
  rel <- dens / max(dens)
  d <- emb; d$.v <- rel
  d <- d[order(d$.v, os_draw_order(nrow(d)), method = "radix"), , drop = FALSE]
  xr <- range(d$x); yr <- range(d$y)
  pts <- os_points_layer(ggplot2::geom_point(shape = OS_FIG$shape_dense, size = os_cell_point_mm(nrow(d)), stroke = 0), nrow(d))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y, colour = .v)) +
    pts$layer +
    ggplot2::scale_colour_gradientn(colours = OS_PAL_SEQUENTIAL, limits = c(0, 1), labels = os_axis_labels,
                                    guide = os_guide_colourbar("Relative\ndensity")) +
    ggplot2::coord_fixed(ratio = diff(xr) / diff(yr), clip = "off") +
    ggplot2::labs(title = title) +
    theme_omicstat(journal = journal, axes = "none", legend = "right") +
    ggplot2::theme(axis.title = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = if (italic && !is.null(feature)) "italic" else "plain"))
  p <- .os_embedding_axes(p, xr, yr, paste(reduction, "1"), paste(reduction, "2"))
  n_w <- if (is.null(values)) nrow(emb) else sum(values > 0, na.rm = TRUE)
  cap <- paste0(if (is.null(values)) "Density of cells" else paste0("Expression-weighted density of ", title),
                " on the ", reduction, " embedding (", os_num(nrow(emb)), " cells",
                if (!is.null(values)) paste0(", ", os_num(n_w), " with non-zero expression") else "", "). ",
                "Two-dimensional Gaussian kernel density (MASS::kde2d formulation, ", OS_FIG_EXT$kde_grid_n, " x ", OS_FIG_EXT$kde_grid_n,
                " grid, normal-reference bandwidths ", format(signif(g$h[1], 3)), " and ", format(signif(g$h[2], 3)), ")",
                if (!is.null(values)) ", each cell weighted by its expression" else "",
                "; colour, density at each cell relative to the maximum. Cells are drawn in order of increasing density.",
                if (pts$rasterised) sprintf(" Cells are rendered as a %d dpi bitmap layer; text and axes are vector.", OS_FIG$raster_dpi) else "")
  os_with_meta(p, figure_type = "density_embedding", default_height_mm = 70, caption = cap,
               encodings = list(colour = list(scale = "sequential", palette = as.list(OS_PAL_SEQUENTIAL), limits = list(0, 1))),
               data = list(n_cells = nrow(emb), bandwidth = as.list(signif(g$h, 8)), grid_n = OS_FIG_EXT$kde_grid_n,
                           weighted = !is.null(values)),
               notes = list(rasterised_points = pts$rasterised))
}
