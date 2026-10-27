rpa_qc <- function(res) list(
 os_qc_rule("RPA-01","Candidate annotation",TRUE,"blocker","Production, scientific and visual review pending.","Do not publish candidate results."),
 os_qc_rule("RPA-02","Annotation loss",max(res$metadata$loss_query,res$metadata$loss_universe)>.05,"warning","More than five percent of selected or universe IDs lack this snapshot's annotation.","Inspect input_mapping.csv and assay eligibility."),
 os_qc_rule("RPA-03","No significant term",!any(res$tables$enrichment_table$significant),"warning","No pathway passes declared BH threshold; figure omitted.","Report the null result without relaxing the threshold."))
