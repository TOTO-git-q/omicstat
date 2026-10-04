# method-basis -- omicstat-selftest-py

Not an analysis module: no statistical method is applied, so there is no L1/L2 evidence to cite.
What it exercises and where each piece is specified:

| Piece | Specification |
|---|---|
| Environment pins (Python, scanpy, anndata, scvi-tools, CPU-only torch) | `env/omicstat-env.json` block `python_lane`; lock `env/py/uv.lock` / `env/py_lock.txt` (ENGINEERING_PLAN 10.4 lock 1) |
| Entry skeleton, `--help`, typed `OS_*` errors, `--spec` replay | `skills/_shared/py/ospy/args.py`, `module_kit.py` (lock 2; same contract as `args.R`) |
| Randomness lock | `skills/_shared/py/ospy/seed.py` (lock 4: random, NumPy, torch, `scvi.settings.seed`, deterministic algorithms) |
| Feature table | `skills/_shared/py/ospy/feature_table.py` (byte-identical to `feature_table.R`) |
| `--from-run` handoff, ecosystem `scverse`, object type `AnnData` | `skills/_shared/py/ospy/handoff.py` (plan 1.3 / 10.3) |
| Figures | `skills/_shared/py/ospy/figure_request.py` -> `skills/_shared/scripts/render_figure_request.R` (plan 10.5) |

The fixtures are synthetic shapes drawn from `random.Random(seed)`; they carry no biology.
