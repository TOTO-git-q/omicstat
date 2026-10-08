#!/usr/bin/env python3
"""Official anchor replay plus optional latent reuse/new-column invariants."""
import sys
from pathlib import Path
MODULE = Path(__file__).resolve().parent.parent
SUITE = MODULE.parent.parent
sys.path.insert(0, str(SUITE / 'skills/_shared/py/tests'))
from sc_smoke_support import main, run, load


def regression(source, args, output, work):
    import numpy as np
    import pandas as pd
    baseline = load(output)
    cells = work / 'balanced_cells.csv'
    pd.DataFrame({'cell': baseline.obs_names[:64]}).to_csv(cells, index=False)
    reused = list(args)
    reused[reused.index('--outdir') + 1] = work / 'latent_reuse'
    reused += ['--latent-from-run', output, '--cell-list', cells,
               '--leiden-resolution', 0.5, '--scvi-cluster-col', 'scvi_cluster']
    run('scvi-integrate', reused)
    current = load(work / 'latent_reuse')
    np.testing.assert_array_equal(current.obsm['X_scVI'], baseline.obsm['X_scVI'][:64])
    np.testing.assert_array_equal(current.obs['cluster'], baseline.obs['cluster'][:64])
    assert 'scvi_cluster' in current.obs and not (work / 'latent_reuse/objects/scvi_model').exists()
    draft = (work / 'latent_reuse/draft/methods_results.md').read_text()
    assert 'without training an SCVI model in this run' in draft
    import json
    result = json.loads((work / 'latent_reuse/results/scvi_integrate_results.json').read_text())
    assert result['latent_reused'] and result['n_model_genes'] is None
    collision = list(args)
    collision[collision.index('--outdir') + 1] = work / 'refused_column'
    collision += ['--leiden-resolution', 0.5, '--scvi-cluster-col', 'cluster']
    run('scvi-integrate', collision, error='OS_INVALID_PARAMETER')
    print('PASS: exact latent reuse, subset alignment, no retraining and preserved carried clusters')


if __name__ == '__main__':
    raise SystemExit(main(MODULE, regression))
