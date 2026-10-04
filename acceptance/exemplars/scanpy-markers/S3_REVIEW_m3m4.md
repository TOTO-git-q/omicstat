# scanpy-markers — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-py:2026.09.1`; image ID `sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/scanpy-markers:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 omicstat-py:2026.09.1 python skills/scanpy-markers/tests/run_smoke_test.py
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/scanpy-markers:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f omicstat-py:2026.09.1 python tools/make_module_lock.py scanpy-markers --check
```
Exit 1; raw log: `/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 1):
```text
Traceback (most recent call last):
  File "/omicstat/tools/make_module_lock.py", line 90, in <module>
    main()
  File "/omicstat/tools/make_module_lock.py", line 82, in main
    raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
RuntimeError: OS_LOCK_MISMATCH: module sources, baseline or environment changed
```.

## Official workflow and anchor

Native rank_genes_groups on declared normalized expression, all clusters versus rest. Native uns result survives in AnnData, and marker dot data are descriptive. No sample-level inference is claimed.

Locked documentary evidence: `/home/<user>/omic-s0-c/acceptance/exemplars/scanpy-markers/L1_pypi2026-09-15`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: static calls, defaults, flags, package-independent help and typed argument errors
PASS: anchor invariants and independent official-package replay
PASS: --spec determinism; exact identities/tables and fixed coordinate tolerances
PASS: ecosystem, corrected lineage and tampered-hash refusals
PASS: numerical flag effectiveness and scientific refusal path
PASS: exact-table and tolerance-tier golden comparisons
PASS: scanpy-markers pinned numerical smoke; R rendering/visual review must run separately
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `19` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s0-c/acceptance/exemplars/scanpy-markers/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 8 RDS/H5AD files; Methods drafts observed: 8. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

Separate final R-image rendering: [{"module": "scanpy-markers", "run": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/scanpy-markers_rg0we3wf/anchor", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/render_0.log"}, {"module": "scanpy-markers", "run": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/scanpy-markers_rg0we3wf/replay", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/render_4.log"}, {"module": "scanpy-markers", "run": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/scanpy-markers_rg0we3wf/upstream_cluster", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/render_5.log"}, {"module": "scanpy-markers", "run": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/scanpy-markers_rg0we3wf/upstream_qc", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/render_6.log"}, {"module": "scanpy-markers", "run": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/scanpy-markers_rg0we3wf/wilcoxon", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanpy-markers/render_7.log"}]. Exact docker commands are saved in corresponding render_*.command.json files. Python smoke alone does not certify figures.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 5 unique PNG contents for this module, 6 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_032.jpg`, `sheet_033.jpg`, `sheet_034.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

The documented t-test locked default is legitimate; the Wilcoxon tutorial route remains selectable. The purpose gate blocks condition-level pseudoreplication. Display alpha/top-n only select figure rows; full results remain saved.

## Closed repair list

1. `skills/scanpy-markers/scripts/scanpy_markers_core.py:32` — Expose native reference/groups/mask_var/rankby_abs/corr_method/tie_correct and n_genes rather than fixing every comparison to all-versus-rest with BH and no tie correction. Defaults may remain the locked/tutorial values; require scientific comparison choices where documentation does not settle them. Re-verify tie-corrected Wilcoxon and a named reference against native rank_genes_groups. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.
2. `skills/scanpy-markers/scripts/scanpy_markers_core.py:44` — Save the native sc.get.rank_genes_groups_df output with scores/logfoldchanges/pvals/pvals_adj/names and native ordering in addition to the suite-mapped feature table. Current marker_details is another copy of the renamed table. Re-verify columns, values and order against the direct native dataframe and keep AnnData uns. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.
3. `skills/scanpy-markers/module_lock.json:15` — Refresh the lock only after the final authorized environment definition and required module repairs are validated. Independent --check currently fails OS_LOCK_MISMATCH; full read-only build comparison in the pinned image (with correct OMICSTAT_PY_IMAGE_ID) finds env/omicstat-env.json hash drift plus four new fig_mod_*.R files absent from the stored manifest. These reflect merge/rebuild changes, not edits by this review. Re-run locked smoke/golden and make_module_lock.py --check -> OK; do not change the numerical golden solely to hide lock drift. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
