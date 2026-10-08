#!/usr/bin/env python3
"""scanpy-annotate: registered single-cell display/curation workflow."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / 'skills/_shared/py'))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanpy_annotate_core as core
from scanpy_annotate_report import report
from scanpy_annotate_qc import qc
SPEC = A.os_arg_spec(usage='python run_scanpy_annotate.py --from-run <run> --outdir <dir> [options]',
    description='Descriptive marker-panel cluster naming', flags=S.common_flags() + [
        A.os_flag('cluster-col', 'string', required=True, help='cluster column to name descriptively'),
        A.os_flag('marker-panel', 'path', required=True, help='JSON type to genes, lineage, order and optional colour', must_exist=True),
        A.os_flag('label-map', 'path', help='JSON cluster to panel name; unassigned clusters remain unresolved', must_exist=True),
        A.os_flag('unresolved-label', 'string', required=True, help='explicit label for unassigned clusters'),
        A.os_flag('expression-layer', 'string', required=True, help='log expression layer for descriptive panel means'),
        A.os_flag('top-n', 'int', default=15, help='number of evidence genes per cluster', range=(1, 1000)),
    ], exclusive=[('input', 'from-run')])
def main(argv):
    return S.run_module(argv, SPEC, 'scanpy-annotate', str(MODULE_DIR), core.compute, report, qc, core.validate, module_version=core.MODULE_VERSION)
if __name__ == '__main__':
    run_entry(main)
