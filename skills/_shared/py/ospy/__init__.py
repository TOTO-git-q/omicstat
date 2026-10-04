"""ospy -- the shared layer of omicstat's Python (scverse) lane.

One-to-one counterparts of skills/_shared/scripts/*.R (ENGINEERING_PLAN 10.4
lock 2): args (args.R), module_kit (module_kit.R), engine_run (engine_run.R),
handoff (handoff.R), feature_table (feature_table.R); plus seed (lock 4) and
figure_request (10.5: figures are rendered by the R layer). Every module is
standard library only except where it imports a scientific package lazily
(seed.set_seed), so an entry script answers --help on any Python >= 3.10.
An entry script puts skills/_shared/py on sys.path and imports from here.
ASCII only.
"""
OSPY_VERSION = "0.1.0"
