# S4 probe: limma User's Guide sec 17.3 (Illumina) printed values with the guide's own code
# (guide:6435-6552) on the hash-locked F7-F9 files. Run from the suite root.
suppressPackageStartupMessages(library(limma))
source("skills/limma-dupcor/tests/fixtures/make_illumina.R")
p <- make_illumina(file.path(tempdir(), "ilmn"), normalizePath("."))
y <- p$y; targets <- p$targets
print(dim(y))
ct <- factor(targets$CellType)                                        # guide:6521
design <- model.matrix(~0+ct)
colnames(design) <- levels(ct)
dupcor <- duplicateCorrelation(y,design,block=targets$Donor)
print(dupcor$consensus.correlation, digits = 10)
fit <- lmFit(y,design,block=targets$Donor,correlation=dupcor$consensus.correlation)
contrasts <- makeContrasts(ML-MS, LP-MS, ML-LP, levels=design)
fit2 <- contrasts.fit(fit, contrasts)
fit2 <- eBayes(fit2, trend=TRUE)
print(summary(decideTests(fit2, method="global")))
print(topTable(fit2, coef=1), digits = 3)
cat("limma", as.character(packageVersion("limma")), "\n")
tt <- topTable(fit2, coef=1)
print(format(tt$P.Value, digits = 10)); print(format(tt$adj.P.Val, digits = 10))
