#!/usr/bin/env python3
"""scanpy-cluster: one spec, verified input, computation, figures, QC and provenance."""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
MODULE_DIR = HERE.parent
SUITE = MODULE_DIR.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py"))
sys.path.insert(0, str(HERE))
from ospy import args as A, sc_module as S
from ospy.errors import run_entry
import scanpy_cluster_core as core
from scanpy_cluster_report import report
from scanpy_cluster_qc import qc
SPEC = A.os_arg_spec(usage="python run_scanpy_cluster.py --input <h5ad>|--from-run <dir> --outdir <dir> [options]",
    description='Normalize, find variable genes, cluster and embed AnnData cells', flags=S.common_flags() + [
        A.os_flag('use-rep', 'string', help='existing obsm representation for neighbors, Leiden and UMAP; skips recomputed PCA'),
        A.os_flag('n-hvg', 'int', help='prespecified highly variable gene count; tutorial examples are not defaults', required=True, range=(3, 100000)),
        A.os_flag('n-pcs', 'int', help='prespecified PCA dimension', required=True, range=(2, 1000)),
        A.os_flag('n-neighbors', 'int', help='prespecified number of neighbors', required=True, range=(2, 1000)),
        A.os_flag('resolution', 'num', help='prespecified Leiden resolution', required=True, range=(0.0001, 100)),
        A.os_flag('cluster-col', 'string', help='output cluster metadata column', default='cluster'),
        A.os_flag('target-sum', 'num', help='normalize_total target; omitted means locked API median-library behavior', range=(1, 1000000000000.0)),
        A.os_flag('hvg-batch-col', 'string', help='optional batch column for batch-aware HVG selection'),
        A.os_flag('scale-max', 'num', help='clipping in explicit --scale on branch; omitted means no clipping', range=(1e-06, 1000)),
        A.os_flag('min-dist', 'num', help='UMAP minimum distance', default=0.5, range=(0, 1)),
        A.os_flag('normalize-exclude-highly-expressed', 'enum', default='off', values=['on', 'off'], help='native sc.pp.normalize_total.exclude_highly_expressed; boolean option'),
        A.os_flag('normalize-max-fraction', 'num', default=0.05, help='native sc.pp.normalize_total.max_fraction; value option'),
        A.os_flag('log1p-base', 'num', default=None, help='native sc.pp.log1p.base; value option'),
        A.os_flag('hvg-span', 'num', default=0.3, help='native sc.pp.highly_variable_genes.span; value option'),
        A.os_flag('hvg-n-bins', 'int', default=20, help='native sc.pp.highly_variable_genes.n_bins; value option'),
        A.os_flag('hvg-flavor', 'enum', default='seurat', values=['seurat', 'cell_ranger', 'seurat_v3', 'seurat_v3_paper'], help='native sc.pp.highly_variable_genes.flavor; value option'),
        A.os_flag('scale-zero-center', 'enum', default='on', values=['on', 'off'], help='native sc.pp.scale.zero_center; boolean option'),
        A.os_flag('pca-zero-center', 'enum', default='on', values=['on', 'off'], help='native sc.pp.pca.zero_center; boolean option'),
        A.os_flag('pca-svd-solver', 'enum', default='none', values=['none', 'arpack', 'auto', 'full', 'randomized', 'covariance_eigh'], help='native sc.pp.pca.svd_solver; value option'),
        A.os_flag('pca-dtype', 'enum', default='float32', values=['float32', 'float64'], help='native sc.pp.pca.dtype; value option'),
        A.os_flag('neighbors-method', 'string', default='umap', help='native sc.pp.neighbors.method; value option'),
        A.os_flag('neighbors-transformer', 'enum', default='none', values=['none', 'pynndescent', 'sklearn'], help='native sc.pp.neighbors.transformer; nullable_string option'),
        A.os_flag('neighbors-metric', 'string', default=None, help='native sc.pp.neighbors.metric; value option'),
        A.os_flag('neighbors-metric-kwds', 'string', default='{}', help='native sc.pp.neighbors.metric_kwds; object option'),
        A.os_flag('leiden-use-weights', 'enum', default='on', values=['on', 'off'], help='native sc.tl.leiden.use_weights; boolean option'),
        A.os_flag('leiden-n-iterations', 'int', default=-1, help='native sc.tl.leiden.n_iterations; value option'),
        A.os_flag('leiden-partition-type', 'enum', default='none', values=['none', 'RBConfigurationVertexPartition', 'CPMVertexPartition', 'ModularityVertexPartition', 'RBERVertexPartition', 'SignificanceVertexPartition', 'SurpriseVertexPartition'], help='native sc.tl.leiden.partition_type; partition option'),
        A.os_flag('umap-spread', 'num', default=1.0, help='native sc.tl.umap.spread; value option'),
        A.os_flag('umap-maxiter', 'int', default=None, help='native sc.tl.umap.maxiter; value option'),
        A.os_flag('umap-alpha', 'num', default=1.0, help='native sc.tl.umap.alpha; value option'),
        A.os_flag('umap-gamma', 'num', default=1.0, help='native sc.tl.umap.gamma; value option'),
        A.os_flag('umap-negative-sample-rate', 'int', default=5, help='native sc.tl.umap.negative_sample_rate; value option'),
        A.os_flag('umap-init-pos', 'string', default='spectral', help='native sc.tl.umap.init_pos; value option'),
        A.os_flag('umap-a', 'num', default=None, help='native sc.tl.umap.a; value option'),
        A.os_flag('umap-b', 'num', default=None, help='native sc.tl.umap.b; value option'),
        A.os_flag('leiden-flavor', 'enum', default='igraph', values=['igraph', 'leidenalg'], help='native Leiden implementation; partition-type requires leidenalg'),
        A.os_flag('scale', 'enum', default='off', values=['off', 'on'], help='explicit scaling branch; cited clustering tutorial omits scaling'),
    ], exclusive=[("input", "from-run")])
def main(argv):
    return S.run_module(argv, SPEC, 'scanpy-cluster', str(MODULE_DIR), core.compute, report, qc, core.validate, module_version=core.MODULE_VERSION)
if __name__ == "__main__":
    run_entry(main)
