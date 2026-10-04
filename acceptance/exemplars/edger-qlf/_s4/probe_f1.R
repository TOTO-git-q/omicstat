# S4 F1 probe: guide path (User's Guide 4.4 code) vs frozen suite route, in the locked container.
suppressPackageStartupMessages({library(edgeR); library(limma)})
options(digits = 3)
cat("org.Mm.eg.db available:", requireNamespace("org.Mm.eg.db", quietly = TRUE), "\n")
d <- read.delim("acceptance/data/GSE60450_Lactation-GenewiseCounts.txt.gz", check.names = FALSE)
counts <- as.matrix(d[, -(1:2)]); rownames(counts) <- d$EntrezGeneID; colnames(counts) <- 1:12
targets <- data.frame(GEOAccession = c(paste0("GSM1480", 297:302), paste0("GSM1480", 291:296)),
                      CellType = rep(c("B", "L"), each = 6), Status = rep(rep(c("virgin", "pregnant", "lactate"), each = 2), 2))
# ---- guide path (rendered 2536-2538, 2555-2557, 2566, 2610-2611, 2637, 2649, 2672-2673, 2701)
group <- factor(paste0(targets$CellType, ".", targets$Status))
y <- DGEList(counts, group = group)
colnames(y) <- targets$GEO
keep <- filterByExpr(y); print(summary(keep))
y <- y[keep, , keep.lib.sizes = FALSE]
y <- normLibSizes(y); print(y$samples)
mds <- plotMDS(y, plot = FALSE); cat("MDS var.explained", format(mds$var.explained[1:2], digits = 15), "\n")
design <- model.matrix(~ 0 + group); colnames(design) <- levels(group)
y <- estimateDisp(y, design, robust = TRUE)
print(y$common.dispersion); cat("common.dispersion full", format(y$common.dispersion, digits = 15), "\n")
fit <- glmQLFit(y, design, robust = TRUE)
print(fit$dispersion); cat("fit$dispersion length", length(fit$dispersion), "full", format(fit$dispersion, digits = 15), "\n")
print(head(fit$coefficients))
con <- makeContrasts(B.pregnant - B.lactate, levels = design)
qlf <- glmQLFTest(fit, contrast = con)
print(topTags(qlf)); print(summary(decideTests(qlf)))
tr <- glmTreat(fit, contrast = con, lfc = log2(1.2))
print(topTags(tr)); print(summary(decideTests(tr)))
cat("guide df.prior range", format(range(fit$df.prior), digits = 10), "s2.prior length", length(fit$s2.prior), "\n")
# ---- suite route (engine S1 call set, no estimateDisp before glmQLFit)
y0 <- DGEList(counts, group = group); colnames(y0) <- targets$GEO
y0 <- y0[filterByExpr(y0, design = design), , keep.lib.sizes = FALSE]
y0 <- normLibSizes(y0, method = "TMM")
fit0 <- glmQLFit(y0, design = design, dispersion = NULL, abundance.trend = TRUE, robust = TRUE,
                 winsor.tail.p = c(0.05, 0.1), legacy = FALSE, top.proportion = NULL, keep.unit.mat = FALSE)
qlf0 <- glmQLFTest(fit0, contrast = con, poisson.bound = TRUE); tr0 <- glmTreat(fit0, contrast = con, lfc = log2(1.2), null = "interval")
print(summary(decideTests(qlf0))); print(summary(decideTests(tr0)))
cat("suite fit$dispersion", format(fit0$dispersion, digits = 15), "\n")
cat("max |AveLogCPM guide - suite|", format(max(abs(fit$AveLogCPM - fit0$AveLogCPM)), digits = 10), "\n")
cat("guide cached AveLogCPM == aveLogCPM(y0, dispersion = common)",
    isTRUE(all.equal(fit$AveLogCPM, aveLogCPM(y0, dispersion = y$common.dispersion), tolerance = 0)), "\n")
cat("suite AveLogCPM == aveLogCPM(y0) (default dispersion 0.05)", isTRUE(all.equal(fit0$AveLogCPM, aveLogCPM(y0), tolerance = 0)), "\n")
cat("QLF max |P guide - suite|", format(max(abs(qlf$table$PValue - qlf0$table$PValue)), digits = 10), "\n")
cat("Treat max |P guide - suite|", format(max(abs(tr$table$PValue - tr0$table$PValue)), digits = 10), "\n")
cat("guide vs suite df.prior", format(c(median(fit$df.prior), median(fit0$df.prior)), digits = 10), "\n")
ycache <- y0; ycache$AveLogCPM <- y$AveLogCPM
fitc <- glmQLFit(ycache, design = design, dispersion = NULL, abundance.trend = TRUE, robust = TRUE,
                 winsor.tail.p = c(0.05, 0.1), legacy = FALSE, top.proportion = NULL, keep.unit.mat = FALSE)
cat("cache-only: max |P - guide|", max(abs(glmQLFTest(fitc, contrast = con)$table$PValue - qlf$table$PValue)),
    "fit$dispersion", format(fitc$dispersion, digits = 15), "\n")
fitd <- glmQLFit(y0, design = design, dispersion = fit$dispersion, abundance.trend = TRUE, robust = TRUE,
                 winsor.tail.p = c(0.05, 0.1), legacy = FALSE)
cat("dispersion-only (guide scalar given, suite AveLogCPM): max |P - guide|",
    format(max(abs(glmQLFTest(fitd, contrast = con)$table$PValue - qlf$table$PValue)), digits = 10), "\n")
