# test_figures.R -- tests for the omicstat figure layer (fig_*.R).
# ASCII only. Run with: Rscript test_figures.R   (any working directory)
# Exits non-zero and prints FAIL lines on any problem; prints PASS lines and
# exits 0 when every check succeeds (same protocol as test_forest.R).
#
# What is locked here:
#   T1 determinism  -- every figure type rendered twice gives byte-identical
#                      PNG, PDF (after date normalization), SVG and
#                      figure_spec.json (ENGINEERING_PLAN lock 5, byte tier)
#   T2 style tokens -- the machine token table in docs/FIGURE_STYLE.md equals
#                      OS_FIG / palettes in fig_style.R (doc cannot drift)
#   T3 colour registry -- same entity keeps its colour; new entities never
#                      move old ones; JSON round-trip is stable
#   T4 guards       -- typed errors: non-Latin text, too many categories,
#                      figure too tall, font below minimum, missing columns
#   T5 semantics    -- up/down colours, threshold lines, label selection,
#                      caption numbers equal the drawn counts
#   T6 hygiene      -- no Rplots.pdf, no absolute paths / timestamps in specs
#   T7 rasterisation -- > 50,000 points: bitmap point layer, still deterministic
#   T8 built layers -- ggplot_build() data: colours per class, threshold lines,
#                      labelled points, symmetric limits, size / colour scales
#   T9 colour vision -- CIEDE2000, Machado CVD simulation, FIG-03 lint,
#                      palette collision report
#   T10 contracts   -- P stars / labels, n with unit, clipped scales, mean
#                      expression definition, enrichment selection rule

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
shared <- normalizePath(file.path(here, ".."))
source(file.path(shared, "scripts", "fig_all.R"))
source(file.path(here, "fixtures", "fig_fixtures.R"))

outdir <- file.path(tempdir(), "omicstat_fig_test")
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

# Explicit labels on the largest island, rather than the median between islands.
multi <- data.frame(x = c(0, 0.1, -0.1, 0.2, 10, 10.1), y = c(0, 0.1, -0.1, 0.2, 0, 0.1), type = "A")
label_xy <- data.frame(group = "A", x = 0.05, y = 0.05)
p_multi <- os_embedding(multi, "type", label_xy = label_xy)
check(identical(attr(p_multi, "os_meta")$notes$label_xy, label_xy), "multi-island embedding preserves explicit largest-island coordinates")
built_multi <- ggplot2::ggplot_build(p_multi)
check(any(vapply(built_multi$data, function(d) "label" %in% names(d) && any(d$label == "A" & d$x == 0.05 & d$y == 0.05), logical(1))), "multi-island label uses explicit island median")
expect_error_code(os_embedding(multi, "type", label_xy = data.frame(group = "B", x = 0, y = 0)), "OS_INVALID_INPUT", "label groups must match drawn groups")
p_sampled <- os_embedding(multi[1:3, ], "type", display_max_per_group = 3, display_n_input = 6)
check(isTRUE(attr(p_sampled, "os_meta")$data$display_only) && grepl("Display only", attr(p_sampled, "os_meta")$caption), "display sampling is recorded in metadata and caption")
seeded <- os_colour_registry_new(); seeded$families$celltype <- stats::setNames(rep("#0072B2", 24), paste0("T", 1:24))
check(length(os_colours_for(paste0("T", 1:24), "celltype", seeded)$colours) == 24, "fully seeded registry accepts more than 23 categories")

# Opt-in halo label style: background-coloured halo rings under the ink text,
# identical placement inputs, recorded only when requested; default untouched.
halo_emb <- fx_embedding()
repel_layers <- function(p) Filter(function(l) inherits(l$geom, "GeomTextRepel"), p$layers)
p_plain <- os_embedding(halo_emb, "celltype")
p_halo <- os_embedding(halo_emb, "celltype", label_style = "halo")
lh <- repel_layers(p_halo); lp <- repel_layers(p_plain)
rings <- sort(OS_FIG_EXT$label_halo_rings, decreasing = TRUE)
check(length(lp) == 1 && length(lh) == length(rings), "halo style draws one repelled layer per halo ring; plain draws one")
check(identical(unname(vapply(lh, function(l) l$aes_params$bg.r, numeric(1))), rings), "halo rings run from the widest to the narrowest radius")
check(identical(unname(vapply(lh, function(l) l$aes_params$colour, character(1))), c(rep(OS_FIG$col_bg, length(rings) - 1), OS_FIG$col_ink)) &&
      all(vapply(lh, function(l) identical(l$aes_params$bg.colour, OS_FIG$col_bg), logical(1))),
      "halo rings are background-coloured and the ink text is drawn last")
same_place <- function(l, ref) identical(l$data, ref$data) && identical(l$geom_params$seed, ref$geom_params$seed) &&
  identical(l$geom_params$box.padding, ref$geom_params$box.padding) && identical(l$geom_params$point.padding, ref$geom_params$point.padding) &&
  identical(l$aes_params$size, ref$aes_params$size) && identical(l$geom_params$max.iter, ref$geom_params$max.iter)
check(all(vapply(lh, same_place, logical(1), ref = lh[[length(lh)]])), "halo layers share data, size, padding, seed and iteration budget (same placement)")
check(identical(lp[[1]]$aes_params$bg.r, 0.12) && identical(as.numeric(lp[[1]]$geom_params$box.padding), 0.05), "plain label style keeps the original halo and padding")
check(identical(attr(p_halo, "os_meta")$notes$label_style, "halo") && grepl("white halo", attr(p_halo, "os_meta")$caption, fixed = TRUE) &&
      is.null(attr(p_plain, "os_meta")$notes$label_style) && !grepl("halo", attr(p_plain, "os_meta")$caption, fixed = TRUE),
      "halo style is recorded in caption and notes only when requested")
check(!grepl("halo", attr(os_embedding(halo_emb, "celltype", label = FALSE, label_style = "halo"), "os_meta")$caption, fixed = TRUE),
      "label_style has no effect without labels")
check(!is.null(tryCatch(os_embedding(halo_emb, "celltype", label_style = "glow"), error = function(e) e)), "unknown label_style is refused")
rh1 <- os_save_figure(p_halo, file.path(outdir, "halo1", "umap"), formats = "png")
rh2 <- os_save_figure(os_embedding(halo_emb, "celltype", label_style = "halo"), file.path(outdir, "halo2", "umap"), formats = "png")
check(identical(sha(rh1$files$png), sha(rh2$files$png)), "halo label PNG byte-identical across reruns")

# ------------------------------------------------------------- builders ----
ft <- fx_feature_table(); ex <- fx_expression(ft); et <- fx_enrichment(); emb <- fx_embedding(3000)
mk <- fx_markers(); mt <- fx_module_trait(); mf <- fx_maf()
builders <- list(
  volcano = function() os_volcano(ft, contrast_label = "Treated vs control"),
  ma = function() os_ma(ft),
  pca = function() os_pca_plot(os_pca_scores(ex$mat), ex$coldata, "condition", shape_col = "batch", reference = "control"),
  sample_distance = function() os_sample_distance(ex$mat, ex$coldata, "condition", reference = "control"),
  top_heatmap = function() os_top_heatmap(ex$mat, ft, ex$coldata, "condition", n = 30, reference = "control"),
  ora_dotplot = function() os_enrich_dotplot(et, "gene_ratio"),
  nes_bar = function() os_nes_bar(et),
  gsea_curve = function() { rk <- fx_ranked(ft); os_gsea_curve(rk, names(sort(rk, decreasing = TRUE))[1:80], "Test set", 2.1, 1e-4) },
  embedding = function() os_embedding(emb, "celltype"),
  marker_dotplot = function() os_marker_dotplot(mk$md, mk$gene_order, mk$cluster_order, mean_definition = "log_mean"),
  proportion_bar = function() os_proportion_bar(fx_proportions(emb)),
  module_trait = function() os_module_trait(mt$r, mt$p),
  oncoplot = function() os_oncoplot(mf$maf, mf$samples, top_n = 10)
)

# ------------------------------------------------------ T1 determinism ----
for (nm in names(builders)) {
  r1 <- os_save_figure(builders[[nm]](), file.path(outdir, "run1", nm), formats = c("pdf", "png", "svg"),
                       root = file.path(outdir, "run1"))
  r2 <- os_save_figure(builders[[nm]](), file.path(outdir, "run2", nm), formats = c("pdf", "png", "svg"),
                       root = file.path(outdir, "run2"))
  for (ext in c("png", "svg")) {
    check(identical(sha(r1$files[[ext]]), sha(r2$files[[ext]])), sprintf("T1 %s.%s byte-identical across reruns", nm, ext))
  }
  check(identical(os_pdf_content_sha256(r1$files$pdf), os_pdf_content_sha256(r2$files$pdf)),
        sprintf("T1 %s.pdf content-identical across reruns (timestamp exempt)", nm))
  check(identical(sha(r1$spec), sha(r2$spec)), sprintf("T1 %s figure_spec.json byte-identical", nm))
}
Sys.sleep(1.1)
os_save_figure(builders$ma(), file.path(outdir, "later", "ma"), formats = "pdf")
check(identical(os_pdf_content_sha256(file.path(outdir, "run1", "ma.pdf")), os_pdf_content_sha256(file.path(outdir, "later", "ma.pdf"))),
      "T1 PDF content hash ignores the creation time")

# --------------------------------------------------------- T2 tokens ----
doc <- readLines(file.path(shared, "docs", "FIGURE_STYLE.md"), encoding = "UTF-8")
rows <- regmatches(doc, regexec("^\\| `([a-z_]+)` \\| `([^`]+)` \\|", doc))
rows <- rows[vapply(rows, length, integer(1)) == 3]
check(length(rows) >= 30, sprintf("T2 FIGURE_STYLE.md machine token table present (%d rows)", length(rows)))
pal_map <- list(OS_PAL_GROUP = OS_PAL_GROUP, OS_PAL_CATEGORY = OS_PAL_CATEGORY, OS_PAL_DIVERGING = OS_PAL_DIVERGING,
                OS_PAL_SEQUENTIAL = OS_PAL_SEQUENTIAL, OS_PAL_EXPRESSION = OS_PAL_EXPRESSION, OS_PAL_DISTANCE = OS_PAL_DISTANCE)
for (r in rows) {
  key <- r[2]; val <- r[3]
  code_val <- if (key %in% names(OS_FIG)) OS_FIG[[key]] else if (toupper(key) %in% names(pal_map)) pal_map[[toupper(key)]] else NULL
  if (is.null(code_val)) { check(FALSE, sprintf("T2 doc token '%s' exists in fig_style.R", key)); next }
  # numbers printed plainly (0.0001, not 1e-04; 50000, not 5e+04)
  code_chr <- if (is.numeric(code_val)) vapply(code_val, function(v) format(v, scientific = FALSE, trim = TRUE, drop0trailing = TRUE), character(1))
              else as.character(code_val)
  code_str <- paste(code_chr, collapse = ",")
  check(identical(gsub(" ", "", val), gsub(" ", "", code_str)), sprintf("T2 token %s: doc == code", key))
}
doc_keys <- vapply(rows, `[`, character(1), 2)
for (k in c("size_tag", "size_axis_title", "size_axis_text", "size_label", "size_min", "lw_axis", "lw_data", "lw_ref",
            "col_up", "col_down", "col_ns", "col_reference_group", "os_pal_category", "os_pal_diverging",
            "p_star_cutpoints", "p_star_symbols", "p_star_ns", "p_star_rule", "p_display_default", "n_units",
            "cvd_simulations", "cvd_severity", "cvd_delta_e_metric", "cvd_delta_e_min")) {
  check(k %in% doc_keys, sprintf("T2 key token '%s' documented", k))
}
check(identical(OS_PAL_DIVERGING[1], OS_FIG$col_down) && identical(OS_PAL_DIVERGING[length(OS_PAL_DIVERGING)], OS_FIG$col_up),
      "T2 diverging endpoints equal the up/down colours")
check(!anyDuplicated(toupper(OS_PAL_CATEGORY)), "T2 category palette has no duplicates")
check(!any(toupper(OS_PAL_CATEGORY) %in% toupper(c(OS_FIG$col_ns, OS_FIG$col_na, OS_FIG$col_reference_group))),
      "T2 category palette excludes the reserved greys")

# ----------------------------------------------------- T3 registry ----
r1 <- os_colours_for(c("T cell", "B cell", "NK"), family = "celltype")
check(identical(unname(r1$colours[c("B cell", "NK", "T cell")]), OS_PAL_CATEGORY[1:3]),
      "T3 first assignment follows sorted order and palette order")
r2 <- os_colours_for(c("Mono", "B cell", "T cell", "DC"), family = "celltype", registry = r1$registry)
check(identical(r2$colours[["B cell"]], r1$colours[["B cell"]]) && identical(r2$colours[["T cell"]], r1$colours[["T cell"]]),
      "T3 existing entities keep their colour when new ones arrive")
check(identical(unname(r2$colours[c("DC", "Mono")]), OS_PAL_CATEGORY[4:5]), "T3 new entities take the next free colours")
rp <- file.path(outdir, "reg.json")
os_colour_registry_write(r2$registry, rp)
back <- os_colour_registry_read(rp)
check(identical(back$families$celltype[sort(names(back$families$celltype))], r2$registry$families$celltype[sort(names(r2$registry$families$celltype))]),
      "T3 registry JSON round-trip")
os_colour_registry_write(back, file.path(outdir, "reg2.json"))
check(identical(sha(rp), sha(file.path(outdir, "reg2.json"))), "T3 registry JSON byte-stable")
g <- os_group_colours(c("control", "drugA", "drugB"), reference = "control")
check(identical(unname(g), c(OS_FIG$col_reference_group, OS_PAL_GROUP[1:2])), "T3 reference group is grey, others Okabe-Ito")

# ------------------------------------------------------- T4 guards ----
ft_cjk <- ft
top_up <- os_pick_labels(transform(ft, de_class = os_de_class(ft$log2fc, ft$padj, 0.05, 1)), 1)[1]
ft_cjk$symbol[ft_cjk$feature_id == top_up] <- "\u57fa\u56e0"   # a gene that WILL be labelled
expect_error_code(os_volcano(ft_cjk), "OS_FIG_NON_LATIN_TEXT", "T4 CJK gene label rejected")
expect_error_code(os_colours_for(sprintf("c%02d", 1:30), family = "x"), "OS_TOO_MANY_CATEGORIES", "T4 30 categories rejected")
expect_error_code(os_group_colours(sprintf("g%d", 1:9)), "OS_TOO_MANY_CATEGORIES", "T4 9 groups rejected")
expect_error_code(os_save_figure(builders$volcano(), file.path(outdir, "tall"), height_mm = 400), "OS_FIG_TOO_TALL", "T4 too-tall figure rejected")
expect_error_code(os_volcano(ft[, c("feature_id", "log2fc")]), "OS_MISSING_COLUMN", "T4 missing padj column")
expect_error_code(os_journal("lancet_fake"), "OS_INVALID_PARAMETER", "T4 unknown journal preset")
tiny <- builders$ma() + ggplot2::annotate("text", x = 1, y = 0, label = "tiny", size = os_fs(3))
lt <- os_fig_lint(tiny)
check(any(lt$rule == "FIG-01" & lt$severity == "blocker"), "T4 lint flags 3 pt text as blocker")
expect_error_code(os_finalize_figure(tiny, file.path(outdir, "tiny")), "OS_FIG_LINT_BLOCKER", "T4 finalize refuses blocker")
check(!file.exists(file.path(outdir, "tiny.pdf")), "T4 nothing written when lint blocks")
w <- tryCatch({ os_save_figure(os_top_heatmap(ex$mat, ft, ex$coldata, "condition", n = 60), file.path(outdir, "crowd"), height_mm = 60); "none" },
              warning = function(w) conditionMessage(w))
check(grepl("OS_FIG_ROW_LABELS_CROWDED", w), "T4 crowded heatmap row labels warned")

# Every figure type must pass lint under the strictest preset (Cell: 6 pt min).
cell_builders <- list(
  volcano = function() os_volcano(ft, journal = "cell"),
  ma = function() os_ma(ft, journal = "cell"),
  pca = function() os_pca_plot(os_pca_scores(ex$mat), ex$coldata, "condition", reference = "control", label_samples = TRUE, journal = "cell"),
  top_heatmap = function() os_top_heatmap(ex$mat, ft, ex$coldata, "condition", n = 30, reference = "control", journal = "cell"),
  module_trait = function() os_module_trait(mt$r, mt$p, journal = "cell"),
  embedding = function() os_embedding(emb, "celltype", journal = "cell"),
  soft = function() os_soft_threshold(fx_soft_threshold(), chosen_power = 8, journal = "cell"))
for (nm in names(cell_builders)) {
  lt <- os_fig_lint(cell_builders[[nm]](), journal = "cell")
  check(!any(lt$severity == "blocker"), sprintf("T4 %s passes lint under the Cell preset (6 pt minimum)", nm))
}

# ---------------------------------------------------- T5 semantics ----
v <- builders$volcano(); vm <- attr(v, "os_meta")
cls <- os_de_class(ft$log2fc, ft$padj, 0.05, 1)
check(vm$counts$up == sum(cls == "up") && vm$counts$down == sum(cls == "down"), "T5 volcano counts equal classification")
check(grepl(sprintf("n = %s)", os_num(vm$counts$up)), vm$caption, fixed = TRUE), "T5 caption carries the drawn up count")
check(identical(vm$encodings$colour$up, OS_FIG$col_up) && identical(vm$encodings$colour$down, OS_FIG$col_down), "T5 volcano up/down colours")
b <- ggplot2::ggplot_build(v)
hl <- unlist(lapply(b$data, function(d) if ("yintercept" %in% names(d)) d$yintercept))
vl <- unlist(lapply(b$data, function(d) if ("xintercept" %in% names(d)) d$xintercept))
check(isTRUE(all.equal(hl, -log10(0.05))) && setequal(vl, c(-1, 1)), "T5 volcano threshold lines at padj 0.05 and |LFC| 1")
d2 <- ft; d2$de_class <- cls
lab <- os_pick_labels(d2, 5)
up5 <- d2[d2$de_class == "up", ]; up5 <- up5$feature_id[order(up5$padj, -abs(up5$log2fc), up5$feature_id)][1:5]
check(identical(lab[1:5], up5), "T5 label choice = top 5 up by padj (deterministic tie-break)")
pc <- os_pca_scores(ex$mat)
check(all(apply(pc$scores[, c("PC1", "PC2")], 2, function(x) TRUE)), "T5 PCA scores computed")
pc2 <- os_pca_scores(-ex$mat + 2 * mean(ex$mat))
check(isTRUE(all.equal(abs(pc$scores$PC1), abs(pc2$scores$PC1))), "T5 PCA sign normalization stable under reflection")
check(identical(os_num(-2.5), "\u22122.5"), "T5 negative numbers use the true minus sign")
check(identical(os_p_text(0.0123), "0.012") && grepl("10\\^", os_p_text(3.2e-6)), "T5 P value text formatting")
tagged <- os_compose(list(builders$ma(), builders$ma()), ncol = 2, journal = "cell")
check(grepl("(A)", attr(tagged, "os_meta")$caption, fixed = TRUE), "T5 Cell preset uses upper-case panel letters")
tagged_n <- os_compose(list(builders$ma(), builders$ma()), ncol = 2, journal = "nature")
check(grepl("**a**,", attr(tagged_n, "os_meta")$caption, fixed = TRUE), "T5 Nature preset uses lower-case bold panel letters")

# ------------------------------------------------ T7 rasterisation ----
big <- fx_embedding(60000, seed = 21)
if (requireNamespace("ggrastr", quietly = TRUE)) {
  eb <- os_embedding(big, "celltype")
  check(isTRUE(attr(eb, "os_meta")$notes$rasterised_points), "T7 60,000-cell embedding rasterises the point layer")
  check(grepl("bitmap layer", attr(eb, "os_meta")$caption), "T7 caption discloses the bitmap layer")
  rb1 <- os_save_figure(eb, file.path(outdir, "big1", "umap"), formats = c("pdf", "png"))
  rb2 <- os_save_figure(os_embedding(big, "celltype"), file.path(outdir, "big2", "umap"), formats = c("pdf", "png"))
  check(file.info(rb1$files$pdf)$size < 3e6, sprintf("T7 rasterised PDF stays small (%.1f MB)", file.info(rb1$files$pdf)$size / 1e6))
  check(identical(os_pdf_content_sha256(rb1$files$pdf), os_pdf_content_sha256(rb2$files$pdf)), "T7 rasterised PDF content-identical across reruns")
  check(identical(sha(rb1$files$png), sha(rb2$files$png)), "T7 rasterised PNG byte-identical across reruns")
} else {
  cat("SKIP: T7 ggrastr not installed (it is part of env layer L7)\n")
}
check(!isTRUE(attr(os_embedding(emb, "celltype"), "os_meta")$notes$rasterised_points), "T7 3,000-cell embedding stays vector")

# ------------------------------------ T8 ggplot_build layer assertions ----
# What is DRAWN (built layer data), not what the builder says it drew.
.layer_is <- function(p, i, geom) inherits(p$layers[[i]]$geom, geom)
v <- builders$volcano(); vb <- ggplot2::ggplot_build(v); vm <- attr(v, "os_meta")
pal_de <- c(up = OS_FIG$col_up, down = OS_FIG$col_down, ns = OS_FIG$col_ns)
col_ok <- TRUE; seen <- character(0)
for (i in seq_along(v$layers)) {
  ld <- v$layers[[i]]$data
  if (!is.data.frame(ld) || !"de_class" %in% names(ld) || !nrow(ld)) next
  for (a in intersect(c("colour", "fill"), names(v$layers[[i]]$mapping))) {
    col_ok <- col_ok && identical(toupper(vb$data[[i]][[a]]), toupper(unname(pal_de[ld$de_class])))
    seen <- union(seen, ld$de_class)
  }
}
check(col_ok && setequal(seen, c("up", "down", "ns")), "T8 volcano: every drawn point colour equals the token of its class")
hl_i <- which(vapply(seq_along(v$layers), function(i) .layer_is(v, i, "GeomHline"), logical(1)))
vl_i <- which(vapply(seq_along(v$layers), function(i) .layer_is(v, i, "GeomVline"), logical(1)))
check(length(hl_i) == 1 && isTRUE(all.equal(vb$data[[hl_i]]$yintercept, -log10(0.05))) &&
        identical(toupper(vb$data[[hl_i]]$colour), OS_FIG$col_ref) && identical(vb$data[[hl_i]]$linetype, OS_FIG$ref_linetype),
      "T8 volcano: padj threshold line at -log10(0.05), reference colour, dashed")
check(length(vl_i) == 1 && isTRUE(all.equal(sort(vb$data[[vl_i]]$xintercept), c(-1, 1))), "T8 volcano: |log2FC| threshold lines at -1 and 1")
rp_i <- which(vapply(seq_along(v$layers), function(i) .layer_is(v, i, "GeomOsPlacedLabel"), logical(1)))
n_up <- sum(os_de_class(ft$log2fc, ft$padj, 0.05, 1) == "up"); n_dn <- sum(os_de_class(ft$log2fc, ft$padj, 0.05, 1) == "down")
n_drawn <- if (length(rp_i) == 1) sum(nzchar(vb$data[[rp_i]]$label)) else -1L
check(length(rp_i) == 1 && n_drawn == min(10, n_up) + min(10, n_dn) && n_drawn == length(vm$data$labelled_feature_ids),
      sprintf("T8 volcano: %d labelled points drawn (10 per direction)", n_drawn))
m <- builders$ma(); mb <- ggplot2::ggplot_build(m)
ylim <- mb$layout$panel_scales_y[[1]]$get_limits()
check(isTRUE(all.equal(ylim[1], -ylim[2])) && isTRUE(all.equal(ylim[2], attr(m, "os_meta")$data$y_limit)),
      sprintf("T8 MA: y limits symmetric (%s, %s)", ylim[1], ylim[2]))
e1 <- builders$embedding(); eb <- ggplot2::ggplot_build(e1)
ecols <- unlist(attr(e1, "os_meta")$encodings$colour)
reg_cols <- os_colours_for(sort(unique(emb$celltype), method = "radix"), family = "celltype")$colours
check(identical(ecols[names(reg_cols)], reg_cols) &&
        identical(eb$data[[1]]$colour, unname(reg_cols[as.character(e1$data$.g)])),
      "T8 embedding: every cell's drawn colour equals the registry colour of its category")
mkp <- builders$marker_dotplot(); mkb <- ggplot2::ggplot_build(mkp)
szs <- mkb$plot$scales$get_scales("size")
check(isTRUE(all.equal(szs$map(c(0, 100)), c(0.3, 3.2))) && all(mkb$data[[1]]$size >= 0.3 - 1e-9 & mkb$data[[1]]$size <= 3.2 + 1e-9),
      "T8 marker dot plot: size scale maps 0-100% to 0.3-3.2 mm")
cs <- mkb$plot$scales$get_scales("colour")
cl <- cs$get_labels(cs$get_breaks())
check(identical(cs$get_limits(), c(-2, 2)) && identical(cl[1], "\u2264\u22122") && identical(cl[length(cl)], "\u22652"),
      sprintf("T8 marker dot plot: clipped colour bar limits +/-2 with end labels %s / %s", cl[1], cl[length(cl)]))
nb <- builders$nes_bar(); nbb <- ggplot2::ggplot_build(nb)
bar <- nbb$data[[1]]
check(identical(toupper(bar$fill), ifelse(bar$xmin + bar$xmax > 0, OS_FIG$col_up, OS_FIG$col_down)) && any(bar$xmax > 0) && any(bar$xmin < 0),
      "T8 NES bar: fill is col_up for NES > 0 and col_down for NES < 0")
onc <- builders$oncoplot(); body <- onc[[2]]; ob <- ggplot2::ggplot_build(body)
tile_cls <- body$layers[[2]]$data$cls
check(identical(ob$data[[2]]$fill, unname(OS_PAL_MUTATION[tile_cls])) && all(ob$data[[1]]$fill == "#EFEFEF"),
      "T8 oncoplot: every variant tile's fill equals OS_PAL_MUTATION[class]; background tiles #EFEFEF")

# --------------------------------------- T9 colour-vision lint (FIG-03) ----
# CIEDE2000 against the Sharma, Wu & Dalal (2005) test data (pairs 1, 7, 17, 25, 33).
sharma <- list(list(c(50, 2.6772, -79.7751), c(50, 0, -82.7485), 2.0425),
               list(c(50, 0, 0), c(50, -1, 2), 2.3669),
               list(c(50, 2.5, 0), c(73, 25, -18), 27.1492),
               list(c(60.2574, -34.0099, 36.2677), c(60.4626, -34.1751, 39.4387), 1.2644),
               list(c(90.9257, -0.5406, -0.9208), c(88.6381, -0.8985, -0.7239), 1.5381))
de_ok <- vapply(sharma, function(s) abs(os_delta_e2000(s[[1]], s[[2]]) - s[[3]]) < 1e-4, logical(1))
check(all(de_ok), "T9 CIEDE2000 reproduces the Sharma et al. 2005 test pairs")
check(identical(os_cvd_simulate(OS_PAL_GROUP, "normal"), toupper(OS_PAL_GROUP)), "T9 'normal' simulation is the identity")
gs <- grDevices::col2rgb(os_cvd_simulate(OS_PAL_CATEGORY, "grayscale"))
check(all(gs[1, ] == gs[2, ] & gs[2, ] == gs[3, ]), "T9 grayscale simulation gives R = G = B")
grey_d <- grDevices::col2rgb(os_cvd_simulate("#808080", "deutan"))
check(all(abs(grey_d - 128) <= 1), "T9 deutan simulation leaves a neutral grey (almost) unchanged")
cvd_modes <- c("normal", OS_FIG$cvd_simulations)
cat_coll <- os_cvd_collisions(OS_PAL_CATEGORY, modes = cvd_modes)
cat(sprintf("INFO: T9 OS_PAL_CATEGORY: %d colour pairs closer than %s %s under normal/%s vision (reported, not failed):\n",
            nrow(cat_coll), OS_FIG$cvd_delta_e_metric, OS_FIG$cvd_delta_e_min, paste(OS_FIG$cvd_simulations, collapse = "/")))
for (i in seq_len(nrow(cat_coll))) {
  cat(sprintf("INFO:   %s (#%d) / %s (#%d)  %-6s %.1f\n", cat_coll$colour_a[i], match(cat_coll$colour_a[i], OS_PAL_CATEGORY),
              cat_coll$colour_b[i], match(cat_coll$colour_b[i], OS_PAL_CATEGORY), cat_coll$mode[i], cat_coll$delta_e[i]))
}
grp_coll <- os_cvd_collisions(OS_PAL_GROUP[1:4], modes = cvd_modes)
check(!nrow(grp_coll), sprintf("T9 OS_PAL_GROUP first 4 colours distinct (>= %s) under normal and simulated CVD%s",
                               OS_FIG$cvd_delta_e_min, if (nrow(grp_coll)) paste0(": ", .os_cvd_pairs_text(grp_coll)) else ""))
ref_coll <- os_cvd_collisions(c(OS_FIG$col_reference_group, OS_PAL_GROUP[1:4]), modes = cvd_modes)
check(!nrow(ref_coll), "T9 reference-group grey distinct from the first 4 group colours under simulated CVD")
ud_coll <- os_cvd_collisions(c(OS_FIG$col_up, OS_FIG$col_down, OS_FIG$col_ns), modes = cvd_modes)
check(!nrow(ud_coll), "T9 up / down / not-significant colours distinct under normal and simulated CVD")
gray_ud <- os_cvd_collisions(c(OS_FIG$col_up, OS_FIG$col_down), modes = "grayscale")
cat(sprintf("INFO: T9 up/down in grayscale: delta E %.1f (%s) -- direction is also encoded by position (sign of x)\n",
            os_cvd_pairs(c(OS_FIG$col_up, OS_FIG$col_down), "grayscale")$delta_e, if (nrow(gray_ud)) "below threshold" else "ok"))
bad_pal <- ggplot2::ggplot(data.frame(x = c("a", "b"), y = 1:2), ggplot2::aes(x, y, fill = x)) + ggplot2::geom_col() +
  ggplot2::scale_fill_manual(values = c(a = "#E69F00", b = "#8DB600"))
lt3 <- os_fig_lint(bad_pal)
check(any(lt3$rule == "FIG-03" & lt3$severity == "warning"), "T9 lint flags two colours that collide under protanopia (FIG-03 warning)")
lt_v <- os_fig_lint(builders$volcano())
check(!any(lt_v$rule == "FIG-03" & lt_v$severity == "warning"), "T9 volcano passes FIG-03 (no CVD warning)")
check(any(lt_v$rule == "FIG-03" & lt_v$severity == "info"), "T9 volcano up/down grayscale closeness reported as FIG-03 info")

# ------------------------------------- T10 display contracts (v1.1.0) ----
# P value stars: strict "p < cutpoint"
check(identical(os_p_stars(c(0.05, 0.0499, 0.01, 0.0099, 0.001, 0.00099, 1e-4, 9.99e-5, 1e-300, 0, 1)),
                c("ns", "*", "*", "**", "**", "***", "***", "****", "****", "****", "ns")),
      "T10 stars: p = 0.05 -> ns, 0.0499 -> *, each cut-point is strict")
check(identical(os_p_stars(c(NA, 0.2)), c(NA, "ns")), "T10 stars: NA in, NA out")
expect_error_code(os_p_stars(1.5), "OS_INVALID_PARAMETER", "T10 stars: P > 1 rejected")
check(identical(os_p_label(0.012, "Wilcoxon rank-sum test", "holm", 6),
                "Wilcoxon rank-sum test; Holm-adjusted P = 0.012 (family of 6 comparisons)"),
      "T10 caption label: test; adjustment; family size")
ul <- os_p_label(0.012, "Wilcoxon rank-sum test", adjusted = FALSE, family_size = 6)
check(grepl("unadjusted P = 0.012", ul, fixed = TRUE) && grepl("no multiplicity adjustment", ul, fixed = TRUE),
      "T10 unadjusted label says 'unadjusted'")
check(grepl("^unadjusted P", os_p_label(0.3, "t test", adjusted = FALSE, form = "short")) &&
        identical(os_p_label(0.012, "t test", "BH", 3, form = "short"), "adj. P = 0.012"),
      "T10 short on-plot form (adjusted / unadjusted)")
check(identical(os_p_label(1e-320, "t test", "BH", 3, form = "short"), paste0("adj. P < 10^", OS_MINUS, "300")) &&
        grepl("10\\^", os_p_label(3.2e-6, "t test", "BH", 3)) && grepl("P = NA", os_p_label(NA, "t test", "BH", 3), fixed = TRUE),
      "T10 tiny P and NA P formatted")
expect_error_code(os_p_label(0.01, "t test", family_size = 3), "OS_MISSING_PARAMETER", "T10 adjusted P without method")
expect_error_code(os_p_label(0.01, "t test", "holm"), "OS_MISSING_PARAMETER", "T10 adjusted P without family size")
check(identical(OS_FIG$p_display_default, "adjusted") && identical(formals(os_p_label)$adjusted, quote(identical(OS_FIG$p_display_default, "adjusted"))),
      "T10 adjusted P is the display default")
# n with its unit
check(identical(os_n_label(3, "samples"), "n = 3 samples") && identical(os_n_label(1, "samples"), "n = 1 sample") &&
        identical(os_n_label(c(120, 2400, 800), "cells", per = "sample"), paste0("n = 120", OS_NDASH, "2,400 cells per sample")),
      "T10 os_n_label: unit word, singular, range")
expect_error_code(os_n_label(3, "reps"), "OS_INVALID_PARAMETER", "T10 os_n_label rejects an unknown unit")
pbp <- builders$proportion_bar(); pbb <- ggplot2::ggplot_build(pbp)
strips <- unlist(pbb$layout$facet$params$labeller(pbb$layout$layout[, ".cond", drop = FALSE]))
check(all(grepl("n = 3\nsamples", strips, fixed = TRUE)), "T10 proportion bar strips carry n = 3 samples")
pcap <- attr(pbp, "os_meta")$caption
check(grepl("control, n = 3 samples", pcap, fixed = TRUE) && grepl("cells per sample", pcap, fixed = TRUE),
      "T10 proportion bar caption: samples per condition and cells per sample")
qv <- os_qc_violin(fx_qc(), c("nFeature", "percent_mt"))
check(grepl("cells per sample", attr(qv, "os_meta")$caption, fixed = TRUE), "T10 QC violin caption gives cells per sample")
sv <- os_score_violin(data.frame(ct = emb$celltype, s = seq_len(nrow(emb)) %% 7), "ct", "s", "Score")
check(grepl("cells per group", attr(sv, "os_meta")$caption, fixed = TRUE) &&
        grepl("not independent replicates", attr(sv, "os_meta")$caption, fixed = TRUE),
      "T10 score violin caption: cells per group and the replicate warning")
# marker dot plot: mean definition, clipping, few groups
expect_error_code(os_marker_dotplot(mk$md, mk$gene_order, mk$cluster_order), "OS_MISSING_PARAMETER", "T10 marker dot plot without mean_definition")
expect_error_code(os_marker_dotplot(mk$md, mean_definition = "median"), "OS_INVALID_PARAMETER", "T10 marker dot plot with unknown mean_definition")
mkm <- attr(mkp, "os_meta")
drawn <- mk$md[mk$md$pct_exp > 0, ]
check(identical(mkm$counts$clipped_cells, sum(abs(drawn$avg_exp) > 2)) && mkm$counts$dots_drawn == nrow(drawn) &&
        grepl(os_clip_note(sum(abs(drawn$avg_exp) > 2), nrow(drawn), 2, "dots"), mkm$caption, fixed = TRUE),
      sprintf("T10 marker dot plot: %d clipped dots counted and stated in the caption", mkm$counts$clipped_cells))
check(grepl(OS_MEAN_DEFINITIONS[["log_mean"]], mkm$caption, fixed = TRUE) && identical(mkm$definition$mean_expression, "log_mean"),
      "T10 marker dot plot caption states the mean-expression definition verbatim")
check(grepl(paste0("n = 120", OS_NDASH, "1,440 cells per cluster"), mkm$caption, fixed = TRUE), "T10 marker dot plot caption gives cells per cluster")
check(!grepl("fewer than 5", mkm$caption, fixed = TRUE), "T10 10 clusters: no few-groups QC sentence")
m4 <- os_marker_dotplot(mk$md[mk$md$cluster %in% c("B", "NK", "pDC"), ], mean_definition = "log1p_mean_expm1")
check(grepl("scaling across fewer than 5 groups exaggerates differences", attr(m4, "os_meta")$caption, fixed = TRUE) &&
        !is.null(attr(m4, "os_meta")$notes$qc_scaled_few_groups),
      "T10 3 z-scored clusters: QC sentence in caption and note")
m4u <- os_marker_dotplot(mk$md[mk$md$cluster %in% c("B", "NK", "pDC"), ], scaled = FALSE, mean_definition = "nonzero_mean")
check(!grepl("fewer than 5", attr(m4u, "os_meta")$caption, fixed = TRUE), "T10 unscaled dot plot: no z-score QC sentence")
# enrichment: selection rule, definitions, empty result
oc <- attr(builders$ora_dotplot(), "os_meta")
check(grepl("smallest adjusted P", oc$caption, fixed = TRUE) && grepl("ordered by gene ratio", oc$caption, fixed = TRUE) &&
        grepl("Gene ratio = input genes in the set / input genes annotated", oc$caption, fixed = TRUE) &&
        !is.null(oc$definition$selection) && !is.null(oc$definition$gene_ratio),
      "T10 ORA dot plot caption states selection, ordering and the gene-ratio definition")
check(grepl("NES from preranked GSEA", attr(builders$nes_bar(), "os_meta")$caption, fixed = TRUE) &&
        grepl("NES from preranked GSEA", attr(os_enrich_dotplot(et, "nes"), "os_meta")$caption, fixed = TRUE),
      "T10 NES figures state 'NES from preranked GSEA'")
cmp <- attr(os_enrich_compare(rbind(transform(et, group = "g1"), transform(et, group = "g2"))), "os_meta")
check(grepl("Selection: in each group", cmp$caption, fixed = TRUE) && grepl("Gene ratio =", cmp$caption, fixed = TRUE),
      "T10 compare dot plot caption states selection and gene ratio definition")
et_none <- transform(et, padj = pmax(et$padj, 0.2))
note <- os_enrich_empty_note(et_none, 0.05)
check(identical(note, sprintf("No gene set reached adjusted P < 0.05 (20 gene sets tested; smallest adjusted P = %s).", os_p_text(min(et_none$padj)))),
      "T10 empty-enrichment note: threshold, number tested, smallest adjusted P")
emsg <- tryCatch({ os_enrich_dotplot(et_none, "gene_ratio"); "" }, error = function(e) conditionMessage(e))
check(grepl("^OS_EMPTY_DATA: ", emsg) && grepl(note, emsg, fixed = TRUE), "T10 empty enrichment still throws OS_EMPTY_DATA, with the note")
expect_error_code(os_nes_bar(et_none), "OS_EMPTY_DATA", "T10 NES bar with no significant set")
sp <- jsonlite::fromJSON(file.path(outdir, "run1", "ora_dotplot.figure_spec.json"))
check(!is.null(sp$definition$gene_ratio) && identical(sp$style_version, OS_FIG_STYLE_VERSION), "T10 figure_spec carries 'definition' and the current style version")
volcano_spec <- jsonlite::fromJSON(file.path(outdir, "run1", "volcano.figure_spec.json"))
check(identical(volcano_spec$definition$de_contract$test$hypothesis, "unspecified"),
      "T10 legacy volcano declares an unspecified DE contract instead of inventing a native hypothesis")
plain_no_definition <- os_with_meta(
  ggplot2::ggplot(data.frame(x=0,y=0),ggplot2::aes(x,y)) + ggplot2::geom_point(),
  figure_type="test_no_definition",caption="Synthetic metadata-absence check.")
plain_saved <- os_save_figure(plain_no_definition,file.path(outdir,"no_definition"),formats="pdf",root=outdir)
check(is.null(jsonlite::fromJSON(plain_saved$spec)$definition), "T10 'definition' absent when a builder sets none")

# ------------------------------------------------------ T6 hygiene ----
rfiles <- list.files(shared, pattern = "\\.R$", recursive = TRUE, full.names = TRUE)
non_ascii <- rfiles[vapply(rfiles, function(f) any(readBin(f, "raw", file.info(f)$size) > as.raw(127)), logical(1))]
check(!length(non_ascii), sprintf("T6 all _shared .R files are ASCII only%s", if (length(non_ascii)) paste0(" (offenders: ", paste(basename(non_ascii), collapse = ", "), ")") else ""))
specs <- list.files(file.path(outdir, "run1"), pattern = "figure_spec\\.json$", full.names = TRUE)
txt <- unlist(lapply(specs, readLines))
check(!any(grepl(normalizePath(outdir), txt, fixed = TRUE)), "T6 figure specs contain no absolute paths")
check(!any(grepl("20[0-9]{2}-[0-9]{2}-[0-9]{2}", txt)), "T6 figure specs contain no dates")
setwd(old_wd)
check(!file.exists(file.path(tempdir(), "Rplots.pdf")) && !file.exists("Rplots.pdf"), "T6 no Rplots.pdf device leak")

if (length(failures)) {
  cat(sprintf("%d check(s) FAILED:\n", length(failures)))
  for (f in failures) cat("  - ", f, "\n", sep = "")
  quit(status = 1)
} else {
  cat("ALL FIGURE CHECKS PASSED\n")
  quit(status = 0)
}
