# Read actual canonical outputs; no computation or expected-value substitution.
a <- commandArgs(TRUE)
stopifnot(length(a) == 2L)
j <- jsonlite::fromJSON(file.path(a[1], "results/deseq2_wald_results.json"))
f <- utils::read.csv(file.path(a[1], "tables/deseq2_results_full.csv"), stringsAsFactors = FALSE)
g <- f[f$feature_id == "FBgn0000017", , drop = FALSE]
h <- f[f$feature_id == "FBgn0000008", , drop = FALSE]
stopifnot(nrow(g) == 1L, nrow(h) == 1L)
x <- list(`DW-A1` = j$n_tested, `DW-A2` = j$n_significant, `DW-A3` = j$n_up,
          `DW-A4` = j$n_down, `DW-A5` = g$log2fc_mle, `DW-A6` = g$padj,
          `DW-A7` = g$log2fc_shrunken, `DW-A8` = h$log2fc_mle,
          `DW-A9` = h$log2fc_shrunken)
jsonlite::write_json(x, a[2], auto_unbox = TRUE, digits = NA, na = "null")
