#!/usr/bin/env python3
"""Build an offline official-package/tutorial anchor; no fabricated values."""
import sys
from pathlib import Path
SUITE = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(SUITE / "skills/_shared/py"))
sys.path.insert(0, str(SUITE / "skills/_shared/py/tests"))
from sc_anchor import make_synthetic
if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: make_anchor.py output.h5ad")
    make_synthetic(SUITE, Path(sys.argv[1]))
