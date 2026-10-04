# QC rules

| ID | Severity | Criterion | Action | Source |
|---|---|---|---|---|
| SM-01 | blocker | no retained cells | withhold draft; revise explicit limits | PACK T/C |
| SM-02 | warning | engine warnings | inspect qc/engine_warnings.csv | plan 3.2; PACK X |
| SM-03 | info | cell analysis | descriptive only; route condition inference to muscat-pseudobulk | plan 4.5; PACK W |

Input blockers use typed errors before rendering: OS_INVALID_COUNTS, OS_MITO_FEATURES, OS_CHAIN_STATE, OS_ECOSYSTEM_MIXED, OS_HANDOFF_MISMATCH and OS_BATCH_CORRECTED_INPUT. A rejected run does not produce a scientific draft.
