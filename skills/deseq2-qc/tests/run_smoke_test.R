# run_smoke_test.R -- module deseq2-qc. ASCII only on purpose.
# requires: DESeq2 pasilla ggplot2 ggrepel patchwork ragg svglite jsonlite digest
# Checks (ENGINEERING_PLAN 7.2 S2): anchors (PACK C: the vignette printed rows, and replay
# anchors that run the vignette's own code in-session -- S4 F1),
# flag effectiveness, typed errors and blockers, call-registry consistency,
# default drift, default consistency, flag-doc coverage, lint, determinism,
# --spec replay, forward chaining into deseq2-wald, golden baseline, no Rplots.pdf.
# OMICSTAT_WRITE_GOLDEN=1 rewrites tests/golden_manifest.csv from this run.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
shared <- file.path(suite, "skills", "_shared", "scripts")
source(file.path(shared, "calls_check.R"))
source(file.path(shared, "module_kit.R"))
source(file.path(shared, "handoff.R"))
source(file.path(here, "fixtures", "make_pasilla.R"))
failures <- character(0)
check <- function(cond, msg) { if (isTRUE(cond)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
near <- function(a, b, tol = 5e-6) isTRUE(abs(a - b) <= tol * max(1, abs(b)))

tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "deseq2-qc-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
old_wd <- setwd(tmp)   # cwd independence: never run from the module directory
entry <- file.path(module_dir, "scripts", "run_deseq2_qc.R")
wald_entry <- file.path(suite, "skills", "deseq2-wald", "scripts", "run_deseq2_wald.R")
rscript <- file.path(R.home("bin"), "Rscript")
run <- function(entry_path, ...) {
  out <- suppressWarnings(system2(rscript, c(shQuote(entry_path), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(out, "status") %||% 0L, out = out)
}
res_json <- function(d) jsonlite::fromJSON(file.path(d, "results", "deseq2_qc_results.json"))
sha <- function(p) digest::digest(file = p, algo = "sha256")
read_mat <- function(p) { d <- utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE); m <- as.matrix(d[-1]); rownames(m) <- d[[1]]; m }

# ---- static checks ------------------------------------------------------------
scripts <- list.files(file.path(module_dir, "scripts"), pattern = "[.]R$", full.names = TRUE)
reg <- file.path(module_dir, "scripts", "calls_registry.json")
cc <- check_calls(scripts, reg)
check(cc$ok, paste("call registry consistent", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(reg)
check(dd$ok, paste("no default drift", paste(dd$problems, collapse = "; ")))
py <- Sys.which("python3")
tools_dir <- file.path(suite, "tools")
if (nzchar(py)) {
  for (tool in c("check_defaults.py", "check_flag_docs.py")) {
    o <- suppressWarnings(system2(py, c(shQuote(file.path(tools_dir, tool)), shQuote(module_dir)), stdout = TRUE, stderr = TRUE))
    check((attr(o, "status") %||% 0L) == 0L, paste(tool, paste(o, collapse = " | ")))
  }
  o <- suppressWarnings(system2(py, c(shQuote(file.path(tools_dir, "lint_r.py")), shQuote(file.path(module_dir, "scripts"))), stdout = TRUE, stderr = TRUE))
  check((attr(o, "status") %||% 0L) == 0L, paste("engine hygiene lint", paste(o, collapse = " | ")))
} else cat("SKIP: check_defaults.py / check_flag_docs.py / lint_r.py need python3\n")

# ---- A: anchors (DESeq2 vignette, pasilla) -------------------------------------
p <- make_pasilla(file.path(tmp, "pasilla"), suite)
base <- c("--counts", shQuote(p$counts), "--samples", shQuote(p$samples))
a1 <- file.path(tmp, "a1")
r <- run(entry, base, "--shape-col", "type", "--blind-false-supplement", "--outdir", shQuote(a1))
check(r$status == 0, paste("A1 pasilla run (blind-false-supplement) exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  j <- res_json(a1)
  check(j$n_input_features == 14599 && j$n_tested == 8148, sprintf("A1 8,148 of 14,599 features after pre-filtering (vignette 'out of 8148'); got %s of %s", j$n_tested, j$n_input_features))
  check(identical(j$transform, "vst") && isTRUE(j$transform_blind) && isTRUE(j$blind_false_supplement), "A1 primary transform is vst, blind = TRUE, supplement requested")
  # A1 PRINTED anchor: vignette head(assay(vsd), 3) for vsd <- vst(dds, blind=FALSE)
  # on this exact pasilla dds (columns: treated1 treated2 treated3 untreated1 untreated2 untreated3 untreated4).
  supp <- read_mat(file.path(a1, "tables", "vst_matrix_blind_false.csv"))
  cols <- c("treated1", "treated2", "treated3", "untreated1", "untreated2", "untreated3", "untreated4")
  want8 <- c(7.777746, 7.984491, 7.765448, 7.735026, 7.807720, 7.997378, 7.832458)
  want17 <- c(11.954934, 12.035700, 12.028610, 12.049838, 12.295662, 12.471723, 12.089675)
  want18 <- c(9.219162, 9.089390, 9.028791, 9.374577, 9.173538, 9.052143, 9.142848)
  check(all(mapply(near, supp["FBgn0000008", cols], want8, MoreArgs = list(tol = 5e-6))), "A1 PRINTED anchor FBgn0000008 (vst blind=FALSE) matches vignette head(assay(vsd),3)")
  check(all(mapply(near, supp["FBgn0000017", cols], want17, MoreArgs = list(tol = 5e-6))), "A1 PRINTED anchor FBgn0000017 (vst blind=FALSE) matches vignette")
  check(all(mapply(near, supp["FBgn0000018", cols], want18, MoreArgs = list(tol = 5e-6))), "A1 PRINTED anchor FBgn0000018 (vst blind=FALSE) matches vignette")
  last <- utils::tail(r$out, 1)
  check(grepl("^[0-9]+ of 7 rules triggered; read .+ first$", last), paste("A1 closing line format:", last))
  d <- readLines(file.path(a1, "draft", "methods_results.md"))
  check(!any(grepl("\\{[A-Za-z0-9_]+\\}", d)) && any(grepl("blind = TRUE", d, fixed = TRUE)), "A1 draft filled from the reporting template (no open slots; states blind = TRUE)")
  check(any(grepl("nsub = 1000", d, fixed = TRUE)) && any(grepl("fitType = \"parametric\"", d, fixed = TRUE)) &&
          any(grepl("estimateSizeFactors(type = \"ratio\")", d, fixed = TRUE)) &&
          any(grepl("blind = FALSE", d, fixed = TRUE)),
        "A1 Methods states nsub, fitType, size-factor type and requested supplement")
  for (fig in c("pca", "sample_distance", "size_factor", "pca_blind_false")) {
    sp <- jsonlite::fromJSON(file.path(a1, "figures", paste0(fig, ".figure_spec.json")))
    check(file.exists(file.path(a1, "figures", paste0(fig, ".pdf"))) && nzchar(sp$caption) && !grepl(tmp, jsonlite::toJSON(sp), fixed = TRUE),
          sprintf("A1 figure %s: pdf + caption, no absolute path in the spec", fig))
  }
  check(grepl("blind = FALSE", jsonlite::fromJSON(file.path(a1, "figures", "pca_blind_false.figure_spec.json"))$caption, fixed = TRUE),
        "A1 pca_blind_false caption states blind = FALSE (P-1)")
  ew <- utils::read.csv(file.path(a1, "qc", "engine_warnings.csv"))
  check(identical(names(ew), c("stage", "type", "message")), "A1 qc/engine_warnings.csv has columns stage, type, message")
  h <- read_handoff(a1, expect = list(count_matrix = "count_matrix", sample_table = "sample_table", expression_matrix = "expression_matrix", colour_registry = "colour_registry"))
  check(identical(h$module, "deseq2-qc"), "A1 handoff readable with the declared object types")
}

# A2: default run (blind = TRUE only), used later as the golden baseline anchor.
a2 <- file.path(tmp, "a2")
r <- run(entry, base, "--outdir", shQuote(a2))
check(r$status == 0, "A2 pasilla default run (blind=TRUE only) exits 0")
if (r$status == 0) {
  j <- res_json(a2)
  st <- utils::read.csv(file.path(a2, "tables", "sample_qc_descriptive.csv"), stringsAsFactors = FALSE)
  check(setequal(st$sample, c("treated1", "treated2", "treated3", "untreated1", "untreated2", "untreated3", "untreated4")), "A2 descriptive table has all 7 samples")
  check(!"outlier" %in% tolower(names(st)) && !any(grepl("flag", names(st), fixed = TRUE)), "A2 descriptive table has no outlier/flag column (P-2 pending, safe interim)")
  check(!"dist_to_group_centroid" %in% names(st), "A2 pending centroid statistic is absent")
  check(!file.exists(file.path(a2, "tables", "vst_matrix_blind_false.csv")) && !file.exists(file.path(a2, "figures", "pca_blind_false.pdf")),
        "A2 no supplement output without --blind-false-supplement")
  check(file.exists(file.path(a2, "tables", "sample_distances.csv")), "A2 writes tables/sample_distances.csv (the distances behind figures/sample_distance)")
}

# ---- A-oracle: the DESeq2 vignette's OWN code, run in this session -------------
# Source: acceptance/exemplars/deseq2-qc/L1_bioc3.23/DESeq2/vignettes/DESeq2.Rmd
#   loadPasilla :421-433, reorderPasila :455-461 (the cts reorder line), matrixInput :479-484,
#   prefilter :588-592, factorlvl :611-613, deseq :675-679, rlogAndVST :1284-1288,
#   sampleClust :1394-1396, figPCA2 :1431-1434.
# The oracle never sources the engine or a _shared helper. It reads the vignette's
# own input files (DESeq2 extdata; identical content to the acceptance-layer
# pasilla files the engine fixture uses -- probe _s4/probe_env.R). Deviations from
# the vignette text, each named where it occurs: blind = TRUE for the primary QA
# path (vignette "Blind dispersion estimation": TRUE "to perform sample QA"; the
# vignette's code chunk uses FALSE and is replayed as written further below), and
# an explicit whole-column sign alignment of each principal component (the sign
# of a prcomp component is arbitrary). Nothing else is transformed.
# Kind: REPLAY anchor (guide code in-session must equal the engine output).
# Tolerance: relative 1e-8 (floor 1) -- the engine writes CSV/JSON with 10
# significant digits; no other difference is allowed.
near_all <- function(a, b, tol = 1e-8) length(a) == length(b) && !anyNA(a) && !anyNA(b) && all(abs(a - b) <= tol * pmax(1, abs(b)))
maxdiff <- function(a, b) format(max(abs(a - b)), digits = 3)
suppressPackageStartupMessages(library("DESeq2"))
pasCts <- system.file("extdata",
                      "pasilla_gene_counts.tsv.gz",
                      package="DESeq2", mustWork=TRUE)
pasAnno <- system.file("extdata",
                       "pasilla_sample_annotation.csv",
                       package="DESeq2", mustWork=TRUE)
cts <- as.matrix(read.csv(pasCts,sep="\t",row.names="gene_id"))
coldata <- read.csv(pasAnno, row.names=1)
coldata <- coldata[,c("condition","type")]
coldata$condition <- factor(coldata$condition)
coldata$type <- factor(coldata$type)
rownames(coldata) <- sub("fb", "", rownames(coldata))
cts <- cts[, rownames(coldata)]
dds <- DESeqDataSetFromMatrix(countData = cts,
                              colData = coldata,
                              design = ~ condition)
smallestGroupSize <- 3
keep <- rowSums(counts(dds) >= 10) >= smallestGroupSize
dds <- dds[keep,]
dds$condition <- factor(dds$condition, levels = c("untreated","treated"))

# A2 REPLAY (primary path, blind = TRUE; engine default run a2): the full
# transformed matrix, PC1/PC2 of every sample, percentVar, full distance matrix.
if (file.exists(file.path(a2, "tables", "vst_matrix.csv"))) {
  vsd <- vst(dds, blind=TRUE)
  sampleDists <- dist(t(assay(vsd)))
  pcaData <- suppressMessages(plotPCA(vsd, intgroup=c("condition", "type"), returnData=TRUE))
  percentVar <- attr(pcaData, "percentVar")
  em <- read_mat(file.path(a2, "tables", "vst_matrix.csv"))
  om <- assay(vsd)
  same_shape <- identical(rownames(em), rownames(om)) && identical(colnames(em), colnames(om))
  check(same_shape, sprintf("A2 REPLAY: engine vst matrix has the vignette's %d x %d rows/columns in the same order", nrow(om), ncol(om)))
  if (same_shape) check(near_all(as.vector(em), as.vector(om)),
        sprintf("A2 REPLAY: full blind=TRUE vst matrix (%d values) equals vignette vst(dds, blind=TRUE); max |diff| %s",
                length(om), maxdiff(as.vector(em), as.vector(om))))
  st2 <- utils::read.csv(file.path(a2, "tables", "sample_qc_descriptive.csv"), stringsAsFactors = FALSE)
  rownames(st2) <- st2$sample
  ss <- rownames(pcaData)
  check(setequal(ss, st2$sample) && length(ss) == 7, "A2 REPLAY: plotPCA returnData and the engine table cover the same 7 samples")
  for (pc in c("PC1", "PC2")) {
    e <- st2[ss, pc]; o <- pcaData[ss, pc]
    sgn <- if (sum(e * o) < 0) -1 else 1   # explicit whole-column sign alignment, nothing else
    cat(sprintf("INFO: %s whole-column sign alignment applied to the vignette plotPCA column: %+d\n", pc, sgn))
    check(near_all(e, sgn * o), sprintf("A2 REPLAY: %s of all 7 samples equals vignette plotPCA(returnData=TRUE) after whole-column sign %+d; max |diff| %s",
                                         pc, sgn, maxdiff(e, sgn * o)))
  }
  j2 <- res_json(a2)
  check(near_all(c(j2$pc1_percent_var, j2$pc2_percent_var), 100 * percentVar),
        sprintf("A2 REPLAY: percent variance %.6f / %.6f equals 100 * attr(pcaData, 'percentVar') = %.6f / %.6f",
                j2$pc1_percent_var, j2$pc2_percent_var, 100 * percentVar[1], 100 * percentVar[2]))
  ed <- read_mat(file.path(a2, "tables", "sample_distances.csv"))
  od <- as.matrix(sampleDists)
  dshape <- identical(dim(ed), dim(od)) && setequal(rownames(ed), rownames(od)) && setequal(colnames(ed), colnames(od))
  check(dshape && near_all(as.vector(ed[rownames(od), colnames(od)]), as.vector(od)),
        sprintf("A2 REPLAY: full 7 x 7 sample distance matrix equals vignette as.matrix(dist(t(assay(vsd)))); max |diff| %s",
                if (dshape) maxdiff(as.vector(ed[rownames(od), colnames(od)]), as.vector(od)) else "NA"))
} else check(FALSE, "A2 REPLAY: engine a2 vst_matrix.csv missing")

# A1 REPLAY of the vignette chunk exactly as written (dds <- DESeq(dds);
# vsd <- vst(dds, blind=FALSE)) against the engine's --blind-false-supplement
# run a1. The printed rows first validate the oracle itself; the full matrix and
# the supplement's percent variance are then asserted against the engine.
if (file.exists(file.path(a1, "tables", "vst_matrix_blind_false.csv"))) {
  dds <- suppressMessages(DESeq(dds))
  vsd <- vst(dds, blind=FALSE)
  om <- assay(vsd)
  cols <- c("treated1", "treated2", "treated3", "untreated1", "untreated2", "untreated3", "untreated4")
  pr <- rbind(FBgn0000008 = c(7.777746, 7.984491, 7.765448, 7.735026, 7.807720, 7.997378, 7.832458),
              FBgn0000017 = c(11.954934, 12.035700, 12.028610, 12.049838, 12.295662, 12.471723, 12.089675),
              FBgn0000018 = c(9.219162, 9.089390, 9.028791, 9.374577, 9.173538, 9.052143, 9.142848))
  check(identical(rownames(om)[1:3], rownames(pr)) && all(abs(om[1:3, cols] - pr) <= 5e-7 + 1e-12),
        "A1 oracle self-check: the vignette code reproduces its own printed head(assay(vsd), 3) to the printed 6 decimals")
  em <- read_mat(file.path(a1, "tables", "vst_matrix_blind_false.csv"))
  same_shape <- identical(rownames(em), rownames(om)) && identical(colnames(em), colnames(om))
  check(same_shape && near_all(as.vector(em), as.vector(om)),
        sprintf("A1 REPLAY: full blind=FALSE supplement matrix (%d values) equals the vignette chunk's vst(dds, blind=FALSE); max |diff| %s",
                length(om), if (same_shape) maxdiff(as.vector(em), as.vector(om)) else "NA"))
  pcaData <- suppressMessages(plotPCA(vsd, intgroup=c("condition", "type"), returnData=TRUE))
  sp <- jsonlite::fromJSON(file.path(a1, "figures", "pca_blind_false.figure_spec.json"))
  pvs <- unlist(sp$data$percent_var)
  check(length(pvs) == 2 && all(abs(pvs - round(100 * attr(pcaData, "percentVar"), 4)) <= 1e-9),
        sprintf("A1 REPLAY: supplement percent variance in pca_blind_false.figure_spec.json (%s; stored at 4 decimals) equals round(100 * percentVar, 4) of the vignette plotPCA",
                paste(pvs, collapse = " / ")))
} else check(FALSE, "A1 REPLAY: engine a1 vst_matrix_blind_false.csv missing")

# A3: --transform rlog exits 0 and produces a different (non vst) matrix.
a3 <- file.path(tmp, "a3")
r <- run(entry, base, "--transform", "rlog", "--outdir", shQuote(a3))
check(r$status == 0 && file.exists(file.path(a3, "tables", "rlog_matrix.csv")), "A3 --transform rlog exits 0 and writes rlog_matrix.csv")
r2ok <- file.exists(file.path(a2, "tables", "vst_matrix.csv"))
if (r$status == 0 && r2ok) {
  v <- read_mat(file.path(a2, "tables", "vst_matrix.csv")); g <- read_mat(file.path(a3, "tables", "rlog_matrix.csv"))
  check(!isTRUE(all.equal(unname(v["FBgn0000017", ]), unname(g["FBgn0000017", ]))), "A3 rlog matrix numerically differs from vst matrix")
}

# ---- D: determinism, --spec replay, forward chaining into deseq2-wald --------
d1 <- file.path(tmp, "d1")
r <- run(entry, "--spec", shQuote(file.path(a2, "provenance", "resolved_spec.json")), "--outdir", shQuote(d1))
check(r$status == 0, "D1 --spec replay exits 0")
if (r$status == 0) {
  for (f in c("tables/sample_qc_descriptive.csv", "tables/vst_matrix.csv", "tables/sample_distances.csv", "results/deseq2_qc_results.json",
              "figures/pca.figure_spec.json", "figures/pca.png", "figures/sample_distance.png", "draft/methods_results.md")) {
    check(identical(sha(file.path(a2, f)), sha(file.path(d1, f))), paste("D1 byte-identical on replay:", f))
  }
}
if (file.exists(wald_entry)) {
  w1 <- file.path(tmp, "w1")
  r <- run(wald_entry, "--from-run", shQuote(a2), "--reference", "untreated", "--target", "treated", "--outdir", shQuote(w1))
  check(r$status == 0, paste("D2 forward chain: deseq2-wald --from-run <deseq2-qc run> exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
  if (r$status == 0) {
    ft <- utils::read.csv(file.path(w1, "tables", "feature_table.csv"))
    check(nrow(ft) > 0, "D2 deseq2-wald produced a non-empty feature table from the deseq2-qc handoff")
  }
  # D3: tamper the handed-off sample table after the deseq2-qc run; deseq2-wald must refuse it.
  tamp_parent <- file.path(tmp, "tamper_parent"); dir.create(tamp_parent)
  file.copy(a2, tamp_parent, recursive = TRUE)
  tamp <- file.path(tamp_parent, basename(a2))
  cat("col1,x\n", file = file.path(tamp, "objects", "sample_table.csv"), append = TRUE)
  r <- run(wald_entry, "--from-run", shQuote(tamp), "--reference", "untreated", "--target", "treated", "--outdir", shQuote(file.path(tmp, "w2")))
  check(r$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", r$out)), "D3 a changed deseq2-qc handoff is refused by deseq2-wald (OS_HANDOFF_MISMATCH)")
} else cat("SKIP: skills/deseq2-wald not found; forward-chain checks skipped\n")

# ---- E: typed errors and blockers (small synthetic fixture) ----------------------
set.seed(1)
syn <- matrix(stats::rnbinom(600 * 6, mu = 200, size = 5), 600, 6, dimnames = list(sprintf("ENSG%011d", 1:600), sprintf("S%d", 1:6)))
write_mat <- function(m, path) utils::write.csv(data.frame(feature_id = rownames(m), m, check.names = FALSE), path, row.names = FALSE)
write_mat(syn, file.path(tmp, "syn_counts.csv"))
st6 <- data.frame(sample = colnames(syn), condition = rep(c("ctrl", "trt"), each = 3), batch = rep(c("b1", "b2"), 3),
                  conf = rep(c("x", "y"), each = 3))
utils::write.csv(st6, file.path(tmp, "syn_samples.csv"), row.names = FALSE)
sbase <- c("--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")))
r <- run(entry, sbase, "--outdir", shQuote(file.path(tmp, "e1")))
check(r$status == 0, "E1 simple two-level design (no covariates) auto-resolves --min-samples")
r <- run(entry, sbase, "--covariates", "batch", "--outdir", shQuote(file.path(tmp, "e2")))
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER: --min-samples must be given explicitly", r$out)), "E2 complex design (covariates given) without --min-samples -> OS_MISSING_PARAMETER")
r <- run(entry, sbase, "--covariates", "conf", "--min-samples", "3", "--outdir", shQuote(file.path(tmp, "e2b")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN", r$out)), "E2b condition fully confounded with covariate 'conf' -> OS_INVALID_DESIGN")
r <- run(entry, sbase, "--min-cont", "5", "--outdir", shQuote(file.path(tmp, "e3")))
check(r$status != 0 && any(grepl("OS_UNKNOWN_FLAG", r$out)), "E3 misspelled flag -> OS_UNKNOWN_FLAG")
nonint <- syn; storage.mode(nonint) <- "double"; nonint[1, 1] <- 10.5
write_mat(nonint, file.path(tmp, "nonint.csv"))
e4 <- file.path(tmp, "e4")
r <- run(entry, "--counts", shQuote(file.path(tmp, "nonint.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")), "--outdir", shQuote(e4))
q <- if (file.exists(file.path(e4, "qc", "qc_results.csv"))) utils::read.csv(file.path(e4, "qc", "qc_results.csv")) else NULL
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: DQ-01", r$out)) && isTRUE(q$triggered[q$id == "DQ-01"]) &&
        any(grepl("draft withheld", readLines(file.path(e4, "draft", "methods_results.md")))),
      "E4 non-integer counts -> DQ-01 blocker, qc table written, draft withheld")
neg <- syn; neg[1, 1] <- -5L
write_mat(neg, file.path(tmp, "neg.csv"))
r <- run(entry, "--counts", shQuote(file.path(tmp, "neg.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")), "--outdir", shQuote(file.path(tmp, "e5")))
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: DQ-02", r$out)), "E5 negative counts -> DQ-02 blocker")
two <- syn[, 1:2]
write_mat(two, file.path(tmp, "two.csv"))
utils::write.csv(st6[1:2, ], file.path(tmp, "two_samples.csv"), row.names = FALSE)
r <- run(entry, "--counts", shQuote(file.path(tmp, "two.csv")), "--samples", shQuote(file.path(tmp, "two_samples.csv")), "--outdir", shQuote(file.path(tmp, "e6")))
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: DQ-03", r$out)), "E6 fewer than 3 samples -> DQ-03 blocker")

# ---- F: flag effectiveness (synthetic) ------------------------------------------
f0 <- file.path(tmp, "f0"); f1 <- file.path(tmp, "f1"); f2 <- file.path(tmp, "f2")
r0 <- run(entry, sbase, "--outdir", shQuote(f0))
r1 <- run(entry, sbase, "--ntop", "50", "--outdir", shQuote(f1))
r2 <- run(entry, sbase, "--min-count", "250", "--outdir", shQuote(f2))
check(r0$status == 0, paste("F0 base run exits 0", paste(utils::tail(r0$out, 5), collapse = " | ")))
check(r1$status == 0, paste("F1 --ntop 50 run exits 0", paste(utils::tail(r1$out, 5), collapse = " | ")))
check(r2$status == 0, paste("F2 --min-count 250 run exits 0", paste(utils::tail(r2$out, 5), collapse = " | ")))
if (r0$status == 0 && r1$status == 0 && r2$status == 0) {
  j0 <- res_json(f0); j1 <- res_json(f1); j2 <- res_json(f2)
  check(j0$ntop == 500 && j1$ntop == 50 && !isTRUE(all.equal(j0$pc1_percent_var, j1$pc1_percent_var)), "F1 --ntop 50 changes the PCA (different percent variance) from the default 500")
  check(j2$n_tested < j0$n_tested, "F2 --min-count 250 reduces the tested feature count")
  singleton <- st6; singleton$condition[1] <- "solo"
  utils::write.csv(singleton, file.path(tmp, "singleton_samples.csv"), row.names = FALSE)
  r <- run(entry, "--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "singleton_samples.csv")),
           "--min-samples", "1", "--outdir", shQuote(file.path(tmp, "f3")))
  check(r$status == 0, "F3 singleton condition level run exits 0")
  if (r$status == 0) {
    q3 <- utils::read.csv(file.path(tmp, "f3", "qc", "qc_results.csv"))
    check(isTRUE(q3$triggered[q3$id == "DQ-04"]), "F3 DQ-04 (singleton condition level) fires as a non-blocking warning")
  }
} else check(FALSE, "F synthetic runs exit 0")
# DQ-05 (vst nsub fallback): fewer than 1000 features pass the pre-filter.
f4 <- file.path(tmp, "f4")
r <- run(entry, "--counts", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")),
        "--min-count", "0", "--outdir", shQuote(f4))
if (r$status == 0) {
  q4 <- utils::read.csv(file.path(f4, "qc", "qc_results.csv"))
  j4 <- res_json(f4)
  check(j4$n_tested < 1000 && isTRUE(q4$triggered[q4$id == "DQ-05"]) && isTRUE(j4$transform_fallback),
        "F4 DQ-05 fires and transform_fallback is TRUE when fewer than 1,000 features pass the pre-filter")
} else check(FALSE, "F4 small-panel run exits 0")

# vst needs 1,000 rows with mean normalized count > 5, not just 1,000 rows.
low <- rbind(syn[1:200, , drop = FALSE], matrix(0L, 1000, ncol(syn),
             dimnames = list(sprintf("LOW%011d", 1:1000), colnames(syn))))
write_mat(low, file.path(tmp, "low_mean_counts.csv"))
f5 <- file.path(tmp, "f5")
r <- run(entry, "--counts", shQuote(file.path(tmp, "low_mean_counts.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")),
         "--min-count", "0", "--outdir", shQuote(f5))
if (r$status == 0) {
  j5 <- res_json(f5)
  q5 <- utils::read.csv(file.path(f5, "qc", "qc_results.csv"))
  d5 <- readLines(file.path(f5, "draft", "methods_results.md"))
  check(j5$n_tested >= 1000 && isTRUE(j5$transform_fallback) && isTRUE(q5$triggered[q5$id == "DQ-05"]),
        "F5 >=1,000 rows with <1,000 eligible means use the typed vst fallback")
  check(any(grepl("varianceStabilizingTransformation", d5, fixed = TRUE)), "F5 Methods names the fallback")
} else check(FALSE, paste("F5 low-mean run exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))

# ---- G: golden baseline (lock 5) --------------------------------------------------
golden <- c("tables/sample_qc_descriptive.csv", "tables/vst_matrix.csv", "tables/size_factors.csv", "tables/sample_distances.csv",
            "results/deseq2_qc_results.json", "figures/pca.figure_spec.json",
            "figures/sample_distance.figure_spec.json", "figures/size_factor.figure_spec.json")
if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) { os_golden_write(module_dir, a2, golden); cat("golden manifest written\n") }
gc <- os_golden_check(module_dir, a2)
if (gc$status == "SKIP") cat("SKIP: golden baseline --", gc$reason, "\n") else check(gc$status == "PASS", paste("G golden baseline", paste(gc$problems, collapse = ", ")))

setwd(old_wd)
check(!file.exists(file.path(tmp, "Rplots.pdf")) && !file.exists(file.path(module_dir, "Rplots.pdf")), "no Rplots.pdf device leak")
if (length(failures)) { cat(length(failures), "check(s) FAILED\n"); quit(status = 1) } else cat("SMOKE PASSED\n")
