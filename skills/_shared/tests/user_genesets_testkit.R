# user_genesets_testkit.R -- fixtures for the user-supplied gene-set contract
# (skills/_shared/scripts/user_genesets.R), sourced by module smoke tests.
# ASCII only. Every fixture is synthetic: gene sets are built from genes that
# exist in the module's own anchor, with KEGG-style term IDs (hsa04110, ...)
# and one MSigDB-style KEGG_ ID, to prove that the registered-collection
# KEGG term-ID exclusion is not
# applied to user-supplied files. No KEGG content is used or downloaded.

ugs_write_gmt <- function(path, sets, desc = NULL) {
  desc <- desc %||% stats::setNames(paste(names(sets), "synthetic KEGG-like set"), names(sets))
  writeLines(vapply(names(sets), function(n) paste(c(n, desc[[n]], sets[[n]]), collapse = "\t"), ""), path)
  invisible(path)
}

ugs_write_provenance <- function(path, gmt, id_type, species = "hsa", source = "KEGG REST",
                                 name = "KEGG-like pathways (synthetic test fixture)", sha256 = NULL) {
  jsonlite::write_json(list(source = source, name = name, version_or_release = "synthetic-test-1",
                            download_time = "2026-10-09T00:00:00Z", urls = list("https://rest.kegg.jp/link/hsa/pathway"),
                            sha256 = sha256 %||% digest::digest(file = gmt, algo = "sha256"),
                            terms = "academic use terms of the source (synthetic fixture)", terms_url = "https://www.kegg.jp/kegg/legal.html",
                            id_type = id_type, species = species),
                       path, auto_unbox = TRUE, pretty = TRUE)
  invisible(path)
}

# k sets with KEGG-style IDs. enriched: genes drawn into the first sets so that
# an enrichment or score has signal; background: the remaining pool.
ugs_kegg_like_sets <- function(enriched, background, sizes = c(40, 35, 30, 30, 60, 60), n_enriched = c(30, 20, 15, 0, 0, 10), seed = 20260925L) {
  ids <- c("hsa04110", "hsa04115", "KEGG_APOPTOSIS", "hsa04010", "hsa04151", "hsa05200")[seq_along(sizes)]
  set.seed(seed)
  out <- lapply(seq_along(sizes), function(i) {
    e <- utils::head(sample(enriched), min(n_enriched[i], length(enriched)))
    unique(c(e, sample(setdiff(background, e), sizes[i] - length(e))))
  })
  stats::setNames(out, ids)
}

ugs_descriptions <- function(sets) {
  nm <- c(hsa04110 = "Cell cycle (KEGG-like synthetic)", hsa04115 = "p53 signaling pathway (KEGG-like synthetic)",
          KEGG_APOPTOSIS = "Apoptosis (KEGG-like synthetic, MSigDB-style ID)", hsa04010 = "MAPK signaling pathway (KEGG-like synthetic)",
          hsa04151 = "PI3K-Akt signaling pathway (KEGG-like synthetic)", hsa05200 = "Pathways in cancer (KEGG-like synthetic)")
  stats::setNames(unname(nm[names(sets)]), names(sets))
}

# A complete user collection in dir: gmt, matching provenance, a provenance
# with a wrong sha256, and a low-overlap GMT of the same ID form. lowfn makes
# IDs that look like the right type but are absent from the anchor.
ugs_fixture <- function(dir, sets, id_type, species = "hsa", lowfn = function(i) paste0("ZZFAKE", i)) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  gmt <- ugs_write_gmt(file.path(dir, "user_sets.gmt"), sets, ugs_descriptions(sets))
  prov <- ugs_write_provenance(file.path(dir, "user_sets.provenance.json"), gmt, id_type, species)
  bad_sha <- ugs_write_provenance(file.path(dir, "user_sets.bad_sha.json"), gmt, id_type, species, sha256 = strrep("0", 64))
  low_sets <- lapply(seq_along(sets), function(i) c(utils::head(sets[[i]], 1), lowfn(seq_len(30) + 100 * i)))
  names(low_sets) <- names(sets)
  low <- ugs_write_gmt(file.path(dir, "low_overlap.gmt"), low_sets, ugs_descriptions(sets))
  low_prov <- ugs_write_provenance(file.path(dir, "low_overlap.provenance.json"), low, id_type, species)
  list(gmt = gmt, prov = prov, bad_sha = bad_sha, low = low, low_prov = low_prov,
       wrong_id = if (identical(id_type, "SYMBOL")) "ENTREZID" else "SYMBOL")
}

# Assertions shared by every module: provenance record and Methods sentence.
ugs_check_recorded <- function(check, outdir, label, n_sets, species = "Homo sapiens") {
  rec_path <- file.path(outdir, "provenance", "user_gene_sets.json")
  rec <- if (file.exists(rec_path)) jsonlite::read_json(rec_path, simplifyVector = TRUE) else list()
  prov <- jsonlite::read_json(file.path(outdir, "provenance", "provenance.json"), simplifyVector = TRUE)
  check(identical(rec$origin, "user-supplied, not bundled with omicstat") && identical(rec$source, "KEGG REST") &&
          identical(rec$version_or_release, "synthetic-test-1") && identical(rec$species, species) &&
          isTRUE(rec$sha256_verified_against_provenance) && rec$n_sets == n_sets && !is.null(rec$overlap$fraction) &&
          identical(prov$user_gene_sets$sha256, rec$sha256) && !is.null(prov$inputs$gene_sets_provenance %||% prov$inputs[["gene-sets-provenance"]]),
        sprintf("%s: provenance/user_gene_sets.json and provenance.json record source, release, species, sha256, %d sets", label, n_sets))
  draft <- paste(readLines(file.path(outdir, "draft", "methods_results.md"), warn = FALSE), collapse = "\n")
  need <- c(sprintf("Gene sets: KEGG-like pathways (synthetic test fixture) (%s), retrieved from KEGG REST on 2026-10-09T00:00:00Z, release synthetic-test-1", species),
            "supplied by the user, not bundled with omicstat", rec$sha256 %||% "<no sha>")
  check(all(vapply(need, grepl, logical(1), x = draft, fixed = TRUE)), sprintf("%s: Methods state the user-supplied gene sets", label))
  invisible(rec)
}

# Run one refusal through a CLI runner and look for the typed code.
ugs_refused <- function(check, z, code, label) {
  st <- attr(z, "status") %||% 0L
  check(st != 0L && any(grepl(code, z, fixed = TRUE)), sprintf("%s refused with %s", label, code))
}
