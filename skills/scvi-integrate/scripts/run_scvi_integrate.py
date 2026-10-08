#!/usr/bin/env python3
"""scvi-integrate: one spec, verified input, computation, figures, QC and provenance."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py"))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scvi_integrate_core as core
from scvi_integrate_report import report
from scvi_integrate_qc import qc
SPEC = A.os_arg_spec(usage="python run_scvi_integrate.py --input <h5ad>|--from-run <dir> --outdir <dir> [options]",
    description='Integrate multiple batches using a CPU scVI latent model', flags=S.common_flags() + [
        A.os_flag('latent-from-run', 'path', must_exist=True, help='reuse matched or subset cells from an earlier scvi-integrate run; no training'),
        A.os_flag('leiden-resolution', 'num', range=(0.0001, 100), help='optional explicit Leiden resolution on scvi_neighbors'),
        A.os_flag('scvi-cluster-col', 'string', help='new column for optional scVI-graph Leiden; requires leiden-resolution'),
        A.os_flag('batch-col', 'string', help='nuisance batch variable; not an unexamined biological condition', required=True),
        A.os_flag('cluster-col', 'string', help='existing descriptive cluster metadata', required=True),
        A.os_flag('max-epochs', 'int', help='explicit CPU training budget', required=True, range=(1, 400)),
        A.os_flag('n-neighbors', 'int', help='explicit neighbors for latent-space graph', required=True, range=(2, 1000)),
        A.os_flag('n-latent', 'int', help='scVI latent dimension', default=10, range=(2, 1000)),
        A.os_flag('batch-size', 'int', help='training and inference minibatch size', default=128, range=(2, 4096)),
        A.os_flag('min-dist', 'num', help='UMAP minimum distance', default=0.5, range=(0, 1)),
        A.os_flag('features-file', 'path', help='optional prespecified ordered gene subset (one ID per line); otherwise all genes'),
        A.os_flag('size-factor-key', 'string', default=None, help='native scvi.model.SCVI.setup_anndata.size_factor_key; value option'),
        A.os_flag('categorical-covariate-keys', 'string', default=None, help='native scvi.model.SCVI.setup_anndata.categorical_covariate_keys; list option'),
        A.os_flag('continuous-covariate-keys', 'string', default=None, help='native scvi.model.SCVI.setup_anndata.continuous_covariate_keys; list option'),
        A.os_flag('n-hidden', 'int', default=128, help='native scvi.model.SCVI.n_hidden; value option'),
        A.os_flag('n-layers', 'int', default=1, help='native scvi.model.SCVI.n_layers; value option'),
        A.os_flag('dropout-rate', 'num', default=0.1, help='native scvi.model.SCVI.dropout_rate; value option'),
        A.os_flag('dispersion', 'enum', default='gene', values=['gene', 'gene-batch', 'gene-label', 'gene-cell'], help='native scvi.model.SCVI.dispersion; value option'),
        A.os_flag('gene-likelihood', 'enum', default='zinb', values=['zinb', 'nb', 'poisson', 'normal'], help='native scvi.model.SCVI.gene_likelihood; value option'),
        A.os_flag('use-observed-lib-size', 'enum', default='on', values=['on', 'off'], help='native scvi.model.SCVI.use_observed_lib_size; boolean option'),
        A.os_flag('latent-distribution', 'enum', default='normal', values=['normal', 'ln'], help='native scvi.model.SCVI.latent_distribution; value option'),
        A.os_flag('train-size', 'num', default=None, help='native model.train.train_size; value option'),
        A.os_flag('validation-size', 'num', default=None, help='native model.train.validation_size; value option'),
        A.os_flag('shuffle-set-split', 'enum', default='on', values=['on', 'off'], help='native model.train.shuffle_set_split; boolean option'),
        A.os_flag('early-stopping', 'enum', default='off', values=['on', 'off'], help='native model.train.early_stopping; boolean option'),
        A.os_flag('datasplitter-kwargs', 'string', default=None, help='native model.train.datasplitter_kwargs; object option'),
        A.os_flag('plan-kwargs', 'string', default=None, help='native model.train.plan_kwargs; object option'),
        A.os_flag('neighbors-method', 'string', default='umap', help='native sc.pp.neighbors.method; value option'),
        A.os_flag('neighbors-transformer', 'enum', default='none', values=['none', 'pynndescent', 'sklearn'], help='native sc.pp.neighbors.transformer; nullable_string option'),
        A.os_flag('neighbors-metric', 'string', default=None, help='native sc.pp.neighbors.metric; value option'),
        A.os_flag('neighbors-metric-kwds', 'string', default='{}', help='native sc.pp.neighbors.metric_kwds; object option'),
        A.os_flag('umap-spread', 'num', default=1.0, help='native sc.tl.umap.spread; value option'),
        A.os_flag('umap-maxiter', 'int', default=None, help='native sc.tl.umap.maxiter; value option'),
        A.os_flag('umap-alpha', 'num', default=1.0, help='native sc.tl.umap.alpha; value option'),
        A.os_flag('umap-gamma', 'num', default=1.0, help='native sc.tl.umap.gamma; value option'),
        A.os_flag('umap-negative-sample-rate', 'int', default=5, help='native sc.tl.umap.negative_sample_rate; value option'),
        A.os_flag('umap-init-pos', 'string', default='spectral', help='native sc.tl.umap.init_pos; value option'),
        A.os_flag('umap-a', 'num', default=None, help='native sc.tl.umap.a; value option'),
        A.os_flag('umap-b', 'num', default=None, help='native sc.tl.umap.b; value option'),
    ], exclusive=[("input", "from-run")])
def main(argv):
    return S.run_module(argv, SPEC, 'scvi-integrate', str(MODULE_DIR), core.compute, report, qc, core.validate, module_version=core.MODULE_VERSION)
if __name__ == "__main__":
    run_entry(main)
