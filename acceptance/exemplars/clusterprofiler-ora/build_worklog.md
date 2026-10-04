# clusterprofiler-ora S2 build worklog

Worktree `/home/<user>/omic-build-m2`, branch `build/m2`, run name `build_m2/clusterprofiler-ora`.

## Checklist

- [x] Scaffold with `python3 tools/new_module.py clusterprofiler ora` (exit 0, pre-existing scaffold commit).
- [x] Engine, calls registry, QC, references, SKILL.md.
- [x] Container smoke: DOSE replay anchor, flags, typed errors, determinism, from-run, static checks.
- [x] Container goldens; module lock written in container.
- [x] Inspect figures: `ora_dotplot.png` opened; 15 labels and legend readable, no overlap or clipping. Caption/spec state BH threshold, n significant and n shown.
- [x] S3_REQUEST.md written; final commit `437c741`.

## Verified log

- 2026-09-28: locked container has clusterProfiler 4.20.0, enrichit 0.2.1, org.Hs.eg.db 3.23.1.
- 2026-09-28: DOSE replay anchor (PACK C): 207 selected, 12,495 candidate background, 194 effective GO input, 11,525 effective GO background, 2,588 tested terms, 154 BH 0.05 terms; first GO:0140014 adjusted P 1.69548321341e-16. Container replay and byte-identical table/PNG checks passed.
- 2026-09-28: static registry/formal/default/flag/lint checks passed; missing universe, missing KEGG, ALL without pool and tampered upstream produced typed refusals. `--from-run` matched direct input. Golden manifest written in container and checked PASS in same run; separate non-write smoke also PASS. Lock generated in the container. Commit `437c741`.

NEXT STEP: independent S3 reviewer; M2 lane continues with clusterprofiler-gsea.

## 待裁决 (S2)

- PACK D-O5 and full-table rule: use calculation P/q cutoffs 1/1, retain all testable terms and flag BH 0.05 separately; owner to confirm reconciliation.
- Container GO annotation asset has no registry sha256 or final licence evidence. Only registered, installed GO is used; other collections refuse.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
clusterprofiler-ora: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
