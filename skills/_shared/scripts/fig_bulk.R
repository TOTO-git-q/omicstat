# fig_bulk.R -- standard bulk-omics figures: volcano, MA, sample PCA, sample
# distance heatmap, top-feature heatmap, generic diagnostic scatter/line.
# ASCII only on purpose. Requires fig_style.R and fig_heatmap.R.
#
# Every builder:
#   * takes a tidy table (feature_table columns where applicable),
#   * reads every visual constant from OS_FIG / OS_PAL_* (fig_style.R),
#   * returns a ggplot/patchwork with attr "os_meta" (figure_type, caption,
#     encodings, thresholds, counts, data rows used) for os_save_figure(),
#   * is deterministic: row order, label choice and z-order are fully
#     specified below, and ggrepel gets a fixed seed.

if (!exists("OS_FIG_STYLE_VERSION")) stop("OS_MISSING_DEPENDENCY: source fig_style.R before fig_bulk.R.", call. = FALSE)
if (!requireNamespace("ggrepel", quietly = TRUE)) stop("OS_MISSING_PACKAGE: ggrepel is required by fig_bulk.R.", call. = FALSE)


.os_require_cols <- function(df, cols, fn) {
  miss <- setdiff(cols, names(df))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: %s needs column(s) %s.", fn, paste(miss, collapse = ", ")), call. = FALSE)
}

# Direction class used by volcano and MA (identical rule in both).
os_de_class <- function(log2fc, padj, padj_threshold, lfc_threshold, statistic_kind = "adjusted_p",
                        test_contract = NULL, tested_log2fc = log2fc, p_operator = "<", display_operator = ">",
                        return_details = FALSE) {
  x <- .os_de_decision_values(log2fc, padj, padj_threshold, lfc_threshold, statistic_kind,
                             test_contract, tested_log2fc, p_operator, display_operator)
  if (isTRUE(return_details)) x else x$de_class
}

# Deterministic label selection: top n per direction by padj, ties broken by
# |log2fc| (larger first) then feature_id (C-locale).
os_pick_labels <- function(df, n_per_side = 10, genes = NULL) {
  if (!is.null(genes)) {
    hit <- df$feature_id %in% genes | (!is.null(df$symbol) & df$symbol %in% genes)
    return(df$feature_id[hit])
  }
  pick <- character(0)
  for (d in c("up", "down", "within_margin")) {
    s <- df[df$de_class == d, , drop = FALSE]
    if (!nrow(s)) next
    o <- order(s$padj, -abs(s$log2fc), s$feature_id, method = "radix")
    pick <- c(pick, s$feature_id[utils::head(o, n_per_side)])
  }
  pick
}

.os_display_symbol <- function(df) {
  sym <- if ("symbol" %in% names(df)) as.character(df$symbol) else rep(NA_character_, nrow(df))
  ifelse(is.na(sym) | !nzchar(sym), as.character(df$feature_id), sym)
}

.os_count_key <- function(p, x, y, hjust, colour, text) {
  fam <- os_font_family()
  gap <- 0.0
  p + ggplot2::annotate("point", x = x, y = y, colour = colour, size = OS_FIG$pt_highlight_mm * 1.6, shape = 16) +
    ggplot2::annotate("text", x = x, y = y, label = text, hjust = hjust, vjust = 0.5,
                      size = os_fs(OS_FIG$size_annot), family = fam, colour = OS_FIG$col_ink)
}

# Label data for volcano / MA (os_label_place, fig_style.R sec 12b): the
# labelled points in priority order, then the most significant other
# coloured points as unlabelled obstacles (label ""), so labels stay off the
# coloured point cloud and off each other. Added 2026-09-27 after the pasilla
# anchor (8,148 genes) showed ggrepel label-label overlaps in the container.
# Volcano and MA get their panel shape from the figure height, not from a
# fixed theme(aspect.ratio).
OS_LABEL_MAX_OBSTACLES <- 300L
.os_label_rows <- function(d, lab, priority) {
  lab <- lab[order(priority, lab$feature_id, method = "radix"), , drop = FALSE]
  rep <- d[!d$feature_id %in% lab$feature_id & d$de_class %in% c("up", "down", "within_margin"), , drop = FALSE]
  rep <- rep[order(rep$padj, rep$feature_id, method = "radix"), , drop = FALSE]
  rep <- utils::head(rep, OS_LABEL_MAX_OBSTACLES)
  rep$display <- rep("", nrow(rep))
  rbind(lab[, c("x", "y", "display")], rep[, c("x", "y", "display")])
}

# ---------------------------------------------------------------------------
# Volcano plot
# ---------------------------------------------------------------------------
# Source statistic, tested hypothesis and plotted estimator are separate contracts.
# Missing-statistic rows retain native reasons and never count as nonsignificant.
# Display caps/selection and annotation colours cannot overwrite source values.
os_volcano <- function(ft, padj_threshold = 0.05, lfc_threshold = 1, label_n = 10, label_genes = NULL,
                       x_max = NULL, y_max = NULL, contrast_label = NULL, method_label = NULL,
                       italic_labels = TRUE, journal = NULL, statistic_kind = "adjusted_p",
                       statistic_col = "padj", statistic_method = "unknown", adjustment = "unknown",
                       family_id = "unknown", family_size = NULL, test_contract = NULL,
                       effect_provenance = NULL, p_operator = "<", display_operator = ">",
                       colour_mode = "decision", annotation_col = NULL, annotation_title = NULL,
                       annotation_levels = NULL, colour_registry = NULL, tercile_cutpoints = NULL,
                       annotation_denominator = NULL, family_source_ids = NULL) {
  prepared <- .os_de_prepare(ft, padj_threshold, lfc_threshold, statistic_kind, statistic_col,
    statistic_method, adjustment, family_id, family_size, test_contract, effect_provenance, p_operator, display_operator, family_source_ids)
  ann <- .os_de_annotation(ft, colour_mode, annotation_col, annotation_title, annotation_levels, colour_registry, tercile_cutpoints)
  if (is.null(ann) && !is.null(annotation_denominator)) .os_de_error("category ratios require an actual annotation colour mode")
  original_ft <- ft; d <- ft; d$padj <- ft[[statistic_col]]
  for (k in setdiff(names(prepared$decision), "feature_id")) d[[k]] <- prepared$decision[[k]]
  d$.colour <- if (is.null(ann)) d$de_class else ann$values
  shown <- is.finite(d$log2fc) & !is.na(d$padj)
  excluded <- data.frame(feature_id = d$feature_id[!shown], reason = ifelse(is.na(d$padj[!shown]), paste0("statistic_unavailable:", d$test_state[!shown]), "nonfinite_plotted_effect"), stringsAsFactors = FALSE)
  d <- d[shown, , drop = FALSE]
  for (v in list(x_max, y_max)) if (!is.null(v) && (length(v) != 1L || !is.finite(v) || v <= 0)) .os_de_error("volcano display limits must be positive finite values")
  d$raw_neglog10 <- -log10(d$padj)
  finite_y <- d$raw_neglog10[is.finite(d$raw_neglog10)]
  y_cap <- y_max %||% if (any(!is.finite(d$raw_neglog10))) ceiling(max(finite_y, 1) * 1.05) else NULL
  x_lim <- x_max %||% os_sym_limit(d$log2fc, min_abs = max(lfc_threshold * 1.5, 1))
  upper <- !is.finite(d$raw_neglog10) | d$raw_neglog10 > (y_cap %||% Inf)
  d$cap_direction <- ifelse(d$log2fc < -x_lim, "left", ifelse(d$log2fc > x_lim, "right", ifelse(upper, "upper", "none")))
  d$capped <- d$cap_direction != "none"; d$x <- pmax(pmin(d$log2fc, x_lim), -x_lim)
  d$y <- d$raw_neglog10
  if (!is.null(y_cap)) d$y[upper] <- y_cap
  d$z <- ifelse(d$de_class == "ns", 0, 1)
  d <- d[order(d$z, d$y, abs(d$log2fc), d$feature_id, method = "radix"), , drop = FALSE]
  d$display <- .os_display_symbol(d)
  lab <- d[d$feature_id %in% os_pick_labels(d, label_n, label_genes), , drop = FALSE]
  os_assert_latin(lab$display, "volcano labels")
  pal <- if (is.null(ann)) .os_de_class_palette() else ann$colours
  alpha_line <- if (padj_threshold > 0) -log10(padj_threshold) else NULL
  y_dmax <- max(c(d$y, alpha_line, 1), na.rm = TRUE); y_top <- y_dmax * 1.16
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y))
  if (!is.null(alpha_line)) p <- p + os_hline(alpha_line)
  margin <- prepared$definition$test$margin
  p <- .os_de_effect_lines(p, margin, lfc_threshold, "x")
  p <- .os_de_points(p, d, lab, pal, journal, italic_labels, -lab$y, ymax = y_dmax * 1.05,
    colour_title = if (!is.null(ann)) ann$title else if (!is.null(test_contract)) "Statistical decision" else NULL,
    colour_levels = if (is.null(ann)) names(pal) else ann$levels,
    colour_breaks = if (is.null(ann)) intersect(names(pal),unique(d$de_class[d$de_class != "na"])) else ann$levels,
    colour_labels = if (is.null(ann)) .os_de_class_labels() else NULL)
  stat_text <- switch(statistic_kind, raw_p = "unadjusted P", adjusted_p = "adjusted P", qvalue = "q value")
  estimator <- prepared$definition$effect$plotted_estimator
  effect_label <- .os_de_effect_axis(estimator)
  p <- p + ggplot2::scale_x_continuous(limits = c(-x_lim, x_lim), labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::scale_y_continuous(limits = c(0, y_top), labels = os_axis_labels, expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(x = effect_label, y = if (statistic_kind == "adjusted_p") OS_AXIS$neglog10padj else paste0("-log10(", stat_text, ")"), title = contrast_label) +
    theme_omicstat(journal = journal, legend = "bottom") + .os_de_guide_layout()
  n_up <- sum(d$de_class == "up"); n_down <- sum(d$de_class == "down"); n_ns <- sum(d$de_class == "ns"); n_within <- sum(d$de_class == "within_margin")
  n_undirected <- sum(d$de_class == "supported_undirected")
  family <- os_font_family(); xr <- 2*x_lim
  if (prepared$definition$test$hypothesis == "small_effect") {
    p <- p + ggplot2::annotate("text", x = 0, y = y_top*0.985, label = paste0("Shown within margin: ", n_within), size = os_fs(OS_FIG$size_annot), family = family)
  } else {
    if (is.null(ann)) {
      p <- .os_count_key(p, -x_lim+0.03*xr, y_top*0.985, 0, OS_FIG$col_down, "")
      p <- .os_count_key(p, x_lim-0.03*xr, y_top*0.985, 1, OS_FIG$col_up, "")
    }
    p <- p + ggplot2::annotate("text", x = -x_lim+0.065*xr, y = y_top*0.985, hjust = 0, label = sprintf("Shown down: %s", os_num(n_down)), size = os_fs(OS_FIG$size_annot), family = family) +
      ggplot2::annotate("text", x = x_lim-0.065*xr, y = y_top*0.985, hjust = 1, label = sprintf("Shown up: %s", os_num(n_up)), size = os_fs(OS_FIG$size_annot), family = family)
  }
  decision_label <- if (is.null(test_contract)) "display-selected" else "statistically supported"
  colour_text <- if (!is.null(ann)) paste0("Colour denotes ", ann$title, ", independently of statistical calls. Missing annotation is neutral grey, not a nonsignificance claim. ") else if (prepared$definition$test$hypothesis == "small_effect") paste0("Green, within-margin evidence (n = ", n_within, "); grey, inconclusive (n = ", n_ns, "). ") else paste0("Red, ", decision_label, " positive direction (n = ", os_num(n_up), "); blue, ", decision_label, " negative direction (n = ", os_num(n_down), "); grey, ", if (is.null(test_contract)) "not display-selected" else "inconclusive", " (n = ", n_ns, "). ")
  cap <- paste0("Volcano plot", if (!is.null(contrast_label)) paste0(" (", contrast_label, ")"), ". Each point is one feature; ", nrow(d), " shown of ", nrow(ft), " supplied. ",
    colour_text, .os_de_caption(prepared$definition), if (!is.null(method_label)) paste0("Method label: ", method_label, ". "),
    if (is.null(ann) && n_undirected > 0) paste0("Purple, statistically supported with zero or unavailable tested direction (n = ", n_undirected, "); these are not inconclusive. "),
    "The dashed horizontal line marks the statistic threshold. Effect-line labels give log2 values: dotted = effect margin, dashed = display filter, dot-dash = coincident margin and display filter. ",
    if (is.null(label_genes)) paste0("The ", label_n, " most significant features per direction or decision category are labelled. ") else "Labelled feature IDs were pre-specified. ",
    nrow(excluded), " features not drawn: ", paste(paste(names(table(excluded$reason)), as.integer(table(excluded$reason)), sep = "="), collapse = "; "), ". ",
    if (any(d$capped)) "Boundary glyphs point outward; if both axes overflow, the horizontal glyph takes priority and both flags remain in the numeric table. ",
    if (any(ft[[statistic_col]] == 0, na.rm = TRUE)) "Reported P = 0 is displayed at the upper cap; original precision/underflow is unknown and the raw zero is retained. ")
  counts <- c(list(up = n_up, down = n_down, ns = n_ns, within_margin = n_within, supported_undirected = n_undirected, padj_na = sum(is.na(ft[[statistic_col]])), capped = sum(d$capped),
    n_displayed = nrow(d), n_excluded = nrow(excluded)), prepared$counts)
  audit <- d[, c("feature_id", "log2fc", "raw_neglog10", "x", "y", "de_class", "statistical_call", "display_selected", "capped", "cap_direction", ".colour")]
  audit$upper_overflow <- !is.finite(audit$raw_neglog10) | audit$raw_neglog10 > (y_cap %||% Inf)
  prepared$definition$annotation <- if (is.null(ann)) NULL else ann$definition
  category_counts <- if (is.null(ann)) NULL else .os_de_category_counts(prepared$decision, ann$values, annotation_denominator)
  figure_height <- if (is.null(ann) && !is.null(test_contract)) 112 else 92
  if (!is.null(category_counts)) {
    band <- .os_de_category_band(category_counts,ann$levels,ann$colours,prepared$definition$test$hypothesis,journal)
    band_height <- 14 + 4*length(ann$levels)
    p <- patchwork::wrap_plots(p,band,ncol=1,heights=c(92,band_height))
    figure_height <- figure_height + band_height
    cap <- paste0(cap,"A separate count band describes all supplied finite-statistic tests, including coordinate exclusions; it is not the display-selected subset. Each entry gives numerator/denominator and the corresponding percentage; an empty denominator is undefined. Denominator rule: ",category_counts[[1]]$denominator_definition,". ")
  }
  out <- os_with_meta(p, figure_type = "volcano", default_height_mm = figure_height, caption = cap,
    encodings = list(colour = as.list(pal), shape = list(point = OS_FIG$shape_dense, upper = 24, left = 60, right = 62)),
    thresholds = list(padj = padj_threshold, abs_log2fc = lfc_threshold, effect_margin = margin, p_operator = p_operator, display_operator = display_operator),
    counts = counts, definition = list(de_contract = prepared$definition),
    data = list(labelled_feature_ids = as.list(sort(lab$feature_id, method = "radix")), x_limit = x_lim, y_cap = y_cap %||% NA,
      raw_source = original_ft, statistic = prepared$definition$statistic, statistic_column = statistic_col,
      decision_table = prepared$decision, display_table = audit, excluded_features = excluded,
      direction_category = category_counts),
    notes = list(numeric_precision = "binary64_roundtrip", statistic_kind = statistic_kind, statistic_method = statistic_method,
      adjustment = adjustment, family_id = family_id, n_zero_reported = prepared$definition$statistic$n_zero,
      zero_display = "upper display cap; raw zero precision unknown", q_is_individual_posterior = FALSE),
    colour_registry = if (is.null(ann)) colour_registry else ann$registry)
  frozen_label_rows <- .os_label_rows(d, lab, -lab$y)
  if (!exists(".os_restyle_attach", mode="function")) return(out)
  .os_restyle_attach(out, "volcano", environment())
}

os_ma <- function(ft, padj_threshold = 0.05, lfc_threshold = 0, label_n = 10, label_genes = NULL,
                  y_max = NULL, contrast_label = NULL, method_label = NULL, italic_labels = TRUE, journal = NULL,
                  statistic_kind = "adjusted_p", statistic_col = "padj", statistic_method = "unknown",
                  adjustment = "unknown", family_id = "unknown", family_size = NULL, test_contract = NULL,
                  effect_provenance = NULL, p_operator = "<", display_operator = ">",
                  mean_kind = "normalized_count_mean", mean_unit = NULL, mean_scale = "linear",
                  mean_transform = NULL, mean_col = "base_mean", family_source_ids = NULL) {
  .os_require_cols(ft, mean_col, "os_ma")
  if (!is.numeric(ft[[mean_col]])) .os_de_error("MA abundance must be numeric")
  if (!mean_kind %in% c("normalized_count_mean", "linear_intensity_mean", "mean_log_abundance", "unknown") || !mean_scale %in% c("linear", "log2", "log10", "unknown")) .os_de_error("unknown mean abundance kind/scale")
  if (mean_kind == "normalized_count_mean" && mean_scale != "linear") .os_de_error("normalized-count means are linear counts; declare already-log abundance separately")
  if (mean_kind == "mean_log_abundance" && !mean_scale %in% c("log2", "log10")) .os_de_error("mean(log abundance) requires its actual log scale")
  if (is.null(mean_transform)) mean_transform <- if (mean_scale == "linear") "log10" else "identity"
  if (!mean_transform %in% c("log10", "identity") || (mean_scale %in% c("log2", "log10") && mean_transform != "identity")) .os_de_error("already-log abundance cannot be logged again")
  mean_unit <- mean_unit %||% if (mean_kind == "normalized_count_mean") "normalized counts" else "unknown"
  .os_de_scalar(mean_unit, "abundance unit")
  prepared <- .os_de_prepare(ft, padj_threshold, lfc_threshold, statistic_kind, statistic_col,
    statistic_method, adjustment, family_id, family_size, test_contract, effect_provenance, p_operator, display_operator, family_source_ids)
  d <- ft; d$padj <- ft[[statistic_col]]
  for (k in setdiff(names(prepared$decision), "feature_id")) d[[k]] <- prepared$decision[[k]]
  d$.colour <- d$de_class
  reason <- rep("shown", nrow(ft)); reason[!is.finite(ft$log2fc)] <- "nonfinite_plotted_effect"
  reason[!is.finite(ft[[mean_col]])] <- "nonfinite_abundance"
  if (mean_transform == "log10") reason[is.finite(ft[[mean_col]]) & ft[[mean_col]] <= 0] <- "nonpositive_abundance_for_log10"
  excluded <- data.frame(feature_id = ft$feature_id[reason != "shown"], reason = reason[reason != "shown"], stringsAsFactors = FALSE)
  d <- d[reason == "shown", , drop = FALSE]
  if (!is.null(y_max) && (length(y_max) != 1L || !is.finite(y_max) || y_max <= 0)) .os_de_error("MA y limit must be positive finite")
  y_lim <- y_max %||% os_sym_limit(d$log2fc, min_abs = 1)
  d$cap_direction <- ifelse(d$log2fc > y_lim, "upper", ifelse(d$log2fc < -y_lim, "lower", "none")); d$capped <- d$cap_direction != "none"
  d$y <- pmax(pmin(d$log2fc, y_lim), -y_lim)
  d$x <- if (mean_transform == "log10") log10(d[[mean_col]]) else d[[mean_col]]
  d$z <- ifelse(d$de_class == "ns", 0, 1)
  d <- d[order(d$z, -d$padj, d$feature_id, method = "radix", na.last = FALSE), , drop = FALSE]
  d$display <- .os_display_symbol(d); lab <- d[d$feature_id %in% os_pick_labels(d, label_n, label_genes), , drop = FALSE]
  os_assert_latin(lab$display, "MA labels")
  pal <- .os_de_class_palette()
  p <- ggplot2::ggplot(d, ggplot2::aes(x = x, y = y)) + ggplot2::geom_hline(yintercept = 0, colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref))
  margin <- prepared$definition$test$margin
  p <- .os_de_effect_lines(p, margin, lfc_threshold, "y")
  p <- .os_de_points(p, d, lab, pal, journal, italic_labels, lab$padj,
    colour_title = if (!is.null(test_contract)) "Statistical decision" else NULL,
    colour_breaks = intersect(names(pal),unique(d$de_class[d$de_class != "na"])),
    colour_labels = .os_de_class_labels())
  if (mean_transform == "log10") p <- p + ggplot2::scale_x_continuous(labels = function(b) {
    if (any(abs(b - round(b)) > 1e-10, na.rm = TRUE)) os_axis_labels(10^b)
    else parse(text = ifelse(is.finite(b), paste0("10^", b), "NA"))
  }, breaks = function(l) if (diff(l) < 1) pretty(l, n = 4) else seq(floor(l[1]), ceiling(l[2]), by = 1))
  else p <- p + ggplot2::scale_x_continuous(labels = os_axis_labels)
  xlab <- switch(mean_kind, normalized_count_mean = "Mean of normalized counts", linear_intensity_mean = paste0("Mean linear intensity (", mean_unit, ")"), mean_log_abundance = paste0("Mean ", mean_scale, " abundance (", mean_unit, ")"), paste0("Supplied abundance (", mean_unit, ")"))
  ylab <- .os_de_effect_axis(prepared$definition$effect$plotted_estimator)
  p <- p + ggplot2::scale_y_continuous(limits = c(-y_lim, y_lim), labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.02)) +
    ggplot2::labs(x = xlab, y = ylab, title = contrast_label) + theme_omicstat(journal = journal, legend = "bottom") + .os_de_guide_layout()
  n_up <- sum(d$de_class == "up"); n_down <- sum(d$de_class == "down"); n_ns <- sum(d$de_class == "ns"); n_na <- sum(d$de_class == "na"); n_within <- sum(d$de_class == "within_margin")
  n_undirected <- sum(d$de_class == "supported_undirected")
  text <- if (prepared$definition$test$hypothesis == "small_effect") paste0("Green, within-margin evidence (n = ", n_within, "); grey, inconclusive (n = ", n_ns, "). ") else paste0("Red, positive direction (n = ", n_up, "); blue, negative direction (n = ", n_down, "); grey, ", if (is.null(test_contract)) "not display-selected" else "inconclusive", " (n = ", n_ns, "). ")
  missing_reasons <- prepared$counts$missing_statistic_reasons
  cap <- paste0("MA plot", if (!is.null(contrast_label)) paste0(" (", contrast_label, ")"), ". ", nrow(d), " of ", nrow(ft), " supplied features shown. ",
    "X: ", mean_kind, "; source scale ", mean_scale, "; unit ", mean_unit, "; display transform ", mean_transform, ". ", text,
    if (n_undirected > 0) paste0("Purple, statistically supported with zero or unavailable tested direction (n = ", n_undirected, "); these are not inconclusive. "),
    n_na, " displayed with unavailable statistic as dark-grey crosses, separate from tested inconclusive circles. ",
    .os_de_caption(prepared$definition), if (!is.null(method_label)) paste0("Method label: ", method_label, ". "),
    "Missing statistic reasons: ", paste(paste(names(missing_reasons), unlist(missing_reasons), sep = "="), collapse = "; "), ". ",
    nrow(excluded), " excluded from coordinates: ", paste(paste(names(table(excluded$reason)), as.integer(table(excluded$reason)), sep = "="), collapse = "; "), ". ",
    "Upward/downward triangles identify strict upper/lower overflow, including highlighted features; exact boundary values are not overflow. Raw values are unchanged. ",
    "Effect-line labels give log2 values: dotted = effect margin, dashed = display filter, dot-dash = coincident margin and display filter.")
  prepared$definition$abundance <- list(kind = mean_kind, unit = mean_unit, source_scale = mean_scale, display_transform = mean_transform, source_column = mean_col,
    operation_order = if (mean_kind == "mean_log_abundance") "mean of already-log abundance; no additional logarithm" else if (mean_transform == "log10") "log10 of supplied mean linear abundance" else "identity of supplied mean abundance")
  os_with_meta(p, figure_type = "ma", default_height_mm = if (is.null(test_contract)) 86 else 106, caption = cap,
    encodings = list(colour = as.list(pal), shape = list(tested = OS_FIG$shape_dense, missing_statistic = 4, upper = 24, lower = 25)),
    thresholds = list(padj = padj_threshold, abs_log2fc = lfc_threshold, effect_margin = margin, p_operator = p_operator, display_operator = display_operator),
    counts = c(list(up = n_up, down = n_down, ns = n_ns, within_margin = n_within, supported_undirected = n_undirected, padj_na = n_na, capped = sum(d$capped),
      upper_overflow = sum(d$cap_direction == "upper"), lower_overflow = sum(d$cap_direction == "lower"), n_displayed = nrow(d), n_excluded = nrow(excluded),
      missing_padj_reasons = missing_reasons), prepared$counts), definition = list(de_contract = prepared$definition),
    data = list(labelled_feature_ids = as.list(sort(lab$feature_id, method = "radix")), y_limit = y_lim,
      test_states = d[, c("feature_id", "de_class")], source_table = ft, raw_source = ft, decision_table = prepared$decision,
      display_table = d[, c("feature_id", "log2fc", "x", "y", "de_class", "capped", "cap_direction", "test_state")], excluded_features = excluded,
      upper_overflow_ids = as.list(d$feature_id[d$cap_direction == "upper"]), lower_overflow_ids = as.list(d$feature_id[d$cap_direction == "lower"])),
    notes = list(numeric_precision = "binary64_roundtrip"))
}

# ---------------------------------------------------------------------------
# PCA of samples
# ---------------------------------------------------------------------------
# os_pca_scores(): DESeq2::plotPCA-equivalent computation on a transformed
# matrix (rows features, cols samples): top `ntop` rows by variance, prcomp
# with centring and no scaling, then SIGN NORMALIZATION (ENGINEERING_PLAN
# lock 4: in every PC the loading with the largest |value| is made positive)
# so the plot never mirrors between platforms.
os_pca_scores <- function(mat, ntop = 500) {
  rv <- apply(mat, 1, stats::var)
  o <- order(-rv, rownames(mat), method = "radix")
  sel <- utils::head(o, min(ntop, length(rv)))
  pc <- stats::prcomp(t(mat[sel, , drop = FALSE]), center = TRUE, scale. = FALSE)
  for (k in seq_len(ncol(pc$rotation))) {
    i <- which.max(abs(pc$rotation[, k]))
    if (pc$rotation[i, k] < 0) { pc$rotation[, k] <- -pc$rotation[, k]; pc$x[, k] <- -pc$x[, k] }
  }
  pv <- pc$sdev^2 / sum(pc$sdev^2)
  list(scores = data.frame(sample = rownames(pc$x), pc$x[, 1:min(5, ncol(pc$x)), drop = FALSE],
                           check.names = FALSE, stringsAsFactors = FALSE),
       percent_var = 100 * pv, ntop = length(sel))
}

# scores: data.frame(sample, PC1, PC2, ...); coldata: data.frame(sample, <group_col>, [<shape_col>]).
os_pca_plot <- function(pca, coldata, group_col, shape_col = NULL, reference = NULL, pcs = c(1, 2),
                        label_samples = FALSE, colour_registry = NULL, journal = NULL) {
  sc <- merge(pca$scores, coldata, by = "sample", sort = FALSE)
  sc <- sc[order(sc$sample, method = "radix"), , drop = FALSE]
  xs <- paste0("PC", pcs[1]); ys <- paste0("PC", pcs[2])
  sc$.x <- sc[[xs]]; sc$.y <- sc[[ys]]
  grp <- as.character(sc[[group_col]])
  lv <- if (is.factor(coldata[[group_col]])) levels(coldata[[group_col]]) else sort(unique(grp), method = "radix")
  if (!is.null(reference)) lv <- c(reference, setdiff(lv, reference))
  cols <- if (!is.null(colour_registry)) os_colours_for(lv, "group", colour_registry, reference = reference)$colours
          else os_group_colours(lv, reference = reference)
  sc$.g <- factor(grp, levels = lv)
  fam <- os_font_family()
  if (!is.null(shape_col)) {
    slv <- sort(unique(as.character(sc[[shape_col]])), method = "radix")
    if (length(slv) > length(OS_FIG$shape_sample_sequence)) stop("OS_TOO_MANY_CATEGORIES: more than 5 shape levels.", call. = FALSE)
    sc$.s <- factor(as.character(sc[[shape_col]]), levels = slv)
  }
  pv <- pca$percent_var
  # Axes on a common scale (DESeq2 plotPCA convention) while the panel stays
  # readable: if the y/x data-range ratio is within [0.4, 2.5] use
  # coord_fixed; otherwise a free 0.75 aspect, disclosed in the caption.
  rr <- diff(range(sc$.y)) / max(diff(range(sc$.x)), 1e-12)
  common_scale <- rr >= 0.4 && rr <= 2.5
  pca_coord <- if (common_scale) ggplot2::coord_fixed(ratio = 1) else ggplot2::coord_cartesian()
  pts <- if (is.null(shape_col)) {
    ggplot2::geom_point(ggplot2::aes(fill = .g), shape = 21, size = OS_FIG$pt_sample_mm,
                        colour = OS_FIG$col_point_edge, stroke = os_lw(OS_FIG$lw_point_edge))
  } else {
    ggplot2::geom_point(ggplot2::aes(fill = .g, shape = .s), size = OS_FIG$pt_sample_mm,
                        colour = OS_FIG$col_point_edge, stroke = os_lw(OS_FIG$lw_point_edge))
  }
  p <- ggplot2::ggplot(sc, ggplot2::aes(x = .x, y = .y)) + pts +
    ggplot2::scale_fill_manual(values = cols, breaks = lv, guide = os_guide_legend(group_col, override = list(shape = 21, size = OS_FIG$pt_sample_mm))) +
    ggplot2::scale_x_continuous(labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.08)) +
    ggplot2::scale_y_continuous(labels = os_axis_labels, expand = ggplot2::expansion(mult = 0.08)) +
    pca_coord +
    ggplot2::labs(x = sprintf("%s (%.1f%% variance)", xs, pv[pcs[1]]), y = sprintf("%s (%.1f%% variance)", ys, pv[pcs[2]])) +
    theme_omicstat(journal = journal, legend = "right")
  if (!is.null(shape_col)) {
    p <- p + ggplot2::scale_shape_manual(values = OS_FIG$shape_sample_sequence[seq_along(levels(sc$.s))],
                                         guide = os_guide_legend(shape_col, override = list(fill = OS_FIG$col_reference_group, size = OS_FIG$pt_sample_mm)))
  }
  if (label_samples) {
    p <- p + os_label_repel(sc, ggplot2::aes(label = sample), italic = FALSE, journal = journal)
  }
  cap <- sprintf(paste0("Principal component analysis of %d samples using the %d most variable features ",
                        "(centred, not scaled; %s). Each point is one sample, coloured by %s%s. ",
                        "Percentages give the variance explained by each component."),
                 nrow(sc), pca$ntop, if (common_scale) "axes on a common scale" else "axes NOT on a common scale because the two components span very different ranges",
                 group_col, if (!is.null(shape_col)) paste0(" and shaped by ", shape_col) else "")
  if (!common_scale) p <- p + ggplot2::theme(aspect.ratio = 0.75)
  os_with_meta(p, figure_type = "pca", default_height_mm = 70, caption = cap,
               encodings = list(fill = as.list(cols), shape = if (is.null(shape_col)) 21 else as.list(stats::setNames(OS_FIG$shape_sample_sequence[seq_along(levels(sc$.s))], levels(sc$.s)))),
               data = list(samples = as.list(sc$sample), percent_var = as.list(round(pv[pcs], 4)), ntop = pca$ntop,
                           common_scale = common_scale))
}

# ---------------------------------------------------------------------------
# Sample-to-sample distance heatmap (DESeq2 vignette)
# ---------------------------------------------------------------------------
os_sample_distance <- function(mat, coldata, group_col, reference = NULL, journal = NULL,
                               annotation_cols = group_col, distance_source = "transformed expression",
                               preprocessing = c("unknown", "blind", "design-aware"),
                               metric = "euclidean", linkage = "complete", distance_unit = "unknown",
                               show_sample_labels = TRUE) {
  preprocessing <- match.arg(preprocessing); .os_matrix_ids(mat)
  .os_require_cols(coldata, c("sample", group_col, annotation_cols), "os_sample_distance")
  if (!setequal(.os_require_ids(coldata$sample, "sample metadata IDs"), colnames(mat)) || any(!is.finite(mat)))
    stop("OS_INVALID_INPUT: sample distance needs finite values and matching sample metadata IDs.", call. = FALSE)
  if (ncol(mat) < 2L) .os_matrix_error("sample distance needs at least two samples")
  if (!metric %in% c("euclidean", "maximum", "manhattan", "canberra", "binary") ||
      !linkage %in% c("complete", "single", "average", "mcquitty", "ward.D", "ward.D2", "centroid", "median"))
    .os_matrix_error("unknown distance metric or linkage")
  .os_sem_string(distance_source, "distance source")
  dm <- as.matrix(stats::dist(t(mat), method = metric))
  tree <- stats::hclust(stats::as.dist(dm), method = linkage); tree$dist.method <- metric
  ann <- coldata[, unique(annotation_cols), drop = FALSE]; rownames(ann) <- coldata$sample
  lv <- sort(unique(as.character(coldata[[group_col]])), method = "radix")
  if (!is.null(reference)) lv <- c(reference, setdiff(lv, reference))
  ac <- list(); ac[[group_col]] <- os_group_colours(lv, reference)
  p <- os_heatmap(dm, value_title = paste(metric, "distance", sep = "\n"), scale_type = "distance", cluster_rows = TRUE,
                  cluster_cols = TRUE, show_row_dendro = FALSE, italic_rows = FALSE, show_col_labels = show_sample_labels,
                  col_annot = ann[colnames(dm), , drop = FALSE], row_annot = ann[rownames(dm), , drop = FALSE],
                  annot_colours = ac, journal = journal, row_hclust = tree, col_hclust = tree,
                  matrix_kind = "distance", row_entity = "sample", col_entity = "sample",
                  quantity = paste(metric, "distance"), unit = distance_unit,
                  clustering_provenance = list(source = distance_source, preprocessing = preprocessing, metric = metric, linkage = linkage))
  meta <- attr(p, "os_meta"); original <- .os_matrix_table(mat)
  os_with_meta(p, figure_type = "sample_distance", default_height_mm = 85,
               caption = sprintf(paste0("Sample-to-sample %s distances on %s (%d samples; %d features). ",
                                        "Preprocessing: %s. Samples are ordered once from these direct distances (%s linkage); both axes reuse the same tree. Darker blue indicates smaller distance. ",
                                        "Keyed annotation tracks: %s. Sample IDs remain unique. No branch confidence or general superiority is inferred."),
                                 metric, distance_source, ncol(mat), nrow(mat), preprocessing, linkage, paste(annotation_cols, collapse = ", ")),
               definition = list(matrix_kind = "distance", source = distance_source, metric = metric, linkage = tree$method, preprocessing = preprocessing),
               counts = list(n_samples = ncol(mat), n_features = nrow(mat)),
               data = list(tree = list(merge = tree$merge, height = tree$height, leaf_ids = as.list(tree$labels[tree$order])),
                           distance_input = original, distance_input_sha256 = os_semantic_table_sha256(original, .os_cell_keys(original$row_id, original$col_id))))
}

# ---------------------------------------------------------------------------
# Top-feature heatmap: row z-scores of the top n features (by padj), columns
# ordered by group (reference first) then sample id; rows clustered.
# ---------------------------------------------------------------------------
os_top_heatmap <- function(mat, ft, coldata, group_col, n = 50, reference = NULL, clip = 2,
                           cluster_cols = FALSE, show_col_labels = NULL, journal = NULL,
                           missing_policy = c("error", "no_cluster"), col_unit = c("sample", "condition_average"),
                           aggregation_order = c("zscore_then_mean", "mean_then_zscore")) {
  missing_policy <- match.arg(missing_policy); col_unit <- match.arg(col_unit); aggregation_order <- match.arg(aggregation_order)
  .os_matrix_ids(mat); .os_require_cols(ft, c("feature_id", "padj"), "os_top_heatmap")
  .os_require_ids(ft$feature_id, "feature-table IDs")
  .os_require_cols(coldata, c("sample", group_col), "os_top_heatmap")
  if (!setequal(.os_require_ids(coldata$sample, "top heatmap sample IDs"), colnames(mat)) || anyNA(coldata[[group_col]])) .os_matrix_error("top heatmap metadata must cover each sample once and have a known group")
  if (length(n) != 1L || !is.finite(n) || n < 1 || n != as.integer(n)) .os_matrix_error("top-feature count must be a positive integer")
  f <- ft[is.finite(ft$padj) & ft$feature_id %in% rownames(mat), , drop = FALSE]
  if (any(f$padj < 0 | f$padj > 1)) .os_matrix_error("adjusted P values must lie in [0,1]")
  f <- f[order(f$padj, -abs(f$log2fc %||% rep(0, nrow(f))), f$feature_id, method = "radix"), , drop = FALSE]
  selected_rank <- utils::head(f$feature_id, n)
  sel <- sort(selected_rank, method = "radix")
  if (!length(sel)) .os_matrix_error("no eligible finite adjusted-P features are present in the matrix")
  cd <- coldata
  lv <- sort(unique(as.character(cd[[group_col]])), method = "radix")
  if (!is.null(reference)) lv <- c(reference, setdiff(lv, reference))
  cd$.g <- factor(as.character(cd[[group_col]]), levels = lv)
  cd <- cd[order(cd$.g, cd$sample, method = "radix"), , drop = FALSE]
  m <- mat[sel, cd$sample, drop = FALSE]
  scaling <- os_matrix_normalize(m, "row_zscore")
  labs <- if ("symbol" %in% names(ft)) stats::setNames(.os_display_symbol(ft[match(sel, ft$feature_id), ]), sel) else NULL
  groups <- split(as.character(cd$sample), cd$.g, drop = TRUE)
  aggregate_matrix <- function(x) {
    z <- vapply(groups, function(ids) rowMeans(x[, ids, drop = FALSE]), numeric(nrow(x)))
    if (!is.matrix(z)) z <- matrix(z, nrow(x), length(groups))
    dimnames(z) <- list(rownames(x), names(groups)); z
  }
  input <- m; normalization <- "row_zscore"; states <- NULL; group_values <- as.character(cd$.g)
  if (col_unit == "condition_average") {
    group_values <- names(groups)
    if (aggregation_order == "mean_then_zscore") input <- aggregate_matrix(m)
    else {
      input <- aggregate_matrix(scaling$values); normalization <- "identity"
      states <- .os_matrix_states(input)
      for (i in seq_len(nrow(input))) for (j in seq_len(ncol(input))) if (!is.finite(input[i,j])) {
        source_states <- scaling$state[i, groups[[j]]]
        states[i,j] <- if ("undefined_constant" %in% source_states) "undefined_constant" else if ("undefined_single_sample" %in% source_states) "undefined_single_sample" else "undefined_nonfinite_reference"
      }
    }
  }
  ann <- data.frame(row.names = colnames(input), check.names = FALSE); ann[[group_col]] <- group_values
  ac <- list(); ac[[group_col]] <- os_group_colours(lv, reference)
  quantity <- if (col_unit == "sample") "within-feature sample z-score" else if (aggregation_order == "zscore_then_mean") "condition mean of within-feature sample z-scores" else "within-feature z-score of condition means"
  p <- os_heatmap(input, value_title = if (col_unit == "sample") OS_AXIS$zscore else if (aggregation_order == "zscore_then_mean") "Mean sample\nz-score" else "Condition-mean\nz-score",
                  scale_type = "diverging", clip = clip, cluster_rows = TRUE,
                  cluster_cols = cluster_cols, row_labels = labs, col_annot = ann, annot_colours = ac,
                  show_col_labels = show_col_labels %||% (ncol(input) <= 24), journal = journal,
                  missing_policy = missing_policy, value_state = states, normalization = normalization,
                  matrix_kind = "expression", row_entity = "feature", col_entity = col_unit,
                  quantity = quantity, unit = "dimensionless", col_axis_role = "design")
  meta <- attr(p, "os_meta")
  effective_scaling <- if (col_unit == "condition_average" && aggregation_order == "mean_then_zscore") os_matrix_normalize(input, "row_zscore") else scaling
  os_with_meta(p, figure_type = "top_heatmap", default_height_mm = min(170, 30 + 2.2 * length(sel)),
               caption = sprintf(paste0("Expression of %d selected features with the smallest adjusted P values from %d eligible features. ",
                                        "Columns are %s (%d displayed columns; %d source samples). Transformation order: %s. ",
                                        "Rows are ordered by %s; columns by %s. %d display cells were clipped at +/- %s. ",
                                        "Undefined values remain unavailable; no zero imputation is used. This selected-feature view is not unsupervised whole-transcriptome validation. ",
                                        if (length(sel) > 60) "Dense rows are not individually labelled; use the full exported feature IDs and numeric table for gene-level values." else ""),
                                 length(sel), nrow(f), col_unit, ncol(input), ncol(m),
                                 if (col_unit == "sample") "row z-score across supplied samples" else aggregation_order,
                                 if (identical(meta$data$clustering$rows, "none")) "input feature ID (clustering disabled)" else "hierarchical clustering (Euclidean distance, complete linkage)",
                                 if (identical(meta$data$clustering$cols, "none")) paste(group_col, "then sample ID / condition ID") else "hierarchical clustering (Euclidean distance, complete linkage)", meta$counts$clipped_cells, clip),
               definition = list(top_feature_selection = list(metric = "adjusted_p", adjustment_method = "unknown", family = "supplied feature table",
                 requested_n = n, actual_n = length(sel), eligible_feature_ids = as.list(f$feature_id), rank_order_ids = as.list(selected_rank),
                 tie_rule = "padj ascending, absolute log2fc descending when supplied, feature_id ascending; input rows then sorted by feature ID"),
                 aggregation = list(col_unit = col_unit, operation_order = if (col_unit == "sample") "row_zscore" else aggregation_order,
                   groups = lapply(groups, as.list), n_replicates = lapply(groups, length), independent_unit = "unknown",
                   source_normalization = if (col_unit == "sample" || aggregation_order == "zscore_then_mean") scaling$definition else NULL)),
               counts = list(n_source_samples = ncol(m), n_display_columns = ncol(input), n_selected_features = length(sel)),
               data = list(feature_ids = as.list(sel), selected_feature_table = ft[match(selected_rank, ft$feature_id), , drop = FALSE],
                           raw_values = m, source_sample_values = .os_matrix_table(m, .os_matrix_states(m)),
                           scaling_center = as.list(effective_scaling$definition$parameters$center), scaling_sd = as.list(effective_scaling$definition$parameters$divisor)))
}

# ---------------------------------------------------------------------------
# Generic diagnostic plot (elbow, soft-threshold, BCV, mean-variance, ...)
# ---------------------------------------------------------------------------
# kind = "points" | "line" | "line+points". Colour is ink by default; a
# grouping column uses the category palette. Reference lines via hlines/vlines.
os_diag_xy <- function(df, x, y, kind = c("line+points", "points", "line"), group = NULL,
                       xlab = x, ylab = y, hlines = NULL, vlines = NULL, highlight = NULL,
                       point_labels = NULL, caption = "", figure_type = "diagnostic", journal = NULL,
                       definition = NULL) {
  kind <- match.arg(kind)
  semantic_binding <- if(!is.null(definition)) os_validate_render_sources(definition,list(df=df)) else NULL
  if(!is.null(definition)) {
    declared<-unlist(lapply(definition$layers,`[[`,"value_columns"),use.names=FALSE)
    if(!y %in% declared) .os_sem_error("diagnostic y must be an explicitly declared source value column")
    finite_xy<-is.finite(df[[x]])&is.finite(df[[y]])
    caption<-paste(caption,sprintf("%d finite coordinate rows drawn; %d nonfinite rows retained in the source but not drawn. Missing points break lines; no interpolation or imputation is performed.",sum(finite_xy),sum(!finite_xy)))
  }
  df$.x <- df[[x]]; df$.y <- df[[y]]
  fam <- os_font_family()
  map <- if (is.null(group)) ggplot2::aes(x = .x, y = .y) else ggplot2::aes(x = .x, y = .y, colour = .data[[group]], group = .data[[group]])
  p <- ggplot2::ggplot(df, map)
  if (!is.null(hlines)) p <- p + os_hline(hlines)
  if (!is.null(vlines)) p <- p + os_vline(vlines)
  if (grepl("line", kind)) p <- p + if (is.null(group)) ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data), colour = OS_FIG$col_ink) else ggplot2::geom_line(linewidth = os_lw(OS_FIG$lw_data))
  if (grepl("points", kind)) {
    n <- nrow(df)
    sz <- if (n > 500) OS_FIG$pt_dense_mm else OS_FIG$pt_highlight_mm * 1.4
    p <- p + if (is.null(group)) ggplot2::geom_point(shape = 16, size = sz, stroke = 0, colour = OS_FIG$col_ink) else ggplot2::geom_point(shape = 16, size = sz, stroke = 0)
  }
  if (!is.null(highlight)) {
    h <- df[highlight, , drop = FALSE]
    p <- p + ggplot2::geom_point(data = h, shape = 21, fill = OS_FIG$col_up, colour = OS_FIG$col_ink,
                                 size = OS_FIG$pt_highlight_mm * 2, stroke = os_lw(OS_FIG$lw_point_edge))
  }
  if (!is.null(point_labels)) {
    df$.lab <- df[[point_labels]]
    p <- p + ggplot2::geom_text(data = df, ggplot2::aes(label = .lab), vjust = -0.9, size = os_fs(os_text_pt(OS_FIG$size_label, journal)), family = fam, colour = OS_FIG$col_ink)
  }
  if (!is.null(group)) {
    lv <- sort(unique(as.character(df[[group]])), method = "radix")
    p <- p + ggplot2::scale_colour_manual(values = os_colours_for(lv, "category")$colours, guide = os_guide_legend(group))
  }
  p <- p + ggplot2::scale_x_continuous(labels = os_axis_labels) + ggplot2::scale_y_continuous(labels = os_axis_labels) +
    ggplot2::labs(x = xlab, y = ylab) + theme_omicstat(journal = journal, legend = if (is.null(group)) "none" else "right") +
    ggplot2::theme(aspect.ratio = 0.75)
  os_with_meta(p, definition = definition, figure_type = figure_type, default_height_mm = 65, caption = caption,
               notes=if(is.null(semantic_binding))list()else list(render_source_binding=semantic_binding))
}
