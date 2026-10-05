singler_annotate_qc <- function(r, inp, a, elog) {
  rows <- list(
    os_qc_rule("SA-01", "pruned labels", r$n_assigned < r$n_cells, "warning", sprintf("%d of %d cells unassigned after pruning.", r$n_cells-r$n_assigned, r$n_cells), "Review score diagnostics and reference coverage.", "PACK C; SingleR vignette Annotation diagnostics"),
    os_qc_rule("SA-02", "all labels pruned", r$n_assigned == 0, "blocker", "All cells unassigned.", "Review reference suitability before reporting labels.", "PACK D-SR7; Annotation diagnostics"),
    os_qc_rule("SA-03", "Python to R crossing", inp$crossing, "info", "OS_ECOSYSTEM_CROSSING: Python front end feeds neutral R backend; upstream ecosystem is preserved.", "Preserve upstream ecosystem in provenance.", "Lane build_m3b ecosystem owner rule"),
    os_qc_rule("SA-04", "engine warnings", os_engine_counts(elog)[["warning"]] > 0, "warning", "Engine emitted warnings.", "Read qc/engine_warnings.csv.", "ENGINEERING_PLAN lock 2"))
  os_qc_finalize(rows, "tables/annotations.csv")
}
