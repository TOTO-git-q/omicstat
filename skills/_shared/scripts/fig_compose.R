# fig_compose.R -- assemble panels into one journal figure.
# ASCII only on purpose. Requires fig_style.R.
#
# Rules enforced here (docs/FIGURE_STYLE.md sec 7):
#   * panel letters: journal case (nature a,b,c / cell & science A,B,C),
#     bold 8 pt, top-left corner OUTSIDE the panel, aligned across a row;
#   * one reading direction: panels are filled row by row;
#   * > 6 panels -> OS_FIG_TOO_MANY_PANELS warning (field median is 3-5);
#   * the combined legend text is "a, <caption a> b, <caption b> ..." built
#     from each panel's own generated caption, so the legend can never
#     disagree with what is drawn.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_compose.R.", call. = FALSE)

# Top margin (in tag lines) reserved above a wrapped patchwork sub-figure.
OS_FIG_TAG_MARGIN_LINES <- 1.5

# Contracts describe actual rendered mappings, not a requested interpretation.
# For plots without a contract, guide collection remains local and explicit.
os_panel_contract <- function(plot, guides = list(), axes = list(), row_ids = NULL, col_ids = NULL,
                              population = list(status = "unknown")) {
  contract <- list(version = "omicstat.panel-contract.v1", guides = guides, axes = axes,
                   row_ids = if (is.null(row_ids)) NULL else as.list(.os_require_ids(row_ids, "panel row IDs")),
                   col_ids = if (is.null(col_ids)) NULL else as.list(.os_require_ids(col_ids, "panel column IDs")), population = population)
  .os_validate_panel_contract(contract)
  if (!inherits(plot, "patchwork")) {
    built <- ggplot2::ggplot_build(plot)
    for (guide in guides) {
      scale <- built$plot$scales$get_scales(guide$aesthetic)
      if (is.null(scale)) stop("OS_FIG_GUIDE_INCOMPATIBLE: declared guide has no rendered scale.", call. = FALSE)
      if (guide$kind == "discrete") {
        actual <- unname(scale$map(names(guide$values))); declared <- unname(unlist(guide$values))
        if (!isTRUE(all.equal(actual, declared, check.attributes = FALSE))) stop("OS_FIG_GUIDE_INCOMPATIBLE: declared entity mapping differs from the actual scale.", call. = FALSE)
      } else if (!isTRUE(all.equal(unname(scale$get_limits()), unname(unlist(guide$limits)), check.attributes = FALSE)) ||
                 !isTRUE(all.equal(unname(scale$get_breaks()), unname(unlist(guide$ticks)), check.attributes = FALSE)))
        stop("OS_FIG_GUIDE_INCOMPATIBLE: declared continuous guide differs from its rendered limits or ticks.", call. = FALSE)
    }
    for (name in names(axes)) {
      if (!name %in% c("x", "y") || length(built$layout$panel_params) != 1L) stop("OS_FIG_AXIS_INCOMPATIBLE: explicit single-panel x/y axes are required.", call. = FALSE)
      rendered <- built$layout$panel_params[[1]][[name]]
      actual_ticks <- rendered$get_breaks(); actual_ticks <- actual_ticks[is.finite(actual_ticks)]
      if (!isTRUE(all.equal(unname(rendered$limits), unname(unlist(axes[[name]]$limits)), check.attributes = FALSE)) ||
          !isTRUE(all.equal(unname(actual_ticks), unname(unlist(axes[[name]]$ticks)), check.attributes = FALSE)))
        stop("OS_FIG_AXIS_INCOMPATIBLE: declared axis differs from actual limits or ticks.", call. = FALSE)
    }
  } else if (length(guides) || length(axes)) {
    existing <- (attr(plot, "os_meta") %||% list())$notes$panel_contract
    if (is.null(existing) || !.os_panel_equal(guides, existing$guides) || !.os_panel_equal(axes, existing$axes))
      stop("OS_FIG_GUIDE_INCOMPATIBLE: nested plots require their builder-generated actual scale contract.", call. = FALSE)
  }
  context <- vapply(names(population), function(n) paste0(n, "=", paste(unlist(population[[n]]), collapse = ",")), "")
  os_with_meta(plot, notes = list(panel_contract = contract), caption = paste((attr(plot, "os_meta") %||% list())$caption %||% "",
    "Panel provenance:", paste(context, collapse = "; "), "."))
}
.os_validate_panel_contract <- function(contract) {
  if (!identical(contract$version, "omicstat.panel-contract.v1")) stop("OS_FIG_GUIDE_INCOMPATIBLE: unknown panel contract version.", call. = FALSE)
  for (guide in contract$guides) {
    if (!is.list(guide) || length(guide$kind) != 1L || length(guide$aesthetic) != 1L)
      stop("OS_FIG_GUIDE_INCOMPATIBLE: guide kind and aesthetic are required.", call. = FALSE)
    if (!guide$kind %in% c("continuous", "discrete") || !guide$aesthetic %in% c("fill", "colour", "shape", "linetype", "size"))
      stop("OS_FIG_GUIDE_INCOMPATIBLE: guide kind and aesthetic must be explicit.", call. = FALSE)
    if (guide$kind == "discrete") {
      .os_sem_string(guide$entity_type, "guide entity type")
      .os_require_ids(names(guide$values), "guide entity IDs")
      if (any(vapply(guide$values, is.null, logical(1)))) stop("OS_FIG_GUIDE_INCOMPATIBLE: missing entity mapping.", call. = FALSE)
    } else {
      for (n in c("quantity", "unit", "transform")) .os_sem_string(guide[[n]], paste("guide", n))
      lim <- unlist(guide$limits); ticks <- unlist(guide$ticks)
      if (length(lim) != 2L || any(!is.finite(lim)) || lim[1] >= lim[2] || !length(ticks) || any(!is.finite(ticks)))
        stop("OS_FIG_GUIDE_INCOMPATIBLE: continuous guide needs actual finite limits and ticks.", call. = FALSE)
    }
  }
  for (axis in contract$axes) {
    for (n in c("quantity", "unit", "transform")) .os_sem_string(axis[[n]], paste("axis", n))
    if (length(unlist(axis$limits)) != 2L || !length(unlist(axis$ticks)) || any(!is.finite(c(unlist(axis$limits), unlist(axis$ticks)))))
      stop("OS_FIG_AXIS_INCOMPATIBLE: axis contracts need actual finite limits and ticks.", call. = FALSE)
  }
  invisible(TRUE)
}
.os_panel_equal <- function(a, b) identical(jsonlite::toJSON(.os_sort_keys(a), auto_unbox = TRUE, null = "null", digits = I(17)),
                                          jsonlite::toJSON(.os_sort_keys(b), auto_unbox = TRUE, null = "null", digits = I(17)))
.os_shared_guide_grob <- function(plot) {
  # Measure the declared installed font with the same Cairo backend used for
  # PDF export, rather than a default PostScript device with missing metrics.
  measure_file <- tempfile(fileext = ".pdf")
  grDevices::cairo_pdf(measure_file, width = 7, height = 7, family = os_font_family())
  measure_device <- grDevices::dev.cur()
  on.exit({ if (measure_device %in% grDevices::dev.list()) grDevices::dev.off(measure_device); unlink(measure_file) }, add = TRUE)
  gt <- if (inherits(plot, "patchwork")) patchwork::patchworkGrob(plot + patchwork::plot_layout(guides = "collect")) else
    ggplot2::ggplotGrob(plot + ggplot2::theme(legend.position = "right"))
  ids <- grep("^guide-box", gt$layout$name)
  ids <- ids[!vapply(gt$grobs[ids], inherits, logical(1), what = "zeroGrob")]
  if (length(ids) != 1L) stop("OS_FIG_GUIDE_INCOMPATIBLE: a verified shared guide must resolve to one actual legend box.", call. = FALSE)
  gt$grobs[[ids]]
}
.os_check_panel_contracts <- function(plots, collect_guides, shared_axes, linked_rows, linked_cols) {
  contracts <- lapply(plots, function(p) (attr(p, "os_meta") %||% list())$notes$panel_contract)
  for (c in Filter(Negate(is.null), contracts)) .os_validate_panel_contract(c)
  # Same entity/aesthetic must never quietly change its mapping across panels.
  mappings <- list(); colour_entities <- list(); alias <- FALSE
  for (contract in contracts) for (guide in contract$guides) if (guide$kind == "discrete") {
    for (id in names(guide$values)) {
      k <- as.character(jsonlite::toJSON(c(guide$entity_type, id, guide$aesthetic)))
      v <- guide$values[[id]]
      if (!is.null(mappings[[k]]) && !.os_panel_equal(mappings[[k]], v)) stop("OS_FIG_GUIDE_CONFLICT: the same entity has different mappings across panels.", call. = FALSE)
      mappings[[k]] <- v
      if (guide$aesthetic %in% c("fill", "colour")) {
        ck <- as.character(jsonlite::toJSON(v)); entity <- as.character(jsonlite::toJSON(c(guide$entity_type, id)))
        if (!is.null(colour_entities[[ck]]) && !identical(colour_entities[[ck]], entity)) alias <- TRUE
        colour_entities[[ck]] <- entity
      }
    }
  }
  for (axis in intersect(c("x", "y"), if (shared_axes == "both") c("x", "y") else shared_axes)) {
    ax <- lapply(contracts, function(c) c$axes[[axis]])
    if (any(vapply(ax, is.null, logical(1))) ||
        any(vapply(ax, function(x) any(c(x$quantity, x$unit, x$transform) %in% c("unknown", "not supplied")), logical(1))) ||
        !all(vapply(ax[-1], .os_panel_equal, logical(1), b = ax[[1]])))
      stop(paste0("OS_FIG_AXIS_INCOMPATIBLE: shared ", axis, " axes require identical quantity, unit, transform, limits and ticks."), call. = FALSE)
  }
  for (which in c("row", "col")) if (if (which == "row") linked_rows else linked_cols) {
    ids <- lapply(contracts, function(c) c[[paste0(which, "_ids")]])
    if (any(vapply(ids, is.null, logical(1))) || !all(vapply(ids[-1], identical, logical(1), y = ids[[1]])))
      stop("OS_FIG_ROW_MISMATCH: linked panels need identical explicit ID orders, including unavailable slots.", call. = FALSE)
  }
  reason <- "local guides requested"; effective <- FALSE
  if (collect_guides) {
    if (any(vapply(contracts, is.null, logical(1))) || any(vapply(contracts, function(c) !length(c$guides), logical(1)))) {
      reason <- "missing actual guide contract; legends remain local"
      warning(paste0("OS_FIG_GUIDE_LOCAL: ", reason), call. = FALSE)
    } else if (any(vapply(contracts, function(c) any(vapply(c$guides, function(g)
      if (g$kind == "continuous") any(c(g$quantity, g$unit, g$transform) %in% c("unknown", "not supplied")) else identical(g$entity_type, "unknown"), logical(1))), logical(1)))) {
      reason <- "quantity, units or entity identity are unverified; legends remain local"
      warning(paste0("OS_FIG_GUIDE_LOCAL: ", reason), call. = FALSE)
    } else if (alias) {
      reason <- "same colour represents different entities; legends remain local"
      warning(paste0("OS_FIG_GUIDE_LOCAL: ", reason), call. = FALSE)
    } else {
      guides <- lapply(contracts, `[[`, "guides")
      if (!all(vapply(guides[-1], .os_panel_equal, logical(1), b = guides[[1]])))
        stop("OS_FIG_GUIDE_INCOMPATIBLE: collected guides require identical quantity, units, transforms, limits, ticks and entity mappings.", call. = FALSE)
      effective <- TRUE; reason <- "all supplied guide contracts exactly match"
    }
  }
  list(requested = collect_guides, effective = effective, reason = reason, shared_axes = shared_axes,
       linked_rows = linked_rows, linked_cols = linked_cols, contracts = contracts)
}

os_compose <- function(plots, ncol = NULL, widths = NULL, heights = NULL, design = NULL, title = NULL,
                       journal = NULL, collect_guides = FALSE, shared_axes = c("none", "x", "y", "both"),
                       linked_rows = FALSE, linked_cols = FALSE) {
  jp <- os_journal(journal)
  n <- length(plots)
  if (!is.list(plots) || n < 1L || n > 26L) stop("OS_INVALID_INPUT: compose requires one to 26 panels.", call. = FALSE)
  shared_axes <- match.arg(shared_axes)
  compatibility <- .os_check_panel_contracts(plots, collect_guides, shared_axes, linked_rows, linked_cols)
  shared_guide <- if (compatibility$effective) .os_shared_guide_grob(plots[[1]]) else NULL
  if (n > 6) warning(sprintf("OS_FIG_TOO_MANY_PANELS: %d panels; the field median is 3-5 and > 6 usually means the figure should be split.", n), call. = FALSE)
  tags <- if (jp$tag_case == "lower") letters[seq_len(n)] else LETTERS[seq_len(n)]
  wrapped <- lapply(seq_len(n), function(i) {
    p <- plots[[i]]
    if (compatibility$effective) p <- if (inherits(p, "patchwork")) p & ggplot2::theme(legend.position = "none") else p + ggplot2::theme(legend.position = "none")
    # a patchwork sub-figure (heatmap, GSEA curve) is wrapped so it takes ONE tag;
    # the wrapper gets a top margin of one tag line, otherwise the letter is
    # drawn over the sub-figure's first row (e.g. a heatmap's annotation bar)
    if (inherits(p, "patchwork")) {
      patchwork::wrap_elements(full = p) +
        ggplot2::theme(plot.margin = ggplot2::margin(t = OS_FIG$size_tag * OS_FIG_TAG_MARGIN_LINES, unit = "pt"))
    } else p
  })
  comp <- patchwork::wrap_plots(wrapped, ncol = ncol, widths = widths, heights = heights, design = design,
                                guides = if (compatibility$effective) "collect" else "keep")
  comp <- comp + patchwork::plot_annotation(
    title = title, tag_levels = list(tags),
    subtitle = if (n > 1L) paste0(if (shared_axes == "none") "Independent panel axes" else paste("Shared", shared_axes, "axes"),
      if (!linked_rows && !linked_cols) "; independent object orders" else "; ID-linked object orders", if (!compatibility$effective) "; local legends" else "") else NULL,
    theme = ggplot2::theme(plot.title = ggplot2::element_text(size = OS_FIG$size_title + 1, face = "bold", hjust = 0,
                                                              family = os_font_family()),
                           plot.subtitle = ggplot2::element_text(size = max(jp$min_pt, OS_FIG$size_axis_text), hjust = 0, family = os_font_family()))
  ) & ggplot2::theme(plot.tag = ggplot2::element_text(size = OS_FIG$size_tag, face = jp$tag_face, hjust = 0, vjust = 1,
                                                       family = os_font_family(), colour = OS_FIG$col_ink),
                     plot.tag.position = c(0, 1))
  # Wrapped subfigures keep one tag, but patchwork cannot collect guides out of
  # their frozen grobs. Extract one verified actual guide before wrapping, hide
  # local guides, and allocate its physical width outside the data panels.
  if (!is.null(shared_guide)) {
    guide <- grid::grobTree(shared_guide, vp = grid::viewport(y = grid::unit(1, "npc"), just = "top", height = sum(shared_guide$heights)))
    comp <- patchwork::wrap_plots(list(patchwork::wrap_elements(full = comp), patchwork::wrap_elements(full = guide)), ncol = 2,
                                  widths = grid::unit.c(grid::unit(1, "null"), sum(shared_guide$widths) + grid::unit(2, "mm")))
  }
  compatibility$shared_legend_rendered <- !is.null(shared_guide)
  caps <- vapply(seq_len(n), function(i) (attr(plots[[i]], "os_meta") %||% list())$caption %||% "", character(1))
  legend <- paste(vapply(seq_len(n), function(i) paste0(if (jp$tag_case == "lower") paste0("**", tags[i], "**,") else paste0("(", tags[i], ")"), " ", caps[i]),
                         character(1)), collapse = " ")
  if (n > 1L) legend <- paste(legend,
    if (shared_axes == "none") "Panel axes are independent; compare their numerical scales, not visual heights." else paste0("Shared ", shared_axes, " axes have matching quantities, units, limits and ticks."),
    if (!linked_rows && !linked_cols) "Panel orders are independent; row position alone does not link objects." else "Linked panel axes use the same explicit IDs and order.",
    if (!compatibility$effective) paste0("Local legends: ", compatibility$reason, ".") else "Guide mappings were checked before collection.",
    "Populations, endpoints, horizons and validation scope remain specific to each panel.")
  panel_meta <- lapply(seq_len(n), function(i) {
    m <- attr(plots[[i]], "os_meta") %||% list()
    m$colour_registry <- NULL
    c(list(tag = tags[i]), m[setdiff(names(m), "caption")])
  })
  # A composite's own default height, so os_save_figure() does not fall back
  # to a generic width-derived height (which left a large blank canvas above
  # a short row of small panels, e.g. two 70 mm-tall PCA panels under a
  # "double"-width preset): panels are filled row by row (patchwork::wrap_plots
  # default), so the height is (number of rows) x (tallest panel in a row).
  # NULL when no panel carries its own default_height_mm, so the width-derived
  # fallback in os_save_figure still applies exactly as before.
  panel_h <- vapply(plots, function(p) (attr(p, "os_meta") %||% list())$default_height_mm %||% NA_real_, numeric(1))
  default_h <- if (all(is.na(panel_h))) NULL else {
    eff_ncol <- ncol %||% n
    rows <- ceiling(n / eff_ncol)
    ph <- ifelse(is.na(panel_h), mean(panel_h, na.rm = TRUE), panel_h)
    row_max <- vapply(split(ph, ceiling(seq_len(n) / eff_ncol)), max, numeric(1))
    sum(row_max[seq_len(rows)])
  }
  attr(comp, "os_meta") <- list(figure_type = "composite", caption = legend, default_height_mm = default_h,
                                data = list(panels = panel_meta, n_panels = n), definition = list(composition = compatibility))
  comp
}

# Convenience: build, lint and save in one call. Returns the save result
# plus the lint table; blocker lint findings stop the save.
os_finalize_figure <- function(plot, out_stem, width = "single", height_mm = NULL, journal = NULL,
                               formats = c("pdf", "png"), root = NULL) {
  lint <- os_fig_lint(plot, journal)
  if (any(lint$severity == "blocker")) {
    stop("OS_FIG_LINT_BLOCKER: ", paste(lint$rule[lint$severity == "blocker"], lint$message[lint$severity == "blocker"],
                                        sep = ": ", collapse = "; "), call. = FALSE)
  }
  res <- os_save_figure(plot, out_stem, width = width, height_mm = height_mm, journal = journal,
                        formats = formats, root = root,
                        extra_meta = list(lint = if (nrow(lint)) lapply(seq_len(nrow(lint)), function(i) as.list(lint[i, ])) else list()))
  res$lint <- lint
  invisible(res)
}
