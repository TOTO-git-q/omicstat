# clusterprofiler-gsea S2 build worklog

Worktree `/home/<user>/omic-build-m2`, branch `build/m2`, run name `build_m2/clusterprofiler-gsea`.

## Checklist

- [x] Scaffold (`python3 tools/new_module.py clusterprofiler gsea`, exit 0; commit `59707b3`).
- [x] Engine, calls registry, QC, references, SKILL.md.
- [x] Container smoke: DOSE replay, typed errors, from-run, determinism and static checks.
- [x] Container goldens, non-write check and module lock.
- [x] Inspect both PNGs: dot labels and legend readable, no overlap/clipping; curve's three tracks, NES and adjusted P readable. Captions/specs state threshold and counts.
- [x] S3_REQUEST.md written; final commit `e69bdc6`.

## Verified log

- Locked clusterProfiler 4.20.0 `GSEA`/`gseGO` call `enrichit::gsea_gson` without forwarding `...`. Downstream enrichit 0.2.1 formals were read in the container. Its `seed = FALSE` draws with `sample.int`; `set.seed(20260925)` yielded byte-identical table and PNGs in two fresh runs.
- PACK C DOSE replay: 12,495 ranked genes, 5,299 tested GO BP sets, 715 BH 0.05 sets. First GO:0000819 NES 2.89486744, adjusted P 8.02878788e-09. Same-session direct gseGO replay matched.
- Static call registry, formals, defaults, flag docs and R lint passed. Typed refusals passed for missing direction, non-directional LRT/F metric, absent KEGG and tampered upstream. An untampered ranked_list handoff matched direct input.
- Main BH threshold fixed at 0.05 in code; `--exploratory-fdr` adds a separately named 0.25 flag. Updated flag-effectiveness smoke to test it and min-size 20; golden and non-write smoke both passed; lock generated in the container. Commit `e69bdc6`.

NEXT STEP: independent S3 reviewer; M2 lane continues with clusterprofiler-compare.

## 待裁决 (S2)

- P-2: locked clusterProfiler wrappers swallow `...` and cannot explicitly pass enrichit seed/eps/sampleSize/nPermSimple/scoreType/weight. Seeded R RNG gives byte-identical output; owner to decide whether wrapper defaults are acceptable or to revise API.
- deseq2-wald 1.1.0 on this branch lacks `ranked_list`; a finite-stat `feature_table` fallback is implemented. Owner's lane task says the handoff exists, so integration should be rechecked when branches merge.
- GO annotation asset lacks final registry hash/licence evidence; only installed registered GO is used.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
clusterprofiler-gsea: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
