# test_user_genesets.R -- unit tests of the user-supplied gene-set contract
# (scripts/user_genesets.R) and of the calls_check.R site selectors.
# Needs jsonlite and digest only. ASCII only.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
shared <- dirname(here)
for (f in c("args.R", "module_kit.R", "enrich_rank_io.R", "user_genesets.R", "calls_check.R")) source(file.path(shared, "scripts", f))
source(file.path(here, "user_genesets_testkit.R"))
fail <- character()
check <- function(ok, msg) { cat(if (isTRUE(ok)) "PASS: " else "FAIL: ", msg, "\n", sep = ""); if (!isTRUE(ok)) fail <<- c(fail, msg) }
err <- function(expr) tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "user_genesets_unit")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)

universe <- as.character(1000 + seq_len(400))
sets <- list(hsa04110 = universe[1:40], hsa04115 = universe[30:80], KEGG_APOPTOSIS = universe[60:90], hsa05200 = universe[100:160])
fx <- ugs_fixture(file.path(tmp, "fx"), sets, "ENTREZID", lowfn = function(i) as.character(900000 + i))
args <- function(...) { a <- list(...); a }

# 1. KEGG-style term IDs and names are accepted for user files; registered reader still excludes them.
coll <- os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-provenance` = fx$prov))
check(identical(names(coll$sets), names(sets)) && identical(coll$label, "KEGG REST (user-supplied)") &&
        identical(coll$record$species, "Homo sapiens") && isTRUE(coll$record$sha256_verified_against_provenance),
      "provenance JSON: KEGG-style IDs accepted, species hsa -> Homo sapiens, sha256 verified")
check(grepl("excluded KEGG content", err(os_gmt_read(fx$gmt)), fixed = TRUE), "registered-collection GMT reader still excludes KEGG term IDs")
coll <- os_user_genesets_check(coll, "ENTREZID", universe, "the test universe", "--key-type", "Homo sapiens")
check(coll$record$overlap$n_present == length(unique(unlist(sets))) && coll$record$overlap$fraction == 1, "overlap counted against the universe")
s <- os_user_genesets_methods(coll$record)
check(grepl("Gene sets: KEGG-like pathways (synthetic test fixture) (Homo sapiens), retrieved from KEGG REST on 2026-10-09T00:00:00Z, release synthetic-test-1, used under", s, fixed = TRUE) &&
        grepl("supplied by the user, not bundled with omicstat", s, fixed = TRUE) && grepl(coll$sha256, s, fixed = TRUE), "Methods sentence")
d <- file.path(tmp, "draft.md"); os_write_text(c("# Methods", "", "M.", "", "# Results", "", "R."), d)
os_user_genesets_draft(d, coll$record); dl <- readLines(d)
check(which(startsWith(dl, "Gene sets:")) < which(dl == "# Results"), "Methods sentence inserted before the Results heading")

# 2. Without provenance: source, version and ID type are required, never guessed.
m <- err(os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-source` = "KEGG REST")))
check(grepl("OS_MISSING_PARAMETER", m) && grepl("--gene-sets-version", m) && grepl("--gene-sets-id-type", m), "explicit fields required without provenance")
c2 <- os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-source` = "KEGG REST", `gene-sets-version` = "r1", `gene-sets-id-type` = "ENTREZID"))
check(identical(c2$record$fields_from, "command line (no provenance JSON)") && !isTRUE(c2$record$sha256_verified_against_provenance) &&
        identical(c2$record$name, "user_sets") && is.null(c2$record$species), "explicit fields accepted; name from file; species unknown")
check(grepl("retrieval date not stated", os_user_genesets_methods(c2$record), fixed = TRUE), "Methods says when the retrieval date is unknown")

# 3. Refusals.
check(grepl("OS_REFDATA_MISMATCH", err(os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-provenance` = fx$bad_sha)))), "sha256 mismatch against provenance")
check(grepl("OS_CONFLICTING_PARAMETERS", err(os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-provenance` = fx$prov, `gene-sets-version` = "other")))),
      "explicit flag disagreeing with provenance")
check(grepl("OS_GENE_SET_ID_MISMATCH", err(os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-source` = "x", `gene-sets-version` = "1", `gene-sets-id-type` = "SYMBOL")))),
      "declared SYMBOL for an all-numeric GMT")
check(grepl("OS_GENE_SET_ID_MISMATCH", err(os_user_genesets_check(os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-provenance` = fx$prov)), "SYMBOL", universe, "u", "--key-type"))),
      "gene-set ID type differs from the analysis key type")
check(grepl("OS_GENE_SET_SPECIES_MISMATCH", err(os_user_genesets_check(os_user_genesets_resolve(args(`gene-sets` = fx$gmt, `gene-sets-provenance` = fx$prov)), "ENTREZID", universe, "u", "--key-type", "mouse"))),
      "species mismatch")
check(grepl("OS_GENE_SET_LOW_OVERLAP", err(os_user_genesets_check(os_user_genesets_resolve(args(`gene-sets` = fx$low, `gene-sets-provenance` = fx$low_prov)), "ENTREZID", universe, "u", "--key-type"))),
      "low overlap")
check(grepl("OS_MISSING_PARAMETER", err(os_user_genesets_check(coll, NULL, universe, "u", "--feature-id-type"))), "analysis ID type required")
bad <- file.path(tmp, "bad.gmt"); writeLines(c("hsa1\tdesc\t1\t2", "hsa2\tonly two fields"), bad)
check(grepl("line 2 has fewer than three", err(os_user_gmt_read(bad))), "GMT format: too few fields")
writeLines(c("hsa1\td\t1", "hsa1\td\t2"), bad); check(grepl("repeats term ID", err(os_user_gmt_read(bad))), "GMT format: duplicate term")
writeLines(c("hsa1\td\t1", "", "hsa2\td\t2"), bad); check(grepl("line 2 is empty", err(os_user_gmt_read(bad))), "GMT format: blank line")
pj <- file.path(tmp, "p.json"); writeLines('{"source": "x"}', pj)
check(grepl("lacks required key", err(os_user_provenance_read(pj))), "provenance JSON: required keys")
check(grepl("OS_CONFLICTING_PARAMETERS", err(os_user_geneset_guard(list(`gene-sets-source` = "x"), FALSE, "--database custom"))), "contract flags refused outside user mode")
check(grepl("not bundled with omicstat", os_user_genesets_not_bundled("KEGG", "--database custom"), fixed = TRUE), "not-bundled refusal text")

# 4. calls_check.R site selectors: one function, two argument sets.
src <- file.path(tmp, "sites.R")
writeLines(c("f <- function() {", "  pkg::fn(a = 1, b = 2)", "  pkg::fn(a = 1, T2G = 3)", "}"), src)
entry <- function(args, ...) c(list(fn = "pkg::fn", args = stats::setNames(lapply(args, function(z) list(value = 1)), args)), list(...))
reg <- list(package_versions = list(pkg = "1"), calls = list(entry(c("a", "b"), site_excludes = list("T2G")), entry(c("a", "T2G"), site_requires = list("T2G"))))
check(check_calls(src, reg)$ok, "site_requires / site_excludes split two call forms")
reg$calls[[1]]$site_excludes <- NULL
check(!check_calls(src, reg)$ok, "without site_excludes the GO-form entry still fails the other call form (C1 unchanged)")

if (length(fail)) quit(status = 1) else cat(sprintf("ALL PASSED (user-supplied gene-set contract)\n"))
