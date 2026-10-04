# fgsea-prerank S2 build worklog

Worktree `/home/<user>/omic-build-m2b`; branch `build/m2-rank`; run name `build_m2b/fgsea-prerank`.

## Steps

- [x] Scaffold (2026-09-28; `python3 tools/new_module.py fgsea prerank`, prefix FG).
- [x] Engine and call registry.
- [x] QC, references, SKILL.md.
- [x] Container smoke, anchors, flags, typed errors, determinism and chaining.
- [x] Golden manifest and module lock from locked container.
- [x] Visual review of every PNG.
- [x] S3_REQUEST.md; final module commit pending.

## Verified log

- Locked image `omicstat-r:2026.09.1` runs fgsea 1.38.0; `fgseaMultilevel` formals inspected in container.
- Current branch `46cec19` has no `ranked_list` handoff in deseq2-wald despite the lane task's assertion. Module will read the frozen handoff type; coordinator must reconcile upstream implementation.
- Locked-container smoke `fgsea_final_smoke.log`: 22 PASS, 0 FAIL, SMOKE PASSED. Golden written by container and checked PASS in a separate run. `check_calls`, `check_default_drift`, defaults/flag-doc lint and R lint all PASS. `--spec` replay made byte-identical table and PNG; conforming `--from-run` works; tampered handoff, bad ranking, and unresolved Hallmark all refused with typed errors. `--min-size` changed retained set count.
- Replay anchor (fgsea 1.38.0 examplePathways/exampleRanks, seed 20260925): 12,000 ranked genes, 1,457 input sets, 586 retained, 124 BH-significant; Cell Cycle Mitotic NES 2.75941576990235. Input CSV SHA-256 `18a41efbab53aa9e60380b495615d8ac5f98494ef7fd465525b94ec17c55488a`; registered collection SHA-256 `c26782589a8d38e92701386418a64101b7a66875702d2d48549f8151d29ee10e`.
- Viewed anchor `nes_bar.png`: ten bars (five per sign), readable shortened display labels, axis complete, no overlaps. Viewed `gsea_curve.png`: curve, hit ticks, annotations and axes readable; no clipping. Both figure specs state n and threshold in captions; `os_finalize_figure` lint had no blocker (NES figure FIG-03 info on grayscale blue/red proximity).
- Final rerun after truthful `exampleRanks` metric label and species provenance: 22 PASS, 0 FAIL, SMOKE PASSED; `module_lock --check` OK (14 files).

## NEXT STEP

Check module lock after final files, commit fgsea-prerank, and start gsva-score.

## 待裁决 (S2)

- `msigdb_collections` container registry entry has `TO_FILL_AT_BUILD` version/hash; refuse its Hallmark preset with `OS_REFDATA_MISSING` until the owner resolves M1-3.
- Upstream deseq2-wald ranked-list handoff is absent in this branch; keep the reader contract and list the integration gap for the coordinator.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
fgsea-prerank: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
