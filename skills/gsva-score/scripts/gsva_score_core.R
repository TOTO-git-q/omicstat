GV_MODULE <- "gsva-score"
GV_MODULE_VERSION <- "1.1.0"

# S4 F1: this module scores and hands on only. Group inference on GSVA scores
# (which limma entry receives the scores, eBayes trend / robust / gene-set
# size trend) is an owner-pending S1 P-3 decision; a request for it is refused
# with OS_OWNER_DECISION_PENDING before any computation (run_gsva_score.R).

gsva_score_kernel <- function(a, mat) {
  if (a$kcdf != "auto") return(a$kcdf)
  if (ncol(mat) >= 200L) return("none")
  if (a[["input-scale"]] == "counts") return("Poisson")
  "Gaussian"
}

# Rows GSVA's filterRows = TRUE removes for a dense, finite matrix: rows whose
# minimum equals their maximum (GSVA 2.6.6 .filterGenes, constant rows; the
# nonzero-constant rule applies to sparse input only). Used only to explain
# exclusions; the sizes actually used are read back from GSVA itself.
gsva_score_constant_rows <- function(mat) {
  rng <- apply(mat, 1, range)
  rownames(mat)[rng[1, ] == rng[2, ]]
}

# S4 F3: per-set table from the collection, the expression IDs, the constant
# rows GSVA removes, and GSVA's own filtered gene sets (geneSets() /
# geneSetSizes() on the returned score matrix).
gsva_score_set_table <- function(sets, mat, constant, used_sets, a) {
  genes <- rownames(mat)
  kept_genes <- setdiff(genes, constant)
  ids <- sort(names(sets), method = "radix")
  n_coll <- vapply(ids, function(s) length(unique(as.character(sets[[s]]))), 0L)
  n_ids <- vapply(ids, function(s) length(intersect(unique(as.character(sets[[s]])), genes)), 0L)
  n_filt <- vapply(ids, function(s) length(intersect(unique(as.character(sets[[s]])), kept_genes)), 0L)
  scored <- ids %in% names(used_sets)
  n_used <- vapply(ids, function(s) if (s %in% names(used_sets)) length(used_sets[[s]]) else NA_integer_, 0L)
  reason <- ifelse(scored, "scored",
            ifelse(n_ids == 0L, "no member matches an expression feature ID",
            ifelse(n_filt < a[["min-size"]] & n_ids >= a[["min-size"]],
                   sprintf("fewer than %d members after GSVA removed constant-expression rows (filterRows)", a[["min-size"]]),
            ifelse(n_filt < a[["min-size"]], sprintf("fewer than %d members match expression feature IDs", a[["min-size"]]),
            ifelse(n_filt > a[["max-size"]], sprintf("more than %d members after ID intersection and constant-row removal", a[["max-size"]]),
                   "not returned by GSVA")))))
  data.frame(term_id = ids, n_collection = unname(n_coll), n_matched_ids = unname(n_ids),
             n_after_constant_filter = unname(n_filt), n_used_by_gsva = unname(n_used),
             status = ifelse(scored, "retained", "excluded"), reason = unname(reason),
             stringsAsFactors = FALSE, row.names = NULL)
}

gsva_score_compute <- function(mat, collection, a) {
  constant <- gsva_score_constant_rows(mat)
  kept_genes <- setdiff(rownames(mat), constant)
  size <- lengths(lapply(collection$sets, function(s) intersect(unique(as.character(s)), kept_genes)))
  if (!any(size >= a[["min-size"]] & size <= a[["max-size"]]))
    stop("OS_EMPTY_DATA: no set remains after gene ID intersection, constant-row removal and size filtering.", call. = FALSE)
  set.seed(a$seed)
  param <- GSVA::gsvaParam(exprData = mat, geneSets = collection$sets,
                           assay = NA_character_, annotation = NULL,
                           minSize = a[["min-size"]], maxSize = a[["max-size"]],
                           kcdf = a$kcdf, kcdfNoneMinSampleSize = 200,
                           tau = 1, maxDiff = TRUE, absRanking = FALSE,
                           sparse = TRUE, checkNA = "auto", use = "everything",
                           filterRows = TRUE, ondisk = "auto", verbose = FALSE)
  scores <- GSVA::gsva(param = param, verbose = FALSE,
                       BPPARAM = BiocParallel::SerialParam(progressbar = FALSE, RNGseed = a$seed))
  used_sets <- GSVA::geneSets(scores)
  used_sizes <- GSVA::geneSetSizes(scores)
  if (!is.matrix(scores)) scores <- as.matrix(scores)
  scores <- scores[sort(rownames(scores), method = "radix"), colnames(mat), drop = FALSE]
  if (any(!is.finite(scores))) stop("OS_INVALID_RESULT: GSVA returned nonfinite scores.", call. = FALSE)
  sets_tab <- gsva_score_set_table(collection$sets, mat, constant, used_sets, a)
  chk <- sets_tab[sets_tab$status == "retained", , drop = FALSE]
  if (!setequal(chk$term_id, rownames(scores)) ||
      any(chk$n_used_by_gsva != unname(used_sizes[chk$term_id])) ||
      any(chk$n_used_by_gsva != chk$n_after_constant_filter))
    stop("OS_INVALID_RESULT: GSVA's filtered gene-set sizes disagree with the ID intersection after constant-row removal.", call. = FALSE)
  list(scores = scores, param = param, kernel = gsva_score_kernel(a, mat), set_table = sets_tab,
       n_input_sets = length(collection$sets), n_retained = sum(sets_tab$status == "retained"),
       n_excluded = sum(sets_tab$status == "excluded"), n_scored = nrow(scores),
       n_constant_rows = length(constant), input_storage = typeof(mat), n_input_features = nrow(mat))
}
