# QC facts; computational input blockers precede fitting.
wgcna_network_qc <- function(res) {
  os_qc_finalize(list(
    os_qc_rule("WG-01", "missing or constant input", FALSE, "blocker", "goodSamplesGenes passed.", evidence = "L1 goodSamplesGenes; PACK D-WG2"),
    os_qc_rule("WG-02", "unassigned genes", any(res$gene$module == "grey"), "info", "Unassigned genes remain in full tables.", "Review grey assignments.", "PACK T"),
    os_qc_rule("WG-03", "exploratory inference", TRUE, "info", "Module-trait associations and hub ranks are exploratory, without causal interpretation.", "Validate independently.", "PACK W")), "tables/module_traits.csv")
}
