# Differential-effect semantics. This layer consumes supplied results; it never
# fits a model, adjusts P values, reverses a test or invents an equivalence test.
OS_DE_SEMANTIC_VERSION <- "omicstat.de-semantics.v1"
.os_de_error <- function(message) stop(paste0("OS_INVALID_INPUT: ", message), call. = FALSE)
.os_de_scalar <- function(x, name) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) .os_de_error(paste(name, "must be an explicit string, or unknown"))
  x
}

os_de_test_contract <- function(hypothesis = "unspecified", margin = NULL,
    p_value_hypothesis = "unknown", p_value_margin = NULL, p_value_source = "unknown",
    test_id = "unknown", prespecified = FALSE, effect_unit = "log2_fold_change",
    test_method = "unknown", model_id = "unknown", software = "unknown",
    software_version = "unknown", prior = "unknown", shrinkage = "unknown") {
  .os_de_scalar(hypothesis, "hypothesis")
  if (!hypothesis %in% c("unspecified", "zero_effect", "minimum_effect", "small_effect")) .os_de_error("unsupported DE hypothesis")
  if (!identical(effect_unit, "log2_fold_change")) .os_de_error("effect margins must be explicitly in log2 fold-change units, not linear fold change")
  for (n in c("p_value_hypothesis", "p_value_source", "test_id", "test_method", "model_id", "software", "software_version", "prior", "shrinkage")) .os_de_scalar(get(n), n)
  if (!is.logical(prespecified) || length(prespecified) != 1L || is.na(prespecified)) .os_de_error("prespecified must be one logical value")
  if (hypothesis != "unspecified") {
    if (!is.numeric(margin) || length(margin) != 1L || !is.finite(margin) || margin < 0 ||
        (hypothesis == "zero_effect" && margin != 0) || (hypothesis != "zero_effect" && margin <= 0)) .os_de_error("hypothesis and prespecified log2 effect margin disagree")
    if (!identical(p_value_hypothesis, hypothesis) || !isTRUE(all.equal(p_value_margin, margin, tolerance = 0)) ||
        p_value_source == "unknown" || test_id == "unknown") .os_de_error("declared hypothesis needs matching supplied P-value hypothesis/margin, source and test ID; changing a caption cannot change a test")
    if (hypothesis %in% c("minimum_effect", "small_effect") && !prespecified) .os_de_error("minimum/small-effect margins must be prespecified, not selected from the plot")
  } else if (!is.null(margin) || p_value_hypothesis != "unknown" || !is.null(p_value_margin)) .os_de_error("an unspecified test must retain an unknown null and margin")
  null <- switch(hypothesis, unspecified = "unknown", zero_effect = "beta = 0",
                 minimum_effect = "abs(beta) <= margin", small_effect = "abs(beta) >= margin")
  alternative <- switch(hypothesis, unspecified = "unknown", zero_effect = "beta != 0",
                        minimum_effect = "abs(beta) > margin", small_effect = "abs(beta) < margin")
  list(version = OS_DE_SEMANTIC_VERSION, hypothesis = hypothesis, margin = margin,
       effect_unit = effect_unit, null = null, alternative = alternative,
       p_value_hypothesis = p_value_hypothesis, p_value_margin = p_value_margin,
       p_value_source = p_value_source, test_id = test_id, prespecified = prespecified,
       test_method = test_method, model_id = model_id, software = software,
       software_version = software_version, prior = prior, shrinkage = shrinkage)
}

.os_de_validate_test <- function(x) {
  if (is.null(x)) return(os_de_test_contract())
  required <- names(os_de_test_contract())
  if (!is.list(x) || !setequal(names(x), required) || !identical(x$version, OS_DE_SEMANTIC_VERSION)) .os_de_error("a DE test contract must be a complete versioned value")
  args <- x[setdiff(names(x), c("version", "null", "alternative"))]
  result <- do.call(os_de_test_contract, args)
  if (!identical(x$null, result$null) || !identical(x$alternative, result$alternative)) .os_de_error("DE null/alternative contradict the supplied hypothesis")
  result
}

.os_de_compare <- function(x, cutoff, operator) {
  switch(operator, "<" = x < cutoff, "<=" = x <= cutoff, ">" = x > cutoff, ">=" = x >= cutoff,
         .os_de_error("unsupported threshold operator"))
}

.os_de_decision_values <- function(plotted_effect, p, alpha, display_threshold, statistic_kind,
                                   test_contract = NULL, tested_effect = plotted_effect,
                                   p_operator = "<", display_operator = ">") {
  test <- .os_de_validate_test(test_contract)
  if (!statistic_kind %in% c("raw_p", "adjusted_p", "qvalue")) .os_de_error("DE decisions require a named P/q statistic; posterior or local-FDR decisions are separate")
  if (!is.numeric(plotted_effect) || !is.numeric(tested_effect) || length(tested_effect) != length(plotted_effect) ||
      !is.numeric(p) || length(p) != length(plotted_effect) || any(is.infinite(p)) || any(p < 0 | p > 1, na.rm = TRUE)) .os_de_error("DE effects and P/q values must align; P/q is in [0,1] or missing")
  if (length(alpha) != 1L || !is.finite(alpha) || alpha < 0 || alpha > 1 || length(display_threshold) != 1L || !is.finite(display_threshold) || display_threshold < 0 ||
      !p_operator %in% c("<", "<=") || !display_operator %in% c(">", ">=")) .os_de_error("invalid DE threshold or comparison operator")
  supported <- rep(NA, length(p)); supported[!is.na(p)] <- .os_de_compare(p[!is.na(p)], alpha, p_operator)
  call <- ifelse(is.na(supported), "not_tested", "inconclusive")
  sig <- which(!is.na(supported) & supported)
  if (test$hypothesis == "small_effect") call[sig] <- "within_margin"
  else {
    call[sig] <- "supported_direction_unavailable"
    call[sig[is.finite(tested_effect[sig]) & tested_effect[sig] > 0]] <- "supported_positive"
    call[sig[is.finite(tested_effect[sig]) & tested_effect[sig] < 0]] <- "supported_negative"
    call[sig[is.finite(tested_effect[sig]) & tested_effect[sig] == 0]] <- "supported_zero_estimate"
  }
  display_selected <- !is.na(supported) & supported & is.finite(plotted_effect) &
    if (display_threshold == 0) TRUE else .os_de_compare(abs(plotted_effect), display_threshold, display_operator)
  cls <- rep("ns", length(p)); cls[is.na(p)] <- "na"
  # The historical default colours are a display selection. An explicit test
  # contract instead colours the statistical decision independently of that gate.
  coloured <- if (is.null(test_contract)) display_selected else !is.na(supported) & supported
  cls[coloured & call == "supported_positive"] <- "up"
  cls[coloured & call == "supported_negative"] <- "down"
  cls[coloured & call == "within_margin"] <- "within_margin"
  cls[coloured & call %in% c("supported_zero_estimate", "supported_direction_unavailable")] <- "supported_undirected"
  list(statistical_call = call, statistical_supported = supported,
       display_selected = display_selected, de_class = cls, test = test)
}

.os_de_effect_contract <- function(ft, x = NULL) {
  defaults <- list(plotted_estimator = "unknown", tested_estimator = "unknown", tested_effect_col = "log2fc",
                   software = "unknown", software_version = "unknown", shrinkage = "unknown", prior = "unknown",
                   contrast = list(numerator = "unknown", reference = "unknown", expanded_control = "unknown"),
                   sample_counts = NULL, independent_unit = "unknown")
  if (!is.null(x) && (!is.list(x) || any(!names(x) %in% names(defaults)))) .os_de_error("unknown effect-provenance field")
  out <- utils::modifyList(defaults, x %||% list(), keep.null = TRUE)
  for (n in setdiff(names(defaults), c("contrast", "sample_counts"))) .os_de_scalar(out[[n]], n)
  if (!out$tested_effect_col %in% names(ft) || !is.numeric(ft[[out$tested_effect_col]])) .os_de_error("tested effects need an actual numeric source column aligned by feature ID")
  if (!is.list(out$contrast) || !all(c("numerator", "reference", "expanded_control") %in% names(out$contrast))) .os_de_error("contrast provenance needs numerator, reference and expanded control")
  invisible(lapply(out$contrast, .os_de_scalar, name = "contrast"))
  if (!is.null(out$sample_counts)) {
    z <- unlist(out$sample_counts)
    if (!is.numeric(z) || any(!is.finite(z)) || any(z < 0 | z != floor(z)) || is.null(names(z))) .os_de_error("sample counts must be named nonnegative integer counts with an explicit unit")
  }
  out
}

.os_de_prepare <- function(ft, alpha, display_threshold, statistic_kind = "adjusted_p", statistic_col = "padj",
    statistic_method = "unknown", adjustment = "unknown", family_id = "unknown", family_size = NULL,
    test_contract = NULL, effect_provenance = NULL, p_operator = "<", display_operator = ">",
    family_source_ids = NULL) {
  .os_require_cols(ft, c("feature_id", "log2fc", statistic_col), "differential-effect plot")
  .os_require_ids(ft$feature_id, "DE feature IDs")
  if (statistic_kind != "adjusted_p" && statistic_col == "padj") .os_de_error("do not relabel padj as raw P/q; supply the actual source column")
  if ("prefilter_pass" %in% names(ft) && (!is.logical(ft$prefilter_pass) || anyNA(ft$prefilter_pass)))
    .os_de_error("prefilter_pass must contain actual complete logical eligibility, not inferred from display")
  if (!is.null(family_source_ids)) {
    family_source_ids <- .os_sem_ids(family_source_ids, "actual DE family IDs", empty = TRUE)
    if (is.null(family_size) || length(family_source_ids) != family_size ||
        !all(family_source_ids %in% ft$feature_id) ||
        !all(ft$feature_id[is.finite(ft[[statistic_col]])] %in% family_source_ids))
      .os_de_error("actual DE family membership must match its size, source IDs and all finite statistics")
  }
  effect <- .os_de_effect_contract(ft, effect_provenance)
  values <- .os_de_decision_values(ft$log2fc, ft[[statistic_col]], alpha, display_threshold,
    statistic_kind, test_contract, ft[[effect$tested_effect_col]], p_operator, display_operator)
  statistic <- os_statistic_contract("de_statistic", ft[[statistic_col]], ft$feature_id, statistic_kind,
    statistic_method, adjustment, family_id, family_size, null = values$test$null,
    alternative = values$test$alternative, threshold = alpha)
  statistic$comparison_operator <- p_operator
  statistic$decision <- as.list(stats::setNames(ifelse(is.na(values$statistical_supported), "unknown",
    ifelse(values$statistical_supported, "meets_declared_rule", "does_not_meet_declared_rule")), ft$feature_id))
  reason <- if ("filtered_reason" %in% names(ft)) as.character(ft$filtered_reason) else rep("unknown", nrow(ft))
  reason[is.na(reason) | !nzchar(reason)] <- "unknown"
  state <- ifelse(is.na(ft[[statistic_col]]), ifelse(reason == "unknown", "missing_result_unknown", reason), "tested")
  decision <- data.frame(feature_id = ft$feature_id, plotted_effect = ft$log2fc,
    tested_effect = ft[[effect$tested_effect_col]], statistic_value = ft[[statistic_col]],
    statistical_call = values$statistical_call, statistical_supported = values$statistical_supported,
    display_selected = values$display_selected, de_class = values$de_class, test_state = state,
    filtered_reason = reason, stringsAsFactors = FALSE)
  contract <- list(version = OS_DE_SEMANTIC_VERSION, test = values$test, effect = effect,
    source_sha256 = os_semantic_table_sha256(ft, ft$feature_id), source_ids = as.list(ft$feature_id), statistic = statistic,
    thresholds = list(statistic_kind = statistic_kind, statistic_column = statistic_col, alpha = alpha,
      p_operator = p_operator, display_abs_log2fc = display_threshold, display_operator = display_operator,
      display_filter_has_separate_FDR_guarantee = FALSE),
    colour_decision = if (is.null(test_contract)) "legacy_display_selection" else "statistical_call",
    family_source_ids = if (is.null(family_source_ids)) NULL else as.list(family_source_ids),
    family_membership_status = if (is.null(family_source_ids)) "unknown" else "complete_supplied_native_family",
    source_values = "data.raw_source", decisions = "data.decision_table")
  counts <- list(n_input = nrow(ft), n_prefilter_pass = if ("prefilter_pass" %in% names(ft)) sum(ft$prefilter_pass %in% TRUE) else NULL,
    n_finite_raw_p = if ("pvalue" %in% names(ft)) sum(is.finite(ft$pvalue)) else NULL,
    n_finite_padj = if ("padj" %in% names(ft)) sum(is.finite(ft$padj)) else NULL,
    n_finite_statistic = sum(is.finite(ft[[statistic_col]])), n_statistically_supported = sum(values$statistical_supported, na.rm = TRUE),
    n_display_selected = sum(values$display_selected), input_test_states = as.list(table(state)),
    missing_statistic_reasons = as.list(table(reason[is.na(ft[[statistic_col]])])),
    statistical_calls = as.list(table(values$statistical_call)))
  list(decision = decision, definition = contract, counts = counts)
}

.os_de_caption <- function(contract) {
  t <- contract$test; e <- contract$effect; z <- contract$thresholds
  hypothesis <- if (t$hypothesis == "unspecified") "Test hypothesis and effect margin were not supplied. " else paste0(
    "Supplied ", t$test_method, " test: H0 ", t$null, "; H1 ", t$alternative, ". ",
    if (t$hypothesis != "zero_effect") paste0("Prespecified margin = ", os_num(t$margin), " log2 units (linear fold change ", os_num(2^t$margin), "). ") else "",
    if (t$hypothesis == "small_effect") "Within-margin evidence means equivalent within the prespecified margin, not identical or no biological effect. " else "")
  paste0(hypothesis, "Statistical decision: ", z$statistic_kind, " ", z$p_operator, " ", z$alpha,
    "; family ", contract$statistic$family_id, " (size ", contract$statistic$family_size %||% "unknown", "); finite supplied statistics = ", contract$statistic$n_finite, ". Display selection uses |plotted log2 effect| ", z$display_operator, " ", z$display_abs_log2fc,
    " (0 disables the effect gate); it neither changes the supplied P values nor establishes a separate large-effect FDR guarantee. ",
    "Plotted estimator: ", e$plotted_estimator, "; tested estimator: ", e$tested_estimator, ". ",
    "Contrast numerator: ", e$contrast$numerator, "; reference: ", e$contrast$reference, "; control composition: ", e$contrast$expanded_control, ". ",
    "Estimator software/version: ", e$software, "/", e$software_version, "; shrinkage/prior: ", e$shrinkage, "/", e$prior, ". ",
    "Sample counts (", e$independent_unit, "): ", if (is.null(e$sample_counts)) "unknown" else
      paste(paste(names(e$sample_counts), unlist(e$sample_counts), sep = "="), collapse = "; "), ". ")
}

.os_de_class_palette <- function() c(up = OS_FIG$col_up, down = OS_FIG$col_down,
    ns = OS_FIG$col_ns, na = OS_FIG$col_reference_group, within_margin = OS_PAL_GROUP[3],
    supported_undirected = "#CC79A7")
.os_de_class_labels <- function() c(up = "Supported positive", down = "Supported negative",
    ns = "Inconclusive", na = "Statistic unavailable", within_margin = "Within margin",
    supported_undirected = "Supported; direction unknown")

# An effect margin is not a significance region. Coincident statistical and
# display cutoffs share one explicitly labelled line rather than hiding one.
.os_de_effect_lines <- function(p, margin, display, axis = "x") {
  rows <- list(); styles <- character()
  if (!is.null(margin) && margin > 0) {
    label <- paste0(if (margin == display) "Effect margin + display filter: " else "Effect margin: ",
      "+/-", os_num(margin), " log2")
    rows[[length(rows)+1L]] <- data.frame(value = c(-margin, margin), threshold = label)
    styles[label] <- if (margin == display) "dotdash" else "dotted"
  }
  if (display > 0 && (is.null(margin) || display != margin)) {
    label <- paste0("Display filter: +/-", os_num(display), " log2")
    rows[[length(rows)+1L]] <- data.frame(value = c(-display, display), threshold = label)
    styles[label] <- "dashed"
  }
  if (!length(rows)) return(p)
  d <- do.call(rbind, rows)
  if (axis == "x") p <- p + ggplot2::geom_vline(data = d,
    ggplot2::aes(xintercept = value, linetype = threshold), colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref))
  else p <- p + ggplot2::geom_hline(data = d,
    ggplot2::aes(yintercept = value, linetype = threshold), colour = OS_FIG$col_ref, linewidth = os_lw(OS_FIG$lw_ref))
  p + ggplot2::scale_linetype_manual(name = NULL, values = styles, breaks = names(styles),
    guide = ggplot2::guide_legend(ncol=1,order=2))
}

.os_de_guide_layout <- function() ggplot2::theme(legend.box="vertical",legend.box.just="left",
  legend.justification="left",legend.spacing.y=grid::unit(.5,"mm"))

.os_de_effect_axis <- function(estimator) {
  if(estimator=="unknown") OS_AXIS$log2fc else os_wrap(paste0("log2 fold change (",estimator,")"),42)
}

.os_de_points <- function(p, d, lab, palette, journal, italic, label_priority, ymax = NULL,
                          colour_title = NULL, colour_levels = names(palette),
                          colour_breaks = colour_levels, colour_labels = NULL) {
  shapes <- c(upper = 24, lower = 25, left = 60, right = 62, missing = 4)
  cap <- d[d$cap_direction != "none", , drop = FALSE]
  plain <- d[d$cap_direction == "none" & d$de_class != "na", , drop = FALSE]
  missing <- d[d$de_class == "na", , drop = FALSE]; missing$cap_direction <- rep("missing", nrow(missing))
  if (nrow(plain)) p <- p + ggplot2::geom_point(data = plain, ggplot2::aes(colour = .colour), shape = OS_FIG$shape_dense, size = OS_FIG$pt_dense_mm, stroke = 0)
  vertical_cap <- cap[cap$cap_direction %in% c("upper", "lower"), , drop = FALSE]
  lateral_cap <- cap[cap$cap_direction %in% c("left", "right"), , drop = FALSE]
  if (nrow(lateral_cap)) p <- p + ggplot2::geom_point(data = lateral_cap, ggplot2::aes(colour = .colour, shape = cap_direction), size = OS_FIG$pt_highlight_mm * 1.2, stroke = 0)
  if (nrow(vertical_cap)) p <- p + ggplot2::geom_point(data = vertical_cap, ggplot2::aes(colour = .colour, fill = .colour, shape = cap_direction), size = OS_FIG$pt_dense_mm * 1.3, stroke = 0)
  if (nrow(missing)) p <- p + ggplot2::geom_point(data = missing, ggplot2::aes(shape = cap_direction), colour = OS_FIG$col_reference_group, size = max(0.65, OS_FIG$pt_dense_mm * 1.5), stroke = os_lw(OS_FIG$lw_data))
  normal_lab <- lab[lab$cap_direction == "none", , drop = FALSE]
  cap_lab <- lab[lab$cap_direction != "none", , drop = FALSE]
  if (nrow(normal_lab)) p <- p + ggplot2::geom_point(data = normal_lab, ggplot2::aes(fill = .colour), shape = 21, colour = OS_FIG$col_ink, size = OS_FIG$pt_highlight_mm, stroke = os_lw(OS_FIG$lw_point_edge))
  lateral_lab <- cap_lab[cap_lab$cap_direction %in% c("left", "right"), , drop = FALSE]
  cap_lab <- cap_lab[cap_lab$cap_direction %in% c("upper", "lower"), , drop = FALSE]
  if (nrow(lateral_lab)) p <- p + ggplot2::geom_point(data = lateral_lab, ggplot2::aes(colour = .colour, shape = cap_direction), size = OS_FIG$pt_highlight_mm * 1.5, stroke = 0)
  if (nrow(cap_lab)) p <- p + ggplot2::geom_point(data = cap_lab, ggplot2::aes(fill = .colour, shape = cap_direction), colour = OS_FIG$col_ink, size = OS_FIG$pt_highlight_mm * 1.1, stroke = os_lw(OS_FIG$lw_point_edge))
  p <- p + os_label_place(.os_label_rows(d, lab, label_priority), ggplot2::aes(label = display), italic = italic, ymax = ymax, journal = journal)
  breaks <- intersect(names(shapes), c(as.character(cap$cap_direction), if (nrow(missing)) "missing"))
  labels <- c(upper = "Upper overflow", lower = "Lower overflow", left = "Left overflow", right = "Right overflow", missing = "Statistic unavailable")
  p + ggplot2::scale_colour_manual(values = palette, limits = colour_levels, name = colour_title,
        breaks = colour_breaks, labels = if (is.null(colour_labels)) ggplot2::waiver() else unname(colour_labels[colour_breaks]),
        guide = if (is.null(colour_title)) "none" else ggplot2::guide_legend(ncol=2,byrow=TRUE,title.position="top",order=1,override.aes = list(shape = 16, size = 2))) +
    ggplot2::scale_fill_manual(values = palette, limits = colour_levels, guide = "none") +
    ggplot2::scale_shape_manual(values = shapes, breaks = breaks, labels = labels[breaks], name = "Display state",
      guide = if (length(breaks)) ggplot2::guide_legend(ncol=2,byrow=TRUE,title.position="top",order=3,override.aes = list(colour = OS_FIG$col_reference_group, fill = OS_FIG$col_reference_group, size = 2)) else "none")
}

.os_de_category_counts <- function(decision, categories, denominator = NULL) {
  if (is.null(denominator)) return(NULL)
  if (!denominator %in% c("direction", "category")) .os_de_error("annotation percentages require an explicit direction or category denominator")
  rows <- list()
  for (direction in c("supported_negative", "supported_positive", "within_margin")) {
    for (category in sort(unique(categories), method = "radix")) {
      numerator <- decision$feature_id[decision$statistical_call == direction & categories == category]
      eligible <- if (denominator == "direction") decision$feature_id[decision$statistical_call == direction] else decision$feature_id[categories == category & !is.na(decision$statistical_supported)]
      rows[[length(rows) + 1L]] <- list(direction = direction, category = category, numerator_ids = as.list(numerator),
        denominator_ids = as.list(eligible), denominator_definition = if (denominator == "direction") "all statistically supported features in this direction/decision" else "all features with a finite supplied decision statistic in this annotation category",
        numerator = length(numerator), denominator = length(eligible), fraction = if (length(eligible)) length(numerator)/length(eligible) else NULL)
    }
  }
  rows
}

.os_de_category_band <- function(rows, levels, colours, hypothesis, journal) {
  directions <- if (hypothesis == "small_effect") "within_margin" else c("supported_negative", "supported_positive")
  selected <- rows[vapply(rows, function(z) z$direction %in% directions, logical(1))]
  d <- do.call(rbind, lapply(selected, function(z) data.frame(direction=z$direction, category=z$category,
    numerator=z$numerator, denominator=z$denominator, fraction=z$fraction %||% NA_real_, stringsAsFactors=FALSE)))
  d$direction <- factor(d$direction, levels=directions)
  d$category <- factor(d$category, levels=rev(levels))
  d$label <- paste0(d$numerator,"/",d$denominator," (",ifelse(is.na(d$fraction),"undefined",paste0(formatC(100*d$fraction,format="f",digits=1),"%")),")")
  labels <- c(supported_negative="Negative direction",supported_positive="Positive direction",within_margin="Within margin")
  ggplot2::ggplot(d,ggplot2::aes(direction,category)) +
    ggplot2::geom_point(ggplot2::aes(colour=category),shape=15,size=OS_FIG$pt_highlight_mm,
      position=ggplot2::position_nudge(x=-.35)) +
    ggplot2::geom_text(ggplot2::aes(label=label),size=os_fs(OS_FIG$size_annot),family=os_font_family(),
      hjust=.5,colour=OS_FIG$col_ink) +
    ggplot2::scale_x_discrete(labels=labels,drop=FALSE,expand=ggplot2::expansion(add=.6)) +
    ggplot2::scale_y_discrete(drop=FALSE,expand=ggplot2::expansion(add=.55)) +
    ggplot2::scale_colour_manual(values=colours,limits=levels,guide="none") +
    ggplot2::labs(x=NULL,y=NULL,subtitle="Full-source calls: category count / declared denominator") +
    theme_omicstat(journal=journal,legend="none") +
    ggplot2::theme(axis.line=ggplot2::element_blank(),axis.ticks=ggplot2::element_blank(),
      plot.subtitle=ggplot2::element_text(size=OS_FIG$size_annot))
}

# Deduplicate a detected union without discarding any subtype result or
# manufacturing specificity. Family IDs/members must come from the caller's
# actual model audit; this function never recalculates multiplicity correction.
os_de_detected_union <- function(tests, family_definitions, alpha = .05, p_operator = "<") {
  .os_require_cols(tests,c("feature_id","subtype","test_id","family_id","statistic_kind","statistic_value"),"detected feature union")
  for(k in c("feature_id","subtype","test_id","family_id","statistic_kind"))
    if(!is.character(tests[[k]]) || anyNA(tests[[k]]) || any(!nzchar(tests[[k]]))) .os_de_error("union test identity columns must be complete strings")
  ids <- .os_sem_rows(tests,c("feature_id","test_id"))
  mapping <- unique(tests[,c("test_id","subtype"),drop=FALSE])
  if(anyDuplicated(mapping$test_id)) .os_de_error("one test ID cannot silently represent different subtype tests")
  if(!is.numeric(tests$statistic_value) || any(is.infinite(tests$statistic_value)) ||
     any(tests$statistic_value<0 | tests$statistic_value>1,na.rm=TRUE) ||
     any(!tests$statistic_kind %in% c("raw_p","adjusted_p","qvalue"))) .os_de_error("union decisions require typed supplied P/q values")
  if(length(alpha)!=1L || !is.finite(alpha) || alpha<0 || alpha>1 || !p_operator %in% c("<","<=")) .os_de_error("invalid union decision threshold/operator")
  if(!is.list(family_definitions) || is.null(names(family_definitions)) ||
     anyDuplicated(names(family_definitions)) || !setequal(names(family_definitions),unique(tests$family_id)))
    .os_de_error("every actual union family needs a complete uniquely named definition")
  families <- lapply(names(family_definitions),function(fid) {
    f <- family_definitions[[fid]]
    if(!is.list(f) || !all(c("source_ids","method","adjustment","provenance") %in% names(f))) .os_de_error("union family lacks native source membership/provenance")
    member <- .os_sem_ids(f$source_ids,"union family source IDs",empty=TRUE)
    rows <- which(tests$family_id==fid)
    if(!all(member %in% ids[rows]) || !all(ids[rows][is.finite(tests$statistic_value[rows])] %in% member))
      .os_de_error("union family membership contradicts the full supplied test rows")
    for(k in c("method","adjustment","provenance")) .os_de_scalar(f[[k]],paste("union family",k))
    if(f$provenance=="unknown") .os_de_error("union family requires a named native provenance source")
    kind <- unique(tests$statistic_kind[rows])
    if(length(kind)!=1L) .os_de_error("one union family cannot mix statistic types")
    list(family_id=fid,source_ids=as.list(member),provenance=f$provenance,
      statistic=os_statistic_contract(fid,tests$statistic_value[rows],ids[rows],kind,
        f$method,f$adjustment,fid,length(member),threshold=alpha))
  })
  names(families) <- names(family_definitions)
  detected <- !is.na(tests$statistic_value) & .os_de_compare(tests$statistic_value,alpha,p_operator)
  all <- tests; all$source_id <- ids; all$detected <- detected
  all$decision_state <- ifelse(is.na(tests$statistic_value),"not_tested",ifelse(detected,"detected","inconclusive"))
  features <- sort(unique(tests$feature_id[detected]),method="radix")
  union <- data.frame(feature_id=features,n_detected_tests=integer(length(features)),
    n_detected_subtypes=integer(length(features)),detected_subtypes=character(length(features)),
    interpretation=character(length(features)),stringsAsFactors=FALSE)
  for(i in seq_along(features)) {
    rows <- detected & tests$feature_id==features[i]
    subtypes <- sort(unique(tests$subtype[rows]),method="radix")
    union$n_detected_tests[i] <- sum(rows); union$n_detected_subtypes[i] <- length(subtypes)
    union$detected_subtypes[i] <- as.character(jsonlite::toJSON(subtypes,auto_unbox=FALSE))
    union$interpretation[i] <- if(length(subtypes)==1L)paste0("Detected only in ",subtypes," among supplied tests")else"Detected in multiple supplied subtype tests"
  }
  by_subtype <- do.call(rbind,lapply(sort(unique(tests$subtype),method="radix"),function(s) {
    rows<-tests$subtype==s
    data.frame(subtype=s,n_source_tests=sum(rows),n_finite_statistic=sum(rows & is.finite(tests$statistic_value)),
      n_detected_tests=sum(rows & detected),n_unique_detected_features=length(unique(tests$feature_id[rows & detected])),stringsAsFactors=FALSE)
  }))
  list(union=union,all_tests=all,per_subtype=by_subtype,
    counts=list(n_source_tests=nrow(tests),n_detected_tests=sum(detected),n_unique_detected_features=length(features)),
    definition=list(source_sha256=os_semantic_table_sha256(tests,ids),families=families,
      alpha=alpha,p_operator=p_operator,aggregation="one union row per original feature ID; all subtype tests retained",
      specificity_claim=FALSE,interaction_test_performed=FALSE,separate_selected_family_FDR=FALSE,
      selection_display="a heatmap of this union is selected-result description, not independent validation or an effect confidence interval"))
}

.os_de_annotation <- function(ft, mode, annotation_col = NULL, annotation_title = NULL,
                              annotation_levels = NULL, colour_registry = NULL, tercile_cutpoints = NULL) {
  if (mode == "decision") return(NULL)
  if (!mode %in% c("annotation", "effect_tercile")) .os_de_error("unknown volcano colour mode")
  if (mode == "annotation") {
    .os_require_cols(ft, annotation_col %||% "<annotation column required>", "annotation colouring")
    .os_de_scalar(annotation_title, "annotation legend title")
    values <- as.character(ft[[annotation_col]]); values[is.na(values) | !nzchar(values)] <- "Missing annotation"
    levels <- annotation_levels %||% sort(unique(values), method = "radix")
    .os_require_ids(levels, "annotation levels")
    if (!setequal(levels, unique(values))) .os_de_error("annotation levels must contain exactly the displayed source categories including missing")
    key <- as.character(jsonlite::toJSON(list("de_annotation", annotation_title), auto_unbox = TRUE))
    reg <- os_colours_for(levels, key, colour_registry)
    cols <- reg$colours; cols[names(cols) == "Missing annotation"] <- OS_FIG$col_reference_group
    reg$registry$families[[key]][names(cols)] <- cols
    return(list(values = values, levels = levels, colours = cols, title = annotation_title,
      registry = reg$registry, definition = list(mode = mode, source_column = annotation_col,
        legend_title = annotation_title, levels = as.list(levels), missing = "Missing annotation", no_change_to_statistical_calls = TRUE)))
  }
  if (is.null(tercile_cutpoints)) {
    x <- abs(ft$log2fc[is.finite(ft$log2fc)])
    if (!length(x)) .os_de_error("effect terciles need finite supplied effects")
    tercile_cutpoints <- unname(stats::quantile(x, c(1/3, 2/3), type = 7))
    cut_source <- "type-7 quantiles of absolute plotted effects over the full supplied feature universe"
  } else cut_source <- "explicit supplied cutpoints"
  if (!is.numeric(tercile_cutpoints) || length(tercile_cutpoints) != 2L || any(!is.finite(tercile_cutpoints)) || any(tercile_cutpoints < 0) || diff(tercile_cutpoints) < 0) .os_de_error("tercile cutpoints must be two ordered nonnegative finite values")
  values <- ifelse(!is.finite(ft$log2fc), "Unavailable effect", ifelse(abs(ft$log2fc) <= tercile_cutpoints[1], "Lower absolute-effect tercile", ifelse(abs(ft$log2fc) <= tercile_cutpoints[2], "Middle absolute-effect tercile", "Upper absolute-effect tercile")))
  levels <- c("Lower absolute-effect tercile", "Middle absolute-effect tercile", "Upper absolute-effect tercile", "Unavailable effect")
  cols <- stats::setNames(c(OS_PAL_GROUP[1:3], OS_FIG$col_reference_group), levels)
  levels <- levels[levels %in% unique(values)]; cols <- cols[levels]
  list(values = values, levels = levels, colours = cols, title = "Absolute plotted effect tercile", registry = colour_registry,
       definition = list(mode = mode, cutpoints = as.list(tercile_cutpoints), cutpoint_source = cut_source,
                         interval_rule = "lower <= cut1; middle > cut1 and <= cut2; upper > cut2; ties not forcibly split",
                         no_change_to_statistical_calls = TRUE))
}
