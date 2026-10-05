#!/usr/bin/env python3
"""Static checks plus official anchor numerical replay in the pinned image."""
import sys
from pathlib import Path
MODULE = Path(__file__).resolve().parent.parent
SUITE = MODULE.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py/tests"))
from sc_smoke_support import main
sys.path.insert(0, str(MODULE / "scripts"))
from marker_regressions import verify
if __name__ == "__main__":
    raise SystemExit(main(MODULE, regression=verify))
