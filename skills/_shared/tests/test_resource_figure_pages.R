# Native synthetic display contract. No scientific fit or owner anchor claim.
# Rscript skills/_shared/tests/test_resource_figure_pages.R --outdir <NEW_DIR>
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L || args[1] != "--outdir" || !nzchar(args[2]))
  stop("Pass --outdir <new evidence directory>", call. = FALSE)
if (file.exists(args[2])) stop("Evidence directory already exists; use a fresh path", call. = FALSE)
this <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
root <- normalizePath(file.path(dirname(this), "../../.."))
scripts <- file.path(root, "skills/_shared/scripts")
options(omicstat.shared_scripts = scripts)
for (name in c("args.R", "engine_run.R", "module_kit.R", "fig_all.R", "render_figure_request.R"))
  source(file.path(scripts, name))
fixture <- file.path(root, "docs/round4/20261018-resource-figures-r2/synthetic-contract")
manifest <- jsonlite::fromJSON(file.path(fixture, "FIXTURE.json"), simplifyVector = FALSE)
stopifnot(identical(manifest$official_anchor, FALSE), identical(manifest$patient_rows, FALSE))
for (f in manifest$files) stopifnot(identical(digest::digest(file = file.path(fixture, f$path), algo = "sha256"), f$sha256))
dir.create(args[2], recursive = TRUE, showWarnings = FALSE)
run <- normalizePath(args[2], winslash = "/", mustWork = TRUE)
for (f in manifest$files) {
  target <- file.path(run, f$path)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  stopifnot(file.copy(file.path(fixture, f$path), target, overwrite = FALSE))
}
refusal <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = function(e) e)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error), fixed = TRUE))
  cat("EXPECTED_REFUSAL", conditionMessage(error), "\n")
}
req <- os_rr_read_request(run)
stopifnot(length(req$figures) == 3L, length(OS_PAL_CATEGORY) == 23L)
metas <- list(); foreground <- character(); all_categories <- character(); plots <- list()
for (f in req$figures) {
  dat <- list(emb = os_rr_read_data(run, f$data$emb, "synthetic embedding"))
  scope <- .os_rr_sampling_scope(run, f$sampling_scope, f$caption_context, dat)
  stopifnot(scope$observations_before == 96, scope$observations_after == 48,
    scope$biological_units_before == 6, scope$biological_units_after == 6,
    all(vapply(scope$by_group, function(g) g$biological_units_after == 3, TRUE)))
  p <- do.call(os_embedding_page, c(dat, lapply(f$args, .os_rr_simplify)))
  meta <- attr(p, "os_meta"); n <- meta$data
  stopifnot(n$n_cells == 48, n$foreground_n + n$background_n == 48,
    n$unique_cell_denominator == 48,
    identical(meta$notes$background_is_category, FALSE),
    identical(meta$notes$background_added_to_denominator, FALSE),
    isTRUE(meta$notes$background_repeated_across_pages),
    identical(meta$notes$analysis_recomputed, FALSE),
    grepl("never the sum of pages", meta$caption, fixed = TRUE),
    grepl("not as another cluster", meta$caption, fixed = TRUE))
  built <- ggplot2::ggplot_build(p)
  stopifnot(nrow(built$data[[1]]) == n$background_n, nrow(built$data[[2]]) == n$foreground_n)
  page_groups <- unlist(n$foreground_categories, use.names = FALSE)
  foreground <- c(foreground, dat$emb$cell[as.character(dat$emb$cluster) %in% page_groups])
  all_categories <- c(all_categories, page_groups)
  metas[[length(metas) + 1L]] <- meta
  plots[[length(plots) + 1L]] <- p
}
stopifnot(!anyDuplicated(foreground), length(foreground) == 48L,
  !anyDuplicated(all_categories), length(all_categories) == 48L,
  sum(vapply(metas, function(m) m$data$foreground_n, 0)) == 48,
  identical(vapply(metas, function(m) m$data$foreground_n, 0), c(23, 23, 2)),
  all(vapply(metas, function(m) identical(m$data$coordinate_range, metas[[1]]$data$coordinate_range), TRUE)),
  length(unique(vapply(metas, function(m) m$data$coordinate_sha256, ""))) == 1L,
  all(vapply(plots, function(p) !is.null(attr(p, "os_prepared_draw_unavailable")), TRUE)))
# Strict source, caption and selected-ID bindings in the real R reader.
f <- req$figures[[1]]; dat <- list(emb = os_rr_read_data(run, f$data$emb, "synthetic embedding"))
bad <- f$sampling_scope; bad$observations_before <- 97
refusal(.os_rr_sampling_scope(run, bad, f$caption_context, dat), "source aggregate counts differ")
refusal(.os_rr_sampling_scope(run, f$sampling_scope, "omitted original n", dat), "caption is absent")
bad <- f$sampling_scope; bad$source$sha256 <- paste(rep("0", 64), collapse = "")
refusal(.os_rr_sampling_scope(run, bad, f$caption_context, dat), "source SHA256 differs")
wrong <- dat; wrong$emb$cell <- rev(wrong$emb$cell)
refusal(.os_rr_sampling_scope(run, f$sampling_scope, f$caption_context, wrong), "cell order/IDs differ")
page_args <- lapply(f$args, .os_rr_simplify); page_args$page_groups <- rev(page_args$page_groups)
refusal(do.call(os_embedding_page, c(dat, page_args)), "exact ordered partition")
extreme <- data.frame(cell = sprintf("synthetic_stress_%04d", 1:2002),
  x = seq_len(2002), y = seq_len(2002) %% 19, cluster = sprintf("c%04d", 1:2002))
refusal(os_embedding_page(extreme, "cluster", sprintf("c%04d", 1:23), 1, 88), "OS_TOO_MANY_CATEGORIES")
# Actual PNG/PDF/spec rendering and replay are mandatory; missing native deps
# fail this lane. The frozen source request/CSV/record bytes must not change.
first <- os_render_figure_request(run)
stopifnot(length(first$figures) == 3L)
for (f in first$figures) {
  spec <- jsonlite::fromJSON(file.path(run, f$spec$path), simplifyVector = FALSE)
  stopifnot(grepl("48 of 96 input cells", spec$caption, fixed = TRUE),
    grepl("6 of 6 biological units", spec$caption, fixed = TRUE))
}
second <- os_render_figure_request(run)
stopifnot(length(second$figures) == 3L)
for (f in manifest$files) stopifnot(identical(digest::digest(file = file.path(run, f$path), algo = "sha256"), f$sha256))
cat("PASS native synthetic resource captions, page coverage/ranges, strict refusals, PNG/PDF and replay. Owner review remains pending.\n")
