"""Run the retained direct Scanpy replay against the actual PBMC3k result.

No printed cluster count is invented. The three tests retain the documented
same-platform thresholds (HVG exact; PCA atol/rtol 1e-6; cluster ARI exactly 1).
An assertion or missing dependency fails the script and cannot yield true.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'skills/_shared/py/tests'))


def check(source, run, destination):
    from sc_smoke_support import independent_replay
    independent_replay('scanpy-cluster', pathlib.Path(source), pathlib.Path(run))
    result = {'hvg_exact': True, 'pca_fixed_tolerance': True, 'cluster_ari_one': True}
    pathlib.Path(destination).write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit('usage: anchors.py PREPARED_INPUT CANONICAL_RUN OBTAINED_JSON')
    check(*sys.argv[1:])
