# fig_network.R -- WGCNA and mutation-landscape figures: module-trait
# heatmap, soft-threshold diagnostics, oncoplot.
# ASCII only on purpose. Requires fig_style.R, fig_heatmap.R, fig_bulk.R.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_network.R.", call. = FALSE)

# Module-trait correlation heatmap (WGCNA tutorial layout): rows modules,
# columns traits, fill = Pearson r on [-1, 1] (diverging), each cell shows
# r and, in parentheses, the P value. Rows and columns keep the caller's
# order (modules are conventionally ordered by the eigengene dendrogram).
os_module_trait <- function(r, pval, journal = NULL) {
  if (!identical(dim(r), dim(pval))) stop("OS_INVALID_INPUT: r and pval must have the same dimensions.", call. = FALSE)
  txt <- matrix(paste0(formatC(r, format = "f", digits = 2), "\n(",
                       ifelse(pval < 0.001, formatC(pval, format = "e", digits = 0), formatC(pval, format = "f", digits = 3)), ")"),
                nrow(r), dimnames = dimnames(r))
  txt <- gsub("-", OS_MINUS, txt, fixed = TRUE)
  txt <- gsub("e\u2212", "e-", txt, fixed = TRUE)   # keep the exponent readable: 3e-04
  p <- os_heatmap(r, value_title = OS_AXIS$correlation, scale_type = "diverging", limits = c(-1, 1),
                  cluster_rows = FALSE, cluster_cols = FALSE, italic_rows = FALSE, cell_text = txt, journal = journal)
  meta <- attr(p, "os_meta")
  os_with_meta(p, figure_type = "module_trait", default_height_mm = min(170, 25 + 7 * nrow(r)),
               caption = sprintf(paste0("Correlation between module eigengenes (%d modules, rows) and traits (%d, columns). ",
                                        "Each cell gives the Pearson correlation coefficient and, in parentheses, its unadjusted P value; ",
                                        "colour encodes r from %s1 (blue) to 1 (red)."), nrow(r), ncol(r), OS_MINUS))
}

# Soft-threshold power diagnostics: scale-free fit (signed R^2) and mean
# connectivity against power; the chosen power is highlighted.
os_soft_threshold <- function(sft, chosen_power, r2_threshold = 0.85, journal = NULL) {
  for (cc in c("power", "signed_r2", "mean_k")) if (!cc %in% names(sft)) stop(sprintf("OS_MISSING_COLUMNS: os_soft_threshold needs '%s'.", cc), call. = FALSE)
  hi <- which(sft$power == chosen_power)
  a <- os_diag_xy(sft, "power", "signed_r2", kind = "line+points", xlab = "Soft-threshold power",
                  ylab = quote("Scale-free topology fit (signed "*italic(R)^2*")"), hlines = r2_threshold,
                  highlight = hi, figure_type = "soft_threshold", journal = journal)
  b <- os_diag_xy(sft, "power", "mean_k", kind = "line+points", xlab = "Soft-threshold power",
                  ylab = "Mean connectivity", highlight = hi, figure_type = "soft_threshold", journal = journal)
  p <- patchwork::wrap_plots(a, b, ncol = 2)
  os_with_meta(p, figure_type = "soft_threshold", default_height_mm = 50,
               caption = sprintf(paste0("Choice of the soft-thresholding power. Left, scale-free topology fit index (signed R2) ",
                                        "against power; dashed line, R2 = %s. Right, mean connectivity. The chosen power (%s) is highlighted in red."),
                                 r2_threshold, chosen_power),
               thresholds = list(signed_r2 = r2_threshold), data = list(chosen_power = chosen_power))
}

# Oncoplot. maf: data.frame(sample, gene, variant_class). all_samples:
# every sample in the cohort (samples without mutations in the shown genes
# still get a column). Genes ordered by frequency (ties: gene name);
# samples ordered by the mutation-pattern "waterfall" sort. Multiple
# variants of one gene in one sample -> "Multi_Hit" (maftools convention).
os_oncoplot <- function(maf, all_samples = NULL, top_n = 20, journal = NULL) {
  for (cc in c("sample", "gene", "variant_class")) if (!cc %in% names(maf)) stop(sprintf("OS_MISSING_COLUMNS: os_oncoplot needs '%s'.", cc), call. = FALSE)
  samples <- sort(unique(c(all_samples %||% character(0), as.character(maf$sample))), method = "radix")
  ns <- length(samples)
  key <- paste(maf$sample, maf$gene, sep = "\r")
  cls <- tapply(as.character(maf$variant_class), key, function(v) if (length(unique(v)) > 1 || length(v) > 1) "Multi_Hit" else v[1])
  cell <- data.frame(sample = sub("\r.*$", "", names(cls)), gene = sub("^.*\r", "", names(cls)), cls = unname(cls))
  freq <- table(cell$gene)
  genes <- names(freq)[order(-as.integer(freq), names(freq), method = "radix")]
  genes <- utils::head(genes, top_n)
  cell <- cell[cell$gene %in% genes, , drop = FALSE]
  # waterfall: sort samples by binary mutation vectors over genes in order
  bin <- sapply(genes, function(g) as.integer(samples %in% cell$sample[cell$gene == g]))
  if (is.null(dim(bin))) bin <- matrix(bin, nrow = ns)
  ord_args <- c(lapply(seq_len(ncol(bin)), function(j) -bin[, j]), list(samples, method = "radix"))
  s_ord <- samples[do.call(order, ord_args)]
  bg <- expand.grid(sample = s_ord, gene = genes, stringsAsFactors = FALSE)
  cell$.x <- match(cell$sample, s_ord); cell$.y <- match(cell$gene, rev(genes))
  bg$.x <- match(bg$sample, s_ord); bg$.y <- match(bg$gene, rev(genes))
  classes <- intersect(names(OS_PAL_MUTATION), unique(cell$cls))
  other <- setdiff(unique(cell$cls), names(OS_PAL_MUTATION))
  pal <- c(OS_PAL_MUTATION[classes], stats::setNames(rep(OS_FIG$col_na, length(other)), other))
  pct <- 100 * as.integer(freq[genes]) / ns
  gap <- if (ns > 100) 0 else 0.1
  body <- ggplot2::ggplot() +
    ggplot2::geom_tile(data = bg, ggplot2::aes(x = .x, y = .y), fill = "#EFEFEF", width = 1 - gap, height = 0.9) +
    ggplot2::geom_tile(data = cell, ggplot2::aes(x = .x, y = .y, fill = cls), width = 1 - gap, height = 0.9) +
    ggplot2::scale_fill_manual(values = pal, breaks = names(pal), labels = gsub("_", " ", names(pal)),
                               guide = ggplot2::guide_legend(title = "Variant class", title.position = "top", nrow = 2)) +
    ggplot2::scale_x_continuous(expand = c(0, 0), limits = c(0.5, ns + 0.5)) +
    ggplot2::scale_y_continuous(breaks = seq_along(genes), labels = rev(genes), expand = c(0, 0),
                                sec.axis = ggplot2::dup_axis(labels = paste0(round(rev(pct)), "%"))) +
    theme_omicstat(journal = journal, axes = "none", legend = "bottom") +
    ggplot2::theme(axis.text.y.left = ggplot2::element_text(face = "italic", size = OS_FIG$size_axis_text, hjust = 1),
                   axis.text.y.right = ggplot2::element_text(size = OS_FIG$size_axis_text, hjust = 0),
                   legend.justification = "left", plot.margin = ggplot2::margin(0, 2, 2, 2, unit = "mm"))
  tmb <- as.data.frame(table(factor(maf$sample, levels = s_ord), maf$variant_class))
  names(tmb) <- c("sample", "cls", "n"); tmb <- tmb[tmb$n > 0, ]
  tmb$.x <- match(tmb$sample, s_ord)
  tmb$cls <- ifelse(tmb$cls %in% names(pal), as.character(tmb$cls), other[1] %||% "Other")
  top <- ggplot2::ggplot(tmb, ggplot2::aes(x = .x, y = n, fill = cls)) +
    ggplot2::geom_col(width = 1 - gap) +
    ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::scale_x_continuous(expand = c(0, 0), limits = c(0.5, ns + 0.5)) +
    ggplot2::scale_y_continuous(expand = c(0, 0), breaks = scales::breaks_pretty(n = 3), labels = os_axis_labels) +
    ggplot2::labs(x = NULL, y = "Variants") +
    theme_omicstat(journal = journal) +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank(),
                   axis.line.x = ggplot2::element_blank(), plot.margin = ggplot2::margin(2, 2, 0.5, 2, unit = "mm"))
  p <- patchwork::wrap_plots(top, body, ncol = 1, heights = c(1, max(3, length(genes) * 0.35)))
  os_with_meta(p, figure_type = "oncoplot", default_height_mm = min(170, 35 + 3.2 * length(genes)),
               caption = sprintf(paste0("Somatic variant landscape of the %d most frequently mutated genes across %d samples. ",
                                        "Each column is a sample (sorted by mutation pattern) and each row a gene; percentages give the fraction of samples mutated. ",
                                        "Top, number of variants per sample. Multi hit, more than one variant in the gene."),
                                 length(genes), ns),
               encodings = list(fill = as.list(pal)), data = list(genes = as.list(genes), sample_order = as.list(s_ord)))
}
