# limma User's Guide 17.4 (single-channel Agilent case study, GSE33005 =
# E-GEOD-33005) replayed with the guide's OWN code, and the printed values it
# shows. Guide text: acceptance/exemplars/limma-array/L1_bioc3.23/limma/
# vignettes/usersguide.rendered.txt (limma 3.68.5, Bioconductor 3.23); every
# step cites its line there as ":<line>". Test-side only: the engine never
# sources this file, and this file never calls engine or shared helpers.
#
# The only departure from the guide text is the file names: the sha-locked
# GEO RAW tar (ANCHOR_REGISTRY row 6, F5) ships the same Agilent files
# gzip-compressed, so SDRF[,"Array Data File"] gets the ".gz" suffix.
# Step 17.4.4 (annotation) needs RnAgilentDesign028282.db (+ org.Rn.eg.db);
# callers put the library holding them on .libPaths() and pass annotate = TRUE.

GSE33005_SHA <- c(raw = "3d094f4dc7a771d54d9efff7c67c12dcbdf06e036220132719515ab246e70d92",
                  sdrf = "a2e13071c73023ed6b4762d003f2748df97016c184235d22c7b2316838e1fb25")

# Printed values (usersguide.rendered.txt).
G174_PRINTED <- list(
  dim_x = c(44254L, 19L),                                            # :6680-6681
  genes_201_205 = data.frame(                                        # :6690-6696
    spot = 201:205, Row = c(3L, 3L, 3L, 3L, 3L), Col = 34:38, ControlType = 0L,
    ProbeName = c("A_42_P642757", "A_64_P066694", "A_42_P699201", "A_42_P591944", "A_44_P115293"),
    SystematicName = c("NM_031235", "A_64_P066694", "XM_227798", "NM_172093", "NM_001108294"),
    EntrezID = c("81918", NA, "295538", "94164", "360611"),
    Symbol = c("Pard3", NA, "Depdc1", "Hbg1", "Copz2"), stringsAsFactors = FALSE),
  dim_yfilt = c(27024L, 19L),                                        # :6731-6732
  head_yfilt = data.frame(                                           # :6735-6742
    spot = c(13L, 14L, 15L, 18L, 19L, 20L),
    ProbeName = c("A_64_P002176", "A_42_P664913", "A_43_P13320", "A_43_P11804", "A_44_P808710", "A_64_P142111"),
    Symbol = c("Wdfy3", "Ankrd37", "Ifng", "Ptn", "Rd3", "Gxylt1"),
    EntrezID = c("305164", "361149", "25712", "24924", "684158", "300173"), stringsAsFactors = FALSE),
  decide = matrix(c(0L, 27024L, 0L, 0L, 27024L, 0L, 756L, 24734L, 1534L), nrow = 3,  # :6749-6753
                  dimnames = list(c("Down", "NotSig", "Up"),
                                  c("Treatment2 ml/kg corn oil", "Treatment5 ml/kg corn oil", "Treatment10 ml/kg corn oil"))),
  top20 = utils::read.table(header = TRUE, stringsAsFactors = FALSE, colClasses = c(spot = "integer", EntrezID = "character"), text = "
spot ProbeName Symbol EntrezID logFC AveExpr t P.Value adj.P.Val B
28763 A_44_P552452 RT1-Bb 309622 9.33 8.78 45.3 1.68e-21 4.55e-17 32.4
9680 A_44_P991565 Bad 64639 3.73 7.91 39.1 2.03e-20 2.74e-16 31.5
42069 A_64_P160096 Mei1 315162 3.84 7.67 32.6 7.49e-19 6.74e-15 29.5
12513 A_42_P638620 Lcn2 170496 3.83 8.09 32.1 1.01e-18 6.84e-15 29.3
6942 A_42_P667782 Fastkd2 301463 -1.70 12.44 -24.4 2.08e-16 1.12e-12 25.7
4631 A_64_P006625 RT1-A 100188935 2.65 13.17 24.1 2.61e-16 1.17e-12 25.6
40353 A_64_P149280 Vegfb 89811 -3.26 8.69 -21.2 3.31e-15 1.28e-11 23.6
655 A_42_P667782 Fastkd2 301463 -1.44 12.13 -20.5 6.40e-15 2.16e-11 23.1
23459 A_42_P667782 Fastkd2 301463 -1.64 12.53 -20.3 7.21e-15 2.16e-11 23.0
22161 A_64_P154811 Ccdc146 499980 1.79 6.97 20.1 9.05e-15 2.44e-11 22.8
37136 A_42_P667782 Fastkd2 301463 -1.78 12.32 -20.0 1.00e-14 2.46e-11 22.7
10116 A_42_P667782 Fastkd2 301463 -1.71 12.49 -19.4 1.71e-14 3.85e-11 22.3
36556 A_42_P667782 Fastkd2 301463 -1.81 12.36 -18.9 2.98e-14 6.20e-11 21.8
29421 A_42_P667782 Fastkd2 301463 -1.72 12.53 -18.3 5.52e-14 1.06e-10 21.3
23088 A_64_P163386 Uqcc6 691921 1.49 11.22 18.0 7.19e-14 1.30e-10 21.1
35094 A_64_P054586 Usp9x 363445 -1.59 9.35 -17.8 9.48e-14 1.60e-10 20.9
13512 A_42_P667782 Fastkd2 301463 -1.56 12.64 -17.3 1.62e-13 2.58e-10 20.4
11619 A_64_P107239 A4gnt 685758 1.17 6.46 16.8 2.66e-13 3.99e-10 20.0
22476 A_42_P667782 Fastkd2 301463 -1.55 12.65 -16.5 3.81e-13 5.42e-10 19.7
371 A_64_P059545 Mlycd 85239 -2.43 13.28 -16.4 5.91e-13 7.98e-10 19.3
"))

# Probe -> gene pairs PRINTED in the guide (:6690-6696, :6735-6742,
# :6757-6778): the only annotation usable without RnAgilentDesign028282.db.
g174_printed_annotation <- function() {
  a <- rbind(G174_PRINTED$genes_201_205[, c("ProbeName", "Symbol", "EntrezID")],
             G174_PRINTED$head_yfilt[, c("ProbeName", "Symbol", "EntrezID")],
             G174_PRINTED$top20[, c("ProbeName", "Symbol", "EntrezID")])
  a[!duplicated(a$ProbeName), , drop = FALSE]
}

# The guide's code, :6626-6757. Returns the objects the anchors need.
gse33005_guide <- function(dir, suite, annotate = FALSE) {
  tarfile <- file.path(suite, "acceptance", "data", "GSE33005_RAW.tar")
  sdrffile <- file.path(suite, "acceptance", "data", "E-GEOD-33005.sdrf.txt")
  if (!file.exists(tarfile) || !file.exists(sdrffile)) return(NULL)
  if (digest::digest(file = tarfile, algo = "sha256") != GSE33005_SHA[["raw"]] ||
      digest::digest(file = sdrffile, algo = "sha256") != GSE33005_SHA[["sdrf"]])
    stop("OS_ANCHOR_HASH_MISMATCH: GSE33005 F5/F6")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  utils::untar(tarfile, exdir = dir)
  file.copy(sdrffile, file.path(dir, "E-GEOD-33005.sdrf.txt"), overwrite = TRUE)
  old <- setwd(dir); on.exit(setwd(old))
  suppressPackageStartupMessages(library(limma))
  # 17.4.3 Reading the data (:6626, :6649-6655)
  SDRF <- read.delim("E-GEOD-33005.sdrf.txt",check.names=FALSE,stringsAsFactors=FALSE)
  Treatment <- SDRF[,"Characteristics[treatment]"]
  levels <- c("10 ml/kg saline","2 ml/kg corn oil","5 ml/kg corn oil","10 ml/kg corn oil")
  Treatment <- factor(Treatment, levels=levels)
  x <- read.maimages(paste0(SDRF[,"Array Data File"], ".gz"),
                     source="agilent", green.only=TRUE, other.columns="gIsWellAboveBG")
  out <- list(dim_x = dim(x), genes_x = x$genes, SDRF = SDRF, Treatment = Treatment, annotated = FALSE)
  # 17.4.4 Gene annotation (:6685-6690)
  if (annotate) {
    suppressPackageStartupMessages(library(RnAgilentDesign028282.db))
    x$genes$EntrezID <- mapIds(RnAgilentDesign028282.db, x$genes$ProbeName,
                               keytype="PROBEID", column="ENTREZID")
    x$genes$Symbol <- mapIds(RnAgilentDesign028282.db, x$genes$ProbeName,
                             keytype="PROBEID", column="SYMBOL")
    out$genes_x <- x$genes
    out$annotated <- TRUE
    out$annotation_versions <- c(RnAgilentDesign028282.db = as.character(utils::packageVersion("RnAgilentDesign028282.db")),
                                 org.Rn.eg.db = as.character(utils::packageVersion("org.Rn.eg.db")))
  }
  # 17.4.5 Background correction and normalize (:6699, :6720)
  y <- suppressMessages(backgroundCorrect(x, method="normexp"))
  y <- normalizeBetweenArrays(y, method="quantile")
  # 17.4.6 Gene filtering (:6723, :6728)
  NotControl <- y$genes$ControlType==0L
  IsExpr <- rowSums(y$other$gIsWellAboveBG > 0) >= 4
  # 17.4.7 design (:6746)
  design <- model.matrix(~Treatment)
  out$y <- y; out$NotControl <- NotControl; out$IsExpr <- IsExpr; out$design <- design
  # Partial route, always available: the guide's filter WITHOUT the NoSymbol
  # term (which needs the annotation package), same design and eBayes call.
  fit0 <- lmFit(y[NotControl & IsExpr, ], design)
  fit0 <- eBayes(fit0, trend=TRUE, robust=TRUE)
  out$partial <- list(n = sum(NotControl & IsExpr), decide = unclass(summary(decideTests(fit0[,-1]))),
                      tt = topTable(fit0, coef=4, number=Inf, sort.by="none"))
  if (annotate) {
    # :6725, :6730-6735 and :6746-6757, verbatim
    NoSymbol <- is.na(y$genes$Symbol)
    yfilt <- y[NotControl & !NoSymbol & IsExpr, ]
    out$dim_yfilt <- dim(yfilt)
    yfilt$genes <- yfilt$genes[,c("ProbeName","Symbol","EntrezID")]
    out$head_yfilt <- head(yfilt$genes)
    fit <- lmFit(yfilt,design)
    fit <- eBayes(fit,trend=TRUE,robust=TRUE)
    out$decide <- unclass(summary(decideTests(fit[,-1])))
    out$top20 <- topTable(fit,coef=4,n=20)
    out$full <- list(tt = topTable(fit, coef=4, number=Inf, sort.by="none"), NoSymbol = NoSymbol)
  }
  out
}

# Unique feature IDs that keep the original Agilent ProbeName: a ProbeName
# printed once on the array is its own ID; replicate spots of the same
# ProbeName get "|<spot>" (spot = row of the feature-extraction file = the
# row name the guide prints, e.g. 28763).
g174_feature_ids <- function(pn) {
  spot <- seq_along(pn)
  ifelse(pn %in% pn[duplicated(pn)], paste0(pn, "|", spot), pn)
}

# Engine inputs from the guide's normalized EList `g$y` (rows = logical probe
# selection). Writes full-precision values (%.17g) so the engine reads exactly
# the guide's numbers.
gse33005_engine_inputs <- function(g, dir, rows = rep(TRUE, nrow(g$y$E)), annotation = c("printed", "db")) {
  annotation <- match.arg(annotation)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  y <- g$y
  fid_all <- g174_feature_ids(y$genes$ProbeName)
  fid <- fid_all[rows]
  arrays <- sub("_.*$", "", g$SDRF[, "Array Data File"])
  cond <- c("10 ml/kg saline" = "saline", "2 ml/kg corn oil" = "corn2", "5 ml/kg corn oil" = "corn5",
            "10 ml/kg corn oil" = "corn10")[as.character(g$Treatment)]
  wr <- function(m, path) {
    d <- data.frame(feature_id = fid, stringsAsFactors = FALSE)
    for (j in seq_len(ncol(m))) d[[arrays[j]]] <- sprintf("%.17g", m[, j])
    utils::write.csv(d, path, row.names = FALSE, quote = FALSE)
  }
  wr(y$E[rows, , drop = FALSE], file.path(dir, "matrix.csv"))
  bg <- y$other$gIsWellAboveBG[rows, , drop = FALSE]
  storage.mode(bg) <- "integer"
  wr(bg, file.path(dir, "background.csv"))
  ctrl <- fid[y$genes$ControlType[rows] != 0L]
  utils::write.csv(data.frame(feature_id = ctrl), file.path(dir, "controls.csv"), row.names = FALSE)
  utils::write.csv(data.frame(sample = arrays, condition = unname(cond), treatment = as.character(g$Treatment)),
                   file.path(dir, "samples.csv"), row.names = FALSE)
  pn <- y$genes$ProbeName[rows]
  utils::write.csv(data.frame(feature_id = fid, technical_id = pn), file.path(dir, "technical_ids.csv"), row.names = FALSE)
  if (annotation == "printed") {
    pa <- g174_printed_annotation()
    ix <- match(pn, pa$ProbeName)
    keep <- !is.na(ix)
    ann <- data.frame(feature_id = fid[keep], symbol = pa$Symbol[ix[keep]], entrez = pa$EntrezID[ix[keep]],
                      probe_name = pn[keep], systematic_name = y$genes$SystematicName[rows][keep], stringsAsFactors = FALSE)
  } else {
    ann <- data.frame(feature_id = fid, symbol = unname(y$genes$Symbol[rows]), entrez = unname(y$genes$EntrezID[rows]),
                      probe_name = pn, systematic_name = y$genes$SystematicName[rows], stringsAsFactors = FALSE)
  }
  utils::write.csv(ann, file.path(dir, "probe_annotation.csv"), row.names = FALSE, na = "NA")
  list(matrix = file.path(dir, "matrix.csv"), background = file.path(dir, "background.csv"),
       controls = file.path(dir, "controls.csv"), n_controls = length(ctrl), samples = file.path(dir, "samples.csv"),
       technical_ids = file.path(dir, "technical_ids.csv"), annotation = file.path(dir, "probe_annotation.csv"),
       feature_id = fid, spot = which(rows))
}

# Printed-value checks that need no annotation package (:6681, :6690-6696
# columns read from the files, :6757-6778 spot -> ProbeName identities).
g174_check_raw_printed <- function(g, check) {
  P <- G174_PRINTED
  check(identical(as.integer(g$dim_x), P$dim_x), "PRINTED 17.4.3 dim(x) = 44254 x 19 (usersguide :6681)")
  gx <- g$genes_x[201:205, ]
  pr <- P$genes_201_205
  check(identical(as.integer(gx$Row), pr$Row) && identical(as.integer(gx$Col), pr$Col) &&
          identical(as.integer(gx$ControlType), pr$ControlType) && identical(gx$ProbeName, pr$ProbeName) &&
          identical(gx$SystematicName, pr$SystematicName),
        "PRINTED 17.4.4 x$genes[201:205, Row/Col/ControlType/ProbeName/SystematicName] (usersguide :6691-6696)")
  check(identical(g$genes_x$ProbeName[P$top20$spot], P$top20$ProbeName) &&
          identical(g$genes_x$ProbeName[P$head_yfilt$spot], P$head_yfilt$ProbeName),
        "PRINTED 17.4.6/17.4.7 spot -> ProbeName of head(yfilt$genes) and the top-20 table (usersguide :6736-6742, :6759-6778)")
}

# Full printed anchor (needs the annotation; g from gse33005_guide(annotate = TRUE)).
g174_check_full_printed <- function(g, check) {
  P <- G174_PRINTED
  gx <- g$genes_x[201:205, ]
  check(identical(unname(as.character(gx$EntrezID)), P$genes_201_205$EntrezID) &&
          identical(unname(as.character(gx$Symbol)), P$genes_201_205$Symbol),
        "PRINTED 17.4.4 mapIds EntrezID/Symbol of spots 201-205 (usersguide :6691-6696)")
  check(identical(as.integer(g$dim_yfilt), P$dim_yfilt), "PRINTED 17.4.6 dim(yfilt) = 27024 x 19 (usersguide :6732)")
  hy <- g$head_yfilt
  check(identical(as.integer(rownames(hy)), P$head_yfilt$spot) && identical(hy$ProbeName, P$head_yfilt$ProbeName) &&
          identical(unname(hy$Symbol), P$head_yfilt$Symbol) && identical(unname(hy$EntrezID), P$head_yfilt$EntrezID),
        "PRINTED 17.4.6 head(yfilt$genes) (usersguide :6736-6742)")
  d <- g$decide
  check(identical(dim(d), c(3L, 3L)) && identical(rownames(d), rownames(P$decide)) && identical(colnames(d), colnames(P$decide)) &&
          all(as.integer(d) == as.integer(P$decide)),
        "PRINTED 17.4.7 summary(decideTests(fit[,-1])): 2 and 5 ml/kg 0/27024/0, 10 ml/kg Down 756 NotSig 24734 Up 1534 (usersguide :6750-6753)")
  t20 <- g$top20; pt <- P$top20
  ok_id <- identical(as.integer(rownames(t20)), pt$spot) && identical(t20$ProbeName, pt$ProbeName) &&
    identical(unname(t20$Symbol), pt$Symbol) && identical(unname(t20$EntrezID), pt$EntrezID)
  # printed precision: 2 decimals (logFC, AveExpr), 1 decimal (t, B), 3 significant digits (P, adj.P)
  same <- function(a, b) length(a) == length(b) && all(abs(a - b) <= 1e-12 * abs(b))
  ok_num <- same(round(t20$logFC, 2), pt$logFC) && same(round(t20$AveExpr, 2), pt$AveExpr) &&
    same(round(t20$t, 1), pt$t) && same(signif(t20$P.Value, 3), pt$P.Value) &&
    same(signif(t20$adj.P.Val, 3), pt$adj.P.Val) && same(round(t20$B, 1), pt$B)
  check(ok_id && ok_num, "PRINTED 17.4.7 topTable(fit, coef=4, n=20): 20 rows, spot/ProbeName/Symbol/EntrezID and logFC/AveExpr/t/P/adj.P/B at printed precision, RT1-Bb logFC 9.33 first (usersguide :6757-6778)")
}

# Replay: the engine run in `outdir` vs the guide topTable of the same route
# (same probes, same design reparametrised with saline as reference, same
# eBayes). tt = guide topTable(..., sort.by = "none"); fid = engine IDs of the
# guide rows. Two levels: (1) the saved MArrayLM (objects/fit.rds, full
# precision) at tolerance 1e-10 -- only the column order of the design
# differs; (2) tables/feature_table.csv, which the shared writer prints with 10
# significant digits, element-wise at that precision (relative 1e-9).
g174_compare_engine <- function(outdir, tt, fid, coef = "conditioncorn10") {
  ft <- utils::read.csv(file.path(outdir, "tables", "feature_table.csv"), stringsAsFactors = FALSE)
  fit <- readRDS(file.path(outdir, "objects", "fit.rds"))
  if (nrow(ft) != length(fid) || !identical(sort(rownames(fit$coefficients)), sort(fid))) return(FALSE)
  j <- match(fid, rownames(fit$coefficients))
  eq <- function(a, b) isTRUE(all.equal(unname(a), unname(b), tolerance = 1e-10))
  ok_fit <- eq(fit$coefficients[j, coef], tt$logFC) && eq(fit$Amean[j], tt$AveExpr) && eq(fit$t[j, coef], tt$t) &&
    eq(fit$p.value[j, coef], tt$P.Value) && eq(stats::p.adjust(fit$p.value[, coef], method = "BH")[j], tt$adj.P.Val) &&
    eq(fit$lods[j, coef], tt$B)
  z <- ft[match(fid, ft$feature_id), , drop = FALSE]
  near <- function(a, b) all(abs(a - b) <= 1e-9 * abs(b))
  ok_tab <- !anyNA(z$feature_id) && near(z$log2fc, tt$logFC) && near(z$base_mean, tt$AveExpr) && near(z$stat, tt$t) &&
    near(z$pvalue, tt$P.Value) && near(z$padj, tt$adj.P.Val)
  ok_fit && ok_tab
}

# Engine on the guide's full route: the fixture drops the NoSymbol probes
# upstream (the annotation filter of :6725), the engine removes controls and
# applies the >= 4 arrays above-background rule, design ~ condition with all
# four levels, Agilent preset eBayes(trend = TRUE, robust = TRUE).
g174_check_full_engine <- function(g, dir, run, check) {
  rows <- !g$full$NoSymbol
  p <- gse33005_engine_inputs(g, file.path(dir, "fixture_db"), rows = rows, annotation = "db")
  ctl <- if (p$n_controls > 0) c("--control-ids", shQuote(p$controls)) else "--controls-removed"
  out <- file.path(dir, "full_route")
  r <- run("--matrix", shQuote(p$matrix), "--samples", shQuote(p$samples), ctl,
           "--above-background", shQuote(p$background), "--background-k", "4", "--platform", "agilent",
           "--reference", "saline", "--target", "corn10", "--keep-other-levels",
           "--probe-annotation", shQuote(p$annotation),
           "--preprocessing", shQuote("normexp background correction followed by quantile normalization between arrays; probes without an annotated gene symbol (RnAgilentDesign028282.db) removed"),
           "--outdir", shQuote(out))
  check(r$status == 0, paste("full-route engine run", paste(utils::tail(r$out, 2), collapse = " | ")))
  if (r$status != 0) return(invisible(FALSE))
  ft <- utils::read.csv(file.path(out, "tables", "feature_table.csv"), stringsAsFactors = FALSE)
  fid_all <- g174_feature_ids(g$y$genes$ProbeName)
  sel <- g$NotControl & !g$full$NoSymbol & g$IsExpr
  check(nrow(ft) == 27024L && g174_compare_engine(out, g$full$tt, fid_all[sel]),
        "REPLAY 17.4 full route: engine tests the guide's 27024 probes; fit logFC/AveExpr/t/P/adj.P/B equal the guide fit (tol 1e-10), feature table at its 10 printed digits")
  ds <- utils::read.csv(file.path(out, "tables", "direction_summary.csv"))
  check(ds$Down == 756L && ds$NotSig == 24734L && ds$Up == 1534L,
        "PRINTED 17.4.7 via the engine: direction_summary.csv corn10 vs saline Down 756 / NotSig 24734 / Up 1534 (usersguide :6750-6753)")
  check(ft$feature_id[1] == fid_all[28763] && identical(ft$symbol[1], "RT1-Bb") && abs(round(ft$log2fc[1], 2) - 9.33) < 1e-9,
        "PRINTED 17.4.7 via the engine: top feature A_44_P552452 (spot 28763) symbol RT1-Bb, logFC 9.33 (usersguide :6759)")
  fa <- utils::read.csv(file.path(out, "tables", "feature_annotation.csv"), stringsAsFactors = FALSE, colClasses = "character")
  top <- G174_PRINTED$top20
  fa20 <- fa[match(fid_all[top$spot], fa$feature_id), ]
  check(nrow(fa) == 27024L && all(fa$annotation_status == "mapped") && identical(fa20$symbol, top$Symbol) && identical(fa20$entrez, top$EntrezID),
        "PRINTED 17.4.7 via the engine: feature_annotation.csv 27024 mapped rows; Symbol/EntrezID of the printed top 20 (usersguide :6759-6778)")
  invisible(TRUE)
}
