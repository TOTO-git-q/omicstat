"""Retained direct raw-count QC replay; no guessed printed Scanpy values."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'skills/_shared/py/tests'))


def check(source, run, destination):
    destination = pathlib.Path(destination)
    if destination.exists():
        raise FileExistsError('preserve previous anchor result; fresh output required')
    from sc_smoke_support import independent_replay
    independent_replay('scanpy-qc', pathlib.Path(source), pathlib.Path(run))
    result = {'library_counts_exact': True, 'detected_genes_exact': True, 'retained_cell_ids_exact': True}
    destination.write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: anchors.py PREPARED_INPUT CANONICAL_RUN OBTAINED_JSON')
    check(*sys.argv[1:])
