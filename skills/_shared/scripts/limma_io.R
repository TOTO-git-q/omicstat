# Shared input and output helpers for the three limma S2 modules.
# Estimator calls remain in each module's registered core.

os_limma_design <- function(mat, st, a, block_col = NULL, allow_multilevel = FALSE) {
  if (!a$condition %in% names(st)) stop("OS_MISSING_COLUMN: condition column is absent.", call. = FALSE)
  if (identical(a$reference, a$target) || !all(c(a$reference, a$target) %in% st[[a$condition]]))
    stop("OS_INVALID_PARAMETER: reference and target must be distinct observed levels.", call. = FALSE)
  cvs <- if (is.null(a$covariates)) character(0) else trimws(strsplit(a$covariates, ",", fixed = TRUE)[[1]])
  if (any(!nzchar(cvs)) || anyDuplicated(cvs) || a$condition %in% cvs || !all(cvs %in% names(st)))
    stop("OS_INVALID_DESIGN: covariates must be distinct sample columns other than condition.", call. = FALSE)
  if (!allow_multilevel && length(unique(st[[a$condition]])) != 2L)
    stop("OS_INVALID_DESIGN: this module requires exactly two condition levels.", call. = FALSE)
  other_levels <- sort(setdiff(unique(st[[a$condition]]), c(a$reference, a$target)), method = "radix")
  st[[a$condition]] <- factor(st[[a$condition]], levels = c(a$reference, a$target, other_levels))
  for (cv in cvs) {
    if (anyNA(st[[cv]])) stop("OS_INVALID_DESIGN: a covariate has missing values.", call. = FALSE)
    if (length(unique(st[[cv]])) < 2L) stop("OS_INVALID_DESIGN: a covariate has one level.", call. = FALSE)
    st[[cv]] <- factor(st[[cv]], levels = sort(unique(st[[cv]]), method = "radix"))
  }
  f <- stats::as.formula(sprintf("~ %s", paste(c(cvs, a$condition), collapse = " + ")))
  mm <- stats::model.matrix(f, data = st)
  if (qr(mm)$rank != ncol(mm)) stop("OS_INVALID_DESIGN: design is not full rank; check confounding.", call. = FALSE)
  if (ncol(mat) - qr(mm)$rank < 2L) stop("OS_INVALID_DESIGN: at least two residual degrees of freedom are required.", call. = FALSE)
  coef <- paste0(a$condition, a$target)
  if (!coef %in% colnames(mm)) stop("OS_INVALID_DESIGN: target contrast is not estimable; use syntactic factor levels.", call. = FALSE)
  ns <- table(st[[a$condition]])
  if (any(ns[c(a$reference, a$target)] < 2L)) stop("OS_QC_BLOCKER: fewer than two biological replicates in a compared group.", call. = FALSE)
  block <- NULL
  biological <- unname(ns[c(a$reference,a$target)])
  if (!is.null(block_col)) {
    if (!block_col %in% names(st)) stop("OS_MISSING_COLUMN: block column is absent.", call. = FALSE)
    block <- st[[block_col]]
    if (anyNA(block) || any(!nzchar(block))) stop("OS_INVALID_DESIGN: block has missing values.", call. = FALSE)
    if (all(table(block) == 1L)) stop("OS_QC_BLOCKER: block has no repeated unit.", call. = FALSE)
    bm <- stats::model.matrix(~ 0 + factor(block))
    if (qr(cbind(mm, bm))$rank == qr(mm)$rank)
      stop("OS_INVALID_DESIGN: block is spanned by the fixed-effect design.", call. = FALSE)
    if (identical(a[["block-role"]] %||% "correlated_unit", "correlated_unit")) {
      biological <- vapply(c(a$reference, a$target), function(g) length(unique(block[st[[a$condition]] == g])), integer(1))
      if (any(biological < 2L)) stop("OS_PSEUDOREPLICATION: each compared group needs at least two independent correlated units; repeated observations are not biological replicates.", call. = FALSE)
    }
  }
  list(design = mm, coef = coef, formula = deparse(f), samples = st, block = block,
       n_target = unname(biological[2]), n_reference = unname(biological[1]),
       n_target_observations = unname(ns[a$target]), n_reference_observations = unname(ns[a$reference]),
       biological_reference=biological[1], biological_target=biological[2],
       n_blocks = if (is.null(block)) NULL else length(unique(block)))
}

# res$annotation (optional): data.frame(feature_id, symbol, entrez, ...) with
# one row per tested feature (after any technical averaging), built by the
# module from an explicit, hashed mapping; missing symbols are "" and their
# annotation_status is "unmapped" (S3 limma-array F3).
os_limma_feature <- function(tt, model, a, module, annotation = NULL) {
  ids <- rownames(tt)
  if (is.null(ids)) stop("OS_INVALID_RESULT: top table has no feature IDs.", call. = FALSE)
  sym <- rep("", length(ids))
  if (!is.null(annotation)) {
    ix <- match(ids, annotation$feature_id)
    sym <- ifelse(is.na(ix) | is.na(annotation$symbol[ix]), "", as.character(annotation$symbol[ix]))
  }
  x <- data.frame(feature_id = ids, symbol = sym, contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference),
                  base_mean = tt$AveExpr, log2fc = tt$logFC, log2fc_se = NA_real_,
                  stat = tt$t, pvalue = tt$P.Value, padj = tt$adj.P.Val,
                  method = module, shrinkage = "none", n_group1 = model$n_target,
                  n_group2 = model$n_reference, filtered_reason = "", stringsAsFactors = FALSE)
  as_feature_table(x)
}

# Direction summary of the audited coefficient (decideTests method =
# "separate" semantics on the topTable of that coefficient: BH adjusted P <
# alpha, sign of logFC; S3 limma-array F3).
os_limma_direction_summary <- function(tt, alpha, coef, lfc = 0) {
  sig <- !is.na(tt$adj.P.Val) & tt$adj.P.Val < alpha
  data.frame(coefficient = coef, Down = sum(sig & tt$logFC < 0), NotSig = sum(!sig), Up = sum(sig & tt$logFC > 0),
             adjust_method = "BH", p_value = alpha, lfc = lfc, stringsAsFactors = FALSE)
}

os_limma_qc <- function(ft, model, a, prefix, n_input, extra = list()) {
  rows <- list(
    os_qc_rule(paste0(prefix, "-01"), "replicates per group", min(model$biological_target %||% model$n_target, model$biological_reference %||% model$n_reference) < 3L,
               "warning", "A compared group has only two biological replicates.", "Interpret uncertainty cautiously.", "ENGINEERING_PLAN 4.5"),
    os_qc_rule(paste0(prefix, "-02"), "tested features", nrow(ft) < 100L,
               "warning", "Fewer than 100 features were tested.", "Check input and filtering.", "PACK C; ENGINEERING_PLAN 4.5"),
    os_qc_rule(paste0(prefix, "-03"), "adjusted P values", all(is.na(ft$padj)),
               "error", "All adjusted P values are NA.", "Inspect model and residual df.", "ENGINEERING_PLAN 4.5"),
    os_qc_rule(paste0(prefix, "-04"), "finite effects", any(!is.finite(ft$log2fc)),
               "error", "Some log2 fold changes are non-finite.", "Inspect affected rows.", "ENGINEERING_PLAN 4.5"),
    os_qc_rule(paste0(prefix, "-05"), "all features significant", nrow(ft) > 1L && all(!is.na(ft$padj) & ft$padj < a$alpha),
               "warning", "Every feature is significant.", "Check design and input scale.", "ENGINEERING_PLAN 4.5"))
  os_qc_finalize(c(rows, extra), "tables/feature_table.csv")
}

# Writer shared by limma-voom, limma-array and limma-dupcor (S4 revision).
# The module core returns `res` with:
#   fit, tt (topTable of model$coef), elist (EList or NULL), detail/details;
#   expr (matrix actually fitted: voom E / normalized log2 intensities, rows =
#     fitted features) and expr_scale (one phrase naming its scale);
#   weights_note: which observation weights the fit used ("voom precision
#     weights", "voom precision weights x sample quality weights", "none");
#   template_values (named list): extra Methods slots from the ACTUAL run;
#   annotation (optional, see os_limma_feature), annotation_source (label);
#   mds (optional): list(coords = data.frame(sample, dim1, dim2),
#     var_explained, top, gene_selection, input_label, n_features) from
#     limma::plotMDS(plot = FALSE) called in the module core;
#   voom_trend (optional): list(xy, line, span) from voom save.plot = TRUE;
#   probe_map, sa (as before).
# Hand-off (S4 contracts a/b): feature_table, MArrayLM fit, EList (with its
# weights) when present, expression_matrix (+ scale / weights provenance in
# state), sample_table, ranked_list (moderated t of the single coefficient)
# with its metadata. The EList carries the precision weights that camera /
# roast need; the expression_matrix is the explicit weight-free conversion
# for GSVA-type consumers (state records that weights were dropped).
os_limma_figure_context <- function(res, ft, model, a, module) {
  zero <- is.null(a[["min-effect-fc"]]) || a[["min-effect-fc"]] == 1
  native_margin <- res$fit$treat.lfc %||% 0
  expected_margin <- if (zero) 0 else log2(a[["min-effect-fc"]])
  if (!isTRUE(all.equal(as.numeric(native_margin), expected_margin, tolerance = 0)))
    stop("OS_INVALID_RESULT: limma test margin disagrees with the actual fitted object.", call. = FALSE)
  matched <- match(ft$feature_id, rownames(res$fit$coefficients))
  table_matched <- match(ft$feature_id, rownames(res$tt))
  tested_p <- res$fit$p.value[, model$coef]
  if (anyNA(matched) || anyNA(table_matched) || anyDuplicated(ft$feature_id) ||
      !isTRUE(all.equal(ft$pvalue, unname(tested_p[matched]), check.attributes = FALSE, tolerance = 0)) ||
      !isTRUE(all.equal(ft$padj, res$tt$adj.P.Val[table_matched], check.attributes = FALSE, tolerance = 0)) ||
      !isTRUE(all.equal(ft$log2fc, unname(res$fit$coefficients[matched, model$coef]), check.attributes = FALSE, tolerance = 0)) ||
      !setequal(ft$feature_id[is.finite(ft$padj)], rownames(res$fit$coefficients)[is.finite(tested_p)]))
    stop("OS_INVALID_RESULT: limma displayed P values/family differ from the complete native coefficient test.", call. = FALSE)
  hypothesis <- if (zero) "zero_effect" else "minimum_effect"
  margin <- if (zero) 0 else log2(a[["min-effect-fc"]])
  backend_version <- as.character(utils::packageVersion("limma"))
  test_id <- paste(module, model$coef, if (zero) "eBayes" else "TREAT", sep = ":")
  list(
    test = os_de_test_contract(hypothesis, margin, hypothesis, margin,
      p_value_source = "Current fitted limma object; full topTable P.Value and adj.P.Val",
      test_id = test_id, prespecified = TRUE,
      test_method = if (zero) "limma moderated t" else "limma TREAT", model_id = model$formula,
      software = "limma", software_version = backend_version, prior = "empirical-Bayes variance moderation", shrinkage = "no display coefficient shrinkage"),
    effect = list(plotted_estimator = "limma coefficient estimate", tested_estimator = "limma coefficient estimate",
      tested_effect_col = "log2fc", software = "limma", software_version = backend_version,
      shrinkage = "none for plotted logFC", prior = "empirical-Bayes variance moderation",
      contrast = list(numerator = a$target, reference = a$reference, expanded_control = "unknown"),
      sample_counts = list(reference_biological_units = model$n_reference, target_biological_units = model$n_target,
        reference_observations = model$n_reference_observations, target_observations = model$n_target_observations),
      independent_unit = if (is.null(model$block)) "declared biological sample" else "declared correlated biological unit"),
    family_id = test_id, family_size = sum(is.finite(ft$padj)),
    family_source_ids = ft$feature_id[is.finite(ft$padj)], display_threshold = a[["display-lfc-filter"]] %||% 0,
    abundance_unit = if (module == "limma-voom" || identical(a$mode, "rna")) "log2 counts per million" else "log2 normalized intensity")
 }

os_limma_write <- function(res, mat, model, a, module, version, prefix, outdir, module_dir, argv, entry, inputs, upstream = NULL, extra_qc = list()) {
  for (d in c("tables", "figures", "results", "draft", "objects")) dir.create(file.path(outdir, d), recursive = TRUE, showWarnings = FALSE)
  ft <- os_limma_feature(res$tt, model, a, module, res$annotation)
  write_feature_table(ft, file.path(outdir, "tables", "feature_table.csv"))
  full <- res$tt
  if (!is.null(res$annotation)) {
    ix <- match(rownames(full), res$annotation$feature_id)
    extra_cols <- setdiff(names(res$annotation), "feature_id")
    for (k in rev(extra_cols)) full <- cbind(stats::setNames(data.frame(res$annotation[[k]][ix], stringsAsFactors = FALSE), k), full)
    utils::write.csv(res$annotation, file.path(outdir, "tables", "feature_annotation.csv"), row.names = FALSE, na = "NA")
  }
  utils::write.csv(full, file.path(outdir, "tables", "limma_full.csv"), row.names = TRUE, na = "NA")
  zero <- is.null(a[["min-effect-fc"]]) || a[["min-effect-fc"]] == 1
  dsum <- os_limma_direction_summary(res$tt, a$alpha, model$coef, lfc = if (zero) 0 else log2(a[["min-effect-fc"]]))
  utils::write.csv(dsum, file.path(outdir, "tables", "direction_summary.csv"), row.names = FALSE)
  display <- NULL
  if (a[["display-lfc-filter"]] > 0) {
    display <- ft[!is.na(ft$padj) & ft$padj < a$alpha & abs(ft$log2fc) >= a[["display-lfc-filter"]], , drop = FALSE]
    write_feature_table(display, file.path(outdir, "tables", "display_filtered.csv"))
  }
  label <- sprintf("%s vs %s", a$target, a$reference)
  figs <- list()
  # Only report the hypothesis of the already fitted object. No P-value or
  # shrinkage calculation is performed in this reporting adapter.
  figure_context <- os_limma_figure_context(res, ft, model, a, module)
  volcano <- os_limma_volcano(ft, a$alpha, a[["label-n"]], label, module, a$journal, figure_context)
  utils::write.csv(attr(volcano, "os_meta")$data$decision_table,
    file.path(outdir, "tables", "de_selection.csv"), row.names = FALSE, na = "NA")
  if (min(attr(volcano, "os_meta")$counts$up, attr(volcano, "os_meta")$counts$down) < a[["label-n"]])
    attr(volcano, "os_meta")$caption <- sub("The ([0-9]+) most significant features per direction", "Up to \\1 most significant features per direction", attr(volcano, "os_meta")$caption)
  figs$volcano <- os_finalize_figure(volcano,
                                     file.path(outdir, "figures", "volcano"), journal = a$journal, root = outdir)
  figs$md <- os_finalize_figure(os_limma_md(ft, a$alpha, a[["label-n"]], label, module, a$journal, figure_context),
                                file.path(outdir, "figures", "md"), journal = a$journal, root = outdir)
  if (!is.null(res$probe_map)) utils::write.csv(res$probe_map, file.path(outdir, "tables", "probe_mapping.csv"), row.names = FALSE)
  if (isTRUE(res$sa)) figs$sa_diagnostic <- os_finalize_figure(os_limma_sa(res$fit, a$platform, a$journal), file.path(outdir, "figures", "sa_diagnostic"), journal = a$journal, root = outdir)
  if (!is.null(res$voom_trend)) {
    vt <- res$voom_trend
    utils::write.csv(data.frame(log2_count_size = vt$xy$x, sqrt_sd = vt$xy$y), file.path(outdir, "tables", "voom_trend_points.csv"), row.names = FALSE)
    figs$voom_trend <- os_finalize_figure(os_voom_trend(vt$xy, vt$line, span = vt$span %||% NA_real_, n_samples = ncol(mat),
                                                        title = vt$title %||% NULL, journal = a$journal),
                                          file.path(outdir, "figures", "voom_trend"), journal = a$journal, root = outdir)
  }
  if (!is.null(res$mds)) {
    md <- res$mds
    cd <- data.frame(sample = rownames(model$samples), stringsAsFactors = FALSE)
    cd[[a$condition]] <- as.character(model$samples[[a$condition]])
    shape_col <- NULL
    if (!is.null(model$block) && length(unique(model$block)) <= length(OS_FIG$shape_sample_sequence)) {
      shape_col <- md$block_label %||% "block"; cd[[shape_col]] <- as.character(model$block)
    }
    utils::write.csv(md$coords, file.path(outdir, "tables", "mds_coordinates.csv"), row.names = FALSE)
    figs$mds <- os_finalize_figure(os_sample_mds(md$coords, md$var_explained, cd, a$condition, shape_col = shape_col, reference = a$reference,
                                                 distance_label = if (identical(md$gene_selection, "common")) "log2 fold change" else "leading log2 fold change",
                                                 input_label = md$input_label, top = md$top, n_features = md$n_features, journal = a$journal),
                                   file.path(outdir, "figures", "mds"), journal = a$journal, root = outdir)
  }
  qc <- os_limma_qc(ft, model, a, prefix, nrow(mat), extra_qc)
  os_write_qc_results(qc, outdir)
  n_sig <- sum(!is.na(ft$padj) & ft$padj < a$alpha)
  zero <- is.null(a[["min-effect-fc"]]) || a[["min-effect-fc"]] == 1
  vals <- list(module = module, package_version = as.character(utils::packageVersion("limma")),
               n_samples = ncol(mat), n_input = nrow(mat), n_tested = nrow(ft),
               design = model$formula, target = a$target, reference = a$reference,
               n_target = model$n_target, n_reference = model$n_reference,
               alpha = a$alpha, n_sig = n_sig, n_up = sum(ft$log2fc > 0 & ft$padj < a$alpha, na.rm = TRUE),
               n_down = sum(ft$log2fc < 0 & ft$padj < a$alpha, na.rm = TRUE),
               test = if (zero) "zero-effect eBayes" else paste0("treat with minimum FC ", a[["min-effect-fc"]]),
               display = if (is.null(display)) "No display-only fold-change filter was applied." else
                 sprintf("For display only, |log2FC| >= %s was applied after BH adjustment; it did not change padj and carries no separate FDR guarantee.", a[["display-lfc-filter"]]),
               detail = res$detail %||% "")
  vals <- utils::modifyList(vals, res$template_values %||% list())
  templ <- os_read_templates(file.path(module_dir, "references", "reporting-templates.md"))
  caps <- vapply(names(figs), function(n) sprintf("- **%s** (figures/%s.pdf): %s", n, n, figs[[n]]$spec_obj$caption %||% ""), "")
  draft <- c(paste0("# ", module, " Methods and Results"), "", "## Methods", "", os_fill_template(templ$methods, vals), "",
             "## Results", "", os_fill_template(templ$results, vals), "", "## Figure legends", "", caps, "")
  os_write_text(draft, file.path(outdir, "draft", "methods_results.md"))
  # ---- hand-off objects ----
  obj <- file.path(outdir, "objects")
  saveRDS(res$fit, file.path(obj, "fit.rds"), version = 3)
  objects <- list(feature_table = list(path = file.path(outdir, "tables", "feature_table.csv"), type = "feature_table"),
                  fit = list(path = file.path(obj, "fit.rds"), type = "MArrayLM"))
  if (!is.null(res$elist)) {
    saveRDS(res$elist, file.path(obj, "elist.rds"), version = 3)
    objects$elist <- list(path = file.path(obj, "elist.rds"), type = "EList")
  }
  st_out <- model$samples
  st_out <- data.frame(sample = rownames(st_out), st_out[, setdiff(names(st_out), "sample"), drop = FALSE], check.names = FALSE, stringsAsFactors = FALSE)
  for (k in names(st_out)) if (is.factor(st_out[[k]])) st_out[[k]] <- as.character(st_out[[k]])
  utils::write.csv(st_out, file.path(obj, "sample_table.csv"), row.names = FALSE)
  objects$sample_table <- list(path = file.path(obj, "sample_table.csv"), type = "sample_table")
  expr_state <- NULL
  if (is.null(res[["expr"]]) && !is.null(res$elist)) { res[["expr"]] <- res$elist$E; res$expr_scale <- res$expr_scale %||% "voom log2 counts per million" }
  if (!is.null(res[["expr"]])) {
    em <- res[["expr"]]
    utils::write.csv(data.frame(feature_id = rownames(em), em, check.names = FALSE), file.path(obj, "expression_matrix.csv"), row.names = FALSE)
    objects$expression_matrix <- list(path = file.path(obj, "expression_matrix.csv"), type = "expression_matrix")
    expr_state <- list(scale = res$expr_scale %||% "log2 expression", n_features = nrow(em), n_samples = ncol(em),
                       weights_in_fit = res$weights_note %||% "none",
                       weights_carried = "no (expression_matrix is the weight-free matrix; the EList object carries the weights)")
  }
  sym <- ft$symbol[match(rownames(res$tt), ft$feature_id)]
  rl <- os_ranked_list_write(file.path(obj, "ranked_list.csv"), rownames(res$tt), sym, res$tt$t, meta = list(
    metric = if (zero) "limma moderated t-statistic" else sprintf("limma treat moderated t-statistic (lfc = log2(%s))", format(a[["min-effect-fc"]])),
    statistic = if (zero) "moderated_t" else "treat_moderated_t", statistic_kind = "test_statistic", lfc_type = NA_character_,
    directional = TRUE, contrast = sprintf("%s: %s vs %s", a$condition, a$target, a$reference),
    positive_end = sprintf("higher expression in %s than in %s", a$target, a$reference),
    negative_end = sprintf("lower expression in %s than in %s", a$target, a$reference),
    null_test = if (zero) "zero_effect" else sprintf("minimum_effect (treat lfc = log2(%s))", format(a[["min-effect-fc"]])),
    universe = sprintf("all %d features tested by %s for coefficient %s", nrow(res$tt), module, model$coef),
    producer = module, producer_version = version, id_type = "feature_id of the fitted matrix"))
  objects$ranked_list <- list(path = rl$path, type = "ranked_list")
  objects$ranked_list_meta <- list(path = rl$meta_path, type = "ranked_list_meta")
  state <- list(contrast = label, design = model$formula, alpha = a$alpha, coefficient = model$coef,
                condition = a$condition, reference = a$reference, target = a$target,
                weights = res$weights_note %||% "none", expression = expr_state, ranked_list = rl$meta,
                block = if (is.null(model$block)) NULL else list(column = a$block %||% NA_character_, n_blocks = model$n_blocks,
                                                                   role = a[["block-role"]] %||% "correlated_unit",
                                                                   consensus_correlation = res$details$consensus_correlation %||% NA_real_))
  write_handoff(outdir, run_id = basename(outdir), module = module, module_version = version, objects = objects,
                ecosystem = "neutral", state = state, upstream_runs = upstream$upstream_runs %||% character(0))
  jsonlite::write_json(c(list(module = module, contrast = label, design = model$formula, coefficient = model$coef,
                            n_input = nrow(mat), n_tested = nrow(ft), n_sig = n_sig),
                         if (model$n_target != model$n_target_observations || model$n_reference != model$n_reference_observations) list(
                            n_target = model$n_target, n_reference = model$n_reference,
                            n_target_observations = model$n_target_observations,
                            n_reference_observations = model$n_reference_observations),
                         list(
                            direction_summary = as.list(dsum[1, c("Down", "NotSig", "Up")]),
                            null_test = if (zero) "zero_effect" else "minimum_effect",
                            min_effect_lfc_threshold = if (zero) 0 else log2(a[["min-effect-fc"]]),
                            display_lfc_filter = a[["display-lfc-filter"]], alpha = a$alpha,
                            weights = res$weights_note %||% "none",
                            details = res$details %||% list())), file.path(outdir, "results", "limma_results.json"),
                       auto_unbox = TRUE, pretty = TRUE, null = "null", digits = I(10))
  fig_outs <- paste0("figures/", names(figs), ".figure_spec.json")
  outputs <- c("tables/feature_table.csv", "tables/limma_full.csv", "tables/direction_summary.csv", "qc/qc_results.csv",
               "draft/methods_results.md", "results/limma_results.json", fig_outs,
               "objects/ranked_list.csv", "objects/ranked_list.meta.json", "objects/sample_table.csv",
               if (!is.null(res[["expr"]])) "objects/expression_matrix.csv",
               if (!is.null(display)) "tables/display_filtered.csv",
               if (!is.null(res$probe_map)) "tables/probe_mapping.csv",
               if (!is.null(res$annotation)) "tables/feature_annotation.csv",
               if (!is.null(res$mds)) "tables/mds_coordinates.csv",
               if (!is.null(res$voom_trend)) "tables/voom_trend_points.csv")
  os_write_provenance(outdir, module, version, argv, entry, a$seed, inputs = inputs, outputs = outputs,
                      upstream = upstream, extra = list(design = model$formula, coefficient = model$coef))
  list(ft = ft, qc = qc, figures = figs)
}

# Consumer side of the limma hand-off (S4 cross-module contract b), for
# limma-camera, gsva-score and any later consumer of a limma-voom /
# limma-array / limma-dupcor run. Returns the real objects, never a rebuilt
# design:
#   E            expression matrix (EList$E when an EList exists, else the
#                expression_matrix object), features x samples
#   weights      EList$weights (voom precision weights, possibly x sample
#                quality weights) or NULL; NEVER silently dropped: callers
#                that cannot use weights must say so (weights_used = FALSE)
#   design       the fitted design matrix (MArrayLM $design)
#   coefficient  name of the tested coefficient (state$coefficient)
#   samples      the sample table written by the producer
#   scale, weights_note, block (list or NULL), contrast, reference, target
#   source       "EList" or "expression_matrix", and the object sha256
os_limma_handoff_read <- function(upstream) {
  if (!upstream$module %in% c("limma-voom", "limma-array", "limma-dupcor"))
    stop(sprintf("OS_HANDOFF_MISMATCH: %s is not a limma producer.", upstream$module), call. = FALSE)
  objs <- upstream$objects
  if (is.null(objs$fit) || !identical(objs$fit$type, "MArrayLM"))
    stop("OS_HANDOFF_MISMATCH: the limma upstream run has no MArrayLM fit object.", call. = FALSE)
  fit <- readRDS(objs$fit$path)
  st <- upstream$state
  if (is.null(st$coefficient) || !st$coefficient %in% colnames(fit$design))
    stop("OS_HANDOFF_MISMATCH: the limma upstream run does not record its tested coefficient (produced before the S4 contract).", call. = FALSE)
  if (!is.null(objs$elist)) {
    if (!identical(objs$elist$type, "EList")) stop("OS_HANDOFF_MISMATCH: object 'elist' has the wrong type.", call. = FALSE)
    el <- readRDS(objs$elist$path)
    E <- el$E; w <- el$weights; src <- "EList"; sha <- objs$elist$sha256
    if (!is.null(w)) dimnames(w) <- dimnames(E)
  } else if (!is.null(objs$expression_matrix)) {
    E <- os_read_matrix(objs$expression_matrix$path, "limma expression matrix"); w <- NULL; src <- "expression_matrix"
    sha <- objs$expression_matrix$sha256
  } else stop("OS_HANDOFF_MISMATCH: the limma upstream run hands on neither an EList nor an expression_matrix.", call. = FALSE)
  samples <- if (!is.null(objs$sample_table)) utils::read.csv(objs$sample_table$path, check.names = FALSE, stringsAsFactors = FALSE) else NULL
  if (!is.null(samples) && !identical(as.character(samples$sample), colnames(E)))
    stop("OS_HANDOFF_MISMATCH: the limma sample table does not match the expression columns.", call. = FALSE)
  if (!identical(rownames(fit$design), colnames(E)) && !is.null(rownames(fit$design)) &&
      !identical(as.character(seq_len(ncol(E))), rownames(fit$design)))
    stop("OS_HANDOFF_MISMATCH: the limma design rows do not match the expression columns.", call. = FALSE)
  list(E = E, weights = w, design = fit$design, coefficient = st$coefficient, samples = samples,
       scale = st$expression$scale %||% NA_character_, weights_note = st$weights %||% "none", block = st$block,
       contrast = st$contrast, reference = st$reference, target = st$target, condition = st$condition,
       source = src, sha256 = sha, producer = upstream$module, producer_version = upstream$module_version)
}
