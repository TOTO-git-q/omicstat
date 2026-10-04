# ranked_list.R -- the ranked_list hand-off contract (S4, cross-module).
# ASCII only on purpose.
#
# MODULE_BUILD_BRIEF sec 3 froze the FILE: csv `feature_id,symbol,score`
# sorted by score descending, score = Wald / moderated t statistic. SUITE
# "M1/M2 S1" cross-module rule 2 (owner 2026-09-27) froze the SEMANTICS: one
# upstream contrast produces one named, directional statistic (DESeq2 Wald
# `stat` / limma moderated t are the presets); an effect-size ranking must
# name the same explicit LFC type on both sides; LRT / multi-df F never give a
# directional ranking. The semantics travel as handoff state
# `ranked_list` (a named list, validated by os_ranked_list_meta_check()):
#   schema          "omicstat.ranked_list.v1"
#   metric          human-readable name, e.g. "DESeq2 Wald statistic"
#   statistic       machine name: wald_stat | moderated_t | treat_moderated_t | log2fc
#   statistic_kind  "test_statistic" | "effect_size"
#   lfc_type        NA for a test statistic; for an effect size the named LFC
#                   type (e.g. "DESeq2 MLE", "apeglm shrunken", "limma logFC")
#   directional     TRUE (a producer never writes an undirectional ranking)
#   contrast        "<condition>: <target> vs <reference>"
#   positive_end    what a positive score means, e.g. "higher in treated than untreated"
#   negative_end    idem for a negative score
#   null_test       "zero_effect" or "minimum_effect (lfcThreshold = x)"
#   universe        which features were ranked (and why others were not)
#   n_ranked, n_excluded_nonfinite, n_ties
#   producer        module name; producer_version
#   id_type         what feature_id is (e.g. "feature_id of the input matrix")
# The metadata is also written next to the csv as <name>.meta.json so a
# user-supplied --ranked file from an omicstat run keeps its meaning.

OS_RANKED_LIST_SCHEMA <- "omicstat.ranked_list.v1"
OS_RANKED_STATISTICS <- c("wald_stat", "moderated_t", "treat_moderated_t", "log2fc")
OS_RANKED_REQUIRED <- c("schema", "metric", "statistic", "statistic_kind", "lfc_type", "directional", "contrast",
                        "positive_end", "negative_end", "null_test", "universe", "n_ranked",
                        "n_excluded_nonfinite", "n_ties", "producer", "producer_version", "id_type")

# Write the ranked list and its sidecar metadata. feature_id / symbol / score
# are parallel vectors over the producer's full tested set; non-finite scores
# are excluded (counted), ties are broken by feature_id (radix) so the file is
# deterministic. Returns list(path, meta_path, meta).
os_ranked_list_write <- function(path, feature_id, symbol, score, meta) {
  feature_id <- as.character(feature_id)
  symbol <- if (is.null(symbol)) rep("", length(feature_id)) else as.character(symbol)
  symbol[is.na(symbol)] <- ""
  if (length(symbol) != length(feature_id) || length(score) != length(feature_id))
    stop("OS_INVALID_INPUT: ranked_list vectors differ in length.", call. = FALSE)
  if (anyNA(feature_id) || any(!nzchar(feature_id)) || anyDuplicated(feature_id))
    stop("OS_INVALID_INPUT: ranked_list feature IDs must be nonempty and unique.", call. = FALSE)
  ok <- is.finite(score)
  d <- data.frame(feature_id = feature_id[ok], symbol = symbol[ok], score = as.numeric(score[ok]), stringsAsFactors = FALSE)
  d <- d[order(-d$score, d$feature_id, method = "radix"), , drop = FALSE]
  if (!nrow(d)) stop("OS_EMPTY_DATA: no finite score to rank.", call. = FALSE)
  meta$schema <- OS_RANKED_LIST_SCHEMA
  meta$n_ranked <- nrow(d)
  meta$n_excluded_nonfinite <- sum(!ok)
  meta$n_ties <- sum(duplicated(d$score))
  meta$directional <- isTRUE(meta$directional)
  if (is.null(meta$lfc_type)) meta$lfc_type <- NA_character_
  os_ranked_list_meta_check(meta, where = "producer")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(d, path, row.names = FALSE)
  meta <- meta[OS_RANKED_REQUIRED]
  mp <- sub("[.]csv$", ".meta.json", path)
  js <- jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = I(10))
  con <- file(mp, open = "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(js, "\n"))), con)
  list(path = path, meta_path = mp, meta = meta)
}

# Validate ranked_list metadata (producer side or consumer side). Typed errors:
#   OS_HANDOFF_MISMATCH       metadata missing or malformed
#   OS_RANKING_UNDIRECTIONAL  not a directional statistic
os_ranked_list_meta_check <- function(meta, where = "consumer") {
  if (is.null(meta) || !is.list(meta))
    stop("OS_HANDOFF_MISMATCH: the ranked_list carries no metadata (metric, statistic, contrast, direction); it cannot be used without guessing.", call. = FALSE)
  miss <- setdiff(OS_RANKED_REQUIRED, names(meta))
  if (length(miss)) stop(sprintf("OS_HANDOFF_MISMATCH: ranked_list metadata lacks %s.", paste(miss, collapse = ", ")), call. = FALSE)
  if (!identical(meta$schema, OS_RANKED_LIST_SCHEMA)) stop("OS_HANDOFF_MISMATCH: unknown ranked_list metadata schema.", call. = FALSE)
  if (!isTRUE(meta$directional))
    stop("OS_RANKING_UNDIRECTIONAL: the ranked_list is not a directional statistic (LRT / multi-df F cannot rank a directional GSEA).", call. = FALSE)
  if (!meta$statistic %in% OS_RANKED_STATISTICS)
    stop(sprintf("OS_HANDOFF_MISMATCH: ranked_list statistic '%s' is not one of %s.", meta$statistic, paste(OS_RANKED_STATISTICS, collapse = ", ")), call. = FALSE)
  if (!meta$statistic_kind %in% c("test_statistic", "effect_size"))
    stop("OS_HANDOFF_MISMATCH: ranked_list statistic_kind must be test_statistic or effect_size.", call. = FALSE)
  if (identical(meta$statistic_kind, "effect_size") && (is.null(meta$lfc_type) || is.na(meta$lfc_type) || !nzchar(meta$lfc_type)))
    stop("OS_HANDOFF_MISMATCH: an effect-size ranked_list must name its LFC type (S1 cross-module rule 2).", call. = FALSE)
  for (k in c("metric", "contrast", "positive_end", "negative_end", "universe", "producer"))
    if (!is.character(meta[[k]]) || length(meta[[k]]) != 1L || !nzchar(meta[[k]]))
      stop(sprintf("OS_HANDOFF_MISMATCH: ranked_list metadata field '%s' is empty.", k), call. = FALSE)
  invisible(meta)
}

# Consumer side: the metadata of an upstream run's ranked_list, from the
# handoff state (primary) or the sidecar file (must agree when both exist).
os_ranked_list_meta <- function(upstream) {
  o <- upstream$objects$ranked_list
  if (is.null(o)) stop("OS_HANDOFF_MISMATCH: upstream run has no ranked_list object.", call. = FALSE)
  if (!identical(o$type, "ranked_list")) stop("OS_HANDOFF_MISMATCH: object 'ranked_list' has the wrong type.", call. = FALSE)
  meta <- upstream$state$ranked_list
  side <- sub("[.]csv$", ".meta.json", o$path)
  if (file.exists(side)) {
    sm <- jsonlite::fromJSON(side, simplifyVector = TRUE)
    if (!is.null(meta) && !identical(as.character(sm$metric), as.character(meta$metric)))
      stop("OS_HANDOFF_MISMATCH: ranked_list sidecar metadata disagrees with the handoff state.", call. = FALSE)
    if (is.null(meta)) meta <- sm
  }
  if (!is.null(meta) && "lfc_type" %in% names(meta) && is.null(meta[["lfc_type"]])) meta["lfc_type"] <- list(NA_character_)
  os_ranked_list_meta_check(meta)
}

# One sentence for Methods: which ranking was used.
os_ranked_list_sentence <- function(meta) {
  sprintf(paste0("Features were ranked by the %s of the %s contrast from %s (%s; %d features ranked, %d excluded for a non-finite score, %d tied score(s)); ",
                 "a positive score means %s and a negative score means %s."),
          meta$metric, meta$contrast, meta$producer, meta$null_test, as.integer(meta$n_ranked), as.integer(meta$n_excluded_nonfinite),
          as.integer(meta$n_ties), meta$positive_end, meta$negative_end)
}
