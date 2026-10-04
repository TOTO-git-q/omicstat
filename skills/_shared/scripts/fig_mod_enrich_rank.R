# fig_mod_enrich_rank.R -- M2b enrichment, scoring, and gene-set test figures.
# ---- fgsea-prerank ----
os_fgsea_nes_figure <- function(et, alpha, collection, journal = NULL, positive_end = NULL, negative_end = NULL) {
  et$term_name <- gsub("_", " ", sub("^[0-9]+_", "", et$term_name))
  et$term_name <- ifelse(nchar(et$term_name) > 38,
                         paste0(substr(et$term_name, 1, 35), "..."), et$term_name)
  os_nes_bar(et, top_n_each = 5, padj_threshold = alpha,
             database_label = collection, journal = journal,
             positive_end = positive_end, negative_end = negative_end)
}

os_fgsea_curve_figure <- function(stats, set, term_name, nes, padj, alpha, journal = NULL) {
  term_name <- gsub("_", " ", sub("^[0-9]+_", "", term_name))
  p <- os_gsea_curve(stats, set, term_name, nes = nes, padj = padj, journal = journal)
  m <- attr(p, "os_meta")
  m$caption <- paste0(m$caption, " Reporting threshold: BH adjusted P < ", alpha, ".")
  m$thresholds <- list(padj = alpha)
  attr(p, "os_meta") <- m
  p
}

# ---- gsva-score ----
os_gsva_score_heatmap <- function(scores, sample_table = NULL, sample_col = "sample",
                                  group_col = NULL, min_size = 5, max_size = 500, journal = NULL) {
  ord <- order(-apply(scores, 1, stats::var), rownames(scores), method = "radix")
  m <- scores[utils::head(ord, 20), , drop = FALSE]
  if (!is.null(sample_table) && !is.null(group_col)) {
    groups <- as.character(sample_table[[group_col]])
    sample_ids <- as.character(sample_table[[sample_col]])
    selected <- unlist(lapply(sort(unique(groups), method = "radix"), function(g)
      utils::head(sort(sample_ids[groups == g], method = "radix"), 6)), use.names = FALSE)
    selected <- utils::head(selected, 24)
    annot <- data.frame(Group = factor(groups[match(selected, sample_ids)], levels = sort(unique(groups), method = "radix")), row.names = selected)
  } else {
    selected <- utils::head(sort(colnames(m), method = "radix"), 24)
    annot <- NULL
  }
  m <- m[, selected, drop = FALSE]
  row_mean <- rowMeans(m)
  row_sd <- apply(m, 1, stats::sd)
  z <- sweep(sweep(m, 1, row_mean, "-"), 1, ifelse(row_sd > 0, row_sd, 1), "/")
  p <- os_heatmap(z, value_title = "Row z score", scale_type = "diverging",
                  cluster_rows = TRUE, cluster_cols = TRUE, italic_rows = FALSE,
                  show_col_labels = FALSE, col_annot = annot,
                  annot_colours = if (is.null(annot)) NULL else list(Group = os_group_colours(levels(annot$Group))), journal = journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste0(meta$caption, " GSVA score heatmap: ", nrow(m), " of ", nrow(scores),
                         " gene sets and ", ncol(m), " of ", ncol(scores), " samples shown. Set sizes after gene ID intersection and GSVA's removal of constant rows: ",
                         min_size, "-", max_size, ". No significance threshold applies to this descriptive heatmap.")
  meta$counts <- list(sets_shown = nrow(m), sets_scored = nrow(scores),
                      samples_shown = ncol(m), samples_scored = ncol(scores))
  attr(p, "os_meta") <- meta
  p
}

# ---- limma-camera ----
os_camera_set_bar <- function(tab, alpha, method, journal = NULL) {
  d <- tab[order(tab$padj, tab$term_id, method = "radix"), , drop = FALSE]
  d <- utils::head(d, 15)
  d$display <- ifelse(nchar(d$term_name) > 38,
                      paste0(substr(d$term_name, 1, 35), "..."), d$term_name)
  d$.x <- -log10(pmax(d$padj, .Machine$double.xmin))
  d$.direction <- factor(ifelse(d$direction %in% c("Up", "Down"), d$direction, "Mixed"), levels = c("Up", "Down", "Mixed"))
  d$.term <- factor(d$term_id, levels = rev(d$term_id))
  lab <- stats::setNames(d$display, d$term_id)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .x, y = .term, fill = .direction)) +
    ggplot2::geom_col() +
    ggplot2::geom_vline(xintercept = -log10(alpha), colour = OS_FIG$col_ref,
                        linewidth = os_lw(OS_FIG$lw_ref), linetype = "dashed") +
    ggplot2::scale_fill_manual(values = c(Up = OS_FIG$col_up, Down = OS_FIG$col_down,
                                          Mixed = OS_FIG$col_ns), drop = TRUE,
                               guide = os_guide_legend("Direction")) +
    ggplot2::scale_y_discrete(labels = lab) +
    ggplot2::scale_x_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "-log10 adjusted P", y = "Gene set", fill = "Direction") +
    theme_omicstat(journal = journal, legend = "right")
  caption <- sprintf("%s gene-set test: %d of %d tested sets shown, ordered by adjusted P. Dashed line, BH adjusted P < %s; bar length, -log10 adjusted P; colour, reported direction. Set counts are after input-ID intersection.",
                     method, nrow(d), nrow(tab), alpha)
  os_with_meta(p, figure_type = "gene_set_test_bar", default_height_mm = min(120, max(45, 24 + 8 * nrow(d))),
               caption = caption, thresholds = list(padj = alpha),
               counts = list(tested = nrow(tab), shown = nrow(d)))
}

# ---- S4 shared additions (limma-camera F3, gsva-score F4) ----
# Barcode plot with enrichment worm (the limma::barcodeplot display drawn in
# the shared layer). stat: named numeric vector over all ranked features;
# set_ids: members of ONE gene set; worm: data.frame(rank, enrichment) that the
# MODULE computed with limma::tricubeMovingAverage (as barcodeplot does), or
# NULL. Ranks run from the most negative (left) to the most positive (right),
# as in barcodeplot. stat_label names the statistic (e.g. "moderated t").
os_barcode <- function(stat, set_ids, set_name, worm = NULL, stat_label = "statistic", test_label = NULL, journal = NULL) {
  stat <- stat[is.finite(stat)]
  o <- order(stat, names(stat), method = "radix")
  d <- data.frame(rank = seq_along(o), stat = unname(stat[o]), id = names(stat)[o], stringsAsFactors = FALSE)
  hit <- d[d$id %in% set_ids, , drop = FALSE]
  if (!nrow(hit)) stop("OS_EMPTY_DATA: os_barcode: no set member among the ranked features.", call. = FALSE)
  pb <- ggplot2::ggplot(d, ggplot2::aes(x = rank, y = stat)) +
    ggplot2::geom_area(fill = OS_FIG$col_ns, colour = NA) +
    ggplot2::geom_segment(data = hit, ggplot2::aes(x = rank, xend = rank, y = min(d$stat), yend = max(d$stat)),
                          colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment)) +
    os_hline(0) +
    ggplot2::scale_x_continuous(labels = os_axis_labels, expand = c(0, 0)) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = sprintf("Rank of %s (most negative left)", stat_label), y = stat_label) +
    theme_omicstat(journal = journal, legend = "none")
  plots <- list(pb)
  if (!is.null(worm)) {
    pw <- ggplot2::ggplot(worm, ggplot2::aes(x = rank, y = enrichment)) + os_hline(1) +
      ggplot2::geom_line(colour = OS_FIG$col_up, linewidth = os_lw(OS_FIG$lw_data)) +
      ggplot2::scale_x_continuous(labels = os_axis_labels, expand = c(0, 0), limits = c(1, nrow(d))) +
      ggplot2::scale_y_continuous(labels = os_axis_labels) +
      ggplot2::labs(x = NULL, y = "Relative enrichment", title = set_name) +
      theme_omicstat(journal = journal, legend = "none")
    plots <- list(pw, pb)
  } else plots[[1]] <- pb + ggplot2::labs(title = set_name)
  p <- if (length(plots) == 2) os_compose(plots, ncol = 1, heights = c(1, 1.2), journal = journal) else plots[[1]]
  cap <- sprintf(paste0("Barcode plot for gene set %s: %d features ranked by %s (grey area), the %d set members as vertical bars%s. %s"),
                 set_name, nrow(d), stat_label, nrow(hit),
                 if (!is.null(worm)) "; the upper panel is the relative enrichment worm (tricube moving average of set membership, 1 = no enrichment)" else "",
                 test_label %||% "")
  os_with_meta(p, figure_type = "barcode", default_height_mm = if (is.null(worm)) 45 else 80, caption = cap,
               counts = list(ranked = nrow(d), members = nrow(hit)))
}

# Mean-difference plot with gene-set members highlighted (limma User's Guide
# 18.1.10 style). d: data.frame(feature_id, ave_expr, log2fc); sets: named
# list of member IDs (at most two sets, e.g. Y and X).
os_md_set_highlight <- function(d, sets, contrast_label, journal = NULL) {
  .os_require_cols(d, c("feature_id", "ave_expr", "log2fc"), "os_md_set_highlight")
  if (length(sets) > 2) stop("OS_TOO_MANY_CATEGORIES: os_md_set_highlight shows at most two sets.", call. = FALSE)
  d$set <- "Other"
  for (nm in rev(names(sets))) d$set[d$feature_id %in% sets[[nm]]] <- nm
  lv <- c("Other", names(sets))
  pal <- c(Other = OS_FIG$col_ns, os_colours_for(names(sets), "category")$colours[names(sets)])
  d$set <- factor(d$set, levels = lv)
  d <- d[order(d$set != "Other", d$feature_id, method = "radix"), , drop = FALSE]
  hl <- d[d$set != "Other", , drop = FALSE]
  p <- ggplot2::ggplot(d, ggplot2::aes(x = ave_expr, y = log2fc, colour = set)) + os_hline(0) +
    ggplot2::geom_point(data = d[d$set == "Other", ], shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm, stroke = 0) +
    ggplot2::geom_point(data = hl, shape = 16, size = OS_FIG$pt_highlight_mm * 1.4, stroke = 0) +
    ggplot2::scale_colour_manual(values = pal, breaks = lv, drop = FALSE, guide = os_guide_legend("Gene set")) +
    ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "Average log2 expression", y = OS_AXIS$log2fc, title = contrast_label) +
    theme_omicstat(journal = journal, legend = "right")
  cnt <- vapply(names(sets), function(nm) sum(d$set == nm), 0L)
  os_with_meta(p, figure_type = "md_set_highlight", default_height_mm = 70,
               caption = sprintf("Mean-difference plot (%s) of %d features with gene-set members highlighted: %s. Display only; the gene-set test results are in the table.",
                                 contrast_label, nrow(d), paste(sprintf("%s (n = %d)", names(cnt), cnt), collapse = ", ")),
               encodings = list(colour = as.list(pal)), counts = as.list(cnt))
}

# GSVA score by group (PACK F): one small panel per gene set, samples as
# points over a box per group. Purely descriptive: no test annotation is ever
# drawn (score inference is an owner-pending decision).
os_score_by_group <- function(scores, sample_table, sample_col = "sample", group_col, max_sets = 12,
                              value_title = "GSVA score", journal = NULL) {
  ord <- order(-apply(scores, 1, stats::var), rownames(scores), method = "radix")
  sel <- rownames(scores)[utils::head(ord, max_sets)]
  st <- sample_table[match(colnames(scores), sample_table[[sample_col]]), , drop = FALSE]
  if (anyNA(st[[sample_col]])) stop("OS_INVALID_INPUT: os_score_by_group: sample table misses scored samples.", call. = FALSE)
  lv <- sort(unique(as.character(st[[group_col]])), method = "radix")
  long <- do.call(rbind, lapply(sel, function(s) data.frame(set = s, sample = colnames(scores), value = unname(scores[s, ]),
                                                             group = factor(as.character(st[[group_col]]), levels = lv), stringsAsFactors = FALSE)))
  long$set <- factor(long$set, levels = sel)
  cols <- os_group_colours(lv)
  p <- ggplot2::ggplot(long, ggplot2::aes(x = group, y = value, fill = group)) +
    ggplot2::geom_boxplot(outlier.shape = NA, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_box), width = 0.6) +
    ggplot2::geom_point(shape = 21, size = OS_FIG$pt_highlight_mm, colour = OS_FIG$col_point_edge, stroke = os_lw(OS_FIG$lw_point_edge),
                        position = ggplot2::position_nudge(x = 0)) +
    ggplot2::facet_wrap(~set, scales = "free_y", ncol = min(3, length(sel))) +
    ggplot2::scale_fill_manual(values = cols, breaks = lv, guide = os_guide_legend(group_col)) +
    ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = NULL, y = value_title) +
    theme_omicstat(journal = journal, legend = "right") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1))
  n_grp <- table(st[[group_col]])
  os_with_meta(p, figure_type = "score_by_group", default_height_mm = 30 + 38 * ceiling(length(sel) / 3),
               caption = sprintf(paste0("%s by %s for the %d of %d gene sets with the largest score variance; each point is one sample ",
                                        "(%s), boxes show the median and interquartile range. Descriptive only: no group test is shown."),
                                 value_title, group_col, length(sel), nrow(scores),
                                 paste(sprintf("%s n = %d", names(n_grp), as.integer(n_grp)), collapse = ", ")),
               encodings = list(fill = as.list(cols)), counts = list(sets_shown = length(sel), sets_scored = nrow(scores)))
}
