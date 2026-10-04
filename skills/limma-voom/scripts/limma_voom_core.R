# limma-voom S2 estimator. Frozen decisions: PACK S1 appendix P-1..P-3.
# S4 (2026-09-29): voom trend saved (save.plot = TRUE), sample MDS from
# limma::plotMDS(plot = FALSE), and every Methods slot filled from the actual run.
LV_MODULE <- "limma-voom"
LV_MODULE_VERSION <- "1.1.0"
LV_MIN_TOTAL_COUNT <- 15
LV_LARGE_N <- 10
LV_MIN_PROP <- 0.7
LV_MDS_TOP <- 500
LV_CPM_PRIOR_COUNT <- 2

.lv_fmt <- function(x, d = 3) trimws(formatC(x, digits = d, format = "g"))

# The thresholds filterByExpr.default applies with a design (edgeR 4.10.5 source,
# filterByExpr.Rd Details): CPM cutoff = min.count / median(lib.size) * 1e6 in at least
# 1 / max(hat(design)) samples (reduced above large.n by min.prop), and a total count of at
# least min.total.count. Reported, not re-applied: `keep` comes from filterByExpr itself.
lv_filter_thresholds <- function(mat, design, min_count) {
  lib <- colSums(mat)
  n_min <- 1 / max(stats::hat(design))
  if (n_min > LV_LARGE_N) n_min <- LV_LARGE_N + (n_min - LV_LARGE_N) * LV_MIN_PROP
  list(min_count = min_count, min_total_count = LV_MIN_TOTAL_COUNT, large_n = LV_LARGE_N, min_prop = LV_MIN_PROP,
       median_lib_size = stats::median(lib), cpm_cutoff = min_count / stats::median(lib) * 1e6,
       min_samples = n_min)
}

limma_voom_compute <- function(mat, model, a) {
  cs <- os_count_state(mat)
  if (cs$n_negative || cs$n_non_integer || any(cs$library_sizes <= 0))
    stop("OS_INVALID_INPUT: limma-voom requires nonnegative integer raw counts and nonempty libraries.", call. = FALSE)
  if (nrow(mat) < 100L) stop("OS_INVALID_INPUT: at least 100 count features are needed for the voom trend.", call. = FALSE)
  keep <- edgeR::filterByExpr(y = mat, design = model$design, group = NULL, lib.size = NULL,
                              min.count = a[["min-count"]], min.total.count = LV_MIN_TOTAL_COUNT,
                              large.n = LV_LARGE_N, min.prop = LV_MIN_PROP)
  if (sum(keep) < 100L) stop("OS_QC_BLOCKER: fewer than 100 genes remain after filterByExpr.", call. = FALSE)
  thr <- lv_filter_thresholds(mat, model$design, a[["min-count"]])
  dge <- edgeR::DGEList(counts = mat[keep, , drop = FALSE], lib.size = NULL,
                        norm.factors = NULL, samples = NULL, group = NULL,
                        genes = NULL, remove.zeros = FALSE)
  dge <- edgeR::normLibSizes(object = dge, method = "TMM", refColumn = NULL,
                             logratioTrim = 0.3, sumTrim = 0.05, doWeighting = TRUE,
                             Acutoff = -1e10, p = 0.75)
  sw <- isTRUE(a[["sample-weights"]])
  if (a$interface == "voomLmFit") {
    fit <- edgeR::voomLmFit(counts = dge, design = model$design, block = NULL,
                            prior.weights = NULL, sample.weights = sw,
                            var.design = NULL, var.group = NULL, prior.n = 10,
                            lib.size = NULL, offset = NULL, offset.prior = NULL,
                            normalize.method = "none", span = 0.5,
                            adaptive.span = TRUE, plot = FALSE, save.plot = TRUE,
                            keep.EList = TRUE)
    elist <- fit[["EList"]]
    trend <- list(xy = fit$voom.xy, line = fit$voom.line)
    # voomLmFit does not return its span; this is the call it makes when adaptive.span = TRUE.
    span_used <- limma::chooseLowessSpan(n = nrow(dge), small.n = 50, min.span = 0.3, power = 1/3)
  } else {
    if (sw) {
      elist <- limma::voomWithQualityWeights(counts = dge, design = model$design,
                    lib.size = NULL, normalize.method = "none", plot = FALSE,
                    span = 0.5, adaptive.span = TRUE, var.design = NULL,
                    var.group = NULL, method = "genebygene", maxiter = 50,
                    tol = 1e-5, trace = FALSE, col = NULL, save.plot = TRUE)
    } else {
      elist <- limma::voom(counts = dge, design = model$design, lib.size = NULL,
                           offset = NULL, offset.prior = NULL, normalize.method = "none",
                           block = NULL, correlation = NULL, weights = NULL,
                           span = 0.5, adaptive.span = TRUE, plot = FALSE, save.plot = TRUE)
    }
    trend <- list(xy = elist$voom.xy, line = elist$voom.line)
    span_used <- elist$span
    elist$voom.xy <- NULL; elist$voom.line <- NULL
    fit <- limma::lmFit(object = elist, design = model$design, ndups = NULL,
                        spacing = NULL, block = NULL, correlation = NULL,
                        weights = NULL, method = "ls")
  }
  zero <- a[["min-effect-fc"]] <= 1
  if (!zero) {
    fit <- limma::treat(fit = fit, fc = a[["min-effect-fc"]],
                        lfc = log2(a[["min-effect-fc"]]), trend = FALSE,
                        robust = FALSE, winsor.tail.p = c(0.05, 0.1),
                        legacy = NULL, upshot = FALSE)
  } else {
    fit <- limma::eBayes(fit = fit, proportion = 0.01,
                         stdev.coef.lim = c(0.1, 4), trend = FALSE,
                         span = NULL, robust = FALSE,
                         winsor.tail.p = c(0.05, 0.1), legacy = NULL)
  }
  tt <- limma::topTable(fit = fit, coef = model$coef, number = Inf,
                        genelist = fit$genes, adjust.method = "BH",
                        sort.by = "P", resort.by = NULL, p.value = 1,
                        fc = NULL, lfc = NULL, confint = FALSE)
  estimated_weights <- if (sw) fit$targets$sample.weight %||% elist$targets$sample.weight else NULL
  if (sw && (length(estimated_weights) != ncol(mat) ||
             any(!is.finite(estimated_weights)) || any(estimated_weights <= 0)))
    stop("OS_INVALID_RESULT: sample quality weights were requested but not returned for every sample.", call. = FALSE)
  if (!is.null(estimated_weights)) names(estimated_weights) <- colnames(mat)
  # Sample MDS (PACK F; RNAseq123 Rmd:280-285 plotMDS(lcpm) with lcpm <- cpm(x, log = TRUE)
  # on the filtered TMM DGEList): leading log2 fold change over the top 500 genes.
  logcpm <- edgeR::cpm(y = dge, normalized.lib.sizes = TRUE, log = TRUE, prior.count = LV_CPM_PRIOR_COUNT)
  mds <- limma::plotMDS(logcpm, top = LV_MDS_TOP, labels = NULL, pch = NULL, cex = 1, dim.plot = c(1, 2),
                        gene.selection = "pairwise", xlab = NULL, ylab = NULL, plot = FALSE, var.explained = TRUE)
  nf <- dge$samples$norm.factors
  df_prior <- fit$df.prior; s2_prior <- fit$s2.prior
  tv <- lv_template_values(a, thr, sum(keep), nrow(mat), nf, span_used, sw, estimated_weights,
                           zero, df_prior, s2_prior, nrow(dge))
  list(fit = fit, elist = elist, tt = tt,
       detail = "",
       # expr set explicitly (limma_io reads res[["expr"]] since integrate fa9227c; kept explicit).
       expr = elist$E,
       expr_scale = "voom log2 counts per million (TMM-normalised library sizes)",
       weights_note = if (sw) "voom precision weights x sample quality weights" else "voom precision weights",
       template_values = tv,
       voom_trend = list(xy = trend$xy, line = trend$line, span = span_used, title = NULL),
       mds = list(coords = data.frame(sample = colnames(logcpm), dim1 = mds$x, dim2 = mds$y, stringsAsFactors = FALSE),
                  var_explained = mds$var.explained, top = mds$top, gene_selection = mds$gene.selection,
                  input_label = sprintf("filtered, TMM-normalised log2 CPM (prior count %s)", format(LV_CPM_PRIOR_COUNT)),
                  n_features = nrow(logcpm)),
       details = list(interface = a$interface, edger_version = as.character(utils::packageVersion("edgeR")),
                      filter_input = nrow(mat), filter_kept = sum(keep),
                      filter = list(min_count = thr$min_count, min_total_count = thr$min_total_count,
                                    large_n = thr$large_n, min_prop = thr$min_prop,
                                    cpm_cutoff = thr$cpm_cutoff, min_samples = thr$min_samples,
                                    design = model$formula),
                      norm = "TMM", norm_factors = as.list(stats::setNames(nf, colnames(mat))),
                      adaptive_span = TRUE, span = span_used,
                      sample_weights = sw,
                      sample_weight_values = if (is.null(estimated_weights)) NULL else as.list(estimated_weights),
                      var_design = NULL, var_group = NULL,
                      moderation = if (zero) "eBayes" else "treat",
                      fc = if (zero) NULL else a[["min-effect-fc"]], lfc = if (zero) 0 else log2(a[["min-effect-fc"]]),
                      df_prior = if (length(df_prior) == 1L) df_prior else NULL, s2_prior = if (length(s2_prior) == 1L) s2_prior else NULL,
                      mds = list(top = mds$top, gene_selection = mds$gene.selection, prior_count = LV_CPM_PRIOR_COUNT)))
}

# Methods slots from the actual run (S3 F2): no sentence states a setting that the
# code path did not use.
lv_template_values <- function(a, thr, n_kept, n_input, nf, span, sw, w, zero, df_prior, s2_prior, n_genes) {
  filter <- sprintf(paste0("Genes were filtered with edgeR filterByExpr using the design matrix (min.count = %s, ",
                           "min.total.count = %s, large.n = %s, min.prop = %s): a gene was kept when it had at least %s counts per million ",
                           "(%s / median library size of %s million) in at least %s samples (the minimum sample size filterByExpr derives from the design leverage) ",
                           "and a total count of at least %s; %d of %d genes were retained."),
                    format(thr$min_count), format(thr$min_total_count), format(thr$large_n), format(thr$min_prop),
                    .lv_fmt(thr$cpm_cutoff), format(thr$min_count), .lv_fmt(thr$median_lib_size / 1e6, 4),
                    .lv_fmt(thr$min_samples, 4), format(thr$min_total_count), n_kept, n_input)
  norm <- sprintf(paste0("Library sizes were scaled with TMM normalisation (edgeR normLibSizes, method = \"TMM\", logratioTrim = 0.3, ",
                         "sumTrim = 0.05, doWeighting = TRUE, Acutoff = -1e10); normalisation factors ranged from %s to %s."),
                  formatC(min(nf), digits = 3, format = "f"), formatC(max(nf), digits = 3, format = "f"))
  span_txt <- sprintf("the lowess span of the mean-variance trend was chosen adaptively (adaptive.span = TRUE; span = %s for %d genes)",
                      formatC(span, digits = 4, format = "f"), n_genes)
  sw_txt <- if (sw) sprintf("Sample quality weights were estimated (user-enabled; var.design = NULL, var.group = NULL%s) and were %s.",
                            if (a$interface == "legacy") ", method = \"genebygene\", maxiter = 50, tol = 1e-5" else "",
                            paste(sprintf("%s %s", names(w), formatC(w, digits = 3, format = "f")), collapse = ", "))
            else "Sample quality weights were not used."
  voom <- if (a$interface == "voomLmFit") {
    sprintf(paste0("Counts were transformed to log2 counts per million with precision weights and fitted gene-wise with ",
                   "edgeR voomLmFit (block = NULL, prior.weights = NULL, prior.n = 10, normalize.method = \"none\"); %s."), span_txt)
  } else if (sw) {
    sprintf(paste0("Counts were transformed with limma voomWithQualityWeights (normalize.method = \"none\"); %s. ",
                   "Linear models were fitted gene-wise with lmFit (method = \"ls\")."), span_txt)
  } else {
    sprintf(paste0("Counts were transformed with limma voom (normalize.method = \"none\"); %s. ",
                   "Linear models were fitted gene-wise with lmFit (method = \"ls\")."), span_txt)
  }
  prior <- paste0(if (length(df_prior) == 1L) sprintf("estimated prior df = %s", .lv_fmt(df_prior, 4)) else
                     sprintf("gene-wise prior df (robust; median %s)", .lv_fmt(stats::median(df_prior), 4)),
                   if (length(s2_prior) == 1L) sprintf(", prior variance = %s", .lv_fmt(s2_prior, 4)) else
                     ", prior variance following the mean-expression trend")
  moderation <- if (zero) {
    sprintf(paste0("Variances were moderated with limma eBayes (trend = FALSE, robust = FALSE, proportion = 0.01, ",
                   "stdev.coef.lim = c(0.1, 4), legacy = NULL; %s) and each gene was tested against a zero log2 fold change."), prior)
  } else {
    sprintf(paste0("Variances were moderated and each gene was tested against the pre-specified minimum fold change with limma treat ",
                   "(fc = %s, lfc = log2(fc) = %s, trend = FALSE, robust = FALSE, legacy = NULL, upshot = FALSE; %s): ",
                   "the null hypothesis was |log2 fold change| <= %s."),
            format(a[["min-effect-fc"]]), formatC(log2(a[["min-effect-fc"]]), digits = 4, format = "f"), prior,
            formatC(log2(a[["min-effect-fc"]]), digits = 4, format = "f"))
  }
  list(edger_version = as.character(utils::packageVersion("edgeR")),
       interface_label = if (a$interface == "voomLmFit") "edgeR voomLmFit interface" else "limma voom + lmFit (legacy reproduction interface)",
       filter_sentence = filter, norm_sentence = norm, voom_sentence = voom, weights_sentence = sw_txt,
       moderation_sentence = moderation)
}
