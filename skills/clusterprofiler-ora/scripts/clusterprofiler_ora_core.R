# clusterprofiler_ora_core.R -- GO ORA with an explicit selection universe.
CO_MODULE <- "clusterprofiler-ora"
CO_VERSION <- "1.1.0"
CO_MODULE_VERSION <- "1.1.0"

co_read_ids <- function(path, column, label) {
  d <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!column %in% names(d)) stop(sprintf("OS_MISSING_COLUMN: %s needs '%s'.", label, column), call. = FALSE)
  x <- trimws(as.character(d[[column]]))
  if (anyNA(x) || any(!nzchar(x))) stop(sprintf("OS_INVALID_INPUT: %s contains empty IDs.", label), call. = FALSE)
  if (anyDuplicated(x)) stop(sprintf("OS_INVALID_INPUT: %s contains duplicate IDs.", label), call. = FALSE)
  x
}

co_input <- function(a, upstream = NULL) {
  if (!is.null(upstream)) {
    o <- upstream$objects$feature_table
    if (is.null(o) || !identical(o$type, "feature_table"))
      stop("OS_HANDOFF_MISMATCH: upstream needs a feature_table.", call. = FALSE)
    d <- utils::read.csv(o$path, check.names = FALSE, stringsAsFactors = FALSE)
    if (!all(c("feature_id", "padj") %in% names(d)))
      stop("OS_MISSING_COLUMN: upstream feature table needs feature_id and padj.", call. = FALSE)
    if (anyDuplicated(d$feature_id)) stop("OS_INVALID_INPUT: duplicate upstream feature IDs.", call. = FALSE)
    eligible <- !is.na(d$padj) & is.finite(d$padj)
    universe <- as.character(d$feature_id[eligible])
    genes <- as.character(d$feature_id[eligible & d$padj < a$alpha])
    origin <- sprintf("%s feature_table, padj < %s; universe is rows with finite padj", upstream$module, a$alpha)
    return(list(genes = genes, universe = universe, origin = origin,
                inputs = list(feature_table = o$path)))
  }
  genes <- co_read_ids(a$input, a[["id-column"]], "--input")
  universe <- co_read_ids(a$universe, a[["id-column"]], "--universe")
  list(genes = genes, universe = universe, origin = a[["selection-rule"]],
       inputs = list(input = a$input, universe = a$universe))
}

co_validate <- function(x, a) {
  if (!length(x$universe)) stop("OS_INVALID_UNIVERSE: no eligible background genes.", call. = FALSE)
  if (!length(x$genes)) stop("OS_EMPTY_DATA: no selected input genes.", call. = FALSE)
  if (!all(x$genes %in% x$universe))
    stop("OS_INVALID_UNIVERSE: every selected gene must belong to the eligible universe.", call. = FALSE)
  if (setequal(x$genes, x$universe))
    stop("OS_INVALID_UNIVERSE: selected genes cannot themselves be the whole background.", call. = FALSE)
  if (a$ontology == "ALL" && is.null(a$pool))
    stop("OS_MISSING_PARAMETER: ontology ALL requires an explicit --pool value.", call. = FALSE)
  if (a$ontology != "ALL" && !is.null(a$pool))
    stop("OS_CONFLICTING_PARAMETERS: --pool is only used for ontology ALL.", call. = FALSE)
  if (!a[["key-type"]] %in% AnnotationDbi::keytypes(org.Hs.eg.db::org.Hs.eg.db))
    stop("OS_INVALID_PARAMETER: --key-type is not supported by org.Hs.eg.db.", call. = FALSE)
  invisible(TRUE)
}

co_compute <- function(x, a) {
  if (a$database != "GO") stop("OS_REFDATA_MISSING: this collection is not pinned for offline use in the locked container.", call. = FALSE)
  ans <- clusterProfiler::enrichGO(gene = x$genes, OrgDb = org.Hs.eg.db::org.Hs.eg.db,
    keyType = a[["key-type"]], ont = a$ontology, pvalueCutoff = 1,
    pAdjustMethod = "BH", universe = x$universe, qvalueCutoff = 1,
    minGSSize = a[["min-size"]], maxGSSize = a[["max-size"]],
    readable = FALSE, pool = if (a$ontology == "ALL") a$pool else FALSE)
  if (is.null(ans)) stop("OS_EMPTY_DATA: no GO term had a testable overlap with the supplied genes and universe.", call. = FALSE)
  raw <- as.data.frame(ans)
  if (!nrow(raw)) stop("OS_EMPTY_DATA: no GO term remained after set-size and mapping filters.", call. = FALSE)
  simp <- NULL; relation <- NULL; sim_source <- NULL
  if (a$simplify) {
    cap <- co_capture_similarity()
    s <- clusterProfiler::simplify(x = ans, cutoff = 0.7, by = "p.adjust",
                                   select_fun = min, measure = "Wang", semData = NULL)
    sims <- cap$stop()
    simp <- as.data.frame(s)
    rel <- co_simplify_relation(raw, simp, sims, cutoff = 0.7, ontology = a$ontology)
    relation <- rel$relation; sim_source <- rel$source
  }
  mapped <- AnnotationDbi::keys(org.Hs.eg.db::org.Hs.eg.db, keytype = a[["key-type"]])
  effective_background <- intersect(x$universe, mapped)
  effective_input <- intersect(x$genes, effective_background)
  fam <- co_families(raw, a)
  single <- nrow(fam$table) == 1L
  list(result = ans, raw = raw, simplified = simp, relation = relation, similarity_source = sim_source,
       families = fam$table, family = fam$row_family, symbols = co_symbols(x, a),
       n_candidate = length(x$universe), n_input = length(x$genes),
       n_mapped_background = length(effective_background), n_mapped_input = length(effective_input),
       n_effective_background = if (single) fam$table$n_effective_background else NA_integer_,
       n_effective = if (single) fam$table$n_effective_input else NA_integer_)
}

# Testing families (cross-module contract d). enrichGO(ont = "ALL",
# pool = FALSE) calls enrichGO once per ontology (clusterProfiler 4.20.0
# source), so BP, CC and MF each have their own effective input, background
# and BH family. pool = TRUE and a single ontology are one family. Each
# family's denominators must be unique and its p.adjust must equal BH over
# that family alone; otherwise the result is refused.
co_families <- function(raw, a) {
  per_ont <- identical(a$ontology, "ALL") && isFALSE(a$pool)
  lab <- if (per_ont) paste("GO", as.character(raw$ONTOLOGY)) else
    rep(if (identical(a$ontology, "ALL")) "GO ALL pooled" else paste("GO", a$ontology), nrow(raw))
  den <- function(z) as.integer(vapply(strsplit(as.character(z), "/", fixed = TRUE), `[`, "", 2))
  fams <- intersect(c("GO BP", "GO CC", "GO MF", "GO ALL pooled"), unique(lab))
  rows <- lapply(fams, function(f) {
    i <- lab == f
    gi <- unique(den(raw$GeneRatio[i])); bi <- unique(den(raw$BgRatio[i]))
    if (length(gi) != 1L || length(bi) != 1L)
      stop(sprintf("OS_INVALID_RESULT: terms of testing family %s disagree on effective input or background denominator.", f), call. = FALSE)
    if (max(abs(stats::p.adjust(raw$pvalue[i], method = "BH") - raw$p.adjust[i])) > 1e-12)
      stop(sprintf("OS_INVALID_RESULT: adjusted P of %s is not BH over that family.", f), call. = FALSE)
    scope <- if (per_ont) sprintf("BH over the %d tested %s terms only (pool = FALSE: one enrichGO test per ontology)", sum(i), f) else
      if (identical(f, "GO ALL pooled")) sprintf("BH over all %d tested BP, CC and MF terms together (pool = TRUE)", sum(i)) else
        sprintf("BH over the %d tested %s terms", sum(i), f)
    data.frame(test_family = f, n_effective_input = gi, n_effective_background = bi,
               n_tested_terms = sum(i), adjustment_scope = scope, stringsAsFactors = FALSE)
  })
  list(table = do.call(rbind, rows), row_family = lab)
}

# Symbol mapping supplement (PACK T). enrichit::EXTID2NAME is the mapping
# function that setReadable uses: first symbol per ID, unmapped IDs kept.
co_symbols <- function(x, a) {
  kt <- a[["key-type"]]
  if (identical(kt, "SYMBOL"))
    return(data.frame(feature_id = x$genes, symbol = x$genes, mapping = "input is SYMBOL", stringsAsFactors = FALSE))
  gn <- enrichit::EXTID2NAME(OrgDb = org.Hs.eg.db::org.Hs.eg.db, geneID = x$genes, keytype = kt, toType = "SYMBOL")
  sym <- unname(gn[match(x$genes, names(gn))])
  status <- ifelse(is.na(sym), "no symbol in OrgDb", ifelse(sym == x$genes, "unmapped: original ID kept", "mapped"))
  data.frame(feature_id = x$genes, symbol = sym, mapping = status, stringsAsFactors = FALSE)
}

# Capture the Wang similarity matrices that clusterProfiler::simplify itself
# computes (mgoSim, one call per ontology), so that the merged-term relation
# is derived from the package's own numbers without a second pass.
co_capture_similarity <- function() {
  env <- new.env(parent = emptyenv()); env$sims <- list()
  where <- asNamespace("clusterProfiler")
  ok <- tryCatch({
    suppressMessages(trace("mgoSim", where = where, print = FALSE,
      exit = bquote(assign("sims", c(get("sims", envir = .(env)), list(returnValue())), envir = .(env)))))
    TRUE
  }, error = function(e) FALSE)
  list(stop = function() {
    if (ok) suppressMessages(untrace("mgoSim", where = where))
    if (ok && length(env$sims)) env$sims else NULL
  })
}

# Merged term -> representative term, replaying the selection loop of
# clusterProfiler:::simplify_internal (locked 4.20.0) on the same similarity
# matrices: for each term (in result order) the terms with Wang similarity
# > cutoff to it form a group; the member with the smallest p.adjust is kept
# (ties: most GO ancestors, as the package does) and the others are removed.
# ALL results are simplified per ontology (simplify_ALL). The reconstructed
# kept set must equal the package output exactly, otherwise refuse.
co_simplify_relation <- function(res, simp, sims, cutoff, ontology) {
  onts <- if ("ONTOLOGY" %in% names(res)) unique(as.character(res$ONTOLOGY)) else ontology
  subs <- lapply(onts, function(o) if ("ONTOLOGY" %in% names(res)) res[res$ONTOLOGY == o, , drop = FALSE] else res)
  source <- "captured from clusterProfiler::simplify"
  if (is.null(sims) || length(sims) != length(onts)) {
    source <- "recomputed with GOSemSim::mgoSim (capture unavailable)"
    sims <- lapply(seq_along(onts), function(k) GOSemSim::mgoSim(subs[[k]]$ID, subs[[k]]$ID,
      semData = GOSemSim::godata(ont = onts[k]), measure = "Wang", combine = NULL))
  }
  kept_all <- character(); rows <- list()
  for (k in seq_along(onts)) {
    ont <- onts[k]; sub <- subs[[k]]; sim <- sims[[k]]
    if (!setequal(rownames(sim), sub$ID))
      stop("OS_INVALID_RESULT: captured similarity matrix does not match the simplified ontology.", call. = FALSE)
    anc <- GOSemSim:::getAncestors(ont)
    removed <- character(); first <- list(); n_events <- list()
    for (id in sub$ID) {
      col <- sim[, id]
      members <- sort(names(col)[!is.na(col) & col > cutoff], method = "radix")
      if (length(members) < 2L) next
      pa <- sub$p.adjust[match(members, sub$ID)]
      rep <- members[pa == min(pa)]
      if (length(rep) > 1L) rep <- rep[which.max(vapply(rep, function(z) length(anc[[z]]), numeric(1)))]
      for (m in setdiff(members, rep)) {
        n_events[[m]] <- (if (is.null(n_events[[m]])) 0L else n_events[[m]]) + 1L
        if (is.null(first[[m]])) first[[m]] <- list(anchor = id, rep = rep, sim = unname(col[m]))
      }
      removed <- unique(c(removed, setdiff(members, rep)))
    }
    kept <- sub$ID[!sub$ID %in% removed]
    kept_all <- c(kept_all, kept)
    for (m in sub$ID[sub$ID %in% removed]) {
      f <- first[[m]]
      rows[[length(rows) + 1L]] <- data.frame(
        ontology = ont, merged_term = m, merged_term_name = sub$Description[match(m, sub$ID)],
        merged_padj = sub$p.adjust[match(m, sub$ID)], representative_term = f$rep,
        representative_term_name = sub$Description[match(f$rep, sub$ID)],
        representative_padj = sub$p.adjust[match(f$rep, sub$ID)],
        representative_retained = f$rep %in% kept, group_anchor_term = f$anchor,
        wang_similarity_to_anchor = f$sim, n_removal_events = n_events[[m]], stringsAsFactors = FALSE)
    }
  }
  if (!identical(kept_all, as.character(simp$ID)))
    stop("OS_INVALID_RESULT: reconstructed simplify relation disagrees with clusterProfiler::simplify output.", call. = FALSE)
  rel <- if (length(rows)) do.call(rbind, rows) else data.frame(
    ontology = character(), merged_term = character(), merged_term_name = character(), merged_padj = numeric(),
    representative_term = character(), representative_term_name = character(), representative_padj = numeric(),
    representative_retained = logical(), group_anchor_term = character(), wang_similarity_to_anchor = numeric(),
    n_removal_events = integer())
  list(relation = rel, source = source)
}
