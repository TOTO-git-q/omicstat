# cellchat-communication S2 worklog
Worktree: /home/<user>/omic-b-m3b; branch build/m3b; run build_m3b.

- [x] Scaffold
- [x] Engine and registry
- [x] QC, references, docs
- [x] Anchors and smoke
- [x] Goldens and lock (final checks recorded below)
- [x] PNG inspection and handover

Initial scaffold checkpoint superseded by verified entries below.

## 待裁决 (S2)
Python front end to R backend label: preserve upstream ecosystem, flag crossing; no new label.

2026-10-01: official pinned createCellChat→subsetDB/subsetData→overexpression→probabilities→filter→pathway/network/centrality wrapper finished; native results/tables and per-formal options retained.
2026-10-01 VERIFIED full human-skin LS input: 17328×5011, 12 groups. Official default do.fast=TRUE anchor FAIL because locked image has no presto. Package error explicitly recommends do.fast=FALSE standard Wilcoxon; rerun uses that explicit option, default remains locked TRUE. projectData not exported at pin; projected workflow refused. No packages installed.
NEXT STEP: explicit standard-Wilcoxon anchor smoke, figures and final handover.
2026-10-01 VERIFIED container standard-Wilcoxon explicit option: full 17328×5011/12-group anchor pipeline PASS; native 365 significant LR rows/16 pathways; direct/from-run tables identical; ecosystem retained; calls/default drift/lint PASS; golden saved. Official default do.fast=TRUE remains documented FAIL with separately reproduced presto-missing log. Four heatmap/circle PNGs opened; captions n/cutoffs explicit; circle arrowhead clearance adjusted, next final figure inspection/check and lock.
NEXT STEP: final lock/check and S3 handover.

2026-10-01 FINAL: container golden PASS; refreshed final module_lock --check OK (9 files); calls/default drift and R lint PASS; all PNGs opened.
NEXT STEP: awaiting independent S3; image/default limitations in S3_REQUEST remain explicit.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
2026-10-01 env_rebuild: new native routes replayed offline; original golden rows preserved, only new route rows appended; fixed static registries/default checks and refreshed lock; final new-image validation pending.
2026-10-01 env_rebuild: non-root offline h5ad native table/golden parity PASS in disposable fixed environment; final image exception and validation pending; awaiting independent S3
cellchat-communication: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged_plus_additions; lock checked; awaiting independent S3); next remaining full R suite
