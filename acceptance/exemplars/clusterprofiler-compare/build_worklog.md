# clusterprofiler-compare S2 build worklog

Worktree `/home/<user>/omic-build-m2`, branch `build/m2`, run name `build_m2/clusterprofiler-compare`.

## Checklist

- [x] Scaffold (`python3 tools/new_module.py clusterprofiler compare`, exit 0; commit `0ebe3eb`).
- [x] Engine, calls registry, QC, references and SKILL.md.
- [x] Container smoke: gcSample/DOSE replay anchor, mixed-background route, typed errors, determinism and static checks.
- [x] Container golden; separate non-write golden check PASS and module lock written in container.
- [x] Figure visually checked: `compare_dotplot.png` all eight group labels shown, four blank as expected, all term labels and legends readable, no overlap or clipping. Caption/spec state threshold, number of lists, four with significance, and no between-list test.
- [x] S3_REQUEST.md written; final commit `7dd27c2`.

## Verified log

- Locked container static call registry, formals, defaults, flag docs and lint checks PASS.
- PACK C gcSample replay was adapted to an explicit eligible fixture universe: eight gcSample lists restricted to DOSE geneList (12,495 IDs). Direct compareCluster replay matched 29,874 list-term rows, 247 BH 0.05 rows; 11,525 effective GO background IDs per list. Golden table/spec PASS and table/PNG replay byte-identical.
- Two-list mixed fixture uses a second selection population; separate ORA branch, CX-01 and no pooled figure passed. ALL without pool, missing KEGG and selected-list-as-background typed refusals passed. No Rplots.pdf. Non-write golden smoke PASS; lock check PASS. Commit `7dd27c2`.

NEXT STEP: independent S3 reviewer; M2 lane writes the Chinese report and appends DONE only after its commit.

## 待裁决 (S2)

- PACK C book example has no eligible background. The DOSE fixture replays the call with a scientifically explicit population; the original book result is not claimed.
- P/q calculation cutoffs 1/1 preserve the full testable table; owner to reconcile PACK D-C3's function defaults 0.05/0.2 with the cross-module full-table rule.
- GO annotation asset lacks final registry hash/licence evidence. Only registered installed GO is used.
- The list manifest records study unit and model, but sample independence cannot be audited from gene IDs alone; the module does not infer between-list significance.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
clusterprofiler-compare: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
