scater_qc_render <- function(r, a) {
  dir.create(file.path(a$outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  for (k in c("metrics", "thresholds", "flow")) utils::write.csv(r[[k]], file.path(a$outdir, "tables", paste0(k, ".csv")), row.names = FALSE)
  cap <- sprintf("QC of %d input cells; %d retained. %s. Bounds and per-batch values: tables/thresholds.csv. Counts are raw; no doublet removal.", nrow(r$metrics), ncol(r$sce),
    if (a[["qc-mode"]] == "mad") sprintf("Lower log2 count/feature and higher mitochondrial outliers, nmads=%s", a$nmads) else sprintf("Counts >= %s; features >= %s; mitochondrial percent <= %s", a[["min-counts"]], a[["min-features"]], a[["max-mito"]]))
  for (y in c("detected", "subsets_Mito_percent")) {
    p <- os_bioc_scatter(r$metrics, "sum", y, "status", cap, registry = r$colours, journal = a$journal, thresholds = r$thresholds, qc_status = TRUE)
    os_finalize_figure(p, file.path(a$outdir, "figures", y), journal = a$journal, root = a$outdir)
  }
  p <- os_bioc_qc_violin(r$metrics, r$thresholds, cap, a$journal)
  os_finalize_figure(p, file.path(a$outdir, "figures", "qc_violin"), journal = a$journal, root = a$outdir)
  c("tables/metrics.csv", "tables/thresholds.csv", "tables/flow.csv", "figures/detected.png", "figures/subsets_Mito_percent.png", "figures/qc_violin.png")
}
scater_qc_report <- function(r, a, qc, module_dir) {
  t <- os_read_templates(file.path(module_dir, "references", "reporting-templates.md"))
  vals <- list(version = as.character(utils::packageVersion("scuttle")), mode = a[["qc-mode"]],
    settings = if (a[["qc-mode"]] == "mad") paste("nmads", a$nmads, "; lower log2 totals/detected and higher untransformed mitochondrial percent") else
      sprintf("minimum counts %s, minimum detected %s, maximum mitochondrial percent %s", a[["min-counts"]], a[["min-features"]], a[["max-mito"]]),
    batch = a[["batch-col"]] %||% "none", n_input = nrow(r$metrics), n_retained = ncol(r$sce), n_removed = sum(r$metrics$discard))
  os_write_text(c(os_fill_template(t$methods, vals), "", os_fill_template(t$results, vals)), file.path(a$outdir, "draft", "methods_results.md"))
  cat("\nSupplementary native arguments: ", jsonlite::toJSON(list(metrics = os_bioc_native_args(a[["metrics-args"]]), filters = os_bioc_native_args(a[["filter-args"]])), auto_unbox = TRUE), "\n", file = file.path(a$outdir, "draft", "methods_results.md"), append = TRUE)
  dir.create(file.path(a$outdir, "results"), showWarnings = FALSE)
  jsonlite::write_json(c(vals, list(qc = qc$table, state = r$state)), file.path(a$outdir, "results", "scater_qc_results.json"), auto_unbox = TRUE, pretty = TRUE)
}
