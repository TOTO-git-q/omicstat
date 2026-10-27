# All geometry uses already computed tables. No fitting or CI estimation here.
omicstat_agreement_render <- function(res, out, module) {
  os_agreement_release(res)
  m <- res$metadata; native <- res$object$native
  if (m$analysis == "bland-altman") {
    p <- os_bland_altman(res$tables$pairs, res$tables$effect_table,
      unname(m$labels[m$method_cols]), m$estimand$difference, m$outcome_unit,
      m$independent_unit, m$confidence_level, native$ci_method, m$dataset_name,
      acceptability_limits = if (native$clinical_limits_supplied) c(native$clinical_lower, native$clinical_upper) else NULL,
      acceptability_rationale = m$estimand$acceptability_rationale, journal = m$journal)
    os_finalize_figure(p, file.path(out, "figures", "bland_altman"), width = "double", height_mm = 110, journal = m$journal, root = out)
  } else if (m$analysis == "kappa") {
    tab <- native$contingency; dimnames(tab) <- list(unname(m$labels[m$levels]), unname(m$labels[m$levels]))
    # Counts and row percentages retain explicit denominators and true zero cells.
    totals <- rowSums(tab); text <- matrix("", nrow(tab), ncol(tab), dimnames = dimnames(tab))
    for (i in seq_len(nrow(tab))) for (j in seq_len(ncol(tab)))
      text[i, j] <- if (totals[i] == 0) paste0(tab[i, j], "\nundefined (0 denominator)") else
        sprintf("%g\n%.1f%% of row", tab[i, j], 100 * tab[i, j] / totals[i])
    p <- os_heatmap(tab, value_title = "Independent-unit count", scale_type = "sequential", cluster_rows = FALSE, cluster_cols = FALSE,
      italic_rows = FALSE, cell_text = text, journal = m$journal, matrix_kind = "measurements", row_entity = "rater_1_category",
      col_entity = "rater_2_category", quantity = "cross_classification_count", unit = "independent_units",
      normalization = "identity", row_axis_role = "design", col_axis_role = "design",
      row_axis_keys = stats::setNames(seq_len(nrow(tab)), rownames(tab)),
      col_axis_keys = stats::setNames(seq_len(ncol(tab)), colnames(tab)),
      clustering_provenance = list(source = "complete declared contingency table", preprocessing = "none; no clustering"),
      # rows = first rater / method, columns = second; titles come from the input column labels
      row_title = unname(m$labels[m$raters[1]]), col_title = unname(m$labels[m$raters[2]]),
      row_label_side = "left",
      col_label_angle = if (ncol(tab) <= 6L && max(nchar(colnames(tab))) <= 12L) 0 else 45)
    caption <- paste0("Dataset: ", m$dataset_name, ". Rows: ", m$labels[m$raters[1]], "; columns: ", m$labels[m$raters[2]],
      ". Complete declared category order retained. Cells show counts and row percentages; numerator is the cell count and denominator its row total. ",
      "A zero row total is undefined, not 0%. Colour encodes count, not percentage. Total independent units: ", native$n,
      ". Kappa and its CI are in effect_table.csv; high observed agreement alone does not establish interchangeability.")
    p <- os_with_meta(p, caption = caption, figure_type = "agreement_contingency", evidence_refs = os_figure_evidence("agreement_contingency"),
      notes = list(dataset = m$dataset_name, denominators = as.list(totals), real_owner_receipt = NULL))
    os_finalize_figure(p, file.path(out, "figures", "agreement_contingency"), width = "double", journal = m$journal, root = out)
  } else {
    os_write_text(c("The copied ICC/Fleiss result is tabular; no undeclared figure is generated.",
      "See effect_table.csv, declared ICC form or Fleiss chance model and interval method. A module owner sheet remains pending."),
      file.path(out, "figures", "NOT_APPLICABLE.txt"))
  }
}
