# limma User's Guide sec 18.1 (Yoruba HapMap RNA-seq), file F10 (ANCHOR_REGISTRY row 7b),
# replayed with the guide's OWN code. Guide text: acceptance/exemplars/<module>/L1_bioc3.23/
# limma/vignettes/usersguide.rendered.txt (cited as guide:<line>).
#
# Version note (S4_ANCHOR_TRACE.md): the User's Guide is a static PDF whose Yoruba output was
# last re-run around limma 3.42 (NEWS 3.42.0). limma 3.66.0 changed the default of
# voom(adaptive.span) to TRUE ("All the voom functions now use chooseLowessSpan() by
# default"). The printed sec 18.1.9 values were therefore produced with the old fixed
# span = 0.5, i.e. adaptive.span = FALSE. yoruba_guide_fit(adaptive.span = FALSE) is the
# version-matched printed anchor; adaptive.span = TRUE is the locked 3.68.5 default that the
# suite route uses (checked by locked replay, never against the printed numbers).
YORUBA_SHA <- "62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b"

yoruba_guide_lines <- function(suite, module) {
  readLines(file.path(suite, "acceptance", "exemplars", module, "L1_bioc3.23", "limma", "vignettes",
                      "usersguide.rendered.txt"), warn = FALSE)
}

# guide:6854-6944 Targets (printed table), :6963 concentration as factor,
# :7201-7209 DGEList + filter (A > 50 and annotation present), :7213 TMM.
yoruba_guide_inputs <- function(suite, guide) {
  f <- file.path(suite, "acceptance", "data", "limma_Yoruba.RData")
  if (!file.exists(f)) return(NULL)
  if (digest::digest(file = f, algo = "sha256") != YORUBA_SHA) stop("OS_ANCHOR_HASH_MISMATCH: Yoruba F10")
  rows <- grep("^[0-9]+ argonne ", guide, value = TRUE)
  if (length(rows) != 86L) stop("OS_ANCHOR_INVALID: guide targets rows changed")
  tok <- strsplit(trimws(rows), " +")
  Targets <- data.frame(individual = vapply(tok, `[`, "", 5), concentration = vapply(tok, `[`, "", 6),
                        cellline = vapply(tok, `[`, "", 7), gender = vapply(tok, `[`, "", 8))
  env <- new.env(); load(f, envir = env); y <- env$y
  if (!identical(colnames(y), Targets$individual)) stop("OS_ANCHOR_INVALID: guide targets do not match F10")
  Targets$concentration <- factor(Targets$concentration)            # guide:6963
  A <- rowSums(y$counts)                                             # guide:7204
  isexpr <- A > 50                                                   # guide:7205
  hasannot <- rowSums(is.na(y$genes)) == 0                           # guide:7207
  y <- y[isexpr & hasannot, , keep.lib.sizes = FALSE]                # guide:7208
  y <- suppressMessages(edgeR::calcNormFactors(y))                   # guide:7213
  list(y = y, Targets = Targets, counts_filtered = y$counts)
}

# guide:7395-7417 (sec 18.1.9), with the voom span setting written out.
yoruba_guide_fit <- function(inp, adaptive.span) {
  y <- inp$y; Targets <- inp$Targets
  design <- stats::model.matrix(~ gender + concentration, data = Targets)                    # :7395
  v <- limma::voom(y, design, adaptive.span = adaptive.span)                                  # :7398
  cor <- limma::duplicateCorrelation(v, design, block = Targets$cellline)                    # :7400
  cor1 <- cor$consensus                                                                       # :7401
  v <- limma::voom(y, design, block = Targets$cellline, correlation = cor$consensus,
                   adaptive.span = adaptive.span, save.plot = TRUE)                           # :7406
  cor <- limma::duplicateCorrelation(v, design, block = Targets$cellline)                    # :7408
  fit <- limma::lmFit(v, design, block = Targets$cellline, correlation = cor$consensus)       # :7415
  fit <- limma::eBayes(fit)                                                                   # :7416
  dt <- summary(limma::decideTests(fit))                                                      # :7417
  tt <- limma::topTable(fit, coef = "genderMale", n = Inf, sort = "p", p = 0.05)              # :7422
  full <- limma::topTable(fit, coef = "genderMale", n = Inf, sort = "none")
  list(design = design, v = v, cor1 = cor1, cor2 = cor$consensus, fit = fit, dt = dt, tt = tt, full = full)
}

# Printed values: consensus (:7402, :7410), decideTests (:7418-7421), topTable (:7423-7473).
yoruba_guide_printed <- function(guide) {
  i <- grep("^> summary\\(decideTests\\(fit\\)\\)$", guide)
  if (length(i) != 1L) stop("OS_ANCHOR_INVALID: decideTests block not found")
  hdr <- strsplit(guide[i + 1L], " +")[[1]]
  dt <- do.call(rbind, lapply(guide[i + 2:4], function(l) as.integer(strsplit(l, " +")[[1]][-1])))
  dimnames(dt) <- list(c("Down", "NotSig", "Up"), hdr)
  j <- grep("^> topTable\\(fit, coef = \"genderMale\"", guide)
  k <- grep("^As expected, the highly ranked genes", guide)
  body <- guide[(j + 2L):(k - 1L)]
  body <- body[grepl("^[0-9]+ ", body) & lengths(strsplit(body, " +")) == 11L]
  tok <- strsplit(body, " +")
  tt <- data.frame(id = vapply(tok, `[`, "", 1), Chr = vapply(tok, `[`, "", 2), Symbol = vapply(tok, `[`, "", 4),
                   logFC = as.numeric(vapply(tok, `[`, "", 6)), AveExpr = as.numeric(vapply(tok, `[`, "", 7)),
                   t = as.numeric(vapply(tok, `[`, "", 8)), P.Value = as.numeric(vapply(tok, `[`, "", 9)),
                   adj.P.Val = as.numeric(vapply(tok, `[`, "", 10)), B = as.numeric(vapply(tok, `[`, "", 11)),
                   stringsAsFactors = FALSE)
  cons <- guide[grep("^> cor\\$consensus$", guide) + 1L]
  list(consensus = as.numeric(sub("^\\[1\\] ", "", cons)), dt = dt, tt = tt)
}

# TRUE when x prints as the guide's value p at the guide's precision: fixed decimals
# (logFC/AveExpr/B 3, t 2) or 3 significant digits for P values.
printed_equal <- function(x, p, decimals = NULL, signif_digits = NULL) {
  if (!is.null(decimals)) return(all(abs(x - p) <= 0.5 * 10^(-decimals) + 1e-12))
  all(abs(x - p) <= 0.5 * 10^(floor(log10(abs(p))) - signif_digits + 1) * (1 + 1e-9))
}

# Compare a topTable with the printed guide rows (ids, symbols, all numeric columns).
yoruba_compare_printed_tt <- function(tt, printed) {
  ok_ids <- identical(rownames(tt), printed$id) && identical(as.character(tt$Symbol), printed$Symbol)
  if (!ok_ids) return(c(ids = FALSE))
  c(ids = TRUE,
    logFC = printed_equal(tt$logFC, printed$logFC, decimals = 3),
    AveExpr = printed_equal(tt$AveExpr, printed$AveExpr, decimals = 3),
    t = printed_equal(tt$t, printed$t, decimals = 2),
    P.Value = printed_equal(tt$P.Value, printed$P.Value, signif_digits = 3),
    adj.P.Val = printed_equal(tt$adj.P.Val, printed$adj.P.Val, signif_digits = 3),
    B = printed_equal(tt$B, printed$B, decimals = 3))
}
