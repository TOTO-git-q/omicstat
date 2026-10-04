# test_figures_ext.R -- tests for the extended figure types (FIGURE_STYLE.md
# sec 18): heatmap row annotations / splits / mark_rows / clipped colour bar,
# os_heatmap_check_rows, fig_sc_extra.R and fig_enrich_network.R.
# ASCII only. Run with: Rscript test_figures_ext.R   (any working directory)
# Same protocol as test_figures.R: PASS/FAIL lines, exit status 1 on failure.
#
#   E1 determinism   -- every new figure rendered twice: PNG/SVG byte-identical,
#                       PDF content hash identical, figure_spec identical
#   E2 lint          -- no blocker/warning lint finding under the nature AND
#                       cell presets (FIG-03 grayscale "info" notes are allowed:
#                       the Okabe-Ito set is chosen for colour-vision safety,
#                       not grayscale printing; FIGURE_STYLE sec 17)
#   E3 encodings     -- ggplot_build / meta assertions of the key encodings
#   E4 typed errors  -- OS_FIG_ROW_MISMATCH and the input guards
#   E5 compatibility -- os_heatmap without the new arguments behaves as before
#   E6 hygiene       -- ASCII sources, no RNG side effects, specs clean

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
shared <- normalizePath(file.path(here, ".."))
source(file.path(shared, "scripts", "fig_all.R"))
source(file.path(here, "fixtures", "fig_fixtures.R"))
source(file.path(here, "fixtures", "fig_fixtures_ext.R"))

outdir <- file.path(tempdir(), "omicstat_fig_test_ext")
unlink(outdir, recursive = TRUE); dir.create(outdir, recursive = TRUE)
old_wd <- setwd(tempdir())

failures <- character(0)
check <- function(cond, msg) {
  if (isTRUE(cond)) cat(sprintf("PASS: %s\n", msg))
  else { cat(sprintf("FAIL: %s\n", msg)); failures <<- c(failures, msg) }
}
expect_error_code <- function(expr, code, msg) {
  e <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  check(!is.null(e) && grepl(code, e, fixed = TRUE), sprintf("%s -> %s", msg, code))
}
sha <- function(f) digest::digest(file = f, algo = "sha256")
# every ggplot inside a (possibly nested) patchwork
all_plots <- function(p) {
  if (!inherits(p, "patchwork")) return(list(p))
  out <- list()
  for (q in p$patches$plots) out <- c(out, all_plots(q))
  last <- p; class(last) <- setdiff(class(last), "patchwork"); last$patches <- NULL
  c(out, list(last))
}
has_geom <- function(p, g) any(vapply(p$layers, function(l) inherits(l$geom, g), logical(1)))

# ------------------------------------------------------------- fixtures ----
ft <- fx_feature_table(); ex <- fx_expression(ft); et <- fx_enrichment()   # legacy fixtures seed globally
rng_before <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
sc <- fxe_sc(); mk <- fxe_markers(sc); gs <- fxe_gene_sets(et)
z <- t(scale(t(ex$mat[order(ft$padj)[1:60], ])))
z[!is.finite(z)] <- 0
ra <- data.frame(row.names = rownames(z),
                 direction = ifelse(ft$log2fc[match(rownames(z), ft$feature_id)] > 0, "up", "down"),
                 module = c("M1", "M2", "M3")[(seq_len(nrow(z)) %% 3) + 1], stringsAsFactors = FALSE)
ca <- data.frame(row.names = colnames(z), condition = ex$coldata$condition, batch = ex$coldata$batch)
labs <- stats::setNames(ft$symbol[match(rownames(z), ft$feature_id)], rownames(z))
marks <- rownames(z)[c(1, 3, 5, 8, 13, 21, 34, 40, 55)]
rk <- fx_ranked(ft)
top_g <- names(sort(rk, decreasing = TRUE)); bot_g <- names(sort(rk))
msets <- list("inflammatory response" = top_g[seq(1, 400, 5)], "cellular response to interleukin-1" = top_g[seq(3, 900, 9)],
              "oxidative phosphorylation" = bot_g[seq(1, 300, 4)])
mnes <- c("inflammatory response" = 2.61, "cellular response to interleukin-1" = 1.93, "oxidative phosphorylation" = -2.2)
mpadj <- c("inflammatory response" = 3.2e-6, "cellular response to interleukin-1" = 0.0042, "oxidative phosphorylation" = 1.1e-4)

builders <- function(journal = NULL) list(
  heatmap_split = function() os_with_meta(
    os_heatmap(z, OS_AXIS$zscore, "diverging", clip = 2, row_labels = labs, row_annot = ra,
               row_split = factor(ra$direction, levels = c("up", "down")), col_split = ex$coldata$condition,
               col_annot = ca, annot_colours = list(direction = c(up = OS_FIG$col_up, down = OS_FIG$col_down)),
               mark_rows = marks, journal = journal), default_height_mm = 110),
  stacked_violin = function() os_stacked_violin(sc$expr, sc$emb$cluster, journal = journal),
  ridge = function() os_ridge(sc$expr["LYZ", ], sc$emb$cluster, "LYZ", journal = journal),
  highlight_embedding = function() os_highlight_embedding(sc$emb, "cluster", "C3", journal = journal),
  alluvial = function() os_alluvial(sc$emb, c("cluster", "celltype"), journal = journal),
  cluster_tree_dotplot = function() os_cluster_tree_dotplot(mk$md, mk$gene_order, mean_definition = "log_mean", journal = journal),
  density_embedding = function() os_density_embedding(sc$emb, sc$expr["LYZ", ], "LYZ", journal = journal),
  cnet = function() os_cnet(et, gs$sets, gs$fc, journal = journal),
  emap = function() os_emap(et, gs$sets, journal = journal),
  term_tree = function() os_term_tree(et, gs$sets, journal = journal),
  gsea_multi = function() os_gsea_multi(rk, msets, mnes, mpadj, journal = journal)
)
widths <- c(heatmap_split = "onehalf", stacked_violin = "onehalf", alluvial = "single", cluster_tree_dotplot = "onehalf",
            cnet = "onehalf", emap = "onehalf", term_tree = "onehalf")
B <- builders()
figs <- lapply(B, function(f) f())
rng_after <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
check(identical(rng_before, rng_after), "E6 fixtures and figure builders leave the global RNG state untouched")

# ------------------------------------------------------ E1 determinism ----
for (nm in names(B)) {
  w <- if (nm %in% names(widths)) widths[[nm]] else "single"
  r1 <- os_save_figure(B[[nm]](), file.path(outdir, "run1", nm), width = w, formats = c("pdf", "png", "svg"),
                       root = file.path(outdir, "run1"))
  r2 <- os_save_figure(B[[nm]](), file.path(outdir, "run2", nm), width = w, formats = c("pdf", "png", "svg"),
                       root = file.path(outdir, "run2"))
  for (ext in c("png", "svg")) {
    check(identical(sha(r1$files[[ext]]), sha(r2$files[[ext]])), sprintf("E1 %s.%s byte-identical across reruns", nm, ext))
  }
  check(identical(os_pdf_content_sha256(r1$files$pdf), os_pdf_content_sha256(r2$files$pdf)),
        sprintf("E1 %s.pdf content-identical across reruns (timestamp exempt)", nm))
  check(identical(sha(r1$spec), sha(r2$spec)), sprintf("E1 %s figure_spec.json byte-identical", nm))
  check(nzchar(r1$spec_obj$caption) && !is.null(r1$spec_obj$figure_type) && r1$spec_obj$figure_type != "unknown",
        sprintf("E1 %s figure_spec carries figure_type and an auto caption", nm))
}

# --------------------------------------------------------------- E2 lint ----
for (j in c("nature", "cell")) {
  BJ <- builders(j)
  for (nm in names(BJ)) {
    lt <- os_fig_lint(BJ[[nm]](), journal = j)
    lt <- lt[lt$severity != "info", , drop = FALSE]
    check(nrow(lt) == 0, sprintf("E2 %s lint-clean under the %s preset%s", nm, j,
                                 if (nrow(lt)) paste0(" (", paste(lt$rule, lt$message, collapse = "; "), ")") else ""))
  }
}
fin <- os_finalize_figure(B$alluvial(), file.path(outdir, "fin", "alluvial"), formats = "png")
check(!any(fin$lint$severity != "info") && file.exists(file.path(outdir, "fin", "alluvial.png")), "E2 os_finalize_figure saves an extension figure")

# ---------------------------------------------------------- E3 heatmap ----
hs <- figs$heatmap_split; hm <- attr(hs, "os_meta")
check(identical(unlist(hm$data$row_slices), c(up = sum(ra$direction == "up"), down = sum(ra$direction == "down"))),
      "E3 heatmap row slices in factor-level order with the right sizes")
ro <- unlist(hm$data$row_order)
check(all(ra[ro, "direction"] == rep(c("up", "down"), unlist(hm$data$row_slices))), "E3 heatmap rows are contiguous within their slice")
up_ids <- rownames(ra)[ra$direction == "up"]
hc_up <- stats::hclust(stats::dist(z[up_ids, ]), "complete")
check(identical(ro[seq_along(up_ids)], up_ids[hc_up$order]), "E3 heatmap clusters rows WITHIN a slice (euclidean/complete)")
check(identical(hm$data$clustering$rows, "euclidean/complete within slices"), "E3 heatmap spec records within-slice clustering")
co <- unlist(hm$data$col_order)
check(all(ex$coldata$condition[match(co, ex$coldata$sample)] == rep(c("control", "treated"), each = 4)),
      "E3 heatmap column slices keep their columns together")
check(setequal(unlist(hm$data$marked_rows), marks) && identical(unlist(hm$data$marked_rows), ro[ro %in% marks]),
      "E3 mark_rows recorded in display order")
hp <- all_plots(hs)
body <- Filter(function(p) has_geom(p, "GeomTile") && "fill" %in% names(p$mapping) &&
                 inherits(p$scales$get_scales("fill"), "ScaleContinuous"), hp)[[1]]
fs <- body$scales$get_scales("fill")
check(identical(fs$get_labels(c(-2, 0, 2)), c("\u2264\u22122", "0", "\u22652")), "E3 clipped colour bar ends read <= -2 and >= 2")
check(identical(grid::unitType(body$theme$panel.spacing), "mm") && isTRUE(all.equal(as.numeric(body$theme$panel.spacing), OS_FIG_EXT$split_gap_mm)),
      "E3 slices separated by the 1 mm gap")
mk_plot <- Filter(function(p) any(vapply(p$layers, function(l) inherits(l$geom, "GeomTextRepel"), logical(1))), hp)[[1]]
mb <- ggplot2::ggplot_build(mk_plot)
mlab <- unlist(lapply(mb$data, function(d) if ("label" %in% names(d)) as.character(d$label)))
check(setequal(mlab, unname(labs[marks])), "E3 mark_rows labels are exactly the marked rows' display labels")
# the aes mapping, not p$labels: ggplot2 >= 4.0 fills labels only at build time
map_x <- function(p) if (is.null(p$mapping$x)) NA_character_ else rlang::as_label(p$mapping$x)
ra_plots <- Filter(function(p) has_geom(p, "GeomTile") && identical(map_x(p), "x"), hp)
check(length(ra_plots) == 2, "E3 two row-annotation tracks drawn")
dir_fill <- unique(ggplot2::ggplot_build(ra_plots[[1]])$data[[1]]$fill)
check(setequal(dir_fill, c(OS_FIG$col_up, OS_FIG$col_down)), "E3 row-annotation colours from annot_colours")
mod_cols <- os_colours_for(c("M1", "M2", "M3"), family = "module")$colours
check(identical(unlist(hm$encodings$row_annotation$module), mod_cols), "E3 row-annotation colours fall back to the colour registry")
# dendrogram orientation: the outlier row joins last, at the full tree height
m5 <- matrix(c(0, 0, 0, 0.1, 0, 0, 5, 5, 5, 0.2, 0.1, 0, 0.05, 0.05, 0.05), 5, 3, byrow = TRUE,
             dimnames = list(c("a", "b", "OUT", "c", "d"), c("x", "y", "z")))
ho <- os_heatmap(m5, "v", "sequential")
hro <- unlist(attr(ho, "os_meta")$data$row_order)
y_out <- 5 + 1 - match("OUT", hro)
dp <- Filter(function(p) has_geom(p, "GeomSegment"), all_plots(ho))
dl <- Filter(function(p) any(grepl("-h", deparse(p$layers[[2]]$mapping$x), fixed = TRUE)), dp)[[1]]
dd <- ggplot2::ggplot_build(dl)$data[[2]]
leaf <- dd[abs(dd$x) < 1e-12 & abs(dd$y - y_out) < 1e-9, ]
hc5 <- stats::hclust(stats::dist(m5), "complete")
check(nrow(leaf) == 1 && isTRUE(all.equal(leaf$xend, -max(hc5$height))),
      "E3 row dendrogram leaves line up with the heatmap rows (outlier row joins at the root)")

# os_heatmap_check_rows
m1 <- matrix(1:6, 3, dimnames = list(c("a", "b", "c"), c("u", "v")))
check(identical(os_heatmap_check_rows(list(m1, m1 * 2)), c("a", "b", "c")), "E3 os_heatmap_check_rows accepts identical row order")

# -------------------------------------------------------- E3 single cell ----
sv <- figs$stacked_violin; svb <- ggplot2::ggplot_build(sv)
check(length(unique(svb$layout$layout$PANEL)) == length(sc$genes), "E3 stacked violin: one row (panel) per gene")
check(identical(sv$layers[[1]]$stat_params$scale, "width"), "E3 stacked violin: violins scaled to equal width")
check(identical(levels(svb$plot$data$.gene), sc$genes), "E3 stacked violin: genes in caller order, top to bottom")
med_lyz <- stats::median(sc$expr["LYZ", sc$emb$cluster == "C4"])
check(isTRUE(all.equal(attr(sv, "os_meta")$data$medians$LYZ$C4, round(med_lyz, 6))), "E3 stacked violin: fill encodes the median")
svg_ <- os_stacked_violin(sc$expr, sc$emb$cluster, fill = "group")
check(identical(unlist(attr(svg_, "os_meta")$encodings$fill), os_colours_for(sort(unique(sc$emb$cluster)), "cluster")$colours),
      "E3 stacked violin fill = 'group' uses registry colours")

rd <- figs$ridge; rdm <- attr(rd, "os_meta")
check(isTRUE(all.equal(rdm$encodings$bandwidth, signif(stats::bw.nrd0(sc$expr["LYZ", ]), 8))), "E3 ridge: one pooled bw.nrd0 bandwidth")
rdb <- ggplot2::ggplot_build(rd)
rib <- do.call(rbind, lapply(rdb$data, function(d) if (all(c("ymin", "ymax") %in% names(d))) d[, c("ymin", "ymax", "fill")]))
check(isTRUE(all.equal(max(rib$ymax - rib$ymin), OS_FIG_EXT$ridge_height)), "E3 ridge: tallest ridge is ridge_height rows high")
check(setequal(unique(rib$fill), os_colours_for(sort(unique(sc$emb$cluster)), "cluster")$colours), "E3 ridge: ridges filled with registry colours")
check(identical(unlist(rdm$data$groups)[1], "C1") && max(rib$ymin[rib$fill == os_colours_for("C1", "cluster")$colours]) == 5,
      "E3 ridge: first group drawn at the top")

he <- figs$highlight_embedding; heb <- ggplot2::ggplot_build(he)
check(all(heb$data[[1]]$colour == OS_FIG$col_ns) && nrow(heb$data[[1]]) == sum(sc$emb$cluster != "C3"),
      "E3 highlight: other cells grey and drawn first (below)")
check(all(heb$data[[2]]$colour == os_colours_for(sort(unique(sc$emb$cluster)), "cluster")$colours[["C3"]]) &&
        nrow(heb$data[[2]]) == sum(sc$emb$cluster == "C3"), "E3 highlight: target cells in their registry colour, on top")

al <- figs$alluvial; alm <- attr(al, "os_meta")
check(sum(unlist(alm$counts$strata[["1"]])) == nrow(sc$emb) && sum(unlist(alm$counts$strata[["2"]])) == nrow(sc$emb),
      "E3 alluvial: strata of each axis sum to the number of cells")
flow_n <- vapply(alm$data$flows, function(f) f$n, numeric(1))
check(sum(flow_n) == nrow(sc$emb), "E3 alluvial: flow widths sum to the number of cells")
tab <- table(sc$emb$cluster, sc$emb$celltype)
fl <- alm$data$flows[[1]]
check(fl$n == tab[fl$from, fl$to] && fl$n == max(tab), "E3 alluvial: largest flow first and equal to the cross-tabulation")
check(identical(unlist(alm$encodings$fill), os_colours_for(sort(unique(sc$emb$cluster)), "cluster")$colours),
      "E3 alluvial: flows coloured by the first-axis registry colours")
bc <- tapply(match(sc$emb$cluster, sort(unique(sc$emb$cluster))), sc$emb$celltype, mean)
check(identical(unlist(alm$data$strata_order$celltype), names(sort(bc))), "E3 alluvial: second axis in barycentre order")
al3 <- os_alluvial(transform(sc$emb, celltype = factor(celltype, levels = c("T cell", "NK cell", "B cell", "Monocyte"))),
                   c("cluster", "celltype"))
check(identical(unlist(attr(al3, "os_meta")$data$strata_order$celltype), c("T cell", "NK cell", "B cell", "Monocyte")),
      "E3 alluvial: factor levels fix the stratum order")
na_df <- sc$emb; na_df$celltype[1:5] <- NA
check(utils::tail(unlist(attr(os_alluvial(na_df, c("cluster", "celltype")), "os_meta")$data$strata_order$celltype), 1) == "Unassigned",
      "E3 alluvial: missing annotations become Unassigned (last)")

ct <- figs$cluster_tree_dotplot; ctm <- attr(ct, "os_meta")
prof <- stats::xtabs(avg_exp ~ cluster + gene, data = mk$md)
prof <- matrix(prof, nrow(prof), dimnames = dimnames(prof))[, unique(mk$md$gene)]
hct <- stats::hclust(stats::dist(prof), "complete")
check(identical(unlist(ctm$data$cluster_order), rownames(prof)[hct$order]), "E3 cluster tree: clusters follow the hclust leaf order")
check(identical(unlist(ctm$data$clusters), unlist(ctm$data$cluster_order)), "E3 cluster tree: dot plot rows use the tree order")
check(grepl("Markers describe clusters", ctm$caption, fixed = TRUE), "E3 cluster tree: marker dot plot caption carried over")

g0 <- os_kde2d_weighted(sc$emb$x, sc$emb$y, NULL, n = 25)
k0 <- MASS::kde2d(sc$emb$x, sc$emb$y, n = 25)
check(isTRUE(all.equal(g0$z, k0$z)), "E3 density: unweighted grid equals MASS::kde2d")
w <- sc$expr["LYZ", ]
gw <- os_kde2d_weighted(sc$emb$x, sc$emb$y, w, n = 25)
h4 <- c(MASS::bandwidth.nrd(sc$emb$x), MASS::bandwidth.nrd(sc$emb$y)) / 4
manual <- sum(w * stats::dnorm((gw$x[7] - sc$emb$x) / h4[1]) * stats::dnorm((gw$y[9] - sc$emb$y) / h4[2])) / (sum(w) * h4[1] * h4[2])
check(isTRUE(all.equal(gw$z[7, 9], manual)), "E3 density: weighted kernel sum matches the documented formula")
dnb <- ggplot2::ggplot_build(figs$density_embedding)
check(isTRUE(all.equal(range(dnb$plot$data$.v), c(min(dnb$plot$data$.v), 1))) && !is.unsorted(dnb$plot$data$.v),
      "E3 density: relative density (max 1), cells drawn in ascending density")

# --------------------------------------------------------- E3 enrichment ----
cn <- figs$cnet; cnm <- attr(cn, "os_meta")
cnb <- ggplot2::ggplot_build(cn)
genes_df <- cnb$data[[2]]
r <- sqrt(genes_df$x^2 + genes_df$y^2)
check(isTRUE(all.equal(min(r), max(r))), "E3 cnet: genes on one outer ring")
ang <- sort(atan2(genes_df$y, genes_df$x) %% (2 * pi))
gaps <- diff(c(ang, ang[1] + 2 * pi))
check(isTRUE(all.equal(min(gaps), 2 * pi / nrow(genes_df))), "E3 cnet: genes evenly spaced (no overlaps)")
set_df <- cnb$data[[3]]
check(isTRUE(all.equal(sqrt(set_df$x^2 + set_df$y^2), rep(1, nrow(set_df)))) && set_df$y[1] == max(set_df$y),
      "E3 cnet: sets on the inner circle, first set at 12 o'clock")
fsc <- cn$scales$get_scales("fill")
check(isTRUE(all.equal(fsc$limits, c(-os_sym_limit(gs$fc[unique(unlist(gs$sets[unlist(cnm$data$term_ids)]))], 1),
                                     os_sym_limit(gs$fc[unique(unlist(gs$sets[unlist(cnm$data$term_ids)]))], 1)))),
      "E3 cnet: log2 fold change colour scale symmetric")
check(cnm$counts$sets == 5 && identical(unlist(cnm$data$term_ids), et$term_id[order(et$padj, et$term_id)][1:5]),
      "E3 cnet: top 5 sets by adjusted P")

em <- figs$emap; emm <- attr(em, "os_meta")
sel <- unlist(emm$data$term_ids)
J <- os_jaccard(lapply(gs$sets[sel], function(g) sort(unique(g))))
check(isSymmetric(J) && all(diag(J) == 1), "E3 emap: Jaccard matrix symmetric with unit diagonal")
check(emm$counts$edges == sum(J[upper.tri(J)] >= 0.2), "E3 emap: edges = pairs with Jaccard >= cutoff")
xy <- do.call(rbind, lapply(emm$data$coordinates, function(c) c(c$x, c$y)))
dmin <- min(stats::dist(xy))
check(dmin >= OS_FIG_EXT$emap_min_dist * 0.9, sprintf("E3 emap: nodes do not overlap (min distance %.3f)", dmin))
ms <- os_mds_signed(stats::as.dist(1 - J))
check(all(apply(ms, 2, function(v) v[which.max(abs(round(v, 10)))] > 0)), "E3 emap: MDS layout sign-normalised (largest |coordinate| positive)")
check(isTRUE(all.equal(abs(ms), abs(stats::cmdscale(stats::as.dist(1 - J), k = 2)))), "E3 emap: layout is classical MDS of 1 - Jaccard")
em_rev <- os_emap(et[rev(seq_len(nrow(et))), ], gs$sets)
check(identical(attr(em_rev, "os_meta")$data$coordinates, emm$data$coordinates), "E3 emap: layout independent of input row order")

tt <- figs$term_tree; ttm <- attr(tt, "os_meta")
check(length(ttm$counts) == 4 && identical(unname(unlist(ttm$encodings$colour)), OS_PAL_CATEGORY[1:4]),
      "E3 term tree: 4 clusters coloured from the category palette")
check(identical(ttm$data$clusters[[ttm$data$term_order[[1]]]], "Cluster 1"), "E3 term tree: clusters numbered in leaf order")

gm <- figs$gsea_multi; gmm <- attr(gm, "os_meta")
gtop <- all_plots(gm)[[1]]
gb <- ggplot2::ggplot_build(gtop)$data[[2]]
rs1 <- os_gsea_running_score(rk, msets[[1]])
check(isTRUE(all.equal(gb$y[gb$group == 1], rs1$es)), "E3 gsea multi: lines are os_gsea_running_score()")
check(identical(unlist(gmm$encodings$colour), os_colours_for(names(msets), "gene_set")$colours[names(msets)]),
      "E3 gsea multi: one registry colour per set")
check(grepl("NES = 2.61", gmm$caption, fixed = TRUE) && grepl("NES = \u22122.20", gmm$caption, fixed = TRUE),
      "E3 gsea multi: caption lists NES per set (true minus)")

# ------------------------------------------------------- E4 typed errors ----
m2 <- m1[c("b", "a", "c"), ]
m3 <- rbind(m1, d = c(7, 8))
expect_error_code(os_heatmap_check_rows(list(expr = m1, score = m2)), "OS_FIG_ROW_MISMATCH", "E4 stacked heatmaps with different row order")
expect_error_code(os_heatmap_check_rows(list(m1, m3)), "OS_FIG_ROW_MISMATCH", "E4 stacked heatmaps with different row sets")
expect_error_code(os_heatmap_check_rows(list(m1, unname(m1))), "OS_FIG_ROW_MISMATCH", "E4 stacked heatmap without row names")
expect_error_code(os_heatmap(z, "z", mark_rows = "nope"), "OS_INVALID_PARAMETER", "E4 mark_rows not in the matrix")
expect_error_code(os_heatmap(z, "z", row_split = c("a", "b")), "OS_INVALID_PARAMETER", "E4 row_split of the wrong length")
expect_error_code(os_heatmap(z, "z", row_annot = ra[1:10, , drop = FALSE]), "OS_INVALID_PARAMETER", "E4 row_annot missing rows")
expect_error_code(os_heatmap(z, "z", row_split = rep(c("\u4e0a", "b"), 30)), "OS_FIG_NON_LATIN_TEXT", "E4 non-Latin slice title")
expect_error_code(os_alluvial(sc$emb, "cluster"), "OS_INVALID_PARAMETER", "E4 alluvial with one axis")
expect_error_code(os_alluvial(sc$emb, c("cluster", "nope")), "OS_MISSING_COLUMNS", "E4 alluvial missing column")
expect_error_code(os_highlight_embedding(sc$emb, "cluster", "C99"), "OS_INVALID_PARAMETER", "E4 highlight target not present")
expect_error_code(os_stacked_violin(sc$expr, sc$emb$cluster[-1]), "OS_INVALID_INPUT", "E4 stacked violin groups length")
expect_error_code(os_stacked_violin(sc$expr, sc$emb$cluster, genes = "NOPE"), "OS_MISSING_COLUMNS", "E4 stacked violin unknown gene")
expect_error_code(os_ridge(1, "a", "x"), "OS_EMPTY_DATA", "E4 ridge with one value")
expect_error_code(os_density_embedding(sc$emb, rep(0, nrow(sc$emb)), "Z"), "OS_EMPTY_DATA", "E4 density with all-zero weights")
expect_error_code(os_cluster_tree_dotplot(mk$md[mk$md$cluster %in% c("C1", "C2"), ]), "OS_EMPTY_DATA", "E4 cluster tree with 2 clusters")
expect_error_code(os_cnet(et, gs$sets, padj_threshold = 1e-30), "OS_EMPTY_DATA", "E4 cnet without significant sets")
expect_error_code(os_emap(et, gs$sets[1:2]), "OS_EMPTY_DATA", "E4 emap with fewer than 3 sets")
expect_error_code(os_cnet(et, unname(gs$sets)), "OS_INVALID_INPUT", "E4 cnet gene_sets without names")
expect_error_code(os_term_tree(et[, c("term_id", "padj")], gs$sets), "OS_MISSING_COLUMNS", "E4 term tree missing term_name")
seven <- stats::setNames(rep(list(top_g[1:50]), 7), paste("set", 1:7))
expect_error_code(os_gsea_multi(rk, seven), "OS_TOO_MANY_CATEGORIES", "E4 more than 6 sets in one GSEA panel")

# ----------------------------------------------------- E5 compatibility ----
old <- os_heatmap(z[1:20, ], "z", "diverging", clip = 2)
om <- attr(old, "os_meta")
check(identical(names(om$data), c("n_rows", "n_cols", "show_row_labels", "show_col_labels", "row_order", "col_order", "clustering")),
      "E5 os_heatmap without new arguments keeps the old figure_spec data keys")
check(identical(unlist(om$data$row_order), rownames(z)[1:20][stats::hclust(stats::dist(z[1:20, ]), "complete")$order]),
      "E5 os_heatmap unsplit row order = hclust order of the full matrix")
check(identical(om$data$clustering, list(rows = "euclidean/complete", cols = "euclidean/complete")), "E5 unsplit clustering description unchanged")
check(is.null(om$encodings$row_annotation) && is.null(om$colour_registry), "E5 no new meta fields when new features are unused")
tb <- os_top_heatmap(ex$mat, ft, ex$coldata, "condition", n = 30, reference = "control")
check(identical(attr(tb, "os_meta")$figure_type, "top_heatmap") && isTRUE(attr(tb, "os_meta")$encodings$fill$clipped_end_labels),
      "E5 os_top_heatmap still builds and now labels its clipped colour bar")
sd_ <- os_sample_distance(ex$mat, ex$coldata, "condition", reference = "control")
check(!isTRUE(attr(sd_, "os_meta")$encodings$fill$clipped_end_labels), "E5 unclipped heatmaps keep plain colour-bar labels")
mt <- fx_module_trait()
check(identical(attr(os_module_trait(mt$r, mt$p), "os_meta")$figure_type, "module_trait"), "E5 os_module_trait still builds")
grDevices::pdf(NULL)
spacer_gap <- suppressWarnings(patchwork::patchworkGrob(os_heatmap(z[1:10, ], "z")))   # PostScript font-metric warnings only
invisible(grDevices::dev.off())
check(inherits(spacer_gap, "gtable"), "E5 heatmap patchwork assembles")

# --------------------------------------------------------- E6 hygiene ----
own <- file.path(shared, c("scripts/fig_heatmap.R", "scripts/fig_sc_extra.R", "scripts/fig_enrich_network.R", "scripts/fig_all.R",
                           "tests/test_figures_ext.R", "tests/fixtures/fig_fixtures_ext.R"))
non_ascii <- own[vapply(own, function(f) any(readBin(f, "raw", file.info(f)$size) > as.raw(127)), logical(1))]
check(!length(non_ascii), sprintf("E6 extension .R files are ASCII only%s", if (length(non_ascii)) paste0(" (", paste(basename(non_ascii), collapse = ", "), ")") else ""))
check(all(vapply(c("OS_FIG_EXT", "os_stacked_violin", "os_ridge", "os_highlight_embedding", "os_alluvial", "os_cluster_tree_dotplot",
                   "os_density_embedding", "os_cnet", "os_emap", "os_term_tree", "os_gsea_multi", "os_heatmap_check_rows"),
                 exists, logical(1))), "E6 fig_all.R loads every extension function")
doc <- readLines(file.path(shared, "docs", "FIGURE_STYLE.md"), encoding = "UTF-8")
s16 <- which(grepl("^## 18\\. ", doc))
check(length(s16) == 1, "E6 FIGURE_STYLE.md has the sec 18 extension section")
if (length(s16)) {
  body16 <- paste(doc[s16:length(doc)], collapse = "\n")
  missing_tok <- names(OS_FIG_EXT)[!vapply(names(OS_FIG_EXT), function(k) grepl(paste0("`", k, "`"), body16, fixed = TRUE), logical(1))]
  check(!length(missing_tok), sprintf("E6 every OS_FIG_EXT constant is documented in sec 18%s",
                                      if (length(missing_tok)) paste0(" (missing: ", paste(missing_tok, collapse = ", "), ")") else ""))
}
specs <- list.files(file.path(outdir, "run1"), pattern = "figure_spec\\.json$", full.names = TRUE)
txt <- unlist(lapply(specs, readLines))
check(length(specs) == length(B), "E6 one figure_spec per extension figure")
check(!any(grepl(normalizePath(outdir), txt, fixed = TRUE)), "E6 figure specs contain no absolute paths")
check(!any(grepl("20[0-9]{2}-[0-9]{2}-[0-9]{2}", txt)), "E6 figure specs contain no dates")
setwd(old_wd)
check(!file.exists(file.path(tempdir(), "Rplots.pdf")) && !file.exists("Rplots.pdf"), "E6 no Rplots.pdf device leak")

if (length(failures)) {
  cat(sprintf("%d check(s) FAILED:\n", length(failures)))
  for (f in failures) cat("  - ", f, "\n", sep = "")
  quit(status = 1)
} else {
  cat("ALL EXTENDED FIGURE CHECKS PASSED\n")
  quit(status = 0)
}
