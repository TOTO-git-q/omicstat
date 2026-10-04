# requires: clusterProfiler, DOSE, org.Hs.eg.db, GO.db, jsonlite, digest
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mdir <- dirname(here); suite <- normalizePath(file.path(mdir, "..", ".."))
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
source(file.path(suite, "skills", "_shared", "scripts", "calls_check.R"))
source(file.path(suite, "skills", "_shared", "scripts", "handoff.R"))
fail <- character()
check <- function(ok, msg) { cat(if (isTRUE(ok)) "PASS: " else "FAIL: ", msg, "\n", sep = ""); if (!isTRUE(ok)) fail <<- c(fail, msg) }
reg <- file.path(mdir, "scripts", "calls_registry.json")
scripts <- list.files(file.path(mdir, "scripts"), pattern = "[.]R$", full.names = TRUE)
check(check_calls(scripts, reg)$ok, "call registry")
check(check_default_drift(reg)$ok, "container formals")
for (nm in c("check_defaults.py", "check_flag_docs.py", "lint_r.py")) {
  cmd <- c(file.path(suite, "tools", nm), if (nm == "lint_r.py") file.path(mdir, "scripts") else mdir)
  z <- suppressWarnings(system2("python3", shQuote(cmd), stdout = TRUE, stderr = TRUE))
  check(is.null(attr(z, "status")) || attr(z, "status") == 0L, paste(nm, paste(z, collapse = " | ")))
}
tmp <- Sys.getenv("OMICSTAT_TEST_TMP", file.path(tempdir(), "ora_smoke"))
dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
data(geneList, package = "DOSE")
selected <- names(geneList)[abs(geneList) > 2]
universe <- names(geneList)
input <- file.path(tmp, "selected.csv"); bg <- file.path(tmp, "eligible.csv")
write.csv(data.frame(feature_id = selected), input, row.names = FALSE)
write.csv(data.frame(feature_id = universe), bg, row.names = FALSE)
entry <- file.path(mdir, "scripts", "run_clusterprofiler_ora.R")
run <- function(args) suppressWarnings(system2("Rscript", shQuote(c(entry, args)), stdout = TRUE, stderr = TRUE))
status <- function(z) attr(z, "status") %||% 0L
den <- function(z) as.integer(vapply(strsplit(as.character(z), "/", fixed = TRUE), `[`, "", 2))
# Independent direct call (replay anchor): same arguments as the PACK C DOSE
# example with the frozen BP preset and explicit eligible background.
direct <- function(ont, pool) clusterProfiler::enrichGO(gene = selected, OrgDb = org.Hs.eg.db::org.Hs.eg.db,
  keyType = "ENTREZID", ont = ont, pvalueCutoff = 1, pAdjustMethod = "BH", universe = universe,
  qvalueCutoff = 1, minGSSize = 10, maxGSSize = 500, readable = FALSE, pool = pool)
one <- file.path(tmp, "anchor")
base <- c("--input", input, "--universe", bg, "--selection-rule", "abs(DOSE geneList)>2")
z <- run(c(base, "--outdir", one)); check(status(z) == 0L, paste("DOSE anchor run", paste(z, collapse = " | ")))
if (status(z) == 0L) {
  actual <- read.csv(file.path(one, "tables", "enrichment_full.csv"), check.names = FALSE)
  # Replay anchor: the PACK's DOSE geneList selection is rerun in this session.
  expected <- direct("BP", FALSE)
  ref <- as.data.frame(expected)
  check(nrow(actual) == nrow(ref) && identical(actual$ID, ref$ID) &&
          isTRUE(all.equal(actual$p.adjust, ref$p.adjust, tolerance = 1e-14)),
        sprintf("DOSE replay anchor: %d tested terms; first %s padj %.12g", nrow(ref), ref$ID[1], ref$p.adjust[1]))
  check(all(c("pvalue", "p.adjust", "qvalue", "significant_bh05", "test_family") %in% names(actual)), "full p/q/BH columns and test family")
  counts <- jsonlite::read_json(file.path(one, "results", "clusterprofiler_ora_results.json"), simplifyVector = TRUE)
  check(counts$n_candidate_background == 12495 && counts$n_effective_background == 11525 &&
          counts$n_input == 207 && counts$n_effective_input == 194, "candidate and effective GO universe counts")
  fam <- read.csv(file.path(one, "tables", "test_families.csv"), stringsAsFactors = FALSE)
  check(nrow(fam) == 1 && fam$test_family == "GO BP" && fam$n_effective_input == 194 && fam$n_effective_background == 11525 &&
          fam$n_tested_terms == 2588, "BP: one testing family 194/11525, 2588 terms")
  # F2: original IDs kept; symbol map and readable table agree with setReadable (PACK T path).
  check(all(grepl("^[0-9/]+$", actual$geneID)), "full table keeps original ENTREZID geneID")
  smap <- read.csv(file.path(one, "tables", "gene_symbol_map.csv"), stringsAsFactors = FALSE, colClasses = "character")
  check(nrow(smap) == 207 && identical(smap$feature_id, selected), "symbol map covers all 207 selected IDs in input order")
  rd <- as.data.frame(enrichit::setReadable(expected, OrgDb = org.Hs.eg.db::org.Hs.eg.db, keyType = "ENTREZID"))
  readable <- read.csv(file.path(one, "tables", "enrichment_full_symbols.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  m <- match(readable$term_id, rd$ID)
  same_sets <- all(!is.na(m)) && all(mapply(function(a1, b1) setequal(strsplit(a1, "/", fixed = TRUE)[[1]], strsplit(b1, "/", fixed = TRUE)[[1]]),
                                            readable$geneID_symbol, rd$geneID[m]))
  check(nrow(readable) == nrow(actual) && identical(readable$geneID, actual$geneID) && same_sets,
        "enrichment_full_symbols: per-term symbols equal enrichit::setReadable on the direct call")
  # F3: software/annotation releases from the actual run in Methods, JSON and provenance.
  prov <- jsonlite::read_json(file.path(one, "provenance", "provenance.json"), simplifyVector = TRUE)
  sw <- counts$software
  pv <- function(p) as.character(utils::packageVersion(p))
  gm <- AnnotationDbi::metadata(GO.db::GO.db)
  check(identical(sw$clusterProfiler, pv("clusterProfiler")) && identical(sw$enrichit, pv("enrichit")) &&
          identical(sw$GO.db, pv("GO.db")) && identical(sw$org.Hs.eg.db, pv("org.Hs.eg.db")) &&
          identical(sw$GO_source_date, gm$value[gm$name == "GOSOURCEDATE"]) &&
          identical(sw$enrichment_function, "clusterProfiler::enrichGO"),
        sprintf("JSON software: clusterProfiler %s, enrichit %s, GO.db %s (GO %s), org.Hs.eg.db %s",
                sw$clusterProfiler, sw$enrichit, sw$GO.db, sw$GO_source_date, sw$org.Hs.eg.db))
  check(all(vapply(c("clusterProfiler", "enrichit", "GO.db", "org.Hs.eg.db"), function(p) identical(prov$packages[[p]], sw[[p]]), logical(1))) &&
          identical(prov$software, sw), "provenance packages and software agree with JSON")
  draft <- paste(readLines(file.path(one, "draft", "methods_results.md"), warn = FALSE), collapse = "\n")
  need <- c(sprintf("enrichGO function of clusterProfiler %s", sw$clusterProfiler), sprintf("enrichit %s", sw$enrichit),
            sprintf("GO.db %s (Gene Ontology release %s)", sw$GO.db, sw$GO_source_date), sprintf("org.Hs.eg.db %s", sw$org.Hs.eg.db),
            "194 selected genes remained in the GO input and 11525 genes in the GO testing universe",
            "adjusted by BH over all 2588 tested terms as one family", "12495 genes", "Nominal P and q-value calculation cutoffs were both 1",
            "No term simplification was applied.")
  check(all(vapply(need, grepl, logical(1), x = draft, fixed = TRUE)), paste("Methods text:", paste(need[!vapply(need, grepl, logical(1), x = draft, fixed = TRUE)], collapse = " | ")))
  check(file.exists(file.path(one, "figures", "ora_dotplot.figure_spec.json")), "figure specification")
  replay <- file.path(tmp, "replay")
  z <- run(c("--spec", file.path(one, "provenance", "resolved_spec.json"), "--outdir", replay))
  check(status(z) == 0L, "resolved spec replay")
  if (status(z) == 0L) check(identical(readBin(file.path(one,"tables","enrichment_full.csv"),"raw",n=1e8),
                                   readBin(file.path(replay,"tables","enrichment_full.csv"),"raw",n=1e8)), "byte-identical replay table")
  if (status(z) == 0L) check(identical(readBin(file.path(one,"figures","ora_dotplot.png"),"raw",n=1e8),
                                   readBin(file.path(replay,"figures","ora_dotplot.png"),"raw",n=1e8)), "byte-identical replay PNG")
  if (identical(Sys.getenv("OMICSTAT_WRITE_GOLDEN"), "1"))
    os_golden_write(mdir, one, c("tables/enrichment_full.csv", "tables/test_families.csv", "tables/gene_symbol_map.csv",
                                 "tables/enrichment_full_symbols.csv", "results/clusterprofiler_ora_results.json",
                                 "figures/ora_dotplot.figure_spec.json"))
  g <- os_golden_check(mdir, one)
  check(g$status %in% c("PASS", "SKIP"), paste("golden", g$status, paste(g$problems, collapse = ",")))
}

# ---- F1 / contract (d): GO ALL, pool FALSE and pool TRUE ----
all_run <- function(pool, want) {
  out <- file.path(tmp, paste0("all_pool_", pool))
  z <- run(c(base, "--ontology", "ALL", "--pool", pool, "--outdir", out))
  check(status(z) == 0L, paste("ALL pool", pool, "legal run", paste(tail(z, 3), collapse = " | ")))
  if (status(z) != 0L) return(invisible(NULL))
  tab <- read.csv(file.path(out, "tables", "enrichment_full.csv"), check.names = FALSE, stringsAsFactors = FALSE)
  fam <- read.csv(file.path(out, "tables", "test_families.csv"), stringsAsFactors = FALSE)
  js <- jsonlite::read_json(file.path(out, "results", "clusterprofiler_ora_results.json"), simplifyVector = TRUE)
  check(identical(fam$test_family, want$family) && identical(fam$n_effective_input, want$input) &&
          identical(fam$n_effective_background, want$background) && identical(fam$n_tested_terms, want$tested),
        sprintf("ALL pool %s families %s: input %s, background %s, tested %s", pool, paste(fam$test_family, collapse = "/"),
                paste(fam$n_effective_input, collapse = "/"), paste(fam$n_effective_background, collapse = "/"),
                paste(fam$n_tested_terms, collapse = "/")))
  k <- match(tab$test_family, fam$test_family)
  check(!anyNA(k) && all(den(tab$GeneRatio) == fam$n_effective_input[k]) && all(den(tab$BgRatio) == fam$n_effective_background[k]),
        paste("ALL pool", pool, "every term keeps its own family's GeneRatio/BgRatio denominators"))
  d <- as.data.frame(direct("ALL", identical(pool, "TRUE")))
  check(identical(tab$ID, d$ID) && identical(tab$GeneRatio, d$GeneRatio) && identical(tab$BgRatio, d$BgRatio) &&
          isTRUE(all.equal(tab$p.adjust, d$p.adjust, tolerance = 1e-14)), paste("ALL pool", pool, "replay equals direct enrichGO"))
  # Multiple-testing scope, independently recomputed from the direct call.
  fam_of <- if (identical(pool, "FALSE")) as.character(d$ONTOLOGY) else rep("all", nrow(d))
  bh <- stats::ave(d$pvalue, fam_of, FUN = function(p) stats::p.adjust(p, method = "BH"))
  check(max(abs(bh - d$p.adjust)) < 1e-14, paste("ALL pool", pool, "p.adjust is BH within", if (identical(pool, "FALSE")) "each ontology" else "the pooled collection"))
  if (identical(pool, "FALSE")) {
    check(is.null(js$n_effective_input) && is.null(js$n_effective_background) && nrow(js$test_families) == 3,
          "ALL pool FALSE: no single effective denominator reported; per-ontology table in JSON")
    check(max(abs(stats::p.adjust(d$pvalue, method = "BH") - d$p.adjust)) > 1e-3, "ALL pool FALSE: pooled BH would differ (families matter)")
  }
  draft <- paste(readLines(file.path(out, "draft", "methods_results.md"), warn = FALSE), collapse = "\n")
  check(all(vapply(want$text, grepl, logical(1), x = draft, fixed = TRUE)), paste("ALL pool", pool, "Methods state per-family denominators and BH scope"))
  if (file.exists(file.path(out, "figures", "ora_dotplot.figure_spec.json"))) {
    spec <- paste(readLines(file.path(out, "figures", "ora_dotplot.figure_spec.json"), warn = FALSE), collapse = "\n")
    check(grepl(want$caption, spec, fixed = TRUE), paste("ALL pool", pool, "figure caption states the testing families"))
  }
}
all_run("FALSE", list(family = c("GO BP", "GO CC", "GO MF"), input = c(194L, 201L, 193L), background = c(11525L, 11914L, 11822L),
                      tested = c(2588L, 292L, 478L),
                      text = c("BP: 194 input genes of a 11525-gene background; CC: 201 input genes of a 11914-gene background; MF: 193 input genes of a 11822-gene background",
                               "adjusted by BH within each ontology separately", "By ontology: BP 154 of 2588; CC 27 of 292; MF 15 of 478"),
                      caption = "Ontologies were tested and BH-adjusted separately (pool = FALSE): BP input 194 / background 11525; CC input 201 / background 11914; MF input 193 / background 11822."))
all_run("TRUE", list(family = "GO ALL pooled", input = 204L, background = 12112L, tested = 3358L,
                     text = c("With pool = TRUE, BP, CC and MF terms formed one collection: 204 selected genes remained in the GO input and 12112 genes",
                              "adjusted by BH over all 3358 tested terms as one family"),
                     caption = "BP, CC and MF were pooled into one test (input 204, background 12112) and one BH family."))

# ---- F2: simplify relation (S1 P-3) on CC (292 terms) and on ALL (per ontology) ----
simp_run <- function(tag, extra, ont, pool) {
  out <- file.path(tmp, paste0("simplify_", tag))
  z <- run(c(base, extra, "--simplify", "--outdir", out))
  check(status(z) == 0L, paste("simplify", tag, "run", paste(tail(z, 3), collapse = " | ")))
  if (status(z) != 0L) return(invisible(NULL))
  full <- read.csv(file.path(out, "tables", "enrichment_full.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  disp <- read.csv(file.path(out, "tables", "enrichment_simplified_display.csv"), stringsAsFactors = FALSE, check.names = FALSE)
  rel <- read.csv(file.path(out, "tables", "simplify_relation.csv"), stringsAsFactors = FALSE)
  js <- jsonlite::read_json(file.path(out, "results", "clusterprofiler_ora_results.json"), simplifyVector = TRUE)
  mins <- as.integer(extra[match("--min-size", extra) + 1]); if (is.na(mins)) mins <- 10L
  d <- clusterProfiler::enrichGO(gene = selected, OrgDb = org.Hs.eg.db::org.Hs.eg.db, keyType = "ENTREZID", ont = ont,
    pvalueCutoff = 1, pAdjustMethod = "BH", universe = universe, qvalueCutoff = 1, minGSSize = mins, maxGSSize = 500,
    readable = FALSE, pool = pool)
  s <- as.data.frame(clusterProfiler::simplify(x = d, cutoff = 0.7, by = "p.adjust", select_fun = min, measure = "Wang", semData = NULL))
  check(identical(disp$ID, s$ID) && nrow(full) == nrow(as.data.frame(d)),
        sprintf("simplify %s: display = direct clusterProfiler::simplify (%d -> %d terms); full table kept (%d rows)", tag, nrow(full), nrow(s), nrow(full)))
  check(nrow(rel) == nrow(full) - nrow(disp) && setequal(c(rel$merged_term, disp$ID), full$ID) && !any(rel$merged_term %in% disp$ID),
        sprintf("simplify %s: %d merged terms + %d retained = all tested terms", tag, nrow(rel), nrow(disp)))
  check(all(rel$representative_term %in% full$ID) && all(rel$representative_padj <= rel$merged_padj) &&
          all(rel$wang_similarity_to_anchor > 0.7) && identical(rel$representative_retained, rel$representative_term %in% disp$ID),
        sprintf("simplify %s: each merged term has a representative with smaller-or-equal padj in a > 0.7 group (%d representatives retained)",
                tag, sum(rel$representative_retained)))
  check(isTRUE(js$simplify$applied) && js$simplify$n_terms == nrow(full) && js$simplify$n_retained == nrow(disp) &&
          js$simplify$n_merged == nrow(rel) && identical(js$simplify$measure, "Wang") && js$simplify$cutoff == 0.7,
        sprintf("simplify %s: JSON rule and counts (similarity %s)", tag, js$simplify$similarity_source))
  draft <- paste(readLines(file.path(out, "draft", "methods_results.md"), warn = FALSE), collapse = "\n")
  check(grepl(sprintf("reduced %d tested terms to %d representative terms; the %d merged terms", nrow(full), nrow(disp), nrow(rel)), draft, fixed = TRUE) &&
          grepl("tables/simplify_relation.csv", draft, fixed = TRUE), paste("simplify", tag, "Methods state rule and relation"))
  if (identical(ont, "ALL")) check(setequal(unique(rel$ontology), c("BP", "CC", "MF")), paste("simplify", tag, "relation per ontology"))
}
simp_run("CC", c("--ontology", "CC"), "CC", FALSE)
simp_run("ALL", c("--ontology", "ALL", "--pool", "FALSE", "--min-size", "200"), "ALL", FALSE)

no_bg <- run(c("--input", input, "--outdir", file.path(tmp,"missing")))
check(status(no_bg) != 0L && any(grepl("OS_MISSING_PARAMETER", no_bg)), "missing universe typed refusal")
missing_ref <- run(c(base, "--database", "KEGG", "--outdir", file.path(tmp,"ref_missing")))
check(status(missing_ref) != 0L && any(grepl("OS_REFDATA_MISSING", missing_ref)), "missing offline KEGG typed refusal")
all_no_pool <- run(c(base, "--ontology", "ALL", "--outdir", file.path(tmp,"all_no_pool")))
check(status(all_no_pool) != 0L && any(grepl("OS_MISSING_PARAMETER", all_no_pool)), "ALL requires explicit pool")
up <- file.path(tmp, "upstream"); dir.create(file.path(up, "objects"), recursive = TRUE, showWarnings = FALSE)
ft <- file.path(up, "objects", "feature_table.csv")
write.csv(data.frame(feature_id = universe, padj = ifelse(universe %in% selected, 0.01, 1)), ft, row.names = FALSE)
write_handoff(up, "dose-fixture", "deseq2-wald", "1.1.0", objects = list(feature_table = list(path = ft, type = "feature_table")))
from <- file.path(tmp, "from_run")
z <- run(c("--from-run", up, "--outdir", from))
check(status(z) == 0L, "from-run with finite padj eligibility")
if (status(z) == 0L && exists("actual")) {
  fr <- read.csv(file.path(from, "tables", "enrichment_full.csv"), check.names = FALSE)
  check(identical(fr$ID, actual$ID) && isTRUE(all.equal(fr$p.adjust, actual$p.adjust, tolerance = 1e-14)), "from-run matches direct input")
}
write("tamper", ft, append = TRUE)
tampered <- run(c("--from-run", up, "--outdir", file.path(tmp,"tampered")))
check(status(tampered) != 0L && any(grepl("OS_HANDOFF_MISMATCH", tampered)), "tampered handoff refused")
check(!file.exists(file.path(suite, "Rplots.pdf")), "no Rplots.pdf")
if (length(fail)) quit(status = 1) else cat("SMOKE PASSED\n")
