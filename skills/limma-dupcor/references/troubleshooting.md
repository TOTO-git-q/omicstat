# Troubleshooting

- `OS_QC_BLOCKER: block has no repeated unit` -> every block appears only once -> use the independent-sample module or correct the unit mapping.
- `OS_INVALID_DESIGN: block is spanned` -> the fixed design fully explains the block -> remove the duplicate fixed block columns or revise the model.
- `OS_MISSING_PARAMETER: non-Agilent arrays` -> no preset has been approved -> choose trend and robust explicitly and inspect the mean-variance diagnostic.
- `OS_INVALID_INPUT: RNA mode requires` -> data are corrected or noninteger -> provide uncorrected raw counts.
