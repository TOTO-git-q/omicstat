ed_qc <- function(res) list(
 os_qc_rule("EDP-01","Candidate cell calling",TRUE,"blocker","Scientific and production review pending.","Do not publish candidate results."),
 os_qc_rule("EDP-02","Monte Carlo resolution",res$metadata$n_limited_unresolved>0,"warning","Limited=TRUE occurs in barcodes not called nonempty.","Prespecify more iterations within resource limits; do not lower FDR after looking."),
 os_qc_rule("EDP-03","No nonempty call",res$metadata$n_nonempty==0,"warning","No barcode meets the declared nonempty criteria.","Check raw input and ambient assumptions; no forced retention."),
 os_qc_rule("EDP-04","Downstream quality control",TRUE,"info","Nonempty droplets may contain damaged cells or fragments; no barcode was removed.","Perform independent QC before inference."))
