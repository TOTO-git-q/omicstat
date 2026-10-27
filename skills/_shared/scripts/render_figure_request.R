# render_figure_request.R -- the R render step of a Python-lane run
# (ENGINEERING_PLAN 10.5). ASCII only on purpose.
#
# Python modules never draw publication figures. They write the data a figure
# needs (figure_data/*.csv) plus figure_data/figure_request.json
# (skills/_shared/py/ospy/figure_request.py); this script renders every
# requested figure through the existing fig_*.R builders and
# os_finalize_figure() (lint, PDF + PNG, figure_spec.json), so FIGURE_STYLE,
# the colour-vision checks, n-with-unit, auto captions and lint exist once.
# It runs in the omicstat-r image (or the native R library) as the final step
# of a Python run and records itself as a provenance step:
#
#   Rscript render_figure_request.R --run-dir <python run outdir>
#     [--request figure_data/figure_request.json]
#
# Request (schema omicstat.figure-request.v1):
#   { "schema", "module", "module_version", "journal",
#     "colour_registry": null | "objects/<in>.json",      # read, passed to builders
#     "colour_registry_out": null | "objects/colour_registry.json",  # optional
#     "figures": [ { "id", "builder": "os_embedding", "out_stem": "figures/<x>",
#                    "width": "single"|"onehalf"|"double"|<mm>, "height_mm": null|<mm>,
#                    "formats": ["pdf","png"],
#                    "data": { "<arg>": { "kind": "data.frame"|"vector"|"matrix",
#                                         "path": "figure_data/<f>.csv", "sha256",
#                                         "n_rows", "columns": [{"name","type","levels"?}] } },
#                    "args": { "<arg>": <JSON scalar | array -> vector | object -> list> } } ] }
# Every data file is sha256-checked before it is read; paths must stay inside
# the run directory. Only the builders in OS_RENDER_BUILDERS can be called.
# Writes: figures/<stem>.{pdf,png,...} + <stem>.figure_spec.json,
#         qc/render_warnings.csv (engine_run.R log of this step),
#         provenance/figure_render.json (this step's provenance record), and,
#         with colour_registry_out, the chain's colour registry (registered as
#         object "colour_registry" in objects/handoff.json when that exists).
# Typed errors: OS_FIGURE_REQUEST_INVALID, OS_FIGURE_DATA_MISMATCH, plus any
# OS_FIG_* raised by the figure layer (e.g. OS_FIG_LINT_BLOCKER).
# Closing line: "N figure(s) rendered from <request>; read provenance/figure_render.json first".

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

OS_FIGURE_REQUEST_SCHEMA <- "omicstat.figure-request.v1"
OS_FIGURE_RENDER_SCHEMA <- "omicstat.figure-render.v1"
# Builders a request may name: every one takes plain data.frames / vectors /
# matrices plus scalar options and returns a plot carrying attr "os_meta".
OS_RENDER_BUILDERS <- c("os_volcano", "os_ma", "os_diag_xy", "os_heatmap", "os_embedding", "os_embedding_page", "os_feature_embedding",
                        "os_marker_dotplot", "os_proportion_bar", "os_qc_violin", "os_score_violin",
                        "os_stacked_violin", "os_ridge", "os_highlight_embedding", "os_alluvial",
                        "os_cluster_tree_dotplot", "os_density_embedding", "os_km", "os_hr_forest",
                        "os_time_roc", "os_lasso_path", "os_calibration", "os_group_points", "os_standard_curve", "os_spatial_map",
                        "os_sample_distance", "os_top_heatmap", "os_selected_feature_points", "os_pseudobulk_eligibility")
OS_RENDER_COL_TYPES <- c(character = "character", numeric = "numeric", integer = "integer", logical = "logical",
                         factor = "character")

.os_rr_stop <- function(code, fmt, ...) stop(sprintf(paste0(code, ": ", fmt), ...), call. = FALSE)

# A relative path inside run_dir (no absolute path, no "..", must exist).
.os_rr_path <- function(run_dir, rel, what, must_exist = TRUE) {
  if (!is.character(rel) || length(rel) != 1 || !nzchar(rel) || grepl("^([A-Za-z]:)?[/\\\\]", rel) ||
      any(strsplit(rel, "[/\\\\]")[[1]] == "..")) {
    .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "%s must be a relative path inside the run directory, got '%s'", what, paste(rel, collapse = " "))
  }
  p <- file.path(run_dir, rel)
  if (must_exist && !file.exists(p)) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "%s '%s' does not exist", what, rel)
  p
}

# JSON (simplifyVector = FALSE) -> R values: an array of scalars becomes an
# atomic vector, an object a named list (recursively), null stays NULL.
.os_rr_simplify <- function(x) {
  if (is.list(x) && is.null(names(x))) {
    if (!length(x)) return(list())
    if (all(vapply(x, function(v) is.atomic(v) && length(v) == 1, logical(1)))) return(unlist(x, use.names = FALSE))
    return(lapply(x, .os_rr_simplify))
  }
  if (is.list(x)) return(lapply(x, .os_rr_simplify))
  x
}

os_rr_read_request <- function(run_dir, rel = "figure_data/figure_request.json") {
  path <- .os_rr_path(run_dir, rel, "--request")
  req <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                  error = function(e) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "%s is not valid JSON (%s)", rel, conditionMessage(e)))
  if (!identical(req$schema, OS_FIGURE_REQUEST_SCHEMA)) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "unknown schema tag '%s'", req$schema %||% "")
  if (!length(req$figures)) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "the request lists no figures")
  ids <- vapply(req$figures, function(f) f$id %||% "", "")
  if (anyDuplicated(ids) || any(!grepl("^[A-Za-z0-9][A-Za-z0-9_-]*$", ids))) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "figure ids must be unique [A-Za-z0-9_-] names")
  for (f in req$figures) {
    if (!(f$builder %||% "") %in% OS_RENDER_BUILDERS) {
      .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "figure '%s': builder '%s' is not one of %s", f$id, f$builder %||% "", paste(OS_RENDER_BUILDERS, collapse = ", "))
    }
    if (!grepl("^figures/[A-Za-z0-9][A-Za-z0-9_./-]*$", f$out_stem %||% "") || any(strsplit(f$out_stem, "/")[[1]] == "..")) {
      .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "figure '%s': out_stem must lie under figures/", f$id)
    }
    fm <- unlist(f$formats %||% list("pdf", "png"))
    if (!length(fm) || !all(fm %in% c("pdf", "png", "svg"))) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "figure '%s': formats must be pdf/png/svg", f$id)
    clash <- intersect(names(f$data), names(f$args))
    if (length(clash)) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "figure '%s': %s given both as data and as args", f$id, paste(clash, collapse = ", "))
  }
  req$.path <- path
  req$.rel <- rel
  req
}

os_rr_read_data <- function(run_dir, d, what) {
  path <- .os_rr_path(run_dir, d$path %||% "", what)
  got <- digest::digest(file = path, algo = "sha256")
  if (!identical(got, d$sha256)) {
    .os_rr_stop("OS_FIGURE_DATA_MISMATCH", "%s (%s): sha256 differs from the request (file changed after the Python step)", what, d$path)
  }
  cols <- d$columns
  nm <- vapply(cols, `[[`, "", "name")
  ty <- vapply(cols, `[[`, "", "type")
  if (!all(ty %in% names(OS_RENDER_COL_TYPES))) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "%s: unknown column type(s) %s", what, paste(setdiff(ty, names(OS_RENDER_COL_TYPES)), collapse = ", "))
  df <- utils::read.csv(path, colClasses = unname(OS_RENDER_COL_TYPES[ty]), na.strings = "NA", check.names = FALSE,
                        stringsAsFactors = FALSE, encoding = "UTF-8")
  if (!identical(names(df), nm)) .os_rr_stop("OS_FIGURE_DATA_MISMATCH", "%s: columns %s differ from the request (%s)", what, paste(names(df), collapse = ","), paste(nm, collapse = ","))
  if (!is.null(d$n_rows) && nrow(df) != d$n_rows) .os_rr_stop("OS_FIGURE_DATA_MISMATCH", "%s: %d rows, the request says %d", what, nrow(df), d$n_rows)
  for (k in which(ty == "factor")) {
    lv <- unlist(cols[[k]]$levels)
    bad <- setdiff(unique(df[[k]][!is.na(df[[k]])]), lv)
    if (length(bad)) .os_rr_stop("OS_FIGURE_DATA_MISMATCH", "%s: column %s has values outside its levels (%s)", what, nm[k], paste(utils::head(bad, 5), collapse = ", "))
    df[[k]] <- factor(df[[k]], levels = lv)
  }
  switch(d$kind %||% "",
    data.frame = {
      if (!is.null(d$row_id_column)) {
        key <- d$row_id_column
        if (!is.character(key) || length(key) != 1L || !key %in% names(df)) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "%s: absent row ID column", what)
        rownames(df) <- .os_require_ids(df[[key]], paste(what, "row IDs"))
        df <- df[, setdiff(names(df), key), drop = FALSE]
      }
      df
    },
    vector = if ("name" %in% names(df)) stats::setNames(df$value, df$name) else df$value,
    matrix = {
      m <- as.matrix(df[, -1, drop = FALSE])
      storage.mode(m) <- "double"
      rownames(m) <- df$row_id
      m
    },
    .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "%s: unknown data kind '%s'", what, d$kind %||% ""))
}

.os_rr_rel_sha <- function(run_dir, p) {
  list(path = .os_rel(p, run_dir), sha256 = digest::digest(file = p, algo = "sha256"))
}

# Validate the aggregate caption against the exact selection-only record.
# No expression/clinical row table or analysis method is read/recomputed here.
.os_rr_sampling_scope <- function(run_dir, scope, caption_context, data_args) {
  bad <- function(message) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "sampling scope: %s", message)
  keys <- c("schema", "observation_unit", "analysis_sampling", "display_only", "observations_before", "observations_after",
    "biological_units_before", "biological_units_after", "groups_provided", "by_group", "caption", "source",
    "original_id_sha256", "selected_id_sha256")
  if (!is.list(scope) || !setequal(names(scope), keys) || anyDuplicated(names(scope)) ||
      !identical(scope$schema, "omicstat.figure-sampling-scope.v1") || !identical(scope$observation_unit, "cells") ||
      !is.logical(scope$analysis_sampling) || length(scope$analysis_sampling) != 1L || is.na(scope$analysis_sampling) ||
      !identical(scope$display_only, FALSE)) bad("unsupported aggregate contract")
  if (!is.list(scope$source) || !setequal(names(scope$source), c("path", "sha256")) ||
      !identical(scope$source$path, "provenance/resource_sampling.json") ||
      anyDuplicated(names(scope$source)) || !is.character(scope$source$sha256) || length(scope$source$sha256) != 1L ||
      !grepl("^[0-9a-f]{64}$", scope$source$sha256)) bad("source identity is invalid")
  path <- .os_rr_path(run_dir, scope$source$path, "sampling record")
  if (nzchar(Sys.readlink(path)) || nzchar(Sys.readlink(dirname(path))) ||
      !startsWith(normalizePath(path, winslash = "/", mustWork = TRUE), paste0(run_dir, "/"))) bad("source path is unsafe")
  if (!identical(digest::digest(file = path, algo = "sha256"), scope$source$sha256)) bad("source SHA256 differs")
  record <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(record$schema, "omicstat.resource-sampling.v1")) bad("source schema differs")
  for (key in c("original_id_sha256", "selected_id_sha256"))
    if (!is.character(scope[[key]]) || length(scope[[key]]) != 1L ||
        !grepl("^[0-9a-f]{64}$", scope[[key]]) || !identical(scope[[key]], record[[key]])) bad("selection ID digest differs")
  count <- function(x, minimum = 0) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x != floor(x) || x < minimum || x > 9007199254740991)
      bad("counts must be exact safe nonnegative integers")
    x
  }
  fields <- c("observations_before", "observations_after", "biological_units_before", "biological_units_after")
  for (key in fields) if (count(scope[[key]], 1) != count(record[[key]], 1)) bad("source aggregate counts differ")
  before <- scope$observations_before; after <- scope$observations_after
  ub <- scope$biological_units_before; ua <- scope$biological_units_after
  if (after > before || ua != ub) bad("selection increased cells or lost a biological unit")
  if (!identical(record$applied, after < before) || !identical(scope$analysis_sampling, record$applied))
    bad("applied selection claim differs from retained counts")
  units <- record$by_unit
  if (!is.list(units) || length(units) != ub) bad("by-unit count differs")
  unit_ids <- vapply(units, function(row) {
    if (!is.character(row$unit_id) || length(row$unit_id) != 1L || is.na(row$unit_id) || !nzchar(row$unit_id)) bad("unit ID missing")
    if (count(row$observations_after, 1) > count(row$observations_before, 1)) bad("unit count increased")
    row$unit_id
  }, "")
  if (anyDuplicated(unit_ids) || sum(vapply(units, function(x) count(x$observations_before, 1), 0)) != before ||
      sum(vapply(units, function(x) count(x$observations_after, 1), 0)) != after) bad("unit totals disagree")
  declared <- record$groups_provided
  if (!is.logical(declared) || length(declared) != 1L || is.na(declared) ||
      !identical(scope$groups_provided, declared) || !is.list(record$by_group) ||
      (length(record$by_group) > 0L) != declared || length(scope$by_group) != length(record$by_group)) bad("declared grouping differs")
  groups <- lapply(seq_along(record$by_group), function(i) {
    row <- record$by_group[[i]]; actual <- scope$by_group[[i]]
    if (!is.character(row$group) || length(row$group) != 1L || is.na(row$group) || !nzchar(row$group) ||
        !is.list(actual) || anyDuplicated(names(actual)) || !setequal(names(actual), c("group", fields)) || !identical(actual$group, row$group)) bad("group label differs")
    for (key in fields) if (count(actual[[key]]) != count(row[[key]])) bad("group counts differ")
    if (row$observations_before < 1 || row$biological_units_before < 1 || row$observations_after > row$observations_before ||
        row$biological_units_after > row$biological_units_before || row$biological_units_before > ub ||
        row$biological_units_after > ua || row$biological_units_before > row$observations_before ||
        row$biological_units_after > row$observations_after) bad("group counts are inconsistent")
    actual
  })
  if (declared && (anyDuplicated(vapply(groups, `[[`, "", "group")) ||
      sum(vapply(groups, `[[`, 0, "observations_before")) != before ||
      sum(vapply(groups, `[[`, 0, "observations_after")) != after)) bad("group cell totals disagree")
  number <- function(x) formatC(x, format = "f", digits = 0, big.mark = ",")
  caption <- sprintf("Analysis subsampling: %s of %s input cells and %s of %s biological units retained. ",
    number(after), number(before), number(ua), number(ub))
  caption <- paste0(caption, if (scope$analysis_sampling)
    "This changes the analyzed observations, not only their display; cells are not biological replicates." else
    "No input cells were removed by this sampling step; cells are not biological replicates.")
  if (declared) {
    labels <- vapply(utils::head(groups, 6L), function(row) sprintf("%s: %s of %s biological units, %s of %s cells", row$group,
      number(row$biological_units_after), number(row$biological_units_before), number(row$observations_after), number(row$observations_before)), "")
    caption <- paste0(caption, " Declared groups: ", paste(labels, collapse = "; "), ".")
    if (length(groups) > 6L) caption <- paste0(caption, sprintf(" %d further groups are listed in the source sampling record and figure metadata.", length(groups) - 6L))
  } else caption <- paste0(caption, " No condition/group column was declared; no per-group replication is inferred.")
  if (!identical(scope$caption, caption) || !is.character(caption_context) || length(caption_context) != 1L ||
      !grepl(caption, caption_context, fixed = TRUE)) bad("caption is absent or differs from the source counts")
  if (!is.null(data_args$emb)) {
    ids <- .os_require_ids(data_args$emb$cell, "sampling display cell IDs")
    if (length(ids) > after) bad("display contains more cells than the retained analysis")
    if (length(ids) == after) {
      encoded <- paste0(nchar(enc2utf8(ids), type = "bytes"), ":", enc2utf8(ids), collapse = "")
      if (!identical(digest::digest(enc2utf8(encoded), algo = "sha256", serialize = FALSE), scope$selected_id_sha256))
        bad("complete display cell order/IDs differ from selected analysis")
    }
  }
  scope
}

# Render every figure of the request; returns the provenance record (also written).
os_render_figure_request <- function(run_dir, rel = "figure_data/figure_request.json", elog = NULL) {
  run_dir <- normalizePath(run_dir, winslash = "/", mustWork = TRUE)
  req <- os_rr_read_request(run_dir, rel)
  journal <- req$journal %||% "nature"
  os_journal(journal)                       # validates the preset name
  old <- options(omicstat.journal = journal); on.exit(options(old), add = TRUE)
  if (is.null(elog)) {
    elog <- os_engine_log_new(run_dir)
    elog$path <- file.path(run_dir, "qc", "render_warnings.csv")
  }
  reg <- if (!is.null(req$colour_registry)) os_colour_registry_read(.os_rr_path(run_dir, req$colour_registry, "colour_registry")) else os_colour_registry_new()
  figs <- list()
  for (f in req$figures) {
    rec <- os_engine_capture({
      fn <- get(f$builder, mode = "function")
      data_args <- lapply(names(f$data), function(a) os_rr_read_data(run_dir, f$data[[a]], sprintf("figure '%s' data '%s'", f$id, a)))
      names(data_args) <- names(f$data)
      call_args <- c(data_args, lapply(f$args %||% list(), .os_rr_simplify))
      sampling_scope <- if (!is.null(f$sampling_scope))
        .os_rr_sampling_scope(run_dir, f$sampling_scope, f$caption_context, data_args) else NULL
      fmls <- names(formals(fn))
      if ("journal" %in% fmls && is.null(call_args$journal)) call_args$journal <- journal
      if ("colour_registry" %in% fmls && is.null(call_args$colour_registry)) call_args$colour_registry <- reg
      # Off-range QC cutoffs must not flatten the observed distributions.
      # Keep every cutoff in the spec/caption, but draw only in-range lines.
      qc_thresholds <- NULL
      if (identical(f$builder, "os_qc_violin") && length(call_args$thresholds)) {
        if (!is.null(call_args$metric_labels)) call_args$metric_labels <- unlist(call_args$metric_labels)
        qc_thresholds <- call_args$thresholds
        call_args$thresholds <- lapply(names(qc_thresholds), function(m) {
          limits <- range(call_args$qc[[m]], finite = TRUE)
          values <- qc_thresholds[[m]]
          values[values >= limits[1] & values <= limits[2]]
        })
        names(call_args$thresholds) <- names(qc_thresholds)
      }
      semantic_binding <- if(!is.null(f$definition)) os_validate_render_sources(f$definition,call_args) else NULL
      if(!is.null(f$definition) && "definition" %in% names(formals(fn)))call_args$definition<-f$definition
      p <- do.call(fn, call_args)
      meta <- attr(p, "os_meta")
      if (is.null(meta)) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "figure '%s': %s returned no os_meta", f$id, f$builder)
      if (!is.null(qc_thresholds)) {
        meta$thresholds <- qc_thresholds
        cutoffs <- vapply(names(qc_thresholds), function(m)
          paste0(m, "=", paste(qc_thresholds[[m]], collapse = ",")), "")
        meta$caption <- paste(meta$caption, "Filtering cutoffs:", paste(cutoffs, collapse = "; "),
                              ". Cutoffs outside the observed range are recorded here but not drawn.")
        attr(p, "os_meta") <- meta
      }
      if (!is.null(f$caption_context)) {
        if (!is.character(f$caption_context) || length(f$caption_context) != 1L || !nzchar(f$caption_context))
          .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "caption_context must be one nonempty string")
        meta$caption <- paste(meta$caption %||% "", f$caption_context)
        attr(p, "os_meta") <- meta
      }
      if (!is.null(sampling_scope)) {
        p <- os_with_meta(p, notes = list(analysis_sampling = sampling_scope))
        meta <- attr(p, "os_meta")
      }
      if (!is.null(f$definition)) {
        p <- os_with_meta(p, definition = f$definition, notes=list(render_source_binding=semantic_binding))
        meta <- attr(p, "os_meta")
      }
      if (!is.null(f$evidence_refs)) {
        os_validate_evidence_refs(f$evidence_refs)
        p <- os_with_meta(p, evidence_refs = f$evidence_refs)
        meta <- attr(p, "os_meta")
      }
      if (!is.null(meta$colour_registry)) reg <- meta$colour_registry
      width <- f$width %||% "single"
      res <- os_finalize_figure(p, file.path(run_dir, f$out_stem), width = width, height_mm = f$height_mm,
                                journal = journal, formats = unlist(f$formats %||% list("pdf", "png")), root = run_dir)
      list(id = f$id, builder = f$builder, figure_type = res$spec_obj$figure_type,
           spec = .os_rr_rel_sha(run_dir, res$spec),
           files = lapply(res$spec_obj$files, function(x) x),
           data = lapply(f$data, function(d) list(path = d$path, sha256 = d$sha256)),
           lint = nrow(res$lint))
    }, paste0("render:", f$id), elog)
    figs[[length(figs) + 1L]] <- rec
  }
  reg_out <- NULL
  if (!is.null(req$colour_registry_out)) {
    out_rel <- req$colour_registry_out
    if (!startsWith(out_rel, "objects/")) .os_rr_stop("OS_FIGURE_REQUEST_INVALID", "colour_registry_out must lie under objects/")
    out_path <- .os_rr_path(run_dir, out_rel, "colour_registry_out", must_exist = FALSE)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    os_colour_registry_write(reg, out_path)
    reg_out <- .os_rr_rel_sha(run_dir, out_path)
    .os_rr_register_colours(run_dir, out_rel, reg_out$sha256)
  }
  sig <- if (exists("os_env_signature", mode = "function")) os_env_signature() else list()
  pk <- sort(intersect(c("ggplot2", "ggrepel", "patchwork", "ragg", "svglite", "ggrastr", "systemfonts", "scales",
                         "jsonlite", "digest"), loadedNamespaces()), method = "radix")
  this <- getOption("omicstat.render_script", NA_character_)
  record <- list(
    schema = OS_FIGURE_RENDER_SCHEMA,
    step = "render_figure_request",
    script = "skills/_shared/scripts/render_figure_request.R",
    script_sha256 = if (!is.na(this) && file.exists(this)) digest::digest(file = this, algo = "sha256") else NULL,
    request = list(path = req$.rel, sha256 = digest::digest(file = req$.path, algo = "sha256"),
                   module = req$module %||% NULL, module_version = req$module_version %||% NULL),
    journal = journal, figure_style_version = OS_FIG_STYLE_VERSION,
    environment = sig, r_version = R.version.string,
    packages = stats::setNames(lapply(pk, function(p) as.character(utils::packageVersion(p))), pk),
    figures = figs, colour_registry_out = reg_out,
    warnings = as.list(os_engine_counts(elog)))
  dir.create(file.path(run_dir, "provenance"), recursive = TRUE, showWarnings = FALSE)
  os_write_json(record, file.path(run_dir, "provenance", "figure_render.json"))
  invisible(record)
}

# Register (or refresh) the chain's colour registry in objects/handoff.json, so
# downstream modules reuse the colours of this run (CONVENTIONS.md sec 6).
.os_rr_register_colours <- function(run_dir, rel, sha) {
  hp <- file.path(run_dir, "objects", "handoff.json")
  if (!file.exists(hp)) return(invisible(FALSE))
  doc <- jsonlite::fromJSON(hp, simplifyVector = FALSE)
  objs <- Filter(function(o) !identical(o$name, "colour_registry"), doc$objects %||% list())
  objs[[length(objs) + 1L]] <- list(name = "colour_registry", type = "colour_registry", path = rel, sha256 = sha)
  doc$objects <- objs[order(vapply(objs, `[[`, "", "name"), method = "radix")]
  if (!length(doc$state)) doc$state <- structure(list(), names = character(0))
  js <- jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = I(10))
  con <- file(hp, open = "wb"); on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(js, "\n"))), con)
  invisible(TRUE)
}

.os_rr_main <- function() {
  options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1, save = "no") })
  this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
  options(omicstat.render_script = this)
  scripts <- dirname(this)
  source(file.path(scripts, "args.R"))
  source(file.path(scripts, "engine_run.R"))
  source(file.path(scripts, "module_kit.R"))
  spec <- os_arg_spec(
    usage = "Rscript render_figure_request.R --run-dir <dir> [options]",
    description = "Render the figure request of a Python-lane run through the R figure layer (ENGINEERING_PLAN 10.5).",
    flags = list(
      os_flag("run-dir", "path", required = TRUE, must_exist = TRUE, help = "output directory of the Python run"),
      os_flag("request", "string", default = "figure_data/figure_request.json", help = "request file, relative to the run directory")))
  args <- os_parse_args(spec, commandArgs(trailingOnly = TRUE))
  if (isTRUE(args$help)) { os_print_help(spec); quit(status = 0) }
  # fig_all.R locates itself through the sourcing frame; from inside this
  # function that frame is not source()'s, so name the directory explicitly.
  options(omicstat.shared_scripts = scripts)
  source(file.path(scripts, "fig_all.R"))
  rec <- os_render_figure_request(args[["run-dir"]], args$request)
  cat(sprintf("%d figure(s) rendered from %s; read provenance/figure_render.json first\n", length(rec$figures), args$request))
}

if (sys.nframe() == 0L) .os_rr_main()
