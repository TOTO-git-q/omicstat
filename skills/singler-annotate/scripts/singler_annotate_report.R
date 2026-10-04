singler_annotate_render <- function(r, a) {
  os_backend_csv(r$annotations, file.path(a$outdir, "tables", "annotations.csv"))
  os_backend_csv(data.frame(unit_id = rownames(r$scores), r$scores, check.names = FALSE), file.path(a$outdir, "tables", "scores.csv"))
  os_backend_csv(data.frame(cluster = rownames(r$cross), r$cross, check.names = FALSE), file.path(a$outdir, "tables", "cluster_labels.csv"))
  plots <- list(scores = os_singler_score_heatmap(r$scores, as.character(r$prediction$labels), r$resolved$pruneScores$nmads, a$journal, r$resolved$pruneScores$min.diff.med, r$resolved$pruneScores$min.diff.next),
                cluster_labels = os_singler_crosstab(r$cross, r$n_cells, r$resolved$pruneScores$nmads, a$journal, r$resolved$pruneScores$min.diff.med, r$resolved$pruneScores$min.diff.next))
  lapply(names(plots), function(nm) os_finalize_figure(plots[[nm]], file.path(a$outdir, "figures", nm), width = "double", journal = a$journal))
}
singler_annotate_report <- function(r, a, qc, figs, module_dir) {
  vals <- list(n_cells = r$n_cells, n_assigned = r$n_assigned, n_unassigned = r$n_cells-r$n_assigned,
    reference = a[["reference-name"]], reference_version = a[["reference-version"]], species = a$species,
    reference_sha256 = digest::digest(file = a$reference, algo = "sha256"), unit = a$unit,
    test_role = r$resolved$SingleR[["assay.type.test"]], de_method = r$resolved$SingleR[["de.method"]], de_n = r$resolved$SingleR[["de.n"]] %||% "NULL",
    fine_tune = r$resolved$SingleR[["fine.tune"]], aggr_ref = r$resolved$SingleR[["aggr.ref"]], quantile = r$resolved$SingleR$quantile,
    tune_thresh = r$resolved$SingleR[["tune.thresh"]], nmads = r$resolved$pruneScores$nmads, min_diff_med=r$resolved$pruneScores$min.diff.med, min_diff_next=r$resolved$pruneScores$min.diff.next, resolved_native=jsonlite::toJSON(r$resolved,auto_unbox=TRUE,null="null",digits=NA), seed = a$seed,
    singler_version = as.character(utils::packageVersion("SingleR")))
  tm <- os_read_templates(file.path(module_dir, "references", "reporting-templates.md"))
  caps <- vapply(figs, function(f) f$spec_obj$caption %||% "", "")
  text <- if (qc$blocking) c("# Draft withheld", "All labels pruned; review qc/qc_results.csv.") else
    c("# SingleR Methods and Results", "", "## Methods", os_fill_template(tm$methods, vals), "", "## Results", os_fill_template(tm$results, vals), "", "## Figure legends", caps)
  os_write_text(text, file.path(a$outdir, "draft", "methods_results.md"))
  dir.create(file.path(a$outdir, "results"), showWarnings = FALSE)
  vals$resolved_native <- r$resolved
  vals$qc_triggered <- as.list(qc$table$id[qc$table$triggered]); vals$n_common_features <- r$n_common
  jsonlite::write_json(vals, file.path(a$outdir, "results", "singler_annotate_results.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
}
