#!/usr/bin/env python3
"""scanvi-annotate: one spec, verified input, computation, figures, QC and provenance."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py"))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanvi_annotate_core as core
from scanvi_annotate_report import report
from scanvi_annotate_qc import qc
SPEC = A.os_arg_spec(usage="python run_scanvi_annotate.py --input <h5ad>|--from-run <dir> --outdir <dir> [options]",
    description='Transfer observed reference labels with scANVI', flags=S.common_flags() + [
        A.os_flag('labels-col', 'string', help='reference labels with an explicit unlabeled category', required=True),
        A.os_flag('unlabeled-category', 'string', help='exact label reserved for query cells', required=True),
        A.os_flag('cluster-col', 'string', help='existing cluster column for crosstab', required=True),
        A.os_flag('prediction-col', 'string', help='new annotation column; observed labels are not overwritten', default='scanvi_label'),
        A.os_flag('max-epochs', 'int', help='explicit CPU training budget', required=True, range=(1, 400)),
        A.os_flag('samples-per-label', 'int', help='optional label subsampling count; omitted means no subsampling', range=(1, 100000)),
        A.os_flag('batch-size', 'int', help='training and inference minibatch size', default=128, range=(2, 4096)),
        A.os_flag('min-confidence', 'num', help='explicit display/QC probability cutoff; labels are still retained', required=True, range=(0, 1)),
        A.os_flag('train-size', 'num', default=0.9, help='native model.train.train_size; value option'),
        A.os_flag('validation-size', 'num', default=None, help='native model.train.validation_size; value option'),
        A.os_flag('shuffle-set-split', 'enum', default='on', values=['on', 'off'], help='native model.train.shuffle_set_split; boolean option'),
        A.os_flag('adversarial-classifier', 'enum', default='none', values=['on', 'off', 'none'], help='native model.train.adversarial_classifier; boolean option'),
        A.os_flag('datasplitter-kwargs', 'string', default=None, help='native model.train.datasplitter_kwargs; object option'),
        A.os_flag('plan-kwargs', 'string', default=None, help='native model.train.plan_kwargs; object option'),
        A.os_flag('use-posterior-mean', 'enum', default='on', values=['on', 'off'], help='native model.predict.use_posterior_mean; boolean option'),
    ], exclusive=[("input", "from-run")])
def main(argv):
    return S.run_module(argv, SPEC, 'scanvi-annotate', str(MODULE_DIR), core.compute, report, qc, core.validate)
if __name__ == "__main__":
    run_entry(main)
