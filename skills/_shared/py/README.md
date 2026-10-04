# `_shared/py` -- the Python (scverse) lane's shared layer (`ospy`)

ENGINEERING_PLAN part 10. One-to-one counterparts of `_shared/scripts/*.R`, so a Python module is
built exactly like an R module (scaffold: `python tools/new_module.py <pkg> <part> --python`).
Everything here is standard library only; scientific packages are imported lazily, so an entry
script answers `--help` on any Python >= 3.10.

| Python (`ospy.*`) | R counterpart | What |
|---|---|---|
| `args` | `args.R` | one spec -> parsing, typed `OS_*` errors, `--help` in the identical line format (parity tested from R) |
| `errors` | `options(error = ...)` | `OmicstatError` (`exc.code`), `run_entry(main)`: typed error -> message + exit 1 |
| `module_kit` | `module_kit.R` | `spec_argv` (`--spec` replay), `canonical_argv`, QC rule table (same CSV bytes), env signature, `write_provenance` (+ `render_step`), templates, golden manifest |
| `engine_run` | `engine_run.R` | `EngineLog.capture(stage, fn, ...)`: warnings / logging messages / errors -> `qc/engine_warnings.csv`, warnings echoed as `OS_ENGINE_WARNING: [stage] ...` |
| `handoff` | `handoff.R` | `objects/handoff.json` read/write; ecosystem `scverse`, object type `AnnData` (`.h5ad`); `OS_HANDOFF_*`, `OS_ECOSYSTEM_MIXED`, `OS_CONTRACT_MISMATCH`, `OS_BATCH_CORRECTED_INPUT` |
| `feature_table` | `feature_table.R` | schema, validation, canonical order; writer byte-identical to the R writer |
| `seed` | lock 4 | `set_seed(seed)`: random, NumPy, torch (deterministic algorithms, 1 thread), `scvi.settings.seed`; returns the provenance record |
| `figure_request` | (plan 10.5) | figure data + `figure_data/figure_request.json`; drawn by `_shared/scripts/render_figure_request.R` in omicstat-r |

Tests: `tests/test_ospy.py` (unit), `skills/_shared/tests/test_render_figure_request.R` (R render
step + cross-lane byte parity), `tools/test_check_calls.py` (lock 3), `env/py/test.sh` (in the
omicstat-py image).
