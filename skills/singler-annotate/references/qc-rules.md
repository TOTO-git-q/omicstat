# QC rules

| ID | Severity | Blocking | Criterion | Action | Source |
|---|---|---|---|---|---|
| SA-01 | warning | no | any cell pruned | Review score diagnostics and reference coverage | PACK C; Annotation diagnostics |
| SA-02 | blocker | yes | all cells pruned | Withhold draft; inspect reference suitability | PACK D-SR7; Annotation diagnostics |
| SA-03 | warning | no | upstream ecosystem scverse | Preserve upstream label and flag Python to R crossing | build_m3b lane rule |
| SA-04 | warning | no | captured engine warning | Read qc/engine_warnings.csv | ENGINEERING_PLAN lock 2 |

Input validation rejects missing layers, missing labels, absent common features, corrected lineage and mismatched handoffs before inference. No invented QC cutoff.
