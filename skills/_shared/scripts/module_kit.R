# module_kit.R -- building blocks every analysis module shares: input tables,
# QC rule tables, the --spec replay, provenance, environment signature and the
# report templates read from references/reporting-templates.md.
# ASCII only on purpose (docs/CONVENTIONS.md sec 2).
#
# Contents
#   os_spec_argv(argv)                  expand "--spec <resolved_spec.json>" into argv
#   os_read_matrix(path, what)          feature x sample numeric matrix from csv/tsv
#   os_read_sample_table(path, col)     sample sheet (character columns)
#   os_align_samples(mat, st, col)      reorder the sheet to the matrix columns
#   os_count_state(mat)                 integer / negative / all-zero diagnostics
#   os_qc_rule(), os_qc_finalize(), os_write_qc_results()
#   os_env_signature()                  tier + R + Bioconductor + platform
#   os_write_provenance()               provenance/provenance.json + resolved_spec.json
#   os_read_templates(path)             ```template <id> blocks of reporting-templates.md
#   os_fill_template(text, values)      {slot} substitution; a missing slot is an error
#   os_write_text(lines, path)          UTF-8, LF, no BOM
#   os_golden_check(module_dir, outdir) compare a run with tests/golden_manifest.csv
#   os_acceptance_file(suite, pkg, ...) file of an acceptance-layer data package (smoke tests only)
#   os_acceptance_data(suite, pkg, nm)  data object of an acceptance-layer data package

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

os_write_text <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), con)
  invisible(path)
}

# ---------------------------------------------------------------------------
# --spec replay (ENGINEERING_PLAN 3.2 step 2)
# ---------------------------------------------------------------------------
# provenance/resolved_spec.json holds {"argv": [...]} -- the canonical flag
# vector of a finished run. "--spec <file>" is replaced by that vector; flags
# given on the command line win over the replayed ones. Keys ending in
# "_resolved" are information only and never replayed.
os_spec_argv <- function(argv) {
  i <- which(argv == "--spec" | startsWith(argv, "--spec="))
  if (!length(i)) return(argv)
  i <- i[1]
  path <- if (argv[i] == "--spec") argv[i + 1L] else sub("^--spec=", "", argv[i])
  if (is.na(path) || !file.exists(path)) stop(sprintf("OS_INVALID_PARAMETER: --spec expected an existing resolved_spec.json, got '%s'", path), call. = FALSE)
  rest <- argv[-c(i, if (argv[i] == "--spec") i + 1L)]
  rs <- jsonlite::fromJSON(path, simplifyVector = TRUE)
  old <- as.character(rs$argv %||% character(0))
  flags_of <- function(v) sub("=.*$", "", v[startsWith(v, "--")])
  drop <- intersect(flags_of(old), flags_of(rest))
  keep <- character(0); j <- 1L
  while (j <= length(old)) {
    tok <- old[j]
    has_val <- j < length(old) && !startsWith(old[j + 1L], "--") && !grepl("=", tok, fixed = TRUE)
    if (!sub("=.*$", "", tok) %in% drop) keep <- c(keep, tok, if (has_val) old[j + 1L])
    j <- j + if (has_val) 2L else 1L
  }
  c(keep, rest)
}

# ---------------------------------------------------------------------------
# Input tables
# ---------------------------------------------------------------------------
.os_read_delim <- function(path) {
  first <- readLines(path, n = 1L, warn = FALSE)
  sep <- if (grepl("\t", first, fixed = TRUE)) "\t" else ","
  utils::read.table(path, header = TRUE, sep = sep, quote = "\"", comment.char = "", check.names = FALSE,
                    stringsAsFactors = FALSE, colClasses = "character", na.strings = c("NA", ""))
}

# First column = feature id; all other columns numeric. Duplicate or empty ids
# and non-numeric cells are typed errors.
os_read_matrix <- function(path, what = "matrix") {
  df <- .os_read_delim(path)
  if (ncol(df) < 2) stop(sprintf("OS_INVALID_INPUT: %s %s needs a feature-id column plus at least one sample column.", what, path), call. = FALSE)
  ids <- df[[1]]
  if (anyNA(ids) || any(!nzchar(ids))) stop(sprintf("OS_INVALID_INPUT: %s has empty feature ids.", what), call. = FALSE)
  dup <- unique(ids[duplicated(ids)])
  if (length(dup)) stop(sprintf("OS_INVALID_INPUT: %s has duplicated feature ids: %s.", what, paste(utils::head(dup, 5), collapse = ", ")), call. = FALSE)
  vals <- df[-1]
  num <- suppressWarnings(lapply(vals, as.numeric))
  bad <- vapply(seq_along(num), function(k) any(is.na(num[[k]]) & !is.na(vals[[k]])), logical(1))
  if (any(bad)) stop(sprintf("OS_INVALID_INPUT: %s has non-numeric values in column(s): %s.", what, paste(utils::head(names(vals)[bad], 5), collapse = ", ")), call. = FALSE)
  m <- matrix(unlist(num, use.names = FALSE), nrow = nrow(df), dimnames = list(ids, names(vals)))
  if (anyNA(m)) stop(sprintf("OS_INVALID_INPUT: %s contains missing values (%d cells).", what, sum(is.na(m))), call. = FALSE)
  m
}

os_read_sample_table <- function(path, sample_col) {
  st <- .os_read_delim(path)
  if (!sample_col %in% names(st)) stop(sprintf("OS_MISSING_COLUMN: sample table has no column '%s' (columns: %s).", sample_col, paste(names(st), collapse = ", ")), call. = FALSE)
  dup <- unique(st[[sample_col]][duplicated(st[[sample_col]])])
  if (length(dup)) stop(sprintf("OS_INVALID_DESIGN: duplicated sample ids in the sample table: %s.", paste(utils::head(dup, 5), collapse = ", ")), call. = FALSE)
  st
}

# Every matrix column must have exactly one sheet row and vice versa; the
# sheet is returned in matrix column order (never matched by position).
os_align_samples <- function(mat, st, sample_col) {
  in_mat <- colnames(mat); in_st <- st[[sample_col]]
  miss_st <- setdiff(in_mat, in_st); miss_mat <- setdiff(in_st, in_mat)
  if (length(miss_st) || length(miss_mat)) {
    stop(sprintf("OS_INVALID_DESIGN: matrix columns and sample table disagree. Not in the sample table: %s. Not in the matrix: %s.",
                 if (length(miss_st)) paste(utils::head(miss_st, 8), collapse = ", ") else "none",
                 if (length(miss_mat)) paste(utils::head(miss_mat, 8), collapse = ", ") else "none"), call. = FALSE)
  }
  out <- st[match(in_mat, in_st), , drop = FALSE]
  rownames(out) <- out[[sample_col]]
  out
}

os_count_state <- function(mat) {
  list(n_features = nrow(mat), n_samples = ncol(mat),
       n_non_integer = sum(abs(mat - round(mat)) > 1e-8),
       n_negative = sum(mat < 0),
       n_all_zero = sum(rowSums(mat != 0) == 0),
       library_sizes = colSums(mat))
}

# ---------------------------------------------------------------------------
# QC rule table (dialect read by mcp/publication.py scan_qc)
# ---------------------------------------------------------------------------
# Severities: blocker (blocking = TRUE; the draft is withheld), error,
# warning, info. One row per rule, triggered or not.
OS_QC_SEVERITIES <- c("blocker", "error", "warning", "info")

os_qc_rule <- function(id, check, triggered, severity, message, action = "", evidence = "") {
  if (!severity %in% OS_QC_SEVERITIES) stop(sprintf("OS_INVALID_PARAMETER: QC severity '%s' is not one of %s.", severity, paste(OS_QC_SEVERITIES, collapse = ", ")), call. = FALSE)
  trig <- isTRUE(triggered)
  data.frame(id = id, check = check, severity = severity, triggered = trig,
             blocking = trig && identical(severity, "blocker"), message = message,
             action = if (trig) action else "", evidence = evidence, stringsAsFactors = FALSE)
}

os_qc_finalize <- function(rows, read_first) {
  qc <- do.call(rbind, rows)
  qc <- qc[order(qc$id, method = "radix"), , drop = FALSE]
  rownames(qc) <- NULL
  trig <- qc[qc$triggered, , drop = FALSE]
  rank <- match(trig$severity, OS_QC_SEVERITIES)
  worst <- if (nrow(trig)) trig$id[order(rank, trig$id, method = "radix")][1] else NA_character_
  list(table = qc, n_rules = nrow(qc), n_triggered = nrow(trig),
       blocking = any(trig$blocking), blocking_ids = trig$id[trig$blocking],
       failed = any(trig$severity %in% c("blocker", "error")),
       worst = worst, read_first = if (nrow(trig)) "qc/qc_results.csv" else read_first)
}

os_write_qc_results <- function(qc, outdir) {
  dir.create(file.path(outdir, "qc"), recursive = TRUE, showWarnings = FALSE)
  path <- file.path(outdir, "qc", "qc_results.csv")
  out <- qc$table
  out$triggered <- ifelse(out$triggered, "TRUE", "FALSE")
  out$blocking <- ifelse(out$blocking, "TRUE", "FALSE")
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

# ---------------------------------------------------------------------------
# Environment signature and provenance
# ---------------------------------------------------------------------------
os_env_signature <- function() {
  tier <- if (nzchar(Sys.getenv("OMICSTAT_CONTAINER"))) "container" else if (nzchar(Sys.getenv("OMICSTAT_R_LIBS"))) "native" else "dev"
  list(tier = tier, r = as.character(getRversion()),
       bioconductor = tryCatch(as.character(BiocManager::version()), error = function(e) NA_character_),
       platform = R.version$platform,
       image = Sys.getenv("OMICSTAT_IMAGE_ID", NA_character_))
}
os_env_signature_string <- function(sig = os_env_signature()) sprintf("%s|R %s|Bioc %s|%s", sig$tier, sig$r, sig$bioconductor, sig$platform)

# inputs: named list name -> path (sha256 recorded); outputs: character vector
# of paths relative to outdir (sha256 recorded). argv: the canonical argv of
# this run (written to resolved_spec.json for --spec replay).
os_write_provenance <- function(outdir, module, module_version, argv, entry_script, seed, inputs = list(),
                                outputs = character(0), upstream = NULL, extra = list(), packages = NULL) {
  dir.create(file.path(outdir, "provenance"), recursive = TRUE, showWarnings = FALSE)
  sha <- function(p) digest::digest(file = p, algo = "sha256")
  pk <- packages %||% sort(loadedNamespaces(), method = "radix")
  prov <- c(list(
    schema = "omicstat.provenance.v1", module = module, module_version = module_version,
    command = paste(c("Rscript", entry_script, argv), collapse = " "),
    command_argv = as.list(c("Rscript", entry_script, argv)),
    environment = os_env_signature(), seed = seed,
    inputs = lapply(inputs, function(p) list(file = basename(p), sha256 = sha(p))),
    upstream_runs = as.list(upstream$upstream_runs %||% character(0)),
    upstream_module = upstream$module %||% NULL,
    packages = stats::setNames(lapply(pk, function(p) as.character(utils::packageVersion(p))), pk),
    outputs = stats::setNames(lapply(outputs, function(f) sha(file.path(outdir, f))), outputs)), extra)
  jsonlite::write_json(prov, file.path(outdir, "provenance", "provenance.json"), auto_unbox = TRUE, pretty = TRUE,
                       null = "null", na = "null", digits = I(10))
  jsonlite::write_json(list(schema = "omicstat.resolved_spec.v1", module = module, argv = argv),
                       file.path(outdir, "provenance", "resolved_spec.json"), auto_unbox = TRUE, pretty = TRUE)
  invisible(file.path(outdir, "provenance", "provenance.json"))
}

# Canonical argv: every flag with its resolved value (switches only when on),
# in spec order; used for resolved_spec.json. Paths stay as given.
os_canonical_argv <- function(spec, args, skip = c("help", "spec", "outdir")) {
  out <- character(0)
  for (f in spec$flags) {
    if (f$name %in% skip) next
    v <- args[[f$name]]
    if (identical(f$type, "bool")) { if (isTRUE(v)) out <- c(out, paste0("--", f$name)); next }
    if (is.null(v) || (length(v) == 1 && is.na(v))) next
    out <- c(out, paste0("--", f$name), format(v, scientific = FALSE, trim = TRUE, digits = 15))
  }
  out
}

# ---------------------------------------------------------------------------
# Report templates: fenced blocks in references/reporting-templates.md
# ---------------------------------------------------------------------------
#   ```template methods
#   Differential expression was assessed with DESeq2 (v{deseq2_version}) ...
#   ```
# The engine fills the SAME text the documentation shows, so the two cannot
# drift. Slots are {name}; a slot without a value is OS_TEMPLATE_SLOT_MISSING.
os_read_templates <- function(path) {
  x <- readLines(path, warn = FALSE, encoding = "UTF-8")
  starts <- grep("^```template [A-Za-z0-9_]+\\s*$", x)
  out <- list()
  for (s in starts) {
    id <- sub("^```template ([A-Za-z0-9_]+)\\s*$", "\\1", x[s])
    e <- s + which(x[(s + 1):length(x)] == "```")[1]
    if (is.na(e)) stop(sprintf("OS_INVALID_INPUT: template '%s' in %s is not closed.", id, path), call. = FALSE)
    out[[id]] <- paste(x[(s + 1):(e - 1)], collapse = "\n")
  }
  out
}

os_fill_template <- function(text, values) {
  slots <- unique(regmatches(text, gregexpr("\\{[A-Za-z0-9_]+\\}", text))[[1]])
  for (s in slots) {
    key <- substr(s, 2, nchar(s) - 1)
    v <- values[[key]]
    if (is.null(v) || length(v) != 1 || is.na(v)) stop(sprintf("OS_TEMPLATE_SLOT_MISSING: no value for {%s}.", key), call. = FALSE)
    text <- gsub(s, as.character(v), text, fixed = TRUE)
  }
  text
}

# ---------------------------------------------------------------------------
# Golden baseline (lock 5)
# ---------------------------------------------------------------------------
# tests/golden_manifest.csv: path,sha256,tier,exempt_fields plus a first
# comment line "# env: <os_env_signature_string()>". Rows whose environment
# signature differs from the running one are reported as SKIP, never FAIL
# (ENGINEERING_PLAN 3.5).
os_golden_write <- function(module_dir, outdir, paths) {
  f <- file.path(module_dir, "tests", "golden_manifest.csv")
  rows <- data.frame(path = paths, sha256 = vapply(file.path(outdir, paths), function(p) digest::digest(file = p, algo = "sha256"), ""),
                     tier = os_env_signature()$tier, exempt_fields = "", stringsAsFactors = FALSE)
  os_write_text(c(paste0("# env: ", os_env_signature_string()), "path,sha256,tier,exempt_fields",
                  sprintf("%s,%s,%s,%s", rows$path, rows$sha256, rows$tier, rows$exempt_fields)), f)
  invisible(f)
}

os_golden_check <- function(module_dir, outdir) {
  f <- file.path(module_dir, "tests", "golden_manifest.csv")
  x <- readLines(f, warn = FALSE)
  env_line <- grep("^# env: ", x, value = TRUE)
  rows <- utils::read.csv(text = paste(x[!startsWith(x, "#")], collapse = "\n"), stringsAsFactors = FALSE)
  if (!nrow(rows) || !length(env_line)) return(list(status = "SKIP", reason = "no golden baseline recorded yet", problems = character(0)))
  want <- sub("^# env: ", "", env_line[1])
  have <- os_env_signature_string()
  if (!identical(want, have)) return(list(status = "SKIP", reason = sprintf("environment signature differs (golden: %s; running: %s)", want, have), problems = character(0)))
  got <- vapply(file.path(outdir, rows$path), function(p) if (file.exists(p)) digest::digest(file = p, algo = "sha256") else "<missing>", "")
  bad <- rows$path[got != rows$sha256]
  list(status = if (length(bad)) "FAIL" else "PASS", reason = "", problems = bad)
}

# ---------------------------------------------------------------------------
# Acceptance data layer (S1 M1-2, owner 2026-09-27). SMOKE TESTS ONLY.
# ---------------------------------------------------------------------------
# Experiment-data packages that anchors need but the image does not carry
# (pasilla, airway, fission, bladderbatch, zebrafishRNASeq, GSVAdata) live in
# <suite>/.omicstat-acceptance, built by acceptance/data/install_acceptance_lib.R
# and locked by acceptance/data/acceptance_lib_lock.csv (tarball sha256).
# Mode "installed": on the library <suite>/.omicstat-acceptance/library;
# mode "extracted": used through the unpacked, unedited tarball only.
# Every access re-checks the tarball sha256 against the lock; an absent layer
# gives "" / NULL so the caller can SKIP.
.os_acc_verified <- new.env(parent = emptyenv())
os_acceptance_entry <- function(suite, pkg) {
  lock <- file.path(suite, "acceptance", "data", "acceptance_lib_lock.csv")
  if (!file.exists(lock)) return(NULL)
  lk <- utils::read.csv(lock, stringsAsFactors = FALSE)
  e <- lk[lk$package == pkg, , drop = FALSE]
  if (nrow(e) != 1) return(NULL)
  tb <- file.path(suite, ".omicstat-acceptance", "src", e$tarball)
  if (!file.exists(tb)) return(NULL)
  if (!isTRUE(.os_acc_verified[[pkg]])) {
    if (!identical(digest::digest(file = tb, algo = "sha256"), e$sha256)) {
      stop(sprintf("OS_ACCEPTANCE_DATA: %s does not match the sha256 in acceptance_lib_lock.csv.", e$tarball), call. = FALSE)
    }
    .os_acc_verified[[pkg]] <- TRUE
  }
  as.list(e)
}
os_acceptance_lib <- function(suite) {
  lib <- file.path(suite, ".omicstat-acceptance", "library")
  if (dir.exists(lib)) .libPaths(unique(c(.libPaths(), normalizePath(lib))))
  invisible(dir.exists(lib))
}
# Path of a file shipped by an acceptance package, as system.file() would give
# it for an installed package (inst/<...> for an extracted one). "" if absent.
os_acceptance_file <- function(suite, pkg, ...) {
  e <- os_acceptance_entry(suite, pkg)
  if (is.null(e)) return("")
  if (identical(e$mode, "installed")) {
    os_acceptance_lib(suite)
    return(system.file(..., package = pkg, lib.loc = file.path(suite, ".omicstat-acceptance", "library")))
  }
  f <- file.path(suite, ".omicstat-acceptance", "extracted", pkg, "inst", ...)
  if (file.exists(f)) normalizePath(f) else ""
}
# A dataset of an acceptance package (data(name, package = pkg)); NULL if absent.
# Some Bioconductor experiment-data packages register a data name that differs
# from the R object it loads (data(package = "bladderbatch")$results lists
# "bladderEset (bladderdata)": the data() argument is "bladderdata", the
# object it populates is "bladderEset"). `name` is tried first (the common
# case, e.g. zebrafishRNASeq's zfGenes, where they are equal); when `name`
# itself is not bound afterwards but data()/load() populated exactly one
# object into the (fresh, empty) environment, that object is returned instead
# -- the caller passed the correct data() name, only the bound name differs.
os_acceptance_data <- function(suite, pkg, name) {
  e <- os_acceptance_entry(suite, pkg)
  if (is.null(e)) return(NULL)
  env <- new.env(parent = emptyenv())
  if (identical(e$mode, "installed")) {
    os_acceptance_lib(suite)
    suppressWarnings(utils::data(list = name, package = pkg, lib.loc = file.path(suite, ".omicstat-acceptance", "library"), envir = env))
  } else {
    f <- list.files(file.path(suite, ".omicstat-acceptance", "extracted", pkg, "data"),
                    pattern = sprintf("^%s[.](rda|RData)$", name), full.names = TRUE)
    if (!length(f)) return(NULL)
    load(f[1], envir = env)
  }
  if (exists(name, envir = env, inherits = FALSE)) return(get(name, envir = env, inherits = FALSE))
  bound <- ls(env, all.names = TRUE)
  if (length(bound) == 1) return(get(bound, envir = env, inherits = FALSE))
  NULL
}
