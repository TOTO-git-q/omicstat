CG_MODULE <- "clusterprofiler-gsea"
CG_MODULE_VERSION <- "1.1.0"

cg_read_ranked <- function(path) {
  d <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!all(c("feature_id", "score") %in% names(d))) stop("OS_MISSING_COLUMN: ranked input needs feature_id and score.", call. = FALSE)
  if (anyNA(d$feature_id) || any(!nzchar(d$feature_id)) || anyDuplicated(d$feature_id))
    stop("OS_INVALID_INPUT: ranked feature IDs must be nonempty and unique.", call. = FALSE)
  v <- suppressWarnings(as.numeric(d$score))
  if (anyNA(v) || any(!is.finite(v))) stop("OS_INVALID_INPUT: every ranked score must be finite.", call. = FALSE)
  # Directionality is a property of the statistic and its contrast (S1 P-1),
  # not of the observed signs: a one-sided single-contrast Wald/t/LFC ranking
  # is valid input (S3 F2); undirectional LRT/F are refused from metadata or
  # the declared metric name.
  v <- stats::setNames(v, as.character(d$feature_id))
  v[order(-v, names(v), method = "radix")]
}

# Ranking semantics (S1 P-1; S4 contract a): consumed from the upstream
# ranked_list metadata or declared explicitly on the command line; never
# inferred from the producer module's name.
cg_input <- function(a, upstream = NULL) {
  if (is.null(upstream)) {
    side <- sub("[.]csv$", ".meta.json", a$ranked)
    meta <- NULL
    if (file.exists(side)) meta <- os_ranked_list_meta_check(jsonlite::fromJSON(side, simplifyVector = TRUE))
    if (!is.null(meta) && (!identical(a[["ranking-metric"]], meta$metric) || !identical(a$direction, meta$positive_end)))
      stop("OS_CONFLICTING_PARAMETERS: --ranking-metric/--direction disagree with the ranked list's omicstat metadata.", call. = FALSE)
    kind <- a[["statistic-kind"]]
    if (identical(kind, "effect_size") && is.null(a[["lfc-type"]]))
      stop("OS_MISSING_PARAMETER: an effect-size ranking needs --lfc-type (e.g. 'DESeq2 MLE log2 fold change', 'apeglm shrunken').", call. = FALSE)
    if (identical(kind, "test_statistic") && !is.null(a[["lfc-type"]]))
      stop("OS_CONFLICTING_PARAMETERS: --lfc-type applies only to --statistic-kind effect_size.", call. = FALSE)
    return(list(scores = cg_read_ranked(a$ranked), metric = a[["ranking-metric"]], direction = a$direction,
                negative_end = sprintf("the opposite of: %s", a$direction), statistic_kind = kind,
                lfc_type = a[["lfc-type"]] %||% NA_character_, contrast = meta$contrast %||% "declared by the user",
                source = if (is.null(meta)) "user-declared" else "omicstat ranked_list metadata (sidecar)",
                inputs = list(ranked = a$ranked)))
  }
  meta <- os_ranked_list_meta(upstream)
  o <- upstream$objects$ranked_list
  list(scores = cg_read_ranked(o$path), metric = meta$metric, direction = meta$positive_end,
       negative_end = meta$negative_end, statistic_kind = meta$statistic_kind,
       lfc_type = if (is.null(meta$lfc_type)) NA_character_ else meta$lfc_type, contrast = meta$contrast,
       source = sprintf("ranked_list metadata of upstream %s %s", upstream$module, upstream$module_version),
       inputs = list(ranked = o$path))
}

cg_compute <- function(x, a, coll = NULL) {
  if (identical(a$database, "custom")) return(cg_compute_custom(x, a, coll))
  if (a$database != "GO") stop(os_user_genesets_not_bundled(a$database, "--database custom"), call. = FALSE)
  ans <- clusterProfiler::gseGO(geneList = x$scores, ont = a$ontology,
    OrgDb = org.Hs.eg.db::org.Hs.eg.db, keyType = a[["key-type"]],
    exponent = 1, minGSSize = a[["min-size"]], maxGSSize = a[["max-size"]],
    pvalueCutoff = 1, pAdjustMethod = "BH", verbose = FALSE, nPerm = 1000,
    method = "multilevel", adaptive = FALSE, minPerm = 101, maxPerm = 1e5,
    pvalThreshold = 0.1)
  if (is.null(ans)) stop("OS_EMPTY_DATA: no testable GO set overlaps the ranked IDs at these sizes.", call. = FALSE)
  raw <- as.data.frame(ans)
  if (!nrow(raw)) stop("OS_EMPTY_DATA: GSEA returned no testable terms.", call. = FALSE)
  list(result = ans, raw = raw)
}

# User-supplied collection: clusterProfiler's generic GSEA with TERM2GENE and
# TERM2NAME, with the same multilevel arguments as the GO route.
cg_compute_custom <- function(x, a, coll) {
  tg <- os_user_genesets_term2gene(coll)
  ans <- clusterProfiler::GSEA(geneList = x$scores, exponent = 1, minGSSize = a[["min-size"]], maxGSSize = a[["max-size"]],
    pvalueCutoff = 1, pAdjustMethod = "BH", gson = NULL, TERM2GENE = tg$TERM2GENE, TERM2NAME = tg$TERM2NAME,
    verbose = FALSE, nPerm = 1000, method = "multilevel", adaptive = FALSE, minPerm = 101, maxPerm = 1e5,
    pvalThreshold = 0.1)
  if (is.null(ans)) stop("OS_EMPTY_DATA: no testable user gene set overlaps the ranked IDs at these sizes.", call. = FALSE)
  raw <- as.data.frame(ans)
  if (!nrow(raw)) stop("OS_EMPTY_DATA: GSEA returned no testable user gene sets.", call. = FALSE)
  list(result = ans, raw = raw)
}
