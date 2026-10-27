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

if (!exists("OS_FIG_STYLE_VERSION") || !exists("os_matrix_normalize")) stop("OS_MISSING_DEPENDENCY: source fig_all.R (or fig_style.R and fig_matrix_semantics.R) before fig_heatmap.R.", call. = FALSE)
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

.os_cluster <- function(m, by = c("rows", "cols"), missing_policy = c("error", "no_cluster"),
                        precomputed = NULL) {
  by <- match.arg(by); missing_policy <- match.arg(missing_policy)
  x <- if (by == "rows") m else t(m)
  ids <- .os_require_ids(rownames(x), "clustering IDs")
  if (!is.null(precomputed)) {
    if (inherits(precomputed, "dist")) {
      dm <- as.matrix(precomputed)
      if (!setequal(.os_require_ids(rownames(dm), "distance IDs"), ids) ||
          any(!is.finite(dm)) || any(dm < 0) || any(diag(dm) != 0) ||
          !isTRUE(all.equal(unname(dm), unname(t(dm)))))
        stop("OS_INVALID_INPUT: invalid precomputed distance or mismatched IDs.", call. = FALSE)
      return(stats::hclust(stats::as.dist(dm[ids, ids, drop = FALSE]), method = "complete"))
    }
    .os_validate_hclust(precomputed, ids)
    return(precomputed)
  }
  if (any(!is.finite(x))) {
    if (missing_policy == "no_cluster") return(NULL)
    stop("OS_INVALID_INPUT: nonfinite heatmap values cannot be clustered; explicitly select no_cluster or supply a validated source tree.", call. = FALSE)
  }
  if (nrow(x) < 2) return(NULL)
  stats::hclust(stats::dist(x, method = "euclidean"), method = "complete")
}

# Scaling never substitutes0 for missing observations or undefined variance.
.os_row_zscores <- function(m) {
  center <- rowMeans(m); spread <- apply(m, 1, stats::sd)
  z <- m * NA_real_; state <- matrix("observed", nrow(m), ncol(m), dimnames = dimnames(m))
  state[is.na(m)] <- "missing"; state[is.infinite(m)] <- "infinite"
  for (i in seq_len(nrow(m))) {
    reason <- if (ncol(m) < 2L) "undefined_single_sample" else if (any(!is.finite(m[i, ]))) "undefined_nonfinite_reference" else if (!is.finite(spread[i]) || spread[i] == 0) "undefined_constant" else NULL
    if (is.null(reason)) z[i, ] <- (m[i, ] - center[i]) / spread[i]
    else state[i, is.finite(m[i, ])] <- reason
  }
  list(values = z, state = state, center = center, sd = spread, raw = m)
}

# Resolve a split specification into a factor aligned with `ids` (level order
# = slice order: factor levels when a factor is given, else sorted C-locale).
.os_slices <- function(split, ids, what) {
  if (is.null(split)) return(NULL)
  if (!is.null(names(split)) && anyDuplicated(names(split))) stop("OS_INVALID_PARAMETER: split IDs must be unique.", call. = FALSE)
  if (!is.null(names(split)) && setequal(ids, names(split))) {
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
.os_slice_order <- function(m, slices, cluster, by, missing_policy = "error", precomputed = NULL) {
  n <- if (by == "rows") nrow(m) else ncol(m)
  if (is.null(slices)) {
    hc <- if (cluster) .os_cluster(m, by, missing_policy, precomputed) else NULL
    ids <- if (by == "rows") rownames(m) else colnames(m)
    return(list(order = if (!is.null(hc)) match(hc$labels[hc$order], ids) else seq_len(n), hcs = list(all = hc)))
  }
  if (!is.null(precomputed)) stop("OS_INVALID_INPUT: a global precomputed tree cannot be silently split.", call. = FALSE)
  ord <- integer(0); hcs <- list()
  for (lv in levels(slices)) {
    idx <- which(slices == lv)
    sub <- if (by == "rows") m[idx, , drop = FALSE] else m[, idx, drop = FALSE]
    hc <- if (cluster) .os_cluster(sub, by, missing_policy) else NULL
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
                       colour_registry = NULL, missing_policy = c("error", "no_cluster"),
                       row_hclust = NULL, col_hclust = NULL, value_state = NULL,
                       matrix_kind = "measurements", row_entity = "row", col_entity = "column",
                       quantity = NULL, unit = "unknown", normalization = "identity", source_unit = NULL,
                       row_axis_role = "unordered", col_axis_role = "unordered",
                       row_axis_keys = NULL, col_axis_keys = NULL,
                       row_order = NULL, col_order = NULL, row_tree_rotation = NULL, col_tree_rotation = NULL,
                       display_mask_gt = NULL, display_mask_abs = FALSE, cell_metadata = NULL,
                       clustering_provenance = list(source = "supplied matrix", preprocessing = "unknown"),
                       row_title = NULL, col_title = NULL, col_label_angle = 90, row_label_side = c("right", "left")) {
  row_label_side <- match.arg(row_label_side)
  if (!col_label_angle %in% c(0, 45, 90)) .os_matrix_error("col_label_angle must be 0, 45 or 90")
  if (row_axis_role != "unordered" && missing(cluster_rows)) cluster_rows <- FALSE
  if (col_axis_role != "unordered" && missing(cluster_cols)) cluster_cols <- FALSE
  if (matrix_kind == "distance" && missing(scale_type)) scale_type <- "distance"
  scale_type <- match.arg(scale_type); missing_policy <- match.arg(missing_policy)
  .os_matrix_ids(mat)
  if (!matrix_kind %in% c("measurements", "expression", "distance", "score", "correlation", "missingness")) .os_matrix_error("unknown matrix kind")
  for (x in list(row_entity, col_entity, unit)) if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) .os_matrix_error("matrix entity and unit labels must be explicit nonempty strings")
  quantity <- quantity %||% if (is.character(value_title)) gsub("\n", " ", value_title) else "unknown"
  if (!is.character(quantity) || length(quantity) != 1L || is.na(quantity) || !nzchar(quantity)) .os_matrix_error("matrix quantity must be one string")
  source_unit <- source_unit %||% if (normalization == "identity") unit else "unknown"
  .os_sem_string(source_unit, "raw matrix unit")
  if (normalization != "identity") {
    display_unit <- if (grepl("_rank$", normalization)) "rank" else "dimensionless"
    if (!unit %in% c("unknown", display_unit)) .os_matrix_error("normalized colour values must use their transformed unit; declare the original unit with source_unit")
    unit <- display_unit
    method <- sub("^(row|col)_", "", normalization)
    token <- switch(method, zscore = "z.?score", rms = "rms", max = "max", rank = "rank", ".^")
    if (is.character(value_title) && !grepl(token, value_title, ignore.case = TRUE))
      value_title <- paste0(value_title, "\n(", gsub("_", " ", normalization), ")")
  }
  original_row_ids <- rownames(mat); original_col_ids <- colnames(mat)
  if (matrix_kind == "distance") {
    if (normalization != "identity" || scale_type != "distance" || !is.null(row_split) || !is.null(col_split)) .os_matrix_error("distance matrices require an untransformed distance palette and one shared unsplit ID order")
    if (!identical(cluster_rows, cluster_cols)) .os_matrix_error("distance matrices require the same clustering choice on both axes")
    distance_mat <- .os_validate_distance_matrix(mat)
    if (!is.null(value_state)) value_state <- value_state[rownames(mat), colnames(mat), drop = FALSE]
    if (cluster_rows && nrow(mat) > 1L) {
      supplied <- row_hclust %||% col_hclust
      if (is.null(supplied)) supplied <- stats::hclust(stats::as.dist(distance_mat), method = "complete")
      source_tree <- .os_cluster(mat, "rows", missing_policy, supplied)
      if (!is.null(row_hclust) && !is.null(col_hclust)) {
        other <- .os_cluster(mat, "rows", missing_policy, col_hclust)
        if (!isTRUE(all.equal(.os_tree_record(source_tree), .os_tree_record(other)))) .os_matrix_error("distance axes cannot use different source trees")
      }
      row_hclust <- col_hclust <- source_tree
    }
    if (!cluster_rows && is.null(row_order) && is.null(col_order)) row_order <- rownames(mat)
    if (is.null(row_order)) row_order <- col_order
    if (is.null(col_order)) col_order <- row_order
    if (!identical(row_order, col_order)) .os_matrix_error("distance permutations must act on both axes together")
    if (is.null(row_tree_rotation)) row_tree_rotation <- col_tree_rotation
    if (is.null(col_tree_rotation)) col_tree_rotation <- row_tree_rotation
    if (!identical(row_tree_rotation, col_tree_rotation)) .os_matrix_error("distance tree rotations must act on both axes together")
  }
  raw_mat <- mat
  transformed <- os_matrix_normalize(raw_mat, normalization)
  if (is.null(value_state) && is.data.frame(cell_metadata) && all(c("row_id", "col_id", "state") %in% names(cell_metadata))) {
    cells <- .os_matrix_table(raw_mat); keys <- .os_cell_keys(cells$row_id, cells$col_id)
    supplied <- .os_cell_keys(cell_metadata$row_id, cell_metadata$col_id)
    if (anyDuplicated(supplied) || !setequal(keys, supplied)) .os_matrix_error("cell state metadata must map every cell exactly once")
    value_state <- matrix(as.character(cell_metadata$state[match(keys, supplied)]), nrow(raw_mat), ncol(raw_mat), dimnames = dimnames(raw_mat))
  }
  raw_state <- value_state %||% transformed$state
  if (is.null(value_state)) raw_state <- .os_matrix_states(raw_mat)
  if (!identical(dimnames(raw_state), dimnames(raw_mat)) || !identical(dim(raw_state), dim(raw_mat))) .os_matrix_error("value states must align exactly to raw matrix IDs")
  source_cells <- .os_matrix_cell_metadata(raw_mat, raw_state, cell_metadata)
  mat <- transformed$values
  value_state <- if (normalization == "identity") raw_state else transformed$state
  if (normalization != "identity") {
    special <- raw_state %in% c("reference", "nonsignificant", "not_credible", "failed", "untested", "excluded", "unmeasured")
    value_state[special] <- raw_state[special]
  }
  explicit_ro <- .os_matrix_axis_order(rownames(mat), row_order, row_axis_role, row_axis_keys, cluster_rows, "row")
  explicit_co <- .os_matrix_axis_order(colnames(mat), col_order, col_axis_role, col_axis_keys, cluster_cols, "column")
  if (!is.null(clip) && (length(clip) != 1L || !is.finite(clip) || clip <= 0)) .os_matrix_error("clip must be a positive finite display bound")
  if (!is.null(display_mask_gt) && (length(display_mask_gt) != 1L || !is.finite(display_mask_gt))) .os_matrix_error("display mask threshold must be finite")
  if (!is.logical(display_mask_abs) || length(display_mask_abs) != 1L || is.na(display_mask_abs)) .os_matrix_error("display_mask_abs must be boolean")
  if (!is.matrix(mat) || !is.numeric(mat)) stop("OS_INVALID_INPUT: os_heatmap needs a numeric matrix.", call. = FALSE)
  if (is.null(rownames(mat)) || is.null(colnames(mat))) stop("OS_INVALID_INPUT: heatmap matrix needs row and column names.", call. = FALSE)
  .os_require_ids(rownames(mat), "heatmap row IDs"); .os_require_ids(colnames(mat), "heatmap column IDs")
  nr <- nrow(mat); nc <- ncol(mat)
  for (entry in list(list(col_annot, colnames(mat)), list(row_annot, rownames(mat)))) {
    if (!is.null(entry[[1]]) && !setequal(.os_require_ids(rownames(entry[[1]]), "annotation IDs"), entry[[2]]))
      stop("OS_INVALID_PARAMETER: heatmap annotation IDs must match their matrix axis.", call. = FALSE)
  }
  if (is.null(value_state)) {
    value_state <- matrix("observed", nr, nc, dimnames = dimnames(mat))
    value_state[is.finite(mat) & mat == 0] <- "true_zero"
    value_state[is.na(mat)] <- "missing"; value_state[is.infinite(mat)] <- "infinite"
  }
  if (!identical(dimnames(value_state), dimnames(mat)) || !identical(dim(value_state), dim(mat)) || anyNA(value_state))
    stop("OS_INVALID_INPUT: heatmap value states must align exactly to matrix IDs.", call. = FALSE)
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
  ro <- .os_slice_order(mat, rsl, cluster_rows, "rows", missing_policy, row_hclust)
  co <- .os_slice_order(mat, csl, cluster_cols, "cols", missing_policy, col_hclust)
  if (!is.null(explicit_ro)) ro$order <- explicit_ro
  if (!is.null(explicit_co)) co$order <- explicit_co
  for (which_axis in c("row", "col")) {
    rotation <- if (which_axis == "row") row_tree_rotation else col_tree_rotation
    if (is.null(rotation)) next
    obj <- if (which_axis == "row") ro else co
    if (length(obj$hcs) != 1L) .os_matrix_error("a global tree rotation cannot be applied to separately clustered slices")
    obj$hcs[[1]] <- .os_tree_rotate(obj$hcs[[1]], rotation)
    obj$order <- match(rotation, if (which_axis == "row") rownames(mat) else colnames(mat))
    if (which_axis == "row") ro <- obj else co <- obj
  }
  row_ord <- ro$order; col_ord <- co$order
  any_hr <- any(!vapply(ro$hcs, is.null, logical(1)))
  any_hc <- any(!vapply(co$hcs, is.null, logical(1)))
  rn <- rownames(mat)[row_ord]; cn <- colnames(mat)[col_ord]
  rs_disp <- if (split_r) rsl[row_ord] else NULL
  cs_disp <- if (split_c) csl[col_ord] else NULL
  r_sizes <- if (split_r) as.integer(table(rs_disp)) else nr
  c_sizes <- if (split_c) as.integer(table(cs_disp)) else nc

  v <- mat[row_ord, col_ord, drop = FALSE]
  display_state <- value_state[row_ord, col_ord, drop = FALSE]
  # A mask is applied only AFTER analysis/clustering. Strictly >, never >=.
  masked <- matrix(FALSE, nr, nc, dimnames = dimnames(v))
  if (!is.null(display_mask_gt)) masked <- is.finite(v) & (if (display_mask_abs) abs(v) else v) > display_mask_gt
  display_state[masked] <- "display_masked"
  v[!is.finite(v) | masked] <- NA_real_
  unbounded_display <- v
  clipped_n <- 0L
  if (!is.null(clip)) {
    clipped_n <- sum(abs(v) > clip, na.rm = TRUE)
    v[v > clip] <- clip; v[v < -clip] <- -clip
  }
  # rows drawn top-to-bottom in dendrogram order: y = nr .. 1
  df <- data.frame(col = rep(seq_len(nc), each = nr), row = rep(rev(seq_len(nr)), times = nc),
                   value = as.vector(v), state = as.vector(display_state))
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
    finite_range <- if (any(is.finite(v))) range(v, finite = TRUE) else c(0, 1)
    if (finite_range[1] == finite_range[2]) finite_range <- finite_range + c(-1, 1) * max(abs(finite_range[1]) * 0.01, 0.5)
    if (matrix_kind == "distance") finite_range[1] <- 0
    lim <- limits %||% finite_range
    fill_scale <- ggplot2::scale_fill_gradientn(colours = pal, limits = lim, oob = scales::squish,
                                                labels = os_axis_labels, guide = os_guide_colourbar(value_title))
  }

  if (length(lim) != 2L || any(!is.finite(lim)) || lim[1] >= lim[2]) .os_matrix_error("colour limits must be two increasing finite values")
  if (matrix_kind == "distance" && lim[1] != 0) .os_matrix_error("distance colour limits must start at zero so the near/far direction remains exact")
  fill_scale$na.value <- OS_FIG$col_na
  v[is.finite(v)] <- pmax(lim[1], pmin(lim[2], v[is.finite(v)]))
  clipped_n <- sum(v != unbounded_display, na.rm = TRUE)
  df$value <- as.vector(v)
  if (clipped_n > 0L && !clipped_ends) { fill_scale$labels <- os_clipped_labels(lim[1], lim[2]); clipped_ends <- TRUE }
  fill_breaks <- fill_scale$get_breaks(lim)
  fill_breaks <- fill_breaks[is.finite(fill_breaks) & fill_breaks >= lim[1] & fill_breaks <= lim[2]]
  if (!length(fill_breaks)) fill_breaks <- lim
  fill_scale$breaks <- fill_breaks
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
                                expand = c(0, 0), position = row_label_side) +
    theme_omicstat(journal = journal, axes = "none") +
    ggplot2::theme(axis.title = ggplot2::element_blank(),
                   axis.text.x = if (show_col_labels) ggplot2::element_text(angle = col_label_angle,
                                                                             hjust = if (col_label_angle == 0) 0.5 else 1,
                                                                             vjust = if (col_label_angle == 90) 0.5 else if (col_label_angle == 45) 1 else 1,
                                                                             size = OS_FIG$size_axis_text) else ggplot2::element_blank(),
                   axis.text.y.right = if (show_row_labels && row_label_side == "right") ggplot2::element_text(size = max(os_journal(journal)$min_pt, min(OS_FIG$size_axis_text, 250 / max(nr, 1))),
                                                                                  face = if (italic_rows) "italic" else "plain", hjust = 0) else ggplot2::element_blank(),
                   axis.text.y.left = if (show_row_labels && row_label_side == "left") ggplot2::element_text(size = max(os_journal(journal)$min_pt, min(OS_FIG$size_axis_text, 250 / max(nr, 1))),
                                                                                  face = if (italic_rows) "italic" else "plain", hjust = 1) else ggplot2::element_blank(),
                   plot.margin = ggplot2::margin(0, 0, 0, 0)) +
    (if (!is.null(col_title) || !is.null(row_title))
       ggplot2::labs(x = col_title, y = row_title) else NULL) +
    (if (!is.null(col_title) || !is.null(row_title))
       ggplot2::theme(axis.title.x = if (is.null(col_title)) ggplot2::element_blank() else ggplot2::element_text(size = OS_FIG$size_axis_title, margin = ggplot2::margin(t = 1.5, unit = "mm")),
                      axis.title.y = if (is.null(row_title)) ggplot2::element_blank() else ggplot2::element_text(size = OS_FIG$size_axis_title, angle = 90, margin = ggplot2::margin(r = 1.5, unit = "mm")),
                      axis.text.x = if (show_col_labels) ggplot2::element_text(margin = ggplot2::margin(t = 1.2, unit = "mm")) else ggplot2::element_blank(),
                      axis.text.y.left = if (show_row_labels && row_label_side == "left") ggplot2::element_text(margin = ggplot2::margin(r = 1.2, unit = "mm")) else ggplot2::element_blank(),
                      plot.margin = ggplot2::margin(1, 1, 1, 1, unit = "mm")) else NULL) +
    (if (!show_row_labels) ggplot2::theme(axis.ticks.length.y = grid::unit(0, "mm"))) +
    .os_split_layer(split_r, split_c, row_strip = row_strip_on == "body", col_strip = col_strip_on == "body")
  state_levels <- intersect(names(OS_MATRIX_STATE_STYLES), unique(df$state))
  if (any(masked)) body <- body + ggplot2::geom_tile(data = df[df$state == "display_masked", , drop = FALSE], fill = "#FFFFFF", colour = border, linewidth = os_lw(OS_FIG$lw_segment))
  if (length(state_levels)) {
    sd <- df[df$state %in% state_levels, , drop = FALSE]; sd$state <- factor(sd$state, levels = state_levels)
    styles <- OS_MATRIX_STATE_STYLES[state_levels]
    body <- body + ggplot2::geom_point(data = sd, ggplot2::aes(shape = state, colour = state), size = 1.7, stroke = 0.45) +
      ggplot2::scale_shape_manual(values = vapply(styles, `[[`, 0, "shape"), labels = vapply(styles, `[[`, "", "label"), name = "Cell state", drop = FALSE) +
      ggplot2::scale_colour_manual(values = vapply(styles, `[[`, "", "colour"), labels = vapply(styles, `[[`, "", "label"), name = "Cell state", drop = FALSE)
  }
  if (!is.null(cell_text)) {
    if (!identical(dim(cell_text), dim(raw_mat)) || !identical(dimnames(cell_text), dimnames(raw_mat))) .os_matrix_error("cell text must align exactly to raw matrix IDs")
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
  fill_enc$breaks <- as.list(fill_breaks)
  if (clipped_ends) fill_enc$clipped_end_labels <- TRUE
  enc <- list(fill = fill_enc, annotation = annot_used)
  if (length(row_annot_used)) enc$row_annotation <- row_annot_used
  dat <- list(n_rows = nr, n_cols = nc, show_row_labels = show_row_labels, show_col_labels = show_col_labels,
              row_order = as.list(rn), col_order = as.list(cn),
              clustering = list(rows = if (!is.null(row_hclust)) "precomputed_source_tree" else clus_desc(any_hr, split_r),
                                cols = if (!is.null(col_hclust)) "precomputed_source_tree" else clus_desc(any_hc, split_c)),
              missing_policy = missing_policy,
              source_values = source_cells,
              analysis_values = .os_matrix_table(mat, value_state),
              display_values = .os_matrix_table(v, display_state),
              trees = list(rows = lapply(ro$hcs, .os_tree_record), cols = lapply(co$hcs, .os_tree_record)),
              permutations = list(row_forward = as.list(row_ord), row_inverse = as.list(order(row_ord)),
                                  col_forward = as.list(col_ord), col_inverse = as.list(order(col_ord))),
              annotations = list(rows = if (has_ra) row_annot[rn, , drop = FALSE] else NULL,
                                 cols = if (has_ca) col_annot[cn, , drop = FALSE] else NULL))
  tree_description <- function(hcs) {
    z <- Filter(Negate(is.null), hcs)
    if (!length(z)) return("not clustered")
    paste(unique(vapply(z, function(h) paste0(h$dist.method %||% "unknown metric", "/", h$method %||% "unknown linkage"), "")), collapse = "; ")
  }
  if (any_hr && !is.null(row_hclust)) dat$clustering$rows <- paste0("precomputed_source_tree (", tree_description(ro$hcs), ")")
  if (any_hc && !is.null(col_hclust)) dat$clustering$cols <- paste0("precomputed_source_tree (", tree_description(co$hcs), ")")
  matrix_definition <- list(version = OS_MATRIX_SEMANTIC_VERSION, matrix_kind = matrix_kind,
    row_entity = row_entity, col_entity = col_entity, quantity = quantity, unit = unit, source_unit = source_unit,
    n_rows = nr, n_cols = nc, normalization = transformed$definition,
    original_row_ids = as.list(original_row_ids), original_col_ids = as.list(original_col_ids),
    row_axis = list(role = row_axis_role, original_keys = row_axis_keys),
    col_axis = list(role = col_axis_role, original_keys = col_axis_keys),
    source_sha256 = os_semantic_table_sha256(source_cells, .os_cell_keys(source_cells$row_id, source_cells$col_id)),
    source_values = "data.source_values", analysis_values = "data.analysis_values", display_values = "data.display_values",
    clipping = list(limits = as.list(lim), explicit_symmetric_clip = clip, clipped_cells = clipped_n, statistics_use = "unclipped analysis values"),
    clustering_input = "analysis values before display clipping/masking", clustering_provenance = clustering_provenance,
    ordering = list(rows = if (!is.null(row_tree_rotation)) "supplied topology-preserving rotation; no optimality claim" else if (!is.null(row_order)) "provided ID permutation" else dat$clustering$rows,
                    cols = if (!is.null(col_tree_rotation)) "supplied topology-preserving rotation; no optimality claim" else if (!is.null(col_order)) "provided ID permutation" else dat$clustering$cols),
    alignment = attr(raw_mat, "os_alignment"), missing_policy = missing_policy,
    original_missing_count = attr(raw_mat, "os_alignment")$original_missing_count %||% sum(is.na(raw_mat)),
    source_infinite_count = sum(is.infinite(raw_mat)),
    nonfinite_cells = transform(source_cells[is.infinite(source_cells$value), c("row_id", "col_id"), drop = FALSE],
                               kind = ifelse(source_cells$value[is.infinite(source_cells$value)] > 0, "positive_infinity", "negative_infinity")),
    display_mask = list(rule = if (is.null(display_mask_gt)) "none" else if (display_mask_abs) "abs(value) > threshold" else "value > threshold", threshold = display_mask_gt, masked_cells = sum(masked)),
    palette_direction = if (matrix_kind == "distance") "dark blue = near; light = far; zero = identical object distance" else "low to high",
    raw_range = if (any(is.finite(raw_mat))) as.list(range(raw_mat, finite = TRUE)) else NULL,
    analysis_range = if (any(is.finite(mat))) as.list(range(mat, finite = TRUE)) else NULL,
    display_constant = length(unique(as.vector(v[is.finite(v)]))) == 1L,
    state_legend = OS_MATRIX_STATE_STYLES[state_levels])
  if (split_r) dat$row_slices <- stats::setNames(as.list(r_sizes), levels(rsl))
  if (split_c) dat$col_slices <- stats::setNames(as.list(c_sizes), levels(csl))
  if (!is.null(mark_df)) dat$marked_rows <- as.list(mark_df$id)
  # generic auto caption (callers such as os_top_heatmap() replace it with
  # their own); every number comes from what is drawn
  vt <- if (is.character(value_title)) gsub("\n", " ", value_title) else "value"
  slice_txt <- function(sl, what) sprintf("%s are split into %d groups (%s) separated by gaps", what, nlevels(sl), paste(levels(sl), collapse = ", "))
  cap <- paste0("Heatmap of ", os_num(nr), " rows and ", os_num(nc), " columns; colour, ", vt, ". ",
                if (any_hr || any_hc) paste0(paste(c(if (any_hr) "rows", if (any_hc) "columns"), collapse = " and "),
                                             " are ordered by hierarchical clustering (",
                                             paste(c(if (any_hr) paste0("rows: ", tree_description(ro$hcs)), if (any_hc) paste0("columns: ", tree_description(co$hcs))), collapse = "; "),
                                             if (split_r || split_c) ", within each group" else "", "). ") else "",
                if (split_r) paste0(slice_txt(rsl, "Rows"), ". ") else "",
                if (split_c) paste0(slice_txt(csl, "Columns"), ". ") else "",
                if (length(row_annot_used)) paste0("Left bars: ", paste(names(row_annot_used), collapse = ", "), ". ") else "",
                if (length(annot_used)) paste0("Top bars: ", paste(names(annot_used), collapse = ", "), ". ") else "",
                if (!is.null(mark_df)) paste0(nrow(mark_df), " selected rows are labelled. ") else "",
                if (!is.null(clip)) sprintf("Values are clipped at %s%s (%s cells).", "\u00b1", os_num(clip), os_num(clipped_n)) else "")
  cap <- paste0(cap, " Matrix: ", row_entity, " by ", col_entity, "; quantity ", quantity, "; unit ", unit, ". ",
                "Normalization: ", transformed$definition$method, " (", transformed$definition$formula, "). ",
                if (row_axis_role != "unordered") paste0("Row axis: ", row_axis_role, if (cluster_rows) " reordered by clustering" else " in declared order", ". ") else "",
                if (col_axis_role != "unordered") paste0("Column axis: ", col_axis_role, if (cluster_cols) " reordered by clustering" else " in declared order", ". ") else "",
                if (matrix_kind == "distance") "Distance matrix used directly once; the same ID permutation acts on both axes. Dark blue is near, light is far; no branch support was supplied. " else "",
                if (length(state_levels)) paste0("Cell symbols distinguish ", paste(vapply(OS_MATRIX_STATE_STYLES[state_levels], `[[`, "", "label"), collapse = "; "), ". ") else "",
                if (!is.null(display_mask_gt)) paste0(sum(masked), " cells masked only for display using ", matrix_definition$display_mask$rule, " = ", display_mask_gt, "; clustering uses the unmasked matrix. ") else "",
                if (is.null(clip) && clipped_n > 0L) paste0(clipped_n, " display values clipped to the declared colour limits; source values are retained. ") else "",
                if (isTRUE(matrix_definition$display_constant)) if (matrix_kind == "distance") "All distances are zero and use the near end of the colour scale. " else "All available display values are identical; the single value is mapped within the declared colour range. " else "")
  panel_contract <- list(version = "omicstat.panel-contract.v1", row_ids = as.list(rn), col_ids = as.list(cn),
    guides = list(value = list(kind = "continuous", aesthetic = "fill", quantity = quantity, unit = unit,
      transform = normalization, limits = as.list(lim), ticks = as.list(fill_breaks), palette = as.list(pal),
      display_mask = matrix_definition$display_mask$rule)), axes = list(), population = list(status = "unknown"))
  for (axis in c("row", "col")) {
    mappings <- if (axis == "row") row_annot_used else annot_used
    entity <- if (axis == "row") row_entity else col_entity
    for (track in names(mappings)) panel_contract$guides[[paste(axis, track, sep = ":")]] <- list(kind = "discrete", aesthetic = "fill", entity_type = paste(entity, track, sep = ":"), values = mappings[[track]])
  }
  if (length(state_levels)) {
    panel_contract$guides$state_shape <- list(kind = "discrete", aesthetic = "shape", entity_type = "matrix cell state", values = lapply(OS_MATRIX_STATE_STYLES[state_levels], `[[`, "shape"))
    panel_contract$guides$state_colour <- list(kind = "discrete", aesthetic = "colour", entity_type = "matrix cell state", values = lapply(OS_MATRIX_STATE_STYLES[state_levels], `[[`, "colour"))
  }
  meta <- list(p, figure_type = "heatmap", caption = trimws(cap), encodings = enc, data = dat,
               definition = list(matrix_contract = matrix_definition), notes = list(panel_contract = panel_contract, numeric_precision = "binary64_roundtrip"),
               counts = list(clipped_cells = clipped_n, display_masked_cells = sum(masked),
                             original_missing_cells = matrix_definition$original_missing_count,
                             states = as.list(table(value_state)), source_states = as.list(table(raw_state))))
  if (!is.null(colour_registry) || (length(row_annot_used) + length(annot_used) > 0 && !identical(reg, colour_registry))) {
    meta$colour_registry <- reg
  }
  out <- do.call(os_with_meta, meta)
  # Resolve annotation colours once; derivatives never grow a registry.
  frozen_tracks <- function(maps,axis) if(length(maps)) stats::setNames(lapply(maps,function(m)unlist(m) %||% character()),paste0(axis,"::",names(maps))) else list()
  annot_colours <- c(frozen_tracks(annot_used,"column"),frozen_tracks(row_annot_used,"row"))
  if (!exists(".os_restyle_attach", mode="function")) return(out)
  .os_restyle_attach(out, "heatmap", environment())
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
