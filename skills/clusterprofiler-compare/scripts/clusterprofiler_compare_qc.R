cx_qc <- function(r,x,elog) {
  tab <- r$raw
  rows <- list(
    os_qc_rule("CX-01","selection populations",!x$same_population,"warning",
      "Lists have different eligible populations; enrichment was computed separately, without a shared-universe comparison plot.",
      "Interpret each list against its own background; do not compare P values as a test of between-list differences.",r$mode),
    os_qc_rule("CX-02","BH threshold",!any(!is.na(tab$p.adjust)&tab$p.adjust<0.05),"info",
      "No tested term reaches BH adjusted P < 0.05.","Report the full tested table.",sprintf("%d rows",nrow(tab))),
    os_qc_rule("CX-03","engine warnings",os_engine_counts(elog)[["warning"]]>0,"warning",
      "The package emitted a warning.","Read qc/engine_warnings.csv."))
  os_qc_finalize(rows,read_first="tables/enrichment_full.csv")
}
