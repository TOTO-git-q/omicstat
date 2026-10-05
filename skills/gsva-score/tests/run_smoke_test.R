# run_smoke_test.R -- gsva-score S2 + S4 (F1-F4, contracts b and c).
# requires: GSVA BiocParallel GSVAdata Biobase limma edgeR ggplot2 patchwork ragg svglite jsonlite digest
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
shared <- file.path(suite, "skills", "_shared", "scripts")
for (f in c("args.R", "calls_check.R", "module_kit.R", "handoff.R", "enrich_rank_io.R")) source(file.path(shared, f))
source(file.path(here, "fixtures", "make_gbm.R"))
source(file.path(here, "fixtures", "make_yoruba_counts.R"))
failures <- character(0)
check <- function(x, msg) { if (isTRUE(x)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
sha <- function(p) digest::digest(file = p, algo = "sha256")
has_code <- function(o, code) o$status != 0 && any(grepl(code, o$out, fixed = TRUE))
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "gsva-score-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
setwd(tmp)
entry <- file.path(module_dir, "scripts", "run_gsva_score.R")
rscript <- file.path(R.home("bin"), "Rscript")
run_entry <- function(script, ...) {
  o <- suppressWarnings(system2(rscript, c(shQuote(script), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(o, "status") %||% 0L, out = o)
}
run <- function(...) run_entry(entry, ...)
read_scores <- function(dir) {
  d <- utils::read.csv(file.path(dir, "tables", "scores.csv"), check.names = FALSE)
  m <- as.matrix(d[, -1, drop = FALSE]); rownames(m) <- d$feature_id; m
}
reg <- file.path(module_dir, "scripts", "calls_registry.json")
scripts <- list.files(file.path(module_dir, "scripts"), pattern = "[.]R$", full.names = TRUE)
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

fix <- make_gbm(file.path(tmp, "fixture"), suite)
if (is.null(fix)) { cat("SKIP: GSVAdata sha256-locked acceptance layer absent\n"); quit(status = if (length(failures)) 1 else 0) }
check(sha(fix$expression) == "93027d9f196fb704fb8e7c146ec382bf2bf27a2f0f5deb51c8a2e9162ec3f19c" &&
        sha(fix$samples) == "fade8abcb255460b9f45f2552aaad1b03432b11a23c277ee9793b0de251ab8d0",
      "GSVAdata gbm fixture CSV inputs match locked replay hashes")
base <- c("--input", shQuote(fix$expression), "--input-scale", "normalized_array",
          "--collection", "gsva_brain_txdb_sets", "--samples", shQuote(fix$samples), "--group-col", "subtype")
# ---- F1: inference requests are refused (S1 P-3 owner-pending) ----
for (req in list(c("--reference", "Proneural", "--target", "Classical"), c("--covariates", "subtype"), c("--target", "Classical"))) {
  o <- run(base, req, "--outdir", shQuote(file.path(tmp, "f1_refused")))
  check(has_code(o, "OS_OWNER_DECISION_PENDING") && !dir.exists(file.path(tmp, "f1_refused")),
        paste("F1: inference request", paste(req, collapse = " "), "refused with OS_OWNER_DECISION_PENDING before any output"))
}

# ---- F2 A-vig: GSVA vignette sec 7.1 GBM workflow, the vignette's OWN code (GSVA.rendered.txt:683-724, gsvaParam/gsva at :723-724) ----
# PRINTED anchor for dimensions / group counts / set sizes and members; REPLAY (full score matrix) for the scores,
# which the vignette does not print. Data via the sha256-locked acceptance layer (data(gbm_VerhaakEtAl), data(brainTxDbSets)).
gbm_eset <- os_acceptance_data(suite, "GSVAdata", "gbm_VerhaakEtAl")
brainTxDbSets <- os_acceptance_data(suite, "GSVAdata", "brainTxDbSets")
check(identical(unname(dim(Biobase::exprs(gbm_eset))), c(11861L, 173L)), "A-vig printed: gbm_eset 11861 features, 173 samples (:686)")
check(identical(head(Biobase::featureNames(gbm_eset)), c("AACS", "FSTL1", "ELMO2", "CREB3L1", "RPS11", "PNMA1")),
      "A-vig printed: head(featureNames(gbm_eset)) (:697-698)")
tab <- table(gbm_eset$subtype)
check(identical(as.integer(tab[c("Classical", "Mesenchymal", "Neural", "Proneural")]), c(38L, 56L, 26L, 53L)) && length(tab) == 4L,
      "A-vig printed: table(gbm_eset$subtype) Classical 38, Mesenchymal 56, Neural 26, Proneural 53 (:699-702)")
check(identical(lengths(brainTxDbSets), c(astrocytic_up = 85L, astroglia_up = 88L, neuronal_up = 98L, oligodendrocytic_up = 70L)),
      "A-vig printed: lengths(brainTxDbSets) 85, 88, 98, 70 (:704-706)")
printed_heads <- list(astrocytic_up = c("GRHL1", "GPAM", "PAPSS2", "MERTK", "BTG1", "SLC46A1"),
                      astroglia_up = c("BST2", "SERPING1", "ACTA2", "C9orf167", "C1orf31", "ANXA4"),
                      neuronal_up = c("STXBP1", "JPH4", "CACNG3", "BRUNOL6", "CLSTN2", "FAM123C"),
                      oligodendrocytic_up = c("DCT", "ZNF536", "GNG8", "ELOVL6", "NR2C1", "RCBTB1"))
check(identical(lapply(brainTxDbSets, head), printed_heads), "A-vig printed: lapply(brainTxDbSets, head) (:707-718)")
gbmPar <- GSVA::gsvaParam(gbm_eset, brainTxDbSets, maxDiff = FALSE)
gbm_es <- GSVA::gsva(gbmPar)
vig <- Biobase::exprs(gbm_es)
check(identical(dim(vig), c(4L, 173L)) && all(is.finite(vig)), "A-vig replay: vignette gsva(gbmPar) gives a finite 4 x 173 score matrix")
# The vignette prints no score values; its text (:727-735) states which subtype each set marks. Checked on the vignette's
# own maxDiff=FALSE score matrix as a qualitative printed-text anchor (group means; no test).
gm <- sapply(split(seq_len(ncol(vig)), as.character(gbm_eset$subtype)), function(i) rowMeans(vig[, i, drop = FALSE]))
top <- function(s) names(sort(gm[s, ], decreasing = TRUE))
check(top("neuronal_up")[1] == "Neural" && top("astroglia_up")[1] == "Mesenchymal" && top("oligodendrocytic_up")[1] == "Proneural" &&
        setequal(top("astrocytic_up")[1:2], c("Classical", "Neural")),
      sprintf("A-vig text (:727-735): highest mean score neuronal_up=%s, astroglia_up=%s, oligodendrocytic_up=%s; astrocytic_up top two %s",
              top("neuronal_up")[1], top("astroglia_up")[1], top("oligodendrocytic_up")[1], paste(top("astrocytic_up")[1:2], collapse = "+")))
fx <- utils::read.csv(fix$expression, check.names = FALSE); fxm <- as.matrix(fx[, -1]); rownames(fxm) <- fx$feature_id
vig_csv <- GSVA::gsva(GSVA::gsvaParam(fxm, brainTxDbSets, maxDiff = FALSE))
check(identical(dimnames(vig_csv), dimnames(vig)) && max(abs(vig_csv - vig)) < 1e-12,
      sprintf("A-vig replay: full vignette score matrix on the engine's CSV input equals the ExpressionSet route (max |diff| %.2e)", max(abs(vig_csv - vig))))

# ---- engine run on the suite preset ----
a1 <- file.path(tmp, "a1")
o <- run(base, "--outdir", shQuote(a1))
check(o$status == 0, paste("GBM suite-preset run", paste(utils::tail(o$out, 1), collapse = "")))
if (o$status == 0) {
  j <- jsonlite::fromJSON(file.path(a1, "results", "gsva_score_results.json"))
  for (consumer in c("limma-array","limma-dupcor","limma-camera")) {
    extra <- switch(consumer,"limma-array"=c("--platform","agilent","--reference","Proneural","--target","Classical"),"limma-dupcor"=c("--mode","array","--block","subtype","--block-description","fixture","--reference","Proneural","--target","Classical"),"limma-camera"=c("--question","competitive"))
    refused <- run_entry(file.path(suite,"skills",consumer,"scripts",paste0("run_",gsub("-","_",consumer),".R")),"--from-run",shQuote(a1),extra,"--outdir",shQuote(file.path(tmp,paste0("inference-",consumer))))
    check(has_code(refused,"OS_OWNER_DECISION_PENDING"),paste("GSVA from-run inference refused by",consumer))
  }
  eng <- read_scores(a1)
  sizes <- utils::read.csv(file.path(a1, "tables", "gene_set_sizes.csv"), stringsAsFactors = FALSE)
  check(j$n_features == 11861 && j$n_samples == 173 && j$n_scored == 4 && j$kernel == "Gaussian",
        "suite preset: 11,861 features, 173 samples, 4 scores, Gaussian auto branch")
  # F2 A-suite: frozen suite preset replayed directly with GSVA on the ExpressionSet (REPLAY anchor, not printed).
  set.seed(20260925)
  suitePar <- GSVA::gsvaParam(exprData = gbm_eset, geneSets = brainTxDbSets, minSize = 5, maxSize = 500, kcdf = "auto",
                              kcdfNoneMinSampleSize = 200, tau = 1, maxDiff = TRUE, absRanking = FALSE, sparse = TRUE,
                              checkNA = "auto", use = "everything", filterRows = TRUE, ondisk = "auto", verbose = FALSE)
  suite_es <- GSVA::gsva(param = suitePar, verbose = FALSE, BPPARAM = BiocParallel::SerialParam(progressbar = FALSE, RNGseed = 20260925))
  sm <- Biobase::exprs(suite_es)[rownames(eng), colnames(eng)]
  check(max(abs(sm - eng)) < 1e-12,
        sprintf("A-suite replay: engine's complete 4 x 173 score table equals direct GSVA suite preset (max |diff| %.2e)", max(abs(sm - eng))))
  gss <- GSVA::geneSetSizes(suite_es)
  check(identical(sizes$term_id, sort(names(brainTxDbSets), method = "radix")) &&
          identical(as.integer(sizes$n_collection), unname(lengths(brainTxDbSets)[sizes$term_id])) &&
          identical(as.integer(sizes$n_used_by_gsva), unname(as.integer(gss[sizes$term_id]))) && all(sizes$status == "retained"),
        paste("F3: per-set table matches collection lengths and GSVA's own geneSetSizes():",
              paste(sprintf("%s %d->%d", sizes$term_id, sizes$n_collection, sizes$n_used_by_gsva), collapse = ", ")))
  vs <- max(abs(vig[rownames(eng), colnames(eng)] - eng))
  cat(sprintf("INFO: vignette route (maxDiff=FALSE, 1-Inf) vs suite preset (maxDiff=TRUE, 5-500): max |score diff| %.4f; the two routes are distinct\n", vs))
  check(vs > 1e-3, "vignette route and suite preset are separate computations (maxDiff FALSE vs TRUE)")
  # F1: no inference artefacts, Methods say so.
  dr <- readLines(file.path(a1, "draft", "methods_results.md"), warn = FALSE)
  check(!file.exists(file.path(a1, "tables", "score_limma.csv")) && !file.exists(file.path(a1, "tables", "score_design.csv")) &&
          isFALSE(j$inference) && any(grepl("No group inference was performed on the scores", dr, fixed = TRUE)) &&
          !any(grepl("eBayes used|adj.P|BH adjusted", dr)),
        "F1: no score inference table, JSON inference=false, Methods state that inference awaits the owner")
  # F3: table, JSON and Methods agree.
  used <- sizes$n_used_by_gsva
  rng <- sprintf("%d-%d, median %s", min(used), max(used), format(stats::median(used)))
  js <- j$set_sizes
  check(any(grepl("4 of 4 sets were scored (0 excluded: none excluded)", dr, fixed = TRUE)) && any(grepl(rng, dr, fixed = TRUE)) &&
          identical(as.integer(js$n_used_by_gsva), as.integer(sizes$n_used_by_gsva)) && identical(js$term_id, sizes$term_id) &&
          j$n_retained == 4 && j$n_excluded == 0,
        paste("F3: Methods/JSON/table agree on per-set sizes; used sizes", rng))
  check(file.exists(file.path(a1, "objects", "gsva_param.rds")) && file.exists(file.path(a1, "figures", "score_heatmap.png")) &&
          file.exists(file.path(a1, "figures", "score_by_group.png")), "parameter object, heatmap and score-by-group figure recorded")
  sp <- jsonlite::fromJSON(file.path(a1, "figures", "score_heatmap.figure_spec.json"))
  check(grepl("24 of 173", sp$caption, fixed = TRUE) && grepl("5-500", sp$caption, fixed = TRUE),
        "heatmap caption states shown/full n and set-size threshold")
  sg <- jsonlite::fromJSON(file.path(a1, "figures", "score_by_group.figure_spec.json"))
  check(grepl("Classical n = 38", sg$caption, fixed = TRUE) && grepl("Proneural n = 53", sg$caption, fixed = TRUE) &&
          grepl("4 of 4 gene sets", sg$caption, fixed = TRUE) && grepl("no group test", sg$caption, fixed = TRUE),
        "F4: score-by-group caption states group n, sets shown and that no test is drawn")
  check(any(grepl("score_by_group", dr, fixed = TRUE)) && any(grepl("score_heatmap", dr, fixed = TRUE)), "F4: both figure legends in the draft")
  check(identical(read_handoff(a1, expect = list(expression_matrix = "expression_matrix", gene_sets = "gene_sets",
                                                 sample_table = "sample_table", gene_set_sizes = "gene_set_sizes"))$module, "gsva-score"),
        "typed score-matrix handoff readable")
  gold_paths <- c("tables/scores.csv", "tables/gene_set_sizes.csv", "results/gsva_score_results.json",
                  "figures/score_heatmap.png", "figures/score_heatmap.figure_spec.json",
                  "figures/score_by_group.png", "figures/score_by_group.figure_spec.json")
  if (Sys.getenv("OMICSTAT_WRITE_GOLDEN") == "1") os_golden_write(module_dir, a1, gold_paths)
  gc <- os_golden_check(module_dir, a1)
  check(gc$status %in% c("PASS", "SKIP"), paste("golden", gc$status, paste(gc$problems, collapse = ",")))
  if (length(readLines(file.path(module_dir, "tests", "golden_manifest.csv"))) > 1) check(gc$status == "PASS", "same-signature golden hashes match")
  a2 <- file.path(tmp, "a2")
  o2 <- run("--spec", shQuote(file.path(a1, "provenance", "resolved_spec.json")), "--outdir", shQuote(a2))
  check(o2$status == 0 && sha(file.path(a1, "tables", "scores.csv")) == sha(file.path(a2, "tables", "scores.csv")) &&
          sha(file.path(a1, "figures", "score_heatmap.png")) == sha(file.path(a2, "figures", "score_heatmap.png")) &&
          sha(file.path(a1, "figures", "score_by_group.png")) == sha(file.path(a2, "figures", "score_by_group.png")),
        "--spec replay yields byte-identical score table and PNGs")
  a3 <- file.path(tmp, "a3")
  o3 <- run(base, "--kcdf", "Gaussian", "--outdir", shQuote(a3))
  check(o3$status == 0 && sha(file.path(a1, "tables", "scores.csv")) == sha(file.path(a3, "tables", "scores.csv")),
        "auto branch actually uses Gaussian for 173 continuous samples")
  a4 <- file.path(tmp, "a4")
  o4 <- run(base, "--max-size", "60", "--outdir", shQuote(a4))
  j4 <- if (o4$status == 0) jsonlite::fromJSON(file.path(a4, "results", "gsva_score_results.json")) else NULL
  s4 <- if (o4$status == 0) utils::read.csv(file.path(a4, "tables", "gene_set_sizes.csv"), stringsAsFactors = FALSE) else NULL
  d4 <- if (o4$status == 0) readLines(file.path(a4, "draft", "methods_results.md"), warn = FALSE) else ""
  check(o4$status == 0 && j4$n_scored < j$n_scored && j4$n_scored == sum(s4$status == "retained") &&
          all(grepl("more than 60 members", s4$reason[s4$status == "excluded"], fixed = TRUE)) &&
          any(grepl(sprintf("%d of 4 sets were scored (%d excluded: %d: more than 60 members", j4$n_scored, 4 - j4$n_scored, 4 - j4$n_scored), d4, fixed = TRUE)),
        "F3: --max-size 60 excludes sets with the reason in table, JSON and Methods")
  up <- file.path(tmp, "upstream")
  dir.create(file.path(up, "objects"), recursive = TRUE)
  file.copy(fix$expression, file.path(up, "objects", "expression.csv"))
  file.copy(fix$samples, file.path(up, "objects", "samples.csv"))
  write_handoff(up, run_id = "upstream", module = "fixture", module_version = "1.0.0",
                objects = list(expression_matrix = list(path = file.path(up, "objects", "expression.csv"), type = "expression_matrix"),
                               sample_table = list(path = file.path(up, "objects", "samples.csv"), type = "sample_table")))
  a5 <- file.path(tmp, "a5")
  o5 <- run("--from-run", shQuote(up), "--input-scale", "normalized_array", "--collection", "gsva_brain_txdb_sets",
            "--group-col", "subtype", "--outdir", shQuote(a5))
  check(o5$status == 0 && sha(file.path(a1, "tables", "scores.csv")) == sha(file.path(a5, "tables", "scores.csv")),
        "--from-run carries typed expression and sample table")
  write("bad", file.path(up, "objects", "expression.csv"), append = TRUE)
  ot <- run("--from-run", shQuote(up), "--input-scale", "normalized_array", "--collection", "gsva_brain_txdb_sets", "--outdir", shQuote(file.path(tmp, "tamper")))
  check(has_code(ot, "OS_HANDOFF_MISMATCH"), "tampered upstream refused")
  # ---- contract c: scores of a batch-corrected input keep the corrected lineage ----
  corr <- file.path(tmp, "corrected")
  dir.create(file.path(corr, "objects"), recursive = TRUE)
  file.copy(fix$expression, file.path(corr, "objects", "expression.csv"))
  file.copy(fix$samples, file.path(corr, "objects", "samples.csv"))
  write_handoff(corr, run_id = "corrected", module = "sva-batch", module_version = "fixture",
                objects = list(expression_matrix = list(path = file.path(corr, "objects", "expression.csv"), type = "batch_corrected_matrix"),
                               sample_table = list(path = file.path(corr, "objects", "samples.csv"), type = "sample_table")))
  cs <- file.path(tmp, "corrected_scores")
  oc <- run("--from-run", shQuote(corr), "--input-scale", "normalized_array", "--collection", "gsva_brain_txdb_sets",
            "--group-col", "subtype", "--outdir", shQuote(cs))
  hc <- if (oc$status == 0) jsonlite::fromJSON(file.path(cs, "objects", "handoff.json")) else NULL
  qcc <- if (oc$status == 0) utils::read.csv(file.path(cs, "qc", "qc_results.csv")) else NULL
  check(oc$status == 0 && isTRUE(hc$state$batch_corrected_lineage) &&
          hc$objects$type[hc$objects$name == "expression_matrix"] == "batch_corrected_matrix" &&
          as.logical(qcc$triggered[qcc$id == "GV-03"]),
        "contract c: scores of a corrected input are typed batch_corrected_matrix with batch_corrected_lineage = TRUE")
  e1 <- tryCatch({ read_handoff(cs, expect = list(expression_matrix = "expression_matrix")); "no error" }, error = function(e) conditionMessage(e))
  check(grepl("OS_BATCH_CORRECTED_INPUT", e1, fixed = TRUE), "contract c: a DE-style consumer (read_handoff expect expression_matrix) refuses them")
  e2 <- tryCatch({ read_handoff(cs, expect = list(expression_matrix = "batch_corrected_matrix", sample_table = "sample_table")); "ok" }, error = function(e) conditionMessage(e))
  check(identical(e2, "ok"), "contract c: display consumers may still read them as batch_corrected_matrix")
  cam <- run_entry(file.path(suite, "skills", "limma-camera", "scripts", "run_limma_camera.R"), "--from-run", shQuote(cs),
                   "--question", "competitive", "--group-col", "subtype", "--reference", "Proneural", "--target", "Classical",
                   "--collection", "gsva_brain_txdb_sets", "--outdir", shQuote(file.path(tmp, "camera_on_corrected")))
  check(has_code(cam, "OS_BATCH_CORRECTED_INPUT"), "contract c: limma-camera refuses the corrected-lineage scores (OS_BATCH_CORRECTED_INPUT)")
}

# ---- F3 boundary (S3 probe): one all-constant set is excluded with its reason ----
for (f in c("engine_run.R", "fig_all.R")) source(file.path(shared, f))
for (f in c("gsva_score_core.R", "gsva_score_report.R", "gsva_score_qc.R")) source(file.path(module_dir, "scripts", f))
set.seed(1)
pm <- matrix(stats::rnorm(40 * 12), 40, 12, dimnames = list(paste0("g", 1:40), paste0("s", 1:12)))
pm[1:10, ] <- 1
psets <- list(constant = paste0("g", 1:10), variable1 = paste0("g", 11:30), variable2 = paste0("g", 31:40))
pa <- list("min-size" = 5L, "max-size" = 500L, seed = 20260925L, kcdf = "auto", "input-scale" = "normalized_array", journal = "nature")
pr <- gsva_score_compute(pm, list(sets = psets), pa)
pt <- pr$set_table
check(pr$n_retained == 2 && pr$n_excluded == 1 && pr$n_scored == 2 && pr$n_constant_rows == 10 &&
        pt$status[pt$term_id == "constant"] == "excluded" && pt$n_matched_ids[pt$term_id == "constant"] == 10 &&
        pt$n_after_constant_filter[pt$term_id == "constant"] == 0 &&
        grepl("constant-expression rows", pt$reason[pt$term_id == "constant"], fixed = TRUE) &&
        identical(as.integer(pt$n_used_by_gsva[pt$status == "retained"]), c(20L, 10L)),
      "F3 boundary: 3 sets with one all-constant set -> n_retained 2, n_excluded 1 (constant rows), n_scored 2")
pdir <- file.path(tmp, "f3_probe"); dir.create(pdir)
pqc <- gsva_score_qc(pr, pa, FALSE)
gsva_score_report(pr, c(pa, list(collection = "probe")), pqc, list(entry = list(version = "probe", species = "none"), sha256 = "probe"),
                  pdir, file.path(module_dir, "references", "reporting-templates.md"), FALSE,
                  list(sentence = "Expression was an in-session probe matrix.", object = "matrix"), list())
pd <- readLines(file.path(pdir, "draft", "methods_results.md"), warn = FALSE)
pj <- jsonlite::fromJSON(file.path(pdir, "results", "gsva_score_results.json"))
check(any(grepl("2 of 3 sets were scored (1 excluded: 1: fewer than 5 members after GSVA removed constant-expression rows (filterRows))", pd, fixed = TRUE)) &&
        any(grepl("GSVA removed 10 rows with constant expression", pd, fixed = TRUE)) &&
        pj$n_retained == 2 && pj$n_excluded == 1 && pj$n_scored == 2,
      "F3 boundary: Methods and JSON report 2 scored, 1 excluded with the reason")

# ---- contract b: a REAL limma-voom run handed to gsva-score ----
yc <- make_yoruba_counts(file.path(tmp, "yoruba"), suite)
if (is.null(yc)) { check(FALSE, "contract b: Yoruba acceptance counts absent") } else {
  vr <- file.path(tmp, "voom_run")
  ov <- run_entry(file.path(suite, "skills", "limma-voom", "scripts", "run_limma_voom.R"), "--counts", shQuote(yc$counts),
                  "--samples", shQuote(yc$samples), "--condition", "gender", "--reference", "Female", "--target", "Male",
                  "--covariates", "concentration", "--outdir", shQuote(vr))
  check(ov$status == 0, paste("contract b: real limma-voom upstream run", paste(utils::tail(ov$out, 1), collapse = "")))
  gv <- file.path(tmp, "gsva_from_voom")
  og <- run("--from-run", shQuote(vr), "--input-scale", "logcpm", "--collection", "limma_gender_genes", "--outdir", shQuote(gv))
  check(og$status == 0, paste("contract b: gsva-score consumes the limma-voom hand-off", paste(utils::tail(og$out, 2), collapse = " ")))
  if (og$status == 0) {
    el <- readRDS(file.path(vr, "objects", "elist.rds"))
    gs <- os_genesets_read(suite, "limma_gender_genes")$sets
    set.seed(20260925)
    dp <- GSVA::gsvaParam(exprData = el$E, geneSets = gs, minSize = 5, maxSize = 500, kcdf = "auto", kcdfNoneMinSampleSize = 200,
                          tau = 1, maxDiff = TRUE, absRanking = FALSE, sparse = TRUE, checkNA = "auto", use = "everything",
                          filterRows = TRUE, ondisk = "auto", verbose = FALSE)
    de <- GSVA::gsva(param = dp, verbose = FALSE, BPPARAM = BiocParallel::SerialParam(progressbar = FALSE, RNGseed = 20260925))
    ge <- read_scores(gv)
    check(identical(dim(ge), dim(de)) && max(abs(de[rownames(ge), colnames(ge)] - ge)) < 1e-12 && !is.null(el$weights),
          "contract b: scores equal direct GSVA on the voom EList E (the EList carries weights; GSVA does not use them)")
    dv <- readLines(file.path(gv, "draft", "methods_results.md"), warn = FALSE)
    pv <- jsonlite::fromJSON(file.path(gv, "provenance", "provenance.json"))
    hv <- jsonlite::fromJSON(file.path(gv, "objects", "handoff.json"))
    check(any(grepl("EList matrix E (voom log2 counts per million (TMM-normalised library sizes)) of limma-voom", dv, fixed = TRUE)) &&
            any(grepl("does not use the precision weights", dv, fixed = TRUE)) &&
            isFALSE(hv$state$precision_weights_used) && identical(hv$state$input_object, "EList") &&
            isFALSE(pv$precision_weights_used) && identical(pv$input_object, "EList"),
          "contract b: Methods and hand-off state name E, its scale and that GSVA ignores the precision weights")
    check(file.exists(file.path(gv, "figures", "score_by_group.png")) &&
            grepl("GSVA score by gender", jsonlite::fromJSON(file.path(gv, "figures", "score_by_group.figure_spec.json"))$caption, fixed = TRUE),
          "contract b: limma sample table and condition carried into the score-by-group figure")
    cat("INFO: provenance input_source:", pv$input_source %||% "(absent)", "\n")
  }
  ob <- run("--from-run", shQuote(vr), "--input-scale", "normalized_array", "--collection", "limma_gender_genes", "--outdir", shQuote(file.path(tmp, "gsva_bad_scale")))
  check(has_code(ob, "OS_HANDOFF_MISMATCH"), "contract b: a declared scale that disagrees with the limma hand-off is refused")
}

ob <- run("--input", shQuote(fix$expression), "--input-scale", "counts", "--collection", "gsva_brain_txdb_sets", "--outdir", shQuote(file.path(tmp, "bad_counts")))
check(has_code(ob, "OS_INVALID_PARAMETER"), "counts without explicit Poisson refused")
sets_small <- os_genesets_read(suite, "gsva_brain_txdb_sets")$sets
small_ids <- unique(unlist(lapply(sets_small, utils::head, 20), use.names = FALSE))
set.seed(20260925)
small <- matrix(stats::rnorm(length(small_ids) * 200), nrow = length(small_ids),
                dimnames = list(small_ids, sprintf("s%03d", seq_len(200))))
small_path <- file.path(tmp, "synthetic_200.csv")
utils::write.csv(data.frame(feature_id = rownames(small), small, check.names = FALSE), small_path, row.names = FALSE)
on <- run("--input", shQuote(small_path), "--input-scale", "normalized_array", "--collection", "gsva_brain_txdb_sets",
          "--outdir", shQuote(file.path(tmp, "no_kernel")))
jn <- if (on$status == 0) jsonlite::fromJSON(file.path(tmp, "no_kernel", "results", "gsva_score_results.json")) else NULL
check(on$status == 0 && jn$kernel == "none" && jn$n_samples == 200,
      "auto branch selects no-kernel ECDF at 200 continuous samples")
small_counts <- matrix(stats::rpois(length(small_ids) * 20, lambda = 10), nrow = length(small_ids),
                       dimnames = list(small_ids, sprintf("c%02d", seq_len(20))))
count_path <- file.path(tmp, "synthetic_counts.csv")
utils::write.csv(data.frame(feature_id = rownames(small_counts), small_counts, check.names = FALSE), count_path, row.names = FALSE)
op <- run("--input", shQuote(count_path), "--input-scale", "counts", "--kcdf", "Poisson",
          "--collection", "gsva_brain_txdb_sets", "--outdir", shQuote(file.path(tmp, "poisson")))
jp <- if (op$status == 0) jsonlite::fromJSON(file.path(tmp, "poisson", "results", "gsva_score_results.json")) else NULL
check(op$status == 0 && jp$kernel == "Poisson", "explicit Poisson counts path scores successfully")
om <- run("--input", shQuote(fix$expression), "--input-scale", "normalized_array", "--outdir", shQuote(file.path(tmp, "missing_ref")))
check(has_code(om, "OS_REFDATA_MISSING"), "unresolved Hallmark registry preset refused")
check(!file.exists(file.path(tmp, "Rplots.pdf")), "no Rplots.pdf device leak")
if (length(failures)) quit(status = 1) else cat("SMOKE PASSED\n")
