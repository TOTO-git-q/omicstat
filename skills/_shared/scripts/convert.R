# convert.R -- explicit single-cell object conversion for the ecosystem-neutral
# back-end modules (ENGINEERING_PLAN 1.3 "single-cell ecosystem rules", 10.3).
# ASCII only on purpose (docs/CONVENTIONS.md sec 2).
#
# One entry point:
#
#   res <- os_sc_convert(x, to = "SingleCellExperiment", consumer = "back_end",
#                        layers = c(counts = "counts", logcounts = "data"),
#                        cluster_col = "seurat_clusters", source_assay = "RNA")
#   sce  <- res$object          # (for to = "AnnData": the path of the .h5ad written)
#   step <- res$step            # provenance step; pass all steps of a run as
#                               # os_write_provenance(extra = list(conversions = list(step, ...)))
#
# x is an in-memory Seurat or SingleCellExperiment object, a handoff entry as
# returned in read_handoff()$objects (list(path, type, sha256); type Seurat,
# SingleCellExperiment or AnnData), or a path to a .rds (Seurat / SCE) or .h5ad
# (AnnData) file. to is "Seurat", "SingleCellExperiment" or "AnnData".
#
# Rules implemented here (all mandatory, none has a default):
#   * the caller NAMES the matrices: `layers` maps a role to the source matrix.
#     Roles: counts (raw integer counts) and logcounts (normalised, log scale).
#     Source names: a Seurat layer of `source_assay` ("counts", "data"), an SCE
#     assay name, or for AnnData "X" (the main matrix) / a layers key.
#     Target names are fixed by role: SCE assays counts / logcounts; Seurat
#     layers counts / data of `target_assay`; AnnData X = the role named by
#     `x_role`, every other role in layers[<role>].
#   * the counts role must hold non-negative integers; a logcounts role that
#     equals the counts role, or is integer-valued with values > 30, is raw
#     counts under the wrong name (OS_CONVERT_LAYER_ROLE).
#   * carried as they are: cell ids and order, feature ids and order, every
#     cell-metadata column (type, values, factor levels and their order, unused
#     levels, ordered flag), every feature-metadata column, every embedding
#     (reduction name, coordinates, column names). Nothing is re-clustered,
#     re-normalised or re-reduced; no cell or feature is filtered.
#   * not carried (listed in step$not_carried): other layers / assays,
#     scale.data, graphs, neighbours, PCA loadings and stdev, commands, images,
#     SCE metadata / altExps / pairs, AnnData uns / varm / obsp / varp / raw,
#     and (AnnData only) attributes of an embedding matrix other than its
#     coordinates and column names. A character column written to AnnData
#     comes back as character (see OS_SC_UNS_KEY below).
#   * after the conversion the target is read back through the same extractor
#     and its content fingerprint (cells, features, each matrix, each metadata
#     column, each embedding, the cluster labels) must equal the source's;
#     for AnnData the written file itself is read back. Any difference is
#     OS_CONVERT_MISMATCH naming the component.
#   * a conversion only ever feeds an ecosystem-neutral back-end module:
#     consumer = "front_end" with a change of object type is OS_ECOSYSTEM_MIXED
#     (a chain's front end stays in one ecosystem; ENGINEERING_PLAN 1.3, 10.3).
#   * AnnData goes through zellkonverter's python reader/writer in the basilisk
#     environment prebuilt in the image (anndata OS_SC_ANNDATA_VERSION). The
#     runtime never downloads it: if the environment is not present the call
#     stops with OS_ENV_MISSING before basilisk is touched. zellkonverter's R
#     reader is not offered: it drops every obsm (embedding) entry.
#
# Typed errors:
#   OS_MISSING_PARAMETER     a mandatory argument is absent
#   OS_INVALID_PARAMETER     unknown role / target type / consumer, bad x_role
#   OS_INVALID_INPUT         not a single-cell object, NA / empty ids, NA labels
#   OS_MISSING_COLUMN        cluster_col is not a cell-metadata column
#   OS_HANDOFF_MISMATCH      handoff entry type or sha256 differs from the file
#   OS_CONVERT_LAYER_MISSING the named assay / layer does not exist (or is split)
#   OS_CONVERT_LAYER_ROLE    the named matrix does not hold what its role says
#   OS_CONVERT_UNSUPPORTED   the content cannot be represented faithfully in the
#                            target (e.g. "_" in feature names for Seurat, list
#                            columns, layers over different cells / features)
#   OS_CONVERT_MISMATCH      post-conversion check failed (component named)
#   OS_ECOSYSTEM_MIXED       conversion requested for a front-end module
#   OS_ENV_MISSING           the prebuilt anndata environment is not reachable
#
# Other helpers:
#   os_sc_ecosystem(type)             Seurat -> seurat, SingleCellExperiment ->
#                                     bioconductor, AnnData -> scverse
#   os_sc_chain_state(h)              state entry a neutral module writes into
#                                     its handoff so a later front-end module
#                                     still sees the chain's front-end ecosystem
#   os_sc_anndata_env_path()          where the prebuilt environment must be
#   os_sc_parts(), os_sc_fingerprint(), os_sc_verify()   the check machinery
#                                     (exported for tests)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

OS_SC_TYPES <- c(Seurat = "seurat", SingleCellExperiment = "bioconductor", AnnData = "scverse")
OS_SC_ROLES <- c("counts", "logcounts")
OS_SC_SEURAT_LAYER <- c(counts = "counts", logcounts = "data")
OS_SC_ANNDATA_VERSION <- "0.12.3"
OS_SC_CONSUMERS <- c("back_end", "front_end")

.os_sc_stop <- function(code, fmt, ...) stop(sprintf(paste0(code, ": ", fmt), ...), call. = FALSE)
.os_sc_sha <- function(x) digest::digest(x, algo = "sha256")
.os_sc_file_sha <- function(p) digest::digest(file = p, algo = "sha256")

os_sc_ecosystem <- function(type) {
  if (!type %in% names(OS_SC_TYPES)) .os_sc_stop("OS_INVALID_PARAMETER", "object type must be one of %s, got '%s'", paste(names(OS_SC_TYPES), collapse = ", "), type)
  unname(OS_SC_TYPES[[type]])
}

# The chain's front-end ecosystem as seen from a read_handoff() result: the
# upstream ecosystem, or -- when the upstream module was neutral -- the one it
# recorded in state$front_end_ecosystem. A neutral module passes the result of
# os_sc_chain_state(h) into write_handoff(state = c(<its state>, ...)).
os_sc_chain_state <- function(h) {
  eco <- h$ecosystem %||% "neutral"
  if (identical(eco, "neutral")) eco <- h$state$front_end_ecosystem %||% "neutral"
  list(front_end_ecosystem = eco)
}

# ---------------------------------------------------------------------------
# anndata environment (prebuilt by the image; never downloaded at run time)
# ---------------------------------------------------------------------------
os_sc_anndata_env_path <- function() {
  base <- Sys.getenv("BASILISK_EXTERNAL_DIR", NA)
  if (is.na(base)) base <- tools::R_user_dir("basilisk", "cache")
  file.path(path.expand(base), as.character(utils::packageVersion("basilisk")), "zellkonverter",
            as.character(utils::packageVersion("zellkonverter")), paste0("zellkonverterAnnDataEnv-", OS_SC_ANNDATA_VERSION))
}

.os_sc_require_anndata_env <- function() {
  for (p in c("zellkonverter", "basilisk")) {
    if (!requireNamespace(p, quietly = TRUE)) .os_sc_stop("OS_ENV_MISSING", "R package %s is not installed; AnnData (.h5ad) conversion needs the omicstat-r image.", p)
  }
  if (identical(Sys.getenv("BASILISK_USE_SYSTEM_DIR", NA), "1")) return(invisible(NA_character_))
  p <- os_sc_anndata_env_path()
  if (!file.exists(file.path(p, "bin", "python"))) {
    .os_sc_stop("OS_ENV_MISSING", paste0(
      "the prebuilt anndata %s environment is not reachable at %s (basilisk would download it; runs stay offline). ",
      "The image builds it under the build user's cache: run as that user, or set BASILISK_EXTERNAL_DIR to a readable ",
      "copy of the prebuilt basilisk directory. Seurat <-> SingleCellExperiment conversion does not need it."),
      OS_SC_ANNDATA_VERSION, p)
  }
  invisible(p)
}

# ---------------------------------------------------------------------------
# Source resolution
# ---------------------------------------------------------------------------
.os_sc_type_of <- function(obj) {
  if (methods::is(obj, "Seurat")) return("Seurat")
  if (methods::is(obj, "SingleCellExperiment")) return("SingleCellExperiment")
  NA_character_
}

.os_sc_source <- function(x) {
  if (!is.na(.os_sc_type_of(x))) return(list(type = .os_sc_type_of(x), object = x, path = NA_character_, sha256 = .os_sc_sha(x)))
  entry <- NULL
  if (is.list(x) && !is.null(x$path) && !is.null(x$type)) entry <- x
  else if (is.character(x) && length(x) == 1 && !is.na(x)) {
    ext <- tolower(tools::file_ext(x))
    if (!ext %in% c("rds", "h5ad")) .os_sc_stop("OS_INVALID_INPUT", "expected a .rds (Seurat / SingleCellExperiment) or .h5ad (AnnData) file, got '%s'", x)
    entry <- list(path = x, type = if (ext == "h5ad") "AnnData" else NA_character_, sha256 = NULL)
  } else {
    .os_sc_stop("OS_INVALID_INPUT", "x must be a Seurat or SingleCellExperiment object, a handoff entry or a .rds / .h5ad path (got class %s)", paste(class(x), collapse = "/"))
  }
  if (!file.exists(entry$path)) .os_sc_stop("OS_INVALID_INPUT", "file not found: %s", entry$path)
  sha <- .os_sc_file_sha(entry$path)
  if (!is.null(entry$sha256) && !identical(sha, entry$sha256)) {
    .os_sc_stop("OS_HANDOFF_MISMATCH", "sha256 of %s differs from the handoff entry (file changed after the upstream run).", basename(entry$path))
  }
  if (identical(entry$type, "AnnData")) return(list(type = "AnnData", object = NULL, path = normalizePath(entry$path, winslash = "/"), sha256 = sha))
  obj <- readRDS(entry$path)
  got <- .os_sc_type_of(obj)
  if (is.na(got)) .os_sc_stop("OS_INVALID_INPUT", "%s holds a %s, not a Seurat or SingleCellExperiment object", basename(entry$path), paste(class(obj), collapse = "/"))
  if (!is.na(entry$type) && !identical(got, entry$type)) .os_sc_stop("OS_HANDOFF_MISMATCH", "handoff entry says '%s' but %s holds a %s", entry$type, basename(entry$path), got)
  list(type = got, object = obj, path = normalizePath(entry$path, winslash = "/"), sha256 = sha)
}

# Scientific chain state is retained even when package-specific metadata is dropped.
.os_sc_embedded_state <- function(src) {
  state <- if (src$type == "Seurat") src$object@misc$omicstat_state else if (src$type == "SingleCellExperiment") S4Vectors::metadata(src$object)$omicstat else {
    .os_sc_require_anndata_env()
    listing <- rhdf5::h5ls(src$path, recursive = TRUE)
    key <- "omicstat_chain_state_json"
    if (any(listing$group == "/uns" & listing$name == key))
      jsonlite::fromJSON(rhdf5::h5read(src$path, paste0("/uns/", key)), simplifyVector = FALSE) else NULL
  }
  if (is.null(state)) return(list())
  if (!is.list(state)) .os_sc_stop("OS_HANDOFF_MISMATCH", "embedded single-cell chain state must be an object")
  state
}

# ---------------------------------------------------------------------------
# Parts: the canonical content of a single-cell object
# ---------------------------------------------------------------------------
# list(cells, features, mats = list(<role> = matrix), coldata = data.frame,
#      rowdata = data.frame, reductions = list(<name> = list(emb, colnames)),
#      source_names = c(<role> = <source matrix name>), not_carried = chr)

.os_sc_check_df <- function(cols, what) {
  ok <- vapply(cols, function(v) is.null(dim(v)) && is.null(ncol(v)) && (is.logical(v) || is.integer(v) || is.double(v) || is.character(v) || is.factor(v)), logical(1))
  if (!all(ok)) .os_sc_stop("OS_CONVERT_UNSUPPORTED", "%s column(s) %s are not plain vectors (logical / integer / double / character / factor); they cannot be carried as they are.",
                            what, paste(names(cols)[!ok], collapse = ", "))
  invisible(TRUE)
}

.os_sc_df <- function(x, ids, what) {
  if (ncol(x)) .os_sc_check_df(as.list(x), what)
  df <- as.data.frame(x, optional = TRUE, stringsAsFactors = FALSE)
  rownames(df) <- ids
  df
}

.os_sc_check_ids <- function(cells, features) {
  for (what in c("cell", "feature")) {
    ids <- if (what == "cell") cells else features
    if (is.null(ids) || anyNA(ids) || any(!nzchar(ids))) .os_sc_stop("OS_INVALID_INPUT", "the object has missing or empty %s ids", what)
    if (anyDuplicated(ids)) .os_sc_stop("OS_INVALID_INPUT", "duplicated %s ids: %s", what, paste(utils::head(unique(ids[duplicated(ids)]), 5), collapse = ", "))
  }
  invisible(TRUE)
}

.os_sc_roles <- function(layers) {
  if (missing(layers) || is.null(layers) || !length(layers)) {
    .os_sc_stop("OS_MISSING_PARAMETER", "layers must name the source matrix of each role, e.g. c(counts = \"counts\", logcounts = \"data\"); roles: %s", paste(OS_SC_ROLES, collapse = ", "))
  }
  nm <- names(layers)
  if (!is.character(layers) || is.null(nm) || any(!nzchar(nm)) || anyNA(layers) || any(!nzchar(layers))) {
    .os_sc_stop("OS_INVALID_PARAMETER", "layers must be a named character vector role = source matrix name")
  }
  bad <- setdiff(nm, OS_SC_ROLES)
  if (length(bad)) .os_sc_stop("OS_INVALID_PARAMETER", "unknown role(s) %s in layers; roles are %s", paste(bad, collapse = ", "), paste(OS_SC_ROLES, collapse = ", "))
  if (anyDuplicated(nm)) .os_sc_stop("OS_INVALID_PARAMETER", "role(s) named twice in layers: %s", paste(unique(nm[duplicated(nm)]), collapse = ", "))
  layers[intersect(OS_SC_ROLES, nm)]
}

.os_sc_parts_seurat <- function(obj, assay, layers) {
  if (is.null(assay) || !nzchar(assay)) .os_sc_stop("OS_MISSING_PARAMETER", "source_assay must name the Seurat assay to convert (assays: %s)", paste(SeuratObject::Assays(obj), collapse = ", "))
  if (!assay %in% SeuratObject::Assays(obj)) .os_sc_stop("OS_CONVERT_LAYER_MISSING", "Seurat object has no assay '%s' (assays: %s)", assay, paste(SeuratObject::Assays(obj), collapse = ", "))
  have <- SeuratObject::Layers(obj[[assay]])
  cells <- colnames(obj)
  mats <- list()
  for (role in names(layers)) {
    ln <- layers[[role]]
    if (!ln %in% have) {
      split <- have[startsWith(have, paste0(ln, "."))]
      .os_sc_stop("OS_CONVERT_LAYER_MISSING", "assay '%s' has no layer '%s' for role %s (layers: %s)%s", assay, ln, role, paste(have, collapse = ", "),
                  if (length(split)) "; the layer is split by sample -- join it (SeuratObject::JoinLayers) upstream" else "")
    }
    m <- SeuratObject::LayerData(obj, assay = assay, layer = ln)
    if (!identical(colnames(m), cells)) .os_sc_stop("OS_CONVERT_UNSUPPORTED", "layer '%s' does not cover every cell of the object in object order", ln)
    mats[[role]] <- m
  }
  features <- rownames(mats[[1]])
  .os_sc_check_ids(cells, features)
  for (role in names(mats)) if (!identical(rownames(mats[[role]]), features)) .os_sc_stop("OS_CONVERT_UNSUPPORTED", "layers %s cover different features; a single-cell object needs one feature set", paste(layers, collapse = ", "))
  fm <- obj[[assay]][[]]
  fm <- fm[match(features, rownames(fm)), , drop = FALSE]
  reds <- list()
  for (r in SeuratObject::Reductions(obj)) {
    dr <- obj[[r]]
    emb <- SeuratObject::Embeddings(dr)
    if (!identical(rownames(emb), cells)) .os_sc_stop("OS_CONVERT_UNSUPPORTED", "reduction '%s' does not cover every cell in object order", r)
    orig <- SeuratObject::Misc(dr, slot = "os_sc_colnames")
    cn <- if (is.null(orig)) colnames(emb) else if (length(orig)) as.character(orig) else NULL
    reds[[r]] <- list(emb = emb, colnames = cn)
  }
  nc <- c(sprintf("layer %s/%s", assay, setdiff(have, layers)),
          sprintf("assay %s", setdiff(SeuratObject::Assays(obj), assay)),
          sprintf("graph %s", SeuratObject::Graphs(obj)),
          sprintf("neighbor %s", SeuratObject::Neighbors(obj)),
          sprintf("image %s", SeuratObject::Images(obj)),
          if (length(reds)) sprintf("loadings/stdev of reduction %s", names(reds)),
          if (length(SeuratObject::Command(obj))) "command log",
          "active identity (target idents are set from cluster_col)")
  list(cells = cells, features = features, mats = mats, coldata = .os_sc_df(obj[[]], cells, "cell metadata"),
       rowdata = .os_sc_df(fm, features, "feature metadata"), reductions = reds,
       source_names = layers, not_carried = nc)
}

.os_sc_parts_sce <- function(sce, layers, what = "SingleCellExperiment") {
  have <- SummarizedExperiment::assayNames(sce)
  cells <- colnames(sce); features <- rownames(sce)
  .os_sc_check_ids(cells, features)
  mats <- list()
  for (role in names(layers)) {
    ln <- layers[[role]]
    if (!ln %in% have) .os_sc_stop("OS_CONVERT_LAYER_MISSING", "%s has no %s '%s' for role %s (available: %s)", what,
                                   if (what == "AnnData") "matrix" else "assay", ln, role, paste(have, collapse = ", "))
    m <- SummarizedExperiment::assay(sce, ln, withDimnames = TRUE)
    mats[[role]] <- m
  }
  reds <- list()
  for (r in SingleCellExperiment::reducedDimNames(sce)) {
    emb <- SingleCellExperiment::reducedDim(sce, r, withDimnames = TRUE)
    if (!is.matrix(emb)) emb <- as.matrix(emb)
    reds[[r]] <- list(emb = emb, colnames = colnames(emb))
  }
  md <- names(S4Vectors::metadata(sce))
  nc <- c(sprintf("%s %s", if (what == "AnnData") "matrix" else "assay", setdiff(have, layers)),
          sprintf("altExp %s", SingleCellExperiment::altExpNames(sce)),
          if (length(md)) sprintf("metadata %s", md),
          sprintf("colPair %s", SingleCellExperiment::colPairNames(sce)),
          sprintf("rowPair %s", SingleCellExperiment::rowPairNames(sce)))
  list(cells = cells, features = features, mats = mats,
       coldata = .os_sc_df(SummarizedExperiment::colData(sce), cells, "cell metadata"),
       rowdata = .os_sc_df(SummarizedExperiment::rowData(sce), features, "feature metadata"),
       reductions = reds, source_names = layers, not_carried = nc)
}

# anndata writes every string column of obs / var as a categorical. So that a
# character column comes back as character (and not as a factor), the writer
# records the character columns in uns["omicstat_convert"] (a JSON string) and
# the reader turns exactly those columns back into character. Files written
# elsewhere carry no marker: their categoricals arrive as factors, as they are.
OS_SC_UNS_KEY <- "omicstat_convert"

.os_sc_read_h5ad <- function(path) {
  .os_sc_require_anndata_env()
  ls <- rhdf5::h5ls(path, recursive = 2L)
  has <- any(ls$group == "/uns" & ls$name == OS_SC_UNS_KEY)
  sce <- zellkonverter::readH5AD(file = path, X_name = "X", use_hdf5 = FALSE, reader = "python", version = OS_SC_ANNDATA_VERSION,
                                 verbose = FALSE, layers = TRUE, uns = if (has) OS_SC_UNS_KEY else FALSE, var = TRUE, obs = TRUE,
                                 varm = FALSE, obsm = TRUE, varp = FALSE, obsp = FALSE, raw = FALSE)
  if (has) {
    mk <- jsonlite::fromJSON(S4Vectors::metadata(sce)[[OS_SC_UNS_KEY]], simplifyVector = TRUE)
    for (k in as.character(unlist(mk$obs_character))) {
      if (k %in% names(SummarizedExperiment::colData(sce))) SummarizedExperiment::colData(sce)[[k]] <- as.character(SummarizedExperiment::colData(sce)[[k]])
    }
    for (k in as.character(unlist(mk$var_character))) {
      if (k %in% names(SummarizedExperiment::rowData(sce))) SummarizedExperiment::rowData(sce)[[k]] <- as.character(SummarizedExperiment::rowData(sce)[[k]])
    }
    restore_single <- function(df, specs) {
      for (k in names(specs)) {
        df[[k]] <- factor(as.character(df[[k]]),
                          levels = as.character(unlist(specs[[k]]$levels)),
                          ordered = isTRUE(specs[[k]]$ordered))
      }
      df
    }
    SummarizedExperiment::colData(sce) <- restore_single(SummarizedExperiment::colData(sce), mk$obs_single_factors)
    SummarizedExperiment::rowData(sce) <- restore_single(SummarizedExperiment::rowData(sce), mk$var_single_factors)
    if (!is.null(mk$reduction_order)) {
      ord <- as.character(unlist(mk$reduction_order))
      if (!setequal(ord, SingleCellExperiment::reducedDimNames(sce)))
        .os_sc_stop("OS_CONVERT_MISMATCH", "stored embedding names differ from AnnData obsm")
      SingleCellExperiment::reducedDims(sce) <- SingleCellExperiment::reducedDims(sce)[ord]
    }
  }
  S4Vectors::metadata(sce) <- list()
  sce
}

.os_sc_parts_h5ad <- function(path, layers) {
  sce <- .os_sc_read_h5ad(path)
  p <- .os_sc_parts_sce(sce, layers, what = "AnnData")
  p$not_carried <- c(p$not_carried, "AnnData uns / varm / obsp / varp / raw")
  p
}

# Validate the parts against the roles and cluster column (source side).
.os_sc_check_parts <- function(p, cluster_col) {
  if (!is.null(p$mats$counts)) {
    x <- .os_sc_canon(p$mats$counts)@x
    if (any(x < 0) || any(x != round(x))) .os_sc_stop("OS_CONVERT_LAYER_ROLE", "matrix '%s' named as the counts role holds %s values; raw counts are non-negative integers (name the raw-count layer, or use role logcounts)",
                                                     p$source_names[["counts"]], if (any(x < 0)) "negative" else "non-integer")
  }
  if (!is.null(p$mats$logcounts)) {
    lc <- .os_sc_canon(p$mats$logcounts)
    if (!is.null(p$mats$counts) && identical(.os_sc_mat_sig(lc), .os_sc_mat_sig(.os_sc_canon(p$mats$counts)))) {
      .os_sc_stop("OS_CONVERT_LAYER_ROLE", "matrix '%s' named as the logcounts role is identical to the counts matrix '%s' (not normalised)", p$source_names[["logcounts"]], p$source_names[["counts"]])
    }
    if (length(lc@x) && all(lc@x == round(lc@x)) && max(lc@x) > 30) {
      .os_sc_stop("OS_CONVERT_LAYER_ROLE", "matrix '%s' named as the logcounts role is integer-valued with values up to %s: these are raw counts, not log-normalised values", p$source_names[["logcounts"]], format(max(lc@x)))
    }
  }
  if (missing(cluster_col) || is.null(cluster_col) || !nzchar(cluster_col)) .os_sc_stop("OS_MISSING_PARAMETER", "cluster_col must name the cell-metadata column holding the cluster labels to verify")
  if (!cluster_col %in% names(p$coldata)) .os_sc_stop("OS_MISSING_COLUMN", "cell metadata has no column '%s' (columns: %s)", cluster_col, paste(names(p$coldata), collapse = ", "))
  lab <- p$coldata[[cluster_col]]
  if (!(is.factor(lab) || is.character(lab))) .os_sc_stop("OS_INVALID_INPUT", "cluster_col '%s' is %s; cluster labels must be a factor or character column", cluster_col, class(lab)[1])
  if (anyNA(lab)) .os_sc_stop("OS_INVALID_INPUT", "cluster_col '%s' has %d missing label(s)", cluster_col, sum(is.na(lab)))
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Fingerprint and verification
# ---------------------------------------------------------------------------
.os_sc_canon <- function(m) {
  if (methods::is(m, "DelayedArray")) m <- methods::as(m, "dgCMatrix")
  if (!methods::is(m, "dgCMatrix")) m <- methods::as(methods::as(methods::as(m, "CsparseMatrix"), "generalMatrix"), "dMatrix")
  Matrix::drop0(m)
}
.os_sc_mat_sig <- function(m) list(dim = dim(m), i = m@i, p = m@p, x = m@x)
.os_sc_col_sig <- function(v) list(class = class(v), levels = if (is.factor(v)) levels(v) else NULL,
                                   values = if (is.factor(v)) as.integer(v) else unname(as.vector(v)))
# Coordinates and column names only: other attributes of an embedding matrix
# (e.g. uwot's "scaled:center") are kept between Seurat and SCE but are not
# part of the coordinates, and AnnData obsm cannot hold them.
.os_sc_emb_sig <- function(r) list(values = matrix(as.double(r$emb), nrow = nrow(r$emb)), colnames = r$colnames)

os_sc_fingerprint <- function(p, cluster_col) {
  lab <- p$coldata[[cluster_col]]
  list(n_cells = length(p$cells), n_features = length(p$features),
       cell_ids = .os_sc_sha(p$cells), feature_ids = .os_sc_sha(p$features),
       matrices = lapply(p$mats, function(m) .os_sc_sha(.os_sc_mat_sig(.os_sc_canon(m)))),
       cell_metadata_columns = names(p$coldata),
       cell_metadata = lapply(p$coldata, function(v) .os_sc_sha(.os_sc_col_sig(v))),
       feature_metadata_columns = names(p$rowdata),
       feature_metadata = lapply(p$rowdata, function(v) .os_sc_sha(.os_sc_col_sig(v))),
       reductions = lapply(p$reductions, function(r) .os_sc_sha(.os_sc_emb_sig(r))),
       cluster_labels = list(column = cluster_col, n_levels = length(unique(lab)),
                             levels = if (is.factor(lab)) levels(lab) else sort(unique(lab), method = "radix"),
                             sha256 = .os_sc_sha(.os_sc_col_sig(lab))))
}

# Compare two fingerprints component by component; stops with
# OS_CONVERT_MISMATCH listing every differing component.
os_sc_verify <- function(before, after) {
  bad <- character(0)
  if (!identical(before$n_cells, after$n_cells)) bad <- c(bad, sprintf("cell count %d -> %d", before$n_cells, after$n_cells))
  if (!identical(before$n_features, after$n_features)) bad <- c(bad, sprintf("gene count %d -> %d", before$n_features, after$n_features))
  if (!identical(before$cell_ids, after$cell_ids)) bad <- c(bad, "cell ids / order")
  if (!identical(before$feature_ids, after$feature_ids)) bad <- c(bad, "feature ids / order")
  if (!identical(before$cluster_labels, after$cluster_labels)) bad <- c(bad, sprintf("cluster labels (%s)", before$cluster_labels$column))
  cmp <- function(a, b, what) {
    out <- character(0)
    if (!identical(names(a), names(b))) out <- c(out, sprintf("%s names/order [%s] -> [%s]", what, paste(names(a), collapse = ","), paste(names(b), collapse = ",")))
    for (k in intersect(names(a), names(b))) if (!identical(a[[k]], b[[k]])) out <- c(out, sprintf("%s '%s'", what, k))
    out
  }
  bad <- c(bad, cmp(before$matrices, after$matrices, "matrix"),
           cmp(before$cell_metadata, after$cell_metadata, "cell metadata column"),
           cmp(before$feature_metadata, after$feature_metadata, "feature metadata column"),
           cmp(before$reductions, after$reductions, "embedding"))
  if (length(bad)) .os_sc_stop("OS_CONVERT_MISMATCH", "the converted object differs from its source in: %s", paste(unique(bad), collapse = "; "))
  invisible(TRUE)
}

os_sc_parts <- function(obj_or_path, type, layers, assay = NULL) {
  switch(type,
         Seurat = .os_sc_parts_seurat(obj_or_path, assay, layers),
         SingleCellExperiment = .os_sc_parts_sce(obj_or_path, layers),
         AnnData = .os_sc_parts_h5ad(obj_or_path, layers),
         .os_sc_stop("OS_INVALID_PARAMETER", "unknown object type '%s'", type))
}

# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------
.os_sc_build_sce <- function(p) {
  cd <- S4Vectors::DataFrame(p$coldata, check.names = FALSE)
  rd <- if (ncol(p$rowdata)) S4Vectors::DataFrame(p$rowdata, check.names = FALSE) else S4Vectors::make_zero_col_DFrame(length(p$features))
  rownames(rd) <- p$features
  sce <- SingleCellExperiment::SingleCellExperiment(assays = p$mats, colData = cd, rowData = rd)
  for (r in names(p$reductions)) {
    e <- p$reductions[[r]]$emb
    dimnames(e) <- list(p$cells, p$reductions[[r]]$colnames)
    SingleCellExperiment::reducedDim(sce, r, withDimnames = TRUE) <- e
  }
  sce
}

.os_sc_seurat_key <- function(name, cn) {
  if (length(cn)) {
    pre <- unique(sub("[0-9]+$", "", cn))
    if (length(pre) == 1 && grepl("^[A-Za-z][A-Za-z0-9]*_$", pre) && identical(cn, paste0(pre, seq_along(cn)))) return(list(key = pre, keep = FALSE))
  }
  k <- gsub("[^A-Za-z0-9]", "", name)
  if (!nzchar(k) || !grepl("^[A-Za-z]", k)) k <- paste0("R", k)
  list(key = paste0(k, "_"), keep = TRUE)
}

.os_sc_build_seurat <- function(p, target_assay, cluster_col) {
  if (is.null(target_assay) || !nzchar(target_assay)) .os_sc_stop("OS_MISSING_PARAMETER", "target_assay must name the Seurat assay to create (e.g. \"RNA\")")
  badf <- p$features[grepl("[_|]", p$features)]
  if (length(badf)) .os_sc_stop("OS_CONVERT_UNSUPPORTED", "%d feature name(s) contain '_' or '|' (e.g. %s); Seurat would rename them, so the genes could not be carried as they are. Rename them upstream.",
                                length(badf), paste(utils::head(badf, 3), collapse = ", "))
  a5 <- SeuratObject::CreateAssay5Object(counts = p$mats$counts, data = p$mats$logcounts, min.cells = 0, min.features = 0)
  if (ncol(p$rowdata)) a5 <- SeuratObject::AddMetaData(object = a5, metadata = p$rowdata)
  # With a logcounts-only assay CreateSeuratObject warns that it finds no
  # counts layer for its nCount/nFeature columns; those columns are discarded
  # (meta.data is replaced by the source metadata below), so exactly these
  # two warnings are muffled in that case and nothing else.
  obj <- withCallingHandlers(
    SeuratObject::CreateSeuratObject(counts = a5, assay = target_assay, project = "omicstat"),
    warning = function(w) {
      if (is.null(p$mats$counts) && grepl("^(No layers found matching search pattern provided|Cannot find the layer\\(s\\) specified)", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    })
  md <- p$coldata
  methods::slot(obj, "meta.data") <- md
  for (r in names(p$reductions)) {
    e <- p$reductions[[r]]$emb
    cn <- p$reductions[[r]]$colnames
    k <- .os_sc_seurat_key(r, cn)
    storage.mode(e) <- "double"
    dimnames(e) <- list(p$cells, paste0(k$key, seq_len(ncol(e))))
    misc <- if (k$keep) list(os_sc_colnames = if (is.null(cn)) character(0) else cn) else list()
    obj[[r]] <- SeuratObject::CreateDimReducObject(embeddings = e, key = k$key, assay = target_assay, global = FALSE, misc = misc)
  }
  obj <- SeuratObject::SetIdent(obj, value = cluster_col)
  methods::validObject(obj)
  obj
}

.os_sc_write_h5ad <- function(sce, file, x_role) {
  .os_sc_require_anndata_env()
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(file)) unlink(file)
  chr <- function(df) names(df)[vapply(as.list(df), is.character, logical(1))]
  original_features <- nrow(sce); original_cells <- ncol(sce)
  # The same bridge scalarizes singleton obs/var names. Pad only for writing,
  # then select the original axes with native AnnData before returning a file.
  if (original_features == 1L) {
    sce <- sce[c(1L, 1L), ]
    rownames(sce) <- make.unique(c(rownames(sce)[1], rownames(sce)[1]))
  }
  if (original_cells == 1L) {
    sce <- sce[, c(1L, 1L)]
    colnames(sce) <- make.unique(c(colnames(sce)[1], colnames(sce)[1]))
  }
  mk <- list(schema = "omicstat.convert.v1", obs_character = I(chr(SummarizedExperiment::colData(sce))),
             var_character = I(chr(SummarizedExperiment::rowData(sce))),
             reduction_order = I(SingleCellExperiment::reducedDimNames(sce)))
  # zellkonverter's pandas bridge scalarizes a singleton category list. A
  # temporary unused level avoids that bridge bug; native pandas removes it
  # before the final file is returned, retaining the original category list.
  singles <- function(df) {
    specs <- list()
    for (k in names(df)) if (is.character(df[[k]]) && all(is.na(df[[k]]))) {
      # HDF5 cannot encode pandas object columns containing only None. Native
      # empty categoricals encode missing strings; the existing character
      # marker restores their R type when read.
      specs[[k]] <- list(levels = character(), ordered = FALSE, character = TRUE)
      df[[k]] <- factor(df[[k]], levels = c("..omicstat_missing_1..", "..omicstat_missing_2.."))
    }
    for (k in names(df)) if (is.factor(df[[k]]) && length(levels(df[[k]])) == 1L) {
      specs[[k]] <- list(levels = I(levels(df[[k]])), ordered = is.ordered(df[[k]]))
      extra <- "..omicstat_transport_unused.."
      while (extra %in% levels(df[[k]])) extra <- paste0(extra, "_")
      levels(df[[k]]) <- c(levels(df[[k]]), extra)
    }
    list(df = df, specs = specs)
  }
  obs <- singles(SummarizedExperiment::colData(sce)); var <- singles(SummarizedExperiment::rowData(sce))
  keep_factors <- function(specs) Filter(function(s) !isTRUE(s$character), specs)
  mk$obs_single_factors <- keep_factors(obs$specs); mk$var_single_factors <- keep_factors(var$specs)
  SummarizedExperiment::colData(sce) <- obs$df; SummarizedExperiment::rowData(sce) <- var$df
  chain_state <- S4Vectors::metadata(sce)$omicstat
  S4Vectors::metadata(sce) <- stats::setNames(list(as.character(jsonlite::toJSON(mk, auto_unbox = TRUE))), OS_SC_UNS_KEY)
  if (length(chain_state)) S4Vectors::metadata(sce)$omicstat_chain_state_json <- as.character(jsonlite::toJSON(chain_state, auto_unbox = TRUE, null = "null"))
  zellkonverter::writeH5AD(sce = sce, file = file, X_name = x_role, skip_assays = FALSE, compression = "none",
                           version = OS_SC_ANNDATA_VERSION, verbose = FALSE, assays = TRUE, colData = TRUE, rowData = TRUE,
                           varm = FALSE, reducedDims = TRUE, metadata = names(S4Vectors::metadata(sce)), colPairs = FALSE, rowPairs = FALSE)
  if (length(obs$specs) || length(var$specs) || original_features == 1L || original_cells == 1L) {
    basilisk::basiliskRun(env = zellkonverter:::zellkonverterAnnDataEnv(),
      fun = function(path, obs_specs, var_specs, n_features, n_cells) {
        anndata <- reticulate::import("anndata", convert = FALSE)
        old_remove <- anndata$settings$remove_unused_categories
        anndata$settings$remove_unused_categories <- FALSE
        on.exit({ anndata$settings$remove_unused_categories <- old_remove }, add = TRUE)
        ad <- anndata$read_h5ad(path)
        if (n_features == 1L || n_cells == 1L) {
          slice <- reticulate::import_builtins(convert = FALSE)$slice
          ad <- ad$`__getitem__`(reticulate::tuple(slice(0L, n_cells), slice(0L, n_features)))$copy()
        }
        for (component in c("obs", "var")) {
          specs <- if (component == "obs") obs_specs else var_specs
          df <- reticulate::py_get_attr(ad, component)
          for (k in names(specs)) df[[k]] <- df[[k]]$cat$set_categories(
            reticulate::r_to_py(as.list(specs[[k]]$levels)), ordered = specs[[k]]$ordered)
        }
        ad$write_h5ad(path, convert_strings_to_categoricals = FALSE)
        invisible(NULL)
      }, path = file, obs_specs = obs$specs, var_specs = var$specs,
      n_features = original_features, n_cells = original_cells)
  }
  invisible(file)
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
os_sc_convert <- function(x, to, consumer, layers, cluster_col, source_assay = NULL, target_assay = NULL,
                          x_role = NULL, file = NULL) {
  if (missing(to) || is.null(to)) .os_sc_stop("OS_MISSING_PARAMETER", "to must name the target type (%s)", paste(names(OS_SC_TYPES), collapse = ", "))
  if (!to %in% names(OS_SC_TYPES)) .os_sc_stop("OS_INVALID_PARAMETER", "to must be one of %s, got '%s'", paste(names(OS_SC_TYPES), collapse = ", "), to)
  if (missing(consumer) || is.null(consumer)) .os_sc_stop("OS_MISSING_PARAMETER", "consumer must say who receives the object (%s)", paste(OS_SC_CONSUMERS, collapse = ", "))
  if (!consumer %in% OS_SC_CONSUMERS) .os_sc_stop("OS_INVALID_PARAMETER", "consumer must be one of %s, got '%s'", paste(OS_SC_CONSUMERS, collapse = ", "), consumer)
  if (missing(cluster_col)) cluster_col <- NULL
  layers <- .os_sc_roles(if (missing(layers)) NULL else layers)
  src <- .os_sc_source(x)
  if (identical(consumer, "front_end") && !identical(src$type, to)) {
    .os_sc_stop("OS_ECOSYSTEM_MIXED", paste0("a front-end module cannot take a converted object (%s -> %s). A chain's front end ",
                                             "(qc, clustering, integration, markers, scoring) stays in one ecosystem; only the ",
                                             "ecosystem-neutral back-end modules convert. Start a new chain in the %s ecosystem instead."),
                src$type, to, os_sc_ecosystem(to))
  }
  if (identical(src$type, "AnnData") && identical(to, "AnnData")) .os_sc_stop("OS_CONVERT_UNSUPPORTED", "AnnData -> AnnData is not a conversion; read the .h5ad directly")
  if (identical(to, "AnnData")) {
    if (is.null(file) || !nzchar(file)) .os_sc_stop("OS_MISSING_PARAMETER", "file must name the .h5ad to write for to = \"AnnData\"")
    if (!identical(tolower(tools::file_ext(file)), "h5ad")) .os_sc_stop("OS_INVALID_PARAMETER", "file must end in .h5ad, got '%s'", file)
    if (is.null(x_role)) .os_sc_stop("OS_MISSING_PARAMETER", "x_role must say which role becomes AnnData X (one of %s)", paste(names(layers), collapse = ", "))
    if (!x_role %in% names(layers)) .os_sc_stop("OS_INVALID_PARAMETER", "x_role must be one of the roles given in layers (%s), got '%s'", paste(names(layers), collapse = ", "), x_role)
  }
  if (identical(to, "Seurat") && (is.null(target_assay) || !nzchar(target_assay))) .os_sc_stop("OS_MISSING_PARAMETER", "target_assay must name the Seurat assay to create (e.g. \"RNA\")")
  if (identical(src$type, "AnnData") || identical(to, "AnnData")) .os_sc_require_anndata_env()

  chain_state <- .os_sc_embedded_state(src)
  parts <- os_sc_parts(if (identical(src$type, "AnnData")) src$path else src$object, src$type, layers, assay = source_assay)
  .os_sc_check_parts(parts, cluster_col)
  before <- os_sc_fingerprint(parts, cluster_col)
  tgt_layers <- stats::setNames(names(layers), names(layers))
  impl <- character(0)
  if (identical(src$type, "AnnData")) impl <- c(impl, "zellkonverter::readH5AD(reader = \"python\")")
  if (identical(to, "Seurat")) {
    out <- .os_sc_build_seurat(parts, target_assay, cluster_col)
    if (length(chain_state)) out@misc$omicstat_state <- chain_state
    impl <- c(impl, "SeuratObject::CreateAssay5Object", "SeuratObject::CreateSeuratObject", "SeuratObject::CreateDimReducObject")
    tgt_layers <- OS_SC_SEURAT_LAYER[names(layers)]
    after_parts <- .os_sc_parts_seurat(out, target_assay, tgt_layers)
    target_path <- NA_character_; target_sha <- .os_sc_sha(out)
  } else {
    sce <- .os_sc_build_sce(parts)
    if (length(chain_state)) S4Vectors::metadata(sce)$omicstat <- chain_state
    impl <- c(impl, "SingleCellExperiment::SingleCellExperiment")
    if (identical(to, "SingleCellExperiment")) {
      out <- sce
      after_parts <- .os_sc_parts_sce(out, tgt_layers)
      target_path <- NA_character_; target_sha <- .os_sc_sha(out)
    } else {
      .os_sc_write_h5ad(sce, file, x_role)
      impl <- c(impl, "zellkonverter::writeH5AD")
      tgt_layers[[x_role]] <- "X"
      after_parts <- .os_sc_parts_h5ad(file, tgt_layers)
      out <- normalizePath(file, winslash = "/")
      target_path <- out; target_sha <- .os_sc_file_sha(file)
    }
  }
  after <- os_sc_fingerprint(after_parts, cluster_col)
  os_sc_verify(before, after)

  pk <- c("SeuratObject", "SingleCellExperiment", if ("AnnData" %in% c(src$type, to)) c("zellkonverter", "basilisk"))
  step <- list(
    step = "sc_convert", function_name = "os_sc_convert", implementation = impl,
    from = src$type, to = to, from_ecosystem = os_sc_ecosystem(src$type), to_ecosystem = os_sc_ecosystem(to), consumer = consumer,
    source = list(file = if (is.na(src$path)) NA_character_ else basename(src$path), sha256 = src$sha256,
                  assay = if (identical(src$type, "Seurat")) source_assay else NA_character_, layers = as.list(layers)),
    target = list(file = if (is.na(target_path)) NA_character_ else basename(target_path), sha256 = target_sha,
                  assay = if (identical(to, "Seurat")) target_assay else NA_character_, layers = as.list(tgt_layers),
                  x_role = if (identical(to, "AnnData")) x_role else NA_character_),
    cluster_col = cluster_col, n_cells = before$n_cells, n_features = before$n_features,
    content_sha256_before = .os_sc_sha(before), content_sha256_after = .os_sc_sha(after),
    checks = "PASS: cell count, gene count, cell and feature ids, matrices, cell and feature metadata (levels and order), embeddings, cluster labels",
    carried = list(cell_metadata = names(parts$coldata), feature_metadata = names(parts$rowdata), reductions = names(parts$reductions)),
    not_carried = sort(unique(c(parts$not_carried, if (identical(to, "AnnData")) "embedding attributes other than coordinates and column names (obsm holds coordinates only)")), method = "radix"),
    packages = stats::setNames(lapply(pk, function(q) as.character(utils::packageVersion(q))), pk),
    anndata = if ("AnnData" %in% c(src$type, to)) OS_SC_ANNDATA_VERSION else NA_character_)
  list(object = out, step = step)
}
