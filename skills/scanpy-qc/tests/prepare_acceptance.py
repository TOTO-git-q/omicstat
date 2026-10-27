"""Prepare full hash-checked PBMC3k for canonical/owner review, without download.

The existing smoke test retains its explicit 600-cell budget. This separate
owner fixture uses every supplied cell, with the same biological sample label.
PBMC3k is one sample; this does not create independent biological replicates.
"""
import hashlib
import json
import pathlib
import sys


def prepare(destination, root):
    destination, root = pathlib.Path(destination), pathlib.Path(root)
    destination.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(root / 'skills/_shared/py/tests'))
    from sc_anchor import make_pbmc
    path = destination / 'pbmc3k.h5ad'
    if path.exists() or (destination / 'owner_dataset.json').exists():
        raise FileExistsError('fresh canonical fixture required; preserve earlier evidence')
    path = make_pbmc(root, path, max_cells=None)
    source = json.loads(path.with_name(path.name + '.source.json').read_text())
    receipt = {
        'schema': 'omicstat.owner-dataset-receipt.v1', 'dataset_id': 'pbmc3k', 'kind': 'registered_real',
        'source_files': [{'key': 'archive', 'sha256': source['source_sha256']}],
        'prepared_inputs': [{'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                             'bytes': path.stat().st_size}],
        'preparation': {'rule': source['fixture_rule'], 'n_cells': source['n_cells'],
                        'n_genes': source['n_genes'], 'biological_samples': 1,
                        'independent_condition_inference': False}}
    (destination / 'owner_dataset.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: prepare_acceptance.py FIXTURES ROOT')
    prepare(sys.argv[1], sys.argv[2])
