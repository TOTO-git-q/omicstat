# handoff.R -- the --from-run chaining contract (ENGINEERING_PLAN 1.3).
# ASCII only on purpose.
#
# An upstream module writes <run_dir>/objects/handoff.json describing every
# object it hands on; a downstream module calls read_handoff() with
# --from-run <run_dir> BEFORE it touches any object. Rejections are typed:
#   OS_HANDOFF_MISSING    no objects/handoff.json in the --from-run directory
#   OS_HANDOFF_MISMATCH   object type differs, or a file's sha256 differs
#   OS_ECOSYSTEM_MIXED    a front-end single-cell module received the other
#                         ecosystem's object (Seurat vs Bioconductor vs scverse),
#                         also through neutral modules: a neutral module records
#                         the chain's front-end ecosystem as
#                         state$front_end_ecosystem (convert.R os_sc_chain_state)
#   OS_CONTRACT_MISMATCH  the StudyContract hash differs from the chain's
#   OS_BATCH_CORRECTED_INPUT  an object of type "batch_corrected_matrix" (written
#                         by sva-batch) was requested as anything else, e.g. as
#                         the count_matrix / expression_matrix of a DE module
#                         (S1 sva-batch P-1, owner 2026-09-27: corrected
#                         matrices are for display and scoring only)
#
#   S4 (cross-module contract c): the corrected state must survive derived
#   objects. A module that derives data from a batch-corrected input (e.g.
#   gsva-score scores of a corrected matrix) sets handoff state
#   `batch_corrected_lineage = TRUE` (and types the derived matrix
#   "batch_corrected_matrix"); read_handoff() then refuses, with
#   OS_BATCH_CORRECTED_INPUT, any expected object of that run other than
#   batch_corrected_matrix / sample_table / gene_sets / colour_registry, and
#   os_handoff_assert_uncorrected() lets modules that pick objects themselves
#   (no `expect`) apply the same rule before any inference.
#
# The key "upstream_runs" is read by mcp/server.py into the manifest field of
# the same name (list of run_id strings, oldest first, ending with the run
# that wrote this file). The colour registry (fig_style.R sec 5) travels with
# the chain as a normal object named "colour_registry".

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

OS_HANDOFF_SCHEMA <- "omicstat.handoff.v1"
OS_ECOSYSTEMS <- c("seurat", "bioconductor", "scverse", "neutral")
OS_BATCH_CORRECTED_TYPE <- "batch_corrected_matrix"
OS_BATCH_LINEAGE_ALLOWED <- c("batch_corrected_matrix", "sample_table", "gene_sets", "colour_registry")

.os_sha <- function(path) digest::digest(file = path, algo = "sha256")

# Run identity (S5 R4). Modules name their run basename(outdir); in container
# mode the router mounts the run directory at /ws, so that is "ws" and the
# upstream_runs chain in handoff.json / the MCP manifest breaks. The MCP shell
# passes the run's UUID leaf as OMICSTAT_RUN_ID; when it is set it names the
# run. os_run_id() is the helper; write_handoff() applies it whenever the
# caller passed the directory-derived id (run_id == basename(run_dir)), so an
# explicit id given by a test fixture for another directory is kept.
os_run_id <- function(run_dir) {
  env <- Sys.getenv("OMICSTAT_RUN_ID", "")
  if (!nzchar(env)) return(basename(run_dir))
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", env))
    stop("OS_INVALID_PARAMETER: OMICSTAT_RUN_ID must be 1-128 characters of letters, digits, '.', '_' or '-'.", call. = FALSE)
  env
}

# objects: named list, name -> list(path = <file under run_dir>, type = <class
# string, e.g. "DESeqDataSet", "Seurat", "SingleCellExperiment",
# "feature_table", "colour_registry">).
write_handoff <- function(run_dir, run_id, module, module_version, objects, contract_hash = NA_character_,
                          ecosystem = "neutral", state = list(), upstream_runs = character(0)) {
  if (!ecosystem %in% OS_ECOSYSTEMS) stop(sprintf("OS_INVALID_PARAMETER: ecosystem must be one of %s.", paste(OS_ECOSYSTEMS, collapse = ", ")), call. = FALSE)
  if (identical(as.character(run_id), basename(run_dir))) run_id <- os_run_id(run_dir)
  obj_dir <- file.path(run_dir, "objects")
  dir.create(obj_dir, recursive = TRUE, showWarnings = FALSE)
  root <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  objs <- lapply(names(objects), function(nm) {
    o <- objects[[nm]]
    p <- normalizePath(o$path, winslash = "/", mustWork = TRUE)
    if (!startsWith(p, paste0(root, "/"))) stop(sprintf("OS_INVALID_PARAMETER: handoff object '%s' is outside the run directory.", nm), call. = FALSE)
    list(name = nm, type = o$type, path = substring(p, nchar(root) + 2), sha256 = .os_sha(p))
  })
  names(objs) <- NULL
  objs <- objs[order(vapply(objs, `[[`, "", "name"), method = "radix")]
  st <- if (length(state)) state[order(names(state), method = "radix")] else structure(list(), names = character(0))
  doc <- list(schema = OS_HANDOFF_SCHEMA, run_id = run_id, module = module, module_version = module_version,
              ecosystem = ecosystem, contract_hash = contract_hash, state = st,
              upstream_runs = as.list(c(as.character(upstream_runs), run_id)), objects = objs)
  path <- file.path(obj_dir, "handoff.json")
  js <- jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = I(10))
  con <- file(path, open = "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(js, "\n"))), con)
  invisible(path)
}

# expect: named list, object name -> expected type. front_end_ecosystem: for
# single-cell FRONT-END modules (qc, cluster, integrate, markers, scoring),
# the ecosystem this module belongs to; NULL for ecosystem-neutral modules.
read_handoff <- function(from_run, expect = list(), front_end_ecosystem = NULL, contract_hash = NULL) {
  path <- file.path(from_run, "objects", "handoff.json")
  if (!file.exists(path)) stop(sprintf("OS_HANDOFF_MISSING: no objects/handoff.json under --from-run %s", from_run), call. = FALSE)
  doc <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(doc$schema, OS_HANDOFF_SCHEMA)) stop("OS_HANDOFF_MISMATCH: unknown handoff schema tag.", call. = FALSE)
  eco <- doc$ecosystem
  if (identical(eco, "neutral") && !is.null(doc$state$front_end_ecosystem)) eco <- doc$state$front_end_ecosystem
  if (!is.null(front_end_ecosystem) && !identical(eco, "neutral") && !identical(eco, front_end_ecosystem)) {
    stop(sprintf(paste0("OS_ECOSYSTEM_MIXED: this %s front-end module cannot continue a %s chain (upstream module %s). ",
                        "A chain's front end stays in one ecosystem; start a new chain instead."),
                 front_end_ecosystem, eco, doc$module), call. = FALSE)
  }
  if (!is.null(contract_hash) && !is.na(contract_hash) && !is.null(doc$contract_hash) && !is.na(doc$contract_hash %||% NA) &&
      !identical(doc$contract_hash, contract_hash)) {
    stop("OS_CONTRACT_MISMATCH: the StudyContract differs from the one used upstream; a changed contract starts a new chain.", call. = FALSE)
  }
  if (anyDuplicated(vapply(doc$objects, `[[`, "", "name")))
    stop("OS_HANDOFF_MISMATCH: duplicate object names.", call. = FALSE)
  root <- normalizePath(from_run, winslash = "/", mustWork = TRUE)
  objs <- stats::setNames(doc$objects, vapply(doc$objects, `[[`, "", "name"))
  out <- list()
  for (nm in names(objs)) {
    o <- objs[[nm]]
    if (!is.character(o$path) || length(o$path) != 1L ||
        grepl("^(/|[A-Za-z]:)|(^|/)\\.\\.(/|$)", chartr("\\", "/", o$path)))
      stop("OS_HANDOFF_MISMATCH: object path escapes the run directory.", call. = FALSE)
    p <- file.path(from_run, o$path)
    if (!file.exists(p)) stop(sprintf("OS_HANDOFF_MISMATCH: handoff object '%s' is missing (%s).", nm, o$path), call. = FALSE)
    if (!startsWith(normalizePath(p, winslash = "/", mustWork = TRUE), paste0(root, "/")))
      stop("OS_HANDOFF_MISMATCH: object symlink escapes the run directory.", call. = FALSE)
    if (!identical(.os_sha(p), o$sha256)) stop(sprintf("OS_HANDOFF_MISMATCH: sha256 of '%s' differs from handoff.json (file changed after the upstream run).", nm), call. = FALSE)
    out[[nm]] <- list(path = normalizePath(p, winslash = "/"), type = o$type, sha256 = o$sha256)
  }
  if (isTRUE(doc$state$display_only) && length(expect))
    stop("OS_DISPLAY_ONLY_INPUT: display-curated objects cannot enter proportions, pseudobulk, markers or DE.", call. = FALSE)
  lineage <- isTRUE(doc$state$batch_corrected_lineage)
  for (nm in names(expect)) {
    if (!nm %in% names(out)) stop(sprintf("OS_HANDOFF_MISMATCH: upstream run has no object '%s'.", nm), call. = FALSE)
    if (lineage && !expect[[nm]] %in% OS_BATCH_LINEAGE_ALLOWED) {
      stop(sprintf(paste0("OS_BATCH_CORRECTED_INPUT: upstream run %s (%s) derives from a batch-corrected matrix; its object '%s' ",
                          "is for display only and never enters a differential test or other inference."), doc$run_id, doc$module, nm), call. = FALSE)
    }
    if (identical(out[[nm]]$type, OS_BATCH_CORRECTED_TYPE) && !identical(expect[[nm]], OS_BATCH_CORRECTED_TYPE)) {
      stop(sprintf(paste0("OS_BATCH_CORRECTED_INPUT: object '%s' of upstream run %s (%s) is a batch-corrected matrix; it is for ",
                          "display and scoring only and never enters a differential test. Use the uncorrected data and put ",
                          "the batch (or the surrogate variables) in the design instead."), nm, doc$run_id, doc$module), call. = FALSE)
    }
    if (!identical(out[[nm]]$type, expect[[nm]])) {
      stop(sprintf("OS_HANDOFF_MISMATCH: object '%s' has type '%s', expected '%s'.", nm, out[[nm]]$type, expect[[nm]]), call. = FALSE)
    }
  }
  list(run_id = doc$run_id, module = doc$module, module_version = doc$module_version, ecosystem = doc$ecosystem,
       contract_hash = doc$contract_hash, state = doc$state, upstream_runs = unlist(doc$upstream_runs), objects = out,
       batch_corrected_lineage = lineage)
}

# For modules that choose among upstream objects themselves: refuse a
# batch-corrected object, or any data object of a corrected lineage, before
# it can enter inference (S1 sva-batch P-1; SUITE rule 7; S4 contract c).
os_handoff_assert_uncorrected <- function(upstream, name, purpose = "inference") {
  if (isTRUE(upstream$state$display_only))
    stop("OS_DISPLAY_ONLY_INPUT: display-curated objects cannot enter proportions, pseudobulk, markers or DE.", call. = FALSE)
  o <- upstream$objects[[name]]
  if (is.null(o)) stop(sprintf("OS_HANDOFF_MISMATCH: upstream run has no object '%s'.", name), call. = FALSE)
  if (identical(o$type, OS_BATCH_CORRECTED_TYPE) || isTRUE(upstream$state$batch_corrected_lineage)) {
    stop(sprintf(paste0("OS_BATCH_CORRECTED_INPUT: object '%s' of upstream run %s (%s) is batch-corrected or derived from a ",
                        "batch-corrected matrix; it is for display and scoring only and is not used for %s."),
                 name, upstream$run_id, upstream$module, purpose), call. = FALSE)
  }
  os_handoff_assert_inference_ready(upstream)
  invisible(TRUE)
}

# GSVA scoring is available; its downstream inferential model remains owner-pending.
os_handoff_assert_inference_ready <- function(upstream) {
  if (!is.null(upstream) && (identical(upstream$module, "gsva-score") || isTRUE(upstream$state$score_inference_pending)))
    stop("OS_OWNER_DECISION_PENDING: inference on GSVA scores awaits the owner decision on the limma entry and trend/robust settings; scores are for descriptive use.", call. = FALSE)
  invisible(TRUE)
}
