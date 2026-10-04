# requires: SingleR SingleCellExperiment SummarizedExperiment BiocParallel jsonlite digest
# Partial S2 smoke. Mandatory PACK C recipe deliberately fails when locked
# image lacks scrapper; synthetic checks do NOT replace that anchor.
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
mdir <- dirname(dirname(.this)); suite <- dirname(dirname(mdir))
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
source(file.path(suite, "skills", "_shared", "scripts", "handoff.R"))
source(file.path(suite, "skills", "_shared", "scripts", "convert.R"))
source(file.path(suite, "skills", "_shared", "scripts", "sc_backend_io.R"))
source(file.path(mdir, "scripts", "singler_annotate_core.R"))
root <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "singler-smoke")
dir.create(root, recursive = TRUE, showWarnings = FALSE)
entry <- file.path(mdir, "scripts", "run_singler_annotate.R")
run <- function(args, code = 0L, match_error = NULL) {
  log <- tempfile(tmpdir = root, fileext = ".log")
  rc <- system2("Rscript", c(shQuote(entry), vapply(args, shQuote, "")), stdout = log, stderr = log)
  if (rc != code) stop(paste(readLines(log), collapse = "\n"))
  if (!is.null(match_error)) stopifnot(any(grepl(match_error, readLines(log), fixed = TRUE)))
}
for (tool in c("check_calls.R")) stopifnot(system2("Rscript", c(shQuote(file.path(suite, "tools", tool)), shQuote(mdir))) == 0)
for (tool in c("lint_r.py")) stopifnot(system2("python3", c(shQuote(file.path(suite, "tools", tool)), shQuote(mdir))) == 0)
cat("PASS: static calls, locked default drift and R lint (dynamic JSON flags documented in options.md)\n")
seed <- 20260925L; set.seed(seed)
x <- matrix(rpois(60*40, 2), 60, 40)
x[1:15,1:20] <- x[1:15,1:20] + 30
x[16:30,21:40] <- x[16:30,21:40] + 30
dimnames(x) <- list(paste0("g", seq_len(60)), paste0("c", seq_len(40)))
sce <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = x, logcounts = log1p(x)))
sce$cluster <- rep(c("a", "b"), each = 20); sce$label <- sce$cluster
infile <- file.path(root, "sce.rds"); saveRDS(sce, infile)
common <- c("--input", infile, "--ecosystem", "bioconductor", "--cluster-col", "cluster", "--logcounts-layer", "logcounts", "--reference", infile,
            "--reference-name", "synthetic-smoke", "--reference-version", "v1", "--species", "synthetic", "--reference-label-col", "label")
out <- file.path(root, "run"); replay <- file.path(root, "replay")
run(c(common, "--outdir", out))
tab <- read.csv(file.path(out,"tables","annotations.csv"))
stopifnot(nrow(tab)==40L, identical(tab$label, sce$label))
run(c("--spec", file.path(out,"provenance","resolved_spec.json"),"--outdir",replay))
for (f in c("tables/annotations.csv", "tables/scores.csv", "tables/cluster_labels.csv", "figures/scores.png", "figures/scores.figure_spec.json", "figures/cluster_labels.png", "figures/cluster_labels.figure_spec.json")) {
 stopifnot(identical(digest::digest(file=file.path(out,f),algo="sha256"),digest::digest(file=file.path(replay,f),algo="sha256")))
}
cat("PASS: synthetic classic labels and deterministic --spec tables/figures\n")
changed <- file.path(root,"nmads0")
run(c(common,"--nmads","0","--outdir",changed))
stopifnot(sum(is.na(read.csv(file.path(changed,"tables/annotations.csv"))$pruned_label)) > sum(is.na(tab$pruned_label)))
cat("PASS: nmads flag changes pruned labels\n")
run(c("--unknown","x"),1L,"OS_UNKNOWN_FLAG")
run(c("--outdir",file.path(root,"missing")),1L,"OS_MISSING_PARAMETER")
chain <- c("--from-run",out,"--cluster-col","cluster","--logcounts-layer","logcounts","--reference",infile,
 "--reference-name","synthetic-smoke","--reference-version","v1","--species","synthetic","--reference-label-col","label")
run(c(chain,"--outdir",file.path(root,"chain")))
run(c(chain,"--ecosystem","seurat","--outdir",file.path(root,"mixed")),1L,"OS_ECOSYSTEM_MIXED")
h<-read_handoff(out); stopifnot(identical(os_sc_chain_state(h)$front_end_ecosystem,"bioconductor"))
sce$cluster[1]<-"changed"; saveRDS(sce,file.path(out,"objects","sce.rds"))
run(c(chain,"--outdir",file.path(root,"tamper")),1L,"OS_HANDOFF_MISMATCH")
corrected <- file.path(root, "corrected")
dir.create(file.path(corrected, "objects"), recursive = TRUE, showWarnings = FALSE)
cp <- file.path(corrected, "objects", "sce.rds"); saveRDS(sce, cp)
write_handoff(corrected, basename(corrected), "fixture", "1.0.0", list(sce = list(path = cp, type = "SingleCellExperiment")), ecosystem = "neutral", state = list(front_end_ecosystem = "bioconductor", batch_corrected_lineage = TRUE))
cc <- chain; cc[2] <- corrected
run(c(cc,"--outdir",file.path(root,"refuse-corrected")),1L,"OS_BATCH_CORRECTED_INPUT")
cat("PASS: typed errors, --from-run and ecosystem/tamper/corrected-lineage rejection\n")
stopifnot(!file.exists(file.path(getwd(),"Rplots.pdf")))
if (!requireNamespace("scrapper", quietly = TRUE)) {
 run(c(common,"--de-method","wilcox","--outdir",file.path(root,"wilcox")),1L,"OS_MISSING_DEPENDENCY")
 cat("FAIL: PACK C pancreas printed anchor: scrapper absent from locked image; no normalization or wilcox anchor execution possible. Goldens and module lock withheld.\n")
 quit(status=1)
}
source(file.path(mdir, "tests", "fixtures", "make_pancreas.R"))
fixture <- make_pancreas(suite)
if (is.null(fixture)) {
 cat("SKIP: pancreas anchor files absent; no golden or lock generation.\n")
 quit(status = 1)
}
vignette_prediction <- SingleR::SingleR(test = fixture$test, ref = fixture$reference, labels = fixture$reference$label, de.method = "wilcox")
expected <- c(acinar = 723L, alpha = 228L, beta = 232L, delta = 65L, duct = 344L, endothelial = 15L, epsilon = 2L, mesenchymal = 69L, pp = 36L, unclear = 4L)
cat("Observed official pancreas label counts:\n"); print(table(vignette_prediction$labels)); cat("Observed pruned:",sum(is.na(vignette_prediction$pruned.labels)),"\n")
stopifnot(identical(as.integer(table(vignette_prediction$labels)[names(expected)]), unname(expected)))
stopifnot(sum(is.na(vignette_prediction$pruned.labels)) == 59L, sum(!is.na(vignette_prediction$pruned.labels)) == 1659L)
fp <- file.path(root, "pancreas.rds"); rp <- file.path(root, "muraro.rds")
saveRDS(fixture$test, fp); saveRDS(fixture$reference, rp)
anchor <- file.path(root, "pancreas-anchor")
run(c("--input", fp, "--ecosystem", "bioconductor", "--cluster-col", "cluster", "--logcounts-layer", "logcounts",
      "--reference", rp, "--reference-name", "Muraro", "--reference-version", "EH2692-EH2693", "--species", "human",
      "--reference-label-col", "label", "--de-method", "wilcox", "--outdir", anchor))
engine <- read.csv(file.path(anchor, "tables", "annotations.csv"))
stopifnot(identical(engine$label, as.character(vignette_prediction$labels)), identical(engine$pruned_label, as.character(vignette_prediction$pruned.labels)))
cat("PASS: PACK C exact vignette printed labels and pruning, engine replay\n")
stopifnot(nrow(engine) == 1718L)
if (identical(Sys.getenv("OMICSTAT_WRITE_GOLDEN"), "1")) os_golden_write(mdir, anchor, c("tables/annotations.csv", "tables/scores.csv", "tables/cluster_labels.csv"))
golden <- os_golden_check(mdir, anchor)
stopifnot(identical(golden$status, "PASS"))
cat("PASS: pancreas golden; 1718 cells, 59 pruned, exact printed label counts\n")

if(identical(Sys.getenv("OMICSTAT_TEST_H5AD"),"1")) {
 hp<-file.path(root,"pancreas.h5ad")
 os_sc_convert(fixture$test,to="AnnData",consumer="back_end",layers=c(logcounts="logcounts"),cluster_col="cluster",x_role="logcounts",file=hp)
 ann<-file.path(root,"pancreas-anndata")
 run(c("--input",hp,"--ecosystem","bioconductor","--cluster-col","cluster","--logcounts-layer","X","--reference",rp,"--reference-name","Muraro","--reference-version","EH2692-EH2693","--species","human","--reference-label-col","label","--de-method","wilcox","--outdir",ann))
 for(rel in c("tables/annotations.csv","tables/scores.csv")) stopifnot(identical(digest::digest(file=file.path(anchor,rel),algo="sha256"),digest::digest(file=file.path(ann,rel),algo="sha256")))
 cat("PASS: non-root offline pancreas h5ad input gives identical annotations and scores\n")
}

# Repaired reporting: native JSON overrides supersede convenience flags.
override <- file.path(root,"pancreas-override")
run(c("--input",fp,"--ecosystem","bioconductor","--cluster-col","cluster","--logcounts-layer","logcounts","--reference",rp,"--reference-name","Muraro","--reference-version","EH2692-EH2693","--species","human","--reference-label-col","label","--de-method","classic","--singler-de-method",'"wilcox"',"--singler-quantile","0.5","--prune-nmads","2","--prune-min-diff-med","0.01","--prune-min-diff-next","0.05","--outdir",override))
set.seed(seed)
np <- SingleR::SingleR(test=fixture$test,ref=fixture$reference,labels=fixture$reference$label,de.method="wilcox",quantile=.5)
pr <- SingleR::pruneScores(np,nmads=2,min.diff.med=.01,min.diff.next=.05)
nt <- as.character(np$labels);nt[pr] <- NA_character_
ot <- read.csv(file.path(override,"tables/annotations.csv"))
stopifnot(identical(ot$label,as.character(np$labels)),identical(ot$pruned_label,nt))
md <- paste(readLines(file.path(override,"draft/methods_results.md")),collapse="\n")
stopifnot(all(vapply(c("de.method=wilcox","quantile=0.5","nmads=2","min.diff.med=0.01","min.diff.next=0.05"),grepl,logical(1),x=md,fixed=TRUE)))
for(f in c("scores","cluster_labels")) {
 fs <- jsonlite::read_json(file.path(override,"figures",paste0(f,".figure_spec.json")))
 stopifnot(grepl("min.diff.med = 0.01, min.diff.next = 0.05",fs$caption,fixed=TRUE))
}
pv <- jsonlite::read_json(file.path(override,"provenance/provenance.json"))
stopifnot(pv$resolved_native$SingleR$quantile==.5,pv$resolved_native$pruneScores$min.diff.next==.05)
cat("PASS: pancreas overrides native labels/pruning, actual Methods/results/captions/provenance\n")
