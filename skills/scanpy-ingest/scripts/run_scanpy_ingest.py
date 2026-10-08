#!/usr/bin/env python3
"""scanpy-ingest: registered single-cell display/curation workflow."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / 'skills/_shared/py'))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanpy_ingest_core as core
from scanpy_ingest_report import report
from scanpy_ingest_qc import qc
SPEC = A.os_arg_spec(usage='python run_scanpy_ingest.py --from-run <run> --outdir <dir> [options]',
    description='Project query cells onto a fixed reference UMAP', flags=S.common_flags() + [
        A.os_flag('reference-run', 'path', required=True, help='fixed reference run with UMAP and neighbors', must_exist=True),
        A.os_flag('query-run', 'path', help='query run; optionally select explicit cell-list', must_exist=True),
        A.os_flag('label-col', 'string', required=True, help='existing descriptive label for reference-neighbor agreement'),
        A.os_flag('neighbors-key', 'string', required=True, help='reference uns neighbor graph key'),
        A.os_flag('n-neighbors', 'int', required=True, help='reference neighbors used for ingest and label agreement', range=(1, 1000)),
        A.os_flag('queue-size', 'num', default=5, help='locked ingest nearest-neighbor query queue size', range=(1, 1000)),
        A.os_flag('epsilon', 'num', default=0.1, help='locked ingest nearest-neighbor query epsilon', range=(0, 1)),
    ], exclusive=[('input', 'from-run')])
def main(argv):
    return S.run_module(argv, SPEC, 'scanpy-ingest', str(MODULE_DIR), core.compute, report, qc, core.validate, module_version=core.MODULE_VERSION)
if __name__ == '__main__':
    run_entry(main)
