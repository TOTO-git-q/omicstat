limma_camera_qc <- function(r, a, input) {
  rows <- list(
    os_qc_rule('LC-01', 'empty_sets', r$n_excluded > 0, 'info',
               'Gene sets had no overlap with the input identifiers.',
               'Inspect identifier namespace and retained set sizes.', as.character(r$n_excluded)),
    os_qc_rule('LC-02', 'rank_ties', is.finite(r$n_tied) && r$n_tied > 0, 'warning',
               'Ranked scores include ties.', 'Report the tied-score count and inspect rank construction.', as.character(r$n_tied)),
    os_qc_rule('LC-03', 'no_significant_sets', !any(is.finite(r$table$padj) & r$table$padj < a$alpha), 'info',
               'No gene set reached the BH reporting threshold.', 'Report the full table.', as.character(a$alpha)),
    os_qc_rule('LC-04', 'development_rotations', r$method %in% c('roast', 'mroast') && a$nrot == 1999L, 'warning',
               '1999 rotations is a development-only signature.', 'Rerun at 9999 or more for publication.', as.character(a$nrot)),
    os_qc_rule('LC-05', 'preset_correlation', r$method %in% c('camera', 'cameraPR'), 'info',
               'Inter-gene correlation 0.01 is a preset.', 'Report it as prespecified rather than estimated.', '0.01'),
    os_qc_rule('LC-06', 'block_not_modelled', !is.null(input$block_info) && !r$block_used, 'warning',
               'The upstream limma analysis modelled a block (repeated units) that camera cannot model.',
               'The user acknowledged this (--acknowledge-block-ignored); for a test that models the block use a self-contained question (fry/roast/mroast).',
               if (is.null(input$block_info)) '' else input$block_info$column))
  os_qc_finalize(rows, read_first = 'tables/gene_set_table.csv')
}
