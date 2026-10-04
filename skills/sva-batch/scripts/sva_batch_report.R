# sva_batch_report.R -- report layer of module sva-batch. ASCII only on purpose.
#
# Tables, figures (ONLY through the _shared figure layer + the new
# os_batch_pca_pair() in fig_mod_bulk.R), the results JSON and the
# Methods/Results draft filled from references/reporting-templates.md.

.sb_num <- function(x, digits = 10) ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "g"))

.sb_write_csv <- function(df, path) {
  out <- df
  for (k in names(out)) if (is.numeric(out[[k]])) out[[k]] <- .sb_num(out[[k]])
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, na = "NA", fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}

.sb_matrix_csv <- function(m, path, id = "feature_id") {
  df <- data.frame(m, check.names = FALSE)
  df <- cbind(stats::setNames(data.frame(rownames(m), stringsAsFactors = FALSE), id), df)
  .sb_write_csv(df, path)
}

# A categorical column for figure colour/shape encoding only (never fed back
# into any statistic): a factor/character column stays as given; a
# continuous study variable is cut into labelled quantile bins purely so the
# shared PCA builder has something discrete to colour by.
sb_display_category <- function(x, label) {
  if (is.factor(x) || is.character(x)) return(factor(as.character(x), levels = sort(unique(as.character(x)), method = "radix")))
  br <- unique(stats::quantile(x, probs = seq(0, 1, length.out = min(4, length(unique(x)) + 1)), na.rm = TRUE, type = 7))
  if (length(br) < 2) return(factor(rep(sprintf("%s (all samples)", label), length(x))))
  cut(x, breaks = br, include.lowest = TRUE, dig.lab = 3)
}

# F3: argument values exactly as passed (NULL, TRUE, 20L -> "20", "irw" -> "\"irw\"").
.sb_arg <- function(x) {
  if (is.null(x)) return("NULL")
  if (is.character(x)) return(if (length(x) == 1L) sprintf("\"%s\"", x) else sprintf("c(%s)", paste(sprintf("\"%s\"", x), collapse = ", ")))
  if (is.logical(x)) return(if (isTRUE(x)) "TRUE" else "FALSE")
  format(x)
}
.sb_call_line <- function(fn, args) {
  sprintf("%s(%s)", fn, paste(sprintf("%s = %s", names(args), vapply(args, .sb_arg, "")), collapse = ", "))
}

# Lines of the "Models and parameters" section (batch report) -- the path
# actually run, with the values the calls received (r$calls).
sb_param_lines <- function(r) {
  m <- r$models
  out <- c(sprintf("- Protected design: %s", m$protected_design), sprintf("- Fitted model: %s", m$fitted_model))
  if (!is.na(m$null_model)) out <- c(out, sprintf("- %s", paste0(toupper(substr(m$null_model, 1, 1)), substring(m$null_model, 2))))
  cl <- r$calls
  if (!is.null(cl[["ComBat"]])) {
    out <- c(out, sprintf("- sva::%s", .sb_call_line("ComBat", cl[["ComBat"]])),
             "  - par.prior = TRUE: parametric empirical Bayes priors (normal for the additive, inverse gamma for the multiplicative batch effect); mean.only = FALSE: location AND scale adjusted; ref.batch = NULL: no reference batch, every batch adjusted toward the pooled mean; prior.plots = FALSE: the prior diagnostic is drawn by this module instead (figures/combat_prior).")
  }
  if (!is.null(cl[["ComBat_seq"]])) {
    a <- cl[["ComBat_seq"]]
    out <- c(out, sprintf("- sva::%s", .sb_call_line("ComBat_seq", a[c("full_mod", "shrink", "shrink.disp", "gene.subset.n")])),
             sprintf("  - covar_mod columns: %s; full_mod = TRUE: the protected group stays in the fitted model; shrink = FALSE, shrink.disp = FALSE: GLM estimates without empirical Bayes shrinkage (no prior is fitted, so there is no prior diagnostic).",
                     if (length(a$covar_mod_columns)) paste(a$covar_mod_columns, collapse = ", ") else "none (NULL)"))
  }
  if (!is.null(cl[["num.sv"]])) {
    out <- c(out, sprintf("- sva::%s -> n.sv = %d", .sb_call_line("num.sv", cl[["num.sv"]]), as.integer(r$n.sv)),
             sprintf("  - %s", if (identical(cl[["num.sv"]]$method, "be")) "method \"be\": B = 20 row permutations of the residuals, reproducible through seed; vfilter = NULL: all features used."
                               else "method \"leek\": asymptotic estimate; B and seed are passed but only the \"be\" branch uses them (sva 3.60.0 num.sv source); vfilter = NULL: all features used."))
  }
  for (fn in c("sva", "svaseq")) if (!is.null(cl[[fn]])) {
    out <- c(out, sprintf("- sva::%s", .sb_call_line(fn, cl[[fn]])),
             sprintf("  - method \"irw\" with B = %d iterations of the iteratively re-weighted algorithm; numSVmethod only applies when n.sv is not given (it is given here); controls = NULL (unsupervised)%s.",
                     as.integer(cl[[fn]]$B), if (identical(fn, "svaseq")) sprintf("; constant = %s: SVs are estimated on log(counts + %s)", format(cl[["svaseq"]]$constant), format(cl[["svaseq"]]$constant)) else ""))
  }
  if (!is.null(cl[["removeBatchEffect"]])) {
    ra <- cl[["removeBatchEffect"]]
    out <- c(out, sprintf("- Display matrix: limma::removeBatchEffect(x = input matrix, batch = NULL, batch2 = NULL, group = NULL, covariates = %s, design = %s) -- the SVs are regressed out while the full model is protected; display only.",
                          paste(ra$covariates, collapse = " + "), ra$design))
  } else if (!is.null(cl[["num.sv"]])) {
    out <- c(out, "- Display matrix: no surrogate variable was estimated, so removeBatchEffect was not called and the display matrix is the input.")
  }
  out
}

# F4: batches per prior figure (os_prior_density is 30 + 38 mm per batch);
# names are the figure stems combat_prior, combat_prior_2, ...
sb_prior_chunks <- function(batches, journal) {
  per_fig <- max(1L, as.integer(floor((os_journal(journal)$max_height - 30) / 38)))
  ch <- split(batches, ceiling(seq_along(batches) / per_fig))
  names(ch) <- c("combat_prior", if (length(ch) > 1) sprintf("combat_prior_%d", 2:length(ch)))
  ch
}
.sb_prior_fig_text <- function(r, journal) {
  ch <- sb_prior_chunks(r$prior_diag$hyper$batch, journal)
  if (length(ch) == 1) return("figures/combat_prior")
  paste(sprintf("figures/%s (batches %s)", names(ch), vapply(ch, paste, "", collapse = ", ")), collapse = "; ")
}

# F4: what the prior diagnostic shows, or why there is none on this path.
sb_prior_lines <- function(r, journal) {
  if (is.null(r$prior_diag)) {
    return(switch(r$method,
      combat_seq = "Not applicable: ComBat_seq was run with shrink = FALSE and shrink.disp = FALSE, so no empirical Bayes prior was fitted (GLM estimates are used directly); there is no prior to check.",
      "Not applicable: sva/svaseq estimate surrogate variables and fit no empirical Bayes batch-effect prior."))
  }
  h <- r$prior_diag$hyper
  c(sprintf("%s: kernel density of the per-feature batch-effect estimates (gamma hat, additive; delta hat, multiplicative) against the fitted parametric prior (normal; inverse gamma), every batch, %d features%s. Hyper-parameters (tables/combat_prior.csv):",
            .sb_prior_fig_text(r, journal), h$n_features[1], if (h$n_features_set_aside[1] > 0) sprintf(" (%d feature(s) with zero variance inside a batch are set aside by ComBat and not adjusted)", h$n_features_set_aside[1]) else ""),
    "",
    sprintf("- batch %s (n = %d): gamma.bar = %s, tau^2 = %s, inverse gamma a = %s, b = %s", h$batch, h$n_samples,
            .sb_num(h$gamma_bar, 6), .sb_num(h$tau2, 6), .sb_num(h$a_prior, 6), .sb_num(h$b_prior, 6)))
}

sva_batch_render <- function(r, a, outdir, colour_reg) {
  dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(outdir, "figures"), recursive = TRUE, showWarnings = FALSE)
  tabs <- list(corrected = file.path(outdir, "tables", "corrected_matrix.csv"),
              batch_report = file.path(outdir, "tables", "batch_report.md"))
  .sb_matrix_csv(r$corrected, tabs$corrected)

  is_known_batch <- a$method %in% SB_KNOWN_BATCH_METHODS
  # Display columns carry the user's own column names (they become legend
  # titles and caption text); "sample" is reserved for the id column.
  disp_name <- function(x) if (identical(x, "sample")) "sample group" else x
  sv_col <- disp_name(a[["study-var"]])
  coldata <- data.frame(sample = r$sample_ids, stringsAsFactors = FALSE)
  coldata[[sv_col]] <- sb_display_category(r$study_component, a[["study-var"]])
  if (is_known_batch) {
    b_col <- disp_name(a$batch)
    if (identical(b_col, sv_col)) b_col <- paste(b_col, "(batch)")
    coldata[[b_col]] <- factor(as.character(r$batch_factor), levels = levels(r$batch_factor))
  }
  colour_col <- if (is_known_batch) b_col else sv_col
  shape_col <- if (is_known_batch && nlevels(coldata[[sv_col]]) <= length(OS_FIG$shape_sample_sequence)) sv_col else NULL
  method_label <- switch(a$method,
    combat = sprintf("ComBat correction for %s (study variable %s protected)", a$batch, a[["study-var"]]),
    combat_seq = sprintf("ComBat-seq correction for %s (study variable %s protected)", a$batch, a[["study-var"]]),
    sprintf("removal of %d estimated surrogate variable(s) (%s; study variable %s protected)", r$n.sv, a$method, a[["study-var"]]))

  lv <- levels(coldata[[colour_col]])
  cr <- os_colours_for(lv, family = "group", registry = colour_reg)

  figs <- list()
  p <- os_batch_pca_pair(r$mat_before, r$corrected, coldata, colour_col = colour_col, shape_col = shape_col,
                        ntop = a[["pca-ntop"]], colour_registry = cr$registry, journal = a$journal, method_label = method_label)
  figs$batch_pca <- os_finalize_figure(p, file.path(outdir, "figures", "batch_pca"), journal = a$journal, width = "double")

  # PACK F ComBat prior diagnostic (F4): parametric ComBat path only.
  if (!is.null(r$prior_diag)) {
    pd <- r$prior_diag
    # os_prior_density() is 30 + 38 mm per batch tall; batches are split over
    # as many figures as the journal's maximum height needs (FIGURE_STYLE
    # "split the figure"): combat_prior, combat_prior_2, ... in batch order.
    lv <- r$prior_diag$hyper$batch
    chunks <- sb_prior_chunks(lv, a$journal)
    for (k in seq_along(chunks)) {
      b <- chunks[[k]]
      idx <- match(b, lv)
      part <- if (length(chunks) > 1) sprintf(", batches %s (%d-%d of %d)", paste(b, collapse = ", "), min(idx), max(idx), length(lv)) else ""
      pp <- os_prior_density(pd$emp[pd$emp$batch %in% b, , drop = FALSE], pd$prior[pd$prior$batch %in% b, , drop = FALSE],
                             n_features = ncol(pd$gamma.hat), method_label = paste0("ComBat (par.prior = TRUE, mean.only = FALSE)", part),
                             journal = a$journal)
      stem <- names(chunks)[k]
      figs[[stem]] <- os_finalize_figure(pp, file.path(outdir, "figures", stem), journal = a$journal, width = "double")
    }
    tabs$combat_prior <- file.path(outdir, "tables", "combat_prior.csv")
    .sb_write_csv(pd$hyper, tabs$combat_prior)
  }

  if (!is.null(r$sv)) {
    sv_path <- file.path(outdir, "tables", "sv_table.csv")
    sv_df <- data.frame(sample = r$sample_ids, stringsAsFactors = FALSE)
    if (ncol(r$sv)) sv_df <- cbind(sv_df, as.data.frame(r$sv, check.names = FALSE))
    .sb_write_csv(sv_df, sv_path)
    tabs$sv_table <- sv_path
  }

  batch_lines <- c("# sva-batch: batch report", "",
                   sprintf("Method: %s", r$method),
                   sprintf("Study variable: %s (%s)", a[["study-var"]], a[["study-var-type"]]),
                   if (is_known_batch) sprintf("Batch variable: %s", a$batch)
                   else "Batch variable: none (unknown source of variation; surrogate variables estimated instead)",
                   "")
  if (is_known_batch) {
    tb <- table(batch = as.character(r$batch_factor), study_var = as.character(coldata[[sv_col]]))
    batch_lines <- c(batch_lines,
                     "## Batch levels and sizes", "", utils::capture.output(print(table(as.character(r$batch_factor)))), "",
                     "## Batch x study variable cross-table", "", utils::capture.output(print(tb)), "",
                     sprintf("Joint design check (before correction): %s; empty batch x study-variable cells: %s; confounding status: %s.",
                             r$confound$estimability_check, r$confound$empty_cells, r$confound$status), "")
  } else {
    batch_lines <- c(batch_lines, sprintf("Surrogate variables estimated (num.sv, method = %s, seed recorded in provenance.json): %d",
                                          a[["num-sv-method"]], r$n.sv), "")
  }
  batch_lines <- c(batch_lines, "## Models and parameters (the calls as run)", "", sb_param_lines(r), "",
                   "## ComBat prior diagnostic", "", sb_prior_lines(r, a$journal), "",
                   "## What the corrected matrix is used for", "",
                   "Display (PCA) and downstream descriptive scoring only; never a differential-test input (PACK S1 P-1).", "")
  os_write_text(batch_lines, tabs$batch_report)

  list(tables = tabs, figures = figs, colour_registry = cr$registry)
}

sva_batch_results_json <- function(r, a, outdir, qc) {
  out <- list(module = SB_MODULE, module_version = SB_MODULE_VERSION, method = r$method,
             study_var = a[["study-var"]], study_var_type = a[["study-var-type"]],
             batch_var = a$batch %||% NA_character_, covariates = if (length(a$covariates)) a$covariates else list(),
             n_features = r$n_features, n_samples = r$n_samples,
             confounding_status = if (r$method %in% SB_KNOWN_BATCH_METHODS) r$confound$status else NA_character_,
             joint_design = list(estimability_check = r$confound$estimability_check, study_estimable = r$confound$study_estimable,
                                 rank = r$confound$rank, n_columns = r$confound$n_cols, empty_batch_study_cells = r$confound$empty_cells),
             num_sv_method = if (r$method %in% SB_UNKNOWN_BATCH_METHODS) a[["num-sv-method"]] else NA_character_,
             n_sv = if (is.na(r$n.sv)) NA_integer_ else as.integer(r$n.sv),
             models = r$models, calls = r$calls,
             combat_prior = if (is.null(r$prior_diag)) NULL else r$prior_diag$hyper,
             qc_triggered = qc$table$id[qc$table$triggered], draft_withheld = qc$blocking)
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, file.path(outdir, "results", "sva_batch_results.json"), auto_unbox = TRUE, pretty = TRUE,
                       digits = I(10), na = "null", null = "null")
}

sb_template_values <- function(r, a) {
  method_label <- switch(r$method, combat = "ComBat", combat_seq = "ComBat-seq", sva = "sva", svaseq = "svaseq")
  protected <- sprintf("the study variable %s (%s)%s", a[["study-var"]], a[["study-var-type"]],
                       if (length(a$covariates)) sprintf(" and the covariate(s) %s", paste(a$covariates, collapse = ", ")) else "")
  design_sentence <- if (r$method %in% SB_KNOWN_BATCH_METHODS) {
    sprintf("the known batch recorded in %s, protecting %s", a$batch, protected)
  } else {
    sprintf("an unknown source of variation (surrogate variables), protecting %s", protected)
  }
  m <- r$models; cl <- r$calls
  model_sentence <- if (r$method == "combat") {
    sprintf("The protected design was %s; ComBat fits, per feature, %s.", m$protected_design, sub(" [(].*$", "", m$fitted_model))
  } else if (r$method == "combat_seq") {
    sprintf("The protected design was %s; ComBat-seq fits, per feature, the negative binomial model %s.", m$protected_design, sub(" [(].*$", "", m$fitted_model))
  } else {
    sprintf("The full model was ~ %s and the null model ~ %s (%s).", sub("^full model ~ ", "", m$fitted_model), sub("^null model ~ ", "", m$null_model), m$protected_design)
  }
  parameter_sentence <- if (!is.null(cl[["ComBat"]])) {
    sprintf("ComBat was run with par.prior = %s (parametric empirical Bayes), mean.only = %s (location and scale adjusted) and ref.batch = %s (no reference batch).",
            .sb_arg(cl[["ComBat"]]$par.prior), .sb_arg(cl[["ComBat"]]$mean.only), .sb_arg(cl[["ComBat"]]$ref.batch))
  } else if (!is.null(cl[["ComBat_seq"]])) {
    sprintf("ComBat_seq was run with full_mod = %s, shrink = %s, shrink.disp = %s (GLM estimates without empirical Bayes shrinkage) and gene.subset.n = %s; covar_mod = %s.",
            .sb_arg(cl[["ComBat_seq"]]$full_mod), .sb_arg(cl[["ComBat_seq"]]$shrink), .sb_arg(cl[["ComBat_seq"]]$shrink.disp), .sb_arg(cl[["ComBat_seq"]]$gene.subset.n),
            if (length(cl[["ComBat_seq"]]$covar_mod_columns)) paste(cl[["ComBat_seq"]]$covar_mod_columns, collapse = ", ") else "NULL")
  } else {
    fn <- if (!is.null(cl[["sva"]])) "sva" else "svaseq"
    sprintf(paste0("The number of surrogate variables was estimated with num.sv(method = %s, B = %s, seed = %s, vfilter = %s)%s, and %s was run with method = %s, ",
                   "B = %s iterations, vfilter = %s, controls = %s%s."),
            .sb_arg(cl[["num.sv"]]$method), .sb_arg(cl[["num.sv"]]$B), .sb_arg(cl[["num.sv"]]$seed), .sb_arg(cl[["num.sv"]]$vfilter),
            if (identical(cl[["num.sv"]]$method, "leek")) " (B and seed are used only by the permutation method \"be\")" else "",
            fn, .sb_arg(cl[[fn]]$method), .sb_arg(cl[[fn]]$B), .sb_arg(cl[[fn]]$vfilter), .sb_arg(cl[[fn]]$controls),
            if (identical(fn, "svaseq")) sprintf(" and constant = %s (log(counts + %s))", format(cl[["svaseq"]]$constant), format(cl[["svaseq"]]$constant)) else "")
  }
  sv_sentence <- if (r$method %in% SB_UNKNOWN_BATCH_METHODS) {
    sprintf("num.sv estimated %d surrogate variable(s). %s", as.integer(r$n.sv),
           if (r$n.sv > 0) sprintf(paste0("They are reported (tables/sv_table.csv) for use as covariates in a downstream differential-expression design, not ",
                                          "regressed out before testing; for display only, limma removeBatchEffect (covariates = the %d surrogate variable(s), ",
                                          "design = the full model, batch = NULL, batch2 = NULL, group = NULL) removed them from the matrix."), as.integer(r$n.sv))
           else "No surrogate variables were estimated; the display matrix equals the input.")
  } else {
    sprintf("Before correction the joint design (batch + protected variables) was checked: %s; %s.",
           r$confound$estimability_check,
           if (!is.factor(r$study_component)) "the study variable is continuous, so no batch x study-variable cross-table applies"
           else if (identical(r$confound$status, "partial") && isTRUE(r$confound$study_estimable))
             sprintf("the batch and the study variable are partially confounded (%d empty batch x study-variable cell(s)), so contrasts between levels that never share a batch rest on the additive batch model", r$confound$empty_cells)
           else "no batch x study-variable cell is empty")
  }
  list(sva_version = as.character(utils::packageVersion("sva")), limma_version = as.character(utils::packageVersion("limma")),
      r_version = as.character(getRversion()), method_label = method_label, design_sentence = design_sentence,
      model_sentence = model_sentence, parameter_sentence = parameter_sentence,
      prior_sentence = if (is.null(r$prior_diag)) "" else
        sprintf(paste0(" The parametric priors were checked against the empirical per-feature batch-effect estimates of all %d batches ",
                       "(%s; hyper-parameters in tables/combat_prior.csv)."), nrow(r$prior_diag$hyper), .sb_prior_fig_text(r, a$journal)),
      sv_sentence = sv_sentence, n_features = format(r$n_features, big.mark = ","), n_samples = format(r$n_samples, big.mark = ","))
}

sva_batch_draft <- function(r, a, qc, templates_path, outdir) {
  path <- file.path(outdir, "draft", "methods_results.md")
  if (qc$blocking) {
    os_write_text(c("# sva-batch: draft withheld", "",
                    sprintf("Blocker QC rule(s) %s were triggered; no Methods/Results text is written for this run.", paste(qc$blocking_ids, collapse = ", ")),
                    "Read qc/qc_results.csv and fix the input before reporting anything from this run."), path)
    return(invisible(path))
  }
  tp <- os_read_templates(templates_path)
  v <- sb_template_values(r, a)
  os_write_text(c("# sva-batch: Methods and Results draft", "", "## Methods", "", os_fill_template(tp$methods, v), "",
                  "## Results", "", os_fill_template(tp$results, v), ""), path)
  invisible(path)
}
