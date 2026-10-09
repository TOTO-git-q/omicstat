# enrich_rank_io.R -- M2b ranked-list and offline gene-set contract.
# Registered collections only: the KEGG term-ID exclusion below covers bundled
# or registered content. User-supplied local GMT files go through
# user_genesets.R, which never applies it.

os_rank_read <- function(path) {
  if (!file.exists(path)) stop("OS_MISSING_INPUT: ranked_list file is missing.", call. = FALSE)
  d <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!identical(names(d), c("feature_id", "symbol", "score")))
    stop("OS_HANDOFF_MISMATCH: ranked_list must have exactly feature_id,symbol,score columns.", call. = FALSE)
  if (!nrow(d) || anyNA(d$feature_id) || any(!nzchar(d$feature_id)) || anyDuplicated(d$feature_id))
    stop("OS_INVALID_INPUT: ranked feature_id values must be nonempty and unique.", call. = FALSE)
  if (!is.numeric(d$score) || any(!is.finite(d$score)))
    stop("OS_INVALID_INPUT: ranking scores must be finite numbers.", call. = FALSE)
  if (is.unsorted(-d$score, strictly = FALSE))
    stop("OS_INVALID_INPUT: ranked_list scores must be sorted descending.", call. = FALSE)
  list(table = d, stats = stats::setNames(d$score, d$feature_id),
       n_tied = sum(duplicated(d$score)), n_zero = sum(d$score == 0))
}

os_refdata_entry <- function(suite, id) {
  reg <- jsonlite::fromJSON(file.path(suite, "env", "refdata_registry.json"), simplifyVector = FALSE)
  hits <- Filter(function(e) identical(e$id, id) && is.null(e$tier), reg$entries)
  if (length(hits) != 1L) stop(sprintf(paste0("OS_REFDATA_MISSING: collection '%s' is not a locked-container registry entry. ",
                                              "omicstat never bundles or downloads KEGG, MSigDB, PanglaoDB or similar gene sets; ",
                                              "a local GMT you obtained yourself runs with --collection user --gene-sets <file.gmt> ",
                                              "plus --gene-sets-provenance <json> (or --gene-sets-source, --gene-sets-version and ",
                                              "--gene-sets-id-type) and --feature-id-type."), id), call. = FALSE)
  e <- hits[[1L]]
  if (is.null(e$version) || startsWith(e$version, "TO_FILL") || is.null(e$sha256) || startsWith(e$sha256, "TO_FILL"))
    stop(sprintf("OS_REFDATA_MISSING: collection '%s' lacks a resolved version or hash in the locked registry.", id), call. = FALSE)
  if (is.null(e$species) || !nzchar(e$species))
    stop(sprintf("OS_REFDATA_MISSING: collection '%s' lacks a registered species.", id), call. = FALSE)
  e
}

os_gmt_read <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  cells <- strsplit(lines, "\t", fixed = TRUE)
  if (!length(cells) || any(lengths(cells) < 3L)) stop("OS_INVALID_INPUT: GMT needs term, description, and gene IDs.", call. = FALSE)
  ids <- vapply(cells, `[[`, "", 1L)
  if (any(!nzchar(ids)) || anyDuplicated(ids) || any(grepl("KEGG", ids, ignore.case = TRUE)))
    stop("OS_INVALID_INPUT: GMT has empty/duplicate term IDs or excluded KEGG content.", call. = FALSE)
  stats::setNames(lapply(cells, function(x) unique(x[-c(1L, 2L)][nzchar(x[-c(1L, 2L)])])), ids)
}

os_genesets_read <- function(suite, id, path = NULL) {
  e <- os_refdata_entry(suite, id)
  if (identical(e$asset, "package:fgsea:examplePathways") || identical(e$asset, "acceptance:GSVAdata:brainTxDbSets") ||
      identical(e$asset, "acceptance:limma:GenderGenes")) {
    if (!is.null(path)) stop("OS_CONFLICTING_PARAMETERS: package collection takes no --gene-sets path.", call. = FALSE)
    if (identical(e$asset, "package:fgsea:examplePathways")) {
      env <- new.env(parent = emptyenv())
      utils::data("examplePathways", package = "fgsea", envir = env)
      sets <- env$examplePathways
      description <- "fgsea 1.38.0 examplePathways"
    } else if (identical(e$asset, "acceptance:GSVAdata:brainTxDbSets")) {
      sets <- os_acceptance_data(suite, "GSVAdata", "brainTxDbSets")
      if (is.null(sets)) stop("OS_REFDATA_MISSING: sha256-locked GSVAdata acceptance layer is unavailable.", call. = FALSE)
      description <- "GSVAdata 1.48.1 brainTxDbSets"
    } else {
      f <- file.path(suite, "acceptance", "data", "limma_GenderGenes.RData")
      if (!file.exists(f)) stop("OS_REFDATA_MISSING: GenderGenes offline acceptance file is missing.", call. = FALSE)
      if (!identical(digest::digest(file = f, algo = "sha256"), e$source_sha256))
        stop("OS_REFDATA_MISMATCH: GenderGenes source file hash differs from registry.", call. = FALSE)
      env <- new.env(parent = emptyenv())
      load(f, envir = env)
      sets <- list(Y = env$msYgenes, X = env$XiEgenes)
      description <- "limma GenderGenes User Guide 18.1.10"
    }
    lines <- vapply(sort(names(sets), method = "radix"), function(n)
      paste(c(n, description, sort(unique(as.character(sets[[n]])), method = "radix")), collapse = "\t"), "")
    got <- digest::digest(paste(lines, collapse = "\n"), algo = "sha256", serialize = FALSE)
  } else {
    if (is.null(path)) stop(sprintf("OS_REFDATA_MISSING: collection '%s' needs its registered local GMT file.", id), call. = FALSE)
    got <- digest::digest(file = path, algo = "sha256")
    sets <- os_gmt_read(path)
  }
  if (!identical(got, e$sha256)) stop(sprintf("OS_REFDATA_MISMATCH: collection '%s' hash differs from registry.", id), call. = FALSE)
  if (any(grepl("KEGG", names(sets), ignore.case = TRUE))) stop("OS_REFDATA_MISSING: KEGG content is excluded.", call. = FALSE)
  list(sets = sets, entry = e, sha256 = got)
}
