seurat_modulescore_qc <- function(r,a,elog) {
 os_qc_finalize(list(
 os_qc_rule("OSS-01","nonempty result",ncol(r$object)==0,"blocker","No cells remain.","Review required parameters.","PACK C/T"),
 os_qc_rule("OSS-02","engine warnings",os_engine_counts(elog)[["warning"]]>0,"warning","Engine warnings were captured.","Read engine_warnings.csv.","ENGINEERING_PLAN 3.2; PACK X"),
 os_qc_rule("OSS-03","descriptive analysis",TRUE,"info","Cells are not biological replicates; these outputs are descriptive.","Use muscat-pseudobulk for condition inference.","ENGINEERING_PLAN 4.5; PACK W")
 ),read_first="draft/methods_results.md")
}
