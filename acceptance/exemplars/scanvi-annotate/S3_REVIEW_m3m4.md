# scanvi-annotate — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-py:2026.09.1`; image ID `sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/scanvi-annotate:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 omicstat-py:2026.09.1 python skills/scanvi-annotate/tests/run_smoke_test.py
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/scanvi-annotate:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e OMICSTAT_PY_IMAGE_ID=sha256:dedf331e03f3832cbd069bd3c75af3ac1a6f4f1daf88eea6f72204a3b114b96f omicstat-py:2026.09.1 python tools/make_module_lock.py scanvi-annotate --check
```
Exit 1; raw log: `/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/lock.log`.

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

Verified real scvi-integrate model -> SCVI.load -> SCANVI.from_scvi_model -> train -> native hard/soft predict. Native model and class probability/annotation tables are kept, counts and observed labels preserved.

Locked documentary evidence: `/home/<user>/omic-s0-c/acceptance/exemplars/scanvi-annotate/L1_pypi2026-09-15`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: static calls, defaults, flags, package-independent help and typed argument errors
PASS: anchor invariants and independent official-package replay
PASS: --spec determinism; exact identities/tables and fixed coordinate tolerances
PASS: ecosystem, corrected lineage and tampered-hash refusals
PASS: numerical flag effectiveness and scientific refusal path
PASS: exact-table and tolerance-tier golden comparisons
PASS: scanvi-annotate pinned numerical smoke; R rendering/visual review must run separately
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `21` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s0-c/acceptance/exemplars/scanvi-annotate/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 8 RDS/H5AD files; Methods drafts observed: 8. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

Separate final R-image rendering: [{"module": "scanvi-annotate", "run": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/scanvi-annotate_8yumc3zh/anchor", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/render_0.log"}, {"module": "scanvi-annotate", "run": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/scanvi-annotate_8yumc3zh/different_display", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/render_4.log"}, {"module": "scanvi-annotate", "run": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/scanvi-annotate_8yumc3zh/replay", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/render_5.log"}, {"module": "scanvi-annotate", "run": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/scanvi-annotate_8yumc3zh/upstream_cluster", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/render_6.log"}, {"module": "scanvi-annotate", "run": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/scanvi-annotate_8yumc3zh/upstream_scvi", "exit": 0, "log": "/home/<user>/omic-sol61/s3_m3m4/scanvi-annotate/render_7.log"}]. Exact docker commands are saved in corresponding render_*.command.json files. Python smoke alone does not certify figures.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 6 unique PNG contents for this module, 10 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_034.jpg`, `sheet_035.jpg`, `sheet_037.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

The small two-epoch synthetic smoke establishes model handoff, hash verification and probability shape only. Class probabilities are explicitly uncalibrated. Annotation plots use the unchanged upstream scVI UMAP, clearly distinct from claiming a learned scANVI latent embedding or prediction accuracy. Constructor architecture inherited from the verified upstream is not an independent annotation option.

## Closed repair list

1. `skills/scanvi-annotate/scripts/scanvi_annotate_core.py:47` — Expose result-affecting train_size/validation_size/shuffle_set_split/adversarial_classifier/plan_kwargs/datasplitter_kwargs and predict use_posterior_mean rather than hardcoding them. Bind the locked defaults, record actual values in Methods/registry/options. Re-verify an alternative split and prediction setting against native SCANVI on the verified small upstream model, then golden/lock and model-hash refusal tests. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.
2. `skills/scanvi-annotate/module_lock.json:15` — Refresh the lock only after the final authorized environment definition and required module repairs are validated. Independent --check currently fails OS_LOCK_MISMATCH; full read-only build comparison in the pinned image (with correct OMICSTAT_PY_IMAGE_ID) finds env/omicstat-env.json hash drift plus four new fig_mod_*.R files absent from the stored manifest. These reflect merge/rebuild changes, not edits by this review. Re-run locked smoke/golden and make_module_lock.py --check -> OK; do not change the numerical golden solely to hide lock drift. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
