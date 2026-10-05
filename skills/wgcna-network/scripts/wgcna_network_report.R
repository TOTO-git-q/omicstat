wgcna_soft <- function(res, a) {
  p <- os_soft_threshold(res$diagnostics, a$power, r2_threshold = res$native_controls$pickSoftThreshold$RsquaredCut %||% 0.85, journal = a$journal)
  meta <- attr(p, "os_meta")
  meta$caption <- paste(meta$caption, sprintf("n = %d biological samples, %d genes; %s network, Pearson correlation; input scale %s. Power was chosen explicitly: %s.", res$samples, res$genes, a[["network-type"]], a[["input-scale"]], a[["power-reason"]]))
  soft <- res$native_controls$pickSoftThreshold
  if (!is.null(soft) && (!identical(soft$corFnc, "WGCNA::cor") || !identical(soft$corOptions, list(use = "p"))))
    meta$caption <- sub("Pearson correlation", paste0(soft$corFnc, " correlation; native controls ", jsonlite::toJSON(soft$corOptions, auto_unbox = TRUE)), meta$caption, fixed = TRUE)
  attr(p, "os_meta") <- meta
  p
}
wgcna_cor_setting <- function(res) {
  cc <- res$native_controls$cor
  label <- paste0(toupper(substr(cc$method, 1, 1)), substring(cc$method, 2))
  extra <- c(if (isTRUE(cc$cosine) || isTRUE(cc$cosineX) || isTRUE(cc$cosineY)) "cosine (uncentred) option",
             if (!is.null(cc$weights.x) || !is.null(cc$weights.y)) "observation weights")
  if (length(extra)) paste(label, "with", paste(extra, collapse = " and ")) else label
}
wgcna_n_range <- function(res) {
  n <- range(res$inference_table$n_pairwise_complete)
  if (n[1] == n[2]) as.character(n[1]) else sprintf("%d-%d", n[1], n[2])
}
# Inference wording. The plain Pearson path without missing trait values keeps
# the sealed sentence (corPvalueStudent with n); sentences are added only for
# descriptive settings and for pairwise complete counts below n.
wgcna_trait_text <- function(res, a, cor_method) {
  adj <- a[["trait-p-adjust"]]; tests <- nrow(res$assoc)
  if (identical(res$inference, "descriptive_no_p")) {
    why <- "No P values were computed because a Student-t P value is not valid for this correlation setting; the correlations are descriptive."
    return(list(methods = sprintf("Module-trait correlations (%s) were computed as descriptive coefficients. No P values were computed because a Student-t P value is not valid for this correlation setting (corPvalueStudent applies to plain Pearson correlation only); the correlations are descriptive and no %s adjustment was applied.", wgcna_cor_setting(res), adj),
                results = paste0(" ", why), caption = why, noun = "correlations"))
  }
  if (all(res$inference_table$n_pairwise_complete == res$samples))
    return(list(methods = sprintf("%s module-trait correlations used corPvalueStudent with n=%d; %s adjustment covered all %d module-trait tests.", cor_method, res$samples, adj, tests),
                results = "", caption = "", noun = "tests"))
  list(methods = sprintf("%s module-trait correlations used corPvalueStudent with the pairwise complete sample count of each module-trait pair (n=%s of %d samples, because trait values were missing); %s adjustment covered all %d module-trait tests.", cor_method, wgcna_n_range(res), res$samples, adj, tests),
       results = sprintf(" Trait values were missing for some samples, so each Student-t P value used the pairwise complete sample count of its module-trait pair (n=%s of %d).", wgcna_n_range(res), res$samples),
       caption = sprintf("Trait values were missing for some samples; P values use pairwise complete sample counts (n = %s of %d).", wgcna_n_range(res), res$samples),
       noun = "tests")
}
wgcna_trait <- function(res, a) {
  p <- os_module_trait(res$r, res$p, journal = a$journal)
  meta <- attr(p, "os_meta")
  if (!is.null(res$native_controls$cor$method) && res$native_controls$cor$method != "pearson")
    meta$caption <- sub("Pearson correlation", paste(res$native_controls$cor$method, "correlation"), meta$caption, fixed = TRUE)
  meta$caption <- paste(meta$caption, sprintf("n = %d biological samples; BH adjustment across all %d module-trait tests is retained in the full table; no display significance filter.", res$samples, nrow(res$assoc)))
  if (identical(res$inference, "descriptive_no_p")) {
    meta$caption <- sub("the descriptive correlation coefficient only", sprintf("the descriptive correlation coefficient (%s) only", wgcna_cor_setting(res)), meta$caption, fixed = TRUE)
    meta$caption <- sub("BH adjustment across all .*full table; ", "", meta$caption)
  }
  note <- wgcna_trait_text(res, a, "Pearson")$caption
  if (nzchar(note)) meta$caption <- paste(meta$caption, note)
  attr(p, "os_meta") <- meta
  p
}
# Outputs derive from one computed result.
wgcna_network_render <- function(res, a, module_dir, upstream) {
  outdir <- a$outdir
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  effect <- add_effect_rows(term = res$assoc$trait, level = res$assoc$module, analysis_id = "module_trait", effect_type = "other",
    estimate = res$assoc$estimate, p_value = res$assoc$p_value, p_adjusted = res$assoc$p_adjusted, p_adj_method = if (identical(res$inference, "pearson_student_t")) a[["trait-p-adjust"]] else NA_character_,
    n_unweighted = as.integer(res$assoc$n_unweighted), test_name = if (identical(res$inference, "pearson_student_t")) paste(res$native_controls$cor$method,"corPvalueStudent") else "none (descriptive correlation)", notes = "Exploratory module eigengene correlation")
  os_m4_write_tables(list(effect_table = effect, gene_modules = res$gene, module_sizes = res$sizes, module_traits = res$assoc, module_traits_inference = res$inference_table,
    soft_threshold = res$diagnostics, eigengenes = data.frame(sample = rownames(res$MEs), res$MEs)), outdir)
  dir.create(file.path(outdir, "objects"), recursive = TRUE, showWarnings = FALSE)
  reg <- if (!is.null(upstream$objects$colour_registry)) os_colour_registry_read(upstream$objects$colour_registry$path) else os_colour_registry_new()
  colors <- os_colours_for(res$gene$module, family = "category", registry = reg)
  os_colour_registry_write(colors$registry, file.path(outdir, "objects", "colour_registry.json"))
  saveRDS(res$net, file.path(outdir, "objects", "network.rds"))
  saveRDS(res$MEs, file.path(outdir, "objects", "eigengenes.rds"))
  figures <- list()
  figures$soft_threshold <- os_finalize_figure(wgcna_soft(res, a), file.path(outdir, "figures", "soft_threshold"), width = "double", journal = a$journal, root = outdir)
  trait_plot <- wgcna_trait(res,a)
  trait_meta <- attr(trait_plot,"os_meta")
  trait_meta$caption <- sub("BH adjustment",paste(a[["trait-p-adjust"]],"adjustment"),trait_meta$caption,fixed=TRUE)
  if(any(grepl("^cor-",attr(a,"given")))) trait_meta$caption <- paste(trait_meta$caption,"Resolved correlation controls:",jsonlite::toJSON(res$native_controls$cor,auto_unbox=TRUE,null="null"))
  attr(trait_plot,"os_meta") <- trait_meta
  figures$module_traits <- os_finalize_figure(trait_plot, file.path(outdir, "figures", "module_traits"), width = "double", journal = a$journal, root = outdir)
  figures$samples <- os_finalize_figure(os_m4_tree(res$sampleTree, sprintf("Sample clustering: n = %d biological samples, %d genes; Euclidean distance, average linkage. Prior exclusion audit: %s. No automatic outlier cutoff.", res$samples, res$genes, a[["outlier-rule"]]), a$journal), file.path(outdir, "figures", "samples"), width = "double", journal = a$journal, root = outdir)
  for (i in seq_along(res$net$dendrograms)) {
    nm <- paste0("genes_block", i)
    figures[[nm]] <- os_finalize_figure(os_m4_gene_tree(res$net$dendrograms[[i]], res$net$colors[res$net$blockGenes[[i]]], sprintf("Gene dendrogram, block %d: n = %d genes, %d biological samples; power %s, %s network, %s TOM; deepSplit %d, minModuleSize %d, mergeCutHeight %s. Full module assignments are in gene_modules.csv.", i, length(res$net$blockGenes[[i]]), res$samples, a$power, a[["network-type"]], a[["tom-type"]], a[["deep-split"]], res$minSize, a[["merge-height"]]), a$journal), file.path(outdir, "figures", nm), width = "double", journal = a$journal, root = outdir)
  }
  values <- list(version = as.character(utils::packageVersion("WGCNA")), n = res$samples, genes = res$genes, scale = a[["input-scale"]], preprocessing = a$preprocessing,
    outlier = a[["outlier-rule"]], power = a$power, reason = a[["power-reason"]], network = a[["network-type"]], tom = a[["tom-type"]], minsize = res$minSize,
    split = a[["deep-split"]], merge = a[["merge-height"]], modules = sum(res$sizes$module != "grey"), grey = sum(res$gene$module == "grey"), tests = nrow(res$assoc),cor_type=if(res$native_controls$blockwiseModules$corType=="pearson") "Pearson" else res$native_controls$blockwiseModules$corType,cor_method=if(res$native_controls$cor$method=="pearson") "Pearson" else res$native_controls$cor$method,adjustment=a[["trait-p-adjust"]],native_controls=jsonlite::toJSON(res$native_controls,auto_unbox=TRUE,null="null",digits=NA))
  trait_text <- wgcna_trait_text(res, a, values$cor_method)
  values$trait_inference <- trait_text$methods; values$results_inference <- trait_text$results; values$assoc_noun <- trait_text$noun
  values$inference <- res$inference; values$n_pairwise_complete <- wgcna_n_range(res)
  os_m4_draft(module_dir, values, figures, outdir)
  os_write_text(c("# Supplementary Methods: resolved native controls",values$native_controls),file.path(outdir,"draft/native_parameters.md"))
  jsonlite::write_json(values, file.path(outdir, "results", "wgcna_results.json"), auto_unbox = TRUE, pretty = TRUE)
  write_handoff(outdir, os_run_id(outdir), "wgcna-network", WG_MODULE_VERSION,
    objects = list(colour_registry = list(path = file.path(outdir, "objects", "colour_registry.json"), type = "colour_registry"), network = list(path = file.path(outdir, "objects", "network.rds"), type = "WGCNA_network"),
      eigengenes = list(path = file.path(outdir, "objects", "eigengenes.rds"), type = "module_eigengenes")),
    state = list(input_scale = a[["input-scale"]], power = a$power), upstream_runs = upstream$upstream_runs %||% character(0))
}
