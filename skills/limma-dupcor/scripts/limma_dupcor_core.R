# limma-dupcor S2 estimator; PACK S1 appendix P-1..P-3.
# S4 (2026-09-29): second-round voom trend saved (save.plot = TRUE), sample MDS from
# limma::plotMDS(plot = FALSE), every Methods slot filled from the actual run.
LD_MODULE <- "limma-dupcor"
LD_MODULE_VERSION <- "1.1.0"
LD_MIN_TOTAL_COUNT <- 15
LD_LARGE_N <- 10
LD_MIN_PROP <- 0.7
LD_TRIM <- 0.15
LD_MDS_TOP <- 500
LD_CPM_PRIOR_COUNT <- 2

.ld_fmt <- function(x, d = 3) trimws(formatC(x, digits = d, format = "g"))

limma_dupcor_compute <- function(mat, model, a) {
  if (a[["block-role"]] == "technical_batch" && is.null(a[["block-rationale"]]))
    stop("OS_MISSING_PARAMETER: technical batch as a random block needs --block-rationale; normally put technical batch in the fixed-effect design.", call. = FALSE)
  if (a$mode == "array" && is.null(a$platform))
    stop("OS_MISSING_PARAMETER: array mode requires --platform.", call. = FALSE)
  if (a$mode == "array" && a$platform != "agilent" && (a$trend == "auto" || a$robust == "auto"))
    stop("OS_MISSING_PARAMETER: non-Agilent arrays require explicit --trend and --robust.", call. = FALSE)
  if (a$mode == "rna" && any(!is.finite(mat) | mat < 0 | abs(mat - round(mat)) > 1e-8))
    stop("OS_INVALID_INPUT: RNA mode requires uncorrected nonnegative integer counts.", call. = FALSE)
  trend <- if (a$trend == "auto") a$mode == "array" else a$trend == "true"
  robust <- if (a$robust == "auto") a$mode == "array" else a$robust == "true"
  rounds <- 1L; cor1 <- NULL; elist <- NULL; voom_trend <- NULL; spans <- NULL; filt <- NULL; nf <- NULL
  if (a$mode == "rna") {
    keep <- edgeR::filterByExpr(y = mat, design = model$design, group = NULL, lib.size = NULL,
                                min.count = a[["min-count"]], min.total.count = LD_MIN_TOTAL_COUNT,
                                large.n = LD_LARGE_N, min.prop = LD_MIN_PROP)
    if (sum(keep) < 100L) stop("OS_QC_BLOCKER: fewer than 100 genes after filterByExpr.", call. = FALSE)
    lib <- colSums(mat)
    n_min <- 1 / max(stats::hat(model$design))
    if (n_min > LD_LARGE_N) n_min <- LD_LARGE_N + (n_min - LD_LARGE_N) * LD_MIN_PROP
    filt <- list(min_count = a[["min-count"]], min_total_count = LD_MIN_TOTAL_COUNT, large_n = LD_LARGE_N,
                 min_prop = LD_MIN_PROP, median_lib_size = stats::median(lib),
                 cpm_cutoff = a[["min-count"]] / stats::median(lib) * 1e6, min_samples = n_min,
                 n_input = nrow(mat), n_kept = sum(keep))
    dge <- edgeR::DGEList(counts = mat[keep, , drop = FALSE], lib.size = NULL,
                          norm.factors = NULL, samples = NULL, group = NULL,
                          genes = NULL, remove.zeros = FALSE)
    dge <- edgeR::normLibSizes(object = dge, method = "TMM", refColumn = NULL,
                               logratioTrim = 0.3, sumTrim = 0.05,
                               doWeighting = TRUE, Acutoff = -1e10, p = 0.75)
    nf <- dge$samples$norm.factors
    # Round 1 (User's Guide sec 18.1.9 guide:7398-7400): voom without block, then the correlation.
    v1 <- limma::voom(counts = dge, design = model$design, lib.size = NULL,
                      offset = NULL, offset.prior = NULL, normalize.method = "none",
                      block = NULL, correlation = NULL, weights = NULL,
                      span = 0.5, adaptive.span = TRUE, plot = FALSE, save.plot = FALSE)
    c1 <- limma::duplicateCorrelation(object = v1, design = model$design, ndups = 2,
                                      spacing = 1, block = model$block, trim = LD_TRIM,
                                      weights = NULL)
    cor1 <- c1$consensus.correlation
    # Round 2 (guide:7406-7408): voom with block and round-1 correlation, correlation again.
    v2 <- limma::voom(counts = dge, design = model$design, lib.size = NULL,
                      offset = NULL, offset.prior = NULL, normalize.method = "none",
                      block = model$block, correlation = cor1, weights = NULL,
                      span = 0.5, adaptive.span = TRUE, plot = FALSE, save.plot = TRUE)
    c2 <- limma::duplicateCorrelation(object = v2, design = model$design, ndups = 2,
                                      spacing = 1, block = model$block, trim = LD_TRIM,
                                      weights = NULL)
    voom_trend <- list(xy = v2$voom.xy, line = v2$voom.line, span = v2$span, title = NULL)
    spans <- c(v1$span, v2$span)
    v2$voom.xy <- NULL; v2$voom.line <- NULL
    elist <- v2; input <- v2; corfit <- c2; rounds <- 2L
    mds_in <- edgeR::cpm(y = dge, normalized.lib.sizes = TRUE, log = TRUE, prior.count = LD_CPM_PRIOR_COUNT)
    mds_label <- sprintf("filtered, TMM-normalised log2 CPM (prior count %s)", format(LD_CPM_PRIOR_COUNT))
  } else {
    if (any(!is.finite(mat))) stop("OS_INVALID_INPUT: normalized log2 array matrix must be finite.", call. = FALSE)
    corfit <- limma::duplicateCorrelation(object = mat, design = model$design, ndups = 2,
                                          spacing = 1, block = model$block, trim = LD_TRIM,
                                          weights = NULL)
    input <- mat
    mds_in <- mat
    mds_label <- "user-supplied normalised log2 expression"
  }
  consensus <- corfit$consensus.correlation
  if (!is.finite(consensus) || abs(consensus) >= 1)
    stop("OS_INVALID_RESULT: duplicateCorrelation returned a nonfinite or boundary consensus.", call. = FALSE)
  fit <- limma::lmFit(object = input, design = model$design, ndups = NULL,
                      spacing = NULL, block = model$block,
                      correlation = consensus, weights = NULL, method = "ls")
  zero <- a[["min-effect-fc"]] <= 1
  if (!zero) {
    fit <- limma::treat(fit = fit, fc = a[["min-effect-fc"]],
                        lfc = log2(a[["min-effect-fc"]]), trend = trend,
                        robust = robust, winsor.tail.p = c(0.05, 0.1),
                        legacy = NULL, upshot = FALSE)
  } else {
    fit <- limma::eBayes(fit = fit, proportion = 0.01,
                         stdev.coef.lim = c(0.1, 4), trend = trend,
                         span = NULL, robust = robust,
                         winsor.tail.p = c(0.05, 0.1), legacy = NULL)
  }
  tt <- limma::topTable(fit = fit, coef = model$coef, number = Inf,
                        genelist = fit$genes, adjust.method = "BH", sort.by = "P",
                        resort.by = NULL, p.value = 1, fc = NULL, lfc = NULL,
                        confint = FALSE)
  # Sample MDS (PACK F): leading log2 fold change over the top 500 features of the analysed
  # matrix (RNA: log2 CPM of the filtered TMM DGEList as RNAseq123 Rmd:280; array: the input
  # matrix as User's Guide sec 17.3 guide:6502 plotMDS(y)).
  mds <- limma::plotMDS(mds_in, top = LD_MDS_TOP, labels = NULL, pch = NULL, cex = 1, dim.plot = c(1, 2),
                        gene.selection = "pairwise", xlab = NULL, ylab = NULL, plot = FALSE, var.explained = TRUE)
  bs <- as.list(table(model$block))
  df_prior <- fit$df.prior; s2_prior <- fit$s2.prior
  tv <- ld_template_values(a, model, filt, nf, spans, cor1, consensus, rounds, trend, robust, zero, df_prior, s2_prior,
                           if (is.null(elist)) nrow(mat) else nrow(elist))
  list(fit = fit, elist = elist, tt = tt,
       detail = "",
       # expr set explicitly (limma_io reads res[["expr"]] since integrate fa9227c; kept explicit).
       expr = if (a$mode == "array") mat else elist$E,
       expr_scale = if (a$mode == "array") "user-supplied normalised log2 expression" else "voom log2 counts per million (TMM-normalised library sizes)",
       weights_note = if (a$mode == "rna") "voom precision weights (second round, with block and correlation)" else "none",
       template_values = tv, voom_trend = voom_trend,
       mds = list(coords = data.frame(sample = colnames(mds_in), dim1 = mds$x, dim2 = mds$y, stringsAsFactors = FALSE),
                  var_explained = mds$var.explained, top = mds$top, gene_selection = mds$gene.selection,
                  input_label = mds_label, n_features = nrow(mds_in), block_label = a$block),
       details = list(mode = a$mode, block = a$block, block_description = a[["block-description"]],
                      block_role = a[["block-role"]], block_rationale = a[["block-rationale"]],
                      n_blocks = model$n_blocks, block_sizes = bs,
                      consensus_correlation = consensus, first_correlation = cor1,
                      correlation_rounds = rounds, trim = LD_TRIM, trend = trend, robust = robust,
                      edger_version = if (a$mode == "rna") as.character(utils::packageVersion("edgeR")) else NULL,
                      filter = filt, norm_factors = if (is.null(nf)) NULL else as.list(stats::setNames(nf, colnames(mat))),
                      adaptive_span = if (a$mode == "rna") TRUE else NULL,
                      span_round1 = if (is.null(spans)) NULL else spans[1], span_round2 = if (is.null(spans)) NULL else spans[2],
                      moderation = if (zero) "eBayes" else "treat",
                      fc = if (zero) NULL else a[["min-effect-fc"]], lfc = if (zero) 0 else log2(a[["min-effect-fc"]]),
                      df_prior = if (length(df_prior) == 1L) df_prior else NULL,
                      s2_prior = if (length(s2_prior) == 1L) s2_prior else NULL,
                      mds = list(top = mds$top, gene_selection = mds$gene.selection, input = mds_label)),
       sa = a$mode == "array" && a$platform != "agilent")
}

# Methods slots from the actual run (S3 F2).
ld_template_values <- function(a, model, filt, nf, spans, cor1, consensus, rounds, trend, robust, zero, df_prior, s2_prior, n_genes) {
  sizes <- sort(as.integer(table(model$block)))
  size_txt <- paste(sprintf("%d of size %d", as.integer(table(sizes)), as.integer(names(table(sizes)))), collapse = ", ")
  block <- sprintf(paste0("The correlated unit was %s (sample column \"%s\", role %s%s): %d units (%s). The intra-unit correlation ",
                          "was estimated with limma duplicateCorrelation (block = %s, trim = %s) and the estimated consensus ",
                          "correlation was passed explicitly to lmFit (block = %s, correlation = %s)."),
                   a[["block-description"]], a$block, a[["block-role"]],
                   if (is.null(a[["block-rationale"]])) "" else sprintf("; rationale: %s", a[["block-rationale"]]),
                   model$n_blocks, size_txt, a$block, format(LD_TRIM), a$block, formatC(consensus, digits = 6, format = "f"))
  if (a$mode == "rna") {
    input <- sprintf(paste0("Raw RNA-seq counts were filtered with edgeR filterByExpr using the design matrix (min.count = %s, ",
                            "min.total.count = %s, large.n = %s, min.prop = %s): a gene was kept when it had at least %s counts per million ",
                            "(%s / median library size of %s million) in at least %s samples (the minimum sample size filterByExpr derives ",
                            "from the design leverage) and a total count of at least %s; %d of %d genes were retained. Library sizes were ",
                            "scaled with TMM normalisation (edgeR normLibSizes, method = \"TMM\", logratioTrim = 0.3, sumTrim = 0.05, ",
                            "doWeighting = TRUE, Acutoff = -1e10); normalisation factors ranged from %s to %s."),
                     format(filt$min_count), format(filt$min_total_count), format(filt$large_n), format(filt$min_prop),
                     .ld_fmt(filt$cpm_cutoff), format(filt$min_count), .ld_fmt(filt$median_lib_size / 1e6, 4),
                     .ld_fmt(filt$min_samples, 4), format(filt$min_total_count), filt$n_kept, filt$n_input,
                     formatC(min(nf), digits = 3, format = "f"), formatC(max(nf), digits = 3, format = "f"))
    chain <- sprintf(paste0("Following the limma User's Guide (section 18.1), voom and duplicateCorrelation were run twice: ",
                            "round 1 applied limma voom (normalize.method = \"none\", adaptive.span = TRUE, span %s for %d genes) without a block ",
                            "and estimated a consensus correlation of %s; round 2 recomputed the voom precision weights with block = %s and ",
                            "correlation = %s (span %s) and re-estimated the consensus correlation as %s, which was used for the fit."),
                     formatC(spans[1], digits = 4, format = "f"), n_genes, formatC(cor1, digits = 6, format = "f"), a$block,
                     formatC(cor1, digits = 6, format = "f"), formatC(spans[2], digits = 4, format = "f"),
                     formatC(consensus, digits = 6, format = "f"))
  } else {
    input <- sprintf(paste0("The input was a normalised log2 expression matrix supplied by the user (%d features; preprocessing was not ",
                            "performed by this module), array platform %s."), n_genes, a$platform)
    chain <- "duplicateCorrelation was estimated once on the supplied matrix."
  }
  trend_src <- if (a$mode == "rna") "RNA-seq preset" else if (a$platform == "agilent" && a$trend == "auto") "registered Agilent preset" else "explicit user setting"
  robust_src <- if (a$mode == "rna") "RNA-seq preset" else if (a$platform == "agilent" && a$robust == "auto") "registered Agilent preset" else "explicit user setting"
  prior <- paste0(if (length(df_prior) == 1L) sprintf("estimated prior df = %s", .ld_fmt(df_prior, 4)) else
                     sprintf("gene-wise prior df (robust; median %s)", .ld_fmt(stats::median(df_prior), 4)),
                   if (length(s2_prior) == 1L) sprintf(", prior variance = %s", .ld_fmt(s2_prior, 4)) else
                     ", prior variance following the mean-expression trend")
  moderation <- if (zero) {
    sprintf(paste0("Variances were moderated with limma eBayes (trend = %s [%s], robust = %s [%s], proportion = 0.01, ",
                   "stdev.coef.lim = c(0.1, 4), legacy = NULL; %s) and each feature was tested against a zero log2 fold change."),
            trend, trend_src, robust, robust_src, prior)
  } else {
    sprintf(paste0("Variances were moderated and each feature was tested against the pre-specified minimum fold change with limma treat ",
                   "(fc = %s, lfc = log2(fc) = %s, trend = %s [%s], robust = %s [%s], legacy = NULL, upshot = FALSE; %s): the null ",
                   "hypothesis was |log2 fold change| <= %s."),
            format(a[["min-effect-fc"]]), formatC(log2(a[["min-effect-fc"]]), digits = 4, format = "f"),
            trend, trend_src, robust, robust_src, prior, formatC(log2(a[["min-effect-fc"]]), digits = 4, format = "f"))
  }
  list(edger_sentence = if (a$mode == "rna") sprintf(" and edgeR (v%s)", as.character(utils::packageVersion("edgeR"))) else "",
       data_kind = if (a$mode == "rna") "RNA-seq" else "microarray",
       input_sentence = input, chain_sentence = chain, block_sentence = block, moderation_sentence = moderation,
       consensus_value = formatC(consensus, digits = 6, format = "f"), n_blocks = model$n_blocks)
}
