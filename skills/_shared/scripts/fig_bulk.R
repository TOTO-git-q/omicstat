# fig_bulk.R -- standard bulk-omics figures: volcano, MA, sample PCA, sample
# distance heatmap, top-feature heatmap, generic diagnostic scatter/line.
# ASCII only on purpose. Requires fig_style.R and fig_heatmap.R.
#
# Every builder:
#   * takes a tidy table (feature_table columns where applicable),
#   * reads every visual constant from OS_FIG / OS_PAL_* (fig_style.R),
#   * returns a ggplot/patchwork with attr "os_meta" (figure_type, caption,
#     encodings, thresholds, counts, data rows used) for os_save_figure(),
#   * is deterministic: row order, label choice and z-order are fully
#     specified below, and ggrepel gets a fixed seed.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_bulk.R.", call. = FALSE)
if (!requireNamespace("ggrepel", quietly = TRUE)) stop("OS_MISSING_PACKAGE: ggrepel is required by fig_bulk.R.", call. = FALSE)


.os_require_cols <- function(df, cols, fn) {
  miss <- setdiff(cols, names(df))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMNS: %s needs column(s) %s.", fn, paste(miss, collapse = ", ")), call. = FALSE)
}

# Direction class used by volcano and MA (identical rule in both).
os_de_class <- function(log2fc, padj, padj_threshold, lfc_threshold) {
  cls <- rep("ns", length(log2fc))
  sig <- !is.na(padj) & padj < padj_threshold
  cls[sig & log2fc > lfc_threshold] <- "up"
  cls[sig & log2fc < -lfc_threshold] <- "down"
  cls[is.na(padj)] <- "na"
  cls
}

# Deterministic label selection: top n per direction by padj, ties broken by
# |log2fc| (larger first) then feature_id (C-locale).
os_pick_labels <- function(df, n_per_side = 10, genes = NULL) {
  if (!is.null(genes)) {
    hit <- df$feature_id %in% genes | (!is.null(df$symbol) & df$symbol %in% genes)
    return(df$feature_id[hit])
  }
  pick <- character(0)
  for (d in c("up", "down")) {
    s <- df[df$de_class == d, , drop = FALSE]
    if (!nrow(s)) next
    o <- order(s$padj, -abs(s$log2fc), s$feature_id, method = "radix")
    pick <- c(pick, s$feature_id[utils::head(o, n_per_side)])
  }
  pick
}

.os_display_symbol <- function(df) {
  sym <- if ("symbol" %in% names(df)) as.character(df$symbol) else rep(NA_character_, nrow(df))
  ifelse(is.na(sym) | !nzchar(sym), as.character(df$feature_id), sym)
}

.os_count_key <- function(p, x, y, hjust, colour, text) {
  fam <- os_font_family()
  gap <- 0.0
  p + ggplot2::annotate("point", x = x, y = y, colour = colour, size = OS_FIG$pt_highlight_mm * 1.6, shape = 16) +
    ggplot2::annotate("text", x = x, y = y, label = text, hjust = hjust, vjust = 0.5,
                      size = os_fs(OS_FIG$size_annot), family = fam, colour = OS_FIG$col_ink)
}

# Label data for volcano / MA (os_label_place, fig_style.R sec 12b): the
# labelled points in priority order, then the most significant other
# coloured points as unlabelled obstacles (label ""), so labels stay off the
# coloured point cloud and off each other. Added 2026-09-27 after the pasilla
# anchor (8,148 genes) showed ggrepel label-label overlaps in the container.
# Volcano and MA get their panel shape from the figure height, not from a
# fixed theme(aspect.ratio).
OS_LABEL_MAX_OBSTACLES <- 300L
.os_label_rows <- function(d, lab, priority) {
  lab <- lab[order(priority, lab$feature_id, method = "radix"), , drop = FALSE]
  rep <- d[!d$feature_id %in% lab$feature_id & d$de_class %in% c("up", "down"), , drop = FALSE]
  rep <- rep[order(rep$padj, rep$feature_id, method = "radix"), , drop = FALSE]
  rep <- utils::head(rep, OS_LABEL_MAX_OBSTACLES)
  rep$display <- rep("", nrow(rep))
  rbind(lab[, c("x", "y", "display")], rep[, c("x", "y", "display")])
}

# ---------------------------------------------------------------------------
# Volcano plot
# ---------------------------------------------------------------------------
# x: log2FC (symmetric limits), y: -log10(padj) from 0. Colour: up = col_up,
# down = col_down, ns = col_ns. Rows with padj = NA (independent filtering)
# are not drawn and are counted in the caption. Dashed lines at +/-
# lfc_threshold and -log10(padj_threshold). Counts sit in the top corners
# (down top-left, up top-right) as direct labels -- no legend box.
os_volcano <- function(ft, padj_threshold = 0.05, lfc_threshold = 1, label_n = 10, label_genes = NULL,
                       x_max = NULL, y_max = NULL, contrast_label = NULL, method_label = NULL,
                       italic_labels = TRUE, journal = NULL) {
  .os_require_cols(ft, c("feature_id", "log2fc", "padj"), "os_volcano")
  fam <- os_font_family()
  d <- ft
  d$de_class <- os_de_class(d$log2fc, d$padj, padj_threshold, lfc_threshold)
  n_na <- sum(d$de_class == "na")
  d <- d[d$de_class != "na" & is.finite(d$log2fc), , drop = FALSE]
  d$y <- -log10(d$padj)
  finite_y <- d$y[is.finite(d$y)]
  y_cap <- y_max %||% if (any(!is.finite(d$y))) ceiling(max(finite_y, 1) * 1.05) else NULL
  x_lim <- x_max %||% os_sym_limit(d$log2fc, min_abs = max(lfc_threshold * 1.5, 1))
  d$capped <- (!is.null(y_cap) & (!is.finite(d$y) | d$y > (y_cap %||% Inf))) | abs(d$log2fc) > x_lim
  if (!is.null(y_cap)) d$y[!is.finite(d$y) | d$y > y_cap] <- y_cap
  d$x <- pmax(pmin(d$log2fc, x_lim), -x_lim)
  # z-order: ns first, then down/up by increasing significance (most significant on top)
  d$z <- ifelse(d$de_class == "ns", 0, 1)
  d <- d[order(d$z, d$y, abs(d$log2fc), d$feature_id, method = "radix"), , drop = FALSE]
  d$display <- .os_display_symbol(d)
  lab_ids <- os_pick_labels(d, label_n, label_genes)
  lab <- d[d$feature_id %in% lab_ids, , drop = FALSE]
  os_assert_latin(lab$display, "volcano labels")
  pal <- c(up = OS_FIG$col_up, down = OS_FIG$col_down, ns = OS_FIG$col_ns)
  # Header band: the top 12% of the panel is reserved for the Up/Down counts;
  # data labels are kept below it (repel ylim) so they can never collide.
  y_dmax <- max(c(d$y, -log10(padj_threshold)), na.rm = TRUE)
  y_top <- y_dmax * 1.16
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    os_hline(-log10(padj_threshold))
  if (lfc_threshold > 0) p <- p + os_vline(c(-lfc_threshold, lfc_threshold))
  p <- p +
    ggplot2::geom_point(data = d[!d$capped, ], ggplot2::aes(colour = de_class), shape = OS_FIG$shape_dense,
                        size = OS_FIG$pt_dense_mm, stroke = 0) +
    ggplot2::geom_point(data = d[d$capped, ], ggplot2::aes(colour = de_class), shape = OS_FIG$shape_capped,
                        size = OS_FIG$pt_dense_mm * 1.3, stroke = 0) +
    ggplot2::geom_point(data = lab[!lab$capped, ], ggplot2::aes(fill = de_class), shape = 21, colour = OS_FIG$col_ink,
                        size = OS_FIG$pt_highlight_mm, stroke = os_lw(OS_FIG$lw_point_edge)) +
    ggplot2::geom_point(data = lab[lab$capped, ], ggplot2::aes(fill = de_class), shape = 24, colour = OS_FIG$col_ink,
                        size = OS_FIG$pt_highlight_mm * 1.1, stroke = os_lw(OS_FIG$lw_point_edge)) +
    os_label_place(.os_label_rows(d, lab, -lab$y), ggplot2::aes(label = display), italic = italic_labels,
                   ymax = y_dmax * 1.05, journal = journal) +
    ggplot2::scale_colour_manual(values = pal, guide = "none") +
    ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::scale_x_continuous(limits = c(-x_lim, x_lim), labels = os_axis_labels,
                                expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::scale_y_continuous(limits = c(0, y_top), labels = os_axis_labels,
                                expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(x = OS_AXIS$log2fc, y = OS_AXIS$neglog10padj, title = contrast_label) +
    theme_omicstat(journal = journal, legend = "none")
  n_up <- sum(d$de_class == "up"); n_down <- sum(d$de_class == "down"); n_ns <- sum(d$de_class == "ns")
  xr <- 2 * x_lim
  p <- .os_count_key(p, -x_lim + 0.03 * xr, y_top * 0.985, 0, OS_FIG$col_down, "")
  p <- p + ggplot2::annotate("text", x = -x_lim + 0.065 * xr, y = y_top * 0.985, hjust = 0, vjust = 0.5,
                             label = sprintf("Down: %s", os_num(n_down)), size = os_fs(OS_FIG$size_annot), family = fam)
  p <- .os_count_key(p, x_lim - 0.03 * xr, y_top * 0.985, 1, OS_FIG$col_up, "")
  p <- p + ggplot2::annotate("text", x = x_lim - 0.065 * xr, y = y_top * 0.985, hjust = 1, vjust = 0.5,
                             label = sprintf("Up: %s", os_num(n_up)), size = os_fs(OS_FIG$size_annot), family = fam)
  n_capped <- sum(d$capped)
  cap <- paste0(
    "Volcano plot", if (!is.null(contrast_label)) paste0(" (", contrast_label, ")") else "", ". ",
    "Each point is one feature; ", os_num(nrow(d)), " features with an adjusted P value are shown",
    if (n_na > 0) paste0(" (", os_num(n_na), " features with adjusted P = NA after independent filtering are not shown)") else "",
    ". Red, up-regulated (n = ", os_num(n_up), "); blue, down-regulated (n = ", os_num(n_down),
    "); grey, not significant (n = ", os_num(n_ns), "). Significance: adjusted P < ", padj_threshold,
    if (lfc_threshold > 0) paste0(" and |log2 fold change| > ", lfc_threshold) else "",
    if (!is.null(method_label)) paste0(" (", method_label, ")") else "",
    ". Dashed lines mark these thresholds. ",
    if (is.null(label_genes)) paste0("The ", label_n, " most significant features per direction are labelled.")
    else "Labelled features were pre-specified.",
    if (n_capped > 0) paste0(" ", n_capped, " features beyond the axis limits are drawn as triangles at the limit.") else ""
  )
  os_with_meta(p, figure_type = "volcano", default_height_mm = 92, caption = cap,
               encodings = list(colour = as.list(pal), shape = list(point = OS_FIG$shape_dense, capped = OS_FIG$shape_capped)),
               thresholds = list(padj = padj_threshold, abs_log2fc = lfc_threshold),
               counts = list(up = n_up, down = n_down, ns = n_ns, padj_na = n_na, capped = n_capped),
               data = list(labelled_feature_ids = as.list(sort(lab$feature_id, method = "radix")),
                           x_limit = x_lim, y_cap = y_cap %||% NA))
}

# ---------------------------------------------------------------------------
# MA plot (DESeq2 plotMA convention: x = mean of normalized counts on a log10
# axis, y = log2FC, out-of-range values drawn as triangles at the limit)
# ---------------------------------------------------------------------------
os_ma <- function(ft, padj_threshold = 0.05, lfc_threshold = 0, label_n = 10, label_genes = NULL,
                  y_max = NULL, contrast_label = NULL, method_label = NULL, italic_labels = TRUE, journal = NULL) {
  .os_require_cols(ft, c("feature_id", "base_mean", "log2fc", "padj"), "os_ma")
  fam <- os_font_family()
  d <- ft[is.finite(ft$base_mean) & ft$base_mean > 0 & is.finite(ft$log2fc), , drop = FALSE]
  d$de_class <- os_de_class(d$log2fc, d$padj, padj_threshold, lfc_threshold)
  d$de_class[d$de_class == "na"] <- "ns"
  y_lim <- y_max %||% os_sym_limit(d$log2fc, min_abs = 1)
  d$capped <- abs(d$log2fc) > y_lim
  d$y <- pmax(pmin(d$log2fc, y_lim), -y_lim)
  d$x <- log10(d$base_mean)
  d$z <- ifelse(d$de_class == "ns", 0, 1)
  d <- d[order(d$z, -d$padj, d$feature_id, method = "radix", na.last = FALSE), , drop = FALSE]
  d$display <- .os_display_symbol(d)
  lab <- d[d$feature_id %in% os_pick_labels(d, label_n, label_genes), , drop = FALSE]
  pal <- c(up = OS_FIG$col_up, down = OS_FIG$col_down, ns = OS_FIG$col_ns)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref))
  if (lfc_threshold > 0) p <- p + os_hline(c(-lfc_threshold, lfc_threshold))
  p <- p +
    ggplot2::geom_point(data = d[!d$capped, ], ggplot2::aes(colour = de_class), shape = OS_FIG$shape_dense,
                        size = OS_FIG$pt_dense_mm, stroke = 0) +
    ggplot2::geom_point(data = d[d$capped, ], ggplot2::aes(colour = de_class), shape = OS_FIG$shape_capped,
                        size = OS_FIG$pt_dense_mm * 1.3, stroke = 0) +
    ggplot2::geom_point(data = lab[!lab$capped, ], ggplot2::aes(fill = de_class), shape = 21, colour = OS_FIG$col_ink,
                        size = OS_FIG$pt_highlight_mm, stroke = os_lw(OS_FIG$lw_point_edge)) +
    ggplot2::geom_point(data = lab[lab$capped, ], ggplot2::aes(fill = de_class), shape = 24, colour = OS_FIG$col_ink,
                        size = OS_FIG$pt_highlight_mm * 1.1, stroke = os_lw(OS_FIG$lw_point_edge)) +
    os_label_place(.os_label_rows(d, lab, lab$padj), ggplot2::aes(label = display), italic = italic_labels, journal = journal) +
    ggplot2::scale_colour_manual(values = pal, guide = "none") +
    ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::scale_x_continuous(labels = function(b) parse(text = paste0("10^", b)),
                                breaks = function(l) seq(floor(l[1]), ceiling(l[2]), by = 1)) +
    ggplot2::scale_y_continuous(limits = c(-y_lim, y_lim), labels = os_axis_labels,
                                expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::labs(x = "Mean of normalized counts", y = OS_AXIS$log2fc, title = contrast_label) +
    theme_omicstat(journal = journal, legend = "none")
  n_up <- sum(d$de_class == "up"); n_down <- sum(d$de_class == "down")
  cap <- paste0("MA plot", if (!is.null(contrast_label)) paste0(" (", contrast_label, ")") else "", ". ",
                "x axis, mean of normalized counts (log10 scale); y axis, log2 fold change",
                if (!is.null(method_label)) paste0(" (", method_label, ")") else "", ". ",
                "Red, up-regulated (n = ", os_num(n_up), "); blue, down-regulated (n = ", os_num(n_down),
                "); adjusted P < ", padj_threshold,
                if (lfc_threshold > 0) paste0(" and |log2 fold change| > ", lfc_threshold) else "", ". ",
                if (sum(d$capped)) paste0(sum(d$capped), " features beyond the y limits are drawn as triangles at the limit.") else "")
  os_with_meta(p, figure_type = "ma", default_height_mm = 70, caption = cap,
               encodings = list(colour = as.list(pal)),
               thresholds = list(padj = padj_threshold, abs_log2fc = lfc_threshold),
               counts = list(up = n_up, down = n_down, capped = sum(d$capped)),
               data = list(labelled_feature_ids = as.list(sort(lab$feature_id, method = "radix")), y_limit = y_lim))
}

# ---------------------------------------------------------------------------
# PCA of samples
# ---------------------------------------------------------------------------
# os_pca_scores(): DESeq2::plotPCA-equivalent computation on a transformed
# matrix (rows features, cols samples): top `ntop` rows by variance, prcomp
# with centring and no scaling, then SIGN NORMALIZATION (ENGINEERING_PLAN
# lock 4: in every PC the loading with the largest |value| is made positive)
# so the plot never mirrors between platforms.
os_pca_scores <- function(mat, ntop = 500) {
  rv <- apply(mat, 1, stats::var)
  o <- order(-rv, rownames(mat), method = "radix")
  sel <- utils::head(o, min(ntop, length(rv)))
  pc <- stats::prcomp(t(mat[sel, , drop = FALSE]), center = TRUE, scale. = FALSE)
  for (k in seq_len(ncol(pc$rotation))) {
    i <- which.max(abs(pc$rotation[, k]))
    if (pc$rotation[i, k] < 0) { pc$rotation[, k] <- -pc$rotation[, k]; pc$x[, k] <- -pc$x[, k] }
  }
  pv <- pc$sdev^2 / sum(pc$sdev^2)
  list(scores = data.frame(sample = rownames(pc$x), pc$x[, 1:min(5, ncol(pc$x)), drop = FALSE],
                           check.names = FALSE, stringsAsFactors = FALSE),
       percent_var = 100 * pv, ntop = length(sel))
}

# scores: data.frame(sample, PC1, PC2, ...); coldata: data.frame(sample, <group_col>, [<shape_col>]).
os_pca_plot <- function(pca, coldata, group_col, shape_col = NULL, reference = NULL, pcs = c(1, 2),
                        label_samples = FALSE, colour_registry = NULL, journal = NULL) {
  sc <- merge(pca$scores, coldata, by = "sample", sort = FALSE)
  sc <- sc[order(sc$sample, method = "radix"), , drop = FALSE]
  xs <- paste0("PC", pcs[1]); ys <- paste0("PC", pcs[2])
  sc$.x <- sc[[xs]]; sc$.y <- sc[[ys]]
  grp <- as.character(sc[[group_col]])
  lv <- if (is.factor(coldata[[group_col]])) levels(coldata[[group_col]]) else sort(unique(grp), method = "radix")
  if (!is.null(reference)) lv <- c(reference, setdiff(lv, reference))
  cols <- if (!is.null(colour_registry)) os_colours_for(lv, "group", colour_registry, reference = reference)$colours
          else os_group_colours(lv, reference = reference)
  sc$.g <- factor(grp, levels = lv)
  fam <- os_font_family()
  if (!is.null(shape_col)) {
    slv <- sort(unique(as.character(sc[[shape_col]])), method = "radix")
    if (length(slv) > length(OS_FIG$shape_sample_sequence)) stop("OS_TOO_MANY_CATEGORIES: more than 5 shape levels.", call. = FALSE)
    sc$.s <- factor(as.character(sc[[shape_col]]), levels = slv)
  }
  pv <- pca$percent_var
  # Axes on a common scale (DESeq2 plotPCA convention) while the panel stays
  # readable: if the y/x data-range ratio is within [0.4, 2.5] use
  # coord_fixed; otherwise a free 0.75 aspect, disclosed in the caption.
  rr <- diff(range(sc$.y)) / max(diff(range(sc$.x)), 1e-12)
  common_scale <- rr >= 0.4 && rr <= 2.5
  pca_coord <- if (common_scale) ggplot2::coord_fixed(ratio = 1) else ggplot2::coord_cartesian()
  pts <- if (is.null(shape_col)) {
    ggplot2::geom_point(ggplot2::aes(fill = .g), shape = 21, size = OS_FIG$pt_sample_mm,
                        colour = OS_FIG$col_point_edge, stroke = os_lw(OS_FIG$lw_point_edge))
  } else {
    ggplot2::geom_point(ggplot2::aes(fill = .g, shape = .s), size = OS_FIG$pt_sample_mm,
                        colour = OS_FIG$col_point_edge, stroke = os_lw(OS_FIG$lw_point_edge))
  }
  p <- ggplot2::ggplot(sc, ggplot2::aes(x = .x, y = .y)) + pts +
    ggplot2::scale_fill_manual(values = cols, breaks = lv, guide = os_guide_legend(group_col, override = list(shape = 21, size = OS_FIG$pt_sample_mm))) +
    ggplot2::scale_x_continuous(labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.08)) +
    ggplot2::scale_y_continuous(labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.08)) +
    pca_coord +
    ggplot2::labs(x = sprintf("%s (%.1f%% variance)", xs, pv[pcs[1]]), y = sprintf("%s (%.1f%% variance)", ys, pv[pcs[2]])) +
    theme_omicstat(journal = journal, legend = "right")
  if (!is.null(shape_col)) {
    p <- p + ggplot2::scale_shape_manual(values = OS_FIG$shape_sample_sequence[seq_along(levels(sc$.s))],
                                         guide = os_guide_legend(shape_col, override = list(fill = OS_FIG$col_reference_group, size = OS_FIG$pt_sample_mm)))
  }
  if (label_samples) {
    p <- p + os_label_repel(sc, ggplot2::aes(label = sample), italic = FALSE, journal = journal)
  }
  cap <- sprintf(paste0("Principal component analysis of %d samples using the %d most variable features ",
                        "(centred, not scaled; %s). Each point is one sample, coloured by %s%s. ",
                        "Percentages give the variance explained by each component."),
                 nrow(sc), pca$ntop, if (common_scale) "axes on a common scale" else "axes NOT on a common scale because the two components span very different ranges",
                 group_col, if (!is.null(shape_col)) paste0(" and shaped by ", shape_col) else "")
  if (!common_scale) p <- p + ggplot2::theme(aspect.ratio = 0.75)
  os_with_meta(p, figure_type = "pca", default_height_mm = 70, caption = cap,
               encodings = list(fill = as.list(cols), shape = if (is.null(shape_col)) 21 else as.list(stats::setNames(OS_FIG$shape_sample_sequence[seq_along(levels(sc$.s))], levels(sc$.s)))),
               data = list(samples = as.list(sc$sample), percent_var = as.list(round(pv[pcs], 4)), ntop = pca$ntop,
                           common_scale = common_scale))
}

# ---------------------------------------------------------------------------
# Sample-to-sample distance heatmap (DESeq2 vignette)
# ---------------------------------------------------------------------------
os_sample_distance <- function(mat, coldata, group_col, reference = NULL, journal = NULL) {
  dm <- as.matrix(stats::dist(t(mat), method = "euclidean"))
  ann <- data.frame(row.names = coldata$sample, check.names = FALSE)
  ann[[group_col]] <- as.character(coldata[[group_col]])
  lv <- sort(unique(ann[[group_col]]), method = "radix")
  if (!is.null(reference)) lv <- c(reference, setdiff(lv, reference))
  ac <- list(); ac[[group_col]] <- os_group_colours(lv, reference)
  p <- os_heatmap(dm, value_title = "Euclidean\ndistance", scale_type = "distance", cluster_rows = TRUE,
                  cluster_cols = TRUE, show_row_dendro = FALSE, italic_rows = FALSE, show_col_labels = FALSE,
                  col_annot = ann[colnames(dm), , drop = FALSE], annot_colours = ac, journal = journal)
  meta <- attr(p, "os_meta")
  os_with_meta(p, figure_type = "sample_distance", default_height_mm = 75,
               caption = sprintf(paste0("Sample-to-sample Euclidean distances on transformed expression values (%d samples). ",
                                        "Samples are ordered by hierarchical clustering (complete linkage); darker blue indicates more similar samples. ",
                                        "The top bar shows %s."), ncol(mat), group_col))
}

# ---------------------------------------------------------------------------
# Top-feature heatmap: row z-scores of the top n features (by padj), columns
# ordered by group (reference first) then sample id; rows clustered.
# ---------------------------------------------------------------------------
os_top_heatmap <- function(mat, ft, coldata, group_col, n = 50, reference = NULL, clip = 2,
                           cluster_cols = FALSE, show_col_labels = NULL, journal = NULL) {
  .os_require_cols(ft, c("feature_id", "padj"), "os_top_heatmap")
  f <- ft[!is.na(ft$padj) & ft$feature_id %in% rownames(mat), , drop = FALSE]
  f <- f[order(f$padj, -abs(f$log2fc %||% 0), f$feature_id, method = "radix"), , drop = FALSE]
  sel <- utils::head(f$feature_id, n)
  sel <- sort(sel, method = "radix")   # input order for hclust tie-breaking
  cd <- coldata
  lv <- sort(unique(as.character(cd[[group_col]])), method = "radix")
  if (!is.null(reference)) lv <- c(reference, setdiff(lv, reference))
  cd$.g <- factor(as.character(cd[[group_col]]), levels = lv)
  cd <- cd[order(cd$.g, cd$sample, method = "radix"), , drop = FALSE]
  m <- mat[sel, cd$sample, drop = FALSE]
  z <- t(scale(t(m)))
  z[!is.finite(z)] <- 0
  labs <- if ("symbol" %in% names(ft)) stats::setNames(.os_display_symbol(ft[match(sel, ft$feature_id), ]), sel) else NULL
  ann <- data.frame(row.names = cd$sample, check.names = FALSE); ann[[group_col]] <- as.character(cd$.g)
  ac <- list(); ac[[group_col]] <- os_group_colours(lv, reference)
  p <- os_heatmap(z, value_title = OS_AXIS$zscore, scale_type = "diverging", clip = clip, cluster_rows = TRUE,
                  cluster_cols = cluster_cols, row_labels = labs, col_annot = ann, annot_colours = ac,
                  show_col_labels = show_col_labels %||% (ncol(m) <= 24), journal = journal)
  meta <- attr(p, "os_meta")
  os_with_meta(p, figure_type = "top_heatmap", default_height_mm = min(170, 30 + 2.2 * length(sel)),
               caption = sprintf(paste0("Expression of the %d features with the smallest adjusted P values. ",
                                        "Values are row z-scores of transformed expression, clipped at %s%s; rows are ordered by hierarchical clustering ",
                                        "(Euclidean distance, complete linkage) and columns by %s. %d cells were clipped."),
                                 length(sel), "\u00b1", clip, group_col, meta$counts$clipped_cells),
               data = utils::modifyList(meta$data, list(feature_ids = as.list(sel))))
}

# ---------------------------------------------------------------------------
# Generic diagnostic plot (elbow, soft-threshold, BCV, mean-variance, ...)
# ---------------------------------------------------------------------------
# kind = "points" | "line" | "line+points". Colour is ink by default; a
# grouping column uses the category palette. Reference lines via hlines/vlines.
os_diag_xy <- function(df, x, y, kind = c("line+points", "points", "line"), group = NULL,
                       xlab = x, ylab = y, hlines = NULL, vlines = NULL, highlight = NULL,
                       point_labels = NULL, caption = "", figure_type = "diagnostic", journal = NULL) {
  kind <- match.arg(kind)
  df$.x <- df[[x]]; df$.y <- df[[y]]
  fam <- os_font_family()
  map <- if (is.null(group)) ggplot2::aes(x = .x, y = .y) else ggplot2::aes(x = .x, y = .y, colour = .data[[group]], group = .data[[group]])
  p <- ggplot2::ggplot(df, map)
  if (!is.null(hlines)) p <- p + os_hline(hlines)
  if (!is.null(vlines)) p <- p + os_vline(vlines)
  if (grepl("line", kind)) p <- p + ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data), colour = if (is.null(group)) OS_FIG$col_ink else NULL)
  if (grepl("points", kind)) {
    n <- nrow(df)
    sz <- if (n > 500) OS_FIG$pt_dense_mm else OS_FIG$pt_highlight_mm * 1.4
    p <- p + ggplot2::geom_point(shape = 16, size = sz, stroke = 0, colour = if (is.null(group)) OS_FIG$col_ink else NULL)
  }
  if (!is.null(highlight)) {
    h <- df[highlight, , drop = FALSE]
    p <- p + ggplot2::geom_point(data = h, shape = 21, fill = OS_FIG$col_up, colour = OS_FIG$col_ink,
                                 size = OS_FIG$pt_highlight_mm * 2, stroke = os_lw(OS_FIG$lw_point_edge))
  }
  if (!is.null(point_labels)) {
    df$.lab <- df[[point_labels]]
    p <- p + ggplot2::geom_text(data = df, ggplot2::aes(label = .lab), vjust = -0.9, size = os_fs(os_text_pt(OS_FIG$size_label, journal)), family = fam, colour = OS_FIG$col_ink)
  }
  if (!is.null(group)) {
    lv <- sort(unique(as.character(df[[group]])), method = "radix")
    p <- p + ggplot2::scale_colour_manual(values = os_colours_for(lv, "category")$colours, guide = os_guide_legend(group))
  }
  p <- p + ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = xlab, y = ylab) + theme_omicstat(journal = journal, legend = if (is.null(group)) "none" else "right") +
    ggplot2::theme(aspect.ratio = 0.75)
  os_with_meta(p, figure_type = figure_type, default_height_mm = 65, caption = caption)
}
