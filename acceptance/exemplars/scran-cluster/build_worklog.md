# scran-cluster S2 worklog
Worktree /home/<user>/omic-b-bioc; branch build/m3a-bioc; lane build_m3a_bioc.
- [x] Scaffold and read PACK/locked evidence
NEXT STEP: official workflow engine, native options and smoke.
## 待裁决 (S2)
Study choices are explicit; consult reference service; no literature majority defaults.
- [x] Official engine with CLI scientific choices and supplementary native JSON options; container-read registry
- [x] Skill/Methods/options.md; reference-service guidance for judgement options
- [x] Container smoke exit 0; Grun 20148x1728 checked; real scater-qc->scran-cluster handoff: 396 cells, 1000 HVGs, 15 PCs, 9 clusters; golden PASS
- [x] Five anchor PNGs opened, no overlap/clipping; suite figure lint no blockers
- [x] S3 request with unreplayed printed size-factor limitation (scrapper absent)
NEXT STEP: module lock generation/check.
- [x] Container module_lock generation and --check OK (12 files). S2 finished; awaiting independent S3.
2026-10-01 env_rebuild: official full Grun replay PASS, seed 100, scRNAseq ERCC altExp split, median 0.753182785733022 rounds to printed 0.753183; original 400-cell subset goldens untouched; final refreshed-image lock pending.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
scran-cluster: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
