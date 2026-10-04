# S4 probe 1 (run from suite root): GSVA filtered set API, real limma-voom / limma-dupcor hand-offs, barcodeplot worm.
suite <- normalizePath(".")
shared <- file.path(suite, "skills", "_shared", "scripts")
for (f in c("args.R", "module_kit.R", "handoff.R", "enrich_rank_io.R", "ranked_list.R", "limma_io.R")) source(file.path(shared, f))
cat("== GSVA API ==\n")
set.seed(1)
m <- matrix(rnorm(40 * 12), 40, 12, dimnames = list(paste0("g", 1:40), paste0("s", 1:12)))
m[1:10, ] <- 1
sets <- list(constant = paste0("g", 1:10), variable1 = paste0("g", 11:30), variable2 = paste0("g", 31:40),
             partial = c(paste0("g", 5:9), paste0("g", 21:24)), none = c("zz1", "zz2"))
p <- GSVA::gsvaParam(exprData = m, geneSets = sets, minSize = 5, maxSize = 500, kcdf = "auto", maxDiff = TRUE)
print(try(GSVA::geneSetSizes(p)))
es <- GSVA::gsva(p, verbose = FALSE)
print(names(attributes(es)))
print(GSVA::geneSetSizes(es)); print(GSVA::geneSets(es))
print(showMethods("geneSetSizes"))
print(body(GSVA:::.filterGenes))
cat("== barcodeplot worm ==\n")
b <- deparse(limma::barcodeplot)
print(grep("tricube|worm|ave.enrich|span", b, value = TRUE))
cat("== Yoruba limma-voom / dupcor ==\n")
env <- new.env(); load(file.path(suite, "acceptance", "data", "limma_Yoruba.RData"), envir = env)
y <- env$y
print(names(y)); print(head(y$genes)); print(head(y$samples))
keep <- rowSums(y$counts) > 50 & rowSums(is.na(y$genes)) == 0
y <- y[keep, , keep.lib.sizes = FALSE]
guide <- file.path(suite, "acceptance", "exemplars", "limma-camera", "L1_bioc3.23", "limma", "vignettes", "usersguide.rendered.txt")
x <- readLines(guide, warn = FALSE); fields <- strsplit(trimws(grep("^[0-9]+ argonne ", x, value = TRUE)), "[[:space:]]+")
st <- data.frame(sample = vapply(fields, `[[`, "", 5L), concentration = vapply(fields, `[[`, "", 6L),
                 cellline = vapply(fields, `[[`, "", 7L), gender = vapply(fields, `[[`, "", 8L))
wd <- file.path(suite, "_s4", "probe1"); unlink(wd, recursive = TRUE); dir.create(wd, recursive = TRUE)
cnt <- y$counts; rownames(cnt) <- as.character(y$genes$GeneID)
utils::write.csv(data.frame(feature_id = rownames(cnt), cnt, check.names = FALSE), file.path(wd, "counts.csv"), row.names = FALSE)
utils::write.csv(st, file.path(wd, "samples.csv"), row.names = FALSE)
rs <- file.path(R.home("bin"), "Rscript")
t0 <- Sys.time()
o <- system2(rs, c(file.path(suite, "skills/limma-voom/scripts/run_limma_voom.R"), "--counts", file.path(wd, "counts.csv"),
                   "--samples", file.path(wd, "samples.csv"), "--condition", "gender", "--reference", "Female", "--target", "Male",
                   "--covariates", "concentration", "--outdir", file.path(wd, "voom")), stdout = TRUE, stderr = TRUE)
print(tail(o, 5)); print(Sys.time() - t0)
up <- read_handoff(file.path(wd, "voom"))
print(names(up$objects)); str(up$state, max.level = 2)
h <- os_limma_handoff_read(up)
str(h[setdiff(names(h), c("E", "weights", "samples"))])
print(dim(h$E)); print(dim(h$weights)); print(head(h$samples))
t0 <- Sys.time()
o <- system2(rs, c(file.path(suite, "skills/limma-dupcor/scripts/run_limma_dupcor.R"), "--mode", "rna", "--counts", file.path(wd, "counts.csv"),
                   "--samples", file.path(wd, "samples.csv"), "--condition", "gender", "--reference", "Female", "--target", "Male",
                   "--covariates", "concentration", "--block", "cellline", "--block-description", shQuote("cell line of the individual"),
                   "--outdir", file.path(wd, "dupcor")), stdout = TRUE, stderr = TRUE)
print(tail(o, 5)); print(Sys.time() - t0)
up2 <- read_handoff(file.path(wd, "dupcor"))
print(names(up2$objects)); str(up2$state, max.level = 2)
h2 <- os_limma_handoff_read(up2)
str(h2[setdiff(names(h2), c("E", "weights", "samples"))])
print(dim(h2$E)); print(is.null(h2$weights))
