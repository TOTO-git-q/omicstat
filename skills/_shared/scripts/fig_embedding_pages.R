# High-cardinality embedding representation only. Never fit, sample or merge.
# The original 23-colour registry and os_embedding remain unchanged.
os_embedding_page <- function(emb, group_col, page_groups, page_index, page_count,
    label = TRUE, colour_registry = NULL, family = group_col,
    reduction = c("UMAP", "t-SNE"), legend_ncol = NULL, journal = NULL, label_xy = NULL,
    display_max_per_group = NULL, display_n_input = NULL,
    label_island_eps = NULL, label_island_min_samples = NULL,
    label_style = c("plain", "halo"), category_namespace = NULL, category_role = "unknown",
    run_id = NULL, redundant_shapes = FALSE, missing_label = "Missing metadata") {
  reduction <- match.arg(reduction)
  label_style <- match.arg(label_style)
  for (cc in c("cell", "x", "y", group_col)) if (!cc %in% names(emb))
    stop(sprintf("OS_MISSING_COLUMN: embedding page needs '%s'.", cc), call. = FALSE)
  ids <- .os_require_ids(emb$cell, "embedding page cell IDs")
  if (!nrow(emb) || any(!is.finite(emb$x)) || any(!is.finite(emb$y)))
    stop("OS_INVALID_INPUT: embedding page coordinates must be finite", call. = FALSE)
  g <- as.character(emb[[group_col]])
  absent <- is.na(g) | !nzchar(g)
  if (any(absent) && (length(missing_label) != 1L || is.na(missing_label) ||
      !nzchar(missing_label) || missing_label %in% g[!absent]))
    stop("OS_INVALID_INPUT: missing-category label collision", call. = FALSE)
  g[absent] <- missing_label
  lv <- if (is.factor(emb[[group_col]])) intersect(levels(emb[[group_col]]), unique(g)) else sort(unique(g), method = "radix")
  if (any(absent)) lv <- c(setdiff(lv, missing_label), missing_label)
  capacity <- length(OS_PAL_CATEGORY)
  expected_pages <- ceiling(length(lv) / capacity)
  if (expected_pages > 8L)
    stop(sprintf("OS_TOO_MANY_CATEGORIES: %d categories require %d directly labelled pages; display bound is 8. No category or cell was dropped. Request an explicit justified display subset; this stress input is not owner-review evidence.", length(lv), expected_pages), call. = FALSE)
  valid_int <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x == floor(x)
  if (!valid_int(page_index) || !valid_int(page_count) || page_count != expected_pages ||
      page_count < 2L || page_index < 1L || page_index > page_count)
    stop("OS_INVALID_INPUT: embedding page index/count differs from complete category partition", call. = FALSE)
  expected <- lv[seq.int((page_index - 1L) * capacity + 1L, min(page_index * capacity, length(lv)))]
  if (!is.character(page_groups) || !identical(unname(page_groups), unname(expected)))
    stop("OS_INVALID_INPUT: embedding page groups must be the exact ordered partition", call. = FALSE)
  os_assert_latin(page_groups, "embedding page category labels")
  draw_order <- os_draw_order(nrow(emb))
  d <- emb[draw_order, , drop = FALSE]
  d$.g <- g[draw_order]
  focus <- d$.g %in% page_groups
  fg <- d[focus, , drop = FALSE]
  bg <- d[!focus, , drop = FALSE]
  xr <- range(emb$x); yr <- range(emb$y)
  if (diff(xr) == 0) xr <- xr + c(-.5, .5)
  if (diff(yr) == 0) yr <- yr + c(-.5, .5)
  pt <- os_cell_point_mm(nrow(d))
  background <- os_points_layer(ggplot2::geom_point(data = bg, ggplot2::aes(x, y),
    colour = OS_FIG$col_ns, shape = OS_FIG$shape_dense, size = pt, stroke = 0), nrow(d))
  foreground <- os_points_layer(ggplot2::geom_point(data = fg, ggplot2::aes(x, y),
    colour = OS_FIG$col_ink, shape = OS_FIG$shape_dense, size = pt, stroke = 0), nrow(d))
  p <- ggplot2::ggplot() + background$layer + foreground$layer +
    ggplot2::coord_fixed(ratio = diff(xr) / diff(yr), xlim = xr, ylim = yr, clip = "off") +
    theme_omicstat(journal = journal, axes = "none", legend = "none") +
    ggplot2::labs(title = sprintf("%s: category page %d of %d", group_col, page_index, page_count),
      subtitle = os_wrap("Dark: named categories. Grey: other cells (repeated context).", width = 48)) +
    ggplot2::theme(axis.title = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(size = os_text_pt(OS_FIG$size_axis_title, journal)),
      plot.subtitle = ggplot2::element_text(size = os_text_pt(OS_FIG$size_axis_text, journal)))
  p <- .os_embedding_axes(p, xr, yr, paste(reduction, "1"), paste(reduction, "2"))
  if (is.null(label_xy)) {
    cen <- stats::aggregate(cbind(x, y) ~ .g, data = fg, FUN = stats::median)
    names(cen)[1] <- "lab"
  } else {
    if (!all(c("group", "x", "y") %in% names(label_xy)) || anyDuplicated(label_xy$group) ||
        !setequal(as.character(label_xy$group), lv) || any(!is.finite(label_xy$x)) || any(!is.finite(label_xy$y)))
      stop("OS_INVALID_INPUT: page label coordinates need every category exactly once", call. = FALSE)
    cen <- label_xy[as.character(label_xy$group) %in% page_groups, c("group", "x", "y")]
    names(cen)[1] <- "lab"
  }
  # Direct labels replace categorical colours; the two point colours express
  # page foreground/context only, and never stand for distinct clusters.
  p <- p + os_label_repel(cen, ggplot2::aes(x, y, label = lab), italic = FALSE,
    journal = journal, size_pt = OS_FIG$size_annot, inherit.aes = FALSE,
    colour = OS_FIG$col_ink, bg.colour = OS_FIG$col_bg, bg.r = .12,
    segment.size = 0, box.padding = .05)
  counts <- as.list(table(factor(fg$.g, levels = page_groups)))
  source_counts <- as.list(table(factor(g, levels = lv)))
  cap <- sprintf(paste0("%s embedding page %d/%d: %d of %d categories and %s of %s distinct cells are foreground. ",
    "Dark ink plus direct category names replace categorical colour encoding on this page; the categorical palette limit is unchanged. ",
    "All %s other cells appear in grey solely as spatial context, not as another cluster. ",
    "The complete %s-cell embedding is displayed on every page at identical coordinate ranges. ",
    "Repeated background cells are excluded from foreground totals; the unique-cell denominator is always the original %s distinct displayed cells, never the sum of pages. ",
    "Across all pages, each category and each cell belongs to exactly one foreground partition."),
    reduction, page_index, page_count, length(page_groups), length(lv), os_num(nrow(fg)), os_num(nrow(d)),
    os_num(nrow(bg)), os_num(nrow(d)), os_num(nrow(d)))
  if (!is.null(display_max_per_group)) cap <- paste0(cap, sprintf(
    " Display-only curation preceded pagination: at most %d cells/category, %d of %d analysis cells; analysis objects and downstream tables are unchanged.",
    display_max_per_group, nrow(d), display_n_input))
  if (!is.null(label_island_eps)) cap <- paste0(cap, sprintf(
    " Labels retain the supplied largest-island anchors (eps=%s; min_samples=%d).", os_num(label_island_eps), label_island_min_samples))
  out <- os_with_meta(p, figure_type = "embedding_page", default_height_mm = 90,
    caption = cap, counts = counts, colour_registry = colour_registry,
    encodings = list(foreground = OS_FIG$col_ink, background = OS_FIG$col_ns,
      categorical_colour_encoding = FALSE, category_identity = "direct text labels", point_mm = pt),
    data = list(n_cells = nrow(d), foreground_n = nrow(fg), background_n = nrow(bg),
      unique_cell_denominator = nrow(d), page_index = page_index, page_count = page_count,
      foreground_categories = as.list(page_groups), all_categories = as.list(lv), source_category_counts = source_counts,
      coordinate_range = list(x = as.list(xr), y = as.list(yr)),
      coordinate_sha256 = os_table_sha256(emb[order(ids, method = "radix"), c("cell", "x", "y")]),
      foreground_cell_sha256 = os_table_sha256(data.frame(cell = sort(as.character(fg$cell), method = "radix")))),
    notes = list(background_repeated_across_pages = TRUE, background_is_category = FALSE,
      background_added_to_denominator = FALSE, analysis_recomputed = FALSE,
      palette_guard_unchanged = TRUE, display_page_limit = 8L,
      direct_labels_required_for_monochrome = TRUE, original_label_requested = label,
      rasterised_points = background$rasterised || foreground$rasterised,
      original_label_style = label_style, original_redundant_shapes = redundant_shapes,
      category_namespace = category_namespace, category_role = category_role, run_id = run_id))
  attr(out, "os_prepared_draw_unavailable") <- "Paginated category display is not yet a registered prepared-restyle family; frozen figure_request data can be rendered without rerunning analysis."
  out
}
