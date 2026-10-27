"""Invented 141000-nucleus resource fixture; no biological reference data."""
from pathlib import Path


def prepare(out):
    import numpy as np
    import pandas as pd
    import anndata as ad
    from scipy import sparse
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    source = out / 'synthetic_141000.h5ad'
    if source.exists():
        raise FileExistsError('fresh fixture required; preserve earlier evidence')
    n, g = 141000, 2000
    rows = np.repeat(np.arange(n, dtype=np.int32), 3)
    base = np.arange(n, dtype=np.int32) % g
    cols = np.column_stack((base, (base + 137) % g, (base + 911) % g)).ravel()
    matrix = sparse.csr_matrix(
        (np.tile(np.array([1, 2, 4], dtype=np.int32), n), (rows, cols)), shape=(n, g))
    donors = np.repeat(['Synthetic donor ' + str(i + 1) for i in range(6)], 23500)
    condition = np.repeat(['Synthetic condition A', 'Synthetic condition B'], n // 2)
    obs = pd.DataFrame({'donor': donors, 'condition': condition},
                       index=['synthetic_nucleus_%06d' % i for i in range(n)])
    var = pd.DataFrame(index=['synthetic_feature_%04d' % i for i in range(g)])
    data = ad.AnnData(matrix, obs=obs, var=var,
                      uns={'fixture_origin': 'entirely invented deterministic sparse counts',
                           'synthetic': True})
    data.layers['counts'] = data.X.copy()
    data.write_h5ad(source, compression='gzip', compression_opts=1)
    return data, source


def arguments(source, outdir):
    return {'input': str(source), 'outdir': str(outdir), 'sample-col': 'donor',
            'counts-layer': 'counts',
            'species': 'synthetic', 'annotation': 'invented-v1', 'n-hvg': 2000,
            'n-pcs': 30, 'n-neighbors': 15, 'resolution': 0.5, 'seed': 7}
