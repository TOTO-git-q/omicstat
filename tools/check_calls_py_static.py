#!/usr/bin/env python3
"""Run Python C1-C5 from the R image; locked imports run in the Python suite."""
import pathlib
import sys

from check_calls import check_calls

if len(sys.argv) != 2:
    raise SystemExit("usage: python tools/check_calls_py_static.py skills/<module>")
mod = pathlib.Path(sys.argv[1]).resolve()
result = check_calls(sorted((mod / "scripts").glob("*.py")), mod / "scripts/calls_registry.json")
for problem in result["problems"]:
    print("FAIL:", problem)
print("%d call sites scanned; %d registry problems" % (result["n_sites"], len(result["problems"])))
print("SKIP: Python signature/default imports delegated to the locked Python image suite")
raise SystemExit(0 if result["ok"] else 1)
