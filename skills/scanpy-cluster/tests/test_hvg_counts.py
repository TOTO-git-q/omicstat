"""HVG flavors use the input scale required by the installed Scanpy API."""
import runpy
import sys
from pathlib import Path
from unittest.mock import patch

MODULE = Path(__file__).resolve().parent.parent
SUITE = MODULE.parent.parent
sys.path.insert(0, str(SUITE / 'skills/_shared/py/tests'))


def check_hvg_counts(work):
    import anndata as ad
    import numpy as np
    import scanpy as sc
    from sc_anchor import make_pbmc
    entry = runpy.run_path(str(MODULE / 'scripts/run_scanpy_cluster.py'))
    work = Path(work)
    work.mkdir(parents=True, exist_ok=True)
    raw = ad.read_h5ad(make_pbmc(SUITE, work / 'pbmc.h5ad'))
    sc.pp.filter_genes(raw, min_cells=3)
    args = entry['A'].os_parse_args(entry['SPEC'], ['--input', str(work / 'pbmc.h5ad'), '--outdir', str(work / 'out'),
        '--sample-col', 'sample', '--counts-layer', 'X', '--species', 'human', '--annotation', 'anchor',
        '--n-hvg', '600', '--n-pcs', '10', '--n-neighbors', '10', '--resolution', '.5'])
    native = sc.pp.highly_variable_genes
    class FinishedHVG(Exception):
        pass
    for flavor in ('seurat_v3', 'seurat_v3_paper'):
        args['hvg-flavor'] = flavor
        observed = {}
        def capture(**kwargs):
            assert kwargs['layer'] == 'counts', 'count-based HVG flavor received log-normalized X'
            native(**kwargs)
            observed['hvg'] = kwargs['adata'].var['highly_variable'].to_numpy().copy()
            raise FinishedHVG
        with patch.object(sc.pp, 'highly_variable_genes', side_effect=capture):
            try:
                entry['core'].compute(raw.copy(), args, None)
            except FinishedHVG:
                pass
        replay = raw.copy()
        native(replay, flavor=flavor, n_top_genes=600, span=.3)
        np.testing.assert_array_equal(observed['hvg'], replay.var['highly_variable'].to_numpy())
        print('PASS:', flavor, 'HVGs equal native raw-count replay')


if __name__ == '__main__':
    import os
    check_hvg_counts(Path(os.environ.get('OMICSTAT_TEST_TMP', '/tmp')) / 'hvg-counts')
