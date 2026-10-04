# QC rules — clusterprofiler-gsea

| ID | Severity | Criterion | Action | Source |
|---|---|---|---|---|
| CG-01 | warning | at least one tested set has NA nominal P | inspect warnings and full table | enrichit 0.2.1 `gsea.Rd` and warnings |
| CG-02 | info | no set reaches main BH threshold | report full table, no significance claim | PACK S1 P-3 |
| CG-03 | warning | package warning captured | read engine warnings | ENGINEERING_PLAN §3.2 |

Missing metric/direction, duplicate IDs, nonfinite scores and a nondirectional upstream test are typed refusals before computation.
