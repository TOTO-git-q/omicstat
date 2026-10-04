# QC rules

| Rule | Severity | Criterion | Action | Source |
|---|---|---|---|---|
| FG-01 | warning | Tied ranking scores | Report tie count and metric | PACK P-1; fgseaMultilevel.Rd stats |
| FG-02 | info | Set removed by intersection and size limits | Report retained and excluded counts | PACK P-3 |
| FG-03 | warning | Missing adjusted P | Inspect full result and log2err | fgseaMultilevel.Rd Value |
| FG-04 | info | No set at BH threshold | Report tested sets and smallest adjusted P | PACK D-F5; fig_enrich.R empty note |

Malformed, unsorted, unnamed, duplicate, or nonfinite rankings stop before fitting with typed OS_* errors. Missing or mismatched reference data stop before fitting. No draft is emitted for these refusals.
