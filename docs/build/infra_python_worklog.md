# infra/python-lane worklog (Python/scverse lane foundation)

Branch `infra/python-lane` (from `origin/build/m1m2` 2ddf174). Spec: ENGINEERING_PLAN v1.2 part 10
(10.4 seven locks, 10.5 figures via R, 10.6 MCP, 10.8). Local worktree
`E:/claude workspace/skills-dev/omic-infra-python`; GT103 runtime mirror `~/omic-infra-python`,
logs `~/omic-build-logs/infra-python/`.

## Verified state

- 2026-09-29 worktree created; spec read (plan part 10, env/, mcp/server.py, test_client.py,
  templates/module, tools/check_*).
- PyPI (queried 2026-09-29, upload time <= 2026-09-15 23:59:59 UTC, pre-releases and yanked
  excluded): scanpy 1.12.4 (2026-08-27), anndata 0.13.3.post0 (2026-08-27), scvi-tools 1.5.1
  (2026-09-10), torch 2.14.0 (2026-09-02; CPU wheel `torch-2.14.0+cpu-cp312-cp312-manylinux_2_28_x86_64`
  on download.pytorch.org/whl/cpu). scanpy 1.13.0a2 (S0 lane choice) is a pre-release -> not used.
  anndata 0.13.4 is 2026-09-18 (after cutoff) -> not used. Python 3.12.13 (3.12.14 tag appeared
  2026-09-19, after cutoff). All three need Python >= 3.12.

## Steps

| # | Step | Status |
|---|---|---|
| 0 | worktree + worklog + first push + GT103 mirror | DONE (f6d04b1; mirror ~/omic-infra-python) |
| 1 | env/py: pyproject + uv lock (hashes) + Dockerfile + build/test scripts; omicstat-env.json | DONE (521671e; first image build sha256:dedf331e..., static self-test ALL PASSED; final rebuild in step 8) |
| 2 | skills/_shared/py (args, errors, module_kit, engine_run, handoff, feature_table, seed, figure_request) + tests | DONE (7889744; test_ospy.py ALL PASSED locally) |
| 3 | tools/check_calls.py (+ tests) | DONE (82dba1b; test_check_calls.py ALL PASSED) |
| 4 | skills/_shared/scripts/render_figure_request.R (+ tests) | DONE (test_render_figure_request.R ALL PASSED in omicstat-r on GT103, incl. cross-lane byte parity of help / feature table / QC table / handoff) |
| 5 | MCP: run_*.py registration, dispatch by extension, render step, native python key, provenance probe (+ tests) | DONE (a34e095, e2b51ea; host e2e 91/92, the 1 failure is pre-existing, see findings) |
| 6 | skills/omicstat-selftest-py (+ smoke test) | DONE (6b1bd2f; smoke PASSED in omicstat-py) |
| 7 | templates/module_py + tools/new_module.py --python | DONE (test_new_module_py.py ALL PASSED) |
| 8 | GT103: build omicstat-py, image self-test, full test runs, final push | DONE (env/py/BUILD_RECORD.md: image sha256:dedf331e...; env/test.sh ALL PASSED (4 skipped = baseline); env/py/test.sh ALL PASSED; e2e 91/92, 1 = F1 pre-existing) |

## Baseline

- 2026-09-29 GT103 `bash env/test.sh` on the unmodified base (f6d04b1 = build/m1m2 + worklog):
  ALL PASSED, 4 skipped (acceptance data layer absent in the mirror). Log:
  `~/omic-build-logs/infra-python/baseline_test.log`.

## 待裁决 (owner decisions; safest choice taken)

1. **env_version not bumped.** Plan 10.9 says changing either image = new env_version. Adding the
   `python_lane` block changes no R value, and bumping would force an omicstat-r rebuild + new R
   golden baselines. Taken: env_version / omicstat-r tag stay 2026.09.1; the Python image has its
   own `python_lane.py_env_version` (2026.09.1) and any later change to either block follows 10.9.
   Side effect to know: env/container/Dockerfile COPYs env/omicstat-env.json, so the NEXT omicstat-r
   rebuild will not reuse its layer cache (results unaffected).
2. **Lock tool = uv** (plan allows conda-lock or pixi; the task allows uv). `env/py/uv.lock`
   (universal lock, every file sha256, resolution capped with exclude-newer 2026-09-16T00:00Z) and
   its pip export `env/py_lock.txt` (plan 10.4 location), installed with `pip --require-hashes
   --no-deps`. Pinned locker: uv 0.11.24.
3. **docrep 0.3.2 has no wheel** (scvi-tools needs it). Taken: installed from its hash-locked sdist
   with `--no-build-isolation` against the already-installed, hash-locked setuptools 84.0.0 (no
   unhashed build dependency is downloaded). Everything else is wheel-only.
4. **Python base image** = python:3.12.13-slim-bookworm by digest (3.12.13 is the newest 3.12 on or
   before 2026-09-15; the R image stays Ubuntu 24.04). pandas resolved to 3.0.5 (allowed by
   scanpy 1.12.4's pandas>=2.3); functional self-test decides whether it needs a cap.
5. **Extra determinism env** beyond the plan's four thread variables: PYTHONHASHSEED=0,
   NUMEXPR/VECLIB threads 1, PYTHONDONTWRITEBYTECODE=1 (no __pycache__ in the mounted checkout),
   caches under /tmp (container runs as the caller's uid).
6. **Argument parser**: plan 10.6 item 3 mentions argparse; taken: a hand-written parser that mirrors
   args.R exactly (same typed OS_* errors, same --help bytes; parity tested from R), because
   argparse cannot produce the R error codes or layout.
7. **Who runs the render step.** Plan 10.5: "the entry script's last step calls a fixed R render
   step, run in omicstat-r". A Python entry runs inside omicstat-py and cannot start omicstat-r, so
   taken: the entry's last step WRITES figure_data/figure_request.json and records the render step
   in provenance.json (`render_step`); the dispatcher (MCP `omicstat_run`) runs
   render_figure_request.R in omicstat-r right after (native: the native Rscript), and the step
   writes its own record provenance/figure_render.json.
8. **Colour registry of a Python run**: the R render step writes `colour_registry_out`
   (objects/colour_registry.json) and registers it in objects/handoff.json (sha256), so the chain
   carries the cluster colours (CONVENTIONS sec 6). handoff.R itself is untouched: its
   OS_ECOSYSTEMS lacks "scverse" (R *reads* scverse chains fine; an R writer of scverse chains is
   only needed by the future convert.R -> add "scverse" there, owner's R lane).

9. **Python execution tier** is read from `OMICSTAT_PY_CONTAINER` / `OMICSTAT_PY_NATIVE`, not
   `OMICSTAT_CONTAINER` (omicstat-r sets that one too, so a Python run inside the R image would
   otherwise count as the Python container tier).
10. **Run id inside the container.** The router mounts the run directory as `/ws`, so
    `basename(outdir)` is "ws" in container runs. Taken for the Python lane: the MCP shell passes
    `OMICSTAT_RUN_ID` (the UUID leaf) to every engine run (and the render step); `ospy.module_kit.run_id()`
    uses it. R modules still use basename(outdir) -> see finding F1.
11. **figure_data/** is classified "machine" (publication.classify_artifact) and skipped by the
    payload scan (server._scan_effect_tables): a volcano's copy of the feature table must never
    become the run's primary payload.
12. **Manifest schema**: `software_versions.python_engine` added as an OPTIONAL property of
    publication_manifest.v1 (present only for run_*.py modules), instead of a v2 schema; R-module
    manifests are unchanged. For a Python module `container_image_id` = the omicstat-py image and
    `python_engine.render_image_id` = the omicstat-r image that drew the figures.
13. **Selftest golden manifest** left header-only (same as omicstat-selftest); the smoke test checks
    rerun byte-identity instead. Python goldens start with the M3c modules (S5).

## Findings for the owner

- **F1 (pre-existing, not caused by this lane)**: in the container engine every R module writes
  `run_id = basename(outdir)` = "ws" (the router mounts the run dir at /ws), so `upstream_runs` in
  handoff.json / the manifest is wrong. Reproduced on the unmodified base (f6d04b1) with
  mcp/test_client.py run on the GT103 host: `selftest/container: upstream_runs ends with this run`
  FAILS with ['ws'] (env/test.sh never sees it because docker is absent inside omicstat-r, so its
  container cases SKIP). Suggested fix (R lane): read `Sys.getenv("OMICSTAT_RUN_ID")` first -- the
  MCP shell now sets it for every run.

## Existing files touched (for the merge)

- `env/omicstat-env.json` -- new `python_lane` block only (no R value changed)
- `bin/omicstat-r-route.sh`, `bin/omicstat-r-route.ps1` -- Tool `python`: omicstat-py image or the native `python` key; R path unchanged
- `mcp/server.py` -- router regex `run_*.(R|py)`; `_tool_for`/`_build_cmd` by extension; `_native_python`; `_python_render_step` + manifest `render_step`; `OMICSTAT_RUN_ID`; `_python_env_probe` + `python_engine`; dirty-tree code identity covers .py + _shared/py for Python modules; figure_data/ skipped in the payload scan
- `mcp/publication.py` -- same code-identity closure; `python_engine` passthrough (+ gaps); figure_data/ -> machine
- `mcp/test_client.py` -- regex; Python-lane acceptance (registry, describe, refusal, container/native runs incl. render step and provenance)
- `skills/_shared/schemas/publication_manifest.v1.schema.json` -- optional `software_versions.python_engine`
- `skills/_shared/publication/module_rules_v1.json` -- record for omicstat-selftest-py
- `skills/omicstat/SKILL.md` -- section 1 row for omicstat-selftest-py (+ one note on run_*.py)
- `tools/check_defaults.py`, `tools/check_flag_docs.py` -- accept run_*.py (help via sys.executable)
- `tools/new_module.py` -- `--python`
- `tools/run_tests.sh` -- Python-lane tests (config, ospy, check_calls, scaffold, R render + parity, py smoke, check_defaults for .py modules)

## Next exact step

Lane complete. For the owner's session: merge `infra/python-lane` (touched-file list above), decide
待裁决 1-13 and F1, then start M3c (`python tools/new_module.py scanpy qc --python` ...). Re-run
`bash env/py/test_e2e.sh` on GT103 after the merge.
