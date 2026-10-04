# QC rules

| Rule | Check | Severity | Source |
|---|---|---|---|
| LV-01 | fewer than three replicates in a group | warning | ENGINEERING_PLAN 4.5 |
| LV-02 | fewer than 100 features retained | warning | PACK C; voom trend |
| LV-03 | all adjusted P values unavailable | error | ENGINEERING_PLAN 4.5 |
| LV-04 | a nonfinite log2 fold change | error | ENGINEERING_PLAN 4.5 |
| LV-05 | every tested feature significant | warning | ENGINEERING_PLAN 4.5 |

Invalid raw counts, nonestimable design, and fewer than two replicates are typed pre-fit blockers.
