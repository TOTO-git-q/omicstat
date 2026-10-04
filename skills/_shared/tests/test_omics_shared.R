# test_omics_shared.R -- tests for feature_table.R, handoff.R, calls_check.R.
# ASCII only. Run with: Rscript test_omics_shared.R (any working directory).
# Same PASS/FAIL protocol as the other _shared tests.

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
S <- file.path(here, "..", "scripts")
source(file.path(S, "feature_table.R")); source(file.path(S, "handoff.R")); source(file.path(S, "calls_check.R"))
source(file.path(here, "fixtures", "fig_fixtures.R"))

failures <- character(0)
check <- function(cond, msg) {
  if (isTRUE(cond)) cat(sprintf("PASS: %s\n", msg))
  else { cat(sprintf("FAIL: %s\n", msg)); failures <<- c(failures, msg) }
}
err_code <- function(expr) tryCatch({ force(expr); "" }, error = function(e) sub(":.*$", "", conditionMessage(e)))
tmp <- file.path(tempdir(), "omicstat_shared_test"); unlink(tmp, recursive = TRUE); dir.create(tmp)

# ------------------------------------------------------------ feature table
raw <- fx_feature_table(500)
raw$feature_id[1:3] <- paste0(raw$feature_id[1:3], ".12")
ft <- as_feature_table(raw)
check(!any(grepl("\\.[0-9]+$", ft$feature_id)), "FT as_feature_table strips Ensembl version suffix")
check(identical(names(ft), FEATURE_TABLE_SCHEMA$column), "FT columns in schema order")
v <- validate_feature_table(ft)
check(v$ok, "FT fixture validates")
bad <- ft; bad$padj[1] <- 1.5
check(!validate_feature_table(bad)$ok, "FT padj > 1 rejected")
bad <- ft; bad$feature_id[2] <- "ENSG00000000001.4"
check(!validate_feature_table(bad)$ok, "FT versioned Ensembl ID rejected")
bad <- rbind(ft, ft[1, ])
check(!validate_feature_table(bad)$ok, "FT duplicated feature within contrast rejected")
deg <- ft; deg$padj <- NA
check(any(grepl("OS_DEGENERATE", validate_feature_table(deg)$warnings)), "FT all-NA padj flagged degenerate")
deg <- ft; deg$log2fc[1] <- Inf
check(any(grepl("non-finite", validate_feature_table(deg)$warnings)), "FT infinite log2fc flagged")
p1 <- file.path(tmp, "a.csv"); p2 <- file.path(tmp, "b.csv")
write_feature_table(ft, p1); write_feature_table(as_feature_table(raw[sample(nrow(raw)), ]), p2)
check(identical(digest::digest(file = p1), digest::digest(file = p2)), "FT persisted bytes independent of input row order")
cli <- system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(S, "validate_feature_table_cli.R")), shQuote(p1)), stdout = TRUE, stderr = FALSE)
js <- jsonlite::fromJSON(paste(cli, collapse = ""))
check(isTRUE(js$ok), "FT validator CLI accepts the persisted table")

# ------------------------------------------------------------------ handoff
up <- file.path(tmp, "run_up"); dir.create(file.path(up, "objects"), recursive = TRUE)
saveRDS(list(x = 1), file.path(up, "objects", "dds.rds"))
invisible(file.copy(p1, file.path(up, "objects", "feature_table.csv")))
write_handoff(up, "run-0001", "deseq2-wald", "1.0.0",
              list(dds = list(path = file.path(up, "objects", "dds.rds"), type = "DESeqDataSet"),
                   feature_table = list(path = file.path(up, "objects", "feature_table.csv"), type = "feature_table")),
              contract_hash = "abc", ecosystem = "neutral", state = list(seed = 20260925, alpha = 0.05),
              upstream_runs = "run-0000")
h <- read_handoff(up, expect = list(dds = "DESeqDataSet"), contract_hash = "abc")
check(identical(h$upstream_runs, c("run-0000", "run-0001")), "HO upstream_runs chain ends with the writing run")
check(identical(err_code(read_handoff(up, expect = list(dds = "Seurat"))), "OS_HANDOFF_MISMATCH"), "HO wrong object type -> OS_HANDOFF_MISMATCH")
check(identical(err_code(read_handoff(up, contract_hash = "zzz")), "OS_CONTRACT_MISMATCH"), "HO changed contract -> OS_CONTRACT_MISMATCH")
check(identical(err_code(read_handoff(file.path(tmp, "nope"))), "OS_HANDOFF_MISSING"), "HO missing handoff -> OS_HANDOFF_MISSING")
saveRDS(list(x = 2), file.path(up, "objects", "dds.rds"))
check(identical(err_code(read_handoff(up)), "OS_HANDOFF_MISMATCH"), "HO modified object -> sha256 mismatch")
sc <- file.path(tmp, "run_sc"); dir.create(file.path(sc, "objects"), recursive = TRUE)
saveRDS(1, file.path(sc, "objects", "seurat.rds"))
write_handoff(sc, "run-0100", "seurat-qc", "1.0.0", list(obj = list(path = file.path(sc, "objects", "seurat.rds"), type = "Seurat")),
              ecosystem = "seurat")
check(identical(err_code(read_handoff(sc, front_end_ecosystem = "bioconductor")), "OS_ECOSYSTEM_MIXED"), "HO Seurat chain into scran front end -> OS_ECOSYSTEM_MIXED")
check(identical(err_code(read_handoff(sc, front_end_ecosystem = "seurat")), ""), "HO same ecosystem accepted")
check(identical(err_code(read_handoff(sc)), ""), "HO neutral back-end module accepts either ecosystem")
b1 <- digest::digest(file = file.path(sc, "objects", "handoff.json"))
write_handoff(sc, "run-0100", "seurat-qc", "1.0.0", list(obj = list(path = file.path(sc, "objects", "seurat.rds"), type = "Seurat")),
              ecosystem = "seurat")
check(identical(b1, digest::digest(file = file.path(sc, "objects", "handoff.json"))), "HO handoff.json byte-stable")
# S5 R4: in container mode the run directory is mounted at /ws, so a module's
# basename(outdir) is "ws"; OMICSTAT_RUN_ID (set by the MCP shell) names the run.
ws <- file.path(tmp, "ws"); dir.create(file.path(ws, "objects"), recursive = TRUE)
saveRDS(1, file.path(ws, "objects", "x.rds"))
ws_obj <- list(x = list(path = file.path(ws, "objects", "x.rds"), type = "rds"))
old_env <- Sys.getenv("OMICSTAT_RUN_ID", NA)
Sys.unsetenv("OMICSTAT_RUN_ID")
write_handoff(ws, basename(ws), "omicstat-selftest", "1.0.0", ws_obj, upstream_runs = "up-1")
check(identical(read_handoff(ws)$run_id, "ws") && identical(os_run_id(ws), "ws"), "HO R4 without OMICSTAT_RUN_ID the run id stays basename(outdir)")
rid <- "3f2b8c1e-5d4a-4e7b-9c1d-2a6f8e0b7c55"
Sys.setenv(OMICSTAT_RUN_ID = rid)
write_handoff(ws, basename(ws), "omicstat-selftest", "1.0.0", ws_obj, upstream_runs = "up-1")
hw <- read_handoff(ws)
check(identical(os_run_id(ws), rid) && identical(hw$run_id, rid) && identical(hw$upstream_runs, c("up-1", rid)),
      "HO R4 OMICSTAT_RUN_ID replaces the directory-derived id ('ws'); upstream_runs ends with the MCP run id")
write_handoff(ws, "fixture-run", "omicstat-selftest", "1.0.0", ws_obj)
check(identical(read_handoff(ws)$run_id, "fixture-run"), "HO R4 an explicit run id that is not basename(outdir) is kept")
Sys.setenv(OMICSTAT_RUN_ID = "../bad id")
check(identical(err_code(write_handoff(ws, basename(ws), "omicstat-selftest", "1.0.0", ws_obj)), "OS_INVALID_PARAMETER"),
      "HO R4 a malformed OMICSTAT_RUN_ID is refused")
if (is.na(old_env)) Sys.unsetenv("OMICSTAT_RUN_ID") else Sys.setenv(OMICSTAT_RUN_ID = old_env)
bc <- file.path(tmp, "run_bc"); dir.create(file.path(bc, "objects"), recursive = TRUE)
invisible(file.copy(p1, file.path(bc, "objects", "corrected.csv")))
write_handoff(bc, "run-0200", "sva-batch", "1.0.0", list(count_matrix = list(path = file.path(bc, "objects", "corrected.csv"), type = "batch_corrected_matrix")))
check(identical(err_code(read_handoff(bc, expect = list(count_matrix = "count_matrix"))), "OS_BATCH_CORRECTED_INPUT"),
      "HO batch-corrected matrix requested as count_matrix -> OS_BATCH_CORRECTED_INPUT")
check(identical(err_code(read_handoff(bc, expect = list(count_matrix = "batch_corrected_matrix"))), ""),
      "HO batch-corrected matrix accepted where that type is expected")

# ------------------------------------------------------------ calls check
scr <- file.path(tmp, "run_toy.R")
writeLines(c(
  "m <- matrix(1:20, 5)",
  "p <- stats::prcomp(t(m), center = TRUE, scale. = FALSE)",
  "q <- stats::prcomp(t(m), center = TRUE)",
  "h <- stats::hclust(stats::dist(m, method = 'euclidean'), method = 'complete')"
), scr)
reg <- list(module = "toy", package_versions = list(stats = as.character(getRversion())),
            calls = list(list(fn = "stats::prcomp", args = list(center = list(value = TRUE, source = "vignette"),
                                                                   scale. = list(value = FALSE, source = "vignette", function_default = "FALSE"))),
                         list(fn = "stats::hclust", args = list(method = list(value = "complete", source = "pack_majority",
                                                                                 function_default = "\"complete\""))),
                         list(fn = "stats::dist", args = list(method = list(value = "euclidean", source = "pack_majority")))))
cc <- check_calls(scr, reg)
check(!cc$ok && any(grepl("^C1 .*:3 stats::prcomp .*scale\\.", cc$problems)), "CC missing explicit argument caught (line 3)")
check(!any(grepl(":2 ", cc$problems)), "CC fully explicit call passes")
reg2 <- reg; reg2$calls[[3]] <- NULL
cc2 <- check_calls(scr, reg2)
check(any(grepl("C2 .*stats::dist", cc2$problems)), "CC unregistered package call caught")
reg3 <- reg; reg3$calls[[4]] <- list(fn = "stats::kmeans", args = list())
check(any(grepl("C3 .*kmeans", check_calls(scr, reg3)$problems)), "CC stale registry entry caught")
dd <- check_default_drift(reg)
check(dd$ok, "CC recorded defaults match the installed formals()")
reg4 <- reg; reg4$calls[[2]]$args$method$function_default <- "\"average\""
check(any(grepl("^D1 ", check_default_drift(reg4)$problems)), "CC default drift detected")

if (length(failures)) {
  cat(sprintf("%d check(s) FAILED:\n", length(failures))); for (f in failures) cat("  - ", f, "\n", sep = ""); quit(status = 1)
} else { cat("ALL OMICS SHARED CHECKS PASSED\n"); quit(status = 0) }
