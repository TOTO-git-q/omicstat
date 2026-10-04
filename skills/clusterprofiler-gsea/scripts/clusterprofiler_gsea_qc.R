cg_qc <- function(r,a,elog) {
  rows <- list(
    os_qc_rule("CG-01","ranked scores",anyNA(r$raw$pvalue),"warning",
               "Some tested sets have no estimable P value.","Inspect enrichment_full.csv and engine warnings.",
               sprintf("%d/%d P values missing",sum(is.na(r$raw$pvalue)),nrow(r$raw))),
    os_qc_rule("CG-02","BH threshold",!any(!is.na(r$raw$p.adjust)&r$raw$p.adjust<a$alpha),"info",
               "No tested set reaches the main BH threshold.","Report full table and smallest adjusted P.",
               sprintf("%d terms tested",nrow(r$raw))),
    os_qc_rule("CG-03","engine warnings",os_engine_counts(elog)[["warning"]]>0,"warning",
               "The package emitted a warning.","Read qc/engine_warnings.csv."))
  os_qc_finalize(rows,read_first="tables/enrichment_full.csv")
}
