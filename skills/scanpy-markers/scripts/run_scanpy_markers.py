#!/usr/bin/env python3
"""scanpy-markers: one spec, verified input, computation, figures, QC and provenance."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py"))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanpy_markers_core as core
from scanpy_markers_report import report
from scanpy_markers_qc import qc
SPEC = A.os_arg_spec(usage="python run_scanpy_markers.py --input <h5ad>|--from-run <dir> --outdir <dir> [options]",
    description='Describe cluster markers without condition-level pseudoreplication', flags=S.common_flags() + [
        A.os_flag('cluster-col', 'string', help='observed cluster column', required=True),
        A.os_flag('expression-layer', 'string', help='natural-log1p normalized expression layer; use X explicitly for .X', required=True),
        A.os_flag('purpose', 'enum', help='must declare descriptive use; condition-inference is refused', required=True, values=['cluster-description', 'condition-inference']),
        A.os_flag('test', 'enum', help='locked API test family; t-test is the package default', default='t-test', values=['t-test', 't-test_overestim_var', 'wilcoxon']),
        A.os_flag('top-n', 'int', help='genes per cluster in the display; full results retained', default=5, range=(1, 100)),
        A.os_flag('mask-var', 'string', default=None, help='native sc.tl.rank_genes_groups.mask_var; value option'),
        A.os_flag('groups', 'string', default='all', help='native sc.tl.rank_genes_groups.groups; groups option'),
        A.os_flag('reference', 'string', default='rest', help='native sc.tl.rank_genes_groups.reference; value option'),
        A.os_flag('n-genes', 'int', default=None, help='native sc.tl.rank_genes_groups.n_genes; value option'),
        A.os_flag('rankby-abs', 'enum', default='off', values=['on', 'off'], help='native sc.tl.rank_genes_groups.rankby_abs; boolean option'),
        A.os_flag('corr-method', 'enum', default='benjamini-hochberg', values=['benjamini-hochberg', 'bonferroni'], help='native sc.tl.rank_genes_groups.corr_method; value option'),
        A.os_flag('tie-correct', 'enum', default='off', values=['on', 'off'], help='native sc.tl.rank_genes_groups.tie_correct; boolean option'),
    ], exclusive=[("input", "from-run")])
def main(argv):
    return S.run_module(argv, SPEC, 'scanpy-markers', str(MODULE_DIR), core.compute, report, qc, core.validate)
if __name__ == "__main__":
    run_entry(main)
