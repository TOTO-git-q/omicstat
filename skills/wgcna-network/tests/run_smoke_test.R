# requires: WGCNA, jsonlite, digest, ggplot2
.this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
mod <- dirname(dirname(.this)); suite <- dirname(dirname(mod)); shared <- file.path(suite, "skills", "_shared", "scripts")
for (f in c("module_kit.R", "handoff.R")) source(file.path(shared, f))
source(file.path(mod, "tests", "fixtures", "make_female_liver.R"))
tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "wgcna-smoke"); dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
old <- setwd(tmp)
suppressPackageStartupMessages(library(WGCNA))
n <- 0L
check <- function(ok, label) { n <<- n + 1L; cat(if (isTRUE(ok)) "PASS:" else "FAIL:", label, "\n"); if (!isTRUE(ok)) stop(label) }
entry <- file.path(mod, "scripts", "run_wgcna_network.R")
run <- function(...) { out <- system2("Rscript", c(shQuote(entry), unlist(list(...))), stdout = TRUE, stderr = TRUE); list(status = attr(out, "status") %||% 0, out = out) }
sha <- function(p) digest::digest(file = p, algo = "sha256")
for (tool in c("check_calls.R", "check_defaults.py", "check_flag_docs.py", "lint_r.py")) {
 cmd <- if (endsWith(tool, ".R")) "Rscript" else "python3"
 check(system2(cmd, c(shQuote(file.path(suite, "tools", tool)), shQuote(mod))) == 0, tool)
}
f <- make_female_liver(suite, file.path(tmp, "input")); check(!is.null(f), "FemaleLiver hash, 3600x143/361x38 structures and tutorial 134 retained samples")
base <- c("--input", shQuote(f$input), "--samples", shQuote(f$samples), "--traits", "other_fat", "--input-scale", "normalized_array", "--preprocessing", "tutorial-selected-3600-probes", "--outlier-rule", "tutorial-height15-minSize10-retain-cluster1", "--power", "6", "--power-reason", "tutorial-example-replay", "--tom-type", "unsigned", "--min-module-size", "30", "--merge-height", "0.25", "--reassign-threshold", "0", "--pam-respects-dendro", "false")
a0 <- file.path(tmp, "anchor"); z <- run(base, "--outdir", shQuote(a0)); check(z$status == 0, paste("full tutorial engine", paste(tail(z$out, 2), collapse = " | ")))
net <- WGCNA::blockwiseModules(f$x, power = 6, TOMType = "unsigned", minModuleSize = 30, reassignThreshold = 0,
 mergeCutHeight = 0.25, numericLabels = TRUE, pamRespectsDendro = FALSE, saveTOMs = FALSE, verbose = 0, nThreads = 1)
ref <- WGCNA::labels2colors(net$colors)
gene <- utils::read.csv(file.path(a0, "tables", "gene_modules.csv"))
check(identical(gene$module, ref), "REPLAY all 3600 gene module assignments equal tutorial part 2 code")
sizes <- table(ref); cat("LOCKED tutorial module sizes:", paste(names(sizes), sizes, collapse = "; "), "\n")
printed <- c(99,609,460,409,316,312,221,211,157,123,106,100,94,91,77,76,58,47,34)
check(identical(as.integer(table(net$colors)), as.integer(printed)), "PRINTED tutorial part 2 PDF lines 149-153: all 19 label counts; 18 assigned modules, grey99, assigned range34-609")
M <- WGCNA::moduleEigengenes(f$x, colors = ref, softPower = 6)$eigengenes
r <- WGCNA::cor(M, f$traits$other_fat, use = "p")
p <- WGCNA::corPvalueStudent(r, nrow(f$x))
a <- utils::read.csv(file.path(a0, "tables", "module_traits.csv"))
check(max(abs(a$estimate - as.vector(r[match(a$module, rownames(r)), , drop = FALSE]))) < 1e-12, "REPLAY trait correlations equal tutorial part 3")
check(max(abs(a$p_value - as.vector(p))) < 1e-12, "REPLAY Pearson Student-t P values equal tutorial part 3")
trait_cols <- c("module", "trait", "estimate", "p_value", "p_adjusted", "n_unweighted")
check(identical(names(a), trait_cols) && all(a$n_unweighted == nrow(f$x)), "module_traits.csv keeps its sealed schema with complete sample counts")
ai <- utils::read.csv(file.path(a0, "tables", "module_traits_inference.csv"))
check(identical(ai$module, a$module) && identical(ai$trait, a$trait) && all(ai$inference == "pearson_student_t") && all(ai$n_pairwise_complete == nrow(f$x)) && all(ai$n_samples == nrow(f$x)), "Pearson inference sidecar: mode and complete pairwise counts")
# Small real-data subset for flags/determinism/handoff.
small <- file.path(tmp, "small.csv"); mat <- t(as.matrix(f$x[, 1:200])); utils::write.csv(data.frame(feature_id = rownames(mat), mat, check.names = FALSE), small, row.names = FALSE)
b <- base; b[match("--input", b)+1] <- shQuote(small)
s0 <- file.path(tmp, "small"); check(run(b, "--outdir", shQuote(s0))$status == 0, "small run")
s1 <- file.path(tmp, "replay"); check(run("--spec", shQuote(file.path(s0, "provenance", "resolved_spec.json")), "--outdir", shQuote(s1))$status == 0, "spec replay")
for (rel in c("tables/gene_modules.csv", "tables/module_traits.csv", "tables/soft_threshold.csv", "figures/soft_threshold.png", "figures/module_traits.png", "figures/samples.png", "figures/genes_block1.png")) check(sha(file.path(s0, rel)) == sha(file.path(s1, rel)), paste("determinism", rel))
b8 <- base; b8[match("--power", b8)+1] <- "8"
s2 <- file.path(tmp, "power8"); check(run(b8, "--outdir", shQuote(s2))$status == 0, "power flag")
check(sha(file.path(a0, "tables", "gene_modules.csv")) != sha(file.path(s2, "tables", "gene_modules.csv")), "power changes full-anchor module assignments/membership")
err <- run(b, "--wrong-flag", "1", "--outdir", shQuote(file.path(tmp, "error"))); check(err$status != 0 && any(grepl("OS_UNKNOWN_FLAG", err$out)), "typed unknown flag")
u <- file.path(tmp, "upstream"); dir.create(file.path(u, "objects"), recursive = TRUE, showWarnings = FALSE); file.copy(small, file.path(u, "objects", "expression.csv"), overwrite = TRUE)
write_handoff(u, "fixture", "fixture", "1.0.0", list(expression_matrix = list(path = file.path(u, "objects", "expression.csv"), type = "expression_matrix")), state = list(input_scale = "normalized_array"))
bc <- b[-c(match("--input", b), match("--input", b)+1)]
uo <- file.path(tmp, "chained"); check(run(bc, "--from-run", shQuote(u), "--outdir", shQuote(uo))$status == 0 && sha(file.path(uo, "tables", "gene_modules.csv")) == sha(file.path(s0, "tables", "gene_modules.csv")), "from-run equal")
cat("tamper\n", file = file.path(u, "objects", "expression.csv"), append = TRUE)
e <- run(bc, "--from-run", shQuote(u), "--outdir", shQuote(file.path(tmp, "tamper"))); check(any(grepl("OS_HANDOFF_MISMATCH", e$out)), "tampered handoff refused")
file.copy(small, file.path(u, "objects", "expression.csv"), overwrite = TRUE)
write_handoff(u, "fixture", "fixture", "1.0.0", list(expression_matrix = list(path = file.path(u, "objects", "expression.csv"), type = "batch_corrected_matrix")))
e <- run(bc, "--from-run", shQuote(u), "--outdir", shQuote(file.path(tmp, "corrected"))); check(any(grepl("OS_BATCH_CORRECTED_INPUT", e$out)), "corrected lineage refused")
# Inference boundaries are tested end to end on real anchor probes.
for (fshared in c("args.R", "effect_table.R", "fig_all.R", "m4_io.R")) source(file.path(shared, fshared))
source(file.path(mod,"scripts/wgcna_network_core.R"))
source(file.path(mod,"scripts/wgcna_network_report.R"))
plot_labels <- function(p) {
 labels <- c(p$data$label, unlist(lapply(p$layers, function(l) l$data$label)))
 if (length(p$patches$plots)) labels <- c(labels, unlist(lapply(p$patches$plots, plot_labels)))
 labels
}
for (setting in c("spearman", "cosine")) {
 dest <- file.path(tmp, setting)
 controls <- if (setting == "spearman") c("--cor-method", shQuote('"spearman"')) else c("--cor-cosine", "true")
 check(run(b, controls, "--outdir", shQuote(dest))$status == 0, paste(setting, "CLI run"))
 tab <- utils::read.csv(file.path(dest,"tables/module_traits.csv"))
 effect <- utils::read.csv(file.path(dest,"tables/effect_table.csv"))
 side <- utils::read.csv(file.path(dest,"tables/module_traits_inference.csv"))
 check(identical(names(tab), trait_cols) && all(is.na(tab$p_value)) && all(is.na(tab$p_adjusted)), paste(setting,"sealed schema with NA P values"))
 check(identical(side$module, tab$module) && all(side$inference == "descriptive_no_p") && all(side$n_pairwise_complete == tab$n_unweighted) && all(side$p_value_source == "none (descriptive correlation)"), paste(setting,"descriptive inference sidecar"))
 check(all(effect$test_name == "none (descriptive correlation)") && all(is.na(effect$p_value)) && all(is.na(effect$p_adj_method)), paste(setting,"descriptive effect test"))
 wording <- paste(readLines(file.path(dest,"draft/methods_results.md")),collapse="\n")
 check(grepl("No P values were computed because a Student-t P value is not valid", wording, fixed=TRUE) && grepl("the correlations are descriptive",wording,fixed=TRUE),paste(setting,"Methods/Results wording"))
 cap <- jsonlite::read_json(file.path(dest,"figures/module_traits.figure_spec.json"))$caption
 check(grepl("no P values are shown",cap,fixed=TRUE) && grepl("not valid for this correlation setting",cap,fixed=TRUE),paste(setting,"caption reason"))
 rr <- matrix(tab$estimate, nrow=nrow(tab), dimnames=list(tab$module,"other_fat"))
 labels <- plot_labels(os_module_trait(rr, matrix(NA_real_, nrow(rr),1)))
 check(length(labels) == nrow(tab) && all(!grepl("[()\n]",labels)) && all(!grepl("NA",labels,fixed=TRUE)),paste(setting,"actual figure labels show r only"))
}
missing <- f$traits; missing$other_fat[1] <- NA_real_
missing_path <- file.path(tmp,"missing_traits.csv"); utils::write.csv(data.frame(sample=rownames(missing),other_fat=missing$other_fat),missing_path,row.names=FALSE)
bmiss <- b; bmiss[match("--samples",bmiss)+1L] <- shQuote(missing_path)
miss <- file.path(tmp,"missing-trait")
check(run(bmiss,"--outdir",shQuote(miss))$status == 0,"missing trait Pearson CLI run")
mt <- utils::read.csv(file.path(miss,"tables/module_traits.csv"))
me <- readRDS(file.path(miss,"objects/eigengenes.rds"))
tr <- as.matrix(missing[rownames(me),"other_fat",drop=FALSE])
pair_n <- crossprod(!is.na(as.matrix(me)),!is.na(tr))
ref_r <- WGCNA::cor(me,tr,use="p",method="pearson",nThreads=1)
ref_p <- WGCNA::corPvalueStudent(cor=ref_r,nSamples=pair_n)
ms <- utils::read.csv(file.path(miss,"tables/module_traits_inference.csv"))
check(identical(names(mt), trait_cols) && all(mt$n_unweighted == nrow(f$x)-1L) && identical(as.numeric(mt$n_unweighted),as.vector(pair_n)),"missing trait pairwise sample counts")
check(all(ms$inference == "pearson_student_t") && identical(as.numeric(ms$n_pairwise_complete),as.vector(pair_n)) && all(ms$n_samples == nrow(f$x)),"missing trait inference sidecar pairwise counts")
mwd <- paste(readLines(file.path(miss,"draft/methods_results.md")),collapse=" ")
check(grepl(sprintf("pairwise complete sample count of each module-trait pair (n=%d of %d samples", nrow(f$x)-1L, nrow(f$x)), mwd, fixed=TRUE) && grepl("Trait values were missing for some samples", jsonlite::read_json(file.path(miss,"figures/module_traits.figure_spec.json"))$caption, fixed=TRUE), "missing trait pairwise n stated in Methods and caption")
check(max(abs(mt$p_value-as.vector(ref_p))) < 1e-12,"missing trait P values match direct corPvalueStudent")
# Direct native comparisons on the real 200-probe anchor subset.
source(file.path(mod,"scripts/wgcna_network_core.R"))
args <- list(power=6,powers="1,2,3,4,5,6,7,8,9,10,12,14,16,18,20",`network-type`="unsigned",`tom-type`="unsigned",`min-module-size`=30,`max-block-size`=5000,seed=20260925,`deep-split`=2,`pam-respects-dendro`="false",`reassign-threshold`=0,`merge-height`=.25,traits="other_fat",`trait-p-adjust`="BH")
for(corType in c("pearson","bicor")) {
 args[["network-cor-type"]] <- paste0('"',corType,'"')
 args[["network-tomdenom"]] <- '"mean"'
 rr <- wgcna_network_compute(args,mat,f$traits)
 nn <- WGCNA::blockwiseModules(as.data.frame(t(mat)),power=6,TOMType="unsigned",minModuleSize=30,reassignThreshold=0,mergeCutHeight=.25,pamRespectsDendro=FALSE,nThreads=1,randomSeed=20260925,corType=corType,TOMDenom="mean",verbose=0)
 check(identical(rr$net$colors,nn$colors),paste("native",corType,"TOMDenom mean module labels"))
 check(isTRUE(all.equal(rr$net$MEs,nn$MEs)),paste("native",corType,"TOMDenom mean eigengenes"))
}
for(method in c("BH","none")) {
 args[["trait-p-adjust"]] <- method
 rr <- wgcna_network_compute(args,mat,f$traits)
 check(identical(rr$assoc$p_adjusted,stats::p.adjust(rr$assoc$p_value,method)),paste("native saved P adjustment",method))
}
for(method in c("pearson","spearman")) {
 args[["cor-method"]] <- paste0('"',method,'"')
 check(isTRUE(all.equal(wg_cor(t(mat),as.matrix(f$traits$other_fat),args),WGCNA::cor(t(mat),as.matrix(f$traits$other_fat),use="p",method=method,nThreads=1))),paste("native correlation binding",method))
}
# CLI verifies that nondefault controls reach Methods and captions.
na <- file.path(tmp,"native-alternative")
check(run(b,"--network-cor-type",shQuote('"bicor"'),"--network-tomdenom",shQuote('"mean"'),"--trait-p-adjust","none","--outdir",shQuote(na))$status==0,"native alternative CLI")
md <- paste(readLines(file.path(na,"draft/methods_results.md")),collapse="\n")
check(grepl("bicor correlation",md,fixed=TRUE)&&grepl("none adjustment",md,fixed=TRUE),"actual Methods correlation/adjustment")
cap <- jsonlite::read_json(file.path(na,"figures/module_traits.figure_spec.json"))$caption
check(grepl("none adjustment",cap,fixed=TRUE),"actual adjustment caption")

gold <- c("tables/gene_modules.csv", "tables/module_sizes.csv", "tables/module_traits.csv", "tables/soft_threshold.csv", "draft/methods_results.md", "figures/soft_threshold.figure_spec.json", "figures/module_traits.figure_spec.json")
if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) os_golden_write(mod, a0, gold)
g <- os_golden_check(mod, a0); if (g$status == "SKIP") cat("SKIP: golden", g$reason, "\n") else check(g$status == "PASS", "container golden")
check(!file.exists(file.path(tmp, "Rplots.pdf")), "no Rplots.pdf"); setwd(old)
cat("SMOKE PASSED:", n, "checks\n")
