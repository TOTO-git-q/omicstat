# Opt-in model figure tokens; existing module appearance is unchanged.
OS_FIG_MODEL <- list(jitter_width = 0.12, bracket_tip_fraction = 0.025,
                    range_alpha = 0.12, censor_shape = 3, km_heights = c(3, 1))
# Evidence is descriptive design support, never a statistical validation claim.
# Until 20 independent records per family have been reviewed, keep pending.
os_figure_evidence <- function(family, refs = list()) {
  if (!length(refs)) {
    refs <- switch(family,
      survival = list(list(record_id = "0005", path = "docs/figure-evidence/records/0005_amara_2024_fig1.json", independent_figure_key = "10.1038/s41467-024-45132-2::Figure 1", sha256 = "f65a74817c1dc554e3ef29ab9db09479bb6bc3f8ff8e7c37118625affd5716c0", source_ref = "research/figure-evidence-301-20261015", support = "transferable_visual_design_only"),
        list(record_id = "0006", path = "docs/figure-evidence/records/0006_sujit_2024_fig4.json", independent_figure_key = "10.1038/s41467-024-47512-0::Figure 4", sha256 = "e948528c35fc16c89a8f5a5dff205948065f2eacb3a2bfeec6d6833238aed68b", source_ref = "research/figure-evidence-301-20261015", support = "transferable_visual_design_only")),
      group_comparison = list(list(record_id = "0013", path = "docs/figure-evidence/records/0013_buettner_2021_fig3.json", independent_figure_key = "10.1038/s41467-021-27150-6::Figure 3", sha256 = "038b9b7501ea10e470f849896f638d0f60c2969b45100fb58705100371b19fe9", source_ref = "research/figure-evidence-301-20261015", support = "transferable_visual_design_only")),
      list())
  }
  result <- list(list(status = "pending", family = family, required_independent_records = 20L,
       records = refs, reason = "Per-family independent visual review is incomplete"))
  if (exists("os_validate_evidence_refs", mode="function")) os_validate_evidence_refs(result)
  result
}

os_plot_columns <- function(d, columns, numeric = character()) {
  if (!is.data.frame(d) || !nrow(d) || !all(columns %in% names(d)))
    stop("OS_INVALID_INPUT: figure input lacks required rows/columns", call. = FALSE)
  if (anyNA(d[, columns, drop = FALSE])) stop("OS_INVALID_INPUT: figure data contain missing values", call. = FALSE)
  for (n in numeric) if (!is.numeric(d[[n]]) || any(!is.finite(d[[n]])))
    stop(sprintf("OS_INVALID_INPUT: %s must be finite numeric", n), call. = FALSE)
  invisible(d)
}

os_plot_probability <- function(d, columns) {
  os_plot_columns(d, columns, columns)
  if (any(vapply(d[columns], function(x) any(x < 0 | x > 1), logical(1))))
    stop("OS_INVALID_INPUT: probabilities must be between zero and one", call. = FALSE)
}
