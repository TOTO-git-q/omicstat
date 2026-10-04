# make_combat_seq_sim.R -- ComBat_seq anchor fixture (PACK section C). ASCII only.
# The sva vignette's own ComBat_seq example (sec 8, "ComBat-Seq for batch
# adjustment on RNA-Seq count data") simulates its count matrix
# (matrix(rnbinom(400, size = 10, prob = 0.1), nrow = 50, ncol = 8)) with no
# seed shown in the rendered text: PACK section C calls this a REPLAY anchor
# only. A fixed seed makes it reproducible here; the printed console messages
# ("Found 2 batches", "Using .* model in ComBat-seq.", "Adjusting for N
# covariate(s) or covariate level(s)", "Shrinkage off - using GLM estimates
# for parameters") do not depend on the random values and are checked
# verbatim against the vignette's rendered text. Writes <dir>/counts.tsv
# (feature_id + 8 samples) and <dir>/samples.csv (sample, batch, group).
make_combat_seq_sim <- function(dir, seed) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  set.seed(seed)
  count_matrix <- matrix(stats::rnbinom(400, size = 10, prob = 0.1), nrow = 50, ncol = 8)
  rownames(count_matrix) <- sprintf("gene%02d", seq_len(50))
  colnames(count_matrix) <- sprintf("S%d", seq_len(8))
  batch <- c(rep(1, 4), rep(2, 4))
  group <- rep(c(0, 1), 4)
  counts_df <- data.frame(feature_id = rownames(count_matrix), count_matrix, check.names = FALSE)
  samples <- data.frame(sample = colnames(count_matrix), batch = batch, group = group, stringsAsFactors = FALSE)
  p <- list(counts = file.path(dir, "counts.tsv"), samples = file.path(dir, "samples.csv"))
  utils::write.table(counts_df, p$counts, sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.csv(samples, p$samples, row.names = FALSE)
  p
}
