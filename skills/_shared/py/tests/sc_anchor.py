"""Offline official anchors for the five scverse modules.

PBMC3k is the registered Scanpy/Seurat tutorial input (F1). scVI uses the
package's own synthetic_iid simulator; its labels do not imply biological
validity or a prediction-accuracy benchmark. No tutorial numbers are invented.
"""
from __future__ import annotations
import hashlib
import json
import tarfile
from pathlib import Path

PBMC_SHA256 = '847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5'
SEED = 20260925


def make_pbmc(suite, destination, *, max_cells=600):
    if max_cells is not None and (type(max_cells) is not int or max_cells < 1):
        raise ValueError('max_cells must be a positive integer or None for the complete registered input')
    import scanpy as sc
    source = Path(suite) / 'acceptance/data/pbmc3k_filtered_gene_bc_matrices.tar.gz'
    if not source.is_file():
        raise FileNotFoundError('F1 PBMC3k anchor missing; run bash acceptance/data/fetch_anchor_data.sh 10x outside analysis')
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != PBMC_SHA256:
        raise RuntimeError('OS_ANCHOR_MISMATCH: PBMC3k archive SHA256 mismatch')
    unpack = Path(destination).parent / 'pbmc3k_unpacked'
    unpack.mkdir(parents=True, exist_ok=True)
    with tarfile.open(source, 'r:gz') as archive:
        for member in archive.getmembers():
            if member.issym() or member.islnk() or not (unpack / member.name).resolve().is_relative_to(unpack.resolve()):
                raise RuntimeError('OS_ANCHOR_MISMATCH: unsafe archive entry')
        archive.extractall(unpack, filter='data')
    matrix, = unpack.rglob('matrix.mtx')
    # The tutorial uses symbols and explicit duplicate-name disambiguation.
    data = sc.read_10x_mtx(path=matrix.parent, var_names='gene_symbols', make_unique=True,
                           cache=False, cache_compression='gzip', gex_only=True, prefix=None)
    if max_cells is not None:
        data = data[:max_cells, :].copy()  # legacy smoke budget, not an analysis default
    data.obs['sample'] = 'pbmc3k'
    data.write_h5ad(filename=destination, compression='gzip', compression_opts=4, as_dense=())
    rule = ('all supplied cells and genes; no acceptance subsampling' if max_cells is None else
            'first %d cells in supplied order; all genes' % max_cells)
    record = {'anchor': 'F1', 'source_sha256': digest, 'fixture_rule': rule,
              'n_cells': data.n_obs, 'n_genes': data.n_vars, 'kind': 'official tutorial input, replay anchor'}
    Path(str(destination) + '.source.json').write_text(json.dumps(record, indent=2) + '\n')
    return Path(destination)


def make_synthetic(suite, destination):
    import numpy as np
    import scvi
    from ospy.seed import set_seed
    set_seed(SEED)
    data = scvi.data.synthetic_iid(batch_size=48, n_genes=160, n_proteins=1, n_regions=1,
                                  n_batches=2, n_labels=3, dropout_ratio=0.7,
                                  sparse_format='csr_matrix', generate_coordinates=False, return_mudata=False)
    data.obs['sample'] = data.obs['batch'].astype(str)
    truth = data.obs['labels'].astype(str).copy()
    observed = truth.copy()
    # Hold out alternate cells within each simulator label; never report this
    # IID simulation as an external biological classification benchmark.
    for label in sorted(truth.unique()):
        indices = np.flatnonzero(truth.to_numpy() == label)
        observed.iloc[indices[::2]] = 'unlabeled'
    data.obs['observed_label'] = observed
    data.write_h5ad(filename=destination, compression='gzip', compression_opts=4, as_dense=())
    record = {'anchor': 'PY-SIM-1', 'source': 'scvi.data.synthetic_iid', 'version': scvi.__version__, 'seed': SEED,
              'n_cells': data.n_obs, 'n_genes': data.n_vars, 'sha256': hashlib.sha256(Path(destination).read_bytes()).hexdigest(),
              'kind': 'official package simulator; numerical workflow replay only'}
    Path(str(destination) + '.source.json').write_text(json.dumps(record, indent=2) + '\n')
    return Path(destination)
