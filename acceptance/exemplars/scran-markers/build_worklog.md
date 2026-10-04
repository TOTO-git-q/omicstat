# scran-markers S2 worklog
Worktree /home/<user>/omic-b-bioc; branch build/m3a-bioc; lane build_m3a_bioc.
- [x] Scaffold and read PACK/locked evidence
NEXT STEP: official workflow engine, native options and smoke.
## 待裁决 (S2)
Study choices are explicit; consult reference service; no literature majority defaults.
- [x] Native scoreMarkers and optional deprecated findMarkers engine, CLI/options/Methods.
- VERIFIED: container smoke exit 0, official scoreMarkers direct replay identical; full Grun 20148 features x 9 groups, 396 cells from real QC/cluster upstream; golden PASS.
- [x] marker_dotplot.png and marker_heatmap.png opened: readable labels, nonblank, unclipped; captions declare n/top-N/ranking/no cutoff; automatic figure lint no blockers. Native ERCC features retained visibly.
- [x] Container R parse, registry defaults/package versions and flag docs 17/17 pass.
NEXT STEP: lock generation/check after batchelor checkpoint.
- [x] Container module lock generated and --check OK (8 files).
S2 finished; NEXT STEP: independent S3 (no acceptance/installation here).
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
scran-markers: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
