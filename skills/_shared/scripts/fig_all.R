# fig_all.R -- load the complete omicstat figure layer in dependency order.
# ASCII only on purpose. Usage from a module script:
#   source(file.path(shared_dir, "scripts", "fig_all.R"))
# (the directory of this file is found from the sourcing call itself, so it
# works from any working directory).

local({
  this <- tryCatch(normalizePath(sys.frame(1)$ofile, mustWork = TRUE), error = function(e) NULL)
  d <- if (!is.null(this)) dirname(this) else getOption("omicstat.shared_scripts", ".")
  # extension files last: fig_sc_extra.R needs fig_sc.R + fig_heatmap.R,
  # fig_enrich_network.R needs fig_enrich.R + fig_heatmap.R; module-group
  # builders (MODULE_BUILD_BRIEF sec 4) after everything they may call
  for (f in c("fig_style.R", "fig_semantics.R", "fig_matrix_semantics.R", "fig_heatmap.R", "fig_de_semantics.R", "fig_bulk.R", "fig_de_replicates.R", "fig_enrich.R", "fig_sc.R",
              "fig_network.R", "fig_compose.R", "fig_sc_extra.R", "fig_embedding_pages.R", "fig_enrich_network.R",
              "fig_mod_bulk.R", "fig_mod_enrich.R", "fig_mod_bulk_limma.R",
              "fig_mod_enrich_rank.R", "fig_mod_models.R", "fig_evidence.R", "fig_mod_survival.R", "fig_mod_groupcomp.R", "fig_mod_calibration.R", "fig_mod_agreement.R", "fig_mod_roc.R", "fig_mod_distribution.R")) {
    sys.source(file.path(d, f), envir = globalenv())
  }
})
