# Artificial metrics only: no public data, patient/cell record or golden write.
a <- commandArgs(FALSE); here <- dirname(normalizePath(sub("^--file=", "", a[grepl("^--file=", a)][1])))
root <- normalizePath(file.path(here, "../../.."))
source(file.path(root, "skills/_shared/scripts/fig_all.R"))
source(file.path(root, "skills/_shared/scripts/fig_mod_sc_seurat.R"))
source(file.path(root, "skills/_shared/scripts/fig_mod_sc_bioc.R"))
checks <- 0L
check <- function(ok, msg) { if (!isTRUE(ok)) stop(paste("FAIL", msg)); checks <<- checks + 1L; cat("PASS", msg, "\n") }
refuse <- function(expr) check(grepl("OS_INVALID_INPUT", tryCatch({ force(expr); "not refused" }, error = conditionMessage)), "typed QC input refusal")
# A touched legacy figure file must use the canonical error code, not aliases.
for (builder in list(function() os_embedding(data.frame(), "group"),
                     function() os_marker_dotplot(data.frame(), mean_definition = names(OS_MEAN_DEFINITIONS)[1]),
                     function() os_proportion_bar(data.frame()))) {
 message <- tryCatch({ builder(); "not refused" }, error = conditionMessage)
 check(grepl("^OS_MISSING_COLUMN:", message), "shared builder canonical missing-column refusal")
}
d <- data.frame(sample = rep(c("invented_A", "invented_B"), each = 6),
                counts = c(0, 0.01, 0.5, 1, 5, NA, 0, 0.2, 0.8, 2, 9, NA),
                pct = c(NA, 0, 0.1, 1, 2, 5, 0, 0.2, 1, 2, 3, 4))
original <- d
flow <- data.frame(sample = c("invented_C", "invented_B", "invented_A"), input = c(2L, 7L, 8L),
                   displayed = c(0L, 6L, 6L), removed_before_stage = c(2L, 1L, 2L))
build <- function(j = "nature") os_qc_violin(d, c("counts", "pct"), thresholds = list(counts = c(0, 0.1, 3)),
                  log10_metrics = "counts", data_stage = "after_creation", stage_counts = flow, journal = j,
                  metric_definitions = list(counts = list(unit = "artificial count", denominator = "one invented cell")))
p <- build(); meta <- attr(p, "os_meta"); z <- meta$counts$metric_display$counts
check(identical(d, original), "input values are not rewritten")
check(identical(p[[1]]$data$v, c(NA, 0.01, 0.5, 1, 5, NA, NA, 0.2, 0.8, 2, 9, NA)), "positive values below one preserved; zero and missing absent from log density")
check(z$total == 12 && z$zero == 2 && z$missing == 2 && z$positive_below_one == 4 && z$displayed == 8, "independent log denominator arithmetic")
check(sum(z$per_sample$total) == 12 && sum(z$per_sample$displayed) == 8 && z$per_sample$total[3] == 0, "per-sample counts include entirely prefiltered sample")
check(identical(unname(unlist(meta$counts$cells_per_sample)), c(6L, 6L, 0L)), "complete sample slots and counts reconcile")
check(identical(meta$thresholds$counts, c(0, 0.1, 3)) && identical(meta$notes$drawn_thresholds$counts, c(0.1, 3)), "zero cutoff retained in metadata but not drawn on log axis")
b <- suppressWarnings(ggplot2::ggplot_build(p[[1]]))
line <- b$data[[1]]$yintercept
check(isTRUE(all.equal(line, log10(c(0.1, 3)))), "thresholds use the same log10 coordinate transform as observations")
check(identical(meta$data$data_stage, "after_creation") && grepl("after object creation", meta$caption) && !grepl("before filtering", meta$caption), "creation stage is not misrepresented as raw filtering input")
check(grepl("5 removed before this stage", meta$caption) && grepl("2 zero and 2 missing", meta$caption) && grepl("4 positive values below 1", meta$caption), "visible caption states removals and separate zero/missing/subunit counts")
check(meta$definition$metrics$counts$unit == "artificial count" && identical(meta$definition$unspecified_metrics, list("pct")), "metric definitions declared, absent definitions not invented")
for (stage in c("raw_input", "after_cell_qc", "after_doublet_filter", "unspecified")) {
 q <- os_qc_violin(d, "pct", data_stage = stage)
 check(identical(attr(q, "os_meta")$data$data_stage, stage), paste("explicit stage", stage))
}
check(!grepl("before filtering", attr(os_qc_violin(d, "pct"), "os_meta")$caption), "default does not assert an unknown filtering history")
refuse(os_qc_violin(d, "counts", data_stage = "invented_stage"))
bad <- flow; bad$displayed[2] <- 5L; refuse(os_qc_violin(d, "counts", stage_counts = bad))
refuse(os_qc_violin(d, "counts", data_stage = "raw_input", stage_counts = flow))
bad <- d; bad$counts[1] <- -1; refuse(os_qc_violin(bad, "counts", log10_metrics = "counts"))
bad <- d; bad$counts[1] <- Inf; refuse(os_qc_violin(bad, "counts"))
bad <- d; bad$sample[1] <- NA; refuse(os_qc_violin(bad, "counts"))
refuse(os_qc_violin(d, "absent"))
refuse(os_qc_violin(d, "counts", log10_metrics = "absent"))
empty <- data.frame(sample = rep("empty_sample", 3), counts = c(0, 0, NA))
e <- os_qc_violin(empty, "counts", log10_metrics = "counts")
check(attr(e, "os_meta")$counts$metric_display$counts$displayed == 0, "all-zero log panel contains no fabricated positive measurements")
check(!inherits(try(suppressWarnings(ggplot2::ggplot_build(e[[1]])), silent = TRUE), "try-error"), "empty log panel builds with declared absence")
# Exercise both actual lane adapters without a native fit or data download.
saved <- list(); os_finalize_figure <- function(p, stem, ...) { saved[[basename(stem)]] <<- p; invisible(NULL) }
qd <- data.frame(sample = d$sample, nFeature_RNA = rep(1:6, 2), nCount_RNA = rep(c(1, 2, 3, 4, 5, 6), 2), percent.mt = rep(c(0, 1, 2, 3, 4, 5), 2))
sf <- data.frame(sample = c("invented_A", "invented_B", "invented_C"), input = c(8L, 7L, 2L), after_creation = c(6L, 6L, 0L), creation_removed = c(2L, 1L, 2L), retained = c(5L, 4L, 0L))
r <- list(tables = list(cell_qc = qd, filter_flow = sf), details = "Artificial adapter test only.", metric_definitions = list(percent.mt = list(unit = "percent", matched_feature_count = 2L)))
a <- list("min-features" = 0, "max-features" = 10, "min-counts" = 0, "max-counts" = 100, "max-mito" = 20, journal = "nature")
os_seurat_qc_figures(r, a, tempdir()); sm <- attr(saved$qc_metrics, "os_meta")
check(identical(sm$data$data_stage, "after_creation") && sum(sm$counts$stage_flow$removed_before_stage) == 5, "Seurat adapter consumes actual creation denominator")
check(sm$definition$metrics$percent.mt$matched_feature_count == 2L && identical(sm$counts$filter_flow, sf), "Seurat adapter retains metric provenance and distinct flow fields")
bd <- data.frame(batch = d$sample, sum = d$counts, detected = rep(1:6, 2), subsets_Mito_percent = d$pct)
bounds <- data.frame(metric = c("low_lib_size", "low_n_features", "high_subsets_Mito_percent"), lower = c(0, 1, -Inf), higher = c(Inf, Inf, 20))
bp <- os_bioc_qc_violin(bd, bounds, "Artificial caller caption.", "nature"); bm <- attr(bp, "os_meta")
check(identical(bm$data$data_stage, "raw_input") && grepl("zero and 2 missing", bm$caption) && grepl("Artificial caller caption", bm$caption), "Bioconductor adapter preserves transform disclosure and caller context")
# Render only project-made artificial values. No protected output path is used.
out <- Sys.getenv("OMICSTAT_QC_FIGURE_TEST_OUT", file.path(tempdir(), "qc-stage-semantics")); dir.create(out, recursive = TRUE, showWarnings = FALSE)
sha <- function(p) digest::digest(file = p, algo = "sha256")
for (j in c("nature", "cell")) {
 pa <- build(j); lint <- os_fig_lint(pa, j); check(!any(lint$severity %in% c("warning", "blocker")), paste(j, "style lint"))
 x <- os_save_figure(pa, file.path(out, j, "first", "synthetic_qc"), formats = "png", root = file.path(out, j, "first"), journal = j)
 y <- os_save_figure(build(j), file.path(out, j, "replay", "synthetic_qc"), formats = "png", root = file.path(out, j, "replay"), journal = j)
 check(identical(sha(x$files$png), sha(y$files$png)) && identical(sha(x$spec), sha(y$spec)), paste(j, "PNG and metadata byte replay"))
 check(x$spec_obj$data$data_stage == "after_creation" && sum(x$spec_obj$counts$stage_flow$displayed) == 12, paste(j, "serialized stage denominators"))
}
cat(checks, "QC stage/zero/threshold/adapter/render checks PASS\n")
