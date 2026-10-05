#!/usr/bin/env python3
"""Static checks plus official anchor numerical replay in the pinned image."""
import sys
from pathlib import Path
MODULE = Path(__file__).resolve().parent.parent
SUITE = MODULE.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py/tests"))
from sc_smoke_support import main
if __name__ == "__main__":
    status = main(MODULE)
    if status == 0:
        import importlib.util
        if importlib.util.find_spec("scanpy") is not None:
            import os
            from test_hvg_counts import check_hvg_counts
            check_hvg_counts(Path(os.environ.get("OMICSTAT_TEST_TMP", "/tmp")) / "hvg-counts")
    raise SystemExit(status)
