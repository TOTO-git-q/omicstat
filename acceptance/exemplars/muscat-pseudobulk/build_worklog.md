# muscat-pseudobulk S2 worklog
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

2026-10-01: slim scaffold/official prepSCE→aggregateData→pbDS, per-formal options and reference-service documentation finished.
2026-10-01 VERIFIED locked container: printed counts NOC2L=12, ISG15=13/1362, logFC=5.47346 and P=3.0e-21 at printed precision PASS; output 8 clusters; direct/from-run table hashes agree; calls/default drift and lint PASS; container golden written. Proportions and all eight direct volcano PNGs inspected: nonblank/readable/unclipped; n/thresholds explicit in figure specs.
NEXT STEP: final lock refresh/check, then independent S3.
2026-10-01 VERIFIED final module_lock --check OK (8 files, container tier). S2 handover finished; awaiting independent S3.

2026-10-01 FINAL: container golden PASS; refreshed final module_lock --check OK (9 files); calls/default drift and R lint PASS; all PNGs opened.
NEXT STEP: awaiting independent S3; image/default limitations in S3_REQUEST remain explicit.
2026-10-01 env_rebuild: non-root offline h5ad native table/golden parity PASS in disposable fixed environment; final image exception and validation pending; awaiting independent S3
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
muscat-pseudobulk: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
