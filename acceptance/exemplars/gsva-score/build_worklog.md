# gsva-score S2 build worklog

Worktree `/home/<user>/omic-build-m2b`; branch `build/m2-rank`; run name `build_m2b/gsva-score`.

## Steps

- [x] Scaffold (`python3 tools/new_module.py gsva score`, prefix GV).
- [x] Engine, parameter-object API, call registry.
- [x] QC, references, SKILL.md.
- [x] Container smoke with independent replay, flags, typed errors, determinism, chaining.
- [x] Golden manifest and module lock from locked container.
- [x] Visual review of every distinct PNG (byte-identical duplicates checked by hash).
- [x] S3_REQUEST.md; module commit pending.

## Verified log

- S1 appendix P-1–P-3 and SUITE cross-module rules read; limma scores inference uses continuous `lmFit` + `eBayes` as a provisional safe choice, with no voom or probe filtering. Input scale and actual kernel branch must be recorded.
- Locked GSVA 2.6.6, limma 3.68.5, BiocParallel 1.46.0 formals inspected in the container. `calls_registry` and default drift pass; 21/21 flags documented, default checks and R lint pass.
- GBM/brainTxDbSets replay from sha256-locked GSVAdata 1.48.1: 11,861 features, 173 samples, four scored sets, Gaussian auto branch; Proneural n=53 versus Classical n=38, all four BH-significant, oligodendrocytic_up logFC -0.522609890627989. Independent direct GSVA and limma replays match. Input CSV SHA-256 expression `93027d9f196fb704fb8e7c146ec382bf2bf27a2f0f5deb51c8a2e9162ec3f19c`, samples `fade8abcb255460b9f45f2552aaad1b03432b11a23c277ee9793b0de251ab8d0`.
- Final locked-container smoke `gsva_final_smoke.log`: 27 PASS, 0 FAIL, SMOKE PASSED; golden PASS, `--spec` byte-identical score table and PNG, typed `--from-run` with sample table, max-size flag effectiveness, Gaussian auto equivalence, 200-sample none branch, explicit Poisson counts, corrected-input inference refusal, tampered handoff refusal. `module_lock --check` OK (14 files).
- Visually opened the four distinct PNGs (GBM anchor, max-size variant, 200-sample none, Poisson). Heatmap tiles, dendrograms, legends, row names and group bar are readable without overlap/clipping. Other smoke PNGs were byte-identical to the anchor. Captions give displayed/full n, set-size bounds and no-significance-threshold statement. Figure lint has no blocker; GBM annotation palette has informational FIG-03 grayscale proximity.

## NEXT STEP

Commit gsva-score and start limma-camera.

## 待裁决 (S2)

- Owner has not frozen `eBayes` trend/robust settings or the receiving limma module. This build will use continuous `lmFit` + default `eBayes` and flag the choice for S3/owner review.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
gsva-score: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
