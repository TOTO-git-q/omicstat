proc_roc_render <- function(res, out, module) {
  os_proc_roc_release(res)
  m <- res$metadata; t <- res$tables; primary <- m$markers[1]
  draw <- function(curve, auc, name, band = NULL, cutoff = NULL, comparisons = NULL, partial = NULL) {
    plot <- os_roc_curve(curve, auc, m$dataset_name, m$independent_unit, m$n_positive, m$n_negative,
      m$confidence_level, m$direction, band, cutoff, comparisons, partial, m$journal)
    os_finalize_figure(plot, file.path(out, "figures", name), width = "double", height_mm = 110, journal = m$journal, root = out)
  }
  curve <- t$roc_curve[t$roc_curve$marker == primary, , drop = FALSE]
  auc <- t$auc_summary[t$auc_summary$marker == primary, , drop = FALSE]
  draw(curve, auc, "roc_primary", t$roc_band, t$cutoff_marker)
  if (length(m$markers) > 1L) draw(t$roc_curve, t$auc_summary, "roc_comparison", comparisons = t$auc_comparison)
  if (!is.null(t$partial_auc)) draw(curve, auc, "pauc_region", partial = t$partial_auc)
  os_write_text(c("Participant flow is available as a checked count table. The old clinical diagram/theme was not copied.",
    "Score-distribution and participant-flow figure adapters remain explicitly pending. ROC figures use aggregates only; source and fitted objects can contain private input rows and must not be uploaded."),
    file.path(out, "figures", "ADAPTER_GAPS.txt"))
  if (file.exists("Rplots.pdf")) stop("OS_INVALID_RESULT: ROC-21 stray Rplots.pdf in the working directory; preserve evidence and use a clean explicit-device run", call. = FALSE)
}
