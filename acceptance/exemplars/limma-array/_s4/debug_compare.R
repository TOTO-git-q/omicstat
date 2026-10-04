# S4 debug: column-wise differences between the a0 engine feature table and a
# guide-parametrised fit on the same fixture matrix.
suite <- normalizePath(".")
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
d <- file.path(suite, "_smoke", "limma-array-smoke")
mat <- os_read_matrix(file.path(d, "fixture", "matrix.csv"))
bg <- os_read_matrix(file.path(d, "fixture", "background.csv"))
ctrl <- utils::read.csv(file.path(d, "fixture", "controls.csv"), stringsAsFactors = FALSE)$feature_id
st <- utils::read.csv(file.path(d, "fixture", "samples.csv"), stringsAsFactors = FALSE)
keep <- !rownames(mat) %in% ctrl & rowSums(bg > 0) >= 4
Treatment <- factor(st$treatment, levels = c("10 ml/kg saline", "2 ml/kg corn oil", "5 ml/kg corn oil", "10 ml/kg corn oil"))
fit <- limma::eBayes(limma::lmFit(mat[keep, ], model.matrix(~Treatment)), trend = TRUE, robust = TRUE)
tt <- limma::topTable(fit, coef = 4, number = Inf, sort.by = "none")
ft <- utils::read.csv(file.path(d, "a0", "tables", "feature_table.csv"), stringsAsFactors = FALSE)
z <- ft[match(rownames(tt), ft$feature_id), ]
cat("rows", nrow(ft), nrow(tt), "unmatched", sum(is.na(z$feature_id)), "\n")
rel <- function(a, b) max(abs(a - b) / pmax(abs(b), 1e-300))
for (k in list(c("log2fc", "logFC"), c("base_mean", "AveExpr"), c("stat", "t"), c("pvalue", "P.Value"), c("padj", "adj.P.Val")))
  cat(k[1], "max rel diff", rel(z[[k[1]]], tt[[k[2]]]), " all.equal:", format(all.equal(z[[k[1]]], unname(tt[[k[2]]]), tolerance = 1e-10)), "\n")
w <- which.max(abs(z$log2fc - tt$logFC) / abs(tt$logFC)); print(cbind(z[w, c("feature_id", "log2fc")], tt[w, "logFC", drop = FALSE]))
