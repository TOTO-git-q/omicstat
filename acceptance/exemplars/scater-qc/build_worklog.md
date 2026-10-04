# scater-qc S2 worklog
Worktree /home/<user>/omic-b-bioc; branch build/m3a-bioc; lane build_m3a_bioc.
- [x] Scaffold (resumed; no redo)
- [x] Official QC engine, native parameter options and container-read registry
- [x] Docs, Methods and reference-service option mapping
- [x] Locked-container smoke: printed dimensions, exact metric/filter replay, CLI and from-run, golden PASS
- [x] Three figures rendered through suite layer, lint passed, every anchor PNG opened
- [x] S3_REQUEST written
- [x] Module lock generated in locked container; --check OK (15 files)
NEXT STEP: independent S3
## 待裁决 (S2)
QC thresholds and mitochondrial annotation are explicit caller choices; reference service before choosing. Compatibility APIs deprecated, replacement scrapper not installed. No package installs attempted.
Slim spec intentionally omits exhaustive refusal/determinism matrices. Dynamic native call wrapper unsupported by legacy check_calls.R; no scanner pass claimed.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
scater-qc: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
