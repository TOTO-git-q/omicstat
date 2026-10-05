OLC_MODULE <- "limma-camera"
OLC_MODULE_VERSION <- "1.1.1"

limma_camera_assert_blocks <- function(block, group, reference, target) {
  if (anyNA(block) || any(!nzchar(as.character(block))))
    stop("OS_INVALID_DESIGN: repeated-unit IDs must be nonmissing and nonempty.", call. = FALSE)
  n <- vapply(c(reference, target), function(g) length(unique(block[group == g])), integer(1))
  if (any(n < 2L))
    stop("OS_PSEUDOREPLICATION: each group needs at least two independent repeated units; repeated observations are not biological replicates.", call. = FALSE)
  invisible(n)
}

# Design built HERE only for a plain expression input (CSV or a non-limma
# expression hand-off): ~ group + covariates from the sample table. A limma
# upstream brings its own fitted design and coefficient (S4 contract b); this
# function is never called for it.
limma_camera_design <- function(st, a) {
  group <- factor(st[[a[["group-col"]]]], levels = c(a$reference, a$target))
  if (!is.null(a[["block-col"]]))
    limma_camera_assert_blocks(st[[a[["block-col"]]]], group, a$reference, a$target)
  covars <- if (is.null(a$covariates)) character(0) else trimws(strsplit(a$covariates, ",", fixed = TRUE)[[1]])
  dat <- data.frame(group = group, row.names = st[[a[["sample-col"]]]])
  if (length(covars)) for (v in covars) dat[[v]] <- factor(st[[v]])
  design <- stats::model.matrix(stats::reformulate(c("group", covars)), data = dat)
  if (qr(design)$rank < ncol(design)) stop("OS_INVALID_DESIGN: gene-set design is rank deficient.", call. = FALSE)
  coef <- paste0("group", a$target)
  list(matrix = design, contrast = which(colnames(design) == coef), coefficient = coef,
       formula = paste("~", paste(c(a[["group-col"]], covars), collapse = " + ")),
       source = "built by limma-camera from the sample table", covariates = covars,
       reference = a$reference, target = a$target, group_col = a[["group-col"]],
       n_reference = sum(group == a$reference), n_target = sum(group == a$target))
}

# Barcode worm exactly as limma::barcodeplot computes it (limma 3.68.5 source:
# tricubeMovingAverage(set membership in rank order, span = span.worm = 0.45)
# divided by the average membership). Ranks run from the most negative
# statistic (rank 1) to the most positive, the order os_barcode() draws.
limma_camera_worm <- function(stat, members) {
  o <- order(stat, names(stat), method = "radix")
  idx <- as.numeric(names(stat)[o] %in% members)
  enrich <- limma::tricubeMovingAverage(x = idx, span = 0.45, power = 3) / (sum(idx) / length(idx))
  data.frame(rank = seq_along(o), enrichment = enrich)
}

# Short axis label for a ranking statistic (the barcode y title must fit the
# panel; the Methods carry the full metric name from the ranked_list metadata).
limma_camera_axis_label <- function(meta) {
  lab <- switch(meta$statistic %||% "other", moderated_t = "moderated t", treat_moderated_t = "TREAT moderated t",
                wald_stat = "Wald statistic", log2fc = "log2 fold change", meta$metric)
  if (nchar(lab) > 22L) paste0(substr(lab, 1L, 19L), "...") else lab
}

# Gene-level display statistics for the barcode / MD figures (never used by a
# gene-set test). A limma upstream supplies its own fitted MArrayLM; for a
# plain expression input the same design, weights and block are fitted here
# with lmFit + eBayes (display only). A ranked list supplies its own scores.
limma_camera_display <- function(input, method, design, contrast, block, cor, weights) {
  if (!is.null(input$rank)) return(list(stat = input$rank$stats, logfc = NULL, ave = NULL,
                                        stat_label = limma_camera_axis_label(input$rank_meta), source = "the supplied ranking scores"))
  if (!is.null(input$fit)) {
    f <- input$fit
    return(list(stat = stats::setNames(f$t[, contrast], rownames(f$t)),
                logfc = stats::setNames(f$coefficients[, contrast], rownames(f$coefficients)),
                ave = stats::setNames(f$Amean, rownames(f$coefficients)),
                stat_label = "moderated t", source = sprintf("the moderated t of coefficient %s from the upstream %s fit", colnames(f$coefficients)[contrast], input$producer)))
  }
  dfit <- limma::lmFit(object = input$matrix, design = design, ndups = NULL, spacing = NULL,
                       block = block, correlation = cor, weights = weights, method = "ls")
  dfit <- limma::eBayes(fit = dfit, proportion = 0.01, stdev.coef.lim = c(0.1, 4), trend = FALSE,
                        span = NULL, robust = FALSE, winsor.tail.p = c(0.05, 0.1), legacy = NULL)
  list(stat = stats::setNames(dfit$t[, contrast], rownames(dfit$t)),
       logfc = stats::setNames(dfit$coefficients[, contrast], rownames(dfit$coefficients)),
       ave = stats::setNames(dfit$Amean, rownames(dfit$coefficients)), stat_label = "moderated t",
       source = sprintf("a display-only lmFit + eBayes (trend = FALSE, robust = FALSE) moderated t on the same design%s%s",
                        if (is.null(weights)) "" else " and weights", if (is.null(block)) "" else " with the block and correlation"))
}

limma_camera_compute <- function(input, collection, a) {
  is_rank <- !is.null(input$rank)
  identifiers <- if (is_rank) names(input$rank$stats) else rownames(input$matrix)
  index <- limma::ids2indices(gene.sets = collection$sets, identifiers = identifiers, remove.empty = TRUE)
  if (!length(index)) stop("OS_EMPTY_DATA: no registered gene set overlaps the input IDs.", call. = FALSE)
  method <- if (a$question == "competitive") if (is_rank) "cameraPR" else "camera" else a[["self-contained-method"]]
  design <- if (is_rank) NULL else input$design$matrix
  contrast <- if (is_rank) NULL else input$design$contrast
  if (!is_rank && length(contrast) != 1L) stop("OS_INVALID_DESIGN: target contrast must map to one design coefficient.", call. = FALSE)
  if (identical(method, "roast") && !a[["set-id"]] %in% names(index)) stop("OS_EMPTY_DATA: selected roast set has no input-ID overlap.", call. = FALSE)
  block <- if (method %in% c("fry", "roast", "mroast")) input$block else NULL
  cor <- if (is.null(block)) NULL else input$correlation
  weights <- input$weights
  set.seed(a$seed)
  rng <- RNGkind()
  if (identical(method, "cameraPR")) {
    raw <- limma::cameraPR(statistic = input$rank$stats, index = index,
                           use.ranks = FALSE, inter.gene.cor = 0.01,
                           sort = TRUE, directional = TRUE)
  } else if (identical(method, "camera")) {
    raw <- limma::camera(y = input$matrix, index = index, design = design,
                         contrast = contrast, weights = weights, use.ranks = FALSE,
                         allow.neg.cor = FALSE, inter.gene.cor = 0.01,
                         trend.var = FALSE, sort = TRUE, directional = TRUE)
  } else if (identical(method, "fry")) {
    raw <- limma::fry(y = input$matrix, index = index, design = design,
                      contrast = contrast, geneid = NULL, gene.weights = NULL,
                      standardize = "posterior.sd", sort = "directional",
                      block = block, correlation = cor, weights = weights)
  } else if (identical(method, "roast")) {
    raw <- limma::roast(y = input$matrix, index = index[[a[["set-id"]]]],
                        design = design, contrast = contrast, geneid = NULL,
                        set.statistic = "mean", gene.weights = NULL,
                        var.prior = NULL, df.prior = NULL, nrot = a$nrot,
                        approx.zscore = TRUE, legacy = FALSE,
                        block = block, correlation = cor, weights = weights)
  } else {
    raw <- limma::mroast(y = input$matrix, index = index, design = design,
                         contrast = contrast, geneid = NULL, set.statistic = "mean",
                         gene.weights = NULL, var.prior = NULL, df.prior = NULL,
                         nrot = a$nrot, approx.zscore = TRUE, legacy = FALSE,
                         adjust.method = "BH", midp = TRUE, sort = "directional",
                         block = block, correlation = cor, weights = weights)
  }
  if (identical(method, "roast")) {
    roast_table <- raw$p.value
    raw_df <- data.frame(test_direction = rownames(roast_table), roast_table, row.names = NULL, check.names = FALSE)
    p <- unname(roast_table["UpOrDown", "P.Value"])
    dir <- if (roast_table["Up", "P.Value"] < roast_table["Down", "P.Value"]) "Up" else "Down"
    tab <- data.frame(term_id = a[["set-id"]], term_name = a[["set-id"]], database = a$collection,
                      n_genes = length(index[[a[["set-id"]]]]), direction = dir,
                      pvalue = p, padj = p, pvalue_mixed = unname(roast_table["Mixed", "P.Value"]),
                      padj_mixed = unname(roast_table["Mixed", "P.Value"]), stringsAsFactors = FALSE)
  } else {
    raw_df <- data.frame(term_id = rownames(raw), raw, row.names = NULL, check.names = FALSE)
    tab <- data.frame(term_id = rownames(raw), term_name = rownames(raw), database = a$collection,
                      n_genes = raw$NGenes, direction = raw$Direction,
                      pvalue = raw$PValue, padj = raw$FDR,
                      pvalue_mixed = if ("PValue.Mixed" %in% names(raw)) raw$PValue.Mixed else NA_real_,
                      padj_mixed = if ("FDR.Mixed" %in% names(raw)) raw$FDR.Mixed else NA_real_,
                      stringsAsFactors = FALSE)
  }
  tab <- tab[order(tab$padj, tab$term_id, method = "radix"), , drop = FALSE]
  display <- limma_camera_display(input, method, design, contrast, block, cor, weights)
  show <- utils::head(tab$term_id, 2L)
  members <- lapply(stats::setNames(show, show), function(s) identifiers[index[[s]]])
  worms <- lapply(members, function(m) limma_camera_worm(display$stat, m))
  # Set counts (S5 R3): collection -> matched (ID overlap) -> selected for the
  # test -> actually tested. roast tests only the --set-id set; every other
  # matched set is "not selected", neither tested nor "without overlap".
  selected <- if (identical(method, "roast")) a[["set-id"]] else names(index)
  tested <- as.character(tab$term_id)
  if (anyDuplicated(tested) || !all(tested %in% selected) ||
      (identical(method, "roast") && length(tested) != 1L))
    stop("OS_RESULT_INCONSISTENT: tested gene-set identifiers do not match the selected test.", call. = FALSE)
  set_audit <- data.frame(
    term_id = names(collection$sets),
    collection_size = vapply(collection$sets, length, integer(1)),
    matched_size = vapply(collection$sets, function(x) sum(unique(x) %in% identifiers), integer(1)),
    matched = names(collection$sets) %in% names(index),
    selected = names(collection$sets) %in% selected,
    tested = names(collection$sets) %in% tested, stringsAsFactors = FALSE)
  set_audit$status <- ifelse(!set_audit$matched, "no_overlap",
                            ifelse(!set_audit$selected, "not_selected",
                                   ifelse(set_audit$tested, "tested", "selected_not_returned")))
  set_audit <- set_audit[order(set_audit$term_id, method = "radix"), , drop = FALSE]
  list(table = tab, raw_table = raw_df, set_audit = set_audit,
       tested_sets = tested, method = method, question = a$question,
       design = input$design, block_used = !is.null(block), correlation_used = cor,
       n_input_sets = length(collection$sets), n_matched_sets = length(index),
       n_excluded = length(collection$sets) - length(index), n_input_features = length(identifiers),
       selected_sets = selected, n_selected_sets = length(selected), n_tested_sets = nrow(tab),
       not_selected_sets = setdiff(names(index), selected),
       index = index, rng = rng, n_tied = if (is_rank) input$rank$n_tied else NA_integer_,
       input_kind = if (is_rank) "ranked_list" else "expression", display = display,
       figure_sets = members, worms = worms)
}
