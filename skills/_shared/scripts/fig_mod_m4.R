# fig_mod_m4.R -- lane-owned M4 builders; shared style tokens only.
os_m4_soft <- function(res, a) {
  p <- os_soft_threshold(res$diagnostics, a$power, r2_threshold = 0.85, journal = a$journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste(meta$caption, sprintf("n = %d biological samples, %d genes; %s network, Pearson correlation; input scale %s. Power was chosen explicitly: %s.", res$samples, res$genes, a[["network-type"]], a[["input-scale"]], a[["power-reason"]]))
  attr(p, "os_meta") <- meta
  p
}
os_m4_trait <- function(res, a) {
  p <- os_module_trait(res$r, res$p, journal = a$journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste(meta$caption, sprintf("n = %d biological samples; BH adjustment across all %d module-trait tests is retained in the full table; no display significance filter.", res$samples, nrow(res$assoc)))
  attr(p, "os_meta") <- meta
  p
}
# Convert hclust merges to segments without relying on additional packages.
os_m4_tree <- function(tree, caption, journal) {
  n <- length(tree$order); xp <- yp <- numeric(n - 1L)
  leaves <- numeric(n); leaves[tree$order] <- seq_len(n)
  seg <- list()
  for (i in seq_len(n - 1L)) {
    ch <- tree$merge[i, ]; xx <- ifelse(ch < 0, leaves[pmax(1, -ch)], xp[pmax(1, ch)])
    yy <- ifelse(ch < 0, 0, yp[pmax(1, ch)])
    xp[i] <- mean(xx); yp[i] <- tree$height[i]
    seg[[i]] <- data.frame(x = c(xx, xx[1]), xend = c(xx, xx[2]), y = c(yy, yp[i]), yend = rep(yp[i], 3))
  }
  d <- do.call(rbind, seg)
  p <- ggplot2::ggplot(d) + ggplot2::geom_segment(ggplot2::aes(x = x, xend = xend, y = y, yend = yend), colour = OS_FIG$col_ink, linewidth = os_lw(OS_FIG$lw_segment)) +
    ggplot2::labs(x = "Ordered leaves", y = "Height") + theme_omicstat(journal = journal) + ggplot2::theme(plot.margin = ggplot2::margin(4, 4, 4, 8, unit = "mm"))
  os_with_meta(p, figure_type = "dendrogram", caption = caption, counts = list(leaves = n))
}
os_m4_gene_tree <- function(tree, modules, caption, journal) {
  p <- os_m4_tree(tree, caption, journal)
  d <- data.frame(x = seq_along(tree$order), y = 0, module = modules[tree$order])
  cols <- os_colours_for(d$module, family = "category")
  meta <- attr(p, "os_meta")
  p <- p + ggplot2::geom_point(data = d, ggplot2::aes(x = x, y = y, colour = module), shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm) +
    ggplot2::scale_colour_manual(values = cols$colours, guide = "none")
  attr(p, "os_meta") <- meta
  p
}
os_m4_maf_plot <- function(maf, a) {
  d <- as.data.frame(maf@data)
  p <- os_oncoplot(data.frame(sample = d$Tumor_Sample_Barcode, gene = d$Hugo_Symbol, variant_class = d$Variant_Classification), all_samples = as.character(maftools::getSampleSummary(x = maf)$Tumor_Sample_Barcode), top_n = a$top, journal = a$journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste(meta$caption, "No biological significance filter; n denotes observed tumor samples, not clinical-only rows. Native MAF filters and full native result tables are retained.")
  attr(p, "os_meta") <- meta
  p
}
os_m4_variant_summary <- function(maf, a) {
  d <- as.data.frame(maf@data)
  cls <- as.data.frame(table(d$Variant_Classification)); names(cls) <- c("classification", "variants")
  pal <- OS_PAL_MUTATION
  missing <- setdiff(as.character(cls$classification), names(pal))
  pal <- c(pal, stats::setNames(rep(OS_FIG$col_na, length(missing)), missing))
  p <- ggplot2::ggplot(cls, ggplot2::aes(x = reorder(classification, variants), y = variants, fill = classification)) +
    ggplot2::geom_col(width = 0.7) + ggplot2::coord_flip() + ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::labs(x = "Variant classification", y = "Non-silent variants") + theme_omicstat(journal = a$journal)
  os_with_meta(p, figure_type = "variant_summary", caption = sprintf("Native non-silent variant-class summary: n = %d observed tumors, %d variants; %d silent variants retained separately. No significance cutoff. Filters are the recorded read.maf options.", nrow(maftools::getSampleSummary(x = maf)), nrow(d), nrow(maf@maf.silent)))
}
os_m4_tmb <- function(tab, a) {
 p <- ggplot2::ggplot(tab, ggplot2::aes(x = total_perMB)) + ggplot2::geom_histogram(bins = 25, fill = OS_FIG$col_ink) + ggplot2::labs(x = "Mutations per Mb", y = "Tumor samples") + theme_omicstat(journal = a$journal)
 os_with_meta(p, figure_type = "tmb", caption = sprintf("TMB distribution: n = %d tumors with nonzero eligible mutations; capture territory %g Mb; native ignoreCNV=%s. No high/low threshold; zero-mutation samples omitted by native tmb.", nrow(tab), a[["capture-size"]], a[["ignore-cnv"]]))
}
os_m4_interactions <- function(tab, a, n_samples) {
 mat <- matrix(NA_real_, length(unique(c(tab$gene1, tab$gene2))), length(unique(c(tab$gene1, tab$gene2))))
 ids <- sort(unique(c(tab$gene1, tab$gene2))); dimnames(mat) <- list(ids, ids)
 for (i in seq_len(nrow(tab))) mat[tab$gene1[i], tab$gene2[i]] <- mat[tab$gene2[i], tab$gene1[i]] <- sign(log2(tab$oddsRatio[i])) * -log10(tab$pAdj[i])
 p <- os_heatmap(mat, value_title = "Signed -log10\nBH P", scale_type = "diverging", cluster_rows = FALSE, cluster_cols = FALSE, journal = a$journal)
 m <- attr(p, "os_meta"); m$caption <- paste(m$caption, sprintf("n = %d gene pairs; all tested pairs shown without significance filtering; positive = co-occurrence, negative = mutual exclusion. BH adjusted Fisher tests; %d observed tumors.", nrow(tab), n_samples)); attr(p,"os_meta") <- m; p
}
os_m4_infiltration <- function(tab, a) {
 mat <- as.matrix(tab[-1]); rownames(mat) <- tab$cell_type
 unit <- id_method_unit(a$method)
 score <- unit %in% c("native_score", "scores_and_tumor_purity")
 if (score) {
  mat <- t(scale(t(mat))); mat[!is.finite(mat)] <- 0
 }
 title <- if(score) "Within-row z-score" else if(unit=="estimated_percent") "Estimated percent" else "Cell fraction"
 p <- os_heatmap(mat, value_title=title, scale_type=if(score || any(mat<0)) "diverging" else "sequential", cluster_rows=FALSE, cluster_cols=FALSE, journal=a$journal)
 m <- attr(p,"os_meta"); m$caption <- paste(m$caption,sprintf("%s native %s; n = %d biological samples, %d result rows; input %s; tumor=%s, arrays=%s, scale_mrna=%s. %s No significance threshold or group test.",a$method,unit,ncol(mat),nrow(mat),a[["input-scale"]],a$tumor,a$arrays,a[["scale-mrna"]],if(score) "Rows standardized for display only; colours compare samples within each row, not magnitudes across cell types. Native table retains scores and purity separately." else "Native estimates retained; negative ABIS estimates are not clipped.")); attr(p,"os_meta") <- m; p
}
