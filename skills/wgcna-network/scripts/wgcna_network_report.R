# Outputs derive from one computed result.
wgcna_network_render <- function(res, a, module_dir, upstream) {
  outdir <- a$outdir
  dir.create(file.path(outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  effect <- add_effect_rows(term = res$assoc$trait, level = res$assoc$module, analysis_id = "module_trait", effect_type = "other",
    estimate = res$assoc$estimate, p_value = res$assoc$p_value, p_adjusted = res$assoc$p_adjusted, p_adj_method = a[["trait-p-adjust"]],
    n_unweighted = as.integer(res$assoc$n_unweighted), test_name = paste(res$native_controls$cor$method,"corPvalueStudent"), notes = "Exploratory module eigengene correlation")
  os_m4_write_tables(list(effect_table = effect, gene_modules = res$gene, module_sizes = res$sizes, module_traits = res$assoc,
    soft_threshold = res$diagnostics, eigengenes = data.frame(sample = rownames(res$MEs), res$MEs)), outdir)
  dir.create(file.path(outdir, "objects"), recursive = TRUE, showWarnings = FALSE)
  reg <- if (!is.null(upstream$objects$colour_registry)) os_colour_registry_read(upstream$objects$colour_registry$path) else os_colour_registry_new()
  colors <- os_colours_for(res$gene$module, family = "category", registry = reg)
  os_colour_registry_write(colors$registry, file.path(outdir, "objects", "colour_registry.json"))
  saveRDS(res$net, file.path(outdir, "objects", "network.rds"))
  saveRDS(res$MEs, file.path(outdir, "objects", "eigengenes.rds"))
  figures <- list()
  figures$soft_threshold <- os_finalize_figure(os_m4_soft(res, a), file.path(outdir, "figures", "soft_threshold"), width = "double", journal = a$journal, root = outdir)
  trait_plot <- os_m4_trait(res,a)
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
  os_m4_draft(module_dir, values, figures, outdir)
  os_write_text(c("# Supplementary Methods: resolved native controls",values$native_controls),file.path(outdir,"draft/native_parameters.md"))
  jsonlite::write_json(values, file.path(outdir, "results", "wgcna_results.json"), auto_unbox = TRUE, pretty = TRUE)
  write_handoff(outdir, os_run_id(outdir), "wgcna-network", WG_MODULE_VERSION,
    objects = list(colour_registry = list(path = file.path(outdir, "objects", "colour_registry.json"), type = "colour_registry"), network = list(path = file.path(outdir, "objects", "network.rds"), type = "WGCNA_network"),
      eigengenes = list(path = file.path(outdir, "objects", "eigengenes.rds"), type = "module_eigengenes")),
    state = list(input_scale = a[["input-scale"]], power = a$power), upstream_runs = upstream$upstream_runs %||% character(0))
}
