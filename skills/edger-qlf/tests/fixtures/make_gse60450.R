# edgeR User's Guide 4.4 GSE60450 counts, locked input SHA256.
GSE60450_SHA256 <- "906b6ec4c33e95ca0ba454a3e0d07ad74e9cb7528ee38b89a9b122f5674a5f0d"
make_gse60450 <- function(dir, suite) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  src <- file.path(suite, "acceptance", "data", "GSE60450_Lactation-GenewiseCounts.txt.gz")
  if (!file.exists(src)) return(NULL)
  got <- digest::digest(file = src, algo = "sha256")
  if (!identical(got, GSE60450_SHA256)) stop(sprintf("OS_ANCHOR_MISMATCH: GSE60450 SHA256 %s", got), call. = FALSE)
  d <- utils::read.delim(gzfile(src), check.names = FALSE)
  if (nrow(d) != 27179 || !all(c("EntrezGeneID", "Length") %in% names(d))) stop("OS_ANCHOR_MISMATCH: unexpected GSE60450 count table shape.", call. = FALSE)
  cols <- names(d)[-(1:2)]
  if (length(cols) != 12 || !identical(sub("_.*", "", cols), c(paste0("MCL1-", c("DG","DH","DI","DJ","DK","DL","LA","LB","LC","LD","LE","LF")))))
    stop("OS_ANCHOR_MISMATCH: GSE60450 sample columns differ from the guide order.", call. = FALSE)
  # The guide maps the twelve raw columns to these GEO accessions. Keep the
  # raw column order, while using compact, traceable labels in figures.
  ids <- c(paste0("GSM1480", 297:302), paste0("GSM1480", 291:296))
  names(d)[-(1:2)] <- ids
  samples <- data.frame(sample = ids, condition = rep(c("B.virgin","B.pregnant","B.lactate","L.virgin","L.pregnant","L.lactate"), each = 2), stringsAsFactors = FALSE)
  out <- list(counts = file.path(dir, "counts.tsv"), samples = file.path(dir, "samples.csv"), source_sha256 = got)
  utils::write.table(data.frame(feature_id = as.character(d$EntrezGeneID), d[, -(1:2), drop = FALSE], check.names = FALSE), out$counts, sep = "\t", quote = FALSE, row.names = FALSE)
  utils::write.csv(samples, out$samples, row.names = FALSE)
  out
}
