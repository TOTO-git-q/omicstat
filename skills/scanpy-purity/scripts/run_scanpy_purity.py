#!/usr/bin/env python3
"""scanpy-purity: registered single-cell display/curation workflow."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / 'skills/_shared/py'))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanpy_purity_core as core
from scanpy_purity_report import report
from scanpy_purity_qc import qc
SPEC = A.os_arg_spec(usage='python run_scanpy_purity.py --from-run <run> --outdir <dir> [options]',
    description='Explicit display neighbour purity and isolated-cell flags', flags=S.common_flags() + [
        A.os_flag('label-col', 'string', required=True, help='descriptive identity column'),
        A.os_flag('graph-key', 'string', help='neighbors uns key or obsp connectivity key'),
        A.os_flag('use-rep', 'string', help='obsm representation instead of an existing graph'),
        A.os_flag('n-neighbors', 'int', help='required for representation purity', range=(1, 1000)),
        A.os_flag('metric', 'string', default='minkowski', help='native nearest-neighbor distance metric'),
        A.os_flag('purity-threshold', 'num', required=True, help='prespecified graph/representation purity cut', range=(0, 1)),
        A.os_flag('embedding-neighbors', 'int', required=True, help='UMAP neighbor count for display curation', range=(1, 1000)),
        A.os_flag('embedding-purity-threshold', 'num', required=True, help='prespecified UMAP-space purity cut', range=(0, 1)),
        A.os_flag('island-eps', 'num', required=True, help='DBSCAN eps in UMAP coordinate units', range=(1e-12, 1000000000000.0)),
        A.os_flag('island-min-samples', 'int', required=True, help='DBSCAN minimum density count', range=(1, 2147483647)),
        A.os_flag('island-min-size', 'int', required=True, help='minimum retained island cell count', range=(1, 2147483647)),
        A.os_flag('exclude-label', 'string', help='explicit label to flag for exclusion, e.g. Unresolved'),
    ], exclusive=[('input', 'from-run'), ('graph-key', 'use-rep')])
def main(argv):
    return S.run_module(argv, SPEC, 'scanpy-purity', str(MODULE_DIR), core.compute, report, qc, core.validate, module_version=core.MODULE_VERSION)
if __name__ == '__main__':
    run_entry(main)
