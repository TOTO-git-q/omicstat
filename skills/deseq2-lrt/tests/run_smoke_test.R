# requires: DESeq2 fission pasilla ggplot2 patchwork ragg svglite jsonlite digest
# deseq2-lrt S2 smoke: static locks, primary fission replay, secondary pasilla,
# typed errors, determinism, upstream handoff and golden baseline.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
source(file.path(suite, "skills", "_shared", "scripts", "calls_check.R"))
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
source(file.path(here, "fixtures", "make_fission.R"))
source(file.path(suite, "skills", "deseq2-wald", "tests", "fixtures", "make_pasilla.R"))
failures <- character(0)
check <- function(cond, msg) { if (isTRUE(cond)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
run <- function(entry, ...) {
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(out, "status") %||% 0L, out = out)
}
sha <- function(p) digest::digest(file = p, algo = "sha256")

# ---- oracle helpers (S4 F1): guide code only; never the engine or _shared ----
suppressPackageStartupMessages(library("DESeq2"))
os_acceptance_lib(suite)   # puts the acceptance library (fission, pasilla) on .libPaths()
# rnaseqGene workflow "Time course experiments", saved verbatim in
# acceptance/exemplars/deseq2-lrt/workflow_source/rnaseqGene_fission_timecourse.txt
# (Rmd:1886-1888 and Rmd:1899-1901). With all arguments NULL this IS the workflow
# code; each non-NULL argument is one named suite deviation.
fission_oracle <- function(prefilter_n = NULL, alpha = NULL, strain_levels = NULL) {
  suppressPackageStartupMessages(library("fission"))
  data("fission")
  if (!is.null(strain_levels)) fission$strain <- factor(as.character(fission$strain), levels = strain_levels)  # deviation: level order
  ddsTC <- DESeqDataSet(fission, ~ strain + minute + strain:minute)
  if (!is.null(prefilter_n)) {                           # deviation: suite pre-filter, workflow chunk Rmd:765-767
    smallestGroupSize <- prefilter_n
    keep <- rowSums(counts(ddsTC) >= 10) >= smallestGroupSize
    ddsTC <- ddsTC[keep,]
  }
  ddsTC <- suppressMessages(DESeq(ddsTC, test="LRT", reduced = ~ strain + minute))
  resTC <- if (is.null(alpha)) results(ddsTC) else results(ddsTC, alpha = alpha)   # deviation: alpha
  resTC$symbol <- mcols(ddsTC)$symbol
  list(dds = ddsTC, res = resTC)
}
# Every row and every numeric column of the engine's full table against the
# oracle's results(): identical feature sets, identical NA pattern, and relative
# difference <= 1e-8 elsewhere (the engine writes 10 significant digits).
assert_all_columns <- function(label, full, res, j) {
  same_ids <- nrow(full) == nrow(res) && setequal(full$feature_id, rownames(res)) && !anyDuplicated(full$feature_id)
  check(same_ids, sprintf("%s: engine table and oracle cover the same %d features", label, nrow(res)))
  if (!same_ids) return(invisible(FALSE))
  ii <- match(full$feature_id, rownames(res))
  cols <- c(base_mean = "baseMean", log2fc = "log2FoldChange", log2fc_se = "lfcSE", stat = "stat", pvalue = "pvalue", padj = "padj")
  for (k in names(cols)) {
    e <- full[[k]]; o <- res[[cols[[k]]]][ii]
    na_ok <- identical(is.na(e), is.na(o))
    ok <- !is.na(o)
    rel <- if (any(ok)) max(abs(e[ok] - o[ok]) / pmax(abs(o[ok]), 1e-300)) else 0
    check(na_ok && rel <= 1e-8,
          sprintf("%s: %s -- NA pattern identical (%d NA) and all %d values equal DESeq2 results()$%s (max relative diff %s)",
                  label, k, sum(is.na(o)), sum(ok), cols[[k]], format(rel, digits = 3)))
  }
  check(j$n_tested == nrow(res) && j$n_significant == sum(!is.na(res$padj) & res$padj < j$alpha) && j$n_padj_na == sum(is.na(res$padj)),
        sprintf("%s: JSON counts (tested %d, significant %d, padj NA %d) equal the oracle's", label, j$n_tested, j$n_significant, j$n_padj_na))
  invisible(TRUE)
}
# A printed value is matched to its printed decimals: |x - printed| <= half a
# unit in the last printed digit (mantissa decimals for e-notation).
printed_ok <- function(x, s) {
  s <- trimws(s)
  m <- regmatches(s, regexec("^-?[0-9]+(\\.([0-9]+))?(e([-+]?[0-9]+))?$", s))[[1]]
  if (!length(m)) return(FALSE)
  dec <- nchar(m[3]); ex <- if (nzchar(m[5])) as.integer(m[5]) else 0L
  isTRUE(abs(x - as.numeric(s)) <= 0.5 * 10^(ex - dec) * (1 + 1e-9))
}
entry <- file.path(module_dir, "scripts", "run_deseq2_lrt.R")
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "deseq2-lrt-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
old_wd <- setwd(tmp)
reg <- file.path(module_dir, "scripts", "calls_registry.json")
cc <- check_calls(list.files(file.path(module_dir, "scripts"), pattern = "[.]R$", full.names = TRUE), reg)
check(cc$ok, paste("call registry", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(reg)
check(dd$ok, paste("default drift", paste(dd$problems, collapse = "; ")))
py <- Sys.which("python3")
if (nzchar(py)) {
  for (tool in c("check_defaults.py", "check_flag_docs.py")) {
    o <- suppressWarnings(system2(py, c(shQuote(file.path(suite, "tools", tool)), shQuote(module_dir)), stdout = TRUE, stderr = TRUE))
    check((attr(o, "status") %||% 0L) == 0, paste(tool, paste(o, collapse = " | ")))
  }
  o <- suppressWarnings(system2(py, c(shQuote(file.path(suite, "tools", "lint_r.py")), shQuote(file.path(module_dir, "scripts"))), stdout = TRUE, stderr = TRUE))
  check((attr(o, "status") %||% 0L) == 0, paste("lint_r.py", paste(o, collapse = " | ")))
} else cat("SKIP: Python static checks unavailable\n")

f <- make_fission(file.path(tmp, "fission"), suite)
a1 <- file.path(tmp, "a1")
base <- c("--counts", shQuote(f$counts), "--samples", shQuote(f$samples),
          "--full", shQuote("~ strain + minute + strain:minute"), "--reduced", shQuote("~ strain + minute"),
          "--group-col", "strain", "--time-col", "minute", "--min-samples", "3")
r <- run(entry, base, "--outdir", shQuote(a1))
check(r$status == 0, paste("A1 fission interaction LRT exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j <- jsonlite::fromJSON(file.path(a1, "results", "deseq2_lrt_results.json"))
  ft <- utils::read.csv(file.path(a1, "tables", "feature_table.csv"), check.names = FALSE)
  check(j$df == 5 && identical(j$tested_terms, "strain:minute") && j$n_tested == nrow(ft), "A1 records interaction term, df=5 and full tested table")
  check(length(unique(ft$feature_id)) == nrow(ft) && "SPAC212.11" %in% ft$feature_id, "A1 fission dotted IDs stay intact")
  check(all(ft$stat[!is.na(ft$stat)] >= 0), "A1 LRT statistic is nonnegative")
  check(j$n_significant > 1 && file.exists(file.path(a1, "figures", "top_heatmap.png")) && file.exists(file.path(a1, "figures", "trajectory.png")), "A1 heatmap and trajectory produced")
  # A1 REPLAY (suite path): the rnaseqGene workflow's own fission code, run in
  # this session on data("fission") (never the engine, never a _shared helper).
  # Source, saved verbatim: acceptance/exemplars/deseq2-lrt/workflow_source/
  # rnaseqGene_fission_timecourse.txt (Rmd:1886-1888, Rmd:1899-1900). Named
  # deviations, all of them suite settings (see that file, "How the suite
  # differs"): (1) the suite pre-filter count >= 10 in >= 3 samples, written as
  # the workflow's own pre-filter chunk (Rmd:765-767) with smallestGroupSize = 3
  # (the workflow applies none to fission); (2) results(alpha = 0.05), the
  # suite default (workflow: results() default 0.1); (3) strain levels in the
  # suite's radix order (mut, wt) so both fits use the same parameterization.
  wf <- fission_oracle(prefilter_n = 3L, alpha = 0.05, strain_levels = c("mut", "wt"))
  full <- utils::read.csv(file.path(a1, "tables", "deseq2_lrt_results_full.csv"), check.names = FALSE)
  assert_all_columns("A1 REPLAY (suite filter, 6,205 rows)", full, wf$res, j)
  d <- readLines(file.path(a1, "draft", "methods_results.md"))
  check(any(grepl("strain:minute", d, fixed = TRUE)) && any(grepl("single coefficient", d, fixed = TRUE)), "A1 draft identifies joint terms and single reported coefficient")
  for (nm in c("top_heatmap", "trajectory")) {
    sp <- jsonlite::fromJSON(file.path(a1, "figures", paste0(nm, ".figure_spec.json")))
    check(nzchar(sp$caption) && file.exists(file.path(a1, "figures", paste0(nm, ".pdf"))), paste("A1", nm, "caption and PDF"))
  }
}

# ---- F2: Methods and captions state the display transformation and selection --
if (file.exists(file.path(a1, "draft", "methods_results.md"))) {
  d <- paste(readLines(file.path(a1, "draft", "methods_results.md")), collapse = "\n")
  check(grepl("transformed with DESeq2::vst(blind = FALSE, nsub = 1000, fitType = \"parametric\")", d, fixed = TRUE) &&
          grepl("does not enter the likelihood ratio test", d, fixed = TRUE) && grepl("BH-adjusted LRT P < 0.05 across the 36 samples", d, fixed = TRUE),
        "F2 Methods names the display transformation actually run (vst, blind = FALSE, nsub = 1000, fitType), keeps it apart from the LRT, and states the padj < alpha selection and n = 36")
  hm <- jsonlite::fromJSON(file.path(a1, "figures", "top_heatmap.figure_spec.json"))$caption
  check(grepl("Transformed expression = DESeq2::vst(blind = FALSE, nsub = 1000, fitType = \"parametric\")", hm, fixed = TRUE) &&
          grepl(sprintf("among the %d features with adjusted P < 0.05 in the likelihood ratio test", j$n_significant), hm, fixed = TRUE) &&
          grepl("n = 36 samples", hm, fixed = TRUE),
        paste("F2 heatmap caption states the transformation call, the LRT padj < alpha source set and n:", hm))
  tj <- jsonlite::fromJSON(file.path(a1, "figures", "trajectory.figure_spec.json"))$caption
  check(grepl(sprintf("among the %d features with adjusted P < 0.05 in the likelihood ratio test", j$n_significant), tj, fixed = TRUE) &&
          grepl("n = 36 samples", tj, fixed = TRUE) && grepl("counts(dds, normalized = TRUE)", tj, fixed = TRUE),
        paste("F2 trajectory caption states the LRT padj < alpha source set, n and the normalized-count scale:", tj))
  jj <- jsonlite::fromJSON(file.path(a1, "results", "deseq2_lrt_results.json"))
  check(identical(jj$display_transform, "vst") && isFALSE(jj$display_transform_blind) && jj$display_transform_nsub == 1000 &&
          isFALSE(jj$display_transform_fallback) && jj$n_samples == 36, "F2 results JSON records display transform vst, blind FALSE, nsub 1000, no fallback, 36 samples")
}
# F2 fallback path: fewer than 1,000 features with mean normalized count > 5 ->
# the direct varianceStabilizingTransformation, and the text must say so.
set.seed(7)
syn <- matrix(stats::rnbinom(600 * 6, mu = 200, size = 20), 600, 6, dimnames = list(sprintf("G%04d", 1:600), sprintf("S%d", 1:6)))
syn[1:40, 4:6] <- syn[1:40, 4:6] * 8L
utils::write.csv(data.frame(feature_id = rownames(syn), syn, check.names = FALSE), file.path(tmp, "syn_counts.csv"), row.names = FALSE)
utils::write.csv(data.frame(sample = colnames(syn), condition = rep(c("ctrl", "trt"), each = 3)), file.path(tmp, "syn_samples.csv"), row.names = FALSE)
f2 <- file.path(tmp, "f2-fallback")
r <- run(entry, "--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")),
         "--full", shQuote("~ condition"), "--reduced", shQuote("~ 1"), "--min-samples", "3", "--outdir", shQuote(f2))
check(r$status == 0, paste("F2 fallback synthetic run (600 features) exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  jf <- jsonlite::fromJSON(file.path(f2, "results", "deseq2_lrt_results.json"))
  df2 <- paste(readLines(file.path(f2, "draft", "methods_results.md")), collapse = "\n")
  want <- sprintf("DESeq2::varianceStabilizingTransformation(blind = FALSE, fitType = \"parametric\") -- the direct VST, because only %d features had a mean normalized count > 5",
                  jf$n_vst_eligible)
  check(isTRUE(jf$display_transform_fallback) && identical(jf$display_transform, "varianceStabilizingTransformation") && jf$n_vst_eligible < 1000 &&
          grepl(want, df2, fixed = TRUE) && grepl("across the 6 samples", df2, fixed = TRUE),
        "F2 fallback: JSON and Methods name the direct varianceStabilizingTransformation (blind = FALSE, fitType) with the eligible-feature count and n = 6")
  if (file.exists(file.path(f2, "figures", "top_heatmap.figure_spec.json"))) {
    hc <- jsonlite::fromJSON(file.path(f2, "figures", "top_heatmap.figure_spec.json"))$caption
    check(grepl(want, hc, fixed = TRUE) && grepl("n = 6 samples", hc, fixed = TRUE), paste("F2 fallback heatmap caption names the direct VST:", hc))
  } else check(FALSE, "F2 fallback run produced no heatmap (needs >= 2 significant features)")
}

# ---- A0 PRINTED anchor: rnaseqGene workflow printed head(resTC[order(resTC$padj),], 4)
# (workflow_source/rnaseqGene_fission_timecourse.txt, "Printed output"; rendered
# Bioc 3.23 workflow, DESeq2 1.52.0). The workflow runs with no pre-filter and
# results() alpha = 0.1; the engine is run the same way (--min-count 0
# --min-samples 1 keeps every row, --alpha 0.1).
printed <- data.frame(id = c("SPBC2F12.09c", "SPAC1002.18", "SPAC1002.19", "SPAC1002.17c"),
                      baseMean = c("174.671", "444.505", "336.373", "261.773"),
                      log2FoldChange = c("-2.6567195", "-0.0509321", "-0.3927490", "-1.1387648"),
                      lfcSE = c("0.752261", "0.204299", "0.573494", "0.606129"),
                      stat = c("97.2834", "56.9536", "43.5339", "39.3158"),
                      pvalue = c("1.97415e-19", "5.16955e-11", "2.87980e-08", "2.05137e-07"),
                      padj = c("1.33453e-15", "1.74731e-07", "6.48916e-05", "3.46682e-04"),
                      symbol = c("atf21", "urg3", "urg1", "urg2"), stringsAsFactors = FALSE)
wf0 <- fission_oracle()   # the workflow code exactly as written
top <- head(wf0$res[order(wf0$res$padj),], 4)
cells_ok <- all(vapply(c("baseMean", "log2FoldChange", "lfcSE", "stat", "pvalue", "padj"), function(k)
  all(mapply(printed_ok, top[[k]], printed[[k]])), logical(1)))
check(identical(rownames(top), printed$id) && identical(as.character(top$symbol), printed$symbol) && cells_ok &&
        identical(as.character(S4Vectors::mcols(top)$description[c(2, 5)]),
                  c("log2 fold change (MLE): strainmut.minute180", "LRT p-value: '~ strain + minute + strain:minute' vs '~ strain + minute'")),
      "A0 oracle self-check: the workflow code reproduces every printed cell (4 rows x 7 columns, and both header lines) in this container")
a0 <- file.path(tmp, "a0")
r <- run(entry, "--counts", shQuote(f$counts), "--samples", shQuote(f$samples),
         "--full", shQuote("~ strain + minute + strain:minute"), "--reduced", shQuote("~ strain + minute"),
         "--group-col", "strain", "--min-count", "0", "--min-samples", "1", "--alpha", "0.1", "--outdir", shQuote(a0))
check(r$status == 0, paste("A0 fission, workflow settings (no pre-filter, alpha 0.1), exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j0 <- jsonlite::fromJSON(file.path(a0, "results", "deseq2_lrt_results.json"))
  full0 <- utils::read.csv(file.path(a0, "tables", "deseq2_lrt_results_full.csv"), check.names = FALSE)
  check(j0$n_input_features == 7039 && j0$n_tested == 7039, sprintf("A0 all 7,039 fission rows tested, like the workflow (got %s of %s)", j0$n_tested, j0$n_input_features))
  e4 <- full0[order(full0$padj, full0$feature_id, method = "radix"), , drop = FALSE][1:4, ]
  check(identical(e4$feature_id, printed$id), paste("A0 PRINTED: engine's 4 smallest adjusted P are the printed genes in the printed order:", paste(e4$feature_id, collapse = ", ")))
  for (k in c("base_mean", "stat", "pvalue", "padj")) {
    pk <- c(base_mean = "baseMean", stat = "stat", pvalue = "pvalue", padj = "padj")[[k]]
    check(identical(e4$feature_id, printed$id) && all(mapply(printed_ok, e4[[k]], printed[[pk]])),
          sprintf("A0 PRINTED: engine %s of the 4 printed genes equals the workflow's printed %s to the printed digits (%s)", k, pk, paste(printed[[pk]], collapse = ", ")))
  }
  # The printed log2FoldChange/lfcSE columns are coefficient strainmut.minute180
  # (fission's own level order wt, mut). The engine orders levels by radix (mut,
  # wt), so it displays strainwt.minute180 -- a different coefficient of the same
  # model. Those two printed columns are asserted on the workflow code above
  # (oracle self-check), not on the engine; the engine's values are shown here.
  check(identical(j0$report_coefficient, "strainwt.minute180"),
        "A0 engine displays coefficient strainwt.minute180 (radix levels mut, wt); the printed LFC/lfcSE are strainmut.minute180 and are checked on the workflow code only")
  cat(sprintf("NOTE: A0 printed log2FoldChange/lfcSE (strainmut.minute180) %s / %s; engine strainwt.minute180 %s / %s -- different coefficient, not compared\n",
              paste(printed$log2FoldChange, collapse = " "), paste(printed$lfcSE, collapse = " "),
              paste(formatC(e4$log2fc, digits = 8, format = "g"), collapse = " "), paste(formatC(e4$log2fc_se, digits = 6, format = "g"), collapse = " ")))
  # A0 REPLAY: the whole unfiltered table against the workflow code with the
  # suite's level order (only deviation) and the workflow's alpha 0.1.
  wf0b <- fission_oracle(alpha = 0.1, strain_levels = c("mut", "wt"))
  assert_all_columns("A0 REPLAY (workflow settings, 7,039 rows)", full0, wf0b$res, j0)
  ok <- !is.na(wf0$res$pvalue) & !is.na(wf0b$res$pvalue)
  cat(sprintf("INFO: workflow level order (wt, mut) vs suite order (mut, wt): max relative LRT P difference %s over %d genes (IRLS convergence under a different parameterization; the printed rows agree to their printed digits)\n",
              format(max(abs(wf0$res$pvalue[ok] - wf0b$res$pvalue[ok]) / wf0$res$pvalue[ok]), digits = 3), sum(ok)))
}

# ---- F3: --report-coef changes only the displayed coefficient ------------------
reg_json <- jsonlite::fromJSON(reg, simplifyVector = FALSE)
res_call <- Filter(function(x) identical(x$fn, "DESeq2::results"), reg_json$calls)[[1]]
check(!is.null(res_call$args$name) && identical(res_call$args$name$flag, "--report-coef") && nzchar(res_call$args$name$source %||% ""),
      "F3 calls_registry.json registers results(name =) with its source and the --report-coef binding")
if (file.exists(file.path(a1, "tables", "deseq2_lrt_results_full.csv"))) {
  f3 <- file.path(tmp, "f3-report-coef")
  r <- run(entry, base, "--report-coef", "strainwt.minute30", "--outdir", shQuote(f3))
  check(r$status == 0, paste("F3 --report-coef strainwt.minute30 exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
  if (r$status == 0) {
    ja <- jsonlite::fromJSON(file.path(a1, "results", "deseq2_lrt_results.json"))
    jb <- jsonlite::fromJSON(file.path(f3, "results", "deseq2_lrt_results.json"))
    ca <- utils::read.csv(file.path(a1, "tables", "deseq2_lrt_results_full.csv"), colClasses = "character", check.names = FALSE)
    cb <- utils::read.csv(file.path(f3, "tables", "deseq2_lrt_results_full.csv"), colClasses = "character", check.names = FALSE)
    check(identical(jb$report_coefficient, "strainwt.minute30") && identical(jb$header_log2fc, "log2 fold change (MLE): strainwt.minute30") &&
            identical(ja$report_coefficient, "strainwt.minute180"),
          "F3 the displayed coefficient follows --report-coef (default: last resultsNames entry strainwt.minute180)")
    joint <- c("feature_id", "base_mean", "stat", "pvalue", "padj", "filtered_reason")
    check(identical(ca[joint], cb[joint]) && identical(ja$header_pvalue, jb$header_pvalue),
          "F3 feature ids, baseMean, LRT statistic, P, BH-adjusted P and filter reasons are byte-identical with and without --report-coef")
    check(ja$n_significant == jb$n_significant && ja$n_padj_na == jb$n_padj_na && ja$n_independent_filtered == jb$n_independent_filtered,
          "F3 joint-test counts (significant, padj NA, independently filtered) unchanged")
    check(!identical(ca$log2fc, cb$log2fc) && !identical(ca$log2fc_se, cb$log2fc_se), "F3 the displayed log2fc and its SE do change")
    o3 <- results(wf$dds, name = "strainwt.minute30", alpha = 0.05)
    fb <- utils::read.csv(file.path(f3, "tables", "deseq2_lrt_results_full.csv"), check.names = FALSE)
    assert_all_columns("F3 REPLAY (--report-coef strainwt.minute30 vs workflow code results(name = ))", fb, o3, jb)
  }
}

# ---- A2: secondary pasilla nested-model replay ------------------------------------
# Oracle = DESeq2 vignette code (L1_bioc3.23/DESeq2/vignettes/DESeq2.Rmd):
# loadPasilla :421-433, reorderPasila :459, matrixInput :479-484, prefilter
# :588-592, copyMultifactor :1127-1129, fixLevels :1137, replaceDesign :1150,
# and the LRT form of chunk simpleLRT2 :1677-1680 (`DESeq(dds, test="LRT",
# reduced=~batch)`, eval=FALSE) with `type` as the retained term. Named
# deviations: condition levels in the suite's radix order (treated, untreated)
# instead of the vignette's factorlvl chunk (:611-613), so both fits share one
# parameterization; results(alpha = 0.05), the suite default.
p <- make_pasilla(file.path(tmp, "pasilla"), suite)
a2 <- file.path(tmp, "a2")
r <- run(entry, "--counts", shQuote(p$counts), "--samples", shQuote(p$samples),
         "--full", shQuote("~ type + condition"), "--reduced", shQuote("~ type"), "--min-samples", "3", "--outdir", shQuote(a2))
check(r$status == 0, paste("A2 pasilla nested LRT exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j2 <- jsonlite::fromJSON(file.path(a2, "results", "deseq2_lrt_results.json"))
  check(j2$df == 1 && j2$n_tested == 8148 && identical(j2$tested_terms, "condition"), "A2 pasilla structure: df 1, 8,148 tested, term condition")
  pasCts <- system.file("extdata",
                        "pasilla_gene_counts.tsv.gz",
                        package="DESeq2", mustWork=TRUE)
  pasAnno <- system.file("extdata",
                         "pasilla_sample_annotation.csv",
                         package="DESeq2", mustWork=TRUE)
  cts <- as.matrix(read.csv(pasCts,sep="\t",row.names="gene_id"))
  coldata <- read.csv(pasAnno, row.names=1)
  coldata <- coldata[,c("condition","type")]
  coldata$condition <- factor(coldata$condition)
  coldata$type <- factor(coldata$type)
  rownames(coldata) <- sub("fb", "", rownames(coldata))
  cts <- cts[, rownames(coldata)]
  dds <- DESeqDataSetFromMatrix(countData = cts,
                                colData = coldata,
                                design = ~ condition)
  smallestGroupSize <- 3
  keep <- rowSums(counts(dds) >= 10) >= smallestGroupSize
  dds <- dds[keep,]
  dds$condition <- factor(dds$condition, levels = c("treated","untreated"))   # deviation: suite level order
  ddsMF <- dds
  levels(ddsMF$type) <- sub("-.*", "", levels(ddsMF$type))
  design(ddsMF) <- formula(~ type + condition)
  ddsMF <- suppressMessages(DESeq(ddsMF, test="LRT", reduced=~type))
  res <- results(ddsMF, alpha = 0.05)                                         # deviation: suite alpha
  full2 <- utils::read.csv(file.path(a2, "tables", "deseq2_lrt_results_full.csv"), check.names = FALSE)
  assert_all_columns("A2 REPLAY (pasilla ~ type + condition vs ~ type, 8,148 rows)", full2, res, j2)
}

# Anchor-derived additive design: --group-col must not hide a singleton tested level.
singleton <- read.csv(f$samples,check.names=FALSE)
singleton$tested <- c("singleton",rep("other",nrow(singleton)-1L))
singleton_file <- file.path(tmp,"singleton_samples.csv");write.csv(singleton,singleton_file,row.names=FALSE)
r <- run(entry,"--counts",shQuote(f$counts),"--samples",shQuote(singleton_file),"--full",shQuote("~ tested"),"--reduced",shQuote("~ 1"),"--group-col","strain","--min-samples","3","--outdir",shQuote(file.path(tmp,"singleton-hidden")))
check(r$status != 0 && any(grepl("OS_QC_BLOCKER.*tested level",r$out)),"display group cannot bypass tested-factor replicate guard")

# Typed errors and unavailable optional dependency.
r <- run(entry, "--pattern-clustering", base, "--outdir", shQuote(file.path(tmp, "bad-pattern")))
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER.*pattern-genes", r$out)), "E1 optional patterns require explicit gene selection")
r <- run(entry, "--counts", shQuote(f$counts), "--samples", shQuote(f$samples), "--full", shQuote("~ strain + minute"),
         "--reduced", shQuote("~ strain"), "--outdir", shQuote(file.path(tmp, "bad-filter")))
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER.*min-samples", r$out)), "E2 explicit min-samples required")
r <- run(entry, "--counts", shQuote(f$counts), "--samples", shQuote(f$samples), "--full", shQuote("~ strain + minute"),
         "--reduced", shQuote("~ strain + minute"), "--min-samples", "3", "--group-col", "strain", "--outdir", shQuote(file.path(tmp, "bad-nested")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN", r$out)), "E3 zero-df model pair refused")

# Spec replay compares substantive outputs byte-for-byte.
if (file.exists(file.path(a1, "provenance", "resolved_spec.json"))) {
  replay <- file.path(tmp, "replay")
  r <- run(entry, "--spec", shQuote(file.path(a1, "provenance", "resolved_spec.json")), "--outdir", shQuote(replay))
  check(r$status == 0, "D1 --spec replay exits 0")
  if (r$status == 0) for (rel in c("tables/feature_table.csv", "results/deseq2_lrt_results.json", "figures/top_heatmap.png", "figures/trajectory.png"))
    check(identical(sha(file.path(a1, rel)), sha(file.path(replay, rel))), paste("D1 byte-identical", rel))
}

# Upstream chain and tamper refusal from deseq2-qc.
qc_entry <- file.path(suite, "skills", "deseq2-qc", "scripts", "run_deseq2_qc.R")
qc_run <- file.path(tmp, "qc-upstream")
r <- run(qc_entry, "--counts", shQuote(p$counts), "--samples", shQuote(p$samples), "--outdir", shQuote(qc_run))
check(r$status == 0, "D2 deseq2-qc upstream run exits 0")
if (r$status == 0) {
  lr <- file.path(tmp, "lrt-from-run")
  r2 <- run(entry, "--from-run", shQuote(qc_run), "--full", shQuote("~ type + condition"), "--reduced", shQuote("~ type"),
            "--min-samples", "3", "--outdir", shQuote(lr))
  check(r2$status == 0 && file.exists(file.path(lr, "tables", "feature_table.csv")), "D2 --from-run produces LRT table")
  tamp_parent <- file.path(tmp, "tampered"); dir.create(tamp_parent)
  file.copy(qc_run, tamp_parent, recursive = TRUE)
  tamp <- file.path(tamp_parent, basename(qc_run))
  cat("tamper\n", file = file.path(tamp, "objects", "sample_table.csv"), append = TRUE)
  r3 <- run(entry, "--from-run", shQuote(tamp), "--full", shQuote("~ type + condition"), "--reduced", shQuote("~ type"),
            "--min-samples", "3", "--outdir", shQuote(file.path(tmp, "lrt-tampered")))
  check(r3$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", r3$out)), "D3 tampered upstream refused")
}

# Golden baseline and device leakage.
golden <- c("tables/feature_table.csv", "tables/deseq2_lrt_results_full.csv", "results/deseq2_lrt_results.json",
            "figures/top_heatmap.figure_spec.json", "figures/trajectory.figure_spec.json")
if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) { os_golden_write(module_dir, a1, golden); cat("golden manifest written\n") }
gc <- os_golden_check(module_dir, a1)
if (gc$status == "SKIP") cat("SKIP: golden baseline --", gc$reason, "\n") else check(gc$status == "PASS", paste("G golden baseline", paste(gc$problems, collapse = "; ")))
setwd(old_wd)
check(!file.exists(file.path(tmp, "Rplots.pdf")), "no Rplots.pdf device leak")
if (length(failures)) { cat(length(failures), "check(s) FAILED\n"); quit(status = 1) } else cat("SMOKE PASSED\n")

# Explicit opt-in pattern workflow on the same fission anchor. No default
# selection policy is introduced: this fixture names 60 significant genes.
ft <- utils::read.csv(file.path(a1,"tables","feature_table.csv"))
genes <- head(ft$feature_id[!is.na(ft$padj) & ft$padj < 0.05],60)
pg <- file.path(tmp,"pattern_genes.txt"); writeLines(genes,pg)
po <- file.path(tmp,"pattern_options.json"); jsonlite::write_json(list(minc=3),po,auto_unbox=TRUE)
patdir <- file.path(tmp,"patterns")
r <- run(entry,base,"--pattern-clustering","--pattern-genes",shQuote(pg),"--pattern-options",shQuote(po),"--pattern-group-col","strain","--outdir",shQuote(patdir))
check(r$status==0,paste("P1 explicit DEGreport route",paste(tail(r$out,3),collapse=" | ")))
if(r$status==0) {
 native <- readRDS(file.path(patdir,"objects","patterns.rds"))
 check(is.data.frame(native$df) && nrow(native$df)>0 && all(c("genes","cluster") %in% names(native$df)),"P2 native pattern assignments retained")
 check(identical(digest::digest(file=file.path(a1,"tables","deseq2_lrt_results_full.csv"),algo="sha256"),digest::digest(file=file.path(patdir,"tables","deseq2_lrt_results_full.csv"),algo="sha256")),"P3 opt-in patterns do not change LRT table")
}
if(length(failures)) quit(status=1)
