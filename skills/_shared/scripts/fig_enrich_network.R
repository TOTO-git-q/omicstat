# fig_enrich_network.R -- enrichment network figures (FIGURE_STYLE.md sec
# 18.3): gene-concept network (cnet), enrichment map (emap), term tree, and
# the multi-set GSEA running-score overlay.
# ASCII only on purpose. Requires fig_style.R, fig_heatmap.R
# (.os_dendro_segments) and fig_enrich.R (os_gsea_running_score,
# .os_enrich_check); none of them is modified.
#
# Inputs: an enrichment table `et` (same columns as fig_enrich.R: term_id,
# term_name, padj, ...) plus `gene_sets`, a named list term_id -> character
# vector of genes (ORA: the input genes in the set; GSEA: the core
# enrichment / leading-edge genes). No graph package is used: every layout
# below is a closed-form, deterministic construction (no RNG, no iterative
# force layout), so reruns are byte-identical.
#
# Term selection (all functions): terms with padj < padj_threshold that
# have a gene set, ordered by padj then term_id, first top_n.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_enrich_network.R.", call. = FALSE)
if (!exists("os_gsea_running_score")) stop("OS_MISSING_DEPENDENCY: source fig_enrich.R before fig_enrich_network.R.", call. = FALSE)
if (!exists(".os_dendro_segments")) stop("OS_MISSING_DEPENDENCY: source fig_heatmap.R before fig_enrich_network.R.", call. = FALSE)

OS_FIG_EXT <- utils::modifyList(if (exists("OS_FIG_EXT", inherits = TRUE)) OS_FIG_EXT else list(), list(
  net_term_wrap      = 24,          # characters per line of a term label inside a network
  cnet_set_mm        = c(2.4, 5.2), # cnet: set-node diameter range (by gene count)
  cnet_gene_mm       = 1.6,         # cnet: gene-node diameter
  cnet_ring_ratio    = 2.1,         # cnet: gene ring radius / set circle radius
  cnet_max_labels    = 40,          # cnet: at most this many gene labels
  emap_node_mm       = c(1.6, 5.0), # emap: node diameter range (by gene count)
  emap_edge_pt       = c(0.25, 1.5),# emap: edge width range in pt (by Jaccard index)
  emap_jaccard_cutoff = 0.2,        # emap: draw an edge when Jaccard >= this (enrichplot default)
  emap_min_dist      = 0.2,         # emap: minimum node distance after overlap removal (map width = 1)
  layout_sweeps      = 200,         # emap: fixed number of overlap-removal sweeps
  tree_leaf_mm       = c(1.0, 3.6), # term tree: leaf dot diameter range
  gsea_multi_max     = 6            # multi-set GSEA: most sets in one panel (colour limit)
))

# ---------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------
.os_net_select <- function(et, gene_sets, top_n, padj_threshold, fn, min_n = 1) {
  .os_enrich_check(et, c("term_id", "term_name", "padj"), fn)
  if (!is.list(gene_sets) || is.null(names(gene_sets))) stop(sprintf("OS_INVALID_INPUT: %s needs gene_sets as a named list term_id -> genes.", fn), call. = FALSE)
  d <- et[!is.na(et$padj) & et$padj < padj_threshold & et$term_id %in% names(gene_sets), , drop = FALSE]
  d <- d[order(d$padj, d$term_id, method = "radix"), , drop = FALSE]
  d <- utils::head(d, top_n)
  d <- d[vapply(d$term_id, function(t) length(gene_sets[[t]]) > 0, logical(1)), , drop = FALSE]
  if (nrow(d) < min_n) {
    stop(sprintf("OS_EMPTY_DATA: %s needs at least %d gene set(s) with adjusted P < %s and genes; %d available.",
                 fn, min_n, padj_threshold, nrow(d)), call. = FALSE)
  }
  os_assert_latin(d$term_name, "term names")
  d$genes <- lapply(d$term_id, function(t) sort(unique(as.character(gene_sets[[t]])), method = "radix"))
  d
}

# Jaccard index matrix between gene sets (list of character vectors).
os_jaccard <- function(sets) {
  n <- length(sets)
  j <- diag(1, n)
  for (a in seq_len(n)) for (b in seq_len(n)) if (a < b) {
    u <- length(union(sets[[a]], sets[[b]]))
    j[a, b] <- j[b, a] <- if (u) length(intersect(sets[[a]], sets[[b]])) / u else 0
  }
  dimnames(j) <- list(names(sets), names(sets))
  j
}

.os_neglog10_scale <- function(aes = c("colour", "fill"), limits) {
  aes <- match.arg(aes)
  f <- if (aes == "colour") ggplot2::scale_colour_gradientn else ggplot2::scale_fill_gradientn
  f(colours = OS_PAL_SEQUENTIAL, limits = limits, labels = os_axis_labels,
    guide = ggplot2::guide_colourbar(title = OS_AXIS$neglog10padj, title.position = "top", order = 1,
                                     barwidth = grid::unit(OS_FIG$legend_key_mm * 0.8, "mm"),
                                     barheight = grid::unit(OS_FIG$legend_key_mm * 5, "mm"),
                                     frame.colour = OS_FIG$col_ink, ticks.colour = OS_FIG$col_ink))
}

# ---------------------------------------------------------------------------
# Gene-concept network (cnetplot)
# ---------------------------------------------------------------------------
# Layout (closed form): the S selected sets sit on an inner circle (radius 1,
# first set at 12 o'clock, then clockwise in padj order; a single set sits at
# the centre). Each gene gets a target angle = circular mean of the angles of
# the sets it belongs to (first set's angle when the mean is undefined).
# Genes are sorted by target angle (ties: more sets first, then name) and
# placed at EVENLY spaced angles on the outer ring (radius
# OS_FIG_EXT$cnet_ring_ratio), rotated by the circular mean offset so each
# gene sits as close to its target as the even spacing allows: genes of one
# set form an arc next to it, shared genes fall between their sets, and no
# two gene nodes overlap. Gene fill = log2 fold change (diverging, symmetric
# limits); set-node size = number of genes of the set in the network.
os_cnet <- function(et, gene_sets, fc = NULL, top_n = 5, padj_threshold = 0.05,
                    max_gene_labels = OS_FIG_EXT$cnet_max_labels, journal = NULL) {
  d <- .os_net_select(et, gene_sets, top_n, padj_threshold, "os_cnet")
  S <- nrow(d)
  th_set <- pi / 2 - 2 * pi * (seq_len(S) - 1) / S
  r_set <- if (S == 1) 0 else 1
  sets <- data.frame(term_id = d$term_id, term = os_wrap(d$term_name, OS_FIG_EXT$net_term_wrap),
                     x = r_set * cos(th_set), y = r_set * sin(th_set), n = lengths(d$genes), stringsAsFactors = FALSE)
  genes <- sort(unique(unlist(d$genes)), method = "radix")
  os_assert_latin(genes, "gene names")
  memb <- vapply(d$genes, function(g) genes %in% g, logical(length(genes)))
  if (is.null(dim(memb))) memb <- matrix(memb, nrow = length(genes))
  n_in <- rowSums(memb)
  tgt <- vapply(seq_along(genes), function(i) {
    a <- th_set[memb[i, ]]
    cs <- mean(cos(a)); sn <- mean(sin(a))
    if (sqrt(cs^2 + sn^2) < 1e-9) a[1] else atan2(sn, cs)
  }, numeric(1))
  key <- (pi / 2 - tgt) %% (2 * pi)                 # clockwise from 12 o'clock
  ord <- order(round(key, 10), -n_in, genes, method = "radix")
  G <- length(genes)
  base <- (seq_len(G) - 1) * 2 * pi / G
  dk <- key[ord] - base
  off <- atan2(mean(sin(dk)), mean(cos(dk)))
  ang <- numeric(G); ang[ord] <- pi / 2 - (base + off)
  r_gene <- OS_FIG_EXT$cnet_ring_ratio * max(r_set, 0.5)
  gdf <- data.frame(gene = genes, x = r_gene * cos(ang), y = r_gene * sin(ang), n_sets = n_in, stringsAsFactors = FALSE)
  gdf$fc <- if (is.null(fc)) NA_real_ else unname(fc[genes])
  edges <- do.call(rbind, lapply(seq_len(S), function(s) {
    gi <- match(d$genes[[s]], genes)
    data.frame(x = sets$x[s], y = sets$y[s], xend = gdf$x[gi], yend = gdf$y[gi])
  }))
  # gene labels: all when few; otherwise shared genes first, then |log2FC|, then name
  lab_ord <- order(-gdf$n_sets, -abs(ifelse(is.na(gdf$fc), 0, gdf$fc)), gdf$gene, method = "radix")
  lab_ids <- gdf$gene[utils::head(lab_ord, max_gene_labels)]
  glab <- gdf[gdf$gene %in% lab_ids, , drop = FALSE]
  nud <- 0.16 * r_gene / OS_FIG_EXT$cnet_ring_ratio
  glab$nx <- nud * glab$x / r_gene; glab$ny <- nud * glab$y / r_gene
  p <- ggplot2::ggplot() +
    ggplot2::geom_segment(data = edges, ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
                          colour = OS_FIG$col_ns, linewidth = os_lw(OS_FIG$lw_segment))
  if (is.null(fc)) {
    p <- p + ggplot2::geom_point(data = gdf, ggplot2::aes(x = x, y = y), shape = 21, fill = OS_FIG$col_ns,
                                 colour = OS_FIG$col_ink, stroke = os_lw(OS_FIG$lw_point_edge), size = OS_FIG_EXT$cnet_gene_mm)
  } else {
    lim <- os_sym_limit(gdf$fc, 1)
    p <- p + ggplot2::geom_point(data = gdf, ggplot2::aes(x = x, y = y, fill = pmax(pmin(fc, lim), -lim)), shape = 21,
                                 colour = OS_FIG$col_ink, stroke = os_lw(OS_FIG$lw_point_edge), size = OS_FIG_EXT$cnet_gene_mm) +
      ggplot2::scale_fill_gradientn(colours = OS_PAL_DIVERGING, limits = c(-lim, lim), labels = os_axis_labels,
                                    na.value = OS_FIG$col_na, guide = os_guide_colourbar(OS_AXIS$log2fc))
  }
  p <- p + ggplot2::geom_point(data = sets, ggplot2::aes(x = x, y = y, size = n), shape = 21, fill = OS_FIG$col_bg,
                               colour = OS_FIG$col_ink, stroke = os_lw(OS_FIG$lw_box)) +
    ggplot2::scale_size_continuous(range = OS_FIG_EXT$cnet_set_mm, limits = c(min(sets$n), max(sets$n) + 1e-9),
                                   breaks = scales::breaks_pretty(n = 3),
                                   guide = ggplot2::guide_legend(title = "Genes in set", title.position = "top", order = 2,
                                                                 override.aes = list(fill = OS_FIG$col_bg))) +
    os_label_repel(glab, ggplot2::aes(x = x, y = y, label = gene), italic = TRUE, journal = journal,
                   nudge_x = glab$nx, nudge_y = glab$ny, box.padding = 0.12, point.padding = 0.05,
                   min.segment.length = 0.3) +
    os_label_repel(sets, ggplot2::aes(x = x, y = y, label = term), italic = FALSE, journal = journal,
                   size_pt = OS_FIG$size_annot, nudge_x = -0.38 * sets$x, nudge_y = -0.38 * sets$y,
                   box.padding = 0.2, point.padding = 0.3, lineheight = 0.85, min.segment.length = 0.3,
                   bg.r = 0.2) +
    ggplot2::coord_fixed(clip = "off") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.12)) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = 0.12)) +
    theme_omicstat(journal = journal, axes = "none", legend = "right") +
    ggplot2::theme(axis.title = ggplot2::element_blank())
  n_lab <- nrow(glab)
  cap <- paste0("Gene", OS_NDASH, "concept network of the ", S, " gene sets with the smallest adjusted P (adjusted P < ", padj_threshold,
                "). Open circles, gene sets (size, number of their genes in the network); small circles, the ", os_num(G), " genes",
                if (!is.null(fc)) " coloured by log2 fold change (symmetric scale)" else "",
                "; lines connect each gene to the sets that contain it. Sets are placed clockwise from the top in order of adjusted P; ",
                "each gene sits on the outer ring near the mean direction of its sets.",
                if (n_lab < G) sprintf(" %d of %d genes are labelled (genes in several sets first, then by |log2 fold change|).", n_lab, G) else "")
  os_with_meta(p, figure_type = "cnet", default_height_mm = 89, caption = cap,
               encodings = list(fill = if (is.null(fc)) OS_FIG$col_ns else list(scale = "diverging", palette = as.list(OS_PAL_DIVERGING)),
                                set_size_mm = as.list(OS_FIG_EXT$cnet_set_mm)),
               thresholds = list(padj = padj_threshold),
               counts = list(sets = S, genes = G, shared_genes = sum(n_in > 1), labelled_genes = n_lab),
               data = list(term_ids = as.list(d$term_id), layout = "sets on inner circle; genes evenly spaced on outer ring by mean set angle",
                           labelled = as.list(glab$gene)))
}

# Classical MDS (stats::cmdscale, k = 2) with sign normalisation: in each
# dimension the coordinate with the largest absolute value (first one on
# ties) is made positive, so the layout never mirrors between platforms.
os_mds_signed <- function(d) {
  mds <- stats::cmdscale(d, k = 2)
  if (is.null(dim(mds)) || ncol(mds) < 2) mds <- cbind(mds, 0)
  for (k in 1:2) {
    i <- which.max(abs(round(mds[, k], 10)))
    if (mds[i, k] < 0) mds[, k] <- -mds[, k]
  }
  mds
}

# Deterministic overlap removal for a 2-D layout: scale to a unit range, then
# a FIXED number of sweeps (no RNG, no convergence test) in which every pair
# closer than min_dist is pushed apart symmetrically along the line joining
# it (coincident points: along the direction given by their index pair).
# The global arrangement of the input layout is kept; clusters open up just
# enough for nodes and labels. Returns coordinates rounded to 1e-10.
.os_spread_points <- function(xy, min_dist, sweeps = OS_FIG_EXT$layout_sweeps) {
  unit <- function(m) { r <- max(diff(range(m[, 1])), diff(range(m[, 2])), 1e-9); sweep(m, 2, colMeans(m)) / r }
  xy <- unit(as.matrix(xy[, 1:2, drop = FALSE]))
  n <- nrow(xy)
  # pushing nodes apart widens the map, and re-scaling to unit width shrinks
  # the gaps again: alternate a few (fixed) rounds so the final unit-width
  # map honours min_dist
  if (n > 1) for (round_i in 1:6) {
    for (it in seq_len(sweeps)) {
      moved <- FALSE
      for (a in seq_len(n - 1)) for (b in (a + 1):n) {
        v <- xy[b, ] - xy[a, ]; dd <- sqrt(sum(v^2))
        if (dd >= min_dist) next
        if (dd < 1e-12) { ang <- 2 * pi * ((a * 7 + b * 13) %% 36) / 36; v <- c(cos(ang), sin(ang)); dd <- 1e-12 } else v <- v / dd
        push <- (min_dist - dd) / 2
        xy[a, ] <- xy[a, ] - push * v; xy[b, ] <- xy[b, ] + push * v
        moved <- TRUE
      }
      if (!moved) break
    }
    xy <- unit(xy)
    if (min(stats::dist(xy)) >= 0.98 * min_dist) break
  }
  round(xy, 10)
}

# ---------------------------------------------------------------------------
# Enrichment map (emapplot)
# ---------------------------------------------------------------------------
# Similarity: Jaccard index of the gene sets; an edge joins two terms when
# J >= jaccard_cutoff (default 0.2, the enrichplot default). Layout:
# classical multidimensional scaling (stats::cmdscale, k = 2) of the
# distance 1 - J, with SIGN NORMALISATION (in each dimension the coordinate
# with the largest absolute value is made positive; ties by term order), so
# the map never mirrors across platforms; then deterministic overlap removal
# (.os_spread_points: nodes closer than OS_FIG_EXT$emap_min_dist of the map
# width are pushed apart, fixed sweeps). Axes carry no units and are not
# drawn. Node colour = -log10 adjusted P; size = genes in the set.
os_emap <- function(et, gene_sets, top_n = 30, padj_threshold = 0.05,
                    jaccard_cutoff = OS_FIG_EXT$emap_jaccard_cutoff, journal = NULL) {
  d <- .os_net_select(et, gene_sets, top_n, padj_threshold, "os_emap", min_n = 3)
  n <- nrow(d)
  J <- os_jaccard(stats::setNames(d$genes, d$term_id))
  xy <- .os_spread_points(os_mds_signed(stats::as.dist(1 - J)), OS_FIG_EXT$emap_min_dist)
  nodes <- data.frame(term_id = d$term_id, term = os_wrap(d$term_name, OS_FIG_EXT$net_term_wrap),
                      x = xy[, 1], y = xy[, 2],
                      n = lengths(d$genes), sig = -log10(d$padj), stringsAsFactors = FALSE)
  ij <- which(upper.tri(J) & J >= jaccard_cutoff, arr.ind = TRUE)
  ij <- ij[order(ij[, 1], ij[, 2], method = "radix"), , drop = FALSE]
  edges <- data.frame(x = nodes$x[ij[, 1]], y = nodes$y[ij[, 1]], xend = nodes$x[ij[, 2]], yend = nodes$y[ij[, 2]],
                      jac = J[ij])
  p <- ggplot2::ggplot()
  if (nrow(edges)) {
    p <- p + ggplot2::geom_segment(data = edges, ggplot2::aes(x = x, y = y, xend = xend, yend = yend, linewidth = jac),
                                   colour = OS_FIG$col_ns, lineend = "round") +
      ggplot2::scale_linewidth_continuous(range = os_lw(OS_FIG_EXT$emap_edge_pt), limits = c(jaccard_cutoff, 1),
                                          breaks = scales::breaks_pretty(n = 3), labels = os_axis_labels,
                                          guide = ggplot2::guide_legend(title = "Jaccard index", title.position = "top", order = 3))
  }
  p <- p + ggplot2::geom_point(data = nodes, ggplot2::aes(x = x, y = y, size = n, fill = sig), shape = 21,
                               colour = OS_FIG$col_ink, stroke = os_lw(OS_FIG$lw_point_edge)) +
    .os_neglog10_scale("fill", c(-log10(padj_threshold), max(nodes$sig, -log10(padj_threshold) + 1e-9))) +
    ggplot2::scale_size_continuous(range = OS_FIG_EXT$emap_node_mm, limits = c(min(nodes$n), max(nodes$n) + 1e-9),
                                   breaks = scales::breaks_pretty(n = 3),
                                   guide = ggplot2::guide_legend(title = "Genes", title.position = "top", order = 2,
                                                                 override.aes = list(fill = OS_FIG$col_ns))) +
    os_label_repel(nodes, ggplot2::aes(x = x, y = y, label = term), italic = FALSE, journal = journal,
                   box.padding = 0.2, point.padding = 0.15, lineheight = 0.85, min.segment.length = 0.3,
                   bg.r = 0.2) +
    ggplot2::coord_fixed(clip = "off") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = 0.15)) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = 0.1)) +
    theme_omicstat(journal = journal, axes = "none", legend = "right") +
    ggplot2::theme(axis.title = ggplot2::element_blank())
  deg <- tabulate(c(ij[, 1], ij[, 2]), nbins = n)
  cap <- paste0("Enrichment map of the ", n, " gene sets with the smallest adjusted P (adjusted P < ", padj_threshold, "). ",
                "Nodes are gene sets (colour, ", "-log10 adjusted P; size, number of genes); an edge joins two sets whose Jaccard index ",
                "(shared genes / all genes of the two sets) is at least ", jaccard_cutoff, " (edge width, Jaccard index; ", nrow(edges), " edges, ",
                sum(deg == 0), " unconnected sets). Positions are a two-dimensional classical multidimensional scaling of 1 ", OS_MINUS,
                " Jaccard index, with overlapping nodes pushed apart; the axes have no units.")
  # default height follows the layout's aspect ratio (a 1.5-column figure
  # leaves ~85 mm of panel width next to the legends)
  asp <- (diff(range(nodes$y)) + 0.35) / (diff(range(nodes$x)) + 0.35)
  os_with_meta(p, figure_type = "emap", default_height_mm = round(min(170, max(70, 16 + 85 * asp))), caption = cap,
               encodings = list(fill = list(scale = "sequential", palette = as.list(OS_PAL_SEQUENTIAL)),
                                size_mm = as.list(OS_FIG_EXT$emap_node_mm), edge_pt = as.list(OS_FIG_EXT$emap_edge_pt)),
               thresholds = list(padj = padj_threshold, jaccard = jaccard_cutoff),
               counts = list(sets = n, edges = nrow(edges), unconnected = sum(deg == 0)),
               data = list(term_ids = as.list(d$term_id), layout = "cmdscale(1 - Jaccard), sign-normalised, overlap removal",
                           coordinates = lapply(seq_len(n), function(i) list(term_id = nodes$term_id[i], x = nodes$x[i], y = nodes$y[i]))))
}

# ---------------------------------------------------------------------------
# Term tree (treeplot)
# ---------------------------------------------------------------------------
# hclust of the distance 1 - Jaccard (method "ward.D", the enrichplot
# treeplot default), cut into n_clusters groups. Clusters are numbered in
# leaf order (top to bottom) and coloured from the category palette; a branch
# takes its cluster colour when all leaves below it are in one cluster,
# otherwise it is black. Root on the left, leaves on the right; at each leaf
# a dot (fill, -log10 adjusted P; size, genes in the set) and the term name.
os_term_tree <- function(et, gene_sets, top_n = 30, padj_threshold = 0.05, n_clusters = 4,
                         hclust_method = "ward.D", journal = NULL) {
  d <- .os_net_select(et, gene_sets, top_n, padj_threshold, "os_term_tree", min_n = 3)
  n <- nrow(d)
  k <- max(1L, min(as.integer(n_clusters), n))
  if (k > length(OS_PAL_CATEGORY)) stop(sprintf("OS_TOO_MANY_CATEGORIES: %d term clusters; the category palette holds %d.", k, length(OS_PAL_CATEGORY)), call. = FALSE)
  J <- os_jaccard(stats::setNames(d$genes, d$term_id))
  hc <- stats::hclust(stats::as.dist(1 - J), method = hclust_method)
  cl_raw <- stats::cutree(hc, k = k)
  first <- unique(cl_raw[hc$order])                  # renumber in leaf order
  cl <- match(cl_raw, first)
  cl_lab <- paste("Cluster", seq_len(k))
  cols <- stats::setNames(OS_PAL_CATEGORY[seq_len(k)], cl_lab)
  # segments with the cluster of each subtree (NA when mixed)
  pos <- numeric(n); pos[hc$order] <- seq_len(n)
  m <- hc$merge; h <- hc$height
  nx <- numeric(nrow(m)); ncl <- integer(nrow(m))
  child <- function(c) if (c < 0) list(x = pos[-c], h = 0, cl = cl[-c]) else list(x = nx[c], h = h[c], cl = ncl[c])
  seg <- list()
  for (i in seq_len(nrow(m))) {
    a <- child(m[i, 1]); b <- child(m[i, 2])
    nx[i] <- (a$x + b$x) / 2
    ncl[i] <- if (!is.na(a$cl) && !is.na(b$cl) && a$cl == b$cl) a$cl else NA_integer_
    seg[[length(seg) + 1]] <- data.frame(x = a$x, y = a$h, xend = a$x, yend = h[i], cl = a$cl)
    seg[[length(seg) + 1]] <- data.frame(x = b$x, y = b$h, xend = b$x, yend = h[i], cl = b$cl)
    seg[[length(seg) + 1]] <- data.frame(x = a$x, y = h[i], xend = b$x, yend = h[i], cl = ncl[i])
  }
  seg <- do.call(rbind, seg)
  seg$.cl <- factor(ifelse(is.na(seg$cl), NA, cl_lab[seg$cl]), levels = cl_lab)
  hmax <- max(h)
  leaves <- data.frame(term = os_wrap(d$term_name), pos = n + 1 - pos, n = lengths(d$genes), sig = -log10(d$padj),
                       .cl = factor(cl_lab[cl], levels = cl_lab), stringsAsFactors = FALSE)
  dx <- 0.06 * hmax
  lab_fun <- function(b) { i <- match(round(b), leaves$pos); out <- leaves$term[i]; out[is.na(out)] <- ""; out }
  p <- ggplot2::ggplot() +
    ggplot2::geom_segment(data = seg, ggplot2::aes(x = -y, xend = -yend, y = n + 1 - x, yend = n + 1 - xend, colour = .cl),
                          linewidth = os_lw(OS_FIG$lw_data), lineend = "square") +
    ggplot2::scale_colour_manual(values = cols, breaks = cl_lab, na.value = OS_FIG$col_ink, drop = FALSE,
                                 guide = ggplot2::guide_legend(title = "Term cluster", title.position = "top", order = 3,
                                                               override.aes = list(linewidth = os_lw(1.5)))) +
    ggplot2::geom_segment(data = leaves, ggplot2::aes(x = 0, xend = dx, y = pos, yend = pos, colour = .cl),
                          linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::geom_point(data = leaves, ggplot2::aes(x = dx, y = pos, size = n, fill = sig), shape = 21,
                        colour = OS_FIG$col_ink, stroke = os_lw(OS_FIG$lw_point_edge)) +
    .os_neglog10_scale("fill", c(-log10(padj_threshold), max(leaves$sig, -log10(padj_threshold) + 1e-9))) +
    ggplot2::scale_size_continuous(range = OS_FIG_EXT$tree_leaf_mm, limits = c(min(leaves$n), max(leaves$n) + 1e-9),
                                   breaks = scales::breaks_pretty(n = 3),
                                   guide = ggplot2::guide_legend(title = "Genes", title.position = "top", order = 2,
                                                                 override.aes = list(fill = OS_FIG$col_ns))) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.04))) +
    ggplot2::scale_y_continuous(breaks = seq_len(n), labels = lab_fun, position = "right",
                                expand = ggplot2::expansion(add = 0.6)) +
    ggplot2::labs(x = NULL, y = NULL) +
    theme_omicstat(journal = journal, axes = "none", legend = "right") +
    ggplot2::theme(axis.text.y.right = ggplot2::element_text(size = OS_FIG$size_axis_text, hjust = 0, lineheight = 0.85,
                                                             margin = ggplot2::margin(l = 1, unit = "mm")),
                   axis.ticks.length.y = grid::unit(0, "mm"))
  cap <- paste0("Hierarchical clustering of the ", n, " gene sets with the smallest adjusted P (adjusted P < ", padj_threshold, ") by gene overlap ",
                "(distance 1 ", OS_MINUS, " Jaccard index, ", hclust_method, " linkage), cut into ", k, " clusters (branch colours). ",
                "Dot colour, ", "-log10 adjusted P; dot size, number of genes in the set.")
  os_with_meta(p, figure_type = "term_tree", default_height_mm = min(170, 18 + 4.4 * n), caption = cap,
               encodings = list(colour = as.list(cols), fill = list(scale = "sequential", palette = as.list(OS_PAL_SEQUENTIAL))),
               thresholds = list(padj = padj_threshold),
               counts = as.list(stats::setNames(as.integer(table(factor(cl_lab[cl], levels = cl_lab))), cl_lab)),
               data = list(term_order = as.list(d$term_id[hc$order]), clusters = stats::setNames(as.list(cl_lab[cl]), d$term_id),
                           method = paste0("1 - Jaccard / ", hclust_method)))
}

# ---------------------------------------------------------------------------
# Several GSEA running-score curves in one panel (gseaplot2-style)
# ---------------------------------------------------------------------------
# stats: named numeric ranking metric; sets: named list display name ->
# genes (at most OS_FIG_EXT$gsea_multi_max sets, one colour each from the
# colour registry, family "gene_set"); nes / padj: optional named numeric
# vectors (by set name) shown in the legend. Running scores come from
# os_gsea_running_score() (weighted KS, weight 1, deterministic tie-break).
# Tracks: running scores (one line per set) / hit positions (one row per
# set, in legend order) / ranking metric. Legend at the bottom (one set per
# line) because each entry carries its NES and adjusted P.
os_gsea_multi <- function(stats, sets, nes = NULL, padj = NULL, colour_registry = NULL, journal = NULL) {
  if (!is.list(sets) || is.null(names(sets)) || any(!nzchar(names(sets)))) stop("OS_INVALID_INPUT: sets must be a named list (display name -> genes).", call. = FALSE)
  k <- length(sets)
  if (k > OS_FIG_EXT$gsea_multi_max) {
    stop(sprintf("OS_TOO_MANY_CATEGORIES: %d gene sets in one GSEA panel; at most %d (one colour each). Split into panels.",
                 k, OS_FIG_EXT$gsea_multi_max), call. = FALSE)
  }
  nm <- names(sets)
  os_assert_latin(nm, "gene set names")
  rs <- lapply(nm, function(s) { r <- os_gsea_running_score(stats, sets[[s]]); r$set <- s; r })
  n <- nrow(rs[[1]])
  cr <- os_colours_for(nm, family = "gene_set", registry = colour_registry)
  cols <- cr$colours[nm]
  esc <- function(s) gsub("\"", "\\\\\"", gsub("\\\\", "\\\\\\\\", s))
  labs <- vapply(nm, function(s) {
    stat <- character(0)
    if (!is.null(nes) && !is.na(nes[s])) stat <- c(stat, sprintf("\"NES = %s\"", os_num(round(nes[[s]], 2), digits = 2)))
    if (!is.null(padj) && !is.na(padj[s])) stat <- c(stat, os_p_plotmath(padj[[s]], adjusted = TRUE))
    if (!length(stat)) return(sprintf("\"%s\"", esc(s)))
    sprintf("\"%s\"~~\"(\"*%s*\")\"", esc(s), paste(stat, collapse = "*\", \"*"))
  }, character(1))
  lab_expr <- parse(text = labs)
  all_rs <- do.call(rbind, rs)
  all_rs$set <- factor(all_rs$set, levels = nm)
  peaks <- vapply(rs, function(r) r$es[which.max(abs(r$es))], numeric(1))
  xs <- ggplot2::scale_x_continuous(limits = c(0, n + 1), expand = c(0, 0), labels = os_axis_labels)
  top <- ggplot2::ggplot(all_rs, ggplot2::aes(x = rank, y = es, colour = set)) +
    ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data)) +
    ggplot2::scale_colour_manual(values = cols, breaks = nm, labels = lab_expr,
                                 guide = ggplot2::guide_legend(title = NULL, ncol = 1, override.aes = list(linewidth = os_lw(1.2)))) +
    xs + ggplot2::scale_y_continuous(labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.08)) +
    ggplot2::labs(x = NULL, y = OS_AXIS$running_es) +
    theme_omicstat(journal = journal, legend = "bottom") +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank(),
                   axis.line.x = ggplot2::element_blank(), plot.margin = ggplot2::margin(2, 2, 0, 2, unit = "mm"),
                   legend.justification = "left", legend.text = ggplot2::element_text(size = OS_FIG$size_legend_text, hjust = 0),
                   legend.key.width = grid::unit(4, "mm"))
  hits <- all_rs[all_rs$hit, ]
  hits$row <- k - match(as.character(hits$set), nm)          # first set in the top row
  mid <- ggplot2::ggplot(hits) +
    ggplot2::geom_segment(ggplot2::aes(x = rank, xend = rank, y = row + 0.1, yend = row + 0.9, colour = set),
                          linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::scale_colour_manual(values = cols, breaks = nm, guide = "none") +
    xs + ggplot2::scale_y_continuous(limits = c(0, k), expand = c(0, 0)) +
    theme_omicstat(journal = journal, axes = "track", legend = "none") +
    ggplot2::theme(plot.margin = ggplot2::margin(0.5, 2, 0.5, 2, unit = "mm"))
  zero_cross <- which(diff(sign(rs[[1]]$metric)) != 0)[1]
  bot <- ggplot2::ggplot(rs[[1]], ggplot2::aes(x = rank, y = metric)) +
    ggplot2::geom_area(fill = OS_FIG$col_ns, colour = NA) +
    ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    xs + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "Rank in ordered gene list", y = OS_AXIS$ranked_metric) +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(plot.margin = ggplot2::margin(0, 2, 2, 2, unit = "mm"))
  if (!is.na(zero_cross)) bot <- bot + os_vline(zero_cross)
  p <- patchwork::wrap_plots(top, mid, bot, ncol = 1, heights = c(3, 0.3 * k + 0.2, 1.6), guides = "collect") &
    ggplot2::theme(legend.position = "bottom", legend.justification = "left",
                   legend.text = ggplot2::element_text(size = OS_FIG$size_legend_text, hjust = 0))
  per_set <- vapply(nm, function(s) {
    paste0(s, " (", sum(rs[[match(s, nm)]]$hit), " genes in the list",
           if (!is.null(nes) && !is.na(nes[s])) paste0(", NES = ", os_num(nes[[s]], digits = 2)) else "",
           if (!is.null(padj) && !is.na(padj[s])) paste0(", adjusted P = ", os_p_text(padj[[s]])) else "", ")")
  }, character(1))
  cap <- paste0("GSEA running enrichment scores of ", k, " gene sets in one ranked list of ", os_num(n), " genes. ",
                "Top, running enrichment score (weighted Kolmogorov", OS_NDASH, "Smirnov statistic, weight 1), one line per set. ",
                "Middle, positions of the set members, one row per set in legend order. ", .os_gsea_bottom_caption(zero_cross), " ",
                "Sets: ", paste(per_set, collapse = "; "), ".")
  os_with_meta(p, figure_type = "gsea_multi", default_height_mm = min(170, 72 + 6 * k), caption = cap,
               encodings = list(colour = as.list(cols)),
               counts = stats::setNames(lapply(rs, function(r) sum(r$hit)), nm),
               data = list(sets = as.list(nm), list_size = n, es_peak = stats::setNames(as.list(round(peaks, 6)), nm),
                           nes = if (!is.null(nes)) as.list(nes[nm]) else NULL, padj = if (!is.null(padj)) as.list(padj[nm]) else NULL),
               colour_registry = cr$registry)
}
