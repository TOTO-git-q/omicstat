# user_genesets.R -- user-supplied local gene-set collections (GMT plus an
# optional provenance JSON). ASCII only on purpose. Contract: CONVENTIONS.md
# section "User-supplied gene-set collections".
#
# omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar
# content. A user may supply a local GMT that they obtained themselves (for
# example with the web app's public-data tool, or from the KEGG REST API under
# its academic terms). The suite then
#   1. checks the GMT format;
#   2. takes source, version and identifier type from the provenance JSON, or
#      from --gene-sets-source / --gene-sets-version / --gene-sets-id-type,
#      which are required without a provenance file and never guessed;
#   3. hashes the GMT at run time and refuses a provenance sha256 mismatch;
#   4. refuses an identifier type that differs from the analysis key type (no
#      silent conversion), a species that differs from a known analysis
#      species, and a tiny overlap with the analysed universe;
#   5. records the collection in provenance/user_gene_sets.json, in
#      provenance.json and as one Methods sentence.
# The KEGG term-ID exclusion of enrich_rank_io.R (os_gmt_read and
# os_genesets_read) applies to registered collections only and is never
# applied here.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

OS_USER_GENESETS_ID_TYPES <- c("ENTREZID", "SYMBOL", "ENSEMBL")
OS_USER_GENESETS_MIN_OVERLAP <- 0.10
OS_USER_GENESETS_MIN_ID_PATTERN <- 0.90
OS_USER_GENESETS_ORIGIN <- "user-supplied, not bundled with omicstat"
OS_USER_GENESETS_PROV_KEYS <- c("source", "name", "version_or_release", "download_time", "urls", "sha256",
                                "terms", "terms_url", "id_type", "species")
OS_USER_GENESETS_PROV_REQUIRED <- c("source", "version_or_release", "sha256", "id_type")
OS_USER_GENESETS_CONTRACT_FLAGS <- c("gene-sets-provenance", "gene-sets-source", "gene-sets-version",
                                     "gene-sets-id-type", "gene-sets-species", "gene-sets-name", "gene-sets-terms")

# Flag declarations shared by every consumer. gmt = TRUE adds --gene-sets
# (modules that already declare it pass FALSE); feature_id_type = TRUE adds
# --feature-id-type for modules without their own key-type flag.
os_user_geneset_flags <- function(gmt = TRUE, feature_id_type = TRUE,
                                  gmt_help = "local user-supplied GMT (term ID, description, gene IDs; tab separated)") {
  c(if (gmt) list(os_flag("gene-sets", "path", must_exist = TRUE, help = gmt_help)),
    list(os_flag("gene-sets-provenance", "path", must_exist = TRUE,
                 help = "provenance JSON of the user GMT (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species)"),
         os_flag("gene-sets-source", "string", help = "source of the user GMT, e.g. KEGG REST, PanglaoDB, MSigDB; required without a provenance JSON"),
         os_flag("gene-sets-version", "string", help = "release or version of the user GMT; required without a provenance JSON"),
         os_flag("gene-sets-id-type", "enum", values = OS_USER_GENESETS_ID_TYPES,
                 help = "identifier type of the user GMT; required without a provenance JSON"),
         os_flag("gene-sets-species", "string", help = "species of the user GMT; checked against a known analysis species"),
         os_flag("gene-sets-name", "string", help = "display name of the user GMT; otherwise the provenance name or the file name"),
         os_flag("gene-sets-terms", "string", help = "terms of use of the user GMT, recorded in provenance and Methods")),
    if (feature_id_type) list(os_flag("feature-id-type", "enum", values = OS_USER_GENESETS_ID_TYPES,
                                      help = "identifier type of the analysed features; required with a user GMT")))
}

# TRUE when any user-collection contract flag was given (gmt = TRUE also
# counts --gene-sets; feature = TRUE also counts --feature-id-type).
os_user_geneset_given <- function(a, gmt = FALSE, feature = FALSE) {
  keys <- c(OS_USER_GENESETS_CONTRACT_FLAGS, if (gmt) "gene-sets", if (feature) "feature-id-type")
  any(!vapply(keys, function(k) is.null(a[[k]]), logical(1)))
}

# Refuse contract flags outside the user-collection mode.
os_user_geneset_guard <- function(a, user_mode, mode_text, gmt = FALSE, feature = FALSE) {
  if (!user_mode && os_user_geneset_given(a, gmt = gmt, feature = feature))
    stop(sprintf("OS_CONFLICTING_PARAMETERS: --gene-sets-*%s%s apply only to %s.",
                 if (gmt) ", --gene-sets" else "", if (feature) ", --feature-id-type" else "", mode_text), call. = FALSE)
  invisible(TRUE)
}

# Refusal text for a requested collection that omicstat does not bundle.
os_user_genesets_not_bundled <- function(what, how) {
  sprintf(paste0("OS_REFDATA_MISSING: %s gene sets are not bundled with omicstat and are never downloaded by it. ",
                 "Supply them as a local file you obtained yourself (for example with the web app's public-data tool, ",
                 "or for KEGG from the KEGG REST API under its academic terms) and run with %s --gene-sets <file.gmt> ",
                 "plus --gene-sets-provenance <json> (or --gene-sets-source, --gene-sets-version and --gene-sets-id-type); ",
                 "you are responsible for the terms of use of that file."), what, how)
}

os_species_canonical <- function(x) {
  if (is.null(x) || (length(x) == 1 && is.na(x)) || !nzchar(trimws(x))) return(NULL)
  k <- tolower(gsub("_", " ", trimws(x), fixed = TRUE))
  map <- c("homo sapiens" = "Homo sapiens", human = "Homo sapiens", hsa = "Homo sapiens", "9606" = "Homo sapiens",
           "mus musculus" = "Mus musculus", mouse = "Mus musculus", mmu = "Mus musculus", "10090" = "Mus musculus",
           "rattus norvegicus" = "Rattus norvegicus", rat = "Rattus norvegicus", rno = "Rattus norvegicus",
           "10116" = "Rattus norvegicus")
  if (k %in% names(map)) unname(map[[k]]) else trimws(x)
}

# Fraction of IDs that have the textual form of the declared identifier type.
os_user_id_pattern_fraction <- function(ids, id_type) {
  entrez <- grepl("^[0-9]+$", ids)
  ensembl <- grepl("^ENS[A-Z]*G[0-9]+([.][0-9]+)?$", ids)
  ok <- switch(id_type, ENTREZID = entrez, ENSEMBL = ensembl, SYMBOL = !entrez & !ensembl)
  if (!length(ids)) return(0)
  mean(ok)
}

os_user_gmt_read <- function(path) {
  lines <- sub("\r$", "", readLines(path, warn = FALSE, encoding = "UTF-8"))
  while (length(lines) && !nzchar(trimws(lines[length(lines)]))) lines <- lines[-length(lines)]
  if (!length(lines)) stop("OS_INVALID_INPUT: the user GMT is empty.", call. = FALSE)
  blank <- which(!nzchar(trimws(lines)))
  if (length(blank)) stop(sprintf("OS_INVALID_INPUT: user GMT line %d is empty; GMT has one tab-separated gene set per line.", blank[1]), call. = FALSE)
  cells <- strsplit(lines, "\t", fixed = TRUE)
  short <- which(lengths(cells) < 3L)
  if (length(short)) stop(sprintf(paste0("OS_INVALID_INPUT: user GMT line %d has fewer than three tab-separated fields ",
                                         "(term ID, description, at least one gene ID); a GMT is tab separated, not GMX or CSV."), short[1]), call. = FALSE)
  ids <- trimws(vapply(cells, `[[`, "", 1L))
  if (any(!nzchar(ids))) stop(sprintf("OS_INVALID_INPUT: user GMT line %d has an empty term ID.", which(!nzchar(ids))[1]), call. = FALSE)
  if (anyDuplicated(ids)) stop(sprintf("OS_INVALID_INPUT: user GMT repeats term ID '%s'.", ids[anyDuplicated(ids)]), call. = FALSE)
  desc <- trimws(vapply(cells, `[[`, "", 2L))
  genes <- lapply(cells, function(x) { g <- trimws(x[-c(1L, 2L)]); unique(g[nzchar(g)]) })
  empty <- which(lengths(genes) == 0L)
  if (length(empty)) stop(sprintf("OS_INVALID_INPUT: user GMT term '%s' lists no gene IDs.", ids[empty[1]]), call. = FALSE)
  list(sets = stats::setNames(genes, ids), names = stats::setNames(ifelse(nzchar(desc), desc, ids), ids))
}

.os_prov_scalar <- function(p, k) {
  v <- p[[k]]
  if (is.null(v)) return(NULL)
  if (is.list(v) || length(v) != 1L || !(is.character(v) || is.numeric(v)))
    stop(sprintf("OS_INVALID_INPUT: provenance JSON key '%s' must be a single string.", k), call. = FALSE)
  v <- trimws(as.character(v))
  if (!nzchar(v)) NULL else v
}

os_user_provenance_read <- function(path) {
  p <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                error = function(e) stop(sprintf("OS_INVALID_INPUT: --gene-sets-provenance is not valid JSON (%s).", conditionMessage(e)), call. = FALSE))
  if (!is.list(p) || is.null(names(p))) stop("OS_INVALID_INPUT: --gene-sets-provenance must be a JSON object.", call. = FALSE)
  out <- list()
  for (k in setdiff(OS_USER_GENESETS_PROV_KEYS, "urls")) out[k] <- list(.os_prov_scalar(p, k))
  urls <- p$urls
  if (!is.null(urls)) {
    urls <- unlist(urls, use.names = FALSE)
    if (!is.character(urls) || any(!nzchar(trimws(urls)))) stop("OS_INVALID_INPUT: provenance JSON key 'urls' must be a string or a list of strings.", call. = FALSE)
  }
  out["urls"] <- list(if (length(urls)) as.list(trimws(urls)) else NULL)
  miss <- OS_USER_GENESETS_PROV_REQUIRED[vapply(OS_USER_GENESETS_PROV_REQUIRED, function(k) is.null(out[[k]]), logical(1))]
  if (length(miss)) stop(sprintf("OS_INVALID_INPUT: provenance JSON lacks required key(s) %s (required: %s).",
                                 paste(miss, collapse = ", "), paste(OS_USER_GENESETS_PROV_REQUIRED, collapse = ", ")), call. = FALSE)
  out$sha256 <- tolower(out$sha256)
  if (!grepl("^[0-9a-f]{64}$", out$sha256)) stop("OS_INVALID_INPUT: provenance JSON sha256 must be 64 hexadecimal characters.", call. = FALSE)
  if (!out$id_type %in% OS_USER_GENESETS_ID_TYPES)
    stop(sprintf("OS_INVALID_INPUT: provenance JSON id_type '%s' is not one of %s.", out$id_type, paste(OS_USER_GENESETS_ID_TYPES, collapse = ", ")), call. = FALSE)
  out
}

# Read, hash and describe a user collection. a: parsed flags with gene-sets
# and the contract flags. Returns list(sets, term_names, record, label,
# sha256, entry) -- entry mimics the registry fields used by the reports.
os_user_genesets_resolve <- function(a) {
  gmt <- a[["gene-sets"]]
  if (is.null(gmt)) stop("OS_MISSING_PARAMETER: a user-supplied collection needs --gene-sets <local GMT>.", call. = FALSE)
  prov_path <- a[["gene-sets-provenance"]]
  prov <- if (is.null(prov_path)) NULL else os_user_provenance_read(prov_path)
  explicit <- list(source = a[["gene-sets-source"]], version_or_release = a[["gene-sets-version"]],
                   id_type = a[["gene-sets-id-type"]], species = a[["gene-sets-species"]],
                   name = a[["gene-sets-name"]], terms = a[["gene-sets-terms"]])
  flag_of <- c(source = "--gene-sets-source", version_or_release = "--gene-sets-version", id_type = "--gene-sets-id-type",
               species = "--gene-sets-species", name = "--gene-sets-name", terms = "--gene-sets-terms")
  if (is.null(prov)) {
    need <- c("source", "version_or_release", "id_type")
    miss <- need[vapply(need, function(k) is.null(explicit[[k]]), logical(1))]
    if (length(miss)) stop(sprintf(paste0("OS_MISSING_PARAMETER: a user GMT without --gene-sets-provenance needs %s; ",
                                          "source, version and identifier type are never guessed."),
                                   paste(flag_of[miss], collapse = ", ")), call. = FALSE)
    fields <- c(explicit, list(download_time = NULL, urls = NULL, terms_url = NULL))
    fields_from <- "command line (no provenance JSON)"
  } else {
    for (k in names(explicit)) {
      v <- explicit[[k]]; pv <- prov[[k]]
      if (is.null(v) || is.null(pv)) next
      same <- if (identical(k, "species")) identical(os_species_canonical(v), os_species_canonical(pv)) else identical(trimws(v), pv)
      if (!same) stop(sprintf("OS_CONFLICTING_PARAMETERS: %s '%s' disagrees with the provenance JSON value '%s'.", flag_of[[k]], v, pv), call. = FALSE)
    }
    fields <- prov
    for (k in names(explicit)) if (is.null(fields[[k]]) && !is.null(explicit[[k]])) fields[k] <- list(explicit[[k]])
    fields_from <- "provenance JSON"
  }
  sha <- digest::digest(file = gmt, algo = "sha256")
  if (!is.null(prov) && !identical(sha, prov$sha256))
    stop(sprintf(paste0("OS_REFDATA_MISMATCH: the GMT's sha256 (%s) differs from the provenance JSON sha256 (%s); the file changed ",
                        "after download or the provenance belongs to another file. Supply the matching file and provenance."),
                 sha, prov$sha256), call. = FALSE)
  g <- os_user_gmt_read(gmt)
  members <- unique(unlist(g$sets, use.names = FALSE))
  frac <- os_user_id_pattern_fraction(members, fields$id_type)
  if (frac < OS_USER_GENESETS_MIN_ID_PATTERN)
    stop(sprintf(paste0("OS_GENE_SET_ID_MISMATCH: only %.1f%% of the %d unique GMT gene IDs have the form of %s identifiers ",
                        "(first IDs: %s); the declared identifier type does not describe this file."),
                 100 * frac, length(members), fields$id_type, paste(utils::head(members, 3), collapse = ", ")), call. = FALSE)
  name <- fields$name %||% tools::file_path_sans_ext(basename(gmt))
  record <- list(
    name = name, name_from = if (!is.null(fields$name)) fields_from else "GMT file name",
    source = fields$source, version_or_release = fields$version_or_release, download_time = fields$download_time,
    urls = fields$urls, terms = fields$terms, terms_url = fields$terms_url, id_type = fields$id_type,
    species = os_species_canonical(fields$species), species_declared = fields$species,
    sha256 = sha, sha256_verified_against_provenance = !is.null(prov),
    gmt_file = basename(gmt), provenance_file = if (is.null(prov_path)) NULL else basename(prov_path),
    provenance_sha256 = if (is.null(prov_path)) NULL else digest::digest(file = prov_path, algo = "sha256"),
    fields_from = fields_from, n_sets = length(g$sets), n_unique_genes = length(members),
    id_form_fraction = round(frac, 6), origin = OS_USER_GENESETS_ORIGIN, bundled_with_omicstat = FALSE,
    kegg_term_id_exclusion = "not applied: it covers bundled/registered collections only")
  list(sets = g$sets, term_names = g$names, record = record, label = sprintf("%s (user-supplied)", record$source),
       sha256 = sha, entry = list(id = "user", version = record$version_or_release,
                                  species = record$species %||% "not stated"))
}

# Identifier, species and overlap checks against the analysis. key_type: the
# analysis key type; key_flag names where it came from; analysis_species:
# NULL when the analysis does not know its species.
os_user_genesets_check <- function(coll, key_type, universe, universe_label, key_flag, analysis_species = NULL) {
  rec <- coll$record
  if (is.null(key_type))
    stop(sprintf("OS_MISSING_PARAMETER: a user GMT needs %s, the identifier type of the analysed features.", key_flag), call. = FALSE)
  if (!key_type %in% OS_USER_GENESETS_ID_TYPES)
    stop(sprintf("OS_GENE_SET_ID_MISMATCH: user gene sets are matched on %s identifiers only; the analysis key type is %s (%s).",
                 paste(OS_USER_GENESETS_ID_TYPES, collapse = ", "), key_type, key_flag), call. = FALSE)
  if (!identical(rec$id_type, key_type))
    stop(sprintf(paste0("OS_GENE_SET_ID_MISMATCH: the user gene sets use %s identifiers but the analysed features are %s (%s); ",
                        "omicstat does not convert identifiers silently. Supply a GMT keyed by %s, or re-key the input and declare it."),
                 rec$id_type, key_type, key_flag, key_type), call. = FALSE)
  sp <- os_species_canonical(analysis_species)
  if (!is.null(sp) && !is.null(rec$species) && !identical(sp, rec$species))
    stop(sprintf("OS_GENE_SET_SPECIES_MISMATCH: the user gene sets are for %s but the analysis is %s; supply gene sets of the analysed species.",
                 rec$species, sp), call. = FALSE)
  set_genes <- unique(unlist(coll$sets, use.names = FALSE))
  uni <- unique(as.character(universe))
  present <- sum(set_genes %in% uni)
  frac <- present / length(set_genes)
  if (frac < OS_USER_GENESETS_MIN_OVERLAP)
    stop(sprintf(paste0("OS_GENE_SET_LOW_OVERLAP: only %d of %d unique gene-set genes (%.1f%%) are present in %s (%d features); ",
                        "under 10%% usually means the wrong identifiers (type, version suffix or species). Check %s and ",
                        "the identifier type of the user GMT."),
                 present, length(set_genes), 100 * frac, universe_label, length(uni), key_flag), call. = FALSE)
  rec$analysis_key_type <- key_type
  rec$analysis_species <- sp %||% "not declared by the analysis"
  rec$species_check <- if (is.null(sp) || is.null(rec$species)) "not checked: species unknown on one side" else "matched"
  rec$overlap <- list(universe = universe_label, n_universe = length(uni), n_set_genes = length(set_genes),
                      n_present = present, fraction = round(frac, 6), minimum_fraction = OS_USER_GENESETS_MIN_OVERLAP,
                      n_sets_without_overlap = sum(vapply(coll$sets, function(s) !any(s %in% uni), logical(1))))
  coll$record <- rec
  coll
}

# One Methods sentence; the same text is documented in CONVENTIONS.md.
os_user_genesets_methods <- function(rec) {
  sp <- if (!is.null(rec$species)) sprintf(" (%s)", rec$species) else ""
  when <- if (!is.null(rec$download_time)) sprintf(" on %s", rec$download_time) else " (retrieval date not stated)"
  terms <- if (!is.null(rec$terms)) sprintf(", used under %s", rec$terms) else ", terms of use not stated"
  ov <- rec$overlap
  tail_txt <- if (is.null(ov)) "" else sprintf(" %d of %d unique set genes (%s%%) were present in %s.", ov$n_present, ov$n_set_genes,
                                               format(round(100 * ov$fraction, 1), nsmall = 1), ov$universe)
  sprintf("Gene sets: %s%s, retrieved from %s%s, release %s%s; supplied by the user, not bundled with omicstat. The GMT file (SHA-256 %s) held %d sets of %s identifiers.%s",
          rec$name, sp, rec$source, when, rec$version_or_release, terms, rec$sha256, rec$n_sets, rec$id_type, tail_txt)
}

# Insert the Methods sentence before the first Results heading of a draft.
os_user_genesets_draft <- function(path, rec) {
  x <- readLines(path, warn = FALSE, encoding = "UTF-8")
  i <- grep("^#+ *Results", x)[1]
  s <- os_user_genesets_methods(rec)
  x <- if (is.na(i)) c(x, "", s) else append(x, c(s, ""), after = i - 1L)
  os_write_text(x, path)
}

os_user_genesets_write <- function(outdir, rec) {
  dir.create(file.path(outdir, "provenance"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(rec, file.path(outdir, "provenance", "user_gene_sets.json"), auto_unbox = TRUE, pretty = TRUE,
                       null = "null", na = "null", digits = I(10))
}

# Provenance inputs (paths) of a user collection; empty list otherwise.
os_user_genesets_inputs <- function(a) {
  out <- list(gene_sets = a[["gene-sets"]])
  if (!is.null(a[["gene-sets-provenance"]])) out$gene_sets_provenance <- a[["gene-sets-provenance"]]
  out
}

# TERM2GENE / TERM2NAME data frames for clusterProfiler's generic functions.
os_user_genesets_term2gene <- function(coll) {
  ids <- names(coll$sets)
  list(TERM2GENE = data.frame(term = rep(ids, lengths(coll$sets)), gene = unlist(coll$sets, use.names = FALSE), stringsAsFactors = FALSE),
       TERM2NAME = data.frame(term = ids, name = unname(coll$term_names[ids]), stringsAsFactors = FALSE))
}

# User collections are often small, so few terms reach the threshold; the
# shared dot plot then sizes the panel by its rows and can clip the size
# legend. For user-collection dot plots only, keep at least the height the
# shared builder (fig_enrich.R os_enrich_dotplot) gives eight rows. Default
# GO/registered figures are untouched.
os_user_dotplot_floor <- function(p, min_rows = 8L) {
  m <- attr(p, "os_meta")
  floor_mm <- min(170, 22 + 5.2 * min_rows)
  if (!is.null(m$default_height_mm) && m$default_height_mm < floor_mm) p <- os_with_meta(p, default_height_mm = floor_mm)
  p
}
