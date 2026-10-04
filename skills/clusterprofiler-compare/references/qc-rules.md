# QC rules — clusterprofiler-compare

| ID | Severity | Criterion | Action | Source |
|---|---|---|---|---|
| CX-01 | warning | declared populations or eligible universes differ | test each list against its own background; no shared comparison plot | PACK S1 P-2 |
| CX-02 | info | no tested term has BH adjusted P < 0.05 | report the full tested table | PACK S1 P-1; cross-module full-table rule |
| CX-03 | warning | package warning captured | read engine warnings | ENGINEERING_PLAN §3.2 |

Missing list metadata, selected IDs outside a background, using selected genes as the whole background, absent offline collection and invalid ALL/pool combinations are typed refusals.
