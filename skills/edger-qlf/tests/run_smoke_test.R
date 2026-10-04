# requires: edgeR limma org.Mm.eg.db digest jsonlite ggplot2 patchwork ragg svglite
# edgeR QLF S2: locked guide anchor, replay, option effects, typed refusals.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
source(file.path(suite, "skills", "_shared", "scripts", "calls_check.R"))
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
source(file.path(suite, "skills", "_shared", "scripts", "handoff.R"))
source(file.path(here, "fixtures", "make_gse60450.R"))
failures <- character(0)
check <- function(cond, msg) { if (isTRUE(cond)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
run <- function(...) {
  o <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(o, "status") %||% 0L, out = o)
}
sha <- function(p) digest::digest(file = p, algo = "sha256")
entry <- file.path(module_dir, "scripts", "run_edger_qlf.R")
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "edger-qlf-smoke")
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
}
f <- make_gse60450(file.path(tmp, "gse60450"), suite)
if (is.null(f)) { setwd(old_wd); cat("SKIP: locked GSE60450 count file is absent\n"); quit(status = 0) }
check(!is.null(f) && identical(f$source_sha256, GSE60450_SHA256), "GSE60450 source SHA256 and shape")
# ---- C-guide: PRINTED anchor on the guide's OWN code path (PACK C; S3 F1).
# Code copied from the locked L1 text acceptance/exemplars/edger-qlf/L1_bioc3.23/
# edgeR/vignettes/edgeRUsersGuide.rendered.txt (manifest sha256 4b1b36fb...),
# section 4.4, cited by rendered line. Deviations, all outside the numbers:
# (i) the guide's featureCounts matrix (rendered:2519-2520) is the locked GEO file
# GSE60450_Lactation-GenewiseCounts.txt.gz (same genes and column order);
# (ii) the targets table is typed in from its printout (rendered:2484-2495);
# (iii) plotMDS gets plot = FALSE and no col/pch (rendered:2585; display only).
# options(digits = 3) reproduces the printed precision of every printout in 4.4
# (e.g. rendered:2639 "[1] 0.0134"); the printed lines are compared as text.
# This is the guide route (estimateDisp BEFORE glmQLFit). The frozen suite route
# (S1 P-1: no estimateDisp before glmQLFit) is checked separately below (C-suite).
guide_txt_path <- file.path(suite, "acceptance", "exemplars", "edger-qlf", "L1_bioc3.23", "edgeR", "vignettes", "edgeRUsersGuide.rendered.txt")
check(identical(sha(guide_txt_path), "4b1b36fbbb895518f0b5348056390590f56c9fc12910975ebd5a686eff330823"), "C-guide L1 rendered guide text matches its manifest SHA256")
guide_txt <- readLines(guide_txt_path, encoding = "UTF-8", warn = FALSE)
gl <- function(from, to) gsub("[[:space:]]+", " ", trimws(guide_txt[from:to]))
pr <- function(x) gsub("[[:space:]]+", " ", trimws(utils::capture.output(print(x))))
op_digits <- options(digits = 3)
G <- local({
  suppressPackageStartupMessages({ library(edgeR); library(limma) })
  gd <- utils::read.delim(file.path(suite, "acceptance", "data", "GSE60450_Lactation-GenewiseCounts.txt.gz"), check.names = FALSE)
  fc <- list(counts = as.matrix(gd[, -(1:2)])); rownames(fc$counts) <- gd$EntrezGeneID
  colnames(fc$counts) <- 1:12                                                        # rendered:2520
  targets <- data.frame(FileName = paste0("SRR", c(1552450:1552455, 1552444:1552449), ".fastq"),
                        GEOAccession = c(paste0("GSM1480", 297:302), paste0("GSM1480", 291:296)),
                        CellType = rep(c("B", "L"), each = 6),
                        Status = rep(rep(c("virgin", "pregnant", "lactate"), each = 2), 2))  # rendered:2484-2495
  group <- factor(paste0(targets$CellType, ".", targets$Status))                     # rendered:2534
  y <- DGEList(fc$counts, group = group)                                             # rendered:2535
  colnames(y) <- targets$GEOAccession                                                # rendered:2536 (targets$GEO)
  suppressPackageStartupMessages(require(org.Mm.eg.db))                              # rendered:2539
  Symbol <- suppressMessages(mapIds(org.Mm.eg.db, keys = rownames(y), keytype = "ENTREZID",
                                    column = "SYMBOL"))                              # rendered:2540-2541
  y$genes <- data.frame(Symbol = Symbol)                                             # rendered:2542
  keep <- filterByExpr(y)                                                            # rendered:2545
  y <- y[keep, , keep.lib.sizes = FALSE]                                             # rendered:2551
  y <- normLibSizes(y)                                                               # rendered:2553
  samples_print <- pr(y$samples)                                                     # rendered:2554
  mds <- plotMDS(y, plot = FALSE)                                                    # rendered:2585
  design <- model.matrix(~ 0 + group)                                                # rendered:2608
  colnames(design) <- levels(group)                                                  # rendered:2609
  y <- estimateDisp(y, design, robust = TRUE)                                        # rendered:2637
  fit <- glmQLFit(y, design, robust = TRUE)                                          # rendered:2648
  con <- makeContrasts(B.pregnant - B.lactate, levels = design)                      # rendered:2670
  qlf <- glmQLFTest(fit, contrast = con)                                             # rendered:2671
  tr <- glmTreat(fit, contrast = con, lfc = log2(1.2))                               # rendered:2708
  list(keep = keep, y = y, samples_print = samples_print, mds = mds, design = design, fit = fit, con = con,
       qlf = qlf, tr = tr, top_qlf = pr(topTags(qlf)), top_tr = pr(topTags(tr)),
       dt_qlf = summary(decideTests(qlf)), dt_tr = summary(decideTests(tr)))
})
check(identical(pr(summary(G$keep)), gl(2549, 2550)), "C-guide printed summary(keep) FALSE 11210 / TRUE 15969 (rendered:2549-2550)")
check(identical(G$samples_print, gl(2555, 2567)), "C-guide printed y$samples lib.size and TMM norm.factors (rendered:2555-2567)")
check(identical(round(100 * G$mds$var.explained[1:2]), c(65, 17)), "C-guide printed MDS axis 'Leading logFC dim 1 (65%)' / 'dim 2 (17%)' (rendered:2589-2590)")
check(identical(pr(G$y$common.dispersion), gl(2639, 2639)) && abs(G$y$common.dispersion - 0.0134413085635106) < 1e-12,
      "C-guide printed y$common.dispersion [1] 0.0134 (rendered:2639); locked value 0.0134413085635106")
check(length(G$fit$dispersion) == 1L && identical(pr(G$fit$dispersion), gl(2650, 2650)) && abs(G$fit$dispersion - 0.0129556217857436) < 1e-12,
      "C-guide printed fit$dispersion [1] 0.013 (rendered:2650): a length-1 NB dispersion from glmQLFit.default (new method), locked value 0.0129556217857436")
check(identical(pr(head(G$fit$coefficients)), gl(2652, 2658)), "C-guide printed head(fit$coefficients) (rendered:2652-2658)")
check(identical(tail(G$top_qlf, 11), gl(2678, 2688)), "C-guide printed topTags(qlf), top gene 211577 Mrgprf -5.15 2.74 473 7.62e-13 1.22e-08 (rendered:2678-2688)")
check(identical(as.numeric(G$dt_qlf), c(2607, 10546, 2816)) && identical(tail(pr(G$dt_qlf), 3), gl(2696, 2698)),
      "C-guide printed summary(decideTests(qlf)) Down 2607 / NotSig 10546 / Up 2816 (rendered:2696-2698)")
check(identical(tail(G$top_tr, 11), gl(2711, 2721)), "C-guide printed topTags(tr) glmTreat lfc = log2(1.2) (rendered:2711-2721)")
check(identical(as.numeric(G$dt_tr), c(1533, 12573, 1863)) && identical(tail(pr(G$dt_tr), 3), gl(2726, 2728)),
      "C-guide printed summary(decideTests(tr)) Down 1533 / NotSig 12573 / Up 1863 (rendered:2726-2728)")
options(op_digits)
base <- c("--counts", shQuote(f$counts), "--samples", shQuote(f$samples), "--reference", "B.lactate", "--target", "B.pregnant")
a1 <- file.path(tmp, "a1")
r <- run(base, "--outdir", shQuote(a1))
check(r$status == 0, paste("A1 locked edgeR QLF run", paste(tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j <- jsonlite::fromJSON(file.path(a1, "results", "edger_qlf_results.json"))
  t <- utils::read.csv(file.path(a1, "tables", "edger_qlf_results_full.csv"), check.names = FALSE)
  ft <- utils::read.csv(file.path(a1, "tables", "feature_table.csv"), check.names = FALSE)
  check(j$n_input_features == 27179 && j$n_tested == 15969 && j$n_filtered_out == 11210, "A1 guide filterByExpr 15969/27179")
  # Frozen suite route (S1 P-1). It differs from the guide route by input, not by
  # edgeR version: see the C-suite checks below and S4_FIXES.md F1.
  check(j$n_down == 2608 && j$n_notsig == 10546 && j$n_up == 2815, "A1 suite-route QLF counts 2608/10546/2815 (guide route prints 2607/10546/2816; C-suite)")
  i <- which(t$feature_id == 211577)
  check(length(i) == 1 && abs(t$logFC[i] + 5.148701616) < 1e-7 && abs(t$F[i] - 473.1673102) < 1e-5 && abs(t$PValue[i] - 7.554955726e-13) < 1e-18,
        "A1 Mrgprf/Entrez 211577 suite-route top row (guide route prints P 7.62e-13; C-suite)")
  check(nrow(ft) == 15969 && !anyDuplicated(ft$feature_id) && all(c("log2fc", "padj") %in% names(ft)), "A1 full canonical feature table")
  # REPLAY anchor of the frozen suite route (S1 P-1 call set, no estimateDisp
  # before glmQLFit) in this R process, independent of the engine code.
  m <- as.matrix(utils::read.table(f$counts, sep = "\t", header = TRUE, row.names = "feature_id", check.names = FALSE))
  cd <- utils::read.csv(f$samples, row.names = "sample")
  lv <- sort(unique(cd$condition), method = "radix")
  mm <- stats::model.matrix(~ 0 + group, data = data.frame(group = factor(cd$condition, levels = lv)))
  con <- rep(0, ncol(mm)); con[which(lv == "B.pregnant")] <- 1; con[which(lv == "B.lactate")] <- -1
  y <- edgeR::DGEList(counts = m, group = cd$condition)
  keep <- edgeR::filterByExpr(y, design = mm, min.count = 10, min.total.count = 15, large.n = 10, min.prop = 0.7)
  check(sum(keep) == 15969 && identical(keep, edgeR::filterByExpr(y)), "A1 design-aware and guide group filtering agree")
  y <- y[keep, , keep.lib.sizes = FALSE]
  y <- edgeR::normLibSizes(y, method = "TMM")
  fit <- edgeR::glmQLFit(y, design = mm, dispersion = NULL, abundance.trend = TRUE, robust = TRUE,
                          winsor.tail.p = c(0.05, 0.1), legacy = FALSE, top.proportion = NULL, keep.unit.mat = FALSE)
  q <- edgeR::glmQLFTest(fit, contrast = con, poisson.bound = TRUE)
  ref <- edgeR::topTags(q, n = Inf, adjust.method = "BH", sort.by = "none", p.value = 1)$table
  ix <- match(as.character(t$feature_id), rownames(ref))
  check(all(!is.na(ix)) && max(abs(t$PValue - ref$PValue[ix])) < 1e-10 && max(abs(t$FDR - ref$FDR[ix])) < 1e-10,
        "A1 independent suite-route QLF replay agrees with the engine over every tested gene")
  # ---- C-suite: exact difference between the guide route (G) and the suite route.
  # glmQLFit.DGEList passes y$AveLogCPM to glmQLFit.default. estimateDisp caches
  # AveLogCPM computed with its common dispersion; without estimateDisp,
  # glmQLFit.DGEList computes aveLogCPM(y) with no dispersion (aveLogCPM default).
  # AveLogCPM selects the genes for the scalar NB dispersion, enters the average
  # QL dispersion and is the covariate of the QL prior trend.
  gi <- match(rownames(ref), rownames(G$qlf$table))
  check(all(!is.na(gi)) && identical(rownames(y), rownames(G$y)), "C-suite guide and suite routes test the same 15969 genes")
  check(abs(max(abs(G$fit$AveLogCPM - fit$AveLogCPM)) - 0.2674049001) < 1e-9,
        "C-suite max |AveLogCPM guide - suite| = 0.2674049001")
  check(isTRUE(all.equal(G$fit$AveLogCPM, edgeR::aveLogCPM(y, dispersion = G$y$common.dispersion), tolerance = 0)) &&
        isTRUE(all.equal(fit$AveLogCPM, edgeR::aveLogCPM(y), tolerance = 0)),
        "C-suite guide AveLogCPM = aveLogCPM(y, dispersion = common.dispersion); suite AveLogCPM = aveLogCPM(y)")
  check(abs(fit$dispersion - 0.0129516892728812) < 1e-12 && abs(max(abs(ref$PValue - G$qlf$table$PValue[gi])) - 0.002497297218) < 1e-9,
        "C-suite suite fit$dispersion 0.0129516892728812 (guide 0.0129556217857436); QLF max |P guide - suite| = 0.002497297218")
  ycache <- y; ycache$AveLogCPM <- G$y$AveLogCPM
  fitc <- edgeR::glmQLFit(ycache, design = mm, dispersion = NULL, abundance.trend = TRUE, robust = TRUE,
                          winsor.tail.p = c(0.05, 0.1), legacy = FALSE, top.proportion = NULL, keep.unit.mat = FALSE)
  qc_cache <- edgeR::glmQLFTest(fitc, contrast = con, poisson.bound = TRUE)
  check(identical(max(abs(qc_cache$table$PValue - G$qlf$table$PValue[gi])), 0) && identical(fitc$dispersion, G$fit$dispersion),
        "C-suite cache probe: suite input + guide AveLogCPM reproduces the guide P values exactly (max diff 0)")
  fitd <- edgeR::glmQLFit(y, design = mm, dispersion = G$fit$dispersion, abundance.trend = TRUE, robust = TRUE,
                          winsor.tail.p = c(0.05, 0.1), legacy = FALSE, top.proportion = NULL, keep.unit.mat = FALSE)
  qd <- edgeR::glmQLFTest(fitd, contrast = con, poisson.bound = TRUE)
  check(max(abs(qd$table$PValue - G$qlf$table$PValue[gi])) > 1e-3,
        "C-suite dispersion-only probe: giving the guide scalar dispersion without its AveLogCPM does not close the gap")
  suite_fit <- fit
  # ---- F2 (PACK F): QL dispersion and sample MDS.
  # QL dispersion table = edgeR::plotQLDisp() return value (x, quarter-root raw)
  # plus s2.post / s2.prior of the independent suite-route fit (REPLAY anchor).
  qd_tab <- utils::read.csv(file.path(a1, "tables", "ql_dispersion.csv"), check.names = FALSE)
  grDevices::pdf(NULL); pq <- edgeR::plotQLDisp(suite_fit); invisible(grDevices::dev.off())
  qi <- match(rownames(suite_fit$coefficients), as.character(qd_tab$feature_id))
  check(nrow(qd_tab) == 15969 && all(!is.na(qi)) && max(abs(qd_tab$ave_logcpm[qi] - pq$x)) < 1e-8 &&
        max(abs(qd_tab$raw[qi]^0.25 - pq$y)) < 1e-8 && max(abs(qd_tab$squeezed[qi] / suite_fit$s2.post - 1)) < 1e-8 &&
        max(abs(qd_tab$trended[qi] / suite_fit$s2.prior - 1)) < 1e-8 && max(abs(qd_tab$df_prior[qi] - suite_fit$df.prior)) < 1e-8,
        "F2 QL dispersion table equals edgeR::plotQLDisp x/y and fit s2.post/s2.prior/df.prior over 15969 genes")
  sp <- jsonlite::fromJSON(file.path(a1, "figures", "ql_dispersion.figure_spec.json"))
  check(grepl("15969 features", sp$caption, fixed = TRUE) && grepl("robust = TRUE", sp$caption, fixed = TRUE) &&
        grepl("Prior df = ", sp$caption, fixed = TRUE) && grepl("12 samples", sp$caption, fixed = TRUE) &&
        grepl(sprintf("%.3g", suite_fit$dispersion), sp$caption, fixed = TRUE),
        "F2 QL dispersion caption states n features, samples, robust, prior df and the NB dispersion")
  # Sample MDS: REPLAY of the guide's own plotMDS(y) (rendered:2585; G above);
  # printed axis percentages 65 % / 17 % (rendered:2589-2590).
  md_tab <- utils::read.csv(file.path(a1, "tables", "mds_coordinates.csv"), check.names = FALSE)
  mi <- match(colnames(G$y), md_tab$sample)
  check(nrow(md_tab) == 12 && all(!is.na(mi)) && max(abs(md_tab$dim1[mi] - G$mds$x)) < 1e-8 && max(abs(md_tab$dim2[mi] - G$mds$y)) < 1e-8,
        "F2 MDS coordinates equal the guide's plotMDS(y) for all 12 samples")
  sp <- jsonlite::fromJSON(file.path(a1, "figures", "mds.figure_spec.json"))
  ve <- unlist(sp$data$var_explained)
  check(length(ve) == 2 && max(abs(ve - G$mds$var.explained[1:2])) < 1e-6 && identical(round(100 * ve), c(65, 17)) &&
        grepl("12 samples", sp$caption, fixed = TRUE) && grepl("top 500 features (of 15969)", sp$caption, fixed = TRUE) &&
        grepl("prior count 2", sp$caption, fixed = TRUE),
        "F2 MDS spec: variance explained 65 %/17 % as printed; caption states n samples, top 500 of 15969, input scale")
  check(all(vapply(c("volcano", "md", "bcv", "ql_dispersion", "mds", "top_heatmap"), function(n) {
    sp <- jsonlite::fromJSON(file.path(a1, "figures", paste0(n, ".figure_spec.json")))
    nzchar(sp$caption) && file.exists(file.path(a1, "figures", paste0(n, ".png"))) && file.exists(file.path(a1, "figures", paste0(n, ".pdf")))
  }, logical(1))), "A1 six figures (volcano, MD, BCV, QL dispersion, MDS, heatmap) have captions, PNG and PDF")
}
a2 <- file.path(tmp, "treat")
r <- run(base, "--treat-fc", "1.2", "--outdir", shQuote(a2))
check(r$status == 0, paste("A2 glmTreat(FC=1.2) run", paste(tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j <- jsonlite::fromJSON(file.path(a2, "results", "edger_qlf_results.json"))
  check(j$n_tested == 15969 && j$n_down == 1535 && j$n_notsig == 12570 && j$n_up == 1864 && j$test == "glmTreat",
        "A2 suite-route glmTreat counts 1535/12570/1864 (guide route prints 1533/12573/1863; C-suite)")
  tt2 <- utils::read.csv(file.path(a2, "tables", "edger_qlf_results_full.csv"), check.names = FALSE)
  if (exists("suite_fit")) {
    tr_suite <- edgeR::glmTreat(suite_fit, coef = NULL, contrast = con, lfc = log2(1.2), null = "interval")
    ix2 <- match(as.character(tt2$feature_id), rownames(tr_suite$table))
    check(all(!is.na(ix2)) && max(abs(tt2$PValue - tr_suite$table$PValue[ix2])) < 1e-10,
          "A2 independent suite-route glmTreat replay agrees with the engine over every tested gene")
    check(abs(max(abs(tr_suite$table$PValue - G$tr$table$PValue[match(rownames(tr_suite$table), rownames(G$tr$table))])) - 0.002447249876) < 1e-9,
          "C-suite glmTreat max |P guide - suite| = 0.002447249876")
  }
  check(abs(j$fc_criterion$min_effect_lfc_threshold - log2(1.2)) < 1e-9 && j$fc_criterion$treat_fc_linear == 1.2,
        "A2 threshold is prespecified linear FC converted to log2")
  check(!identical(sha(file.path(a1, "tables", "feature_table.csv")), sha(file.path(a2, "tables", "feature_table.csv"))), "A2 minimum-effect test changes the full results")
}
a3 <- file.path(tmp, "display")
r <- run(base, "--display-lfc-filter", "1", "--outdir", shQuote(a3))
check(r$status == 0, "F1 display-only filter run")
if (r$status == 0) {
  j <- jsonlite::fromJSON(file.path(a3, "results", "edger_qlf_results.json"))
  disp <- utils::read.csv(file.path(a3, "tables", "display_filtered.csv"))
  check(identical(sha(file.path(a1, "tables", "feature_table.csv")), sha(file.path(a3, "tables", "feature_table.csv"))) && nrow(disp) == j$fc_criterion$n_display_filtered && nrow(disp) < j$n_significant,
        "F1 display threshold changes only display table")
}
a4 <- file.path(tmp, "legacy")
r <- run(base, "--legacy", "--outdir", shQuote(a4))
check(r$status == 0, paste("F2 legacy QL run", paste(tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j <- jsonlite::fromJSON(file.path(a4, "results", "edger_qlf_results.json"))
  check(isTRUE(j$legacy) && !identical(sha(file.path(a1, "tables", "feature_table.csv")), sha(file.path(a4, "tables", "feature_table.csv"))), "F2 legacy flag changes QL result")
  sp <- jsonlite::fromJSON(file.path(a4, "figures", "ql_dispersion.figure_spec.json"))
  check(file.exists(file.path(a4, "figures", "ql_dispersion.png")) && grepl("legacy QL method", sp$caption, fixed = TRUE) &&
        grepl("zero-fit corrected", sp$caption, fixed = TRUE) &&
        !identical(sha(file.path(a1, "tables", "ql_dispersion.csv")), sha(file.path(a4, "tables", "ql_dispersion.csv"))),
        "F2 legacy QL dispersion figure uses the legacy deviance/df and says so")
}
# Replay and handoff use the same anchor to check data provenance.
if (file.exists(file.path(a1, "provenance", "resolved_spec.json"))) {
  a5 <- file.path(tmp, "replay")
  r <- run("--spec", shQuote(file.path(a1, "provenance", "resolved_spec.json")), "--outdir", shQuote(a5))
  check(r$status == 0, "D1 resolved-spec replay")
  if (r$status == 0) for (rel in c("tables/feature_table.csv", "tables/edger_qlf_results_full.csv",
                                   "tables/ql_dispersion.csv", "tables/mds_coordinates.csv",
                                   "figures/volcano.png", "figures/md.png", "figures/bcv.png", "figures/top_heatmap.png",
                                   "figures/ql_dispersion.png", "figures/mds.png",
                                   "figures/volcano.figure_spec.json", "figures/md.figure_spec.json",
                                   "figures/bcv.figure_spec.json", "figures/top_heatmap.figure_spec.json",
                                   "figures/ql_dispersion.figure_spec.json", "figures/mds.figure_spec.json"))
    check(identical(sha(file.path(a1, rel)), sha(file.path(a5, rel))), paste("D1 byte-identical", rel))
}
up <- file.path(tmp, "up"); dir.create(file.path(up, "objects"), recursive = TRUE)
invisible(file.copy(f$counts, file.path(up, "objects", "counts.tsv"))); invisible(file.copy(f$samples, file.path(up, "objects", "samples.csv")))
write_handoff(up, "up", "deseq2-qc", "1.0.1", objects = list(count_matrix = list(path = file.path(up, "objects", "counts.tsv"), type = "count_matrix"), sample_table = list(path = file.path(up, "objects", "samples.csv"), type = "sample_table")))
a6 <- file.path(tmp, "from-run")
r <- run("--from-run", shQuote(up), "--reference", "B.lactate", "--target", "B.pregnant", "--outdir", shQuote(a6))
check(r$status == 0 && identical(sha(file.path(a1, "tables", "feature_table.csv")), sha(file.path(a6, "tables", "feature_table.csv"))), "D2 count-matrix handoff gives identical feature table")
bc <- file.path(tmp, "bc"); dir.create(file.path(bc, "objects"), recursive = TRUE)
invisible(file.copy(f$counts, file.path(bc, "objects", "counts.tsv"))); invisible(file.copy(f$samples, file.path(bc, "objects", "samples.csv")))
write_handoff(bc, "bc", "sva-batch", "1.0.0", objects = list(count_matrix = list(path = file.path(bc, "objects", "counts.tsv"), type = "batch_corrected_matrix"), sample_table = list(path = file.path(bc, "objects", "samples.csv"), type = "sample_table")))
r <- run("--from-run", shQuote(bc), "--reference", "B.lactate", "--target", "B.pregnant", "--outdir", shQuote(file.path(tmp, "bad-bc")))
check(r$status != 0 && any(grepl("OS_BATCH_CORRECTED_INPUT", r$out)), "D3 batch-corrected handoff typed refusal")
cat("tampered\n", file = file.path(up, "objects", "samples.csv"), append = TRUE)
r <- run("--from-run", shQuote(up), "--reference", "B.lactate", "--target", "B.pregnant", "--outdir", shQuote(file.path(tmp, "bad-tamper")))
check(r$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", r$out)), "D4 tampered handoff typed refusal")
for (case in list(
  list(c(base, "--treat-fc", "1", "--outdir", shQuote(file.path(tmp, "bad-fc"))), "OS_INVALID_PARAMETER", "E1 FC=1 refusal"),
  list(c(base, "--referenc", "B.lactate", "--outdir", shQuote(file.path(tmp, "bad-flag"))), "OS_UNKNOWN_FLAG", "E2 unknown flag refusal"),
  list(c("--counts", shQuote(f$counts), "--samples", shQuote(f$samples), "--reference", "missing", "--target", "B.pregnant", "--outdir", shQuote(file.path(tmp, "bad-group"))), "OS_INVALID_PARAMETER", "E3 missing group refusal"),
  list(c(base, "--covariates", "condition", "--outdir", shQuote(file.path(tmp, "bad-design"))), "OS_CONFLICTING_PARAMETERS", "E4 confounded design refusal")
)) {
  r <- run(case[[1]])
  check(r$status != 0 && any(grepl(case[[2]], r$out)), case[[3]])
}
# A non-integer count is caught before fitting.
bad <- utils::read.delim(f$counts, check.names = FALSE)
bad[1, 2] <- 1.5
bad_path <- file.path(tmp, "bad-counts.tsv"); utils::write.table(bad, bad_path, sep = "\t", quote = FALSE, row.names = FALSE)
r <- run("--counts", shQuote(bad_path), "--samples", shQuote(f$samples), "--reference", "B.lactate", "--target", "B.pregnant", "--outdir", shQuote(file.path(tmp, "bad-int")))
check(r$status != 0 && any(grepl("OS_QC_BLOCKER", r$out)), "E5 non-integer counts block fit")
golden <- c("tables/feature_table.csv", "tables/edger_qlf_results_full.csv", "results/edger_qlf_results.json",
            "figures/volcano.figure_spec.json", "figures/md.figure_spec.json", "figures/bcv.figure_spec.json", "figures/top_heatmap.figure_spec.json",
            "figures/ql_dispersion.figure_spec.json", "figures/mds.figure_spec.json", "tables/ql_dispersion.csv", "tables/mds_coordinates.csv")
if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) { os_golden_write(module_dir, a1, golden); cat("golden manifest written\n") }
gc <- os_golden_check(module_dir, a1)
if (gc$status == "SKIP") cat("SKIP: golden baseline --", gc$reason, "\n") else check(gc$status == "PASS", paste("G golden baseline", paste(gc$problems, collapse = ", ")))
check(!file.exists(file.path(tmp, "Rplots.pdf")), "no Rplots.pdf device leak")
setwd(old_wd)
if (length(failures)) { cat("SMOKE FAILED:", paste(failures, collapse = "; "), "\n"); quit(status = 1) } else cat("SMOKE PASSED\n")
