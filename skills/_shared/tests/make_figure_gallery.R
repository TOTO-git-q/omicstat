# make_figure_gallery.R -- render every standard figure from the synthetic
# fixtures into docs/figure-gallery/ (PNG + PDF + figure_spec.json), plus two
# composite example figures. ASCII only on purpose.
# Run from any directory:  Rscript skills/_shared/tests/make_figure_gallery.R [out_dir]

args <- commandArgs(trailingOnly = TRUE)
this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
shared <- dirname(dirname(this))
repo <- dirname(dirname(shared))
out <- if (length(args)) args[1] else file.path(repo, "docs", "figure-gallery")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(shared, "scripts", "fig_all.R"))
source(file.path(shared, "tests", "fixtures", "fig_fixtures.R"))
source(file.path(shared, "tests", "fixtures", "fig_fixtures_ext.R"))

save <- function(p, name, width = "single", h = NULL) {
  r <- os_finalize_figure(p, file.path(out, name), width = width, height_mm = h, root = out)
  cat(sprintf("%-22s %s\n", name, if (nrow(r$lint)) paste(r$lint$rule, collapse = ",") else "lint clean"))
  invisible(r)
}

ft <- fx_feature_table()
ex <- fx_expression(ft)
et <- fx_enrichment()
emb <- fx_embedding()
mk <- fx_markers()
reg <- os_colour_registry_new()

v <- os_volcano(ft, contrast_label = "Treated vs control", method_label = "DESeq2 Wald test, apeglm shrinkage, Benjamini-Hochberg")
save(v, "01_volcano")
save(os_ma(ft, contrast_label = "Treated vs control"), "02_ma")
pca <- os_pca_scores(ex$mat)
pc <- os_pca_plot(pca, ex$coldata, "condition", shape_col = "batch", reference = "control")
save(pc, "03_pca")
save(os_sample_distance(ex$mat, ex$coldata, "condition", reference = "control"), "04_sample_distance")
th <- os_top_heatmap(ex$mat, ft, ex$coldata, "condition", n = 40, reference = "control")
th20 <- os_top_heatmap(ex$mat, ft, ex$coldata, "condition", n = 20, reference = "control", show_col_labels = FALSE)
save(th, "05_top_heatmap")
save(os_enrich_dotplot(et, "gene_ratio", database_label = "GO biological process"), "06_ora_dotplot")
save(os_enrich_dotplot(et, "nes", database_label = "GO biological process"), "07_gsea_dotplot")
save(os_nes_bar(et, database_label = "GO biological process"), "08_nes_bar")
rk <- fx_ranked(ft)
set <- names(sort(rk, decreasing = TRUE))[c(seq(1, 400, 4), sample.int(length(rk), 40))]
save(os_gsea_curve(rk, set, "Inflammatory response", nes = 2.41, padj = 3.2e-6), "09_gsea_curve")
et2 <- rbind(transform(et, group = "Cluster 1"), transform(et, group = "Cluster 2", padj = rev(et$padj)),
             transform(et, group = "Cluster 3", padj = pmin(1, et$padj * 50)))
save(os_enrich_compare(et2, top_n_per_group = 4), "10_enrich_compare")
e <- os_embedding(emb, "celltype", colour_registry = reg, family = "celltype")
reg <- attr(e, "os_meta")$colour_registry
save(e, "11_umap_celltype")
save(os_embedding(emb, "celltype", label = FALSE, colour_registry = reg, family = "celltype"), "12_umap_legend")
set.seed(11); vals <- ifelse(emb$celltype %in% c("CD14 Mono", "FCGR3A Mono"), rgamma(nrow(emb), 3, 1.2), rbinom(nrow(emb), 1, 0.05) * runif(nrow(emb), 0, 1.5))
save(os_feature_embedding(emb, vals, "LYZ"), "13_feature_umap")
save(os_marker_dotplot(mk$md, mk$gene_order, mk$cluster_order, mean_definition = "log_mean"), "14_marker_dotplot", width = "onehalf")
pr <- os_proportion_bar(fx_proportions(emb), colour_registry = reg)
save(pr, "15_proportion_bar")
qc <- fx_qc()
save(os_qc_violin(qc, c("nFeature", "nCount", "percent_mt"), thresholds = list(nFeature = c(200, 5000), percent_mt = 10),
                  metric_labels = c(nFeature = "Genes per cell", nCount = "UMIs per cell", percent_mt = "Mitochondrial reads (%)"),
                  log10_metrics = c("nFeature", "nCount")), "16_qc_violin")
set.seed(12); sc <- data.frame(celltype = emb$celltype, score = rnorm(nrow(emb), ifelse(emb$celltype == "NK", 0.6, 0), 0.2))
save(os_score_violin(sc, "celltype", "score", "Cytotoxicity module score", colour_registry = reg, family = "celltype"), "17_score_violin")
mt <- fx_module_trait()
save(os_module_trait(mt$r, mt$p), "18_module_trait")
save(os_soft_threshold(fx_soft_threshold(), chosen_power = 8), "19_soft_threshold", width = "onehalf")
mf <- fx_maf()
save(os_oncoplot(mf$maf, mf$samples, top_n = 12), "20_oncoplot", width = "double")

# Extension figure types (FIGURE_STYLE.md sec 18), same fixtures as test_figures_ext.R.
sc <- fxe_sc(); mk2 <- fxe_markers(sc); gs <- fxe_gene_sets(et)
z <- t(scale(t(ex$mat[order(ft$padj)[1:60], ]))); z[!is.finite(z)] <- 0
ra <- data.frame(row.names = rownames(z), direction = ifelse(ft$log2fc[match(rownames(z), ft$feature_id)] > 0, "up", "down"),
                 module = c("M1", "M2", "M3")[(seq_len(nrow(z)) %% 3) + 1], stringsAsFactors = FALSE)
ca <- data.frame(row.names = colnames(z), condition = ex$coldata$condition, batch = ex$coldata$batch)
hlabs <- stats::setNames(ft$symbol[match(rownames(z), ft$feature_id)], rownames(z))
rk2 <- fx_ranked(ft); top_g <- names(sort(rk2, decreasing = TRUE)); bot_g <- names(sort(rk2))
msets <- list("inflammatory response" = top_g[seq(1, 400, 5)], "cellular response to interleukin-1" = top_g[seq(3, 900, 9)],
              "oxidative phosphorylation" = bot_g[seq(1, 300, 4)])
save(os_with_meta(os_heatmap(z, OS_AXIS$zscore, "diverging", clip = 2, row_labels = hlabs, row_annot = ra,
                             row_split = factor(ra$direction, levels = c("up", "down")), col_split = ex$coldata$condition,
                             col_annot = ca, annot_colours = list(direction = c(up = OS_FIG$col_up, down = OS_FIG$col_down)),
                             mark_rows = rownames(z)[c(1, 3, 5, 8, 13, 21, 34, 40, 55)]), default_height_mm = 110),
     "21_heatmap_split", width = "onehalf")
save(os_stacked_violin(sc$expr, sc$emb$cluster), "22_stacked_violin", width = "onehalf")
save(os_ridge(sc$expr["LYZ", ], sc$emb$cluster, "LYZ"), "23_ridge")
save(os_highlight_embedding(sc$emb, "cluster", "C3"), "24_highlight_embedding")
save(os_alluvial(sc$emb, c("cluster", "celltype")), "25_alluvial")
save(os_cluster_tree_dotplot(mk2$md, mk2$gene_order, mean_definition = "log_mean"), "26_cluster_tree_dotplot", width = "onehalf")
save(os_density_embedding(sc$emb, sc$expr["LYZ", ], "LYZ"), "27_density_embedding")
save(os_cnet(et, gs$sets, gs$fc), "28_cnet", width = "onehalf")
save(os_emap(et, gs$sets), "29_emap", width = "onehalf")
save(os_term_tree(et, gs$sets), "30_term_tree", width = "onehalf")
save(os_gsea_multi(rk2, msets, c("inflammatory response" = 2.61, "cellular response to interleukin-1" = 1.93, "oxidative phosphorylation" = -2.2),
                   c("inflammatory response" = 3.2e-6, "cellular response to interleukin-1" = 0.0042, "oxidative phosphorylation" = 1.1e-4)),
     "31_gsea_multi")

# Composite examples: one claim per figure, 3-4 panels, journal lettering.
f1 <- os_compose(list(v, pc, th20), ncol = 3, widths = c(1.15, 1, 0.9))
save(f1, "F1_composite_bulk", width = "double", h = 75)
f2 <- os_compose(list(e, os_marker_dotplot(mk$md, mk$gene_order, mk$cluster_order, mean_definition = "log_mean"), pr), ncol = 3, widths = c(1, 1.5, 1))
save(f2, "F2_composite_singlecell", width = "double", h = 80)
writeLines(c(attr(f1, "os_meta")$caption, "", attr(f2, "os_meta")$caption), file.path(out, "composite_legends.md"))
os_colour_registry_write(reg, file.path(out, "colour_registry.json"))
specs <- sort(list.files(out, pattern = "\\.figure_spec\\.json$"))
idx <- c("# omicstat figure gallery", "",
         "Synthetic fixtures rendered with the shared figure layer (style v", OS_FIG_STYLE_VERSION,
         "). Regenerate with `Rscript skills/_shared/tests/make_figure_gallery.R`.", "")
idx <- c(paste0(idx[1]), "", paste0(idx[3], idx[4], idx[5]), "")
for (sp in specs) {
  js <- jsonlite::fromJSON(file.path(out, sp))
  stem <- sub("\\.figure_spec\\.json$", "", sp)
  idx <- c(idx, sprintf("## %s (`%s`, %s x %s mm)", stem, js$figure_type, js$width_mm, js$height_mm), "",
           sprintf("![%s](%s.png)", stem, stem), "", js$caption, "")
}
writeLines(idx, file.path(out, "README.md"), useBytes = TRUE)
if (file.exists("Rplots.pdf")) stop("device leak: Rplots.pdf created")
cat("gallery written to", out, "\n")
