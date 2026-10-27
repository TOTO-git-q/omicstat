"""Bind the existing official paired sleep example to a fresh owner receipt.

The R writer, scientific contract, canonical arguments and printed anchors are
unchanged. No download, synthetic substitute or statistical calculation occurs
in this receipt adapter. Fresh native bytes must match the registered example.
"""
import hashlib
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'mcp'))
from acceptance.owner_data import dataset
from study_contract import build_contract, contract_bytes


def prepare(destination, root=ROOT):
    root = pathlib.Path(root).resolve()
    out = pathlib.Path(destination)
    registered, _ = dataset(root, 'omicstat-groupcompare', 'r-sleep')
    if len(registered['sources']) != 1 or registered['sources'][0]['key'] != 'sleep_csv':
        raise ValueError('sleep owner registration must have exactly one source')
    # Pipeline creates an empty fixtures directory. Never overwrite any earlier
    # evidence, including a partial preparation from a failed native attempt.
    if out.is_symlink() or (out.exists() and (not out.is_dir() or any(out.iterdir()))):
        raise FileExistsError('fresh empty canonical fixture required; preserve earlier evidence')
    out.mkdir(parents=True, exist_ok=True)
    contract = build_contract(design='Paired sleep demonstration, two drugs in the same ten subjects',biological_unit='Subject ID, never a row or technical observation',population='All ten subjects in datasets::sleep',comparison={'target':'Drug 1 minus drug 2','measure':'Mean difference in extra sleep hours','exposure':'Drug 1','comparator':'Drug 2'},outcomes=[{'name':'Extra sleep hours','timepoint':'One observation per drug and subject'}],covariates=[],missing_data='Refuse missing data and incomplete pairs',multiplicity='One prespecified two-sided paired t-test; no adjustment; 90% marginal CI',analysis_sets=['All ten paired subjects'],schema_path=root/'skills/_shared/schemas/study_contract.v1.schema.json')
    (out / 'contract.json').write_bytes(contract_bytes(contract))
    subprocess.run(['Rscript', str(root / 'skills/omicstat-groupcompare/tests/make_inputs.R'), str(out)], check=True)
    source = out / 'sleep.csv'
    expected = registered['sources'][0]['sha256']
    if source.is_symlink() or not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != expected:
        raise ValueError('registered datasets::sleep serialization SHA256 mismatch')
    inputs = []
    for name in ('sleep.csv', 'comparisons.csv', 'contract.json'):
        path = out / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('prepared canonical input is missing or unsafe: ' + name)
        inputs.append({'path': name, 'bytes': path.stat().st_size,
                       'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    receipt = {
        'schema': 'omicstat.owner-dataset-receipt.v1',
        'dataset_id': 'r-sleep', 'kind': 'registered_real',
        'source_files': [{'key': 'sleep_csv', 'sha256': expected}],
        'prepared_inputs': inputs,
        'preparation': {'source': 'R datasets::sleep; existing make_inputs.R write.csv',
                        'subjects': 10, 'observations': 20, 'design': 'paired',
                        'rule': 'All supplied subjects; same ten ID values in both drugs',
                        'independent_group_inference': False,
                        'scope': 'Existing paired t-test example only; not clinical guidance or TOST equivalence'},
    }
    (out / 'owner_dataset.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    prepare(sys.argv[1])
