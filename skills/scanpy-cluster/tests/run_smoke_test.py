#!/usr/bin/env python3
"""Static checks plus official anchor numerical replay in the pinned image."""
import sys
from pathlib import Path
MODULE = Path(__file__).resolve().parent.parent
SUITE = MODULE.parent.parent
sys.path.insert(0, str(SUITE / "skills/_shared/py/tests"))
from sc_smoke_support import main, run, load
def regression(source, args, output, work):
    import numpy as np
    original = load(output)
    supplied = list(args)
    source_flag = '--from-run' if '--from-run' in supplied else '--input'
    supplied[supplied.index(source_flag)] = '--from-run'
    supplied[supplied.index('--from-run') + 1] = output
    supplied[supplied.index('--outdir') + 1] = work / 'existing_rep'
    supplied[supplied.index('--counts-layer') + 1] = 'counts'
    supplied[supplied.index('--n-hvg') + 1] = 10
    supplied[supplied.index('--n-pcs') + 1] = 30
    supplied += ['--use-rep', 'X_pca']
    run('scanpy-cluster', supplied)
    current = load(work / 'existing_rep')
    np.testing.assert_array_equal(current.obsm['X_pca'], original.obsm['X_pca'])
    assert 'without recomputing PCA or scaling' in (work / 'existing_rep/draft/methods_results.md').read_text()
    print('PASS: supplied representation remains exact; inactive PCA dimension setting does not constrain HVGs')


if __name__ == "__main__":
    status = main(MODULE, regression)
    if status == 0:
        import importlib.util
        if importlib.util.find_spec("scanpy") is not None:
            import os
            from test_hvg_counts import check_hvg_counts
            check_hvg_counts(Path(os.environ.get("OMICSTAT_TEST_TMP", "/tmp")) / "hvg-counts")
    raise SystemExit(status)
