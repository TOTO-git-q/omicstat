# fig_mod_enrich.R -- figure builders added by the M2 enrichment modules
# (MODULE_BUILD_BRIEF sec 4). ASCII only on purpose. Loaded last by fig_all.R,
# after fig_enrich.R / fig_enrich_network.R, so it may call any os_* builder
# defined there. Same rules as fig_mod_bulk.R.

# ---- clusterprofiler-ora ----
os_cp_ora_dotplot <- function(tab, top_n, alpha, ontology, journal) {
  os_enrich_dotplot(tab, x = "gene_ratio", top_n = top_n,
                    padj_threshold = alpha, database_label = paste("GO", ontology), journal = journal)
}

# ---- clusterprofiler-gsea ----
os_cp_gsea_dotplot <- function(tab, top_n, alpha, ontology, journal) {
  os_enrich_dotplot(tab, x = "nes", top_n = top_n,
                    padj_threshold = alpha, database_label = paste("GO", ontology), journal = journal)
}
os_cp_gsea_curve <- function(stats, set, term_name, nes, padj, journal) {
  os_gsea_curve(stats, set, term_name, nes = nes, padj = padj, journal = journal)
}

# ---- clusterprofiler-gsea: S4 additions (PACK F rows 2-3) ----
# Dot plot split by the sign of NES (enrichplot dotplot(split = ".sign") +
# facet grammar): up to top_n_each significant sets per sign, x = NES,
# colour = -log10 adjusted P, size = set size. positive_end / negative_end
# name the two ends of the named ranking (from the ranked_list metadata).
os_cp_gsea_dotplot_signed <- function(tab, top_n_each, alpha, ontology, positive_end, negative_end, journal = NULL,
                                      score_signs = c("both", "positive", "negative")) {
  score_signs <- match.arg(score_signs)
  d <- tab[!is.na(tab$padj) & tab$padj < alpha & is.finite(tab$nes), , drop = FALSE]
  if (!nrow(d)) .os_enrich_empty_stop(tab, alpha)
  n_sig <- nrow(d)
  pos <- d[d$nes > 0, , drop = FALSE]; pos <- utils::head(pos[order(-pos$nes, pos$padj, pos$term_id, method = "radix"), , drop = FALSE], top_n_each)
  neg <- d[d$nes < 0, , drop = FALSE]; neg <- utils::head(neg[order(neg$nes, neg$padj, neg$term_id, method = "radix"), , drop = FALSE], top_n_each)
  # one panel: the positive-NES block on top, the negative-NES block below,
  # each ordered by NES; the zero line separates the two ends of the ranking
  d <- rbind(neg[order(neg$nes, neg$term_id, method = "radix"), , drop = FALSE],
             pos[order(pos$nes, pos$term_id, method = "radix"), , drop = FALSE])
  d$.y <- factor(d$term_id, levels = d$term_id)
  labs <- stats::setNames(os_wrap(d$term_name), d$term_id)
  os_assert_latin(labs, "term names")
  d$.sig <- -log10(d$padj)
  lim <- os_sym_limit(d$nes, 1)
  p <- ggplot2::ggplot(d, ggplot2::aes(x = nes, y = .y)) +
    ggplot2::geom_vline(xintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_point(ggplot2::aes(size = set_size, colour = .sig), shape = 16, stroke = 0) +
    .os_sig_colour_scale(c(-log10(alpha), max(d$.sig, -log10(alpha)))) +
    .os_count_size_scale("Set size", c(min(d$set_size), max(d$set_size))) +
    ggplot2::scale_y_discrete(labels = labs) +
    ggplot2::scale_x_continuous(limits = c(-lim, lim), labels = os_axis_labels) +
    ggplot2::labs(x = OS_AXIS$nes, y = NULL) +
    theme_omicstat(journal = journal, legend = "right") +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = OS_FIG$size_axis_text, lineheight = 0.85))
  if (nrow(pos) && nrow(neg)) p <- p + os_hline(nrow(neg) + 0.5)
  # S5 R2: NES is relative enrichment toward the top / bottom of the ranking;
  # when every score has one sign the other end is still there, but an
  # enrichment at it does not by itself mean the opposite effect.
  ends <- switch(score_signs,
    both = sprintf(paste0("Positive NES: relative enrichment toward the top of the ranking (highest scores; positive scores: %s); ",
                          "negative NES: relative enrichment toward the bottom (lowest scores; negative scores: %s)."), positive_end, negative_end),
    positive = sprintf(paste0("Positive NES: relative enrichment toward the top of the ranking (largest scores; positive scores: %s); ",
                              "negative NES: relative enrichment toward the bottom (smallest scores). All scores are positive, so a negative NES ",
                              "does not by itself indicate %s."), positive_end, negative_end),
    negative = sprintf(paste0("Positive NES: relative enrichment toward the top of the ranking (scores closest to zero); negative NES: relative ",
                              "enrichment toward the bottom (most negative scores; negative scores: %s). All scores are negative, so a positive ",
                              "NES does not by itself indicate %s."), negative_end, positive_end))
  cap <- sprintf(paste0("Gene set enrichment analysis (GO %s) split by the sign of NES: up to %d sets per sign with the largest |NES| among the %d ",
                        "with BH adjusted P < %s (%d positive, top block; %d negative, bottom block; each block ordered by NES; ties by adjusted P, ",
                        "then term ID). %s Dot colour, -log10 adjusted P; dot size, gene set size."),
                 ontology, top_n_each, n_sig, alpha, nrow(pos), nrow(neg), ends)
  n_lines <- sum(vapply(strsplit(unname(labs), "\n", fixed = TRUE), length, 1L))
  os_with_meta(p, figure_type = "enrichment_dotplot_signed", default_height_mm = min(170, 24 + 4.2 * max(n_lines, nrow(d))),
               caption = cap, thresholds = list(padj = alpha), counts = list(significant = n_sig, positive = nrow(pos), negative = nrow(neg)),
               data = list(term_ids = as.list(rev(as.character(d$term_id)))))
}

# Ridge plot of the ranking scores of each set's core-enrichment genes
# (enrichplot ridgeplot grammar) for up to n_sets significant sets with the
# largest |NES|. core: named list term_id -> core-enrichment feature IDs;
# stats: the named ranking scores; metric: the ranking metric name.
os_cp_gsea_ridge <- function(tab, core, stats, alpha, n_sets, metric, journal = NULL) {
  d <- tab[!is.na(tab$padj) & tab$padj < alpha & is.finite(tab$nes), , drop = FALSE]
  if (!nrow(d)) .os_enrich_empty_stop(tab, alpha)
  # up to n_sets / 2 sets per sign (largest |NES|), so both ends are shown when both are significant
  k <- max(1L, n_sets %/% 2L)
  pos <- d[d$nes > 0, , drop = FALSE]; neg <- d[d$nes < 0, , drop = FALSE]
  pos <- utils::head(pos[order(-pos$nes, pos$padj, pos$term_id, method = "radix"), , drop = FALSE], if (nrow(neg)) k else n_sets)
  neg <- utils::head(neg[order(neg$nes, neg$padj, neg$term_id, method = "radix"), , drop = FALSE], if (nrow(pos)) k else n_sets)
  d <- rbind(pos, neg)
  d <- d[order(-d$nes, d$term_id, method = "radix"), , drop = FALSE]
  lab <- os_wrap(d$term_name)
  vals <- unlist(lapply(seq_len(nrow(d)), function(i) unname(stats[intersect(core[[d$term_id[i]]], names(stats))])))
  grp <- unlist(lapply(seq_len(nrow(d)), function(i) rep(lab[i], length(intersect(core[[d$term_id[i]]], names(stats))))))
  p <- os_ridge(vals, grp, feature = "Core-enrichment genes", group_order = lab, fill = "none",
                value_title = metric, italic = FALSE, journal = journal)
  n_core <- vapply(d$term_id, function(t) length(intersect(core[[t]], names(stats))), 0L)
  m <- attr(p, "os_meta")
  m$caption <- sprintf(paste0("Distribution of the ranking metric (%s) over the core-enrichment (leading-edge) genes of the %d significant GO sets ",
                              "with the largest |NES| per sign (BH adjusted P < %s), ordered by NES (largest at the top); core genes per set: %s. Each ridge is a ",
                              "Gaussian kernel density with one pooled bandwidth (%s); vertical line, median. Display only."),
                       metric, nrow(d), alpha, paste(n_core, collapse = ", "), format(signif(m$encodings$bandwidth, 3)))
  m$figure_type <- "gsea_ridge"
  m$thresholds <- list(padj = alpha)
  attr(p, "os_meta") <- m
  p
}

# ---- clusterprofiler-compare ----
os_cp_compare_dotplot <- function(tab, groups, top_n, ontology, journal) {
  p <- os_enrich_compare(tab, groups_order = groups, top_n_per_group = top_n,
                         padj_threshold = 0.05, database_label = paste("GO", ontology), journal = journal)
  p <- p + ggplot2::scale_x_discrete(drop = FALSE)
  cap <- attr(p, "os_meta")$caption
  n_shown <- length(unique(tab$group[!is.na(tab$padj) & tab$padj < 0.05]))
  os_with_meta(p, caption = paste0(cap, " ", length(groups), " lists share one eligible universe; ",
                                   n_shown, " have a term below the threshold. This chart does not test differences between lists."))
}
