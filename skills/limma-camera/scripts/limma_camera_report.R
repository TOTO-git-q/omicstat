lc_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- file(path, 'wb'); on.exit(close(con))
  utils::write.csv(x, con, row.names = FALSE, na = 'NA', fileEncoding = 'UTF-8', eol = '\n', quote = TRUE)
  invisible(path)
}

lc_fig_name <- function(i) sprintf('barcode_%d', i)

# A P value that underflows double precision is returned as 0 by limma; never
# print it as "P = 0".
lc_fmt_p <- function(p) if (is.finite(p) && p == 0) sprintf('< %s (below double precision, returned as 0)', format(.Machine$double.xmin, digits = 3)) else sprintf('= %s', format(signif(p, 3)))

limma_camera_render <- function(r, a, input, outdir) {
  table <- lc_write_csv(r$table, file.path(outdir, 'tables', 'gene_set_table.csv'))
  lc_write_csv(r$raw_table, file.path(outdir, 'tables', 'method_raw.csv'))
  lc_write_csv(r$set_audit, file.path(outdir, 'tables', 'gene_set_selection.csv'))
  outs <- 'tables/gene_set_selection.csv'
  if (!is.null(r$design)) {
    lc_write_csv(data.frame(sample = rownames(r$design$matrix), r$design$matrix, check.names = FALSE),
                 file.path(outdir, 'tables', 'design.csv'))
    outs <- c(outs, 'tables/design.csv')
  }
  figs <- list()
  figs$gene_set_bar <- os_finalize_figure(os_camera_set_bar(r$table, alpha = a$alpha, method = r$method, journal = a$journal),
                                          file.path(outdir, 'figures', 'gene_set_bar'), width = 'double', journal = a$journal)
  d <- r$display
  pos <- if (!is.null(input$rank)) input$rank_meta$positive_end else sprintf('higher in %s than in %s', r$design$target, r$design$reference)
  for (i in seq_along(r$figure_sets)) {
    s <- names(r$figure_sets)[i]
    row <- r$table[r$table$term_id == s, ]
    lab <- sprintf('%s: %s, direction %s, BH adjusted P %s; positive %s = %s.', r$method, s, row$direction,
                   lc_fmt_p(row$padj), d$stat_label, pos)
    p <- os_barcode(d$stat, r$figure_sets[[s]], s, worm = r$worms[[s]], stat_label = d$stat_label, test_label = lab, journal = a$journal)
    figs[[lc_fig_name(i)]] <- os_finalize_figure(p, file.path(outdir, 'figures', lc_fig_name(i)), width = 'single', journal = a$journal)
  }
  if (!is.null(d$logfc)) {
    md <- data.frame(feature_id = names(d$logfc), ave_expr = unname(d$ave[names(d$logfc)]), log2fc = unname(d$logfc), stringsAsFactors = FALSE)
    p <- os_md_set_highlight(md, r$figure_sets, sprintf('%s vs %s', r$design$target, r$design$reference), journal = a$journal)
    figs$md_set_highlight <- os_finalize_figure(p, file.path(outdir, 'figures', 'md_set_highlight'), width = 'single', journal = a$journal)
  }
  for (n in names(figs)) outs <- c(outs, sprintf('figures/%s.%s', n, c('png', 'pdf', 'figure_spec.json')))
  list(table = table, outputs = outs, figures = figs)
}

# Per-route Methods sentences from the ACTUAL run (S3 F2).
limma_camera_sentences <- function(r, a, input) {
  des <- r$design
  s <- list()
  s$input <- input$source_sentence
  if (!is.null(des)) {
    s$design <- sprintf(paste0('The design was %s (%s; columns %s) and the tested coefficient was %s, i.e. %s versus %s ',
                               '(%d %s and %d %s samples); positive statistics mean higher expression in %s.'),
                        des$formula, des$source, paste(colnames(des$matrix), collapse = ', '), des$coefficient,
                        des$target, des$reference, des$n_target, des$target, des$n_reference, des$reference, des$target)
    s$replicate <- if (r$block_used) {
      sprintf('Repeated units: block %s (%d blocks) with within-block correlation %s (%s) entered the test.',
              input$block_info$column, input$block_info$n_blocks, format(signif(r$correlation_used, 6)), input$block_info$source)
    } else if (!is.null(input$block_info) && r$method == 'camera') {
      sprintf(paste0('The upstream analysis modelled repeated units (block %s, %d blocks, correlation %s); camera has no block ',
                     'argument, so the block was not modelled by this test (acknowledged with --acknowledge-block-ignored, as in the ',
                     'User\'s Guide 18.1.10 camera call); the voom weights still reflect the block.'),
              input$block_info$column, input$block_info$n_blocks, format(signif(input$block_info$correlation, 6)))
    } else 'Each sample was treated as an independent unit (no block).'
  }
  if (r$method == 'cameraPR') s$ranking <- os_ranked_list_sentence(input$rank_meta)
  s$method <- switch(r$method,
    camera = sprintf(paste0('camera used inter.gene.cor = 0.01 (a prespecified preset, not estimated from these sets), use.ranks = FALSE ',
                            '(parametric), allow.neg.cor = FALSE, trend.var = FALSE, directional = TRUE and weights %s.'),
                     if (is.null(input$weights)) 'NULL' else 'the observation-level precision weights described above'),
    cameraPR = paste0('cameraPR used inter.gene.cor = 0.01 (a prespecified preset, not estimated), use.ranks = FALSE (parametric on the ',
                      'scores) and directional = TRUE; the ranking scores were used as given.'),
    fry = sprintf('fry used standardize = "posterior.sd", sort = "directional", gene.weights = NULL and weights %s.',
                  if (is.null(input$weights)) 'NULL' else 'the observation-level precision weights described above'),
    roast = sprintf(paste0('roast tested the single prespecified set %s with set.statistic = "mean", nrot = %d, approx.zscore = TRUE, ',
                           'legacy = FALSE, var.prior/df.prior estimated by limma (NULL) and weights %s.'),
                    a[['set-id']], a$nrot, if (is.null(input$weights)) 'NULL' else 'the precision weights described above'),
    mroast = sprintf(paste0('mroast used set.statistic = "mean", nrot = %d, approx.zscore = TRUE, legacy = FALSE, adjust.method = "BH", ',
                            'midp = TRUE, sort = "directional" and weights %s.'),
                     a$nrot, if (is.null(input$weights)) 'NULL' else 'the precision weights described above'))
  # S5 R3: which of the matched sets were selected and actually tested.
  ns <- length(r$not_selected_sets)
  s$selection <- if (r$method == 'roast') {
    sprintf('roast was run on the one set selected with --set-id (%s), so %d set was tested%s.', paste(r$selected_sets, collapse = ', '),
            r$n_tested_sets, if (ns) sprintf('; the other %d overlapping set%s (%s) %s not selected and %s not tested', ns, if (ns == 1L) '' else 's',
                                               paste(r$not_selected_sets, collapse = ', '), if (ns == 1L) 'was' else 'were', if (ns == 1L) 'was' else 'were') else '')
  } else if (r$n_tested_sets == r$n_matched_sets) {
    sprintf('%s tested all %d overlapping set%s.', r$method, r$n_tested_sets, if (r$n_tested_sets == 1L) '' else 's')
  } else sprintf('%s tested %d of the %d overlapping sets.', r$method, r$n_tested_sets, r$n_matched_sets)
  s
}

limma_camera_report <- function(r, a, qc, collection, outdir, templates_path, input, figures) {
  n_sig <- sum(is.finite(r$table$padj) & r$table$padj < a$alpha)
  sn <- limma_camera_sentences(r, a, input)
  des <- r$design
  vals <- list(limma_version = as.character(utils::packageVersion('limma')),
    question = r$question, method = r$method, input_kind = r$input_kind,
    input_sentence = sn$input, design_sentence = sn$design %||% '', replicate_sentence = sn$replicate %||% '',
    ranking_sentence = sn$ranking %||% '', method_sentence = sn$method,
    input_scale = input$scale %||% NULL, weights = if (is.null(input$weights)) 'none' else input$weights_label,
    upstream_module = input$producer %||% NULL,
    collection = a$collection, collection_version = collection$entry$version,
    collection_species = collection$entry$species, collection_sha256 = collection$sha256,
    n_input_features = r$n_input_features, n_input_sets = r$n_input_sets,
    n_matched_sets = r$n_matched_sets, n_unmatched_sets = r$n_excluded,
    n_selected_sets = r$n_selected_sets, n_tested_sets = r$n_tested_sets, n_not_selected_sets = length(r$not_selected_sets),
    selected_sets = as.list(r$selected_sets), tested_sets = as.list(r$tested_sets), not_selected_sets = as.list(r$not_selected_sets),
    selection_sentence = sn$selection, tested_phrase = sprintf('%d tested gene set%s', r$n_tested_sets, if (r$n_tested_sets == 1L) '' else 's'),
    n_significant = n_sig, alpha = a$alpha, seed = a$seed,
    rng_kind = paste(r$rng, collapse = '/'), nrot = if (r$method %in% c('roast', 'mroast')) a$nrot else NULL,
    midp = if (r$method == 'mroast') TRUE else NULL,
    inter_gene_cor = if (r$method %in% c('camera', 'cameraPR')) 0.01 else NULL,
    reference = des$reference %||% NULL, target = des$target %||% NULL,
    contrast = des$coefficient %||% NULL, design = des$formula %||% NULL,
    design_columns = if (is.null(des)) NULL else colnames(des$matrix), design_source = des$source %||% NULL,
    n_reference = des$n_reference %||% NULL, n_target = des$n_target %||% NULL,
    block = if (is.null(input$block_info)) NULL else input$block_info$column,
    block_modelled = r$block_used, correlation = if (r$block_used) r$correlation_used else NULL,
    rank_metric = if (r$input_kind == 'ranked_list') input$rank_meta$metric else NULL,
    direction = if (r$input_kind == 'ranked_list') input$rank_meta$positive_end else NULL,
    ranking_contrast = if (r$input_kind == 'ranked_list') input$rank_meta$contrast else NULL,
    display_statistic = r$display$source, qc_triggered = qc$table$id[qc$table$triggered],
    direction_meaning = if (r$input_kind == 'ranked_list') sprintf('the set is shifted toward the positive end of the ranking (%s)', input$rank_meta$positive_end) else
      sprintf("the set's genes tend to be higher in %s than in %s", des$target, des$reference))
  tm <- os_read_templates(templates_path)
  caps <- vapply(names(figures), function(n) sprintf('- **%s** (figures/%s.pdf): %s', n, n, figures[[n]]$spec_obj$caption %||% ''), '')
  lines <- c('# limma-camera Methods and Results', '', '## Methods', '',
             gsub('  +', ' ', os_fill_template(tm$methods, vals)), '', '## Results', '',
             os_fill_template(tm$results, vals))
  if (r$method %in% c('camera', 'cameraPR')) lines <- c(lines, '',
    'The inter-gene correlation 0.01 was prespecified, not estimated from these sets. This fixes the variance inflation used for competitive testing; estimating a separate correlation per set could change error control and ranking.')
  zero <- r$table$term_id[is.finite(r$table$padj) & r$table$padj == 0]
  if (length(zero)) lines <- c(lines, '', sprintf(paste0(
    '%d set(s) (%s) had a P value below double precision (%s): limma returned P = 0, which the tables keep as 0; ',
    'report it as P < %s, and note that gene_set_bar draws it at -log10(%s).'),
    length(zero), paste(zero, collapse = ', '), format(.Machine$double.xmin, digits = 3),
    format(.Machine$double.xmin, digits = 3), format(.Machine$double.xmin, digits = 3)))
  if (r$method %in% c('roast', 'mroast')) lines <- c(lines, '',
    sprintf('Rotation test: nrot=%d, seed=%d, RNG=%s, midp=%s. The ordinary mixed/two-sided raw P resolution is 1/(nrot+1); a one-sided P can reach 1/(2*nrot+1). mroast BH FDR uses mid-p.',
            a$nrot, a$seed, paste(r$rng, collapse = '/'), if (r$method == 'mroast') 'TRUE' else 'not applicable'))
  if (r$method %in% c('roast', 'mroast') && a$nrot == 1999L) lines <- c(lines, '', 'Development-only rotation count; do not cite as publication result.')
  lines <- c(lines, '', '## Figure legends', '', caps)
  os_write_text(lines, file.path(outdir, 'draft', 'methods_results.md'))
  dir.create(file.path(outdir, 'results'), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(vals, file.path(outdir, 'results', 'limma_camera_results.json'),
                       auto_unbox = TRUE, pretty = TRUE, null = 'null', na = 'null', digits = I(16))
}
