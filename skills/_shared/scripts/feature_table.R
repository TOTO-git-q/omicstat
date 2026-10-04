# feature_table.R -- canonical omics result table ("feature table") for the
# omicstat suite. ASCII only on purpose (see docs/CONVENTIONS.md sec 2).
#
# Written after effect_table.R (same API shape: SCHEMA data.frame, new_*,
# validate_* returning list(ok, errors, warnings), assert_*, write_*), per
# IMPLEMENTATION_SPEC sec 3 step 5. One row per feature x contrast. The MCP
# server recognises this table by its header (feature_id + log2fc + pvalue +
# padj) as the primary payload of a run, and its omics degeneracy checks read
# these columns (padj all NA, all significant, non-finite log2fc).
#
# Survival / proportion / association results still use effect_table.R; the
# two tables coexist.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

FEATURE_TABLE_SCHEMA <- data.frame(
  column = c("feature_id", "symbol", "contrast", "base_mean", "log2fc", "log2fc_se", "stat",
             "pvalue", "padj", "method", "shrinkage", "n_group1", "n_group2", "filtered_reason"),
  type = c("character", "character", "character", "numeric", "numeric", "numeric", "numeric",
           "numeric", "numeric", "character", "character", "integer", "integer", "character"),
  required = c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE),
  description = c(
    "Ensembl gene ID WITHOUT version suffix (internal key); other ID spaces allowed when declared in the contract",
    "display symbol only; never used as a key",
    "contrast label, e.g. 'condition: treated vs control'",
    "mean of normalized counts / average expression (method specific)",
    "log2 fold change (shrunken when shrinkage is not 'none')",
    "standard error of log2fc (NA when the method has none)",
    "test statistic (Wald z, F, moderated t, ...)",
    "raw P value",
    "multiplicity-adjusted P value (BH unless declared); NA when independently filtered",
    "engine + test, e.g. 'DESeq2 Wald', 'edgeR QLF', 'limma-voom'",
    "'apeglm' | 'ashr' | 'normal' | 'none'",
    "number of biological replicates in group 1 (numerator)",
    "number of biological replicates in group 2 (reference)",
    "why padj is NA: independent_filtering | low_count | outlier | '' "),
  stringsAsFactors = FALSE
)

feature_table_schema <- function() FEATURE_TABLE_SCHEMA

new_feature_table <- function() {
  cols <- lapply(FEATURE_TABLE_SCHEMA$type, function(t) switch(t, character = character(0), numeric = numeric(0),
                                                                integer = integer(0)))
  names(cols) <- FEATURE_TABLE_SCHEMA$column
  as.data.frame(cols, stringsAsFactors = FALSE)
}

# Build a feature table from vectors; missing optional columns are filled
# with NA / "". Rows are sorted by contrast, then padj (NA last), then
# feature_id -- the canonical order of every persisted feature table, so two
# runs with identical numbers write identical bytes.
as_feature_table <- function(df) {
  out <- new_feature_table()[rep(NA_integer_, nrow(df)), , drop = FALSE]
  rownames(out) <- NULL
  for (i in seq_len(nrow(FEATURE_TABLE_SCHEMA))) {
    col <- FEATURE_TABLE_SCHEMA$column[i]; ty <- FEATURE_TABLE_SCHEMA$type[i]
    v <- if (col %in% names(df)) df[[col]] else if (ty == "character") rep("", nrow(df)) else rep(NA, nrow(df))
    out[[col]] <- switch(ty, character = as.character(v), numeric = as.numeric(v), integer = as.integer(v))
  }
  # Only Ensembl IDs use a removable numeric version suffix. Fission gene
  # IDs such as SPAC212.11 contain a dot as part of the stable identifier.
  ens_versioned <- grepl("^ENS[A-Z]*G[0-9]+\\.[0-9]+$", out$feature_id)
  out$feature_id[ens_versioned] <- sub("\\.[0-9]+$", "", out$feature_id[ens_versioned])
  o <- order(out$contrast, is.na(out$padj), out$padj, out$feature_id, method = "radix")
  out <- out[o, , drop = FALSE]; rownames(out) <- NULL
  out
}

validate_feature_table <- function(ft) {
  errors <- character(0); warnings <- character(0)
  if (!is.data.frame(ft)) return(list(ok = FALSE, errors = "OS_SCHEMA_INVALID: feature table must be a data.frame", warnings = character(0)))
  req <- FEATURE_TABLE_SCHEMA$column[FEATURE_TABLE_SCHEMA$required]
  miss <- setdiff(req, names(ft))
  if (length(miss)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: missing required column(s): %s", paste(miss, collapse = ", ")))
  if (!length(miss)) {
    if (anyNA(ft$feature_id) || any(!nzchar(ft$feature_id))) errors <- c(errors, "OS_SCHEMA_INVALID: feature_id has empty values")
    dup <- duplicated(paste(ft$contrast, ft$feature_id, sep = "\r"))
    if (any(dup)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: %d duplicated feature_id within a contrast", sum(dup)))
    if (any(grepl("^ENS[A-Z]*G[0-9]+\\.[0-9]+$", ft$feature_id))) {
      errors <- c(errors, "OS_SCHEMA_INVALID: Ensembl IDs must be stored without version suffix (CONVENTIONS: gene IDs)")
    }
    for (pc in c("pvalue", "padj")) {
      v <- suppressWarnings(as.numeric(ft[[pc]]))
      if (any(!is.na(v) & (v < 0 | v > 1))) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: %s outside [0, 1]", pc))
    }
    lfc <- suppressWarnings(as.numeric(ft$log2fc))
    if (any(!is.na(lfc) & !is.finite(lfc))) warnings <- c(warnings, "OS_DEGENERATE: log2fc contains non-finite values")
    padj <- suppressWarnings(as.numeric(ft$padj))
    for (ct in unique(ft$contrast)) {
      pj <- padj[ft$contrast == ct]
      if (all(is.na(pj))) warnings <- c(warnings, sprintf("OS_DEGENERATE: padj is NA for every feature in contrast '%s'", ct))
      else if (length(pj[!is.na(pj)]) > 1 && all(pj[!is.na(pj)] < 0.05)) warnings <- c(warnings, sprintf("OS_DEGENERATE: every tested feature is significant in contrast '%s'", ct))
    }
    na_reason <- is.na(padj) & (!"filtered_reason" %in% names(ft) | !nzchar(ft$filtered_reason %||% ""))
    if (any(na_reason)) warnings <- c(warnings, sprintf("OS_SCHEMA_WARNING: %d rows have padj = NA without filtered_reason", sum(na_reason)))
    for (nc in c("n_group1", "n_group2")) {
      v <- suppressWarnings(as.numeric(ft[[nc]]))
      if (any(!is.na(v) & v < 2)) warnings <- c(warnings, sprintf("OS_SCHEMA_WARNING: %s < 2 biological replicates", nc))
    }
  }
  list(ok = !length(errors), errors = errors, warnings = warnings)
}

assert_feature_table <- function(ft, label = "feature table") {
  v <- validate_feature_table(ft)
  if (!v$ok) stop(sprintf("OS_SCHEMA_INVALID: %s failed validation: %s", label, paste(v$errors, collapse = "; ")), call. = FALSE)
  for (w in v$warnings) warning(w, call. = FALSE)
  invisible(TRUE)
}

# Persist with fixed formatting: 10 significant digits, "NA" for missing,
# LF line endings, UTF-8, no row names. Byte-identical across reruns.
write_feature_table <- function(ft, path) {
  assert_feature_table(ft)
  out <- ft
  for (i in seq_len(nrow(FEATURE_TABLE_SCHEMA))) {
    col <- FEATURE_TABLE_SCHEMA$column[i]
    if (!col %in% names(out)) next
    if (FEATURE_TABLE_SCHEMA$type[i] == "numeric") {
      out[[col]] <- ifelse(is.na(out[[col]]), "NA", formatC(out[[col]], digits = 10, format = "g"))
    }
  }
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}
