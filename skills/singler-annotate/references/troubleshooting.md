# Troubleshooting

- OS_MISSING_DEPENDENCY: scrapper -> locked image cannot execute the single-cell reference or cluster-unit recipe -> owner must repair the locked environment; this lane may not install packages.
- OS_MISSING_PARAMETER -> input/chain ecosystem or layer roles are undeclared -> provide explicit flags or a verified upstream handoff.
- OS_HANDOFF_MISMATCH -> upstream object changed or ambiguous name -> rebuild upstream or select --object-name.
- OS_ECOSYSTEM_MIXED -> requested ecosystem differs from chain -> preserve upstream chain or start a separate study chain.
- OS_BATCH_CORRECTED_INPUT -> inference input has corrected lineage -> use original counts/normalized uncorrected expression.
- OS_INVALID_INPUT -> reference lacks labels/logcounts or common feature IDs -> provide compatible reference and feature identifiers.
- All cells unassigned -> reference coverage is unsuitable -> review scores and atlas relevance before reporting.
- SingleCellExperiment reference hint -> package recommends t/wilcox markers -> the hint is captured, not suppressed; select the documented method when the locked dependencies exist.
