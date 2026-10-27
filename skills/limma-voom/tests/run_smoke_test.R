# requires: edgeR limma ggplot2 ggrepel patchwork ragg jsonlite digest
# Anchor kinds (S4, S3 F1):
#  PRINTED  RNAseq123 workflow (ANCHOR_REGISTRY row 5): the workflow's OWN code (Rmd:<line>)
#           run here on the sha-locked GSE63310 files; asserts the values printed by the
#           Bioconductor 3.23 release build (rendered:<line>; limma 3.68.4 / edgeR 4.10.1).
#  REPLAY   engine vs the workflow chain on the same 9 samples / 27179 genes / design
#           (~ group + lane, Basal vs LP), with exactly two documented interface differences:
#           D1 filterByExpr(x, design = design) (PACK D-V2) instead of group = group (Rmd:193);
#           D2 the Basal - LP coefficient of ~ lane + group is tested directly instead of
#              contrasts.fit (Rmd:351), whose SEs are approximate for a weighted non-orthogonal
#              design (contrasts.fit Rd). Legacy interface = the workflow's voom + lmFit.
#  SUITE    default voomLmFit route (owner-pending call set, S1 P-1): locked replay only.
#  PRINTED  limma User's Guide sec 18.1 Yoruba (row 7b): the guide's own code with the
#           guide-era voom span (adaptive.span = FALSE, limma NEWS 3.66.0); the blocked
#           design belongs to limma-dupcor, whose RNA engine is asserted there. Here the
#           engine's voom step on the guide input is a locked REPLAY of guide:7398.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mod <- dirname(here); suite <- normalizePath(file.path(mod, "..", ".."))
source(file.path(suite, "skills", "_shared", "scripts", "calls_check.R"))
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
source(file.path(suite, "skills", "_shared", "scripts", "handoff.R"))
source(file.path(here, "fixtures", "make_gse63310.R"))
source(file.path(here, "fixtures", "guide_yoruba.R"))
suppressPackageStartupMessages({ library(limma); library(edgeR) })
errors <- character()
check <- function(ok, label) { if (isTRUE(ok)) cat("PASS:", label, "\n") else { cat("FAIL:", label, "\n"); errors <<- c(errors, label) } }
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "limma-voom-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
oldwd <- setwd(tmp)
entry <- file.path(mod, "scripts", "run_limma_voom.R")
run <- function(...) { o <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE)); list(status = attr(o, "status") %||% 0L, out = o) }
sha <- function(p) digest::digest(file = p, algo = "sha256")
same <- function(a, b, tol = 1e-10) isTRUE(all.equal(unname(a), unname(b), tolerance = tol))
reg <- file.path(mod, "scripts", "calls_registry.json")
cc <- check_calls(list.files(file.path(mod, "scripts"), pattern = "[.]R$", full.names = TRUE), reg)
check(cc$ok, paste("registered explicit calls", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(reg)
check(dd$ok, paste("locked function defaults", paste(dd$problems, collapse = "; ")))
for (tool in c("check_defaults.py", "check_flag_docs.py", "lint_r.py")) {
  o <- suppressWarnings(system2("python3", c(shQuote(file.path(suite, "tools", tool)), shQuote(mod)), stdout = TRUE, stderr = TRUE))
  check((attr(o, "status") %||% 0L) == 0L, paste(tool, paste(o, collapse = " | ")))
}
# A printed value string s (as R printed it) matches x at the printed precision.
pmatch1 <- function(x, s) {
  s <- trimws(s)
  if (grepl("e", s)) {
    m <- sub("e.*$", "", s); d <- nchar(gsub("[^0-9]", "", m)); e <- as.integer(sub("^.*e", "", s))
    return(abs(x - as.numeric(s)) <= 0.5 * 10^(e - d + 1) * (1 + 1e-9))
  }
  d <- if (grepl(".", s, fixed = TRUE)) nchar(sub("^.*[.]", "", s)) else 0L
  abs(x - as.numeric(s)) <= 0.5 * 10^(-d) + 1e-12
}
pmatch <- function(x, s) length(x) == length(s) && all(mapply(pmatch1, x, s))
toks <- function(l) strsplit(trimws(sub("^##", "", l)), " +")[[1]]

p <- make_gse63310(file.path(tmp, "fixture"), suite)
if (is.null(p)) cat("SKIP: GSE63310 F4 is absent\n") else {
  ev <- rnaseq123_evidence(suite); R <- ev$rendered; M <- ev$rmd
  out_after <- function(code, n, occ = 1L) { i <- which(R == code); if (length(i) < occ) stop("rendered code line missing: ", code); R[i[occ] + seq_len(n)] }
  # ---- A. PRINTED: the workflow's own code (RNAseq123 Rmd lines cited) ----
  check(identical(M[94], "x <- readDGE(files, columns=c(1,3))") && identical(M[193], "keep.exprs <- filterByExpr(x, group=group)") &&
        identical(M[348], "v <- voom(x, design, plot=TRUE)") && identical(M[373], "tfit <- treat(vfit, lfc=1)"),
        "RNAseq123 source lines cited by this test are the locked Rmd lines")
  x <- p$x; group <- p$group; lane <- p$lane
  check(identical(R[85], "dim(x)") && pmatch(dim(x), toks(R[86])[-1]) && identical(dim(x), c(27179L, 9L)),
        "RNAseq123 printed dim(x) 27179 x 9 (rendered:86)")
  zt <- table(rowSums(x$counts == 0) == 9)                                                  # Rmd:203
  check(identical(as.integer(zt), as.integer(toks(R[which(R == "table(rowSums(x$counts==0)==9)") + 3L]))),
        "RNAseq123 printed all-zero genes FALSE 22026 / TRUE 5153 (rendered:205)")
  keep.exprs <- filterByExpr(x, group = group)                                              # Rmd:193
  xw <- x[keep.exprs, , keep.lib.sizes = FALSE]                                             # Rmd:194
  check(identical(dim(xw), c(16624L, 9L)) && identical(R[212], "## [1] 16624     9"), "RNAseq123 printed dim after filterByExpr 16624 x 9 (rendered:212)")
  xw <- suppressMessages(calcNormFactors(xw, method = "TMM"))                               # Rmd:238
  check(pmatch(xw$samples$norm.factors, toks(R[249])[-1]), "RNAseq123 printed TMM factors 0.894 ... 0.984 (rendered:249)")
  design <- model.matrix(~0 + group + lane)                                                 # Rmd:310
  colnames(design) <- gsub("group", "", colnames(design))                                   # Rmd:311
  contr.matrix <- makeContrasts(BasalvsLP = Basal - LP, BasalvsML = Basal - ML,             # Rmd:322-326
                                LPvsML = LP - ML, levels = colnames(design))
  v <- voom(xw, design, plot = FALSE)                                                       # Rmd:348 (plot=TRUE draws only)
  check(pmatch(v$span, toks(R[416])[-1]), "RNAseq123 printed voom span 0.401 (rendered:416; adaptive span of limma >= 3.66)")
  ie <- which(R == "## $E")[1]
  E_ok <- all(vapply(1:5, function(k) pmatch(v$E[k, ], toks(R[ie + 2L + k])[-1]) && identical(rownames(v$E)[k], toks(R[ie + 2L + k])[1]), TRUE))
  iw <- which(R == "## $weights")[1]
  W_ok <- all(vapply(1:5, function(k) pmatch(v$weights[k, ], toks(R[iw + 1L + k])[-1]), TRUE))
  check(E_ok && W_ok, "RNAseq123 printed voom E and weights, first 5 genes x 9 samples (rendered:377-381, 386-390)")
  vfit <- lmFit(v, design)                                                                  # Rmd:350
  vfit <- contrasts.fit(vfit, contrasts = contr.matrix)                                     # Rmd:351
  efit <- eBayes(vfit)                                                                      # Rmd:352
  dt_e <- summary(decideTests(efit))                                                        # Rmd:367
  pr_e <- out_after("summary(decideTests(efit))", 4)
  check(all(vapply(1:3, function(k) identical(as.integer(dt_e[k, ]), as.integer(toks(pr_e[k + 1L])[-1])), TRUE)),
        "RNAseq123 printed decideTests(efit): Basal-LP 4646/7118/4860, Basal-ML 4936/7008/4680, LP-ML 3141/10953/2530 (rendered:432-435)")
  tfit <- treat(vfit, lfc = 1)                                                              # Rmd:373
  dt <- decideTests(tfit)                                                                   # Rmd:374
  pr_t <- out_after("summary(dt)", 4)
  check(all(vapply(1:3, function(k) identical(as.integer(summary(dt)[k, ]), as.integer(toks(pr_t[k + 1L])[-1])), TRUE)),
        "RNAseq123 printed treat(lfc = 1) decideTests: Basal-LP 1633/12977/2014, Basal-ML 1777/12793/2054, LP-ML 223/16211/190 (rendered:440-443)")
  de.common <- which(dt[, 1] != 0 & dt[, 2] != 0)                                           # Rmd:381
  check(length(de.common) == as.integer(toks(out_after("length(de.common)", 1))[2]), "RNAseq123 printed length(de.common) 2782 (rendered:447)")
  for (cf in 1:2) {
    tt <- topTreat(tfit, coef = cf, n = Inf)                                                # Rmd:393-394
    code <- c("head(basal.vs.lp)", "head(basal.vs.ml)")[cf]
    pr <- out_after(code, 7)[-1]
    ok <- all(vapply(1:6, function(k) {
      tk <- toks(pr[k]); n <- length(tk)
      identical(rownames(tt)[k], tk[1]) && pmatch(unlist(tt[k, c("logFC", "AveExpr", "t", "P.Value", "adj.P.Val")]), tk[(n - 4):n])
    }, TRUE))
    check(ok, sprintf("RNAseq123 printed %s: IDs, logFC, AveExpr, t, P, adj.P (rendered:%d-%d)", code, which(R == code) + 2L, which(R == code) + 7L))
  }
  # ---- B. REPLAY: engine (legacy = voom + lmFit) vs the workflow chain with D1 + D2 ----
  base <- c("--counts", shQuote(p$counts), "--samples", shQuote(p$samples), "--condition", "group",
            "--reference", "LP", "--target", "Basal", "--covariates", "lane")
  al <- file.path(tmp, "legacy"); rl <- run(base, "--interface", "legacy", "--outdir", shQuote(al))
  check(rl$status == 0, paste("legacy engine run on the RNAseq123 design", paste(utils::tail(rl$out, 2), collapse = " | ")))
  st <- data.frame(group = factor(as.character(group), levels = c("LP", "Basal", "ML")), lane = factor(as.character(lane)))
  design_s <- model.matrix(~ lane + group, data = st)                                      # suite parameterisation (D2)
  xr <- x[filterByExpr(x, design = design_s), , keep.lib.sizes = FALSE]                    # D1 (design leverage)
  xr <- suppressMessages(calcNormFactors(xr, method = "TMM"))
  vr <- voom(xr, design_s, plot = FALSE, save.plot = TRUE)
  fr <- lmFit(vr, design_s)
  er <- eBayes(fr)
  ttr <- topTable(er, coef = "groupBasal", number = Inf, sort.by = "none")
  if (rl$status == 0) {
    lf <- utils::read.csv(file.path(al, "tables", "limma_full.csv"), row.names = 1, check.names = FALSE)
    m <- match(rownames(ttr), rownames(lf))
    check(nrow(lf) == nrow(ttr) && !anyNA(m) && nrow(lf) == 17062L, sprintf("replay: engine tests the same %d genes (filterByExpr with the design keeps 17062 of 27179)", nrow(ttr)))
    if (!anyNA(m)) {
      lf <- lf[m, ]
      check(same(lf$logFC, ttr$logFC) && same(lf$AveExpr, ttr$AveExpr) && same(lf$t, ttr$t) &&
            same(lf$P.Value, ttr$P.Value) && same(lf$adj.P.Val, ttr$adj.P.Val) && same(lf$B, ttr$B),
            "replay: legacy engine logFC/AveExpr/t/P/BH/B equal the workflow chain (D1, D2) for all genes")
    }
    ds <- utils::read.csv(file.path(al, "tables", "direction_summary.csv"))
    dr <- summary(decideTests(er))[, "groupBasal"]
    check(identical(as.integer(unlist(ds[1, c("Down", "NotSig", "Up")])), as.integer(dr)),
          sprintf("replay: engine direction summary %s equals decideTests of the replay", paste(unlist(ds[1, c("Down", "NotSig", "Up")]), collapse = "/")))
    cat(sprintf("NOTE: printed Basal-LP 4646/7118/4860 (workflow filter by group, contrasts.fit) vs engine legacy %s (D1 17062 genes, D2 exact coefficient SE).\n",
                paste(unlist(ds[1, c("Down", "NotSig", "Up")]), collapse = "/")))
    mc <- utils::read.csv(file.path(al, "tables", "mds_coordinates.csv"))
    lcpm <- cpm(xr, log = TRUE)                                                             # Rmd:280 (on the D1 set)
    mr <- plotMDS(lcpm, labels = group, plot = FALSE)                                       # Rmd:285 (plot=FALSE)
    check(identical(mc$sample, colnames(xr)) && same(mc$dim1, mr$x) && same(mc$dim2, mr$y),
          "replay: MDS coordinates equal the workflow's plotMDS(lcpm) (Rmd:280, :285) on the engine's gene set")
    vt <- utils::read.csv(file.path(al, "tables", "voom_trend_points.csv"))
    check(same(vt$log2_count_size, vr$voom.xy$x) && same(vt$sqrt_sd, vr$voom.xy$y), "replay: voom trend points equal voom(save.plot = TRUE)$voom.xy")
    jl <- jsonlite::fromJSON(file.path(al, "results", "limma_results.json"))
    # results JSON stores 10 significant digits
    check(same(jl$details$span, vr$span, 1e-9) && same(unlist(jl$details$norm_factors), xr$samples$norm.factors, 1e-9),
          sprintf("replay: reported span %.7f and the 9 TMM factors equal the replay (10 significant digits)", jl$details$span))
    txt <- paste(readLines(file.path(al, "draft", "methods_results.md")), collapse = " ")
    thr_cut <- 10 / median(x$samples$lib.size) * 1e6; thr_n <- 1 / max(hat(design_s))
    check(grepl(sprintf("edgeR (v%s)", packageVersion("edgeR")), txt, fixed = TRUE) &&
          grepl("17062 of 27179 genes were retained", txt, fixed = TRUE) &&
          grepl(sprintf("at least %s counts per million", trimws(formatC(thr_cut, digits = 3, format = "g"))), txt, fixed = TRUE) &&
          grepl(sprintf("in at least %s samples", trimws(formatC(thr_n, digits = 4, format = "g"))), txt, fixed = TRUE) &&
          grepl("limma voom (normalize.method = \"none\")", txt, fixed = TRUE) &&
          grepl(sprintf("span = %s for 17062 genes", formatC(vr$span, digits = 4, format = "f")), txt, fixed = TRUE) &&
          grepl(sprintf("prior df = %s", trimws(formatC(er$df.prior, digits = 4, format = "g"))), txt, fixed = TRUE) &&
          grepl("Sample quality weights were not used.", txt, fixed = TRUE) &&
          grepl("zero log2 fold change", txt, fixed = TRUE),
          "Methods (legacy): edgeR version, filterByExpr thresholds actually used, voom + adaptive span, eBayes prior df, no weights")
    # the reported filter thresholds reproduce filterByExpr's own keep vector
    cpm_raw <- cpm(p$matrix, lib.size = colSums(p$matrix))
    check(sum(rowSums(cpm_raw >= thr_cut) >= thr_n - 1e-14 & rowSums(p$matrix) >= 15 - 1e-14) == 17062L,
          "reported CPM cutoff and minimum sample size reproduce the 17062 retained genes")
  }
  at <- file.path(tmp, "treat"); rt <- run(base, "--interface", "legacy", "--min-effect-fc", "2", "--outdir", shQuote(at))
  check(rt$status == 0, "treat run (fc = 2, i.e. the workflow's lfc = 1)")
  if (rt$status == 0) {
    trr <- topTreat(treat(fr, lfc = 1), coef = "groupBasal", n = Inf, sort.by = "none")    # Rmd:373 on the D1/D2 fit
    lt <- utils::read.csv(file.path(at, "tables", "limma_full.csv"), row.names = 1, check.names = FALSE)[rownames(trr), ]
    check(same(lt$t, trr$t) && same(lt$P.Value, trr$P.Value) && same(lt$adj.P.Val, trr$adj.P.Val) && is.null(lt$B),
          "replay: engine treat(fc = 2, lfc = log2(2)) t/P/BH equal treat(fit, lfc = 1); no B column")
    txt <- paste(readLines(file.path(at, "draft", "methods_results.md")), collapse = " ")
    check(grepl("limma treat (fc = 2, lfc = log2(fc) = 1.0000", txt, fixed = TRUE) && grepl("|log2 fold change| <= 1.0000", txt, fixed = TRUE),
          "Methods (treat): fc, lfc = log2(fc) and the interval null reported")
    rl_tr <- jsonlite::fromJSON(file.path(at, "objects", "ranked_list.meta.json"))
    check(identical(rl_tr$statistic, "treat_moderated_t"), "treat hand-off ranked list is labelled as the treat statistic")
  }
  # ---- C. SUITE route (default voomLmFit; call set owner-pending, S1 P-1) ----
  a0 <- file.path(tmp, "a0"); r <- run(base, "--outdir", shQuote(a0))
  check(r$status == 0, paste("default voomLmFit run", paste(utils::tail(r$out, 2), collapse = " | ")))
  if (r$status == 0) {
    vf <- voomLmFit(xr, design = design_s, sample.weights = FALSE, keep.EList = TRUE)
    vf <- eBayes(vf)
    tv <- topTable(vf, coef = "groupBasal", number = Inf, sort.by = "none")
    l0 <- utils::read.csv(file.path(a0, "tables", "limma_full.csv"), row.names = 1, check.names = FALSE)[rownames(tv), ]
    check(same(l0$P.Value, tv$P.Value) && same(l0$adj.P.Val, tv$adj.P.Val) && same(l0$logFC, tv$logFC),
          "suite replay: default engine equals voomLmFit(defaults) + eBayes on the same filtered TMM DGEList")
    j0 <- jsonlite::fromJSON(file.path(a0, "results", "limma_results.json"))
    check(same(j0$details$span, vr$span, 1e-9), "voomLmFit reported span equals the span voom chooses for the same genes")
    txt <- paste(readLines(file.path(a0, "draft", "methods_results.md")), collapse = " ")
    check(grepl("edgeR voomLmFit (block = NULL, prior.weights = NULL, prior.n = 10", txt, fixed = TRUE) &&
          grepl("adaptive.span = TRUE", txt, fixed = TRUE) && grepl("Sample quality weights were not used.", txt, fixed = TRUE) &&
          grepl(sprintf("prior df = %s", trimws(formatC(vf$df.prior, digits = 4, format = "g"))), txt, fixed = TRUE) &&
          grepl("## Figure legends", txt, fixed = TRUE),
          "Methods (default): voomLmFit settings, adaptive span, eBayes prior df, figure legends")
    check(inherits(readRDS(file.path(a0, "objects", "fit.rds")), "MArrayLM") && inherits(readRDS(file.path(a0, "objects", "elist.rds")), "EList"),
          "fit and EList output contract")
    for (f in c("volcano", "md", "voom_trend", "mds")) {
      sp <- jsonlite::fromJSON(file.path(a0, "figures", paste0(f, ".figure_spec.json")))
      check(file.exists(file.path(a0, "figures", paste0(f, ".png"))) && nzchar(sp$caption %||% ""), paste(f, "figure PNG and caption"))
    }
    cap <- function(f) jsonlite::fromJSON(file.path(a0, "figures", paste0(f, ".figure_spec.json")))$caption
    check(grepl("adjusted_p < 0.05", cap("volcano"), fixed = TRUE) && grepl(sprintf("span = %s", format(j0$details$span)), cap("voom_trend"), fixed = TRUE) &&
          grepl(sprintf("one of %d features", nrow(utils::read.csv(file.path(a0, "tables", "voom_trend_points.csv")))), cap("voom_trend"), fixed = TRUE) && grepl("9 samples", cap("mds")) && grepl("top 500 features (of 17062)", cap("mds"), fixed = TRUE) &&
          grepl("log2 CPM (prior count 2)", cap("mds"), fixed = TRUE),
          "figure captions state thresholds, n, span and MDS input scale")
    a1 <- file.path(tmp, "a1"); r1 <- run("--spec", shQuote(file.path(a0, "provenance", "resolved_spec.json")), "--outdir", shQuote(a1))
    check(r1$status == 0, "--spec replay")
    if (r1$status == 0) for (f in c("tables/feature_table.csv", "tables/limma_full.csv", "tables/mds_coordinates.csv", "figures/volcano.png", "figures/md.png",
                                    "figures/voom_trend.png", "figures/mds.png", "figures/volcano.figure_spec.json", "figures/md.figure_spec.json"))
      check(sha(file.path(a0, f)) == sha(file.path(a1, f)), paste("byte-identical replay", f))
    ad <- file.path(tmp, "display"); rd <- run(base, "--display-lfc-filter", "1", "--outdir", shQuote(ad))
    check(rd$status == 0 && sha(file.path(a0, "tables", "feature_table.csv")) == sha(file.path(ad, "tables", "feature_table.csv")) &&
          file.exists(file.path(ad, "tables", "display_filtered.csv")), "display filter does not change inferential table")
    aw <- file.path(tmp, "weighted"); rw <- run(base, "--sample-weights", "--outdir", shQuote(aw))
    check(rw$status == 0, "sample quality weight fit (voomLmFit)")
    if (rw$status == 0) {
      jw <- jsonlite::fromJSON(file.path(aw, "results", "limma_results.json"))
      sw <- unlist(jw$details$sample_weight_values)
      vw <- voomLmFit(xr, design = design_s, sample.weights = TRUE, keep.EList = TRUE)
      check(identical(names(sw), colnames(x)) && same(sw, vw$targets$sample.weight) && isTRUE(jw$details$sample_weights),
            "sample weights: engine estimates equal voomLmFit(sample.weights = TRUE), named per sample")
      txt <- paste(readLines(file.path(aw, "draft", "methods_results.md")), collapse = " ")
      check(grepl("Sample quality weights were estimated (user-enabled; var.design = NULL, var.group = NULL)", txt, fixed = TRUE) &&
            grepl(sprintf("JMS8-2 %s", formatC(sw[["JMS8-2"]], digits = 3, format = "f")), txt, fixed = TRUE),
            "Methods (sample weights, voomLmFit): settings and every estimated weight reported")
    }
    alw <- file.path(tmp, "legacy_weighted"); rlw <- run(base, "--interface", "legacy", "--sample-weights", "--outdir", shQuote(alw))
    check(rlw$status == 0, "sample quality weight fit (legacy voomWithQualityWeights)")
    if (rlw$status == 0) {
      jq <- jsonlite::fromJSON(file.path(alw, "results", "limma_results.json"))
      vq <- voomWithQualityWeights(xr, design_s, plot = FALSE)
      fq <- eBayes(lmFit(vq, design_s)); tq <- topTable(fq, coef = "groupBasal", number = Inf, sort.by = "none")
      lq <- utils::read.csv(file.path(alw, "tables", "limma_full.csv"), row.names = 1, check.names = FALSE)[rownames(tq), ]
      check(same(unlist(jq$details$sample_weight_values), vq$targets$sample.weight) && same(lq$P.Value, tq$P.Value),
            "legacy sample weights: estimates and P values equal voomWithQualityWeights + lmFit + eBayes")
      txt <- paste(readLines(file.path(alw, "draft", "methods_results.md")), collapse = " ")
      check(grepl("limma voomWithQualityWeights", txt, fixed = TRUE) && grepl("method = \"genebygene\", maxiter = 50, tol = 1e-5", txt, fixed = TRUE),
            "Methods (legacy sample weights): voomWithQualityWeights settings reported")
      check(file.exists(file.path(alw, "figures", "voom_trend.png")), "legacy sample-weights run draws the voom trend")
    }
    err <- run(base, "--min-cunt", "10", "--outdir", shQuote(file.path(tmp, "error")))
    check(err$status != 0 && any(grepl("OS_UNKNOWN_FLAG", err$out)), "typed unknown flag")
    upstream <- file.path(tmp, "upstream"); dir.create(file.path(upstream, "objects"), recursive = TRUE)
    file.copy(p$counts, file.path(upstream, "objects", "counts.csv")); file.copy(p$samples, file.path(upstream, "objects", "samples.csv"))
    write_handoff(upstream, "upstream", "deseq2-qc", "1.0.0", objects = list(count_matrix = list(path = file.path(upstream, "objects", "counts.csv"), type = "count_matrix"),
                                                                          sample_table = list(path = file.path(upstream, "objects", "samples.csv"), type = "sample_table")))
    chain <- c("--condition", "group", "--reference", "LP", "--target", "Basal", "--covariates", "lane")
    hu <- run("--from-run", shQuote(upstream), chain, "--outdir", shQuote(file.path(tmp, "chained")))
    check(hu$status == 0 && sha(file.path(a0, "tables", "feature_table.csv")) == sha(file.path(tmp, "chained", "tables", "feature_table.csv")), "verified from-run chain")
    cat("tamper\n", file = file.path(upstream, "objects", "counts.csv"), append = TRUE)
    ht <- run("--from-run", shQuote(upstream), chain, "--outdir", shQuote(file.path(tmp, "tampered")))
    check(ht$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", ht$out)), "tampered chain refused")
    golden <- c("tables/feature_table.csv", "tables/limma_full.csv", "tables/direction_summary.csv", "tables/mds_coordinates.csv",
                "tables/voom_trend_points.csv", "results/limma_results.json", "figures/volcano.figure_spec.json",
                "figures/md.figure_spec.json", "figures/voom_trend.figure_spec.json", "figures/mds.figure_spec.json",
                "draft/methods_results.md")
    if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) os_golden_write(mod, a0, golden)
    gc <- os_golden_check(mod, a0)
    if (gc$status == "SKIP") cat("SKIP: golden --", gc$reason, "\n") else check(gc$status == "PASS", "container golden")
  }
}
# ---- D. Yoruba (User's Guide sec 18.1, row 7b) ----
g <- yoruba_guide_lines(suite, "limma-voom")
inp <- yoruba_guide_inputs(suite, g)
if (is.null(inp)) cat("SKIP: Yoruba F10 absent\n") else {
  pr <- yoruba_guide_printed(g)
  check(identical(dim(inp$y), c(16918L, 86L)), "Yoruba PRINTED: 16918 genes x 86 libraries after the guide filter (guide:7210)")
  gf <- yoruba_guide_fit(inp, adaptive.span = FALSE)
  check(length(pr$consensus) == 2L && round(gf$cor1, 3) == pr$consensus[1] && round(gf$cor2, 3) == pr$consensus[2],
        sprintf("Yoruba PRINTED (guide code, adaptive.span = FALSE): consensus %.7f / %.7f print as 0.446 / 0.446 (guide:7402, :7410)", gf$cor1, gf$cor2))
  check(all(unclass(gf$dt) == pr$dt) && identical(colnames(gf$dt), colnames(pr$dt)),
        "Yoruba PRINTED: summary(decideTests(fit)) for all four coefficients, genderMale 27/16869/22 (guide:7418-7421)")
  cmp <- yoruba_compare_printed_tt(gf$tt, pr$tt)
  check(nrow(pr$tt) == 49L && all(cmp), sprintf("Yoruba PRINTED: all 49 topTable rows, IDs/symbols/logFC/AveExpr/t/P/adj.P/B (guide:7423-7473) [%s]",
                                                paste(names(cmp)[!cmp], collapse = ",")))
  # Engine REPLAY of guide:7398 voom(y, design) under the suite span (locked default TRUE):
  # the guide-filtered counts (guide:7204-7208) enter the engine; --min-count 0 makes the
  # engine's filterByExpr retain every gene, so both see the same 16918 x 86 input and TMM.
  yd <- file.path(tmp, "yoruba_in"); dir.create(yd)
  cm <- inp$counts_filtered; storage.mode(cm) <- "integer"
  utils::write.csv(data.frame(feature_id = rownames(cm), cm, check.names = FALSE), file.path(yd, "counts.csv"), row.names = FALSE)
  utils::write.csv(data.frame(sample = inp$Targets$individual, gender = inp$Targets$gender, concentration = paste0("c", inp$Targets$concentration)),
                   file.path(yd, "samples.csv"), row.names = FALSE)
  ay <- file.path(tmp, "yoruba"); ry <- run("--counts", shQuote(file.path(yd, "counts.csv")), "--samples", shQuote(file.path(yd, "samples.csv")),
                                            "--condition", "gender", "--reference", "Female", "--target", "Male", "--covariates", "concentration",
                                            "--interface", "legacy", "--min-count", "0", "--outdir", shQuote(ay))
  check(ry$status == 0, paste("Yoruba engine run (legacy voom)", paste(utils::tail(ry$out, 2), collapse = " | ")))
  if (ry$status == 0) {
    el <- readRDS(file.path(ay, "objects", "elist.rds"))
    v1 <- voom(inp$y, gf$design, adaptive.span = TRUE)                                        # guide:7398, locked default span
    check(nrow(el$E) == 16918L && identical(rownames(el$E), rownames(v1$E)) && same(el$E, v1$E) && same(el$weights, v1$weights) && same(el$span, v1$span),
          sprintf("Yoruba REPLAY: engine voom E, weights and span (%.6f) equal guide:7398 voom(y, design) with the locked adaptive span", el$span))
    cat("NOTE: the guide's blocked fit (duplicateCorrelation, guide:7400-7422) is outside limma-voom; limma-dupcor's RNA engine asserts it.\n")
  }
}
setwd(oldwd)
check(!file.exists(file.path(tmp, "Rplots.pdf")), "no Rplots.pdf")
if (length(errors)) { cat(length(errors), "checks FAILED\n"); quit(status = 1) } else cat("SMOKE PASSED\n")
