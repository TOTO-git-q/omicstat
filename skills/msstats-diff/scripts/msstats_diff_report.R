# Output contract uses shared provenance, QC, feature table and figure layers.
msstats_diff_report <- function(res, a, outdir, argv, inputs, module_dir) {
  for (x in c("tables", "objects", "results", "draft", "figures")) dir.create(file.path(outdir, x), recursive = TRUE, showWarnings = FALSE)
  write_feature_table(res$ft, file.path(outdir, "tables/feature_table.csv"))
  utils::write.csv(res$full, file.path(outdir, "tables/engine_full.csv"), row.names = FALSE, na = "NA")
  utils::write.csv(res$samples, file.path(outdir, "objects/sample_table.csv"), row.names = FALSE, na = "NA")
  saveRDS(res$fit, file.path(outdir, "objects/fit.rds"), version = 3)
  if (!is.null(res$matrix)) utils::write.csv(data.frame(feature_id = rownames(res$matrix), res$matrix, check.names = FALSE),
      file.path(outdir, "tables/fitted_log2_matrix.csv"), row.names = FALSE, na = "NA")
  if (!is.null(res$processed)) {
    saveRDS(res$processed, file.path(outdir, "objects/processed.rds"), version = 3)
    utils::write.csv(as.data.frame(res$processed$ProteinLevelData), file.path(outdir, "tables/protein_level.csv"), row.names = FALSE, na = "NA")
    utils::write.csv(as.data.frame(res$processed$FeatureLevelData), file.path(outdir, "tables/feature_level.csv"), row.names = FALSE, na = "NA")
  }
  qc <- msstats_diff_qc(res, a); os_write_qc_results(qc, outdir)
  valid <- res$ft$filtered_reason == "" & is.finite(res$ft$log2fc) & is.finite(res$ft$padj)
  if (any(valid) && (res$details$n_issue_rows %||% 0L) == 0L) {
    p <- os_volcano(res$ft, padj_threshold = a$alpha, lfc_threshold = 0, label_n = a[["label-n"]],
                    contrast_label = paste(a$target, "vs", a$reference), method_label = "MSstats (experimental)",
                    italic_labels = FALSE, journal = a$journal)
    os_finalize_figure(p, file.path(outdir, "figures/volcano"), journal = a$journal, root = outdir)
  }
  templates <- os_read_templates(file.path(module_dir, "references/reporting-templates.md"))
  values <- list(package_version = as.character(utils::packageVersion("MSstats")), target = a$target, reference = a$reference,
                 n_target = res$details$n_target, n_reference = res$details$n_reference, alpha = a$alpha,
                 settings = jsonlite::toJSON(res$details, auto_unbox = TRUE, null = "null"))
  os_write_text(c("# Experimental analysis audit", "Publication draft withheld: numerical acceptance is pending.",
                 os_fill_template(templates$methods, values)), file.path(outdir, "draft/analysis_audit.md"))
  jsonlite::write_json(list(module = "msstats-diff", version = "0.1.0", acceptance = "pending_numerical_replay",
       publication_ready = FALSE, details = res$details, n_input_features = nrow(res$ft),
       n_estimable = sum(valid), n_bh_below_alpha = sum(valid & res$ft$padj < a$alpha, na.rm = TRUE),
       interpret_counts = !qc$blocking), file.path(outdir, "results/results.json"), auto_unbox = TRUE, pretty = TRUE, na = "null")
  # Quarantine experimental outputs: no hash-valid chain can use them for inference.
  write_handoff(outdir, basename(outdir), "msstats-diff", "0.1.0",
      objects = list(feature_table = list(path = file.path(outdir, "tables/feature_table.csv"), type = "feature_table"),
                     sample_table = list(path = file.path(outdir, "objects/sample_table.csv"), type = "sample_table")),
      ecosystem = "neutral", state = list(candidate = TRUE, development_only = TRUE, display_only = TRUE, acceptance_pending = TRUE, assay = "proteomics",
                                          feature_id_type = a[["feature-id-type"]]))
  outputs <- setdiff(list.files(outdir, recursive = TRUE, all.files = FALSE), "qc/engine_warnings.csv")
  os_write_provenance(outdir, "msstats-diff", "0.1.0", argv, "run_msstats_diff.R", a$seed,
       inputs = inputs, outputs = outputs, extra = list(acceptance = "pending_numerical_replay", feature_id_type = a[["feature-id-type"]]))
  qc
}
