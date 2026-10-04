# QC rules — clusterprofiler-ora

| ID | Severity | Criterion | Action | Source |
|---|---|---|---|---|
| CO-01 | warning | fewer candidate background IDs map than were supplied | check identifier type and annotation version | PACK S1 P-2; enrichGO.Rd `universe` |
| CO-02 | info | no tested term has BH adjusted P below alpha | report full table and smallest adjusted P | PACK S1 appendix cross-module full-table note |
| CO-03 | warning | a package warning was captured | read engine warnings | ENGINEERING_PLAN §3.2 engine contract |

Missing or invalid background, empty selection, invalid ontology/pool and absent offline reference data are typed errors before publication output.
