# speckle-propeller S2 worklog
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

2026-10-01: slim official propeller explicit-vector wrapper, native result/proportion outputs, per-formal JSON options and required replicate-sample check finished.
2026-10-01 VERIFIED container: CellBench seed=10 exact printed logit H1975 P=.01841045/FDR=.05003357 and asin P=.01578743 PASS; 3-row native table; direct/from-run equality, chain ecosystem and calls/default drift/lint PASS; golden written. Both proportions PNGs opened: nonblank/readable/unclipped, n and no display cutoff stated in spec. Bootstraps explicitly documented as technical demonstration only.
NEXT STEP: module lock/check and independent S3.
2026-10-01 VERIFIED module_lock --check OK (8 files, container). S2 handover finished; awaiting independent S3.

2026-10-01 FINAL: container golden PASS; refreshed final module_lock --check OK (9 files); calls/default drift and R lint PASS; all PNGs opened.
NEXT STEP: awaiting independent S3; image/default limitations in S3_REQUEST remain explicit.
2026-10-01 env_rebuild: non-root offline h5ad full smoke/table parity PASS in disposable fixed environment; final image validation pending; awaiting independent S3
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
speckle-propeller: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
