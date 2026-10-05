seurat_markers_qc <- function(r,a,elog) {
 os_qc_finalize(list(
 os_qc_rule("SM-01","nonempty result",ncol(r$object)==0,"blocker","No cells remain.","Review required parameters.","PACK C/T"),
 os_qc_rule("SM-02","engine warnings",os_engine_counts(elog)[["warning"]]>0,"warning","Engine warnings were captured.","Read engine_warnings.csv.","ENGINEERING_PLAN 3.2; PACK X"),
 os_qc_rule("SM-03","descriptive analysis",TRUE,"info","Cells are not biological replicates; these outputs are descriptive.","Use muscat-pseudobulk for condition inference.","ENGINEERING_PLAN 4.5; PACK W")
 ,os_qc_rule("SM-04","cell-level P saturation",ncol(r$object)>=10000 || (nrow(r$tables$markers_full)>0 && sum(r$tables$markers_full$p_val_adj<0.05,na.rm=TRUE)/nrow(r$tables$markers_full)>=0.9),"warning","cell-level P values are near zero for most genes; read effect sizes.","Read avg_log2FC and pct.1/pct.2; use sample-aware modules for condition effects.","CONVENTIONS marker grouping; PACK W")
 ),read_first="draft/methods_results.md")
}
