# run_smoke_test.R -- fgsea-prerank S2.
# requires: fgsea DESeq2 ggplot2 patchwork ragg svglite jsonlite digest
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
shared <- file.path(suite, "skills", "_shared", "scripts")
for (f in c("args.R", "calls_check.R", "module_kit.R", "handoff.R", "ranked_list.R", "enrich_rank_io.R")) source(file.path(shared, f))
failures <- character(0)
check <- function(x, msg) { if (isTRUE(x)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
sha <- function(p) digest::digest(file = p, algo = "sha256")
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "fgsea-prerank-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
setwd(tmp)
entry <- file.path(module_dir, "scripts", "run_fgsea_prerank.R")
run <- function(...) {
  o <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(o, "status") %||% 0L, out = o)
}

scripts <- list.files(file.path(module_dir, "scripts"), pattern = "[.]R$", full.names = TRUE)
reg <- file.path(module_dir, "scripts", "calls_registry.json")
cc <- check_calls(scripts, reg)
check(cc$ok, paste("call registry", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(reg)
check(dd$ok, paste("default drift", paste(dd$problems, collapse = "; ")))
py <- Sys.which("python3")
if (nzchar(py)) for (tool in c("check_defaults.py", "check_flag_docs.py", "lint_r.py")) {
  arg <- if (tool == "lint_r.py") file.path(module_dir, "scripts") else module_dir
  o <- suppressWarnings(system2(py, c(shQuote(file.path(suite, "tools", tool)), shQuote(arg)), stdout = TRUE, stderr = TRUE))
  check((attr(o, "status") %||% 0L) == 0L, paste(tool, paste(o, collapse = " | ")))
}

# ---- P: printed anchor, the tutorial's own code (never the engine) ---------------
# L1_bioc3.23/fgsea/vignettes/fgsea-tutorial.rendered.txt:17-56 ("Quick run"):
# data(examplePathways); data(exampleRanks); set.seed(42);
# fgseaRes <- fgsea(pathways = examplePathways, stats = exampleRanks, minSize = 15, maxSize = 500)
# head(fgseaRes[order(pval), ]) prints pathway/pval/padj/log2err/ES/NES/size/leadingEdge.
tut <- new.env()
utils::data("examplePathways", package = "fgsea", envir = tut); utils::data("exampleRanks", package = "fgsea", envir = tut)
set.seed(42)
invisible(utils::capture.output(fgseaRes <- suppressWarnings(fgsea::fgsea(pathways = tut$examplePathways, stats = tut$exampleRanks, minSize = 15, maxSize = 500))))
top6 <- utils::head(fgseaRes[order(fgseaRes$pval), ], 6)
printed <- data.frame(
  pathway = c("5990980_Cell_Cycle", "5990979_Cell_Cycle,_Mitotic", "5991851_Mitotic_Prometaphase",
              "5992217_Resolution_of_Sister_Chromatid_Cohesion", "5991454_M_Phase", "5991502_Mitotic_Metaphase_and_Anaphase"),
  pval = c(7.957687e-27, 2.198625e-25, 1.836631e-18, 8.436408e-18, 1.956005e-14, 1.059997e-13),
  padj = c(4.663205e-24, 6.441972e-23, 3.587552e-16, 1.235934e-15, 2.292438e-12, 1.035264e-11),
  log2err = c(1.3422338, 1.3030932, 1.1053366, 1.0864405, 0.9759947, 0.9545416),
  ES = c(0.5388497, 0.5594755, 0.7253270, 0.7347987, 0.5576247, 0.6052906),
  NES = c(2.705894, 2.769070, 2.972690, 2.957518, 2.554076, 2.648685),
  size = c(369L, 317L, 82L, 74L, 173L, 123L), le_n = c(155L, 141L, 44L, 40L, 67L, 51L), stringsAsFactors = FALSE)
printed_le <- list(c("66336", "66977", "12442", "107995", "66442", "19361"), c("66336", "66977", "12442", "107995", "66442", "12571"),
                   c("66336", "66977", "12442", "107995", "66442", "52276"), c("66336", "66977", "12442", "107995", "66442", "52276"),
                   c("66336", "66977", "12442", "107995", "66442", "52276"), c("66336", "66977", "107995", "66442", "52276", "67629"))
# printed precision: |x - printed| <= half a unit in the last printed digit
at_print <- function(x, p, digits) all(abs(x - p) <= 0.5 * 10^(floor(log10(abs(p))) - (digits - 1)) * (1 + 1e-9))
check(identical(top6$pathway, printed$pathway), "P1 tutorial Quick run: the six printed pathways in printed order (tutorial:36-41)")
check(at_print(top6$pval, printed$pval, 7) && at_print(top6$padj, printed$padj, 7),
      sprintf("P2 printed pval/padj at 7 significant digits (tutorial:36-41); got pval %s", paste(signif(top6$pval, 7), collapse = ", ")))
# P3 (S5 R1): one executed condition per printed field. log2err is printed with
# 7 decimals; ES and NES with 7 significant digits; size is an integer.
p3_fields <- function(t) c(
  log2err = all(abs(t$log2err - printed$log2err) <= 0.5e-7 * (1 + 1e-9)),
  ES = at_print(t$ES, printed$ES, 7),
  NES = at_print(t$NES, printed$NES, 7),
  size = identical(as.integer(t$size), printed$size))
p3 <- p3_fields(top6)
check(all(p3),
      sprintf("P3 printed log2err/ES/NES/size (tutorial:44-49) [%s]; got log2err %s; ES %s; NES %s; size %s",
              paste(names(p3), ifelse(p3, "ok", "FAIL"), sep = "=", collapse = ", "),
              paste(signif(top6$log2err, 8), collapse = ", "), paste(signif(top6$ES, 7), collapse = ", "),
              paste(signif(top6$NES, 7), collapse = ", "), paste(top6$size, collapse = ", ")))
# P3 negative control (S5 R1): each field is really checked. Moving one row of
# one field by one unit of its last printed digit, away from the printed value
# (size by 1), in the first and
# in the sixth row, must fail that field and only that field; replacing every
# ES by 999 and every NES by -999 must fail ES and NES.
p3_unit <- list(log2err = function(p) rep(1e-7, length(p)), ES = function(p) 10^(floor(log10(abs(p))) - 6),
                NES = function(p) 10^(floor(log10(abs(p))) - 6), size = function(p) rep(1L, length(p)))
p3_probe <- character(0)
for (fld in names(p3_unit)) for (i in c(1L, 6L)) {
  bad <- as.data.frame(top6)
  x <- bad[[fld]][i]
  bad[[fld]][i] <- x + (if (x >= printed[[fld]][i]) 1 else -1) * p3_unit[[fld]](printed[[fld]])[i]  # away from the printed value
  got <- p3_fields(bad)
  p3_probe <- c(p3_probe, sprintf("%s[%d]:%s", fld, i, if (!got[[fld]] && all(got[setdiff(names(got), fld)])) "caught" else "MISSED"))
}
bad <- as.data.frame(top6); bad$ES <- rep(999, 6); bad$NES <- rep(-999, 6)
got <- p3_fields(bad)
p3_probe <- c(p3_probe, sprintf("ES=999,NES=-999:%s", if (!got[["ES"]] && !got[["NES"]] && got[["log2err"]] && got[["size"]]) "caught" else "MISSED"))
check(all(p3) && !any(grepl("MISSED", p3_probe, fixed = TRUE)),
      sprintf("P3 negative control: per-field perturbations fail the printed-precision check (%s)", paste(p3_probe, collapse = ", ")))
check(identical(as.integer(lengths(top6$leadingEdge)), printed$le_n) &&
        all(vapply(seq_len(6), function(i) identical(utils::head(as.character(top6$leadingEdge[[i]]), 6), printed_le[[i]]), logical(1))),
      "P4 printed leadingEdge heads and lengths 155/141/44/40/67/51 (tutorial:51-56)")

data("exampleRanks", package = "fgsea")
stats <- sort(exampleRanks, decreasing = TRUE)
rank_path <- file.path(tmp, "ranks.csv")
utils::write.csv(data.frame(feature_id = names(stats), symbol = "", score = unname(stats)), rank_path, row.names = FALSE)
check(sha(rank_path) == "18a41efbab53aa9e60380b495615d8ac5f98494ef7fd465525b94ec17c55488a",
      "fgsea package exampleRanks input CSV SHA-256 anchor")
base <- c("--ranked-list", shQuote(rank_path), "--direction", shQuote("positive means Th1 versus naive"),
          "--rank-metric", "other", "--metric-name", shQuote("fgsea tutorial exampleRanks, statistic unspecified"),
          "--collection", "fgsea_example_pathways")
a1 <- file.path(tmp, "a1")
o <- run(base, "--outdir", shQuote(a1))
check(o$status == 0, paste("package example anchor runs", paste(utils::tail(o$out, 1), collapse = "")))
if (o$status == 0) {
  j <- jsonlite::fromJSON(file.path(a1, "results", "fgsea_prerank_results.json"))
  tab <- utils::read.csv(file.path(a1, "tables", "enrichment_table.csv"), stringsAsFactors = FALSE)
  check(j$n_genes == 12000 && j$n_sets == 1457 && j$n_retained == 586 && nrow(tab) == 586,
        "examplePathways replay anchor: 12,000 ranked genes, 1,457 input sets, 586 retained")
  check(j$n_sig == 124 && abs(tab$nes[tab$term_id == "5990979_Cell_Cycle,_Mitotic"] - 2.75941576990235) < 1e-12,
        "fixed-seed package example replay: 124 BH-significant, Cell Cycle Mitotic NES 2.75941576990235")
  data("examplePathways", package = "fgsea")
  set.seed(20260925)
  replay <- fgsea::fgseaMultilevel(pathways = examplePathways, stats = os_rank_read(rank_path)$stats,
                                  sampleSize = 101, minSize = 15, maxSize = 500, eps = 1e-50,
                                  scoreType = "std", nproc = 1, gseaParam = 1, BPPARAM = NULL,
                                  nPermSimple = 1000, absEps = NULL)
  row <- replay[replay$pathway == "5990979_Cell_Cycle,_Mitotic"]
  check(abs(unname(row$NES) - tab$nes[tab$term_id == row$pathway]) < 1e-12,
        "tutorial fixture independent direct-call replay NES equals engine")
  check(file.exists(file.path(a1, "figures", "nes_bar.png")) && file.exists(file.path(a1, "figures", "gsea_curve.png")),
        "standard figures emitted")
  sp <- jsonlite::fromJSON(file.path(a1, "figures", "nes_bar.figure_spec.json"))
  check(grepl("0.05", sp$caption, fixed = TRUE) && grepl("124", sp$caption, fixed = TRUE),
        "NES figure caption states BH threshold and significant-set count")
  check(!grepl("up-regulated", sp$caption, fixed = TRUE) && !grepl("down-regulated", sp$caption, fixed = TRUE) &&
          grepl("positive end of the ranking (fgsea tutorial exampleRanks, statistic unspecified: positive means Th1 versus naive)", sp$caption, fixed = TRUE),
        "S4-F3 NES caption names the declared ranking direction, not up/down-regulated genes")
  sg <- !is.na(tab$padj) & tab$padj < 0.05
  ord_ok <- all(diff(as.integer(!sg)) >= 0) && !is.unsorted(-tab$nes[sg]) && !is.unsorted(-tab$nes[!sg & !is.na(tab$nes)])
  check(ord_ok, "S4-F2 table order: significant sets first, NES descending within the significant and non-significant groups (PACK T)")
  check(identical(read_handoff(a1, expect = list(ranked_list = "ranked_list", gene_sets = "gene_sets",
                                                     enrichment_table = "enrichment_table"))$module, "fgsea-prerank"),
        "typed handoff readable")
  gold_paths <- c("tables/enrichment_table.csv", "results/fgsea_prerank_results.json",
                  "figures/nes_bar.png", "figures/nes_bar.figure_spec.json",
                  "figures/gsea_curve.png", "figures/gsea_curve.figure_spec.json")
  if (Sys.getenv("OMICSTAT_WRITE_GOLDEN") == "1") os_golden_write(module_dir, a1, gold_paths)
  gc <- os_golden_check(module_dir, a1)
  check(gc$status %in% c("PASS", "SKIP"), paste("golden", gc$status, paste(gc$problems, collapse = ",")))
  if (length(readLines(file.path(module_dir, "tests", "golden_manifest.csv"))) > 1)
    check(gc$status == "PASS", "same-signature golden hashes match")

  a2 <- file.path(tmp, "a2")
  o2 <- run("--spec", shQuote(file.path(a1, "provenance", "resolved_spec.json")), "--outdir", shQuote(a2))
  check(o2$status == 0 && sha(file.path(a1, "tables", "enrichment_table.csv")) == sha(file.path(a2, "tables", "enrichment_table.csv")) &&
          sha(file.path(a1, "figures", "nes_bar.png")) == sha(file.path(a2, "figures", "nes_bar.png")),
        "--spec replay yields byte-identical table and PNG")
  a3 <- file.path(tmp, "a3")
  o3 <- run("--from-run", shQuote(a1), "--collection", "fgsea_example_pathways", "--outdir", shQuote(a3))
  check(o3$status != 0 && any(grepl("OS_HANDOFF_MISMATCH: the ranked_list carries no metadata", o3$out, fixed = TRUE)),
        "S4 --from-run of a user-declared ranking (no omicstat metadata) is refused instead of guessing its meaning")
  a4 <- file.path(tmp, "a4")
  o4 <- run(base, "--min-size", "100", "--outdir", shQuote(a4))
  j4 <- if (o4$status == 0) jsonlite::fromJSON(file.path(a4, "results", "fgsea_prerank_results.json")) else NULL
  check(o4$status == 0 && j4$n_retained < j$n_retained, "--min-size changes the tested set population")
  tamper <- file.path(tmp, "tamper")
  dir.create(tamper)
  system2("cp", c("-a", shQuote(paste0(a1, "/.")), shQuote(tamper)))
  write("bad", file.path(tamper, "objects", "ranked_list.csv"), append = TRUE)
  ot <- run("--from-run", shQuote(tamper), "--direction", "up", "--collection", "fgsea_example_pathways", "--outdir", shQuote(file.path(tmp, "tamper_out")))
  check(ot$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", ot$out, fixed = TRUE)), "tampered upstream refused")
}
# ---- R: real deseq2-wald -> fgsea chain (S4 contract a) ----------------------------
set.seed(7)
ids <- names(exampleRanks)
cnt <- matrix(stats::rnbinom(length(ids) * 6, mu = 150, size = 8), length(ids), 6, dimnames = list(ids, paste0("s", 1:6)))
data("examplePathways", package = "fgsea")
cc_ids <- intersect(examplePathways[["5990980_Cell_Cycle"]], ids)
cnt[cc_ids, 4:6] <- cnt[cc_ids, 4:6] * 3L
utils::write.csv(data.frame(feature_id = ids, cnt, check.names = FALSE), file.path(tmp, "wald_counts.csv"), row.names = FALSE)
utils::write.csv(data.frame(sample = colnames(cnt), condition = rep(c("ctrl", "trt"), each = 3)), file.path(tmp, "wald_samples.csv"), row.names = FALSE)
wd <- file.path(tmp, "wald_up")
ow <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(suite, "skills", "deseq2-wald", "scripts", "run_deseq2_wald.R")),
      "--counts", shQuote(file.path(tmp, "wald_counts.csv")), "--samples", shQuote(file.path(tmp, "wald_samples.csv")),
      "--reference", "ctrl", "--target", "trt", "--shrinkage", "none", "--outdir", shQuote(wd)), stdout = TRUE, stderr = TRUE))
check((attr(ow, "status") %||% 0L) == 0L, paste("R0 upstream deseq2-wald run on exampleRanks IDs exits 0", paste(utils::tail(ow, 2), collapse = " | ")))
if ((attr(ow, "status") %||% 0L) == 0L) {
  rw <- file.path(tmp, "wald_fgsea")
  o <- run("--from-run", shQuote(wd), "--collection", "fgsea_example_pathways", "--outdir", shQuote(rw))
  check(o$status == 0, paste("R1 real deseq2-wald -> fgsea --from-run exits 0", paste(utils::tail(o$out, 2), collapse = " | ")))
  if (o$status == 0) {
    d <- readLines(file.path(rw, "draft", "methods_results.md"))
    tb <- utils::read.csv(file.path(rw, "tables", "enrichment_table.csv"), stringsAsFactors = FALSE)
    sp <- jsonlite::fromJSON(file.path(rw, "figures", "nes_bar.figure_spec.json"))
    check(any(grepl("The ranking metric was DESeq2 Wald statistic; positive scores mean higher expression in trt than in ctrl.", d, fixed = TRUE)) &&
            grepl("DESeq2 Wald statistic: higher expression in trt than in ctrl", sp$caption, fixed = TRUE),
          "R2 metric and direction come from the upstream ranked_list metadata (Methods and NES caption)")
    cc <- tb[tb$term_id == "5990980_Cell_Cycle", ]
    check(nrow(cc) == 1 && cc$nes > 0 && cc$padj < 0.05, "R3 the planted Cell Cycle up-shift is enriched at the positive end")
    hd <- jsonlite::fromJSON(file.path(rw, "objects", "handoff.json"))
    check(identical(hd$state$ranked_list$statistic, "wald_stat"), "R4 the validated ranking metadata is handed on")
  }
  o <- run("--from-run", shQuote(wd), "--rank-metric", "moderated_t", "--collection", "fgsea_example_pathways", "--outdir", shQuote(file.path(tmp, "wald_conflict")))
  check(o$status != 0 && any(grepl("OS_CONFLICTING_PARAMETERS", o$out, fixed = TRUE)), "R5 an explicit --rank-metric that contradicts the metadata is refused")
  und <- file.path(tmp, "undirectional"); dir.create(file.path(und, "objects"), recursive = TRUE)
  invisible(file.copy(file.path(wd, "objects", "ranked_list.csv"), file.path(und, "objects", "ranked_list.csv")))
  hm <- jsonlite::fromJSON(file.path(wd, "objects", "handoff.json"), simplifyVector = FALSE)$state$ranked_list
  hm$directional <- FALSE
  write_handoff(und, "undirectional", "deseq2-lrt", "1.0.0", objects = list(ranked_list = list(path = file.path(und, "objects", "ranked_list.csv"), type = "ranked_list")),
                state = list(ranked_list = hm))
  o <- run("--from-run", shQuote(und), "--collection", "fgsea_example_pathways", "--outdir", shQuote(file.path(tmp, "und_out")))
  check(o$status != 0 && any(grepl("OS_RANKING_UNDIRECTIONAL", o$out, fixed = TRUE)), "R6 an undirectional ranking (LRT / F) is refused")
}

bad <- file.path(tmp, "bad.csv")
utils::write.csv(data.frame(feature_id = c("g1", "g1"), symbol = "", score = c(1, Inf)), bad, row.names = FALSE)
ob <- run("--ranked-list", shQuote(bad), "--direction", "up", "--collection", "fgsea_example_pathways", "--outdir", shQuote(file.path(tmp, "bad_out")))
check(ob$status != 0 && any(grepl("OS_INVALID_INPUT", ob$out, fixed = TRUE)), "duplicate/nonfinite ranking refused")
om <- run(base[1:4], "--outdir", shQuote(file.path(tmp, "missing_ref")))
check(om$status != 0 && any(grepl("OS_REFDATA_MISSING", om$out, fixed = TRUE)), "unresolved Hallmark registry preset refused")

# ---- user-supplied gene sets: --collection user (CONVENTIONS "User-supplied gene-set collections") ----
# exampleRanks are mouse Entrez IDs; the synthetic KEGG-like sets (mmu) are drawn from them.
source(file.path(suite, "skills", "_shared", "scripts", "user_genesets.R"))
source(file.path(suite, "skills", "_shared", "tests", "user_genesets_testkit.R"))
rz <- function(...) { o <- run(...); structure(o$out, status = o$status) }
ugs_sets <- ugs_kegg_like_sets(head(names(stats), 300), names(stats)[-(1:300)])
ugs <- ugs_fixture(file.path(tmp, "user_sets"), ugs_sets, "ENTREZID", species = "mmu", lowfn = function(i) as.character(990000000 + i))
ubase <- c(base[1:8], "--collection", "user", "--gene-sets", shQuote(ugs$gmt), "--feature-id-type", "ENTREZID")
cu <- file.path(tmp, "user_anchor")
o <- run(ubase, "--gene-sets-provenance", shQuote(ugs$prov), "--outdir", shQuote(cu))
check(o$status == 0, paste("user: user GMT fgsea run", paste(utils::tail(o$out, 2), collapse = " | ")))
if (o$status == 0) {
  ut <- utils::read.csv(file.path(cu, "tables", "enrichment_table.csv"), stringsAsFactors = FALSE)
  set.seed(20260925)
  ur <- fgsea::fgseaMultilevel(pathways = ugs_sets, stats = os_rank_read(rank_path)$stats, sampleSize = 101, minSize = 15, maxSize = 500,
                               eps = 1e-50, scoreType = "std", nproc = 1, gseaParam = 1, BPPARAM = NULL, nPermSimple = 1000, absEps = NULL)
  m <- match(ur$pathway, ut$term_id)
  check(!anyNA(m) && max(abs(ur$NES - ut$nes[m])) < 1e-12 && max(abs(ur$padj - ut$padj[m])) < 1e-12,
        sprintf("user: replay equals direct fgseaMultilevel on the user sets (%d sets)", nrow(ur)))
  check(all(c("hsa04110", "KEGG_APOPTOSIS") %in% ut$term_id) && all(ut$database == "KEGG REST (user-supplied)"),
        "user: KEGG-style term IDs accepted; database label is the user's source")
  uj <- jsonlite::fromJSON(file.path(cu, "results", "fgsea_prerank_results.json"))
  check(identical(uj$user_gene_sets$origin, "user-supplied, not bundled with omicstat") && identical(uj$collection_species, "Mus musculus"),
        "user: results JSON carries the user collection record")
  ugs_check_recorded(check, cu, "user fgsea", length(ugs_sets), species = "Mus musculus")
  ur2 <- file.path(tmp, "user_replay")
  o <- run("--spec", shQuote(file.path(cu, "provenance", "resolved_spec.json")), "--outdir", shQuote(ur2))
  check(o$status == 0 && sha(file.path(cu, "tables", "enrichment_table.csv")) == sha(file.path(ur2, "tables", "enrichment_table.csv")),
        "user: byte-identical --spec replay")
}
ugs_refused(check, rz(ubase[-length(ubase)], "SYMBOL", "--gene-sets-provenance", shQuote(ugs$prov), "--outdir", shQuote(file.path(tmp, "user_idtype"))),
            "OS_GENE_SET_ID_MISMATCH", "user: gene-set ENTREZID vs --feature-id-type SYMBOL")
ugs_refused(check, rz(ubase, "--gene-sets-provenance", shQuote(ugs$bad_sha), "--outdir", shQuote(file.path(tmp, "user_sha"))),
            "OS_REFDATA_MISMATCH", "user: sha256 differing from provenance")
ugs_refused(check, rz(base[1:8], "--collection", "user", "--gene-sets", shQuote(ugs$low), "--gene-sets-provenance", shQuote(ugs$low_prov),
                      "--feature-id-type", "ENTREZID", "--outdir", shQuote(file.path(tmp, "user_low"))), "OS_GENE_SET_LOW_OVERLAP", "user: under 10% overlap with the ranking")
ugs_refused(check, rz(ubase[1:12], "--gene-sets-provenance", shQuote(ugs$prov), "--outdir", shQuote(file.path(tmp, "user_noid"))),
            "OS_MISSING_PARAMETER", "user: no --feature-id-type")
ugs_refused(check, rz(base, "--gene-sets-provenance", shQuote(ugs$prov), "--outdir", shQuote(file.path(tmp, "reg_with_contract"))),
            "OS_CONFLICTING_PARAMETERS", "user: contract flags with a registered collection")
ok <- run(base[1:8], "--collection", "kegg", "--outdir", shQuote(file.path(tmp, "kegg_route")))
check(ok$status != 0 && any(grepl("OS_REFDATA_MISSING", ok$out)) && any(grepl("--collection user", ok$out, fixed = TRUE)),
      "unregistered KEGG collection explains the user-supplied route")
check(!file.exists(file.path(tmp, "Rplots.pdf")), "no Rplots.pdf device leak")
if (length(failures)) quit(status = 1) else cat("SMOKE PASSED\n")
