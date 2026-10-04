# batchelor-integrate S2 worklog
Worktree /home/<user>/omic-b-bioc; branch build/m3a-bioc; lane build_m3a_bioc.
- [x] Scaffold and read PACK/locked evidence
NEXT STEP: official workflow engine, native options and smoke.
## 待裁决 (S2)
Study choices are explicit; consult reference service; no literature majority defaults.
- [x] Official workflow engine/options/docs; native fastMNN and multiBatchNorm objects preserved; original logcounts retained.
- VERIFIED: anchor inputs Zeisel 20006x3005 and Tasic 24150x1809; real Tasic scater-qc -> scran-cluster runs exit 0. Fixture archive DataFrame needed reconstruction and joined cell names needed explicit preservation; corrected.
- VERIFIED: core integration reached figures and native outputs; attaching SingleCellExperiment masked order and broke empty colour registry serialization. Replaced attachment with explicit BiocGenerics::cbind; no changes to shared framework.
NEXT STEP: complete container smoke/golden, inspect PNGs, lock/check.
- [x] Container smoke exit 0: 300 cells/15 corrected dimensions, original logcounts identical, finite corrected coordinates; golden PASS. All four before/after batch/label UMAP PNGs opened, readable/nonblank/unclipped; labels faithfully reflect archived metadata. Figure lint no blockers.
- [x] Container lock generated and --check OK (8 files); 25/25 flags documented; package/default checks passed.
S2 finished; NEXT STEP: independent S3 (no acceptance/installation here).
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
batchelor-integrate: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
