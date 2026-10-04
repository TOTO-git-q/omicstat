# Shared, deterministic enrichment table I/O for the M2 modules.
os_enrich_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, "wb"); on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

os_enrich_registry_go <- function(suite) {
  p <- file.path(suite, "env", "refdata_registry.json")
  reg <- jsonlite::fromJSON(p, simplifyVector = FALSE)
  ids <- vapply(reg$entries, function(z) z$id, "")
  if (!"go_annotation" %in% ids || !requireNamespace("org.Hs.eg.db", quietly = TRUE) ||
      !requireNamespace("GO.db", quietly = TRUE))
    stop("OS_REFDATA_MISSING: registered GO annotation or org.Hs.eg.db is absent.", call. = FALSE)
  list(id = "go_annotation", orgdb = "org.Hs.eg.db", orgdb_version = as.character(utils::packageVersion("org.Hs.eg.db")),
       go_version = as.character(utils::packageVersion("GO.db")))
}

os_enrich_canonical <- function(raw, database = "GO", group = NULL) {
  out <- raw
  # AnnotationDbi can enumerate an overlapping gene set in a different order
  # across fresh R processes. The membership, not that enumeration, is the result.
  if ("geneID" %in% names(out)) out$geneID <- vapply(strsplit(as.character(out$geneID), "/", fixed = TRUE),
    function(z) paste(sort(z, method = "radix"), collapse = "/"), "")
  out$term_id <- as.character(raw$ID)
  out$term_name <- as.character(raw$Description)
  out$database <- database
  out$n_genes <- if ("Count" %in% names(raw)) as.integer(raw$Count) else NA_integer_
  out$gene_ratio <- if ("GeneRatio" %in% names(raw)) {
    vapply(strsplit(as.character(raw$GeneRatio), "/", fixed = TRUE), function(z) as.numeric(z[1]) / as.numeric(z[2]), 0.0)
  } else NA_real_
  out$set_size <- if ("BgRatio" %in% names(raw)) {
    as.integer(vapply(strsplit(as.character(raw$BgRatio), "/", fixed = TRUE), `[`, "", 1))
  } else if ("setSize" %in% names(raw)) as.integer(raw$setSize) else NA_integer_
  out$pvalue <- as.numeric(raw$pvalue)
  out$padj <- as.numeric(raw$p.adjust)
  if ("NES" %in% names(raw)) out$nes <- as.numeric(raw$NES)
  if (!is.null(group)) out$group <- group
  out$significant_bh05 <- !is.na(out$padj) & out$padj < 0.05
  out
}
