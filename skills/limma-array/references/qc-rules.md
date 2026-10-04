# QC rules

| Rule | Check | Severity | Source |
|---|---|---|---|
| LA-01 | fewer than three replicates in a group | warning | ENGINEERING_PLAN 4.5 |
| LA-02 | fewer than 100 retained probes | warning | PACK C; ENGINEERING_PLAN 4.5 |
| LA-03 | all adjusted P values unavailable | error | ENGINEERING_PLAN 4.5 |
| LA-04 | nonfinite log2 fold change | error | ENGINEERING_PLAN 4.5 |
| LA-05 | all tested probes significant | warning | ENGINEERING_PLAN 4.5 |

Known controls and above-background data are validated before fitting (PACK S1 P-2).
