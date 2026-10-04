SA_MODULE_VERSION <- "1.0.0"
SA_MODULE <- "singler-annotate"
singler_annotate_compute <- function(sce, ref, a) {
  if ((a[["de-method"]] %in% c("wilcox", "t") || a$unit == "cluster" || identical(a[["aggr-ref"]], "true")) && !requireNamespace("scrapper", quietly = TRUE)) {
    stop("OS_MISSING_DEPENDENCY: scrapper is absent from the locked image; reference marker/cluster recipe cannot execute.", call. = FALSE)
  }
  lab <- os_backend_column(ref, a[["reference-label-col"]])
  if (length(unique(lab)) < 2L) stop("OS_INVALID_INPUT: reference needs at least two labels.", call. = FALSE)
  if (!"logcounts" %in% SummarizedExperiment::assayNames(ref)) stop("OS_INVALID_INPUT: reference needs normalized logcounts.", call. = FALSE)
  shared <- intersect(rownames(sce), rownames(ref))
  if (!length(shared)) stop("OS_INVALID_INPUT: test and reference have no common features.", call. = FALSE)
  cl <- os_backend_column(sce, a[["cluster-col"]])
  opts_singler <- os_backend_function_options(SingleR::SingleR, a, "singler", list(test=sce, ref=ref, labels=lab, clusters=if(a$unit=="cluster") cl else NULL, de.method=a[["de-method"]], de.n=a[["de-n"]], aggr.ref=identical(a[["aggr-ref"]],"true"), fine.tune=identical(a[["fine-tune"]],"true"), quantile=a$quantile, tune.thresh=a[["tune-thresh"]], assay.type.test=a[["test-role"]], BPPARAM=BiocParallel::SerialParam()))
  pred <- SingleR::SingleR(test=opts_singler[["test"]], ref=opts_singler[["ref"]], labels=opts_singler[["labels"]], method=opts_singler[["method"]], clusters=opts_singler[["clusters"]], genes=opts_singler[["genes"]], sd.thresh=opts_singler[["sd.thresh"]], de.method=opts_singler[["de.method"]], de.n=opts_singler[["de.n"]], de.args=opts_singler[["de.args"]], aggr.ref=opts_singler[["aggr.ref"]], aggr.args=opts_singler[["aggr.args"]], recompute=opts_singler[["recompute"]], restrict=opts_singler[["restrict"]], hint.sce=opts_singler[["hint.sce"]], quantile=opts_singler[["quantile"]], fine.tune=opts_singler[["fine.tune"]], tune.thresh=opts_singler[["tune.thresh"]], fine.tune.combined=opts_singler[["fine.tune.combined"]], prune=opts_singler[["prune"]], assay.type.test=opts_singler[["assay.type.test"]], assay.type.ref=opts_singler[["assay.type.ref"]], check.missing.test=opts_singler[["check.missing.test"]], check.missing.ref=opts_singler[["check.missing.ref"]], check.missing=opts_singler[["check.missing"]], num.threads=opts_singler[["num.threads"]], BNPARAM=opts_singler[["BNPARAM"]], BPPARAM=opts_singler[["BPPARAM"]])
  opts_prune <- os_backend_function_options(SingleR::pruneScores, a, "prune", list(results=pred, nmads=a$nmads))
  pruned <- SingleR::pruneScores(results=opts_prune[["results"]], nmads=opts_prune[["nmads"]], min.diff.med=opts_prune[["min.diff.med"]], min.diff.next=opts_prune[["min.diff.next"]], get.thresholds=opts_prune[["get.thresholds"]])
  scores <- as.matrix(pred$scores)
  rownames(scores) <- rownames(pred)
  pl <- as.character(pred$labels); pl[pruned] <- NA_character_
  ii <- if (a$unit == "cluster") match(cl, rownames(pred)) else match(colnames(sce), rownames(pred))
  if (anyNA(ii)) stop("OS_DEGENERATE: predictions do not align with cell IDs.", call. = FALSE)
  best <- scores[cbind(seq_len(nrow(scores)), match(pred$labels, colnames(scores)))]
  runner <- apply(scores, 1L, function(z) sort(z, decreasing = TRUE)[2L])
  annotations <- data.frame(cell_id = colnames(sce), cluster = cl, label = pred$labels[ii],
    pruned_label = pl[ii], best_score = best[ii], runner_up_score = runner[ii], delta_next = pred$delta.next[ii],
    reference = a[["reference-name"]], reference_version = a[["reference-version"]], species = a$species,
    assay = a[["test-role"]], unit = a$unit)
  cross <- as.matrix(table(cl, ifelse(is.na(pl[ii]), "Unassigned", pl[ii])))
  storage.mode(cross) <- "double"
  sce$singler_label <- as.character(pred$labels[ii]); sce$singler_pruned_label <- pl[ii]
  list(sce = sce, prediction = pred, scores = scores, annotations = annotations, cross = cross,
       resolved = list(SingleR=opts_singler[setdiff(names(opts_singler),c("test","ref","labels","BPPARAM","BNPARAM"))],pruneScores=opts_prune[setdiff(names(opts_prune),"results")]),
       n_cells = ncol(sce), n_assigned = sum(!is.na(pl[ii])), n_common = length(shared))
}
