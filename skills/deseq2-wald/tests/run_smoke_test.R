# run_smoke_test.R -- module deseq2-wald. ASCII only on purpose.
# requires: DESeq2 apeglm pasilla ggplot2 ggrepel patchwork ragg svglite jsonlite digest
# Checks (ENGINEERING_PLAN 7.2 S2): anchors (PACK C, vignette printed values),
# flag effectiveness, typed errors and blockers, call-registry consistency,
# default drift, default consistency, flag-doc coverage, lint, determinism,
# --spec replay, --from-run chaining, golden baseline, no Rplots.pdf.
# OMICSTAT_WRITE_GOLDEN=1 rewrites tests/golden_manifest.csv from this run.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
shared <- file.path(suite, "skills", "_shared", "scripts")
source(file.path(shared, "calls_check.R"))
source(file.path(shared, "module_kit.R"))
source(file.path(shared, "handoff.R"))
source(file.path(shared, "ranked_list.R"))
source(file.path(shared, "enrich_rank_io.R"))
source(file.path(here, "fixtures", "make_pasilla.R"))
failures <- character(0)
check <- function(cond, msg) { if (isTRUE(cond)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
near <- function(a, b, tol = 5e-7) isTRUE(abs(a - b) <= tol * max(1, abs(b)))

tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "deseq2-wald-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
old_wd <- setwd(tmp)   # cwd independence: never run from the module directory
entry <- file.path(module_dir, "scripts", "run_deseq2_wald.R")
rscript <- file.path(R.home("bin"), "Rscript")
run <- function(...) {
  out <- suppressWarnings(system2(rscript, c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(out, "status") %||% 0L, out = out)
}
res_json <- function(d) jsonlite::fromJSON(file.path(d, "results", "deseq2_wald_results.json"))
read_full <- function(d) utils::read.csv(file.path(d, "tables", "deseq2_results_full.csv"), stringsAsFactors = FALSE)
sha <- function(p) digest::digest(file = p, algo = "sha256")

# ---- static checks ------------------------------------------------------------
scripts <- list.files(file.path(module_dir, "scripts"), pattern = "[.]R$", full.names = TRUE)
reg <- file.path(module_dir, "scripts", "calls_registry.json")
cc <- check_calls(scripts, reg)
check(cc$ok, paste("call registry consistent", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(reg)
check(dd$ok, paste("no default drift", paste(dd$problems, collapse = "; ")))
py <- Sys.which("python3")
tools_dir <- file.path(suite, "tools")
if (nzchar(py)) {
  for (tool in c("check_defaults.py", "check_flag_docs.py")) {
    o <- suppressWarnings(system2(py, c(shQuote(file.path(tools_dir, tool)), shQuote(module_dir)), stdout = TRUE, stderr = TRUE))
    check((attr(o, "status") %||% 0L) == 0L, paste(tool, paste(o, collapse = " | ")))
  }
  o <- suppressWarnings(system2(py, c(shQuote(file.path(tools_dir, "lint_r.py")), shQuote(file.path(module_dir, "scripts"))), stdout = TRUE, stderr = TRUE))
  check((attr(o, "status") %||% 0L) == 0L, paste("engine hygiene lint", paste(o, collapse = " | ")))
} else cat("SKIP: check_defaults.py / check_flag_docs.py / lint_r.py need python3\n")

# ---- A: anchors (DESeq2 vignette, pasilla; printed values) ---------------------
p <- make_pasilla(file.path(tmp, "pasilla"), suite)
base <- c("--counts", shQuote(p$counts), "--samples", shQuote(p$samples), "--reference", "untreated", "--target", "treated")
a1 <- file.path(tmp, "a1")
r <- run(base, "--alpha", "0.1", "--outdir", shQuote(a1))
check(r$status == 0, paste("A1 pasilla run exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j <- res_json(a1); f <- read_full(a1)
  check(j$n_tested == 8148, sprintf("A1 8,148 features after pre-filtering (vignette 'out of 8148'); got %s", j$n_tested))
  check(j$n_significant == 1069 && j$n_up == 533 && j$n_down == 536,
        sprintf("A1 padj < 0.1: 1,069 = 533 up + 536 down (vignette summary(res)); got %s = %s + %s", j$n_significant, j$n_up, j$n_down))
  g <- f[f$feature_id == "FBgn0000017", ]
  check(near(g$log2fc_mle, -0.23842494) && near(g$padj, 0.289604, 5e-6) && near(g$log2fc_shrunken, -0.18810628),
        "A1 FBgn0000017: MLE -0.23842494, padj 0.289604, apeglm -0.18810628 (vignette res / resLFC)")
  g <- f[f$feature_id == "FBgn0000008", ]
  check(near(g$log2fc_mle, 0.00399148) && near(g$log2fc_shrunken, 0.00195376), "A1 FBgn0000008: MLE 0.00399148, apeglm 0.00195376")
  last <- utils::tail(r$out, 1)
  check(grepl("^[0-9]+ of 12 rules triggered; read .+ first$", last), paste("A1 closing line format:", last))
  d <- readLines(file.path(a1, "draft", "methods_results.md"))
  check(!any(grepl("\\{[A-Za-z0-9_]+\\}", d)) && any(grepl("1,069 had an adjusted P value below 0.1", d, fixed = TRUE)),
        "A1 draft filled from the reporting template (no open slots; numbers match)")
  h <- read_handoff(a1, expect = list(feature_table = "feature_table", dds = "DESeqDataSet", count_matrix = "count_matrix", sample_table = "sample_table"))
  check(identical(h$module, "deseq2-wald"), "A1 handoff readable with the declared object types")
  ew <- utils::read.csv(file.path(a1, "qc", "engine_warnings.csv"))
  check(identical(names(ew), c("stage", "type", "message")), "A1 qc/engine_warnings.csv has columns stage, type, message")
  for (fig in c("volcano", "ma", "top_heatmap")) {
    sp <- jsonlite::fromJSON(file.path(a1, "figures", paste0(fig, ".figure_spec.json")))
    check(file.exists(file.path(a1, "figures", paste0(fig, ".pdf"))) && nzchar(sp$caption) && !grepl(tmp, jsonlite::toJSON(sp), fixed = TRUE),
          sprintf("A1 figure %s: pdf + caption, no absolute path in the spec", fig))
  }
}
a2 <- file.path(tmp, "a2")
r <- run(base, "--outdir", shQuote(a2))
check(r$status == 0, "A2 pasilla run at the default --alpha 0.05 exits 0")
if (r$status == 0) {
  j <- res_json(a2)
  check(j$n_up == 416 && j$n_down == 437, sprintf("A2 alpha 0.05: 416 up, 437 down (vignette summary(res05)); got %s, %s", j$n_up, j$n_down))
  # R: ranked_list producer (S4 contract a; MODULE_BUILD_BRIEF sec 3; S1 cross-module rule 2)
  h <- read_handoff(a2, expect = list(ranked_list = "ranked_list"))
  meta <- tryCatch(os_ranked_list_meta(h), error = function(e) conditionMessage(e))
  rk <- tryCatch(os_rank_read(h$objects$ranked_list$path), error = function(e) conditionMessage(e))
  ft2 <- utils::read.csv(file.path(a2, "tables", "feature_table.csv"), stringsAsFactors = FALSE)
  check(is.list(meta) && identical(meta$metric, "DESeq2 Wald statistic") && identical(meta$statistic, "wald_stat") &&
          identical(meta$statistic_kind, "test_statistic") && isTRUE(meta$directional) &&
          identical(meta$contrast, "condition: treated vs untreated") &&
          identical(meta$positive_end, "higher expression in treated than in untreated") && identical(meta$null_test, "zero_effect"),
        "R1 ranked_list metadata: DESeq2 Wald statistic, directional, treated vs untreated, zero-effect null")
  if (is.list(rk) && is.list(meta)) {
    fin <- ft2[is.finite(ft2$stat), ]
    m <- match(rk$table$feature_id, fin$feature_id)
    check(!anyNA(m) && nrow(rk$table) == nrow(fin) && meta$n_ranked == nrow(fin) && meta$n_excluded_nonfinite == nrow(ft2) - nrow(fin) &&
            isTRUE(all.equal(rk$table$score, fin$stat[m], tolerance = 1e-9)),
          sprintf("R2 ranked_list = every finite unshrunken Wald stat of the feature table (%d ranked, %d excluded), sorted descending",
                  nrow(rk$table), nrow(ft2) - nrow(fin)))
    # independent replay: the vignette's own call on the same filtered DESeqDataSet
    dds <- readRDS(file.path(a2, "objects", "dds.rds"))
    rv <- DESeq2::results(dds, contrast = c("condition", "treated", "untreated"))
    o <- as.data.frame(rv)[is.finite(rv$stat), ]
    o <- o[order(-o$stat, rownames(o), method = "radix"), ]
    check(identical(rownames(o), rk$table$feature_id) && isTRUE(all.equal(o$stat, rk$table$score, tolerance = 1e-9)),
          "R3 ranked_list replays DESeq2::results(dds, contrast = c('condition','treated','untreated'))$stat (replay anchor)")
  } else check(FALSE, paste("R2 ranked_list readable:", if (is.character(rk)) rk else "", if (is.character(meta)) meta else ""))
}
a3 <- file.path(tmp, "a3")
r <- run(base, "--alpha", "0.1", "--covariates", "type", "--min-samples", "3", "--shrinkage", "none", "--outdir", shQuote(a3))
check(r$status == 0, "A3 multi-factor run (~ type + condition, explicit --min-samples 3 = the vignette's smallestGroupSize) exits 0")
if (r$status == 0) {
  f <- read_full(a3)
  g <- f[f$feature_id == "FBgn0000017", ]; g2 <- f[f$feature_id == "FBgn0000037", ]
  check(near(g$log2fc_mle, -0.2548984) && near(g$padj, 0.131475, 5e-6) && near(g2$log2fc_mle, 0.4541562) && near(g2$padj, 0.691941, 5e-6),
        "A3 ~ type + condition: FBgn0000017 -0.2548984 / padj 0.131475, FBgn0000037 0.4541562 / 0.691941 (vignette resMF)")
  ft <- utils::read.csv(file.path(a3, "tables", "feature_table.csv"), stringsAsFactors = FALSE)
  m <- merge(ft, f, by = "feature_id")
  check(isTRUE(all.equal(m$log2fc, m$log2fc_mle)) && all(ft$shrinkage == "none"), "F1 --shrinkage none: feature-table log2fc is the MLE")
}

# ---- D: determinism, --spec replay, --from-run ----------------------------------
d1 <- file.path(tmp, "d1")
r <- run("--spec", shQuote(file.path(a2, "provenance", "resolved_spec.json")), "--outdir", shQuote(d1))
check(r$status == 0, "D1 --spec replay exits 0")
if (r$status == 0) {
  for (f in c("tables/feature_table.csv", "tables/deseq2_results_full.csv", "results/deseq2_wald_results.json",
              "figures/volcano.figure_spec.json", "figures/volcano.png", "figures/ma.png", "figures/top_heatmap.png", "draft/methods_results.md")) {
    check(identical(sha(file.path(a2, f)), sha(file.path(d1, f))), paste("D1 byte-identical on replay:", f))
  }
}
up <- file.path(tmp, "upstream")
dir.create(file.path(up, "objects"), recursive = TRUE)
invisible(file.copy(p$counts, file.path(up, "objects", "count_matrix.tsv"))); invisible(file.copy(p$samples, file.path(up, "objects", "sample_table.csv")))
write_handoff(up, "upstream", "deseq2-qc", "1.0.0",
              objects = list(count_matrix = list(path = file.path(up, "objects", "count_matrix.tsv"), type = "count_matrix"),
                             sample_table = list(path = file.path(up, "objects", "sample_table.csv"), type = "sample_table")))
d2 <- file.path(tmp, "d2")
r <- run("--from-run", shQuote(up), "--reference", "untreated", "--target", "treated", "--outdir", shQuote(d2))
check(r$status == 0 && identical(sha(file.path(a2, "tables", "feature_table.csv")), sha(file.path(d2, "tables", "feature_table.csv"))),
      "D2 --from-run gives the same feature table as --counts/--samples")
if (r$status == 0) {
  h <- jsonlite::fromJSON(file.path(d2, "objects", "handoff.json"))
  check(identical(unlist(h$upstream_runs), c("upstream", "d2")), "D2 upstream_runs chain recorded")
}
bc <- file.path(tmp, "upstream_bc")
dir.create(file.path(bc, "objects"), recursive = TRUE)
invisible(file.copy(p$counts, file.path(bc, "objects", "corrected.tsv"))); invisible(file.copy(p$samples, file.path(bc, "objects", "sample_table.csv")))
write_handoff(bc, "upstream_bc", "sva-batch", "1.0.0",
              objects = list(count_matrix = list(path = file.path(bc, "objects", "corrected.tsv"), type = "batch_corrected_matrix"),
                             sample_table = list(path = file.path(bc, "objects", "sample_table.csv"), type = "sample_table")))
r <- run("--from-run", shQuote(bc), "--reference", "untreated", "--target", "treated", "--outdir", shQuote(file.path(tmp, "d4")))
check(r$status != 0 && any(grepl("OS_BATCH_CORRECTED_INPUT", r$out)), "D4 a batch-corrected upstream matrix is refused (OS_BATCH_CORRECTED_INPUT, S1 sva-batch P-1)")
cat("col1,x\n", file = file.path(up, "objects", "sample_table.csv"), append = TRUE)
r <- run("--from-run", shQuote(up), "--reference", "untreated", "--target", "treated", "--outdir", shQuote(file.path(tmp, "d3")))
check(r$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", r$out)), "D3 a changed upstream object is refused (OS_HANDOFF_MISMATCH)")

# ---- E: typed errors and blockers (small synthetic fixture) ----------------------
set.seed(1)
syn <- matrix(stats::rnbinom(600 * 6, mu = 200, size = 5), 600, 6, dimnames = list(sprintf("ENSG%011d", 1:600), sprintf("S%d", 1:6)))
syn[1:40, 4:6] <- syn[1:40, 4:6] * 4L
write_mat <- function(m, path) utils::write.csv(data.frame(feature_id = rownames(m), m, check.names = FALSE), path, row.names = FALSE)
write_mat(syn, file.path(tmp, "syn_counts.csv"))
st <- data.frame(sample = colnames(syn), condition = rep(c("ctrl", "trt"), each = 3), batch = rep(c("b1", "b2"), 3), conf = rep(c("x", "y"), each = 3))
utils::write.csv(st, file.path(tmp, "syn_samples.csv"), row.names = FALSE)
sbase <- c("--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")))
r <- run(sbase, "--reference", "ctrl", "--target", "treated", "--outdir", shQuote(file.path(tmp, "e1")))
check(r$status != 0 && any(grepl("OS_INVALID_PARAMETER: level 'treated'", r$out)), "E1 unknown --target level -> OS_INVALID_PARAMETER")
r <- run(sbase, "--reference", "ctrl", "--target", "trt", "--covariates", "conf", "--min-samples", "3", "--outdir", shQuote(file.path(tmp, "e2")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN", r$out)), "E2 condition confounded with a covariate -> OS_INVALID_DESIGN")
r <- run(sbase, "--reference", "ctrl", "--target", "trt", "--min-cont", "5", "--outdir", shQuote(file.path(tmp, "e3")))
check(r$status != 0 && any(grepl("OS_UNKNOWN_FLAG", r$out)), "E3 misspelled flag -> OS_UNKNOWN_FLAG")
nonint <- syn; storage.mode(nonint) <- "double"; nonint[1, 1] <- 10.5
write_mat(nonint, file.path(tmp, "nonint.csv"))
e4 <- file.path(tmp, "e4")
r <- run("--counts", shQuote(file.path(tmp, "nonint.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")), "--reference", "ctrl", "--target", "trt", "--outdir", shQuote(e4))
q <- if (file.exists(file.path(e4, "qc", "qc_results.csv"))) utils::read.csv(file.path(e4, "qc", "qc_results.csv")) else NULL
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: DW-01", r$out)) && isTRUE(q$triggered[q$id == "DW-01"]) &&
        any(grepl("draft withheld", readLines(file.path(e4, "draft", "methods_results.md")))),
      "E4 non-integer counts -> DW-01 blocker, qc table written, draft withheld")
st1 <- st; st1$condition <- c("ctrl", "ctrl", "ctrl", "ctrl", "ctrl", "trt")
utils::write.csv(st1, file.path(tmp, "one_rep.csv"), row.names = FALSE)
r <- run("--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "one_rep.csv")), "--reference", "ctrl", "--target", "trt", "--outdir", shQuote(file.path(tmp, "e5")))
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: DW-03", r$out)), "E5 one replicate in a compared group -> DW-03 blocker")
r <- run(sbase, "--reference", "ctrl", "--target", "trt", "--covariates", "batch", "--outdir", shQuote(file.path(tmp, "e6")))
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER: the design is not a simple two-group design", r$out)),
      "E6 covariates without an explicit --min-samples -> OS_MISSING_PARAMETER (S1 P-3)")
st3 <- st; st3$condition <- rep(c("ctrl", "trt", "oth"), each = 2)
utils::write.csv(st3, file.path(tmp, "three_lv.csv"), row.names = FALSE)
r <- run("--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "three_lv.csv")), "--reference", "ctrl", "--target", "trt", "--outdir", shQuote(file.path(tmp, "e7")))
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER: the design is not a simple two-group design .*3 levels", r$out)),
      "E7 three condition levels without an explicit --min-samples -> OS_MISSING_PARAMETER (S1 P-3)")

# ---- F: flag effectiveness (synthetic) ------------------------------------------
f0 <- file.path(tmp, "f0"); f1 <- file.path(tmp, "f1"); f2 <- file.path(tmp, "f2")
r0 <- run(sbase, "--reference", "ctrl", "--target", "trt", "--outdir", shQuote(f0))
r1 <- run(sbase, "--reference", "ctrl", "--target", "trt", "--lfc-threshold", "1", "--outdir", shQuote(f1))
r2 <- run(sbase, "--reference", "ctrl", "--target", "trt", "--covariates", "batch", "--min-samples", "3", "--min-count", "400", "--outdir", shQuote(f2))
f5 <- file.path(tmp, "f5")
r5 <- run(sbase, "--reference", "ctrl", "--target", "trt", "--display-lfc-filter", "1", "--outdir", shQuote(f5))
if (r0$status == 0 && r1$status == 0 && r2$status == 0) {
  j0 <- res_json(f0); j1 <- res_json(f1); j2 <- res_json(f2)
  check(j0$n_significant >= 30, sprintf("F0 synthetic 4-fold block detected (%s significant)", j0$n_significant))
  check(j1$n_significant < j0$n_significant && j1$lfc_threshold == 1, "F2 --lfc-threshold 1 tests against |log2FC| > 1 (fewer significant)")
  check(j2$n_tested < j0$n_tested && identical(j2$design, "~ batch + condition"), "F3 --min-count and --covariates reach the engine")
  d <- readLines(file.path(f1, "draft", "methods_results.md"))
  check(any(grepl("The null hypothesis was |log2 fold change| <= 1", d, fixed = TRUE)), "F4 the Methods state the lfcThreshold null")
  check(identical(j0$fc_criterion$null_test, "log2 fold change = 0") && j0$fc_criterion$display_lfc_filter == 0 &&
          is.null(j0$fc_criterion$n_display_filtered) && !file.exists(file.path(f0, "tables", "display_filtered.csv")) &&
          identical(j1$fc_criterion$null_test, "|log2 fold change| <= 1") && j1$fc_criterion$min_effect_lfc_threshold == 1,
        "F5 fc_criterion records the zero-effect test, the minimum-effect threshold and the display filter (off by default)")
} else check(FALSE, "F synthetic runs exit 0")
check(r5$status == 0, "F6 --display-lfc-filter 1 run exits 0")
if (r5$status == 0 && r0$status == 0) {
  j5 <- res_json(f5)
  check(identical(sha(file.path(f0, "tables", "feature_table.csv")), sha(file.path(f5, "tables", "feature_table.csv"))) &&
          identical(sha(file.path(f0, "tables", "deseq2_results_full.csv")), sha(file.path(f5, "tables", "deseq2_results_full.csv"))),
        "F6 the display filter leaves the feature table and the full results byte-identical (padj unchanged)")
  dfl <- utils::read.csv(file.path(f5, "tables", "display_filtered.csv"), stringsAsFactors = FALSE)
  ft5 <- utils::read.csv(file.path(f5, "tables", "feature_table.csv"), stringsAsFactors = FALSE)
  want <- ft5$feature_id[!is.na(ft5$padj) & ft5$padj < 0.05 & abs(ft5$log2fc) >= 1]
  check(nrow(dfl) > 0 && setequal(dfl$feature_id, want) && j5$fc_criterion$n_display_filtered == nrow(dfl) &&
          j5$n_significant == j0$n_significant, sprintf("F6 display_filtered.csv = significant AND |log2fc| >= 1 (%d rows), n_significant unchanged", nrow(dfl)))
  d <- readLines(file.path(f5, "draft", "methods_results.md"))
  check(any(grepl("For display only, significant features were additionally listed when the absolute apeglm-shrunken log2 fold change was at least 1", d, fixed = TRUE)) &&
          any(grepl("display-only list, tables/display_filtered.csv", d, fixed = TRUE)),
        "F6 the Methods/Results state the display filter separately, without an FDR claim")
}

# ---- S4: low-count input (S3 F1) and resolved-option Methods (S3 F2) -------------
set.seed(42)
lc <- matrix(stats::rpois(1200 * 6, 1), 1200, 6, dimnames = list(sprintf("g%04d", 1:1200), paste0("s", 1:6)))
lc[1:100, ] <- matrix(stats::rnbinom(600, mu = 100, size = 5), 100, 6)
write_mat(lc, file.path(tmp, "low_counts.csv"))
utils::write.csv(data.frame(sample = colnames(lc), condition = rep(c("ctrl", "trt"), each = 3)), file.path(tmp, "low_samples.csv"), row.names = FALSE)
s1 <- file.path(tmp, "s4_low")
r <- run("--counts", shQuote(file.path(tmp, "low_counts.csv")), "--samples", shQuote(file.path(tmp, "low_samples.csv")), "--reference", "ctrl",
         "--target", "trt", "--min-count", "0", "--sf-type", "poscounts", "--fit-type", "mean", "--shrinkage", "none", "--outdir", shQuote(s1))
check(r$status == 0, paste("S4-F1 low-count input (1,200 rows, 100 with mean normalized count > 5) exits 0 instead of an untyped vst error",
                           paste(utils::tail(r$out, 2), collapse = " | ")))
if (r$status == 0) {
  j <- res_json(s1)
  d <- readLines(file.path(s1, "draft", "methods_results.md"))
  check(identical(j$heatmap_transformation$path, "varianceStabilizingTransformation") && j$heatmap_transformation$n_eligible_mean_gt5 < 1000,
        sprintf("S4-F1 fallback recorded: varianceStabilizingTransformation (%s eligible rows < nsub 1000)", j$heatmap_transformation$n_eligible_mean_gt5))
  check(any(grepl("modified geometric mean over positive counts (DESeq sfType = \"poscounts\")", d, fixed = TRUE)) &&
          any(grepl("mean of the gene-wise dispersion estimates (fitType = \"mean\")", d, fixed = TRUE)) &&
          !any(grepl("median-of-ratios", d, fixed = TRUE)) && !any(grepl("parametric", d, fixed = TRUE)) &&
          any(grepl("varianceStabilizingTransformation (blind = FALSE, fitType = \"mean\") directly", d, fixed = TRUE)) &&
          any(grepl("without shrinkage", d, fixed = TRUE)),
        "S4-F2 poscounts / mean / no-shrinkage run: Methods state the resolved size-factor, dispersion and heatmap-transformation choices")
  pv <- jsonlite::fromJSON(file.path(s1, "provenance", "resolved_spec.json"))$argv
  check(all(c("poscounts", "mean") %in% pv) && identical(j$size_factor_type, "poscounts") && identical(j$dispersion_fit_type, "mean"),
        "S4-F2 results JSON and resolved_spec agree on sfType / fitType")
}
if (file.exists(file.path(a2, "draft", "methods_results.md"))) {
  d <- readLines(file.path(a2, "draft", "methods_results.md"))
  j <- res_json(a2)
  check(any(grepl("median-of-ratios method (DESeq sfType = \"ratio\")", d, fixed = TRUE)) &&
          any(grepl("parametric mean-dispersion trend (fitType = \"parametric\")", d, fixed = TRUE)) &&
          any(grepl(sprintf("apeglm (v%s; lfcShrink type = \"apeglm\", coef = condition_treated_vs_untreated", utils::packageVersion("apeglm")), d, fixed = TRUE)) &&
          any(grepl("transformed with vst (blind = FALSE, nsub = 1000, fitType = \"parametric\")", d, fixed = TRUE)) &&
          identical(j$heatmap_transformation$path, "vst") && identical(j$shrinkage_package_version, as.character(utils::packageVersion("apeglm"))),
        "S4-F2 default run: Methods name median-of-ratios, parametric trend, apeglm version/coef and vst(blind = FALSE, nsub = 1000)")
  sp <- jsonlite::fromJSON(file.path(a2, "figures", "top_heatmap.figure_spec.json"))
  check(grepl("Values: vst (blind = FALSE, fitType = \"parametric\", nsub = 1000)", sp$caption, fixed = TRUE),
        "S4-F2 heatmap caption states the transformation")
}

# ---- G: golden baseline (lock 5) --------------------------------------------------
golden <- c("tables/feature_table.csv", "tables/deseq2_results_full.csv", "results/deseq2_wald_results.json", "objects/ranked_list.csv",
            "figures/volcano.figure_spec.json", "figures/ma.figure_spec.json", "figures/top_heatmap.figure_spec.json")
if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) { os_golden_write(module_dir, a2, golden); cat("golden manifest written\n") }
gc <- os_golden_check(module_dir, a2)
if (gc$status == "SKIP") cat("SKIP: golden baseline --", gc$reason, "\n") else check(gc$status == "PASS", paste("G golden baseline", paste(gc$problems, collapse = ", ")))

setwd(old_wd)
check(!file.exists(file.path(tmp, "Rplots.pdf")) && !file.exists(file.path(module_dir, "Rplots.pdf")), "no Rplots.pdf device leak")
if (length(failures)) { cat(length(failures), "check(s) FAILED\n"); quit(status = 1) } else cat("SMOKE PASSED\n")
