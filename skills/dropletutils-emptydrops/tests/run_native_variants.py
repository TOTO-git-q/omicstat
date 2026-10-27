"""Actual dense/sparse/CSV and native Monte Carlo option checks on artificial drops."""
from pathlib import Path
import csv
import hashlib
import json
import math
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def read_table(path):
    with path.open() as handle:
        return list(csv.DictReader(handle))


def bh(values):
    order = sorted((i for i, value in enumerate(values) if value is not None), key=lambda i: values[i])
    result = [None] * len(values)
    current = 1.
    for rank in range(len(order), 0, -1):
        index = order[rank - 1]
        current = min(current, values[index] * len(order) / rank)
        result[index] = current
    return result


summary = []
with tempfile.TemporaryDirectory() as tmp:
    fx = Path(tmp) / 'fixtures'
    subprocess.run([sys.executable, str(HERE / 'prepare_acceptance.py'), str(fx)], check=True)
    subprocess.run(['Rscript', '-e', "a<-commandArgs(TRUE);x<-readRDS(a[1]);saveRDS(Matrix::Matrix(x,sparse=TRUE),a[2])", str(fx/'counts.rds'), str(fx/'sparse.rds')], check=True)
    provenance = json.loads((fx / 'counts.rds.json').read_text())
    provenance['sha256'] = hashlib.sha256((fx / 'sparse.rds').read_bytes()).hexdigest()
    (fx / 'sparse.rds.json').write_text(json.dumps(provenance))
    base = json.loads((HERE / 'acceptance.json').read_text())['canonical']['argv']
    outputs = {}
    variants = [('dense', {}), ('sparse', {'input': '{fixtures}/sparse.rds', 'input-provenance': '{fixtures}/sparse.rds.json'}),
                ('csv', {'input': '{fixtures}/counts.csv', 'input-provenance': '{fixtures}/counts.csv.json', 'format': 'csv'}),
                ('test-ambient', {'test-ambient': 'true'}), ('retain-by-count', {'retain': '400'}),
                ('finite-alpha', {'alpha': '10'}), ('estimated-alpha', {'alpha': 'estimate'})]
    for name, changes in variants:
        args = base.copy()
        for key, value in changes.items():
            args[args.index('--' + key) + 1] = value
        out = Path(tmp) / name
        args = [x.replace('{fixtures}', str(fx)).replace('{outdir}', str(out)) for x in args]
        subprocess.run(['Rscript', str(HERE.parent / 'scripts/run_dropletutils_emptydrops.R'), *args], check=True)
        observed = read_table(out / 'tables/barcodes.csv')
        assert len(observed) == 250 and len({row['barcode'] for row in observed}) == 250
        assert sum(int(row['total_umi']) for row in observed) == 30000
        correction = [0. if row['retained_by_count'] == 'TRUE' else float(row['p_value']) if row['p_value'] not in ('NA', '') else None for row in observed]
        correction = [None if int(row['total_umi']) <= 100 else p for row, p in zip(observed, correction)]
        expected = bh(correction)
        max_error = 0.
        for row, target in zip(observed, expected):
            assert (row['fdr'] in ('NA', '')) == (target is None)
            if target is not None:
                max_error = max(max_error, abs(float(row['fdr']) - target))
            assert (row['called_nonempty'] == 'TRUE') == (target is not None and target <= .01)
            if row['p_value'] not in ('NA', ''):
                value = float(row['p_value'])
                assert math.isfinite(value) and 0 <= value <= 1
        assert max_error < 1e-10
        profile = read_table(out / 'tables/ambient_profile.csv')
        assert len(profile) == 51 and abs(sum(float(row['probability']) for row in profile) - 1) < 1e-8
        assert float(next(row for row in profile if row['feature_id'] == 'gene51')['probability']) == 0
        assert sum(row['status'] == 'zero-count' for row in observed) == 10
        assert sum(row['retained_by_count'] == 'TRUE' for row in observed) == (40 if name == 'retain-by-count' else 0)
        if name == 'test-ambient':
            assert all(row['p_value'] not in ('NA', '') for row in observed if 0 < int(row['total_umi']) <= 100)
        subprocess.run(['Rscript', str(HERE / 'verify_native_output.R'), str(fx / 'counts.rds'), str(out)], check=True)
        resolved = {row['parameter']: row for row in read_table(out / 'tables/engine_parameters.csv')}
        assert set(resolved) == {'lower', 'niters', 'retain', 'alpha'}
        actual_alpha = float(resolved['alpha']['resolved'])
        assert actual_alpha > 0 and not math.isnan(actual_alpha)
        if name == 'finite-alpha':
            assert actual_alpha == 10
        elif name == 'estimated-alpha':
            assert resolved['alpha']['requested'] == 'estimate'
        else:
            assert actual_alpha == math.inf
        outputs[name] = observed
        summary.append(dict(variant=name, actual_exit=0, resolved_alpha=resolved['alpha']['resolved'], raw_barcodes=250, raw_UMIs=30000,
                            ambient_features=51, BH_family=sum(p is not None for p in expected),
                            independent_BH_max_error=max_error,
                            retained_by_count=sum(row['retained_by_count'] == 'TRUE' for row in observed),
                            nonempty_FDR=sum(row['called_nonempty'] == 'TRUE' for row in observed)))
    assert outputs['dense'] == outputs['sparse'] == outputs['csv']
    summary.append(dict(dense_sparse_CSV_all_barcode_inference_identical=True))
print(json.dumps(summary, indent=2))
