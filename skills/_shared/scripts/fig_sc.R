# fig_sc.R -- standard single-cell figures: embedding (UMAP/t-SNE) coloured
# by cluster or cell type, feature (expression) embedding, marker dot plot,
# cell-type proportion bars, per-sample QC violins, score violins.
# ASCII only on purpose. Requires fig_style.R.
#
# Ecosystem-neutral: every function takes plain data.frames, so Seurat and
# SingleCellExperiment chains produce identical figures from identical
# numbers (ENGINEERING_PLAN 1.3).

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_sc.R.", call. = FALSE)

# Deterministic pseudo-shuffle of draw order (no RNG): Knuth multiplicative
# hash of the row index. Drawing cells in a fixed, group-independent order
# prevents the last-drawn cluster from hiding the others.
os_draw_order <- function(n) order((as.numeric(seq_len(n)) * 2654435761) %% 4294967296, method = "radix")

# Point size by cell count (mm): fewer cells, larger points.
os_cell_point_mm <- function(n) if (n <= 2000) 0.8 else if (n <= 10000) 0.5 else if (n <= 50000) OS_FIG$pt_cell_mm else 0.15

# L-shaped axis guide in the bottom-left corner with "UMAP 1"/"UMAP 2":
# embedding coordinates are arbitrary, so no ticks or numbers are drawn.
.os_embedding_axes <- function(p, xr, yr, xlab, ylab) {
  fam <- os_font_family()
  x0 <- xr[1] - 0.02 * diff(xr); y0 <- yr[1] - 0.02 * diff(yr)
  lx <- 0.18 * diff(xr); ly <- 0.18 * diff(yr)
  arr <- grid::arrow(length = grid::unit(1.2, "mm"), type = "closed", angle = 25)
  p + ggplot2::annotate("segment", x = x0, y = y0, xend = x0 + lx, yend = y0, linewidth = os_lw(OS_FIG$lw_axis),
                        colour = OS_FIG$col_ink, arrow = arr) +
    ggplot2::annotate("segment", x = x0, y = y0, xend = x0, yend = y0 + ly, linewidth = os_lw(OS_FIG$lw_axis),
                      colour = OS_FIG$col_ink, arrow = arr) +
    ggplot2::annotate("text", x = x0, y = y0 - 0.035 * diff(yr), label = xlab, hjust = 0, vjust = 1,
                      size = os_fs(OS_FIG$size_axis_text), family = fam) +
    ggplot2::annotate("text", x = x0 - 0.035 * diff(xr), y = y0, label = ylab, hjust = 0, vjust = 0, angle = 90,
                      size = os_fs(OS_FIG$size_axis_text), family = fam)
}

# Opt-in label style "halo" (os_embedding(label_style = "halo")): a wider
# white halo behind each category name and label-label repulsion with a thin
# leader back to the anchor when a label has to move. Same ggrepel layer,
# seed and iteration budget as every other repelled label (os_label_repel);
# no new dependency. The default "plain" style is untouched.
OS_FIG_EXT <- utils::modifyList(if (exists("OS_FIG_EXT", inherits = TRUE)) OS_FIG_EXT else list(), list(
  label_halo_rings     = c(0.15, 0.30, 0.45),  # halo ring radii, fraction of text height (plain: one ring 0.12)
  label_halo_pad_mm    = 1.2,   # free space kept around each label box, mm
  label_halo_leader_mm = 2.5    # a leader is drawn only when a label moved further than this, mm
))

# emb: data.frame(cell, x, y, <group_col>). Categories get registry colours;
# with label = TRUE category names are written at the group medians (direct
# labelling) and the legend is dropped.
os_embedding <- function(emb, group_col, label = TRUE, colour_registry = NULL, family = group_col,
                         reduction = c("UMAP", "t-SNE"), legend_ncol = NULL, journal = NULL, label_xy = NULL,
                         display_max_per_group = NULL, display_n_input = NULL,
                         label_island_eps = NULL, label_island_min_samples = NULL,
                         label_style = c("plain", "halo")) {
  reduction <- match.arg(reduction)
  label_style <- match.arg(label_style)
  for (cc in c("x", "y", group_col)) if (!cc %in% names(emb)) stop(sprintf("OS_MISSING_COLUMNS: os_embedding needs '%s'.", cc), call. = FALSE)
  d <- emb[os_draw_order(nrow(emb)), , drop = FALSE]
  g <- as.character(d[[group_col]])
  lv <- if (is.factor(emb[[group_col]])) levels(emb[[group_col]]) else sort(unique(g), method = "radix")
  cr <- os_colours_for(lv, family = family, registry = colour_registry)
  cols <- cr$colours
  d$.g <- factor(g, levels = lv)
  os_assert_latin(lv, "category names")
  pt <- os_cell_point_mm(nrow(d))
  xr <- range(d$x); yr <- range(d$y)
  pts <- os_points_layer(ggplot2::geom_point(shape = OS_FIG$shape_dense, size = pt, stroke = 0), nrow(d))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y, colour = .g)) +
    pts$layer +
    ggplot2::scale_colour_manual(values = cols, breaks = lv,
                                 guide = if (label) "none" else ggplot2::guide_legend(title = group_col, title.position = "top",
                                                                                     ncol = legend_ncol %||% if (length(lv) > 12) 2 else 1,
                                                                                     override.aes = list(size = 2))) +
    ggplot2::coord_fixed(ratio = diff(xr) / diff(yr), clip = "off") +
    theme_omicstat(journal = journal, axes = "none", legend = if (label) "none" else "right") +
    ggplot2::theme(axis.title = ggplot2::element_blank())
  p <- .os_embedding_axes(p, xr, yr, paste(reduction, "1"), paste(reduction, "2"))
  if (label) {
    if (is.null(label_xy)) {
      cen <- stats::aggregate(cbind(x, y) ~ .g, data = d, FUN = stats::median)
      names(cen)[1] <- "lab"
    } else {
      if (!all(c("group", "x", "y") %in% names(label_xy)) ||
          anyDuplicated(label_xy$group) || !setequal(as.character(label_xy$group), unique(g)) ||
          any(!is.finite(label_xy$x)) || any(!is.finite(label_xy$y)))
        stop("OS_INVALID_INPUT: label_xy requires one finite group/x/y row per drawn category.", call. = FALSE)
      cen <- label_xy[, c("group", "x", "y")]; names(cen)[1] <- "lab"
    }
    if (identical(label_style, "halo")) {
      # ggrepel draws a halo as 16 copies on ONE ring, which leaves gaps at a
      # wide radius; the outer rings are separate white layers with identical
      # data, padding and seed (so identical placement), the ink text on top.
      rings <- sort(OS_FIG_EXT$label_halo_rings, decreasing = TRUE)
      for (i in seq_along(rings)) {
        top <- i == length(rings)
        p <- p + os_label_repel(cen, ggplot2::aes(x = x, y = y, label = lab), italic = FALSE, journal = journal,
                                size_pt = OS_FIG$size_annot, inherit.aes = FALSE,
                                box.padding = grid::unit(OS_FIG_EXT$label_halo_pad_mm, "mm"), point.padding = 0,
                                min.segment.length = grid::unit(OS_FIG_EXT$label_halo_leader_mm, "mm"),
                                bg.r = rings[i], colour = if (top) OS_FIG$col_ink else OS_FIG$col_bg,
                                segment.size = if (top) os_lw(OS_FIG$lw_segment) else 0)
      }
    } else {
      p <- p + os_label_repel(cen, ggplot2::aes(x = x, y = y, label = lab), italic = FALSE, journal = journal,
                              size_pt = OS_FIG$size_annot, inherit.aes = FALSE, segment.size = 0, box.padding = 0.05)
    }
  }
  counts <- as.list(table(factor(g, levels = lv)))
  cap <- sprintf(paste0("%s embedding of %s cells coloured by %s (%d categories). %s%s"),
                 reduction, os_num(nrow(d)), group_col, length(lv),
                 if (label) if (is.null(label_xy)) "Category names are placed at the median position of their cells." else "Category names use explicitly supplied coordinates (largest-island medians when requested)." else "",
                 if (pts$rasterised) sprintf(" Cells are rendered as a %d dpi bitmap layer; text and axes are vector.", OS_FIG$raster_dpi) else "")
  if (label && identical(label_style, "halo")) {
    cap <- paste0(cap, " Labels carry a white halo and are spaced apart by deterministic repulsion (fixed seed); a thin leader joins a moved label to its anchor.")
  }
  if (!is.null(label_island_eps)) {
    cap <- paste0(cap, sprintf(" Labels use largest-island medians from per-category DBSCAN (eps=%s embedding units; min_samples=%d).", os_num(label_island_eps), label_island_min_samples))
  }
  if (!is.null(label_xy) && "label_fallback" %in% names(label_xy) && any(label_xy$label_fallback)) {
    cap <- paste0(cap, sprintf(" %d categories have no density-supported island; labels fall back to their all-cell median.", sum(label_xy$label_fallback)))
  }
  if (!is.null(display_max_per_group)) {
    cap <- paste0(cap, sprintf(" Display only: at most %d cells per group are drawn (%d of %d cells); analysis objects and downstream tables are unchanged.",
                              display_max_per_group, nrow(d), display_n_input))
  }
  meta_data <- list(n_cells = nrow(d))
  meta_notes <- list(rasterised_points = pts$rasterised)
  if (!is.null(label_xy)) meta_notes$label_xy <- label_xy
  if (label && identical(label_style, "halo")) meta_notes$label_style <- label_style
  if (!is.null(label_island_eps)) {
    meta_notes$label_island_eps <- label_island_eps
    meta_notes$label_island_min_samples <- label_island_min_samples
  }
  if (!is.null(display_max_per_group)) {
    meta_data$display_only <- TRUE
    meta_data$display_max_per_group <- display_max_per_group
    meta_data$display_n_input <- display_n_input
  }
  os_with_meta(p, figure_type = "embedding", default_height_mm = 80, caption = cap,
               encodings = list(colour = as.list(cols), point_mm = pt),
               counts = counts, data = meta_data, colour_registry = cr$registry,
               notes = meta_notes)
}

# Expression on the embedding: grey (zero) -> purple (high); cells drawn in
# ascending expression so expressing cells are on top. Title is the gene
# symbol in italics.
os_feature_embedding <- function(emb, values, feature, reduction = c("UMAP", "t-SNE"), value_title = "Expression",
                                 italic = TRUE, journal = NULL) {
  reduction <- match.arg(reduction)
  d <- emb; d$.v <- as.numeric(values)
  d <- d[order(d$.v, os_draw_order(nrow(d)), method = "radix"), , drop = FALSE]
  xr <- range(d$x); yr <- range(d$y)
  lim <- c(0, max(d$.v, na.rm = TRUE))
  pts <- os_points_layer(ggplot2::geom_point(shape = OS_FIG$shape_dense, size = os_cell_point_mm(nrow(d)), stroke = 0), nrow(d))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y, colour = .v)) +
    pts$layer +
    ggplot2::scale_colour_gradientn(colours = OS_PAL_EXPRESSION, limits = lim, labels = os_axis_labels,
                                    guide = ggplot2::guide_colourbar(title = value_title, title.position = "top",
                                                                     barwidth = grid::unit(OS_FIG$legend_key_mm * 0.8, "mm"),
                                                                     barheight = grid::unit(OS_FIG$legend_key_mm * 4, "mm"),
                                                                     frame.colour = OS_FIG$col_ink, ticks.colour = OS_FIG$col_ink)) +
    ggplot2::coord_fixed(ratio = diff(xr) / diff(yr), clip = "off") +
    ggplot2::labs(title = feature) +
    theme_omicstat(journal = journal, axes = "none", legend = "right") +
    ggplot2::theme(axis.title = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = if (italic) "italic" else "plain"))
  p <- .os_embedding_axes(p, xr, yr, paste(reduction, "1"), paste(reduction, "2"))
  os_with_meta(p, figure_type = "feature_embedding", default_height_mm = 70,
               caption = sprintf("%s expression on the %s embedding (%s cells); cells are drawn in order of increasing expression.%s",
                                 feature, reduction, os_num(nrow(d)),
                                 if (pts$rasterised) sprintf(" Cells are rendered as a %d dpi bitmap layer; text and axes are vector.", OS_FIG$raster_dpi) else ""),
               encodings = list(colour = list(scale = "expression", palette = as.list(OS_PAL_EXPRESSION))),
               notes = list(rasterised_points = pts$rasterised))
}

# Marker dot plot. md: data.frame(cluster, gene, avg_exp, pct_exp[, n_cells])
# where avg_exp is either scaled (z-score across clusters, scaled = TRUE ->
# diverging, clipped at +/- clip) or unscaled mean expression (scaled = FALSE
# -> expression palette). pct_exp in 0..100. Genes keep the caller's order
# (marker panels are ordered by cluster), clusters on y in level order.
#
# mean_definition is REQUIRED (no default): the common tools compute
# "average expression" differently, so the caption must say which one the
# numbers are (docs/FIGURE_STYLE.md sec 8.11). The builder does not compute
# it -- it only states what the caller computed:
#   "log_mean"          mean of log-normalised values (scanpy, SCpubr)
#   "log1p_mean_expm1"  log1p(mean(expm1(x))) (Seurat DotPlot)
#   "nonzero_mean"      mean over expressing (non-zero) cells only (dittoSeq)
# Cells per cluster (caption only) come from cluster_n (named: cluster ->
# number of cells) or, if absent, from an n_cells column of md.
OS_MEAN_DEFINITIONS <- c(
  log_mean         = "mean of log-normalised values",
  log1p_mean_expm1 = "log1p(mean(expm1(x))), the log of the mean of back-transformed values (Seurat convention)",
  nonzero_mean     = "mean over expressing cells only (cells with non-zero expression)"
)
OS_ZSCORE_MIN_GROUPS <- 5L   # z-scoring across fewer groups exaggerates differences (Seurat DotPlot warning)

os_marker_dotplot <- function(md, gene_order = NULL, cluster_order = NULL, scaled = TRUE, clip = 2,
                              mean_definition, cluster_n = NULL, descriptive_note = TRUE, journal = NULL) {
  if (missing(mean_definition) || is.null(mean_definition)) {
    stop(sprintf("OS_MISSING_PARAMETER: os_marker_dotplot needs mean_definition (one of %s); it is stated in the caption.",
                 paste(names(OS_MEAN_DEFINITIONS), collapse = ", ")), call. = FALSE)
  }
  if (length(mean_definition) != 1 || !mean_definition %in% names(OS_MEAN_DEFINITIONS)) {
    stop(sprintf("OS_INVALID_PARAMETER: mean_definition must be one of %s.", paste(names(OS_MEAN_DEFINITIONS), collapse = ", ")),
         call. = FALSE)
  }
  for (cc in c("cluster", "gene", "avg_exp", "pct_exp")) if (!cc %in% names(md)) stop(sprintf("OS_MISSING_COLUMNS: os_marker_dotplot needs '%s'.", cc), call. = FALSE)
  mean_def <- unname(OS_MEAN_DEFINITIONS[mean_definition])
  d <- md
  g_lv <- gene_order %||% unique(as.character(d$gene))
  c_lv <- cluster_order %||% sort(unique(as.character(d$cluster)), method = "radix")
  d$.x <- factor(as.character(d$gene), levels = g_lv)
  d$.y <- factor(as.character(d$cluster), levels = rev(c_lv))
  os_assert_latin(c(g_lv, c_lv), "marker plot labels")
  # cells per cluster (caption only; nothing is computed from it)
  if (is.null(cluster_n) && "n_cells" %in% names(md)) {
    cn <- md[!duplicated(as.character(md$cluster)), c("cluster", "n_cells")]
    cluster_n <- stats::setNames(cn$n_cells, as.character(cn$cluster))
  }
  n_cl <- if (!is.null(cluster_n)) cluster_n[intersect(c_lv, names(cluster_n))] else NULL
  d <- d[d$pct_exp > 0, , drop = FALSE]
  n_clipped <- 0L
  if (scaled) {
    n_clipped <- sum(abs(d$avg_exp) > clip, na.rm = TRUE)
    d$.c <- pmax(pmin(d$avg_exp, clip), -clip)
    col_scale <- ggplot2::scale_colour_gradientn(colours = OS_PAL_DIVERGING, limits = c(-clip, clip),
                                                 breaks = c(-clip, -clip / 2, 0, clip / 2, clip),
                                                 labels = os_clipped_labels(-clip, clip),
                                                 guide = os_guide_colourbar("Scaled\nexpression"))
  } else {
    d$.c <- d$avg_exp
    col_scale <- ggplot2::scale_colour_gradientn(colours = OS_PAL_EXPRESSION, limits = c(0, max(md$avg_exp)), labels = os_axis_labels,
                                                 guide = os_guide_colourbar("Mean\nexpression"))
  }
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .x, y = .y)) +
    ggplot2::geom_point(ggplot2::aes(size = pct_exp, colour = .c), shape = 16, stroke = 0) +
    col_scale +
    ggplot2::scale_size_continuous(range = c(0.3, 3.2), limits = c(0, 100), breaks = c(25, 50, 75, 100),
                                   guide = ggplot2::guide_legend(title = "% expressing", title.position = "top",
                                                                 override.aes = list(colour = OS_FIG$col_ink))) +
    ggplot2::labs(x = NULL, y = NULL) +
    theme_omicstat(journal = journal, axes = "box") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5, face = "italic"))
  few_groups <- scaled && length(c_lv) < OS_ZSCORE_MIN_GROUPS
  cap <- paste0("Marker gene expression by cluster (", length(c_lv), " clusters",
                if (length(n_cl)) paste0("; ", os_n_label(n_cl, "cells", per = "cluster")) else "", "). ",
                "Dot size, percentage of cells in the cluster with non-zero expression; colour, ",
                if (scaled) paste0("mean expression scaled across clusters (z-score, clipped at ", "\u00b1", os_num(clip), "); ",
                                   os_clip_note(n_clipped, nrow(d), clip, "dots"))
                else "mean expression",
                ". Mean expression definition: ", mean_def, ".",
                if (few_groups) paste0(" QC: z-scores are computed across only ", length(c_lv),
                                       " clusters; scaling across fewer than ", OS_ZSCORE_MIN_GROUPS,
                                       " groups exaggerates differences.") else "",
                if (descriptive_note) " Markers describe clusters and are not tests of differences between conditions." else "")
  os_with_meta(p, figure_type = "marker_dotplot", default_height_mm = min(170, max(55, 20 + 4 * length(c_lv))), caption = cap,
               encodings = list(size = list(range_mm = list(0.3, 3.2), limits = list(0, 100)),
                                colour = if (scaled) list(scale = "diverging", limits = list(-clip, clip), clipped_end_labels = TRUE)
                                         else list(scale = "expression")),
               thresholds = if (scaled) list(clip = clip) else list(),
               counts = c(list(dots_drawn = nrow(d)), if (scaled) list(clipped_cells = n_clipped) else list(),
                          if (length(n_cl)) list(cells_per_cluster = as.list(n_cl)) else list()),
               definition = list(mean_expression = mean_definition, mean_expression_text = mean_def,
                                 colour = if (scaled) "z-score of mean expression across clusters" else "mean expression"),
               notes = if (few_groups) list(qc_scaled_few_groups = sprintf("z-scored across %d < %d groups; scaling across fewer than %d groups exaggerates differences",
                                                                           length(c_lv), OS_ZSCORE_MIN_GROUPS, OS_ZSCORE_MIN_GROUPS))
                       else list(),
               data = list(genes = as.list(g_lv), clusters = as.list(c_lv)))
}

# Cell-type proportions per sample, faceted by condition. pd: data.frame(sample,
# condition, celltype, n). Stacks follow the category (registry) order,
# first category at the top.
os_proportion_bar <- function(pd, colour_registry = NULL, family = "celltype", condition_order = NULL, journal = NULL) {
  for (cc in c("sample", "condition", "celltype", "n")) if (!cc %in% names(pd)) stop(sprintf("OS_MISSING_COLUMNS: os_proportion_bar needs '%s'.", cc), call. = FALSE)
  lv <- sort(unique(as.character(pd$celltype)), method = "radix")
  cr <- os_colours_for(lv, family = family, registry = colour_registry)
  tot <- stats::aggregate(n ~ sample, data = pd, FUN = sum); names(tot)[2] <- "tot"
  d <- merge(pd, tot, by = "sample")
  d$prop <- d$n / d$tot
  # first category stacked at the TOP and listed first in the legend, so
  # the legend reads in the same top-to-bottom order as the bars
  d$.ct <- factor(as.character(d$celltype), levels = lv)
  c_lv <- condition_order %||% sort(unique(as.character(d$condition)), method = "radix")
  d$.cond <- factor(as.character(d$condition), levels = c_lv)
  s_ord <- unique(d[order(d$.cond, d$sample, method = "radix"), "sample"])
  d$.s <- factor(d$sample, levels = s_ord)
  # n with its unit: samples per condition (the unit of replication) on the
  # strip, cells per sample in the caption
  n_samp <- vapply(c_lv, function(cn) length(unique(d$sample[d$.cond == cn])), integer(1))
  # A facet is only as wide as its bars: with < 5 samples in some condition
  # the n line is split ("n = 3" / "samples") so it never overflows the
  # strip, even in a narrow composite panel.
  n_txt <- vapply(n_samp, os_n_label, character(1), unit = "samples")
  strip_lab <- stats::setNames(if (min(n_samp) < 5) paste0(c_lv, "\n", sub(" (samples?)$", "\n\\1", n_txt))
                               else paste0(c_lv, "\n(", n_txt, ")"), c_lv)
  cells_per_sample <- tot$tot[match(s_ord, tot$sample)]
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .s, y = prop, fill = .ct)) +
    ggplot2::geom_col(width = 0.8, colour = OS_FIG$col_bg, linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::facet_grid(. ~ .cond, scales = "free_x", space = "free_x", labeller = ggplot2::as_labeller(strip_lab)) +
    ggplot2::scale_fill_manual(values = cr$colours, breaks = lv,
                               guide = ggplot2::guide_legend(title = family, title.position = "top", ncol = if (length(lv) > 12) 2 else 1)) +
    ggplot2::scale_y_continuous(labels = os_axis_labels_pct, limits = c(0, 1.0001), expand = c(0, 0),
                                breaks = seq(0, 1, 0.25)) +
    ggplot2::labs(x = NULL, y = OS_AXIS$prop_cells) +
    theme_omicstat(journal = journal) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5),
                   axis.ticks.x = ggplot2::element_blank(), panel.spacing = grid::unit(2, "mm"))
  cap <- sprintf(paste0("Proportion of cells assigned to each %s in each sample (%d samples, %s cells), grouped by condition ",
                        "(%s); %s. Each bar is one sample, the unit of replication. ",
                        "Proportions are descriptive; differences between conditions are tested separately at the sample level."),
                 family, length(s_ord), os_num(sum(pd$n)),
                 paste(sprintf("%s, %s", c_lv, vapply(n_samp, os_n_label, character(1), unit = "samples")), collapse = "; "),
                 os_n_label(cells_per_sample, "cells", per = "sample"))
  os_with_meta(p, figure_type = "proportion_bar", default_height_mm = 65, caption = cap,
               encodings = list(fill = as.list(cr$colours)), data = list(samples = as.list(s_ord)),
               counts = list(samples_per_condition = as.list(n_samp), cells_per_sample = as.list(stats::setNames(cells_per_sample, s_ord))),
               colour_registry = cr$registry)
}

# Per-sample QC violins. qc: data.frame(sample, <metric columns>). thresholds:
# named list metric -> numeric vector of cut-offs (dashed). log10_metrics are
# drawn on a log10 axis labelled in real units (1,000 not 3). One stacked
# panel per metric (each with its own axis); sample labels only on the bottom
# panel.
os_qc_violin <- function(qc, metrics, thresholds = list(), metric_labels = NULL, log10_metrics = character(0),
                         group_col = NULL, reference = NULL, journal = NULL) {
  mlab <- metric_labels %||% stats::setNames(metrics, metrics)
  s_lv <- sort(unique(as.character(qc$sample)), method = "radix")
  grp <- if (is.null(group_col)) rep("all", nrow(qc)) else as.character(qc[[group_col]])
  fills <- if (is.null(group_col)) c(all = OS_FIG$col_ns) else os_group_colours(sort(unique(grp), method = "radix"), reference)
  panels <- lapply(seq_along(metrics), function(i) {
    m <- metrics[i]
    d <- data.frame(s = factor(qc$sample, levels = s_lv), v = qc[[m]], g = grp)
    is_log <- m %in% log10_metrics
    if (is_log) d$v <- pmax(d$v, 1)
    p <- ggplot2::ggplot(d, ggplot2::aes(x = s, y = v))
    if (!is.null(thresholds[[m]])) p <- p + os_hline(thresholds[[m]])
    p <- p + ggplot2::geom_violin(ggplot2::aes(fill = g), scale = "width", width = 0.8, colour = OS_FIG$col_ink,
                                  linewidth = os_lw(OS_FIG$lw_segment), draw_quantiles = 0.5) +
      ggplot2::scale_fill_manual(values = fills, guide = if (is.null(group_col) || i > 1) "none" else os_guide_legend(group_col)) +
      (if (is_log) ggplot2::scale_y_log10(labels = function(x) os_num(x), breaks = scales::breaks_log(n = 4))
       else ggplot2::scale_y_continuous(labels = os_axis_labels)) +
      ggplot2::labs(x = NULL, y = unname(mlab[m])) +
      theme_omicstat(journal = journal, legend = if (is.null(group_col)) "none" else "right")
    if (i < length(metrics)) {
      p <- p + ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank())
    } else {
      p <- p + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, vjust = 0.5))
    }
    p
  })
  p <- patchwork::wrap_plots(panels, ncol = 1, guides = "collect")
  # n with its unit: x labels stay sample ids; cells per sample go in the caption
  cells_per_sample <- as.integer(table(factor(as.character(qc$sample), levels = s_lv)))
  grp_n <- if (is.null(group_col)) NULL else {
    sg <- unique(data.frame(s = as.character(qc$sample), g = grp, stringsAsFactors = FALSE))
    g_lv <- sort(unique(sg$g), method = "radix")
    stats::setNames(vapply(g_lv, function(g) length(unique(sg$s[sg$g == g])), integer(1)), g_lv)
  }
  cap <- paste0("Per-cell quality-control metrics by sample (", length(s_lv), " samples, ", os_num(nrow(qc)),
                " cells before filtering; ", os_n_label(cells_per_sample, "cells", per = "sample"),
                if (!is.null(grp_n)) paste0("; ", paste(sprintf("%s, %s", names(grp_n), vapply(grp_n, os_n_label, character(1), unit = "samples")),
                                                        collapse = "; ")) else "",
                "). ",
                "Violins are scaled to equal width; horizontal line inside each violin, median; dashed lines, filtering thresholds",
                if (length(log10_metrics)) paste0("; ", paste(unname(mlab[log10_metrics]), collapse = " and "), " on a log10 axis") else "", ".")
  os_with_meta(p, figure_type = "qc_violin", default_height_mm = 25 + 30 * length(metrics), caption = cap,
               thresholds = thresholds,
               counts = list(cells_per_sample = as.list(stats::setNames(cells_per_sample, s_lv))))
}

# Score violins by cluster / cell type (module score, AUCell, GSVA per cell).
os_score_violin <- function(df, group_col, value_col, value_title, colour_registry = NULL, family = group_col, journal = NULL) {
  lv <- sort(unique(as.character(df[[group_col]])), method = "radix")
  cr <- os_colours_for(lv, family = family, registry = colour_registry)
  d <- data.frame(g = factor(as.character(df[[group_col]]), levels = lv), v = df[[value_col]])
  p <- ggplot2::ggplot(d, ggplot2::aes(x = g, y = v, fill = g)) +
    ggplot2::geom_violin(scale = "width", width = 0.8, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment),
                         draw_quantiles = 0.5) +
    ggplot2::scale_fill_manual(values = cr$colours, guide = "none") +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = NULL, y = value_title) +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1))
  n_grp <- as.integer(table(d$g))
  os_with_meta(p, figure_type = "score_violin", default_height_mm = 55,
               caption = sprintf(paste0("%s per cell by %s (%s cells; %s). Violins are scaled to equal width; horizontal line, median. ",
                                        "Cells are not independent replicates: cells from the same sample share its biology and processing, ",
                                        "so differences between groups must be tested at the sample level, not across cells."),
                                 value_title, group_col, os_num(nrow(d)), os_n_label(n_grp, "cells", per = "group")),
               encodings = list(fill = as.list(cr$colours)),
               counts = list(cells_per_group = as.list(stats::setNames(n_grp, lv))), colour_registry = cr$registry)
}
