#!/usr/bin/env python3
"""scanpy-qc: one spec, verified input, computation, figures, QC and provenance."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py"))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanpy_qc_core as core
from scanpy_qc_report import report
from scanpy_qc_qc import qc
SPEC = A.os_arg_spec(usage="python run_scanpy_qc.py --input <h5ad>|--from-run <dir> --outdir <dir> [options]",
    description='Raw-count single-cell quality control in AnnData', flags=S.common_flags() + [
        A.os_flag('mito-prefix', 'string', help='explicit mitochondrial gene-name prefix', required=True),
        A.os_flag('min-genes', 'int', help='inclusive lower detected-gene cutoff', required=True, range=(1, 1000000)),
        A.os_flag('max-genes', 'int', help='inclusive upper detected-gene cutoff', required=True, range=(1, 1000000)),
        A.os_flag('min-counts', 'num', help='inclusive lower library-count cutoff', required=True, range=(1, 1000000000000.0)),
        A.os_flag('max-counts', 'num', help='inclusive upper library-count cutoff', required=True, range=(1, 1000000000000.0)),
        A.os_flag('max-mito-percent', 'num', help='inclusive mitochondrial percentage ceiling', required=True, range=(0, 100)),
        A.os_flag('min-cells', 'int', help='minimum cells expressing each retained gene', required=True, range=(1, 1000000)),
        A.os_flag('doublet-mode', 'enum', help='prespecified doublet policy', required=True, values=['skip', 'score', 'filter']),
        A.os_flag('expected-doublet-rate', 'num', help='expected doublet rate for scrublet; required unless skipped', range=(1e-06, 0.999999)),
        A.os_flag('doublet-threshold', 'num', help='explicit scrublet classification cutoff; required unless skipped', range=(0, 1)),
        A.os_flag('scrublet-pcs', 'int', help='number of scrublet principal components', default=30, range=(2, 1000)),
        A.os_flag('sim-doublet-ratio', 'num', default=2.0, help='native sc.pp.scrublet.sim_doublet_ratio; value option'),
        A.os_flag('stdev-doublet-rate', 'num', default=0.02, help='native sc.pp.scrublet.stdev_doublet_rate; value option'),
        A.os_flag('synthetic-doublet-umi-subsampling', 'num', default=1.0, help='native sc.pp.scrublet.synthetic_doublet_umi_subsampling; value option'),
        A.os_flag('knn-dist-metric', 'string', default='euclidean', help='native sc.pp.scrublet.knn_dist_metric; value option'),
        A.os_flag('normalize-variance', 'enum', default='on', values=['on', 'off'], help='native sc.pp.scrublet.normalize_variance; boolean option'),
        A.os_flag('log-transform', 'enum', default='off', values=['on', 'off'], help='native sc.pp.scrublet.log_transform; boolean option'),
        A.os_flag('mean-center', 'enum', default='on', values=['on', 'off'], help='native sc.pp.scrublet.mean_center; boolean option'),
        A.os_flag('use-approx-neighbors', 'enum', default='none', values=['on', 'off', 'none'], help='native sc.pp.scrublet.use_approx_neighbors; boolean option'),
        A.os_flag('n-neighbors', 'int', default=None, help='native sc.pp.scrublet.n_neighbors; value option'),
    ], exclusive=[("input", "from-run")])
def main(argv):
    return S.run_module(argv, SPEC, 'scanpy-qc', str(MODULE_DIR), core.compute, report, qc, core.validate)
if __name__ == "__main__":
    run_entry(main)
