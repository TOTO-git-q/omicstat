# immunedeconv-infiltration — independent S3 review

Reviewed source commit: `d7355bec9aa73496eba8e2c548a55415455e0508` (branch `s3/m3m4`). Review-only files are excluded from the implementation under review. No module source, golden or lock was changed.

Environment: `omicstat-r:2026.10.1`; image ID `sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7`. Non-root, network disabled; suite and acceptance-library mounts read-only; lane scratch writable. `OMICSTAT_WRITE_GOLDEN` was not set.

## Commands and runtime evidence

```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/immunedeconv-infiltration:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript skills/immunedeconv-infiltration/tests/run_smoke_test.R
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/immunedeconv-infiltration/smoke.log`.
```bash
docker run --rm --network none --user 1000:1000 -v /home/<user>/omic-s3m:/omicstat:ro -v /home/<user>/omic-sol61/s3_m3m4/immunedeconv-infiltration:/scratch -v /home/<user>/omic-integrate/.omicstat-acceptance:/omicstat/.omicstat-acceptance:ro -w /omicstat -e HOME=/tmp/omicstat-home -e OMICSTAT_TEST_TMP=/scratch -e OMICSTAT_CONTAINER=1 -e OMICSTAT_IMAGE_ID=sha256:d77c48fe94fe3f06ded5af701246b0d06eaf823096b84529e620a2fc7cdde0c7 -e OMICSTAT_REQUIRE_LOCKED=1 -e PYTHONDONTWRITEBYTECODE=1 -e OMP_NUM_THREADS=1 -e OPENBLAS_NUM_THREADS=1 -e MKL_NUM_THREADS=1 -e NUMBA_NUM_THREADS=1 -e PATH=/opt/omicstat/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin omicstat-r:2026.10.1 Rscript tools/make_module_lock.R immunedeconv-infiltration --check
```
Exit 0; raw log: `/home/<user>/omic-sol61/s3_m3m4/immunedeconv-infiltration/lock.log`.

Golden must PASS rather than SKIP: verified in smoke assertions/log; smoke exit 0.
Lock evidence (exit 0):
```text
module_lock immunedeconv-infiltration 1.1.0: OK (9 files)
```.

## Official workflow and anchor

Official deconvolute wrapper on pinned Racle32467x4 input. Eight offline methods execute with exact native parity; quanTIseq11 rows and fraction sums1; remaining method-specific goldens appended. Native tables retained; scores/fractions/percent/purity are distinguished.

Locked documentary evidence: `/home/<user>/omic-s0-b/acceptance/exemplars/immunedeconv-infiltration/L1_github`. PACK C/D/F and S0_VERIFICATION_M3M4 §3/§4.3 were used with the owner’s slim-policy override. No literature counts were used to choose defaults. Statistics are delegated to the named native package functions; descriptive reshaping/ranking is distinguished from inference.

Smoke evidence:
```text
PASS: PACK C pinned fixture hash 
PASS: Racle four-sample structure 
PASS: end to end  | Deconvolution successful! | immunedeconv infiltration completed 
PASS: full native official workflow replay 
PASS: 11 cell types,4 samples,fraction sums 
PASS: provisional website B-cell two-decimal output (not locked numerical authority) 
PASS: from-run neutral expression replay equal 
PASS: neutral ecosystem 
PASS: spec deterministic replay 
PASS: typed refusal depmap 
PASS: typed refusal unknown 
PASS: licence acknowledgement required epic 
PASS: licence acknowledgement required cibersort 
PASS: licence acknowledgement required cibersort_abs 
PASS: CIBERSORT source and LM22 never bundled 
PASS: offline native method mcp_counter >>> Running mcp_counter | immunedeconv infiltration completed 
PASS: full official wrapper parity mcp_counter 
PASS: native output shape mcp_counter 
PASS: offline native method epic >>> Running epic | immunedeconv infiltration completed 
PASS: full official wrapper parity epic 
PASS: native output shape epic 
PASS: EPIC native cell fraction sums 
PASS: offline native method xcell ✔ Calculations finished | immunedeconv infiltration completed 
PASS: full official wrapper parity xcell 
PASS: native output shape xcell 
PASS: offline native method timer  | immunedeconv infiltration completed 
PASS: full official wrapper parity timer 
PASS: native output shape timer 
PASS: offline native method abis >>> Running abis | immunedeconv infiltration completed 
PASS: full official wrapper parity abis 
PASS: native output shape abis 
PASS: offline native method consensus_tme ✔ Calculations finished | immunedeconv infiltration completed 
PASS: full official wrapper parity consensus_tme 
PASS: native output shape consensus_tme 
PASS: offline native method estimate [1] "2 gene set: ImmuneSignature  overlap= 139" | immunedeconv infiltration completed 
PASS: full official wrapper parity estimate 
PASS: native output shape estimate 
PASS: counts scale refused 
PASS: check_calls.R 
PASS: lint_r.py 
PASS: check_flag_docs.py 
PASS: golden  
SMOKE PASSED: 42 checks
```

## Options

Compared engine/entry/registry/options.md and SKILL.md. `22` documented option rows; all non-`none` S0 extraction keys exist in `/home/<user>/omic-s3m/acceptance/exemplars/immunedeconv-infiltration/literature/extraction.jsonl`. Both reference services and ask-user guidance are present. Mandatory scientific inputs and native JSON overrides were inspected; input/object names, output keys, serial execution and recorded seeds are transport/execution contracts, not inferred scientific defaults.
The exact options defects, if any, are listed in the closed repair list below.

## Outputs, Methods and handoffs

Native objects observed: 10 RDS/H5AD files; Methods drafts observed: 10. Native result columns/objects are retained except any explicitly listed repair. Methods names, package versions and run options were inspected against the engine and generated outputs. `--from-run` and chain-state evidence are in the smoke logs; real producer-chain supplement is recorded separately where needed.

## Figures

Opened every generated PNG through SHA256-indexed contact sheets (byte-identical repeats share the opened image). 8 unique PNG contents for this module, 10 figure specs. Inventory: `/home/<user>/omic-sol61/s3_m3m4/visual/inventory.json`; sheets: `sheet_020.jpg`, `sheet_021.jpg`, `sheet_026.jpg`, `sheet_027.jpg`. Captions reside in `*.figure_spec.json`, not necessarily inside PNG pixels. Suite builders/theme/palette and finalizer are used. Visual findings: Plots are nonblank, labels readable and not clipped; plotted quantities follow the package workflow. Captions record n and thresholds or explicitly state no cutoff.

## Known issues / scope

EPIC requires academic-use licence acknowledgement; CIBERSORT/CIBERSORT_abs require acknowledgement and user-supplied source/LM22, success paths unverified without lawful files. No download, no signature redistribution. TPM declaration and cancer indications are explicit. ABIS native estimates can be negative; the saved table/percent-scale figure retains those values rather than clipping or claiming constrained fractions.

## Closed repair list

1. `skills/immunedeconv-infiltration/scripts/immunedeconv_infiltration_core.R:24` — Expose a method-specific native-arguments option and bind the currently inaccessible CIBERSORT abs_method (locked sig.score) without bypassing user-source, signature and licence gates. Record resolved values in Methods/options mapping. Re-verify forwarding with a local user-authorized CIBERSORT stub/interface fixture for both absolute methods, retain refusal tests, and rerun all eight offline native-method goldens. This is an interface defect; no claim of executing licensed CIBERSORT is made. Evidence: PACK C/D/F; owner slim options/output/figure requirements. Re-verify in the same locked image; no tolerance relaxation or silent golden replacement.

VERDICT: FAIL
