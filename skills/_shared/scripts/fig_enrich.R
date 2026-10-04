# fig_enrich.R -- standard enrichment figures: ORA/GSEA dot plot, NES bar
# chart, GSEA running-score curve, multi-group comparison dot plot.
# ASCII only on purpose. Requires fig_style.R.
#
# Input: an "enrichment table" (one row per gene set) with these columns
# (clusterProfiler / fgsea results are mapped onto them by the modules):
#   term_id, term_name, database        character
#   n_genes      integer   genes of the list in the set (ORA "Count")
#   set_size     integer   size of the set after filtering to the universe
#   gene_ratio   numeric   n_genes / input genes annotated in the database
#                          (clusterProfiler ORA GeneRatio k/n)
#   nes          numeric   normalized enrichment score (GSEA)
#   pvalue, padj numeric
#   group        character (compare dot plot only)
# Term order on the y axis is decided here, never by the caller: by the x
# value (largest at the top), ties by padj then term_id.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_enrich.R.", call. = FALSE)

.os_enrich_check <- function(et, cols, fn) {
  miss <- setdiff(cols, names(et))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMNS: %s needs column(s) %s.", fn, paste(miss, collapse = ", ")), call. = FALSE)
}

# Written definitions shared by the enrichment captions and figure_spec
# "definition" (docs/FIGURE_STYLE.md sec 8.5-8.8). The gene ratio is the
# clusterProfiler ORA GeneRatio k/n; it is NOT the GSEA core-enrichment
# fraction, which is a different quantity.
OS_ENRICH_DEFINITIONS <- list(
  gene_ratio = "gene ratio = input genes in the set / input genes annotated in the database",
  nes = "NES from preranked GSEA (enrichment score normalized to the mean of permuted scores of the same sign)"
)

# One sentence for QC / Methods when no gene set passes the threshold:
# threshold, number of sets tested and the smallest adjusted P observed.
os_enrich_empty_note <- function(et, padj_threshold) {
  pa <- if ("padj" %in% names(et)) et$padj else numeric(0)
  n_tested <- sum(!is.na(pa)); n_na <- sum(is.na(pa))
  smallest <- if (n_tested) os_p_text(min(pa, na.rm = TRUE)) else "not available"
  sprintf("No gene set reached adjusted P < %s (%s gene sets tested%s; smallest adjusted P = %s).",
          padj_threshold, os_num(n_tested),
          if (n_na) sprintf(", %s more without an adjusted P", os_num(n_na)) else "", smallest)
}
.os_enrich_empty_stop <- function(et, padj_threshold, extra = "") {
  stop(paste0("OS_EMPTY_DATA: ", os_enrich_empty_note(et, padj_threshold), extra, " Nothing to plot; report the sentence in QC/Methods instead."),
       call. = FALSE)
}

# Fixed size scale for gene counts so dot sizes are comparable across panels.
.os_count_size_scale <- function(title, limits) {
  ggplot2::scale_size_continuous(range = c(1.0, 3.6), limits = limits, breaks = scales::breaks_pretty(n = 3),
                                 guide = ggplot2::guide_legend(title = title, title.position = "top", order = 2,
                                                               override.aes = list(colour = OS_FIG$col_ink)))
}
.os_sig_colour_scale <- function(limits) {
  ggplot2::scale_colour_gradientn(colours = OS_PAL_SEQUENTIAL, limits = limits, labels = os_axis_labels,
                                  guide = ggplot2::guide_colourbar(title = OS_AXIS$neglog10padj, title.position = "top",
                                                                   order = 1, barwidth = grid::unit(OS_FIG$legend_key_mm * 0.8, "mm"),
                                                                   barheight = grid::unit(OS_FIG$legend_key_mm * 5, "mm"),
                                                                   frame.colour = OS_FIG$col_ink, ticks.colour = OS_FIG$col_ink))
}

# ---------------------------------------------------------------------------
# Dot plot (ORA: x = gene ratio; GSEA: x = NES)
# ---------------------------------------------------------------------------
os_enrich_dotplot <- function(et, x = c("gene_ratio", "nes"), top_n = 15, padj_threshold = 0.05,
                              title = NULL, database_label = NULL, journal = NULL) {
  x <- match.arg(x)
  .os_enrich_check(et, c("term_id", "term_name", "padj", x, if (x == "gene_ratio") "n_genes" else "set_size"), "os_enrich_dotplot")
  d <- et[!is.na(et$padj) & et$padj < padj_threshold, , drop = FALSE]
  n_sig <- nrow(d)
  if (!n_sig) .os_enrich_empty_stop(et, padj_threshold)
  if (x == "nes") {
    d <- d[order(-abs(d$nes), d$padj, d$term_id, method = "radix"), , drop = FALSE]
  } else {
    d <- d[order(d$padj, -d$gene_ratio, d$term_id, method = "radix"), , drop = FALSE]
  }
  d <- utils::head(d, top_n)
  d$.x <- d[[x]]
  d <- d[order(d$.x, -d$padj, d$term_id, method = "radix", decreasing = FALSE), , drop = FALSE]
  d$.y <- factor(d$term_id, levels = d$term_id)
  labs <- stats::setNames(os_wrap(d$term_name), d$term_id)
  os_assert_latin(labs, "term names")
  d$.sig <- -log10(d$padj)
  d$.size <- if (x == "gene_ratio") d$n_genes else d$set_size
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .x, y = .y))
  if (x == "nes") p <- p + ggplot2::geom_vline(xintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref))
  p <- p + ggplot2::geom_point(ggplot2::aes(size = .size, colour = .sig), shape = 16, stroke = 0) +
    .os_sig_colour_scale(c(-log10(padj_threshold), max(d$.sig, -log10(padj_threshold)))) +
    .os_count_size_scale(if (x == "gene_ratio") "Gene count" else "Set size", c(min(d$.size), max(d$.size))) +
    ggplot2::scale_y_discrete(labels = labs) +
    ggplot2::labs(x = if (x == "nes") OS_AXIS$nes else OS_AXIS$generatio, y = NULL, title = title) +
    theme_omicstat(journal = journal, legend = "right") +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = OS_FIG$size_axis_text, lineheight = 0.85))
  if (x == "gene_ratio") {
    p <- p + ggplot2::scale_x_continuous(limits = c(0, max(d$.x) * 1.08), labels = os_axis_labels,
                                         breaks = scales::breaks_extended(n = 4),
                                         expand = ggplot2::expansion(mult = c(0, 0.02)))
  } else {
    lim <- os_sym_limit(d$.x, 1)
    p <- p + ggplot2::scale_x_continuous(limits = c(-lim, lim), labels = os_axis_labels)
  }
  # selection and ordering rules, written exactly as implemented above
  sel_txt <- if (x == "nes") {
    sprintf("the %d gene sets with the largest |NES| among the %d with adjusted P < %s (ties broken by smaller adjusted P, then term ID)",
            nrow(d), n_sig, padj_threshold)
  } else {
    sprintf("the %d gene sets with the smallest adjusted P among the %d with adjusted P < %s (ties broken by larger gene ratio, then term ID)",
            nrow(d), n_sig, padj_threshold)
  }
  ord_txt <- sprintf("ordered by %s, largest at the top (ties by adjusted P, then term ID)", if (x == "nes") "NES" else "gene ratio")
  def_txt <- if (x == "nes") OS_ENRICH_DEFINITIONS$nes else OS_ENRICH_DEFINITIONS$gene_ratio
  cap <- paste0(if (x == "gene_ratio") "Over-representation analysis" else "Gene set enrichment analysis",
                if (!is.null(database_label)) paste0(" (", database_label, ")") else "", ". ",
                "Selection: ", sel_txt, "; ", ord_txt, ". ",
                toupper(substr(def_txt, 1, 1)), substring(def_txt, 2), ". ",
                "Dot colour, -log10 adjusted P; dot size, ", if (x == "gene_ratio") "number of input genes in the set" else "gene set size", ".")
  os_with_meta(p, figure_type = "enrichment_dotplot", default_height_mm = min(170, 22 + 5.2 * nrow(d)), caption = cap,
               encodings = list(colour = list(scale = "sequential", palette = as.list(OS_PAL_SEQUENTIAL)),
                                size = list(range_mm = list(1.0, 3.6))),
               thresholds = list(padj = padj_threshold), counts = list(significant = n_sig, shown = nrow(d)),
               definition = c(list(selection = sel_txt, ordering = ord_txt), stats::setNames(list(def_txt), x)),
               data = list(term_ids = as.list(rev(as.character(d$term_id)))))
}

# ---------------------------------------------------------------------------
# NES bar chart: top n positive and top n negative sets
# ---------------------------------------------------------------------------
# positive_end / negative_end (S4, fgsea-prerank F3): what the two ends of the
# ranking mean, e.g. "higher expression in treated than untreated"; NULL keeps
# the expression wording, which is only right for a DE statistic.
os_nes_bar <- function(et, top_n_each = 10, padj_threshold = 0.05, database_label = NULL, journal = NULL,
                       positive_end = NULL, negative_end = NULL) {
  .os_enrich_check(et, c("term_id", "term_name", "nes", "padj"), "os_nes_bar")
  d <- et[!is.na(et$padj) & et$padj < padj_threshold & is.finite(et$nes), , drop = FALSE]
  if (!nrow(d)) .os_enrich_empty_stop(et, padj_threshold)
  n_sig <- nrow(d)
  up <- d[d$nes > 0, ]; up <- utils::head(up[order(-up$nes, up$padj, up$term_id, method = "radix"), ], top_n_each)
  dn <- d[d$nes < 0, ]; dn <- utils::head(dn[order(dn$nes, dn$padj, dn$term_id, method = "radix"), ], top_n_each)
  d <- rbind(up, dn)
  d <- d[order(d$nes, d$term_id, method = "radix"), , drop = FALSE]
  d$.y <- factor(d$term_id, levels = d$term_id)
  d$.dir <- ifelse(d$nes > 0, "up", "down")
  labs <- stats::setNames(os_wrap(d$term_name), d$term_id)
  lim <- os_sym_limit(d$nes, 1)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = nes, y = .y, fill = .dir)) +
    ggplot2::geom_col(width = 0.7, colour = NA) +
    ggplot2::geom_vline(xintercept = 0, colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_axis)) +
    ggplot2::scale_fill_manual(values = c(up = OS_FIG$col_up, down = OS_FIG$col_down), guide = "none") +
    ggplot2::scale_x_continuous(limits = c(-lim, lim), labels = os_axis_labels, expand = c(0, 0)) +
    ggplot2::scale_y_discrete(labels = labs) +
    ggplot2::labs(x = OS_AXIS$nes, y = NULL) +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(axis.text.y = ggplot2::element_text(lineheight = 0.85), axis.line.y = ggplot2::element_blank(),
                   axis.ticks.y = ggplot2::element_blank())
  sel_txt <- sprintf(paste0("in each direction, up to %d gene sets with the largest |NES| among the %d with adjusted P < %s ",
                            "(ties broken by smaller adjusted P, then term ID)"), top_n_each, n_sig, padj_threshold)
  ord_txt <- "bars ordered by NES, largest at the top (ties by term ID)"
  cap <- paste0("Normalized enrichment scores", if (!is.null(database_label)) paste0(" (", database_label, ")") else "",
                ". Selection: ", sel_txt, "; ", nrow(up), " positive and ", nrow(dn), " negative sets shown; ", ord_txt, ". ",
                toupper(substr(OS_ENRICH_DEFINITIONS$nes, 1, 1)), substring(OS_ENRICH_DEFINITIONS$nes, 2), ". ",
                if (is.null(positive_end) && is.null(negative_end))
                  "Red, enriched among up-regulated genes (NES > 0); blue, among down-regulated genes (NES < 0)."
                else sprintf("Red, NES > 0: enriched at the positive end of the ranking (%s); blue, NES < 0: enriched at the negative end (%s).",
                             positive_end %||% "positive scores", negative_end %||% "negative scores"))
  os_with_meta(p, figure_type = "nes_bar", default_height_mm = min(170, 20 + 4.6 * nrow(d)), caption = cap,
               encodings = list(fill = list(up = OS_FIG$col_up, down = OS_FIG$col_down)),
               thresholds = list(padj = padj_threshold), counts = list(up = nrow(up), down = nrow(dn), significant = n_sig),
               definition = list(selection = sel_txt, ordering = ord_txt, nes = OS_ENRICH_DEFINITIONS$nes),
               data = list(term_ids = as.list(rev(as.character(d$term_id)))))
}

# ---------------------------------------------------------------------------
# GSEA running enrichment score curve (three aligned tracks)
# ---------------------------------------------------------------------------
# stats: named numeric vector (gene -> ranking metric), any order; set: genes.
# The running score is the weighted Kolmogorov-Smirnov statistic of
# Subramanian et al. 2005 with weight p = 1 (the clusterProfiler/fgsea
# default). Ties in the metric are broken by gene id (C locale) so the
# curve is deterministic.
os_gsea_running_score <- function(stats, set, p = 1) {
  o <- order(-stats, names(stats), method = "radix")
  s <- stats[o]
  hit <- names(s) %in% set
  nh <- sum(hit); n <- length(s)
  if (nh == 0) stop("OS_EMPTY_DATA: no gene of the set is in the ranked list.", call. = FALSE)
  w <- abs(s)^p
  ph <- cumsum(ifelse(hit, w / sum(w[hit]), 0))
  pm <- cumsum(ifelse(hit, 0, 1 / (n - nh)))
  es <- ph - pm
  data.frame(rank = seq_len(n), gene = names(s), metric = unname(s), hit = hit, es = es)
}

# Bottom-track caption (S5 R2): the dashed zero-crossing line is drawn only when
# the ranking metric changes sign, so the caption names it only then.
.os_gsea_bottom_caption <- function(zero_cross) {
  if (!is.na(zero_cross)) "Bottom, ranking metric; dashed line, where it crosses zero."
  else "Bottom, ranking metric; all scores have the same sign, so the metric has no zero crossing and no crossing line is drawn."
}

os_gsea_curve <- function(stats, set, term_name, nes = NULL, padj = NULL, journal = NULL) {
  rs <- os_gsea_running_score(stats, set)
  os_assert_latin(term_name, "term name")
  i_peak <- which.max(abs(rs$es))
  es_peak <- rs$es[i_peak]
  dir_col <- if (es_peak >= 0) OS_FIG$col_up else OS_FIG$col_down
  n <- nrow(rs); fam <- os_font_family()
  xs <- ggplot2::scale_x_continuous(limits = c(0, n + 1), expand = c(0, 0), labels = os_axis_labels)
  top <- ggplot2::ggplot(rs, ggplot2::aes(x = rank, y = es)) +
    ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    os_vline(i_peak) +
    ggplot2::geom_line(colour = dir_col, linewidth = os_lw(OS_FIG$lw_data)) +
    xs + ggplot2::scale_y_continuous(labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.08)) +
    ggplot2::labs(x = NULL, y = OS_AXIS$running_es, title = term_name) +
    theme_omicstat(journal = journal, legend = "none") +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank(),
                   axis.line.x = ggplot2::element_blank(), plot.margin = ggplot2::margin(2, 2, 0, 2, unit = "mm"))
  if (!is.null(nes) || !is.null(padj)) {
    lab <- paste0("NES == \"", formatC(nes %||% NA, format = "f", digits = 2), "\"")
    lab2 <- os_p_plotmath(padj %||% NA, adjusted = TRUE)
    ytxt <- if (es_peak >= 0) max(rs$es) else min(rs$es)
    xtxt <- if (es_peak >= 0) n * 0.97 else n * 0.03
    hj <- if (es_peak >= 0) 1 else 0
    vj1 <- if (es_peak >= 0) 1 else -1.2
    top <- top + ggplot2::annotate("text", x = xtxt, y = ytxt, label = lab, parse = TRUE, hjust = hj, vjust = vj1,
                                   size = os_fs(OS_FIG$size_annot), family = fam) +
      ggplot2::annotate("text", x = xtxt, y = ytxt, label = lab2, parse = TRUE, hjust = hj,
                        vjust = if (es_peak >= 0) 2.4 else 0.2, size = os_fs(OS_FIG$size_annot), family = fam)
  }
  hits <- rs[rs$hit, ]
  mid <- ggplot2::ggplot(hits) +
    ggplot2::geom_segment(ggplot2::aes(x = rank, xend = rank, y = 0, yend = 1), colour = OS_FIG$col_ink,
                          linewidth = os_lw(OS_FIG$lw_segment)) +
    xs + ggplot2::scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
    theme_omicstat(journal = journal, axes = "track") +
    ggplot2::theme(plot.margin = ggplot2::margin(0.5, 2, 0.5, 2, unit = "mm"))
  zero_cross <- which(diff(sign(rs$metric)) != 0)[1]
  bot <- ggplot2::ggplot(rs, ggplot2::aes(x = rank, y = metric)) +
    ggplot2::geom_area(fill = OS_FIG$col_ns, colour = NA) +
    ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    xs + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = "Rank in ordered gene list", y = OS_AXIS$ranked_metric) +
    theme_omicstat(journal = journal) +
    ggplot2::theme(plot.margin = ggplot2::margin(0, 2, 2, 2, unit = "mm"))
  if (!is.na(zero_cross)) bot <- bot + os_vline(zero_cross)
  p <- patchwork::wrap_plots(top, mid, bot, ncol = 1, heights = c(3, 0.45, 1.3))
  cap <- paste0("GSEA running enrichment score for ", term_name, ". Top, running enrichment score (weighted Kolmogorov",
                OS_NDASH, "Smirnov statistic, weight 1); dashed line, position of the maximum deviation. Middle, positions of the ",
                sum(rs$hit), " set members in the ranked list of ", os_num(n), " genes. ", .os_gsea_bottom_caption(zero_cross),
                if (!is.null(nes)) paste0(" NES = ", formatC(nes, format = "f", digits = 2), ", adjusted P = ", os_p_text(padj %||% NA), ".") else "")
  os_with_meta(p, figure_type = "gsea_curve", default_height_mm = 62, caption = cap,
               encodings = list(line = dir_col),
               counts = list(set_in_list = sum(rs$hit), list_size = n),
               data = list(es_peak = round(es_peak, 6), peak_rank = i_peak))
}

# ---------------------------------------------------------------------------
# Multi-group comparison dot plot (compareCluster)
# ---------------------------------------------------------------------------
os_enrich_compare <- function(et, groups_order = NULL, top_n_per_group = 5, padj_threshold = 0.05,
                              database_label = NULL, journal = NULL) {
  .os_enrich_check(et, c("group", "term_id", "term_name", "gene_ratio", "padj", "n_genes"), "os_enrich_compare")
  d <- et[!is.na(et$padj) & et$padj < padj_threshold, , drop = FALSE]
  if (!nrow(d)) .os_enrich_empty_stop(et, padj_threshold, " (all groups pooled)")
  g_lv <- groups_order %||% sort(unique(as.character(d$group)), method = "radix")
  keep <- unlist(lapply(g_lv, function(g) {
    s <- d[d$group == g, ]; utils::head(s$term_id[order(s$padj, -s$gene_ratio, s$term_id, method = "radix")], top_n_per_group)
  }))
  keep <- unique(keep)
  d <- d[d$term_id %in% keep, , drop = FALSE]
  # term order: grouped by the first group in which the term is selected, then by padj
  first_g <- vapply(keep, function(t) match(TRUE, vapply(g_lv, function(g) t %in% d$term_id[d$group == g], logical(1))), integer(1))
  best_p <- vapply(keep, function(t) min(d$padj[d$term_id == t]), numeric(1))
  term_lv <- keep[order(first_g, best_p, keep, method = "radix", decreasing = FALSE)]
  d$.y <- factor(d$term_id, levels = rev(term_lv))
  d$.x <- factor(as.character(d$group), levels = g_lv)
  d$.sig <- -log10(d$padj)
  nm <- d[!duplicated(d$term_id), ]
  labs <- stats::setNames(os_wrap(nm$term_name), nm$term_id)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .x, y = .y)) +
    ggplot2::geom_point(ggplot2::aes(size = gene_ratio, colour = .sig), shape = 16, stroke = 0) +
    .os_sig_colour_scale(c(-log10(padj_threshold), max(d$.sig))) +
    ggplot2::scale_size_continuous(range = c(1.0, 3.6), labels = os_axis_labels,
                                   guide = ggplot2::guide_legend(title = OS_AXIS$generatio, title.position = "top", order = 2)) +
    ggplot2::scale_y_discrete(labels = labs) +
    ggplot2::labs(x = NULL, y = NULL) +
    theme_omicstat(journal = journal, axes = "box") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1),
                   axis.text.y = ggplot2::element_text(lineheight = 0.85))
  sel_txt <- sprintf(paste0("in each group, up to %d gene sets with the smallest adjusted P among those with adjusted P < %s ",
                            "(ties broken by larger gene ratio, then term ID); the union of %d sets is shown"),
                     top_n_per_group, padj_threshold, length(keep))
  ord_txt <- sprintf(paste0("rows grouped by the first group (in axis order) in which the set has adjusted P < %s, then ordered by ",
                            "its smallest adjusted P across groups (ties by term ID)"), padj_threshold)
  cap <- paste0("Comparison of enriched gene sets across groups", if (!is.null(database_label)) paste0(" (", database_label, ")") else "",
                ". Selection: ", sel_txt, "; ", ord_txt, ". ",
                toupper(substr(OS_ENRICH_DEFINITIONS$gene_ratio, 1, 1)), substring(OS_ENRICH_DEFINITIONS$gene_ratio, 2), ". ",
                "Dot colour, -log10 adjusted P; dot size, gene ratio. An empty position means the set is not significant in that group.")
  os_with_meta(p, figure_type = "enrichment_compare", default_height_mm = min(170, 25 + 4.8 * length(keep)), caption = cap,
               thresholds = list(padj = padj_threshold),
               definition = list(selection = sel_txt, ordering = ord_txt, gene_ratio = OS_ENRICH_DEFINITIONS$gene_ratio),
               data = list(groups = as.list(g_lv), term_ids = as.list(term_lv)))
}
