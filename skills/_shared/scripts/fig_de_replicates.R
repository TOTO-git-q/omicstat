# Replicate-source displays. These functions never fit a model, infer pairing,
# convert cells into replicate n, or add a test to a selected-feature display.
.os_replicate_strings <- function(x, what) {
  if ((!is.character(x) && !is.factor(x)) || anyNA(x) || any(!nzchar(as.character(x))))
    .os_de_error(paste(what, "requires explicit nonmissing string IDs"))
  as.character(x)
}

os_selected_feature_points <- function(d, selected_features, selection_reason,
    normalization, unit, reference, subject_col = NULL, pair_col = NULL,
    source_scale = "linear", display_transform = "identity", group_order = NULL,
    order_by = "declared", show_box = TRUE, model_results = NULL,
    colour_registry = NULL, journal = NULL) {
  .os_require_cols(d, c("feature_id", "sample", "group", "value"), "selected-feature points")
  source <- d
  for (k in c("feature_id", "sample", "group")) d[[k]] <- .os_replicate_strings(d[[k]], k)
  keys <- .os_sem_rows(d, c("feature_id", "sample"))
  selected_features <- .os_sem_ids(selected_features, "selected feature IDs")
  if (!all(selected_features %in% d$feature_id)) .os_de_error("a requested feature is absent from the actual sample-value source")
  for (k in c("selection_reason", "normalization", "unit", "reference")) .os_de_scalar(get(k), k)
  if (!is.numeric(d$value) || any(is.infinite(d$value))) .os_de_error("sample values must be finite numeric values or explicit missing")
  if (!source_scale %in% c("linear", "log2", "log10") ||
      !display_transform %in% c("identity", "log2", "log10") ||
      (source_scale != "linear" && display_transform != "identity")) .os_de_error("selected-feature source/display scales would double-log or mislabel values")
  if (length(show_box) != 1L || !is.logical(show_box) || is.na(show_box)) .os_de_error("show_box must be logical")
  map <- unique(d[, c("sample", "group"), drop = FALSE])
  if (anyDuplicated(map$sample)) .os_de_error("a sample maps to multiple groups")
  for (k in c(subject_col, pair_col)) {
    .os_require_cols(d, k, "declared biological or pair IDs")
    d[[k]] <- .os_replicate_strings(d[[k]], k)
    m <- unique(d[, c("sample", k), drop = FALSE])
    if (anyDuplicated(m$sample)) .os_de_error("a sample maps to multiple biological or pair IDs")
  }
  if (!is.null(pair_col)) {
    pairs <- unique(d[, c("sample", "group", pair_col), drop = FALSE])
    if (anyDuplicated(pairs[, c("group", pair_col), drop = FALSE]))
      .os_de_error("pair lines need at most one actual sample per pair and group; aggregate technical repeats upstream explicitly")
    if (!is.null(subject_col)) {
      m <- unique(d[, c(pair_col, subject_col), drop = FALSE])
      if (anyDuplicated(m[[pair_col]])) .os_de_error("a declared pair contains different biological subjects")
    }
  }
  rows <- d$feature_id %in% selected_features
  shown <- d[rows, , drop = FALSE]; shown$.source_id <- keys[rows]
  shown$.state <- ifelse(is.na(shown$value), "missing_value", "shown")
  if (display_transform != "identity") shown$.state[!is.na(shown$value) & shown$value <= 0] <- "nonpositive_for_log"
  shown$.display_value <- shown$value
  shown$.display_value[shown$.state != "shown"] <- NA_real_
  if (display_transform == "log2") shown$.display_value <- log2(shown$.display_value)
  if (display_transform == "log10") shown$.display_value <- log10(shown$.display_value)
  groups <- unique(shown$group)
  if (!order_by %in% c("declared", "median")) .os_de_error("selected-feature ordering must be declared or median")
  if (order_by == "median") {
    if (length(selected_features) != 1L || !is.null(group_order)) .os_de_error("median group ordering is available for one selected feature and cannot override an explicit order")
    med <- vapply(groups, function(g) {x <- shown$value[shown$group == g]; if (all(is.na(x))) Inf else stats::median(x, na.rm = TRUE)}, numeric(1))
    group_order <- groups[order(med, groups, method = "radix")]
  } else group_order <- group_order %||% sort(groups, method = "radix")
  .os_sem_ids(group_order, "group order")
  if (!setequal(group_order, groups)) .os_de_error("group order must contain each displayed source group once")
  if (reference != "unknown" && !reference %in% groups) .os_de_error("declared reference is absent from the selected source groups")
  summary <- do.call(rbind, lapply(selected_features, function(f) do.call(rbind, lapply(group_order, function(g) {
    z <- shown[shown$feature_id == f & shown$group == g, , drop = FALSE]
    good <- z$.state == "shown"; v <- z$.display_value[good]
    data.frame(feature_id = f, group = g, n_source_samples = length(unique(z$sample)),
      n_visible_samples = sum(good), n_missing = sum(z$.state == "missing_value"),
      n_nonpositive_for_log = sum(z$.state == "nonpositive_for_log"),
      n_subjects = if (is.null(subject_col)) NA_integer_ else length(unique(z[[subject_col]])),
      median = if (length(v)) stats::median(v) else NA_real_,
      q25 = if (length(v)) unname(stats::quantile(v, .25, type = 7)) else NA_real_,
      q75 = if (length(v)) unname(stats::quantile(v, .75, type = 7)) else NA_real_,
      stringsAsFactors = FALSE)
  }))))
  sample_order <- sort(unique(shown$sample), method = "radix")
  # Small deterministic offsets preserve every sample and remain stable across
  # selected-feature panels. No random draw or sample matching is inferred.
  offsets <- stats::setNames(vapply(sample_order, function(s) {
    g <- map$group[match(s, map$sample)]; ids <- sample_order[sample_order %in% map$sample[map$group == g]]
    if (length(ids) == 1L) 0 else seq(-.17, .17, length.out = length(ids))[match(s, ids)]
  }, numeric(1)), sample_order)
  shown$.x <- match(shown$group, group_order) + unname(offsets[shown$sample])
  shown$feature_id <- factor(shown$feature_id, levels = selected_features)
  reg <- os_colours_for(selected_features, "selected_feature_identity", colour_registry)
  p <- ggplot2::ggplot(shown[shown$.state == "shown", , drop = FALSE],
    ggplot2::aes(x = .x, y = .display_value, colour = feature_id))
  if (!is.null(pair_col)) {
    paired <- shown[shown$.state == "shown", , drop = FALSE]
    paired$.pair <- vapply(seq_len(nrow(paired)), function(i) as.character(jsonlite::toJSON(
      c(as.character(paired$feature_id[i]), paired[[pair_col]][i]), auto_unbox = FALSE)), "")
    paired <- paired[paired$.pair %in% names(which(table(paired$.pair) > 1L)), , drop = FALSE]
    paired <- paired[order(paired$.pair, paired$.x, method = "radix"), , drop = FALSE]
    if (nrow(paired)) p <- p + ggplot2::geom_line(data = paired, ggplot2::aes(group = .pair),
      colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref))
  }
  box_rows <- shown[shown$.state == "shown", , drop = FALSE]
  n_key <- paste(summary$feature_id, summary$group, sep = "\r")
  box_rows <- box_rows[summary$n_visible_samples[match(paste(box_rows$feature_id, box_rows$group, sep = "\r"), n_key)] >= 5L, , drop = FALSE]
  if (show_box && nrow(box_rows)) p <- p + ggplot2::geom_boxplot(data = box_rows,
    ggplot2::aes(x = match(group, group_order), group = interaction(feature_id, group)),
    width = .55, outlier.shape = NA, fill = NA, linewidth = os_lw(OS_FIG$lw_data))
  p <- p + ggplot2::geom_point(size = OS_FIG$pt_sample_mm) +
    ggplot2::scale_colour_manual(values = reg$colours, limits = selected_features, guide = "none") +
    ggplot2::scale_x_continuous(breaks = seq_along(group_order), labels = group_order,
      limits = c(.5, length(group_order) + .5)) +
    ggplot2::facet_wrap(~feature_id, ncol = min(2L, length(selected_features)), scales = "free_y") +
    ggplot2::labs(x = if (order_by == "median") "Groups ordered by median expression; not time or disease stage" else "Declared group",
      y = paste0(unit, if (display_transform == "identity") "" else paste0(" (", display_transform, " display)")),
      subtitle = os_wrap(paste0("Normalization: ", normalization, "; reference: ", reference), 62)) +
    theme_omicstat(journal = journal, legend = "none")
  if (!is.null(model_results)) {
    .os_require_cols(model_results, c("feature_id", "value", "statistic_kind", "test_id", "method", "family_id"), "existing model result annotations")
    .os_sem_rows(model_results, c("feature_id", "test_id"))
    if (!all(model_results$feature_id %in% selected_features) || !is.numeric(model_results$value) ||
        any(!is.na(model_results$value) & (!is.finite(model_results$value) | model_results$value < 0 | model_results$value > 1)) ||
        any(!model_results$statistic_kind %in% c("raw_p", "adjusted_p", "qvalue"))) .os_de_error("existing model result annotations need actual selected IDs and typed P/q values")
    for (k in c("test_id", "method", "family_id")) .os_replicate_strings(model_results[[k]], k)
  }
  source <- d
  layer <- os_semantic_layer("sample_values", source, c("feature_id", "sample"), "observed",
    "normalized feature abundance", unit, independent_ids = if (is.null(subject_col)) NULL else source[[subject_col]],
    independent_unit = if (is.null(subject_col)) "unknown" else "declared biological subject",
    population_id = "selected_feature_source", value_columns = "value")
  definition <- os_figure_definition("normalized feature abundance", "feature-sample measurement",
    layer$independent_unit, unit, list(status = "known", rule = "complete supplied feature-sample source", ids = as.list(keys)),
    list(status = "known", rule = "explicit selected feature IDs; missing/domain exclusions retained separately", ids = as.list(keys[rows])),
    "none across biological or technical samples; optional box summaries are descriptive", list(layer),
    notes = list(selected_features = as.list(selected_features), selection_reason = selection_reason,
      normalization = normalization, reference = reference, source_scale = source_scale,
      display_transform = display_transform, zero_policy = if (display_transform == "identity") "retained unchanged" else "excluded from logarithmic coordinates with explicit source/state retention",
      subject_column = subject_col, pair_column = pair_col, sample_order = as.list(sample_order),
      group_order = as.list(group_order), ordering_basis = order_by,
      panel_y_scales = "free per feature; no cross-feature magnitude equivalence implied",
      box_definition = "median, type-7 quartiles and 1.5-IQR whiskers; no box for fewer than five visible samples; not a CI",
      model_annotations = if (is.null(model_results)) "none supplied; no test calculated" else "existing supplied model results only; no new selected-sample test"))
  os_with_meta(p, figure_type = "selected_feature_points", default_height_mm = 65 * ceiling(length(selected_features)/2),
    caption = paste0("Every visible point is an actual supplied sample value. Normalization: ", normalization,
      "; reference: ", reference, "; source scale: ", source_scale, ". Selected feature IDs and reason are retained: ", selection_reason,
      ". Panels use separate y scales. These selected examples do not establish genome-wide performance. All small-n points remain visible; boxes, where present, are descriptive median/IQR summaries, not confidence intervals. ",
      if (is.null(subject_col)) "Sample labels do not establish independent biological-subject n. " else "Repeated samples from one subject do not increase biological-subject n. ",
      if (is.null(pair_col)) "No pairing was supplied, so there are no connecting sample lines. " else "Lines connect only actual declared pair IDs; pairing is not inferred from position. ",
      "No new statistical test is computed."), definition = definition,
    counts = list(n_selected_features = length(selected_features), n_source_rows = nrow(d),
      n_selected_samples = length(unique(shown$sample)), n_subjects = if (is.null(subject_col)) NULL else length(unique(shown[[subject_col]])),
      n_visible_points = sum(shown$.state == "shown"), n_missing = sum(shown$.state == "missing_value"), n_log_excluded = sum(shown$.state == "nonpositive_for_log")),
    data = list(raw_source = d, selected_values = shown, group_summary = summary, model_results = model_results),
    notes = list(numeric_precision = "binary64_roundtrip", no_new_inference = TRUE), colour_registry = reg$registry)
}

os_pseudobulk_eligibility <- function(d, conditions, min_cells, donor_col = NULL,
    sample_order = NULL, subtype_order = NULL, journal = NULL) {
  .os_require_cols(d, c("sample", "subtype", "condition", "n_cells", "library_size", "state", "reason"), "pseudobulk eligibility")
  for (k in c("sample", "subtype", "condition", "state", "reason")) d[[k]] <- .os_replicate_strings(d[[k]], k)
  ids <- .os_sem_rows(d, c("sample", "subtype"))
  conditions <- .os_sem_ids(conditions, "conditions")
  if (!setequal(unique(d$condition), conditions) || !is.numeric(min_cells) || length(min_cells) != 1L ||
      !is.finite(min_cells) || min_cells < 0 || min_cells != floor(min_cells)) .os_de_error("actual conditions and minimum cell threshold are required")
  states <- c("fitted", "zero_cell", "below_min_cells", "zero_library", "not_fitted", "prep_excluded")
  if (!all(d$state %in% states) || !is.numeric(d$n_cells) || anyNA(d$n_cells) || any(d$n_cells < 0 | d$n_cells != floor(d$n_cells)) ||
      !is.numeric(d$library_size) || any(!is.na(d$library_size) & (!is.finite(d$library_size) | d$library_size < 0))) .os_de_error("invalid pseudobulk cell/library counts or native eligibility state")
  map <- unique(d[, c("sample", "condition"), drop = FALSE])
  if (anyDuplicated(map$sample)) .os_de_error("pseudobulk sample maps to multiple conditions")
  if (!is.null(donor_col)) {
    .os_require_cols(d, donor_col, "donor mapping"); d[[donor_col]] <- .os_replicate_strings(d[[donor_col]], donor_col)
    if (anyDuplicated(unique(d[, c("sample", donor_col), drop = FALSE])$sample)) .os_de_error("one sample maps to multiple donors")
  }
  samples <- sample_order %||% unlist(lapply(conditions, function(g) sort(map$sample[map$condition == g], method = "radix")))
  subtypes <- subtype_order %||% sort(unique(d$subtype), method = "radix")
  .os_sem_ids(samples, "pseudobulk sample order"); .os_sem_ids(subtypes, "pseudobulk subtype order")
  if (!setequal(samples, map$sample) || !setequal(subtypes, unique(d$subtype)) || nrow(d) != length(samples)*length(subtypes))
    .os_de_error("eligibility display requires a complete explicit sample-by-subtype grid and exact ID orders")
  if (any(d$state == "zero_cell" & d$n_cells != 0) || any(d$state == "below_min_cells" & (d$n_cells <= 0 | d$n_cells >= min_cells)) ||
      any(d$state == "zero_library" & !(d$library_size %in% 0 |
        (if ("fitted_feature_library_size" %in% names(d)) d$fitted_feature_library_size %in% 0 else FALSE))) ||
      any(d$state == "fitted" & (d$n_cells == 0 | is.na(d$library_size) | d$library_size <= 0))) .os_de_error("eligibility state contradicts its actual counts")
  summary <- do.call(rbind, lapply(subtypes, function(cl) do.call(rbind, lapply(conditions, function(g) {
    z <- d[d$subtype == cl & d$condition == g, , drop = FALSE]; fit <- z$state == "fitted"
    data.frame(subtype = cl, condition = g, n_samples = length(unique(z$sample)),
      n_fitted_samples = length(unique(z$sample[fit])),
      n_fitted_donors = if (is.null(donor_col)) NA_integer_ else length(unique(z[[donor_col]][fit])),
      n_cells = sum(z$n_cells), n_fitted_cells = sum(z$n_cells[fit]), stringsAsFactors = FALSE)
  }))))
  plot <- d; plot$sample <- factor(plot$sample, levels = samples); plot$subtype <- factor(plot$subtype, levels = rev(subtypes))
  plot$condition <- factor(plot$condition, levels = conditions)
  palette <- c(fitted = OS_PAL_GROUP[1], zero_cell = "#FFFFFF", below_min_cells = OS_PAL_GROUP[2],
    zero_library = OS_PAL_GROUP[3], not_fitted = "#BDBDBD", prep_excluded = "#666666")
  backgrounds <- unname(palette[as.character(plot$state)])
  plot$.text_colour <- ifelse(os_text_contrast_ratio(rep("#FFFFFF", length(backgrounds)), backgrounds) >
    os_text_contrast_ratio(rep(OS_FIG$col_ink, length(backgrounds)), backgrounds), "#FFFFFF", OS_FIG$col_ink)
  used <- states[states %in% d$state]
  p <- ggplot2::ggplot(plot, ggplot2::aes(sample, subtype, fill = state)) +
    ggplot2::geom_tile(colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref)) +
    ggplot2::geom_text(ggplot2::aes(label = n_cells, colour = .text_colour), size = os_fs(OS_FIG$size_annot),
      family = os_font_family()) + ggplot2::scale_colour_identity() +
    ggplot2::facet_grid(~condition, scales = "free_x", space = "free_x") +
    ggplot2::scale_fill_manual(values = palette, breaks = used, limits = used,
      labels = c(fitted = "Included in fitted model", zero_cell = "No source cells", below_min_cells = "Below cell threshold",
        zero_library = "Zero count library", not_fitted = "Not fitted", prep_excluded = "Removed in preparation")[used]) +
    ggplot2::labs(x = "Actual sample ID", y = "Subtype", fill = "Native sample state",
      subtitle = "Tile labels: aggregated cells; cells are not replicate n") +
    theme_omicstat(journal = journal, legend = "bottom") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE))
  summary_plot <- summary
  summary_plot$condition <- factor(summary_plot$condition,levels=conditions)
  summary_plot$subtype <- factor(summary_plot$subtype,levels=rev(subtypes))
  summary_plot$.label <- paste0("Samples: ",summary_plot$n_fitted_samples,
    if(is.null(donor_col)) "; donors: unknown" else paste0("; donors: ",summary_plot$n_fitted_donors))
  count_panel <- ggplot2::ggplot(summary_plot,ggplot2::aes(condition,subtype,label=.label)) +
    ggplot2::geom_text(size=os_fs(OS_FIG$size_annot),family=os_font_family(),colour=OS_FIG$col_ink) +
    ggplot2::scale_x_discrete(drop=FALSE,expand=ggplot2::expansion(add=.7)) +
    ggplot2::scale_y_discrete(drop=FALSE,expand=ggplot2::expansion(add=.6)) +
    ggplot2::labs(x=NULL,y=NULL,subtitle="Actual fitted sample / donor counts") +
    theme_omicstat(journal=journal,legend="none") +
    ggplot2::theme(axis.line=ggplot2::element_blank(),axis.ticks=ggplot2::element_blank())
  main_height <- 35+8*length(subtypes); summary_height <- 14+5*length(subtypes)
  p <- patchwork::wrap_plots(p,count_panel,ncol=1,heights=c(main_height,summary_height))
  layer <- os_semantic_layer("sample_subtype_eligibility", d, c("sample", "subtype"), "aggregate",
    "native pseudobulk sample eligibility", "cells and library counts", independent_ids = if (is.null(donor_col)) NULL else d[[donor_col]],
    independent_unit = if (is.null(donor_col)) "unknown" else "declared donor", value_columns = c("n_cells", "library_size"))
  definition <- os_figure_definition("native pseudobulk sample eligibility", "sample-subtype aggregate", layer$independent_unit,
    "cells and library counts", list(status = "known", rule = "complete supplied sample-by-subtype grid", ids = as.list(ids)),
    list(status = "known", rule = "all eligible/excluded source states are displayed", ids = as.list(ids)),
    "cell counts are aggregated within sample-subtype; no biological n is summed across subtypes", list(layer),
    notes = list(min_cells = min_cells, donor_column = donor_col, sample_order = as.list(samples), subtype_order = as.list(subtypes),
      fitted_scope = "membership comes from actual backend fitted-data sample IDs; not the prefilter metadata table"))
  os_with_meta(p, figure_type = "pseudobulk_eligibility", default_height_mm = main_height+summary_height,
    caption = paste0("Each tile is one real sample-by-subtype source slot. Labels count cells retained for aggregation, never biological replicates; original input-cell counts, when available, remain separately in the source table. ",
      "Excluded slots retain their actual reason and library value, not a fabricated zero. A separate count panel and exported summary give actual fitted sample and donor counts by condition/subtype. ",
      if (is.null(donor_col)) "Donor mapping was not supplied; sample labels alone do not prove biological independence. " else "Donor counts are deduplicated within each condition/subtype and globally; repeated subtypes do not create donors. ",
      "Fitted membership does not imply that every feature has an available test result. This display performs no statistical test."),
    definition = definition, counts = list(n_samples = length(samples), n_subtypes = length(subtypes),
      n_donors = if (is.null(donor_col)) NULL else length(unique(d[[donor_col]])), n_aggregated_cells = sum(d$n_cells),
      n_fitted_slots = sum(d$state == "fitted"), state_counts = as.list(table(d$state))),
    data = list(raw_source = d, summary = summary), notes = list(numeric_precision = "binary64_roundtrip", no_new_inference = TRUE,
      cell_label_contrast_min = min(os_text_contrast_ratio(plot$.text_colour,backgrounds))))
}
